#!/bin/bash
set -Eeuo pipefail

# =========================================================
# Rocky Linux FastAPI 원클릭 배포
# =========================================================

if [[ $EUID -ne 0 ]]; then
    echo "root에서 실행하세요."
    echo "sudo ./setup-web.sh"
    exit 1
fi

DEFAULT_GIT="https://github.com/k-dev178/cde_web.git"
DEFAULT_PORT="8000"
DEFAULT_DOMAIN="jjcde.duckdns.org"
PYTHON_VERSION="3.12.14"
APP_MODULE="backend.main:app"
APP_USER="webapp"

echo "========================================="
echo " Rocky Linux FastAPI 원클릭 배포"
echo "========================================="
echo

read -rp "Git 주소 [$DEFAULT_GIT]: " GIT_URL
GIT_URL="${GIT_URL:-$DEFAULT_GIT}"

read -rp "FastAPI 내부 포트 [$DEFAULT_PORT]: " APP_PORT
APP_PORT="${APP_PORT:-$DEFAULT_PORT}"

read -rp "도메인 [$DEFAULT_DOMAIN]: " DOMAIN
DOMAIN="${DOMAIN:-$DEFAULT_DOMAIN}"

DOMAIN="${DOMAIN#http://}"
DOMAIN="${DOMAIN#https://}"
DOMAIN="${DOMAIN%/}"

REPO_NAME="$(basename "${GIT_URL%.git}")"
APP_DIR="/opt/$REPO_NAME"
SERVICE_NAME="$REPO_NAME"

echo
echo "Git       : $GIT_URL"
echo "설치 위치 : $APP_DIR"
echo "포트      : $APP_PORT"
echo "도메인    : $DOMAIN"
echo

# =========================================================
# 기본 패키지
# =========================================================

echo "=== 1. 필수 패키지 설치 ==="

dnf install -y \
    git \
    curl \
    ca-certificates \
    openssh-server \
    nginx \
    firewalld \
    policycoreutils

# =========================================================
# SSH / Firewall
# =========================================================

echo "=== 2. SSH / 방화벽 설정 ==="

systemctl enable --now sshd
systemctl enable --now firewalld

firewall-cmd --permanent --add-port=22/tcp
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --reload

# =========================================================
# uv 설치
# =========================================================

echo "=== 3. uv 설치 ==="

if [[ ! -x /usr/local/bin/uv ]]; then
    curl -LsSf https://astral.sh/uv/install.sh | \
        env UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 sh
fi

/usr/local/bin/uv --version

# =========================================================
# Python 설치
# /root 밑에 설치하지 않고 /opt 사용
# =========================================================

echo "=== 4. Python $PYTHON_VERSION 설치 ==="

mkdir -p /opt/uv-python

export UV_PYTHON_INSTALL_DIR="/opt/uv-python"

/usr/local/bin/uv python install "$PYTHON_VERSION"

chmod -R a+rX /opt/uv-python

# =========================================================
# 프로젝트 사용자
# =========================================================

echo "=== 5. 웹앱 사용자 설정 ==="

if ! id "$APP_USER" &>/dev/null; then
    useradd \
        --system \
        --shell /sbin/nologin \
        "$APP_USER"
fi

# =========================================================
# Git clone / update
# =========================================================

echo "=== 6. 프로젝트 다운로드 ==="

if [[ -d "$APP_DIR/.git" ]]; then

    echo "기존 프로젝트 발견"

    chown -R "$APP_USER:$APP_USER" "$APP_DIR"

    runuser -u "$APP_USER" -- \
        git -C "$APP_DIR" pull --ff-only

elif [[ -e "$APP_DIR" ]]; then

    echo "$APP_DIR 가 이미 존재하지만 Git 저장소가 아닙니다."
    exit 1

else

    git clone "$GIT_URL" "$APP_DIR"

fi

chown -R "$APP_USER:$APP_USER" "$APP_DIR"

# =========================================================
# 가상환경
# =========================================================

echo "=== 7. Python 가상환경 생성 ==="

cd "$APP_DIR"

rm -rf .venv

UV_PYTHON_INSTALL_DIR="/opt/uv-python" \
    /usr/local/bin/uv venv \
    --python "$PYTHON_VERSION" \
    --seed \
    .venv

# =========================================================
# requirements.txt
# =========================================================

echo "=== 8. Python 패키지 설치 ==="

./.venv/bin/python \
    -m pip install \
    -r requirements.txt

chown -R "$APP_USER:$APP_USER" "$APP_DIR"

echo
./.venv/bin/python --version

# =========================================================
# systemd
# =========================================================

echo "=== 9. FastAPI 서비스 등록 ==="

cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=${SERVICE_NAME} FastAPI Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple

User=${APP_USER}
Group=${APP_USER}

WorkingDirectory=${APP_DIR}

ExecStart=${APP_DIR}/.venv/bin/python -m uvicorn ${APP_MODULE} --host 127.0.0.1 --port ${APP_PORT}

Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}.service"
systemctl restart "${SERVICE_NAME}.service"

# =========================================================
# SELinux
# =========================================================

echo "=== 10. SELinux 설정 ==="

setsebool -P httpd_can_network_connect 1

# =========================================================
# Nginx
# =========================================================

echo "=== 11. Nginx 설정 ==="

cat > "/etc/nginx/conf.d/${SERVICE_NAME}.conf" <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name ${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:${APP_PORT};

        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

nginx -t

systemctl enable --now nginx
systemctl restart nginx

# =========================================================
# 서버 기동 대기
# =========================================================

echo "=== 12. 서버 확인 ==="

SUCCESS=0

for i in {1..15}; do

    if curl -fsS \
        "http://127.0.0.1:${APP_PORT}/health" \
        >/dev/null 2>&1
    then
        SUCCESS=1
        break
    fi

    sleep 1

done

echo
echo "========================================="

if [[ $SUCCESS -eq 1 ]]; then

    echo "설치 성공!"
    echo
    echo "웹 주소:"
    echo "http://${DOMAIN}"
    echo
    echo "FastAPI:"
    echo "http://127.0.0.1:${APP_PORT}"
    echo
    echo "서비스:"
    echo "${SERVICE_NAME}.service"

else

    echo "FastAPI 실행 실패"
    echo
    echo "아래 명령으로 로그 확인:"
    echo
    echo "systemctl status ${SERVICE_NAME} --no-pager -l"
    echo "journalctl -u ${SERVICE_NAME} -n 100 --no-pager"

fi

echo
echo "방화벽:"
firewall-cmd --list-ports

echo
echo "========================================="
