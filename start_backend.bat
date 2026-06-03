@echo off
title Face Recognition Attendance API
cd /d "%~dp0"

echo.
echo ============================================================
echo   Face Recognition Attendance API - Startup
echo ============================================================
echo.

REM Get local IP for display
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4"') do set "IP=%%a"
set "IP=%IP: =%"

echo Local access:    http://127.0.0.1:8000
echo Network access:  http://%IP%:8000
echo API docs:        http://127.0.0.1:8000/docs
echo.
echo For Flutter (Android emulator): http://10.0.2.2:8000
echo For Flutter (real device):      http://%IP%:8000
echo.
echo ============================================================
echo.

python run_backend.py
if errorlevel 1 (
    echo.
    echo Failed to start the server.
    echo Make sure dependencies are installed: pip install -r backend/requirements.txt
    pause
)
