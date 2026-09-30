@echo off
setlocal
chcp 65001 >nul
title CDE Studio Server
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-server.ps1" %*
set "CDE_EXIT_CODE=%ERRORLEVEL%"
if not "%CDE_EXIT_CODE%"=="0" (
  echo.
  echo CDE Studio could not start. See the message above.
  pause
)
exit /b %CDE_EXIT_CODE%
