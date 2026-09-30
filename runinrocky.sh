#!/bin/bash
set -e

# 현재 스크립트가 있는 프로젝트 폴더로 이동
cd "$(dirname "$0")"

# uv 실행파일 경로
export PATH="$HOME/.local/bin:$PATH"

# uv가 없으면 공식 설치 방식으로 설치
if ! command -v uv >/dev/null 2>&1; then
    echo "uv 설치 중..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

echo "uv 버전:"
uv --version

# 기존 잘못 만들어진 가상환경 삭제
rm -rf .venv

# Python 3.12.14 설치
uv python install 3.12.14

# Python 3.12.14 가상환경 생성
uv venv --python 3.12.14 --seed .venv

# 가상환경 활성화
source .venv/bin/activate

echo "사용 중인 Python:"
python --version

echo "Python 위치:"
which python

# 패키지 설치
python -m pip install -r requirements.txt

# FastAPI 서버 실행
exec python -m uvicorn backend.main:app \
    --reload \
    --host 0.0.0.0 \
    --port 8000
