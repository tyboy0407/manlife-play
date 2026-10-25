# ManLife headless tests: imports the project, then runs every res://tests/verify_*.tscn in name order.
# Usage: powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 [-NoImport]
# Each test scene prints OK / FAIL lines and quits with exit code 0 (pass) or 1 (fail).
# Set $env:GODOT to point at a different Godot console executable.
param([switch]$NoImport)
$godot = $env:GODOT
if (-not $godot) {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $godot = Join-Path $desktop "Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
}
if (-not (Test-Path $godot)) { Write-Host "Godot not found: $godot (set env GODOT)"; exit 2 }
$proj = Split-Path -Parent $PSScriptRoot
if (-not $NoImport) {
    & $godot --headless --path $proj --import | Out-Null
}
$testDir = Join-Path $proj "tests"
$scenes = @()
if (Test-Path $testDir) {
    $scenes = Get-ChildItem $testDir -Filter "verify_*.tscn" | Sort-Object Name
}
if ($scenes.Count -eq 0) { Write-Host "No tests yet (tests/verify_*.tscn)"; exit 0 }
$failed = 0
foreach ($scene in $scenes) {
    & $godot --headless --path $proj ("res://tests/" + $scene.Name)
    if ($LASTEXITCODE -ne 0) { $failed = 1; Write-Host "FAILED: $($scene.Name)" }
}
if ($failed -ne 0) { Write-Host "TESTS FAILED"; exit 1 }
Write-Host "ALL TESTS PASSED"
exit 0
