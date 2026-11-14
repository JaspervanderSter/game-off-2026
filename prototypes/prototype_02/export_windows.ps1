# Exports a Windows build with its sound effects beside the executable, where a
# sound designer can replace them without re-exporting (see README, "Sound effects").
#
#   .\export_windows.ps1 [-Godot <path to Godot_v4.x_console.exe>] [-Out <folder>]
#
# Produces <Out>\ShapeshiftersDuel.exe (with the game icon and version info),
# <Out>\sfx\<category>\<name>.ogg and .json, <Out>\music\music.json and
# <Out>-Windows.zip, which unpacks into a single ShapeshiftersDuel folder.
param(
	[string]$Godot = "",
	[string]$Out = ""
)

$ErrorActionPreference = "Stop"
$project = $PSScriptRoot
if (-not $Out) { $Out = Join-Path $project "..\..\export\ShapeshiftersDuel" }
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
New-Item -ItemType Directory -Force (Join-Path $Out "sfx"), (Join-Path $Out "music") | Out-Null

& $exe --headless --audio-driver Dummy --path $project --script res://tools/make_windows_icon.gd
if ($LASTEXITCODE -ne 0) { throw "Icon generation failed." }
& $exe --headless --audio-driver Dummy --path $project --import | Out-Null
& $exe --headless --audio-driver Dummy --path $project --export-release "Windows Desktop" (Join-Path $Out "ShapeshiftersDuel.exe")
if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $Out "ShapeshiftersDuel.exe"))) { throw "Godot export failed." }

# Sound files and their settings, keeping the category folders.
$sfx = Join-Path $project "sfx"
Get-ChildItem $sfx -Recurse -File -Include *.ogg, *.json | ForEach-Object {
	$target = Join-Path (Join-Path $Out "sfx") $_.FullName.Substring($sfx.Length + 1)
	New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
	Copy-Item $_.FullName $target
}
Copy-Item (Join-Path $project "music\music.json") (Join-Path $Out "music")
@"
Sound effects of Shapeshifters Duel

Sounds are sorted by category: interface, coins, combat, abilities,
shapeshift, duel. Each sound is two files with the same name:

  hit.ogg    the sound itself (OGG Vorbis)
  hit.json   how the game plays it

Edit a file, save it, then click back into the game window: changes apply
without restarting. A missing or unreadable file falls back to the version
built into the game. Keep the file names and folders.

Values in a sound's .json file:

  description       when the game plays the sound (for reading only)
  volume_db         loudness in decibels: 0 = as recorded, -6 = about half
  volume_jitter_db  random loudness change on each play, up to +/- this many dB
  pitch             1 = as recorded, 2 = one octave up. Pitch also changes
                    speed: a higher pitch plays shorter.
  pitch_jitter      random pitch change on each play, up to +/- this amount
                    (0.08 = up to 8 % higher or lower)
  pitch_step        pitch added for each step of a series (each harvest coin)
  cooldown_ms       the same sound repeated sooner than this is skipped
  variants          other uses of the same file with some values changed,
                    e.g. coin_gain's "harvest" and "compensation"

abilities\bard_song.ogg is a loop: it plays from its start while a bard sings
and fades out when none does. It can have any length.

At most 10 effects play at once.

..\music\music.json sets the music volume (volume_db), the fade time in
seconds (fade_seconds) and the battle music speed-up for each of the 5
frenzy levels (frenzy_speed_per_level: 0.05 = 5 % faster per level).
"@ | Set-Content -Encoding utf8 (Join-Path $Out "sfx\README.txt")

$zip = "$Out-Windows.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path $Out -DestinationPath $zip
Write-Host "Exported $Out and $zip"
