@echo off
chcp 65001 >nul
title 澳诡实录 - Aomen Paranormal Records
echo 正在启动《澳诡实录》...
cd /d "%~dp0"
start "" "tools\engine\Godot_v4.7.2-stable_win64.exe" --path .
exit
