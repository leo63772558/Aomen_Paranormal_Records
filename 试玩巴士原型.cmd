@echo off
cd /d "%~dp0"
start "" "%~dp0tools\engine\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." res://levels/ch4_bus/bus_loop.tscn -- --profile=playtest --run-id=bus_prototype_manual
