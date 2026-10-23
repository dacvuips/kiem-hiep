@echo off
cd /d "%~dp0"

echo ========================================================
echo       BUILD BAN WEB (HTML5 / WebAssembly) - JX1
echo ========================================================

set "GODOT_EXE=C:\Users\Hieu Tran\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"

if not exist "%GODOT_EXE%" (
    where godot >nul 2>&1
    if %errorlevel% equ 0 (
        set "GODOT_EXE=godot"
    ) else (
        echo [ERROR] Khong tim thay Godot tai: %GODOT_EXE%
        pause
        exit /b 1
    )
)

if not exist "build\web" mkdir "build\web"

:: Don dep cac file tam hoac pck cu de giai phong dung luong o dia
echo [*] Dang don dep bo nho dem va file tam...
if exist "build\web\*.tmp" del /f /q "build\web\*.tmp" >nul 2>&1
if exist "build\web\index.pck" del /f /q "build\web\index.pck" >nul 2>&1

echo [*] Dang xuat ban Web qua preset 'Web'...
echo [*] Vui long doi khoang 1-2 phut de dong goi toan bo tai nguyen...
echo.

"%GODOT_EXE%" --headless --export-release "Web" "build/web/index.html"

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Xuat ban that bai! Ma loi: %errorlevel%
    pause
    exit /b %errorlevel%
)

echo.
echo ========================================================
echo [OK] XUAT BAN THANH CONG!
echo Thuc muc dau ra: %cd%\build\web\
echo.
echo [*] De chay thu nghiem: Hay nhap dup file run_web.bat
echo ========================================================
echo.
pause
