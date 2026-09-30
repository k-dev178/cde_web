#!/usr/bin/env python3
"""CDE 스튜디오 서버 실행기 — macOS / Windows 공통"""
import os
import sys
import time
import subprocess
import webbrowser
import socket
import urllib.request

PORT = 8000
URL  = f"http://localhost:{PORT}"
HERE = os.path.dirname(os.path.abspath(__file__))


def port_in_use(port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(("localhost", port)) == 0


def wait_ready(url: str, timeout: int = 15) -> bool:
    for _ in range(timeout * 2):
        try:
            urllib.request.urlopen(url, timeout=1)
            return True
        except Exception:
            time.sleep(0.5)
    return False


def main():
    os.chdir(HERE)

    if port_in_use(PORT):
        print(f"서버가 이미 실행 중입니다. 브라우저를 엽니다 → {URL}")
        webbrowser.open(URL)
        return

    print(f"서버를 시작합니다 (포트 {PORT})...")

    proc = subprocess.Popen(
        [sys.executable, "-m", "uvicorn", "backend.main:app", "--port", str(PORT)],
        cwd=HERE,
    )

    if not wait_ready(URL):
        print("서버 시작에 실패했습니다.")
        proc.terminate()
        sys.exit(1)

    print(f"서버 준비 완료 → {URL}")
    webbrowser.open(URL)

    print("서버 실행 중... 종료하려면 Ctrl+C 또는 이 창을 닫으세요.")
    try:
        proc.wait()
    except KeyboardInterrupt:
        print("\n서버를 종료합니다.")
        proc.terminate()
        proc.wait()


if __name__ == "__main__":
    main()
