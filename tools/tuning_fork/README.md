# Tuning Fork

A small Godot 4.7 tool for working on a prototype's sounds: it lists every
sound, plays it the way the game plays it, edits its JSON settings live and
saves them back beside the sound. No more opening JSON files by hand.

## Run

Open `tools/tuning_fork/project.godot` in Godot 4.7 and press F5.

It opens the newest prototype that has an `sfx/` folder (today
`prototypes/prototype_02`). The folder button opens another game folder: any
folder holding `sfx/<category>/<name>.ogg|json` and `music/music.json`, such as
the exported Windows build (`export/ShapeshiftersDuel/`). The tool remembers
the last folder, the selected sound and the auto-play switch.

## Export

```powershell
.\tools\tuning_fork\export_windows.ps1
```

Writes `export/TuningFork/TuningFork.exe` at the repository root (ignored by
git): one executable with the fork icon, launched without Godot. The script
finds Godot like the game's export script (`-Godot <path>` or `$env:GODOT`
otherwise) and first regenerates `icon.ico` from `icon.svg` with
`tools/make_windows_icon.gd`. Run from anywhere inside the repository, the
executable finds the prototypes by looking upward from its folder; elsewhere,
open the game folder once with the folder button and it is remembered.

## What it does

- **List**: effects grouped by category folder, then the music settings. The
  filter box narrows the list. Unsaved sounds show `●` in amber; a sound with a
  settings problem (unknown key, missing or unreadable OGG) shows in orange.
- **Edit**: one slider and number box per value (`volume_db`,
  `volume_jitter_db`, `pitch`, `pitch_jitter`, `pitch_step`, `melody`,
  `cooldown_ms`), the description, and the reset arrow back to the game's
  default. Hover a value name for its meaning. Number boxes accept values beyond
  the slider range.
- **Variants**: one tab for the sound and one per variant (`:harvest`). In a
  variant, the check box beside a value sets it in the variant; unchecked values
  come from the sound and show greyed. `+` adds a variant, `−` removes the open
  one.
- **Play**: Play (or Space, or double-click in the list) plays the sound with
  the open tab's values, including the random variation, the step's
  `pitch_step` and melody note, and the repeat delay. The series button plays
  several steps from the step box at the chosen interval (harvest coins rising,
  the bard melody); the loop button repeats it until Stop (Esc). The chart shows
  where the last plays landed: pitch across, volume up, the random range as a box.
- **Auto-play** (speaker switch, top right): replays the sound a moment after
  each change, so dragging a slider and letting go is enough to hear it.
- **Music**: the music entry plays each track with the game's smooth fades,
  at `volume_db`, with `fade_seconds`; the frenzy slider applies the speed-up of
  each level. Changes apply while the track plays. Music keeps playing while
  another sound is selected, to hear effects over it.
- **Save**: the save button or Ctrl+S saves the open sound, the bottom-right
  button or Ctrl+Shift+S saves all. The revert arrow reloads the file on disk.
  Files are written in the game's layout (tabs, fixed key order, unknown keys
  kept), so an unchanged file stays byte for byte the same. A sound without a
  JSON file gets one on its first save. Closing or changing folder with unsaved
  changes asks to save or discard them.
- **Files changed elsewhere** reload by themselves within a second: a replaced
  OGG, or a JSON edited in another editor. If that JSON also has unsaved changes
  here, the tool warns and keeps your version until you save or revert.

The running game picks up saved values when its window regains focus: keep
the game running from the Godot editor (F5), save in Tuning Fork, click back
into the game, and the next play uses the new values. This covers JSON
settings only; a replaced OGG needs a restart from the editor, which imports
it. An exported Windows build does the same with the `sfx/` and `music/` files
beside its executable, OGG files included, when Tuning Fork is opened on the
export folder.

## Keeping it in sync with the game

The playback rules are a copy of the game's `scripts/audio/sfx.gd` (`Sfx`) and
`scripts/audio/phase_music.gd`: `scripts/sound_library.gd` holds the defaults
and the known keys, `scripts/sound_player.gd` the effect playback and
`scripts/music_preview.gd` the music fades. When the game's rules change, change
them here too. The game speeds up only the battle track with frenzy; the tool
applies the speed-up to whichever track plays. The tool lists every OGG and JSON
it finds; the game only plays the sounds listed in `Sfx.SOUNDS`.

## Tests

```bash
godot --headless --path tools/tuning_fork res://tests/run_tests.tscn
```

Checks that every settings file of the newest prototype is written back
unchanged, that the defaults, known keys and voice count match the game's
`sfx.gd`, the pitch of steps, melody and variants, number formatting, and an
edit-save-reload cycle in a scratch folder (unknown keys kept, new variant,
JSON created for a sound without one).

`-- --select=coin_gain:harvest --screenshot=<file.png>` starts on a sound and
variant, plays a muted series, saves the window and quits.
