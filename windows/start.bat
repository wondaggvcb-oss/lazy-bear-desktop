@echo off
chcp 936 >nul
cd /d "%~dp0"

:: Check Python
python --version >nul 2>&1
if errorlevel 1 (
    msg * "[Error] Python not found. Please install Python 3.7+"
    exit /b 1
)

:: Start Bear
timeout /t 1 /nobreak >nul
start "" pythonw bear_app.py

if errorlevel 1 (
    start "" python bear_app.py
)
