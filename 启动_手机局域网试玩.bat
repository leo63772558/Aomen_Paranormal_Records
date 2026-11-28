@echo off
chcp 65001 >nul
cd /d "%~dp0"
start "" http://127.0.0.1:8068/qr
python tools\serve_mobile_playtest.py --port 8068
pause
