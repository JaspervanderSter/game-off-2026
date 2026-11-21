# Exports a Windows build with its sound effects beside the executable, where a
# sound designer can replace them without re-exporting (see README, "Sound effects").
#
#   .\export_windows.ps1 [-Godot <path to Godot_v4.x_console.exe>] [-Out <folder>]
#
# Produces <Out>\ShapeshiftersDuel.exe (with the game icon and version info),
# <Out>\sfx\ (every sound event's .json and .ogg files, groups.json),
# <Out>\music\music.json and
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
	$candidates = Get-ChildItem -Path "$env:USERPROFILE\Tools\Godot", "C:\Godot*" -Filter "Godot_v4*_console.exe" -Recurse -Depth 1 -ErrorAction SilentlyContinue
	if ($candidates) {
		return ($candidates | Sort-Object { [version]($_.BaseName -replace '^Godot_v([\d.]+).*', '$1') } -Descending | Select-Object -First 1).FullName
	}
	throw "Godot 4 not found. Pass -Godot <path to Godot_v4.x_console.exe> or set `$env:GODOT."
}

$exe = Find-Godot
if (Test-Path $Out) { Remove-Item -Recurse -Force $Out }
New-Item -ItemType Directory -Force (Join-Path $Out "sfx"), (Join-Path $Out "music") | Out-Null

& $exe --headless --audio-driver Dummy --path $project --script res://tools/make_windows_icon.gd
if ($LASTEXITCODE -ne 0) { throw "Icon generation failed." }
& $exe --headless --audio-driver Dummy --path $project --import | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Godot import failed. Check the errors above." }
& $exe --headless --audio-driver Dummy --path $project --export-release "Windows Desktop" (Join-Path $Out "ShapeshiftersDuel.exe")
if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $Out "ShapeshiftersDuel.exe"))) { throw "Godot export failed." }

# Sound events, their files and groups.json, keeping the folders.
$sfx = Join-Path $project "sfx"
Get-ChildItem $sfx -Recurse -File -Include *.ogg, *.json | ForEach-Object {
	$target = Join-Path (Join-Path $Out "sfx") $_.FullName.Substring($sfx.Length + 1)
	New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
	Copy-Item $_.FullName $target
}
Copy-Item (Join-Path $project "music\music.json") (Join-Path $Out "music")
@"
Sound effects of Shapeshifters Duel

Each sound is an event, sorted in folders: ui, coins, combat, abilities,
shapeshift, duel. The game plays an event by its path, such as combat/hit:

  combat\hit.json   how the game plays it
  combat\hit.ogg    the sound itself (OGG Vorbis)
  combat\hit_2.ogg  more takes, numbered from 2 (optional); each play picks
  combat\hit_3.ogg  one of them

Edit a file, save it, then click back into the game window: changes apply
without restarting. The sound files of an event here replace all its built-in
files; once none is left, the built-in ones play again. An unreadable settings
file keeps the current values. Keep the file names and folders. The Tuning
Fork tool edits these files for you.

Values in an event's .json file:

  description       when the game plays the event (for reading only)
  group             mixing group, listed in groups.json: "effects" or "ui"
  loop              true: plays until the game stops it
  protected         true: plays on a voice of its own, never cut by others
  files_from        plays the files of this other event, such as
                    "coins/harvest/1", with its own settings
  volume_db         loudness in decibels: 0 = as recorded, -6 = about half
  volume_jitter_db  random loudness change on each play, up to +/- this many dB
  pitch             1 = as recorded, 2 = one octave up. Pitch also changes
                    speed: a higher pitch plays shorter.
  pitch_jitter      random pitch change on each play, up to +/- this amount
                    (0.08 = up to 8 % higher or lower)
  cooldown_ms       the same event repeated sooner than this is skipped
  pick              how each play chooses a file: "shuffle" plays every file
                    once in a random order before any repeats; "random" draws
                    any file each time
  shuffle_refill_after
                    shuffle only: deal the files again after this many plays
                    (0 = after all of them)

groups.json sets the volume of each group in decibels (volume_db).

abilities\bard_song is a loop: it plays from its start while a bard sings
and fades out when none does. It can have any length. coins\harvest\1 to 8
are the coins of a harvest, each higher; 2 to 8 play the file of 1.

At most 10 effects play at once, plus looping and protected events.

..\music\music.json sets the music volume (volume_db), the fade time in
seconds (fade_seconds) and the battle music speed-up for each of the 5
frenzy levels (frenzy_speed_per_level: 0.05 = 5 % faster per level). It also sets the
loudness of the world map's nature ambience (ambience_volume_db) and its fade
time when the map shows or hides (ambience_fade_seconds).
"@ | Set-Content -Encoding utf8 (Join-Path $Out "sfx\README.txt")

$zip = "$Out-Windows.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path $Out -DestinationPath $zip
Write-Host "Exported $Out and $zip"
