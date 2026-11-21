@echo off
cd /d "%~dp0"
start "" "%~dp0tools\engine\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." -- --profile=playtest --run-id=opening_manual
