@echo off
setlocal
cd /d "%~dp0"

echo Fetching feedback from Supabase...
powershell -NoProfile -ExecutionPolicy Bypass -File "fetch_feedback.ps1" -Open

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Script encountered an error.
    pause
)
