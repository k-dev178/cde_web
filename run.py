#!/usr/bin/env python3
"""CDE 스튜디오 서버 실행기 — macOS / Windows 공통"""
import os
import sys
import time
import subprocess
import webbrowser
import socket
import urllib.request
import argparse
import json

PORT = 8000
HERE = os.path.dirname(os.path.abspath(__file__))


def port_in_use(port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(1)
        return s.connect_ex(("127.0.0.1", port)) == 0


def server_is_ready(url: str) -> bool:
    try:
        with urllib.request.urlopen(f"{url}/health", timeout=1) as response:
            health = json.load(response)
        return health == {"app": "cde-studio", "status": "ok"}
    except (OSError, ValueError):
        return False


def wait_ready(url: str, timeout: int = 20, process=None) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if process is not None and process.poll() is not None:
            return False
        if server_is_ready(url):
            return True
        time.sleep(0.2)
    return False


def stop_server(process):
    if process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()


def main():
    parser = argparse.ArgumentParser(description="CDE 스튜디오 서버 실행기")
    parser.add_argument("--port", type=int, default=PORT)
    parser.add_argument("--no-browser", action="store_true")
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error("포트는 1~65535 사이여야 합니다.")
    url = f"http://127.0.0.1:{args.port}"
    os.chdir(HERE)

    if port_in_use(args.port):
        if not wait_ready(url, timeout=3):
            print(f"포트 {args.port}를 다른 프로그램이 사용 중입니다. 다른 포트를 지정해 주세요.")
            return 1
        print(f"CDE 서버가 이미 실행 중입니다 → {url}")
        if not args.no_browser:
            webbrowser.open(url)
        return 0

    print(f"서버를 시작합니다 (포트 {args.port})...", flush=True)

    proc = subprocess.Popen(
        [sys.executable, "-m", "uvicorn", "backend.main:app", "--host", "127.0.0.1", "--port", str(args.port)],
        cwd=HERE,
    )

    try:
        if not wait_ready(url, process=proc):
            print("서버 시작에 실패했습니다. 위 오류 메시지를 확인해 주세요.")
            return 1
        print(f"서버 준비 완료 → {url}", flush=True)
        if not args.no_browser:
            webbrowser.open(url)

        print("서버 실행 중... 종료하려면 Ctrl+C 또는 이 창을 닫으세요.", flush=True)
        proc.wait()
        return proc.returncode
    except KeyboardInterrupt:
        print("\n서버를 종료합니다.")
        return 0
    finally:
        stop_server(proc)


if __name__ == "__main__":
    sys.exit(main())
