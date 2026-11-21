@echo off
chcp 65001 >nul
title 澳诡实录 (调试控制台) - Aomen Paranormal Records
echo 正在启动《澳诡实录》（控制台模式）...
cd /d "%~dp0"
"tools\engine\Godot_v4.7.2-stable_win64_console.exe" --path .
pause
