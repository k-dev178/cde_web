#!/bin/bash
set -Eeuo pipefail

# =========================================================
# Rocky Linux FastAPI 원클릭 배포
# - git clone 이후 프로젝트 폴더에서 실행
# =========================================================

if [[ $EUID -ne 0 ]]; then
    echo "root에서 실행하세요."
    echo "sudo ./runinrocky.sh"
    exit 1
fi

DEFAULT_PORT="8000"
DEFAULT_DOMAIN="jjcde.duckdns.org"

PYTHON_VERSION="3.12.14"
APP_MODULE="backend.main:app"
APP_USER="webapp"

# 이 스크립트가 위치한 프로젝트 폴더
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_NAME="$(basename "$APP_DIR")"
SERVICE_NAME="$REPO_NAME"

echo "========================================="
echo " Rocky Linux FastAPI 원클릭 배포"
echo "========================================="
echo

echo "프로젝트 위치:"
echo "$APP_DIR"
echo

# =========================================================
# 사용자 입력
# =========================================================

read -rp "FastAPI 내부 포트 [$DEFAULT_PORT]: " APP_PORT
APP_PORT="${APP_PORT:-$DEFAULT_PORT}"

read -rp "도메인 [$DEFAULT_DOMAIN]: " DOMAIN
DOMAIN="${DOMAIN:-$DEFAULT_DOMAIN}"

DOMAIN="${DOMAIN#http://}"
DOMAIN="${DOMAIN#https://}"
DOMAIN="${DOMAIN%/}"

echo
echo "========================================="
echo "설치 위치 : $APP_DIR"
echo "서비스명  : $SERVICE_NAME"
echo "포트      : $APP_PORT"
echo "도메인    : $DOMAIN"
echo "========================================="
echo

# =========================================================
# 1. 필요한 패키지
# =========================================================

echo "=== 1. 필수 패키지 설치 ==="

dnf install -y \
    curl \
    ca-certificates \
    openssh-server \
    nginx \
    firewalld \
    policycoreutils

# =========================================================
# 2. SSH / Firewall
# =========================================================

echo
echo "=== 2. SSH / 방화벽 설정 ==="

systemctl enable --now sshd
systemctl enable --now firewalld

firewall-cmd --permanent --add-port=22/tcp
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --reload

# =========================================================
# 3. uv
# =========================================================

echo
echo "=== 3. uv 설치 ==="

if [[ ! -x /usr/local/bin/uv ]]; then
    curl -LsSf https://astral.sh/uv/install.sh | \
        env \
        UV_INSTALL_DIR=/usr/local/bin \
        UV_NO_MODIFY_PATH=1 \
        sh
fi

/usr/local/bin/uv --version

# =========================================================
# 4. Python
# =========================================================

echo
echo "=== 4. Python $PYTHON_VERSION 설치 ==="

mkdir -p /opt/uv-python

export UV_PYTHON_INSTALL_DIR="/opt/uv-python"

/usr/local/bin/uv python install "$PYTHON_VERSION"

chmod -R a+rX /opt/uv-python

# =========================================================
# 5. 서비스용 사용자
# =========================================================

echo
echo "=== 5. 웹앱 사용자 준비 ==="

if ! id "$APP_USER" &>/dev/null; then
    useradd \
        --system \
        --shell /sbin/nologin \
        "$APP_USER"
fi

# =========================================================
# 6. 가상환경
# =========================================================

echo
echo "=== 6. Python 가상환경 생성 ==="

cd "$APP_DIR"

# 기존 서비스가 있다면 먼저 중지
systemctl stop "${SERVICE_NAME}.service" 2>/dev/null || true

rm -rf .venv

UV_PYTHON_INSTALL_DIR="/opt/uv-python" \
    /usr/local/bin/uv venv \
    --python "$PYTHON_VERSION" \
    --seed \
    .venv

# =========================================================
# 7. requirements
# =========================================================

echo
echo "=== 7. Python 패키지 설치 ==="

./.venv/bin/python \
    -m pip install \
    -r requirements.txt

echo
echo "Python:"
./.venv/bin/python --version

echo
echo "Uvicorn:"
./.venv/bin/python -m uvicorn --version

# webapp 사용자가 읽고 실행할 수 있게 설정
chmod -R a+rX "$APP_DIR"

# =========================================================
# 8. systemd
# =========================================================

echo
echo "=== 8. FastAPI 서비스 등록 ==="

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
# 9. SELinux
# =========================================================

echo
echo "=== 9. SELinux 설정 ==="

setsebool -P httpd_can_network_connect 1

# =========================================================
# 10. Nginx
# =========================================================

echo
echo "=== 10. Nginx 설정 ==="

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
# 11. 서버 확인
# =========================================================

echo
echo "=== 11. FastAPI 서버 확인 ==="

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
    echo "웹:"
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
    echo "상태 확인:"
    echo "systemctl status ${SERVICE_NAME} --no-pager -l"
    echo
    echo "로그 확인:"
    echo "journalctl -u ${SERVICE_NAME} -n 100 --no-pager"

fi

echo
echo "열린 방화벽 포트:"
firewall-cmd --list-ports

echo
echo "========================================="
