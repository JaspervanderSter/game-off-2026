# Exports Tuning Fork for Windows x64.
#
#   .\export_windows.ps1 [-Godot <path to Godot_v4.x_console.exe>] [-Oggenc <path to oggenc2.exe>] [-Out <folder>]
#
# Produces <Out>\TuningFork.exe, by default export\TuningFork\ at the repository
# root, with the getting-started guide and the WAV encoder, then
# <Out>-Windows.zip, which unpacks into a single TuningFork folder.
param(
	[string]$Godot = "",
	[string]$Oggenc = "",
	[string]$Out = ""
)

$ErrorActionPreference = "Stop"
$project = $PSScriptRoot
if (-not $Out) { $Out = Join-Path $project "..\..\export\TuningFork" }
$Out = [System.IO.Path]::GetFullPath($Out)
$encoderFolder = Join-Path $project "vendor\oggenc"
$bundledEncoder = Join-Path $encoderFolder "oggenc.exe"
$encoderSources = Join-Path $encoderFolder "sources"
if (-not $Oggenc) { $Oggenc = $bundledEncoder }
if (-not (Test-Path -LiteralPath $Oggenc -PathType Leaf)) {
	throw "WAV encoder not found at $Oggenc."
}
$Oggenc = (Resolve-Path -LiteralPath $Oggenc).Path
$usingBundledEncoder = $Oggenc -eq $bundledEncoder
if ($usingBundledEncoder -and -not (Test-Path -LiteralPath $encoderSources -PathType Container)) {
	throw "Bundled encoder sources not found at $encoderSources."
}

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

Copy-Item -LiteralPath $Oggenc -Destination (Join-Path $Out "oggenc.exe") -Force
if ($usingBundledEncoder) {
	$packagedSources = Join-Path $Out "oggenc-sources"
	New-Item -ItemType Directory -Force $packagedSources | Out-Null
	Get-ChildItem -LiteralPath $encoderSources -File | Copy-Item -Destination $packagedSources -Force
}
Copy-Item (Join-Path $project "guide\Getting started.html") $Out -Force

$zip = "$Out-Windows.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path $Out -DestinationPath $zip
Write-Host "Exported $target and $zip"
