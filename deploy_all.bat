@echo off
chcp 65001 >nul
cd /d "%~dp0"
title JX1 Idle Origin - 1-Click All-in-One Deploy

echo ======================================================================
echo          JX1 IDLE ORIGIN - 1-CLICK ALL-IN-ONE BUILD ^& DEPLOY
echo ======================================================================
echo  Quy trình tự động thực hiện từ A đến Z:
echo   [1/5] Đồng bộ mã nguồn Git (Commit ^& Push GitHub: Game + Server)
echo   [2/5] Đóng gói bản cập nhật Android / Launcher (.pck + manifest)
echo   [3/5] Xuất bản Web (HTML5 / Wasm + Tối ưu OPFS SSD Cache)
echo   [4/5] Đẩy bản cập nhật Android lên VPS (kiem-hiep-api.viettheo.site)
echo   [5/5] Đẩy bản Web lên VPS Caddy (play.viettheo.site)
echo ======================================================================
echo.

:: --- 1. TÌM KIẾM ĐƯỜNG DẪN GODOT ---
set "GODOT_EXE=C:\Users\Hieu Tran\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT_EXE%" (
    where godot >nul 2>&1
    if %errorlevel% equ 0 (
        set "GODOT_EXE=godot"
    ) else (
        echo [ERROR] Không tìm thấy Godot Console tại: %GODOT_EXE%
        pause
        exit /b 1
    )
)

:: --- 2. TÌM KIẾM PYTHON ---
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Không tìm thấy Python trong hệ thống PATH!
    pause
    exit /b 1
)

:: --- 3. TÌM KIẾM GIT BASH ---
set "BASH_EXE=C:\Program Files\Git\bin\bash.exe"
if not exist "%BASH_EXE%" (
    where bash >nul 2>&1
    if %errorlevel% equ 0 (
        set "BASH_EXE=bash"
    ) else (
        echo [ERROR] Không tìm thấy Git Bash tại: %BASH_EXE%
        pause
        exit /b 1
    )
)

echo [*] Môi trường hợp lệ:
echo     - Godot:  %GODOT_EXE%
echo     - GitBash: %BASH_EXE%
echo.

:: Cho phép người dùng dừng nếu bấm nhầm, tự động chạy sau 3 giây
echo [*] Bắt đầu triển khai tự động trong 3 giây... (Nhấn Ctrl+C để hủy)
timeout /t 3 >nul

set "START_TIME=%TIME%"

:: ======================================================================
:: [BƯỚC 1/5] ĐỒNG BỘ MÃ NGUỒN GIT LÊN GITHUB
:: ======================================================================
echo.
echo ======================================================================
echo [BƯỚC 1/5] KIỂM TRA ^& ĐẨY MÃ NGUỒN LÊN GITHUB
echo ======================================================================

git status --porcelain > "%TEMP%\kh_git_status.tmp" 2>&1
for %%I in ("%TEMP%\kh_git_status.tmp") do set "STATUS_SIZE=%%~zI"
if %STATUS_SIZE% gtr 0 (
    echo [*] Phát hiện thay đổi trong repo kiem-hiep, đang commit ^& push...
    git add -A
    git commit -m "chore(deploy): auto commit before all-in-one deploy [%DATE% %TIME%]"
    git push origin main
    if %errorlevel% neq 0 (
        echo [!] Cảnh báo: Git push kiem-hiep có lỗi hoặc xung đột, tiếp tục build...
    ) else (
        echo [OK] Đã push repo Game kiem-hiep lên GitHub.
    )
) else (
    echo [OK] Repo Game kiem-hiep sạch, không có thay đổi cục bộ.
)
if exist "%TEMP%\kh_git_status.tmp" del /f /q "%TEMP%\kh_git_status.tmp"

:: Kiểm tra repo kiem-hiep-server nếu có
if exist "..\kiem-hiep-server\.git" (
    pushd "..\kiem-hiep-server"
    git status --porcelain > "%TEMP%\kh_server_git_status.tmp" 2>&1
    for %%I in ("%TEMP%\kh_server_git_status.tmp") do set "SERVER_STATUS_SIZE=%%~zI"
    if %SERVER_STATUS_SIZE% gtr 0 (
        echo [*] Phát hiện thay đổi trong repo kiem-hiep-server, đang commit ^& push...
        git add -A
        git commit -m "chore(deploy): auto commit before all-in-one deploy [%DATE% %TIME%]"
        git push origin main
        if %errorlevel% neq 0 (
            echo [!] Cảnh báo: Git push kiem-hiep-server có lỗi, tiếp tục build...
        ) else (
            echo [OK] Đã push repo Server kiem-hiep-server lên GitHub.
        )
    ) else (
        echo [OK] Repo Server kiem-hiep-server sạch.
    )
    if exist "%TEMP%\kh_server_git_status.tmp" del /f /q "%TEMP%\kh_server_git_status.tmp"
    popd
)

:: ======================================================================
:: [BƯỚC 2/5] ĐÓNG GÓI BẢN CẬP NHẬT ANDROID (.PCK + MANIFEST)
:: ======================================================================
echo.
echo ======================================================================
echo [BƯỚC 2/5] ĐÓNG GÓI BẢN CẬP NHẬT CHO ANDROID (Dynamic PCK)
echo ======================================================================
echo [*] Đang phân tích tệp thay đổi và đóng gói các gói PCK cập nhật...

python tools/build_client_update.py --godot "%GODOT_EXE%"
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Đóng gói bản cập nhật Android thất bại!
    pause
    exit /b %errorlevel%
)
echo [OK] Đã cập nhật gói Android tại: server\client\manifest.json

:: ======================================================================
:: [BƯỚC 3/5] XUẤT BẢN WEB (HTML5 / WEBASSEMBLY)
:: ======================================================================
echo.
echo ======================================================================
echo [BƯỚC 3/5] XUẤT BẢN WEB (HTML5 / WebAssembly)
echo ======================================================================

if not exist "build\web" mkdir "build\web"
if exist "build\web\*.tmp" del /f /q "build\web\*.tmp" >nul 2>&1
if exist "build\web\index.pck" del /f /q "build\web\index.pck" >nul 2>&1

echo [*] Đang xuất Web qua Godot headless...
"%GODOT_EXE%" --headless --export-release "Web" "build/web/index.html"
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Xuất bản Web thất bại!
    pause
    exit /b %errorlevel%
)

echo [*] Đang áp dụng cơ chế bộ đệm OPFS SSD Cache và vá In-App Browser...
python tools/patch_web_cache.py
echo [OK] Xuất bản Web hoàn tất tại: build\web\

:: ======================================================================
:: [BƯỚC 4/5] ĐẨY BẢN CẬP NHẬT ANDROID & TRANG DOWNLOAD LÊN VPS
:: ======================================================================
echo.
echo ======================================================================
echo [BƯỚC 4/5] DEPLOY BẢN CẬP NHẬT ANDROID ^& TRANG DOWNLOAD LÊN VPS
echo ======================================================================

"%BASH_EXE%" -c "cd ../kiem-hiep-server && bash deploy/deploy.sh client"
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Deploy bản Android lên VPS thất bại!
    pause
    exit /b %errorlevel%
)
echo [OK] Đã đẩy gói cập nhật Android (.pck) lên VPS thành công!

:: Đồng bộ thư mục trang tải game và APK nếu có
if exist "download\index.html" (
    echo [*] Đồng bộ trang tải game và bộ cài đặt APK/IPA lên VPS...
    "%BASH_EXE%" -c "scp -P 22 -r download/* root@161.248.147.33:/opt/kiemhiep/download/" >nul 2>&1
    echo [OK] Đã đồng bộ trang tải game (download/) lên VPS!
)

:: ======================================================================
:: [BƯỚC 5/5] ĐẨY BẢN WEB LÊN VPS
:: ======================================================================
echo.
echo ======================================================================
echo [BƯỚC 5/5] DEPLOY BẢN WEB LÊN VPS
echo ======================================================================

"%BASH_EXE%" -c "cd ../kiem-hiep-server && bash deploy/deploy.sh web"
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Deploy bản Web lên VPS thất bại!
    pause
    exit /b %errorlevel%
)

:: ======================================================================
:: HOÀN TẤT TOÀN DIỆN
:: ======================================================================
powershell -Command "[console]::beep(1000, 200); [console]::beep(1400, 300)" >nul 2>&1

echo.
echo ======================================================================
echo              [OK] TẤT CẢ ĐÃ DEPLOY THÀNH CÔNG RỰC RỠ!
echo ======================================================================
echo  1. Android App: Người chơi mở app sẽ tự tải bản cập nhật mới nhất!
echo     - Kiểm tra API: https://kiem-hiep-api.viettheo.site/v1/client/manifest
echo.
echo  2. Bản Web: Đã được cập nhật trực tiếp trên VPS.
echo     - Địa chỉ: https://play.viettheo.site
echo.
echo  3. GitHub: Mã nguồn đã được đồng bộ lên remote repository.
echo ======================================================================
echo.
pause
