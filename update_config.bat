@echo off
cd /d "%~dp0"
echo ========================================================
echo       CAP NHAT CAU HINH CADDY LEN VPS (KHONG UP FILE)
echo ========================================================

set "BASH_EXE=C:\Program Files\Git\bin\bash.exe"
if not exist "%BASH_EXE%" (
    where bash >nul 2>&1
    if %errorlevel% equ 0 (
        set "BASH_EXE=bash"
    ) else (
        echo [ERROR] Khong tim thay Git Bash tai: %BASH_EXE%
        pause
        exit /b 1
    )
)

echo [*] Dang day cau hinh Caddyfile moi len VPS va reload...
"%BASH_EXE%" -c "cd ../kiem-hiep-server && bash deploy/deploy.sh config"

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Cap nhat that bai! Vui long kiem tra log.
    pause
    exit /b %errorlevel%
)

echo.
echo ========================================================
echo [OK] CAP NHAT THANH CONG!
echo ========================================================
echo.
pause
