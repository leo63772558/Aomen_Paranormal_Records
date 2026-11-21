$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engine = Join-Path $PSScriptRoot 'engine/Godot_v4.7.2-stable_win64_console.exe'
& $engine --headless --audio-driver Dummy --path $projectRoot --fixed-fps 60 -- --autobot --profile=test --run-id=sample_001
exit $LASTEXITCODE
