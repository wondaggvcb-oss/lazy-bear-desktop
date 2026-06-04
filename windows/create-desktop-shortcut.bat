@echo off
chcp 65001 >nul
title 创建熊快捷方式

set "HERE=%~dp0"
set "TARGET=%HERE%start-bear.bat"
if exist "%HERE%启动熊.bat" set "TARGET=%HERE%启动熊.bat"

set "WORKDIR=%HERE%"
set "ICON=%HERE%Resources\BearIcon.ico"
if exist "%HERE%app\Resources\BearIcon.ico" set "ICON=%HERE%app\Resources\BearIcon.ico"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$shell=New-Object -ComObject WScript.Shell; $desktop=[Environment]::GetFolderPath('Desktop'); $shortcut=$shell.CreateShortcut((Join-Path $desktop '熊.lnk')); $shortcut.TargetPath=$env:TARGET; $shortcut.WorkingDirectory=$env:WORKDIR; if (Test-Path $env:ICON) { $shortcut.IconLocation=$env:ICON }; $shortcut.Save()"

if errorlevel 1 (
    echo.
    echo 快捷方式没有创建成功。没关系，直接双击“启动熊.bat”也可以。
    echo.
    pause
    exit /b 1
)

echo.
echo 已经在桌面创建“熊”快捷方式。
echo 以后可以直接从桌面打开。
echo.
pause
