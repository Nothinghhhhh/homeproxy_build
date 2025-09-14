@echo off
chcp 65001 >nul
title HomeProxy IPK 一键构建工具

echo.
echo ████████████████████████████████████████████████
echo █                                              █
echo █     HomeProxy IPK 一键构建工具               █
echo █     适用于 aarch64 软路由设备               █
echo █                                              █
echo ████████████████████████████████████████████████
echo.

echo [INFO] 检查PowerShell环境...
powershell -Command "if ($PSVersionTable.PSVersion.Major -lt 5) { Write-Host '需要PowerShell 5.0或更高版本' -ForegroundColor Red; exit 1 } else { Write-Host 'PowerShell版本检查通过' -ForegroundColor Green }"
if errorlevel 1 (
    echo [ERROR] PowerShell版本过低
    pause
    exit /b 1
)

echo.
echo [INFO] 启动构建脚本...
echo.

REM 运行PowerShell构建脚本
powershell -ExecutionPolicy Bypass -File "simple-docker-build.ps1"

if errorlevel 1 (
    echo.
    echo [ERROR] 构建过程中出现错误
    pause
    exit /b 1
)

echo.
echo [SUCCESS] 构建完成！
echo.
echo 按任意键退出...
pause >nul
