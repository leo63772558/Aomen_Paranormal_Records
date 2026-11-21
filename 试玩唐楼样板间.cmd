@echo off
cd /d "%~dp0"
start "" "%~dp0tools\engine\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." res://levels/ch0_tanglau/sample_room.tscn -- --profile=playtest --run-id=manual_sample
