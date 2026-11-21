@echo off
cd /d "%~dp0"
for /f %%i in ('powershell -NoProfile -Command "[guid]::NewGuid().ToString('N')"') do set "RUN_ID=fresh_%%i"
if not defined RUN_ID exit /b 1
start "" "%~dp0tools\engine\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." -- --profile=playtest --run-id=%RUN_ID%
