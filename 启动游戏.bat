@echo off
chcp 65001 >nul
setlocal
title 火影世界 - 启动

rem 所有路径相对本脚本（%~dp0 = 工程根）。
set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"

rem Godot：优先 本机配置.ini 的 Godot=，其次环境变量 NARUTO_GODOT，最后 PATH 中的 godot。
set "GODOT="
if exist "%PROJECT%\本机配置.ini" (
    for /f "usebackq tokens=1,* delims==" %%A in ("%PROJECT%\本机配置.ini") do (
        if /i "%%A"=="Godot" set "GODOT=%%~B"
    )
)
if not defined GODOT set "GODOT=%NARUTO_GODOT%"
if not defined GODOT set "GODOT=godot"
if not exist "%GODOT%" (
    where "%GODOT%" >nul 2>&1
    if errorlevel 1 (
        echo [错误] 找不到 Godot。
        echo        复制 本机配置.example.ini 为 本机配置.ini，把 Godot= 改成你的路径；
        echo        或设置环境变量 NARUTO_GODOT 指向 Godot_v4.7.x_console.exe；
        echo        或把 godot 加入 PATH。
        pause
        exit /b 2
    )
)
echo      Godot = %GODOT%

set "PYTHON=%PROJECT%\运行时\python\python.exe"
set "FIXTURE=%PROJECT%\开发工具\本地服务端夹具.py"
set "FIXROOT=%PROJECT%\.fixture-play"
set "GMPORT=18680"

rem 已经在 18684 上监听就复用，避免重启清空存档。
netstat -ano | findstr ":18684" | findstr "LISTENING" >nul 2>&1
if not errorlevel 1 (
    echo [1/2] 本地服务端已在 18684 运行，直接复用。
    goto launch
)

if not exist "%PYTHON%" (
    echo [错误] 找不到 %PYTHON%
    echo        请把 Python 3.13 embeddable 解压到 运行时\python\。
    pause
    exit /b 2
)
echo [1/2] 启动本地服务端...
start "火影世界 - 本地服务端 + GM" "%PYTHON%" "%FIXTURE%" --root "%FIXROOT%" --state-out "%FIXROOT%/state.json" --no-peers --gm-http %GMPORT%

set /a n=0
:wait
set /a n+=1
timeout /t 1 /nobreak >nul
netstat -ano | findstr ":18684" | findstr "LISTENING" >nul 2>&1
if not errorlevel 1 goto ready
if %n% lss 30 goto wait
echo      等待 30 秒仍未就绪，将继续启动客户端；此时界面可能显示离线默认值。
goto launch

:ready
echo      本地服务端已就绪。

:launch
echo      GM 控制台：http://127.0.0.1:%GMPORT%/gm/index.html
echo [2/2] 启动游戏...
"%GODOT%" --path "%PROJECT%" --maximized %NARUTO_EXTRA%
echo.
echo 游戏已退出。本地服务端窗口可以关闭。
timeout /t 6 /nobreak >nul
