# CDE 스튜디오 대여 현황

CDE 스튜디오 예약 현황을 보여주는 웹 앱입니다.

## 프로젝트 구조

```text
cde_web/
├── backend/
│   ├── __init__.py
│   └── main.py
├── frontend/
│   ├── templates/
│   │   ├── base.html
│   │   ├── index.html
│   │   └── components/
│   │       ├── _header.html
│   │       ├── _reservation_panel.html
│   │       └── reservations/
│   └── static/
│       ├── css/
│       │   ├── base.css
│       │   └── components/
│       └── js/
│           ├── app.js
│           ├── components/
│           └── features/
├── run.py
├── requirements.txt
└── README.md
```

- `backend`: FastAPI 라우팅, 외부 예약 데이터 조회, 파일 내보내기
- `frontend/templates`: 페이지 레이아웃과 화면 컴포넌트
- `frontend/static/css`: 기본 스타일과 컴포넌트별 스타일
- `frontend/static/js`: 진입점, 공용 컴포넌트, 기능별 모듈

## 실행 전 준비

개발 및 실행 환경은 **Python 3.12.14**로 맞춥니다.

> 1단계

```powershell
py -m pip install --upgrade uv
```
Python 버전과 가상환경을 관리하는 **uv를 설치하거나 업데이트**합니다.

> 2단계

```powershell
py -m uv venv --python 3.12.14 --seed .venv
```
**Python 3.12.14로 `.venv` 가상환경을 생성**합니다. 해당 버전이 없으면 다운로드하고, `--seed`로 pip도 설치합니다.

> 3단계

```powershell
.\.venv\Scripts\Activate.ps1
```
현재 PowerShell에서 **가상환경을 활성화**합니다. 이후 `python` 명령은 이 환경의 Python을 사용합니다.

> 4단계

```powershell
python --version
```
사용 중인 Python 버전을 확인합니다. **Python 3.12.14**가 출력되어야 합니다.

> 5단계

```powershell
python -m pip install -r requirements.txt
```
프로젝트에 필요한 패키지를 **활성화된 가상환경에 설치**합니다.

> 종합

```powershell
py -m pip install --upgrade uv
py -m uv venv --python 3.12.14 --seed .venv
.\.venv\Scripts\Activate.ps1

python --version

python -m pip install -r requirements.txt
```


## 실행

가상환경이 활성화된 터미널에서 실행합니다. 새 터미널을 열었다면 프로젝트 폴더에서 3단계의 활성화 명령을 다시 실행합니다.

> 6단계

```powershell
python -m uvicorn backend.main:app --reload --port 8000
```
**웹 서버를 실행**합니다. `backend.main:app`은 `backend/main.py`의 FastAPI 앱을 지정하고, `--reload`는 코드 변경 시 서버를 자동으로 재시작하며, `--port 8000`은 접속 포트를 지정합니다.

> 7단계

브라우저에서 `http://localhost:8000`에 접속해 **예약 현황 화면을 확인**합니다.

> 종료

서버가 실행 중인 터미널에서 `Ctrl+C`를 눌러 **서버를 종료**합니다.

```powershell
deactivate
```
**가상환경을 비활성화**합니다. `.venv` 폴더와 설치된 패키지는 유지됩니다.

## 기능

| 기능 | 설명 |
|---|---|
| 예약 목록 | 오늘 날짜 예약 현황 자동 표시 |
| 자동 갱신 | 30초마다 최신 데이터로 갱신 |
| 입실 처리 | 입실 버튼 클릭으로 토글 |
| 미입실 알림 | 예약 시작 20분 후 미입실 시 브라우저 알림 |
| 엑셀 다운로드 | 월별 일별 예약 내역 `.xlsx` 다운로드 |

## 엑셀 다운로드

- 헤더의 월 선택 후 **엑셀 다운로드** 클릭
- URL 직접 호출: `/export?year=2026&month=4`
