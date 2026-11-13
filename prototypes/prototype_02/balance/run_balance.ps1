<#
.SYNOPSIS
  Runs the Prototype 02 balance suite (on demand only; not part of tests/).

.DESCRIPTION
  Launches a headless, silent Godot coordinator that runs every 1v1 duel in
  parallel worker processes and writes duels.csv, matchups.csv, ranking.csv
  and summary.json to balance/results/<timestamp>/.

.EXAMPLE
  ./run_balance.ps1
  ./run_balance.ps1 -Reps 20 -Workers 16
  ./run_balance.ps1 -Stars 0 -Forms peasant,guardian,archer
#>
param(
	[string]$Godot = "",
	[int]$Workers = 0,
	[int]$Reps = 10,
	[string]$Stars = "0,1,2,3",
	[string[]]$Forms = @("all"),
	[int]$Seed = 1,
	[string]$Out = "",
	[switch]$Import
)

$ErrorActionPreference = "Stop"
$project = Split-Path -Parent $PSScriptRoot

function Find-Godot {
	if ($Godot) { return $Godot }
	if ($env:GODOT) { return $env:GODOT }
	foreach ($name in @("godot", "godot4", "godot.exe")) {
		$cmd = Get-Command $name -ErrorAction SilentlyContinue
		if ($cmd) { return $cmd.Source }
	}
	$candidates = Get-ChildItem -Path "$env:USERPROFILE\Tools\Godot", "C:\Godot" -Filter "Godot_v4*_console.exe" -Recurse -Depth 1 -ErrorAction SilentlyContinue
	if ($candidates) { return ($candidates | Sort-Object Name -Descending | Select-Object -First 1).FullName }
	throw "Godot 4 not found. Pass -Godot <path to Godot_v4.x_console.exe> or set `$env:GODOT."
}

$exe = Find-Godot

# A fresh clone has no import cache; imported audio is needed by the Sfx autoload.
if ($Import -or -not (Test-Path (Join-Path $project ".godot/imported"))) {
	Write-Host "Importing project resources..."
	& $exe --headless --audio-driver Dummy --path $project --import | Out-Null
}

$userArgs = @(
	"--no-sound",
	"--workers=$Workers",
	"--reps=$Reps",
	"--stars=$Stars",
	"--forms=$($Forms -join ',')",
	"--seed=$Seed"
)
if ($Out) { $userArgs += "--out=$Out" }

& $exe --headless --audio-driver Dummy --path $project res://balance/balance.tscn -- @userArgs
exit $LASTEXITCODE
