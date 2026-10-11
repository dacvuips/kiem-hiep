@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-mcp.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo Setup encountered an error.
    pause
    exit /b %ERRORLEVEL%
)
pause

