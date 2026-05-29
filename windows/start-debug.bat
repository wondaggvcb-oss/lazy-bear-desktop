@echo off
chcp 936 >nul
title Bear Debug Mode
cd /d "%~dp0"

echo ============================================
echo  Bear / Lazy Bear Desktop - Debug Mode
echo ============================================
echo.

echo [*] Checking Python...
python --version
if errorlevel 1 (
    echo [X] Python not found
    echo     Please install Python 3.7+
    pause
    exit /b 1
)
echo [OK] Python found
echo.

echo [*] Checking files...
if not exist "bear_app.py" (
    echo [X] bear_app.py not found
    pause
    exit /b 1
)
echo [OK] Files OK
echo.

echo [*] Checking assets...
if not exist "assets\*.gif" (
    echo [!] Warning: No .gif files in assets folder
    echo     Bear will show placeholder
echo.
) else (
    echo [OK] GIF files found
echo.
)

echo [*] Starting Bear...
echo [*] If Bear window appears, it is working
echo [*] This window will show exit code after Bear closes
echo ============================================
echo.

python bear_app.py
echo.
echo ============================================
echo Exit code: %errorlevel%
echo ============================================
pause
