@echo off
chcp 65001 >nul
title C盘清理工具

echo ═══════════════════════════════════════
echo     Windows C 盘清理工具
echo ═══════════════════════════════════════
echo.

:: 检查管理员权限
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ⚠️ 未以管理员身份运行，部分系统文件可能无法清理
    echo.
)

:: 确定脚本目录
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

:: 询问模式
echo 请选择清理模式：
echo   [1] 快速清理（仅临时文件/缓存，安全）
echo   [2] 深度清理（含应用缓存，如微信/QQ/剪映等）
echo   [3] 仅扫描分析（不清理）
echo.
set /p MODE="请输入选项 (1/2/3): "

if "%MODE%"=="3" (
    echo.
    echo 运行扫描分析...
    powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scan.ps1"
    echo.
    pause
    exit /b
)

if "%MODE%"=="2" (
    echo.
    echo ⚠️ 深度清理将删除应用缓存数据（微信/QQ/剪映/虎牙等）
    echo    聊天记录不会丢失，但可能需要重新登录和加载
    echo.
    set /p CONFIRM="确认执行深度清理？(y/N): "
    if /i "!CONFIRM!" neq "y" (
        echo 已取消
        pause
        exit /b
    )
    echo.
    echo 开始深度清理...
    powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%clean.ps1" -All
    goto :done
)

:: 默认：快速清理
echo.
echo 开始快速清理...
if "%MODE%"=="" set MODE=1
if "%MODE%"=="1" (
    powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%clean.ps1" -SafeOnly
)

:done
echo.
echo 按任意键退出...
pause >nul
