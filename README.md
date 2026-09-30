# CDE 스튜디오 대여 현황

스튜디오 예약 현황 조회, 입실 처리, 엑셀·TXT 내보내기를 제공하는 웹 앱입니다.
실행 환경은 **Python 3.12.14**입니다.

## Windows 실행 (추천)

프로젝트 폴더의 **`서버시작.bat`를 더블클릭**하세요.

- 첫 실행: Python 3.12.14, `.venv`, 필요한 패키지를 자동으로 준비합니다. 인터넷이 필요하며 Python 사전 설치는 필요 없습니다.
- 준비 완료 후 서버를 켜고 브라우저를 엽니다. 이후에는 준비된 환경을 재사용합니다.
- 실행 창을 열어 두고 사용하세요. 종료는 `Ctrl+C` 또는 창 닫기로 합니다.

기존 `.venv`의 버전이 다르거나 실행되지 않으면 백업 후 새로 만듭니다.
다른 PC로 옮길 때는 `.venv`, `.venv.backup-*`, `.tools`를 제외한 프로젝트 전체를 복사하세요.

BAT 실행이 안 되면 프로젝트 폴더의 PowerShell에서 실행하세요.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\start-server.ps1
```

위 명령 끝에 `-SetupOnly`를 붙이면 환경 준비만 하고, `-Port 8001`을 붙이면 포트를 변경합니다.

## 수동 설치·개발 실행

Python과 `py` 명령이 이미 설치된 PC에서, 프로젝트 폴더의 PowerShell로 실행합니다.

```powershell
# uv 설치
py -m pip install --upgrade uv

# Python 3.12.14 가상환경 생성·활성화
py -m uv venv --python 3.12.14 --seed .venv
.\.venv\Scripts\Activate.ps1
python --version

# 패키지 설치·개발 서버 실행
python -m pip install -r requirements.txt
python -m uvicorn backend.main:app --reload --port 8000
```

브라우저에서 `http://127.0.0.1:8000`에 접속하세요. 서버 종료는 `Ctrl+C`입니다.

## 엑셀·TXT 내보내기

**엑셀·TXT 추출하기** 버튼으로 추출 창을 엽니다. 버튼에 마우스를 올리면 설명이 표시됩니다.

- 기간 지정 해제: 선택한 월 전체를 추출합니다.
- 기간 지정 체크: 시작일~종료일을 일 단위로 지정합니다. 양 끝 날짜를 포함합니다.
- 엑셀 또는 TXT 버튼: 선택한 기간의 예약완료 내역을 다운로드합니다.

## 주요 파일

- `backend/`: FastAPI 서버, 예약 데이터 조회, 파일 내보내기
- `frontend/templates/`: HTML 페이지·컴포넌트
- `frontend/static/`: 기능·컴포넌트별 CSS와 JavaScript
- `서버시작.bat`: Windows 더블클릭 실행
- `start-server.ps1`, `scripts/windows-bootstrap.ps1`: 자동 환경 준비·실행
- `run.py`: 서버 실행·브라우저 열기
- `requirements.txt`: 필요한 Python 패키지
