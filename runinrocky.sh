#!/bin/bash
set -Eeuo pipefail

PYTHON_VERSION="3.12.14"
APP_MODULE="backend.main:app"

echo "========================================="
echo " Rocky Linux FastAPI 웹서버 자동 설치"
echo "========================================="
echo

# --------------------------------------------------
# sudo 설정
# --------------------------------------------------

if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

# 실제 웹앱을 실행할 사용자 결정
if [[ $EUID -eq 0 ]]; then
    APP_USER="${SUDO_USER:-}"

    if [[ -z "$APP_USER" || "$APP_USER" == "root" ]]; then
        APP_USER="$(
            awk -F: '
                $3 >= 1000 &&
                $3 < 60000 &&
                $7 !~ /(nologin|false)$/ {
                    print $1
                    exit
                }
            ' /etc/passwd
        )"
    fi

    APP_USER="${APP_USER:-root}"
else
    APP_USER="$(id -un)"
fi

APP_GROUP="$(id -gn "$APP_USER")"
APP_HOME="$(getent passwd "$APP_USER" | cut -d: -f6)"

echo "웹앱 실행 사용자: $APP_USER"
echo "사용자 홈: $APP_HOME"
echo

# --------------------------------------------------
# 사용자 입력
# --------------------------------------------------

read -r -p \
"Git 주소 [https://github.com/k-dev178/cde_web.git]: " \
GIT_URL

GIT_URL="${GIT_URL:-https://github.com/k-dev178/cde_web.git}"

echo

while true; do
    read -r -p \
    "FastAPI 내부 포트 [8000]: " \
    APP_PORT

    APP_PORT="${APP_PORT:-8000}"

    if [[ "$APP_PORT" =~ ^[0-9]+$ ]] &&
       (( APP_PORT >= 1024 && APP_PORT <= 65535 )); then
        break
    fi

    echo "포트는 1024~65535 사이 숫자를 입력하세요."
done

echo

while true; do
    read -r -p \
    "사용할 도메인 [jjcde.duckdns.org]: " \
    DOMAIN

    DOMAIN="${DOMAIN:-jjcde.duckdns.org}"

    # http:// 또는 https:// 입력해도 제거
    DOMAIN="${DOMAIN#http://}"
    DOMAIN="${DOMAIN#https://}"
    DOMAIN="${DOMAIN%/}"

    if [[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]]; then
        break
    fi

    echo "도메인 형식이 잘못되었습니다."
done

# --------------------------------------------------
# Git 주소에서 프로젝트 이름 추출
# --------------------------------------------------

REPO_NAME="$(basename "${GIT_URL%.git}")"

SERVICE_NAME="$(echo "$REPO_NAME" | tr -cd 'A-Za-z0-9_.-')"

APP_DIR="$APP_HOME/$REPO_NAME"

echo
echo "========================================="
echo " 설정 확인"
echo "========================================="
echo "Git        : $GIT_URL"
echo "프로젝트   : $APP_DIR"
echo "사용자     : $APP_USER"
echo "Python     : $PYTHON_VERSION"
echo "내부 포트  : $APP_PORT"
echo "도메인     : $DOMAIN"
echo "========================================="
echo

# --------------------------------------------------
# Rocky Linux 필수 패키지 설치
# --------------------------------------------------

echo "=== 필수 패키지 설치 ==="

$SUDO dnf install -y \
    git \
    curl \
    ca-certificates \
    openssh-server \
    nginx \
    firewalld \
    policycoreutils

# --------------------------------------------------
# SSH
# --------------------------------------------------

echo
echo "=== SSH 서버 설정 ==="

$SUDO systemctl enable --now sshd

# --------------------------------------------------
# Firewalld
# --------------------------------------------------

echo
echo "=== 방화벽 설정 ==="

$SUDO systemctl enable --now firewalld

$SUDO firewall-cmd \
    --permanent \
    --add-port=22/tcp

$SUDO firewall-cmd \
    --permanent \
    --add-port=80/tcp

$SUDO firewall-cmd --reload

echo
echo "현재 열린 포트:"
$SUDO firewall-cmd --list-ports

# --------------------------------------------------
# uv 전역 설치
# --------------------------------------------------

echo
echo "=== uv 설치 ==="

if [[ ! -x /usr/local/bin/uv ]]; then

    curl -LsSf \
        https://astral.sh/uv/install.sh |
        $SUDO env \
        UV_INSTALL_DIR="/usr/local/bin" \
        UV_NO_MODIFY_PATH=1 \
        sh

fi

UV="/usr/local/bin/uv"

echo
echo "uv 버전:"
"$UV" --version

# --------------------------------------------------
# 사용자 권한으로 명령 실행 함수
# --------------------------------------------------

run_as_app_user() {

    if [[ "$(id -un)" == "$APP_USER" ]]; then

        env \
            HOME="$APP_HOME" \
            "$@"

    elif [[ $EUID -eq 0 ]]; then

        runuser \
            -u "$APP_USER" \
            -- \
            env \
            HOME="$APP_HOME" \
            "$@"

    else

        sudo \
            -u "$APP_USER" \
            -H \
            env \
            HOME="$APP_HOME" \
            "$@"

    fi
}

# --------------------------------------------------
# Git Clone
# --------------------------------------------------

echo
echo "=== Git 프로젝트 준비 ==="

if [[ -d "$APP_DIR/.git" ]]; then

    echo "기존 프로젝트 발견."
    echo "Git pull 실행..."

    $SUDO chown -R \
        "$APP_USER:$APP_GROUP" \
        "$APP_DIR"

    run_as_app_user \
        git \
        -C "$APP_DIR" \
        pull \
        --ff-only

elif [[ -e "$APP_DIR" ]]; then

    echo
    echo "오류:"
    echo "$APP_DIR"
    echo "폴더가 이미 존재하지만 Git 저장소가 아닙니다."
    exit 1

else

    run_as_app_user \
        git clone \
        "$GIT_URL" \
        "$APP_DIR"

fi

cd "$APP_DIR"

# --------------------------------------------------
# Python 3.12.14 설치
# --------------------------------------------------

echo
echo "=== Python $PYTHON_VERSION 설치 ==="

UV_PYTHON_DIR="$APP_HOME/.local/share/uv/python"

run_as_app_user \
    env \
    UV_PYTHON_INSTALL_DIR="$UV_PYTHON_DIR" \
    "$UV" \
    python install \
    "$PYTHON_VERSION"

# --------------------------------------------------
# 기존 가상환경 제거
# --------------------------------------------------

echo
echo "=== 기존 가상환경 정리 ==="

if [[ -d "$APP_DIR/.venv" ]]; then
    $SUDO rm -rf "$APP_DIR/.venv"
fi

# 프로젝트 권한 확보
$SUDO chown -R \
    "$APP_USER:$APP_GROUP" \
    "$APP_DIR"

# --------------------------------------------------
# 가상환경 생성
# --------------------------------------------------

echo
echo "=== Python 가상환경 생성 ==="

run_as_app_user \
    env \
    UV_PYTHON_INSTALL_DIR="$UV_PYTHON_DIR" \
    "$UV" \
    venv \
    --python "$PYTHON_VERSION" \
    --seed \
    "$APP_DIR/.venv"

# --------------------------------------------------
# requirements.txt
# --------------------------------------------------

echo
echo "=== Python 패키지 설치 ==="

run_as_app_user \
    "$APP_DIR/.venv/bin/python" \
    -m pip \
    install \
    -r "$APP_DIR/requirements.txt"

echo
echo "Python 버전:"

run_as_app_user \
    "$APP_DIR/.venv/bin/python" \
    --version

# --------------------------------------------------
# systemd 서비스
# --------------------------------------------------

echo
echo "=== FastAPI systemd 서비스 생성 ==="

$SUDO tee \
"/etc/systemd/system/${SERVICE_NAME}.service" \
>/dev/null <<EOF
[Unit]
Description=${REPO_NAME} FastAPI Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple

User=${APP_USER}
Group=${APP_GROUP}

WorkingDirectory=${APP_DIR}

Environment="HOME=${APP_HOME}"

ExecStart=${APP_DIR}/.venv/bin/python -m uvicorn ${APP_MODULE} --host 127.0.0.1 --port ${APP_PORT}

Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# --------------------------------------------------
# systemd 적용
# --------------------------------------------------

$SUDO systemctl daemon-reload

$SUDO systemctl enable \
    "${SERVICE_NAME}.service"

$SUDO systemctl restart \
    "${SERVICE_NAME}.service"

# --------------------------------------------------
# SELinux 설정
# --------------------------------------------------

echo
echo "=== SELinux Nginx 연결 허용 ==="

$SUDO setsebool \
    -P \
    httpd_can_network_connect \
    1

# --------------------------------------------------
# Nginx Reverse Proxy
# --------------------------------------------------

echo
echo "=== Nginx 설정 ==="

$SUDO tee \
"/etc/nginx/conf.d/${SERVICE_NAME}.conf" \
>/dev/null <<EOF
server {

    listen 80;
    listen [::]:80;

    server_name ${DOMAIN};

    location / {

        proxy_pass http://127.0.0.1:${APP_PORT};

        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;

        proxy_set_header \
            X-Forwarded-For \
            \$proxy_add_x_forwarded_for;

        proxy_set_header \
            X-Forwarded-Proto \
            \$scheme;
    }
}
EOF

# --------------------------------------------------
# Nginx 검사
# --------------------------------------------------

echo
echo "=== Nginx 설정 검사 ==="

$SUDO nginx -t

# --------------------------------------------------
# Nginx 시작
# --------------------------------------------------

$SUDO systemctl enable nginx
$SUDO systemctl restart nginx

# --------------------------------------------------
# FastAPI 서버 기동 대기
# --------------------------------------------------

echo
echo "=== FastAPI 서버 확인 ==="

SUCCESS=false

for i in {1..20}; do

    if curl \
        -fsS \
        "http://127.0.0.1:${APP_PORT}/health" \
        >/dev/null 2>&1
    then
        SUCCESS=true
        break
    fi

    sleep 1
done

# --------------------------------------------------
# 결과
# --------------------------------------------------

echo
echo
echo "========================================="
echo " 설치 결과"
echo "========================================="

if [[ "$SUCCESS" == true ]]; then

    echo "FastAPI : 정상"

else

    echo "FastAPI 상태 확인 필요"
    echo
    echo "확인 명령:"
    echo "systemctl status ${SERVICE_NAME}"

fi

echo
echo "프로젝트:"
echo "$APP_DIR"

echo
echo "서비스:"
echo "${SERVICE_NAME}.service"

echo
echo "내부 주소:"
echo "http://127.0.0.1:${APP_PORT}"

echo
echo "웹 주소:"
echo "http://${DOMAIN}"

echo
echo "열린 포트:"
$SUDO firewall-cmd --list-ports

echo
echo "========================================="
echo " 설치 완료"
echo "========================================="
