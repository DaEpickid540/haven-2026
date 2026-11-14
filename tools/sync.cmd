@echo off
rem Double-click this to safely get the latest code from GitHub.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync.ps1" %*
echo.
pause
