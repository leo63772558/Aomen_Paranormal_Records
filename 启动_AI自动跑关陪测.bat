@echo off
cd /d "%~dp0"
start "AomenGuidedPlaytest" "tools\engine\Godot_v4.7.2-stable_win64.exe" --path . -- --profile=playtest --run-id=guided_watch --guided-playtest
