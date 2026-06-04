@echo off
chcp 65001 >nul
title 熊

set "HERE=%~dp0"
set "APP_DIR=%HERE%"
if exist "%HERE%app\bear_windows.py" set "APP_DIR=%HERE%app\"
set "SCRIPT=%APP_DIR%bear_windows.py"

if not exist "%SCRIPT%" (
    echo.
    echo 熊打不开：找不到 bear_windows.py。
    echo 请确认压缩包已经完整解压，不要只拖出一个文件运行。
    echo.
    pause
    exit /b 1
)

call :choose_python
if errorlevel 1 exit /b 1
if not defined BEAR_EXE goto no_python

pushd "%APP_DIR%" >nul
if defined BEARW_EXE (
    start "" "%BEARW_EXE%" "%SCRIPT%"
) else (
    start "熊" "%BEAR_EXE%" "%SCRIPT%"
)
popd >nul
exit /b 0

:choose_python
where py >nul 2>nul
if not errorlevel 1 (
    py -3 -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 8) else 1)" >nul 2>nul
    if not errorlevel 1 (
        for /f "usebackq delims=" %%P in (`py -3 -c "import sys; print(sys.executable)"`) do set "BEAR_EXE=%%P"
        call :set_pythonw
        exit /b 0
    )
)

where python >nul 2>nul
if not errorlevel 1 (
    python -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 8) else 1)" >nul 2>nul
    if not errorlevel 1 (
        for /f "usebackq delims=" %%P in (`python -c "import sys; print(sys.executable)"`) do set "BEAR_EXE=%%P"
        call :set_pythonw
        exit /b 0
    )
    goto old_python
)

goto no_python

:set_pythonw
for %%F in ("%BEAR_EXE%") do set "BEARW_EXE=%%~dpFpythonw.exe"
if not exist "%BEARW_EXE%" set "BEARW_EXE="
exit /b 0

:old_python
echo.
echo 熊打不开：这台电脑的 Python 太旧了。
echo 请安装 Python 3.10 或更新版本，然后重新双击这个文件。
echo.
echo 下载地址：
echo https://www.python.org/downloads/windows/
echo.
echo 安装时记得勾选 Add python.exe to PATH。
echo 如果你看到 Python 3.2.2 和 ^>^>^>，就是这个问题。
echo.
pause
exit /b 1

:no_python
echo.
echo 熊打不开：这台电脑还没有可用的 Python 3。
echo 请先安装 Python 3.10 或更新版本。
echo.
echo 下载地址：
echo https://www.python.org/downloads/windows/
echo.
echo 安装时记得勾选 Add python.exe to PATH。
echo 装好以后，回来双击这个启动文件就行。
echo.
pause
exit /b 1
