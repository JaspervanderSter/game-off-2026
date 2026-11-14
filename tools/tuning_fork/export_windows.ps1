# Exports Tuning Fork as a single Windows executable.
#
#   .\export_windows.ps1 [-Godot <path to Godot_v4.x_console.exe>] [-Out <folder>]
#
# Produces <Out>\TuningFork.exe, by default export\TuningFork\ at the repository
# root. Launched from there, the tool finds the repository's prototypes by itself.
param(
	[string]$Godot = "",
	[string]$Out = ""
)

$ErrorActionPreference = "Stop"
$project = $PSScriptRoot
if (-not $Out) { $Out = Join-Path $project "..\..\export\TuningFork" }
$Out = [System.IO.Path]::GetFullPath($Out)

function Find-Godot {
	if ($Godot) { return $Godot }
	if ($env:GODOT) { return $env:GODOT }
	foreach ($name in @("godot", "godot4", "godot.exe")) {
		$cmd = Get-Command $name -ErrorAction SilentlyContinue
		if ($cmd) { return $cmd.Source }
	}
	$candidates = Get-ChildItem -Path "$env:USERPROFILE\Tools\Godot", "C:\Godot*" -Filter "Godot_v4*_console.exe" -Recurse -Depth 1 -ErrorAction SilentlyContinue
	if ($candidates) { return ($candidates | Sort-Object Name -Descending | Select-Object -First 1).FullName }
	throw "Godot 4 not found. Pass -Godot <path to Godot_v4.x_console.exe> or set `$env:GODOT."
}

$exe = Find-Godot
New-Item -ItemType Directory -Force $Out | Out-Null
$target = Join-Path $Out "TuningFork.exe"
if (Test-Path $target) { Remove-Item -Force $target }

& $exe --headless --audio-driver Dummy --path $project --script res://tools/make_windows_icon.gd
if ($LASTEXITCODE -ne 0) { throw "Icon generation failed." }
& $exe --headless --audio-driver Dummy --path $project --import | Out-Null
& $exe --headless --audio-driver Dummy --path $project --export-release "Windows Desktop" $target
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $target)) { throw "Godot export failed." }
Write-Host "Exported $target"
