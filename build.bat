@echo off
setlocal
cd /d "%~dp0helm"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0helm\build.ps1" -Target %1
endlocal

