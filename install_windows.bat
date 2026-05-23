@echo off
echo ========================================
echo Face Recognition Attendance System
echo Windows Installation Script
echo ========================================
echo.

echo Installing Python dependencies...
pip install -r requirements_simple.txt

if %errorlevel% neq 0 (
    echo Error: Failed to install dependencies
    echo Please make sure Python is installed and in your PATH
    pause
    exit /b 1
)

echo.
echo Dependencies installed successfully!
echo.
echo Installation complete!
echo To run the application, use: python app_simple.py
echo The system will be available at: http://localhost:5000
echo.

pause 