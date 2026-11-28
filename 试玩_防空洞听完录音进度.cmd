@echo off
chcp 65001 >nul
title 澳诡实录 - 防空洞听完录音进度
echo 正在从最新工程启动《澳诡实录》（防空洞听完录音进度）...
cd /d "%~dp0"
start "" "tools\engine\Godot_v4.7.2-stable_win64.exe" --path . -- --profile=playtest --run-id=bunker_after_tape
exit
