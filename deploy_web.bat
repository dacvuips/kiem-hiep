@echo off
cd /d "%~dp0"
echo ========================================================
echo       DEPLOY BAN WEB LEN VPS (HTTPS CADDY)
echo ========================================================

if not exist "build\web\index.html" (
    echo [ERROR] Chua co file build\web\index.html!
    echo Hay chay build_web.bat truoc khi deploy.
    pause
    exit /b 1
)

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

echo [*] Dang dong goi va tai len VPS...
"%BASH_EXE%" -c "cd ../kiem-hiep-server && bash deploy/deploy.sh web"

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Deploy that bai! Vui long kiem tra log o tren.
    pause
    exit /b %errorlevel%
)

echo.
echo ========================================================
echo [OK] DEPLOY THANH CONG!
echo Truy cap game tai: https://play.viettheo.site
echo (Hoac: https://kiem-hiep-api.viettheo.site/web/)
echo ========================================================
echo.
pause
