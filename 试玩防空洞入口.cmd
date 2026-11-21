@echo off
cd /d "%~dp0"
start "" "%~dp0tools\engine\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." res://levels/ch2_guia/hill_shelter_014.tscn -- --profile=test --run-id=bunker_preview
