# Exports a Windows build with its sound effects beside the executable, where a
# sound designer can replace them without re-exporting (see README, "Sound effects").
#
#   .\export_windows.ps1 [-Godot <path to Godot_v4.x_console.exe>] [-Out <folder>]
#
# Produces <Out>\SHIFT.exe (with the game icon and version info), <Out>\sfx\*.ogg
# and <Out>-Windows.zip, which unpacks into a single SHIFT folder.
param(
	[string]$Godot = "",
	[string]$Out = ""
)

$ErrorActionPreference = "Stop"
$project = $PSScriptRoot
if (-not $Out) { $Out = Join-Path $project "..\..\export\SHIFT" }
$Out = [System.IO.Path]::GetFullPath($Out)

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
if (Test-Path $Out) { Remove-Item -Recurse -Force $Out }
New-Item -ItemType Directory -Force (Join-Path $Out "sfx") | Out-Null

& $exe --headless --audio-driver Dummy --path $project --script res://tools/make_windows_icon.gd
if ($LASTEXITCODE -ne 0) { throw "Icon generation failed." }
& $exe --headless --audio-driver Dummy --path $project --import | Out-Null
& $exe --headless --audio-driver Dummy --path $project --export-release "Windows Desktop" (Join-Path $Out "SHIFT.exe")
if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $Out "SHIFT.exe"))) { throw "Godot export failed." }

Copy-Item (Join-Path $project "sfx\*.ogg") (Join-Path $Out "sfx")
@"
Sound effects of SHIFT

Each .ogg file in this folder replaces the game sound of the same name.
Keep the file names, and use OGG Vorbis. Edit a file, save it, then click
back into the game window: changed sounds reload without restarting.
A missing or unreadable file falls back to the sound built into the game.
"@ | Set-Content -Encoding utf8 (Join-Path $Out "sfx\README.txt")

$zip = "$Out-Windows.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path $Out -DestinationPath $zip
Write-Host "Exported $Out and $zip"
