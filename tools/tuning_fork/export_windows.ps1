# Exports Tuning Fork as a single Windows executable.
#
#   .\export_windows.ps1 [-Godot <path to Godot_v4.x_console.exe>] [-Oggenc <path to oggenc2.exe>] [-Out <folder>]
#
# Produces <Out>\TuningFork.exe, by default export\TuningFork\ at the repository
# root, with "Getting started.html" (from guide\) and a copy of oggenc2.exe
# beside it so the tool converts dropped WAV files on any machine; then
# <Out>-Windows.zip, which unpacks into a single TuningFork folder. oggenc2 (about 2 MB) comes from
# https://www.rarewares.org/ogg-oggenc.php; unless given, the script looks for it
# in %USERPROFILE%\Tools\oggenc\, then $env:OGGENC, then the PATH. Launched from
# there, the tool finds the repository's prototypes by itself.
param(
	[string]$Godot = "",
	[string]$Oggenc = "",
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

if (-not $Oggenc) {
	$found = @((Join-Path $env:USERPROFILE "Tools\oggenc\oggenc2.exe"), $env:OGGENC) | Where-Object { $_ -and (Test-Path $_) }
	if ($found) { $Oggenc = @($found)[0] }
	else {
		$cmd = Get-Command oggenc2, oggenc -ErrorAction SilentlyContinue | Select-Object -First 1
		if ($cmd) { $Oggenc = $cmd.Source }
	}
}
if ($Oggenc -and (Test-Path $Oggenc)) {
	Copy-Item $Oggenc (Join-Path $Out "oggenc2.exe") -Force
	Write-Host "Copied oggenc2 from $Oggenc"
} else {
	Write-Warning "oggenc2 not found: the exported tool adds OGG files only. Get it from https://www.rarewares.org/ogg-oggenc.php and pass -Oggenc <path to oggenc2.exe>."
}
Copy-Item (Join-Path $project "guide\Getting started.html") $Out -Force

$zip = "$Out-Windows.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path $Out -DestinationPath $zip
Write-Host "Exported $target and $zip"
