# Tuning Fork

A small sound tool for games, much simpler than Wwise or FMOD. The sound
designer creates and tunes sound events here; the game plays them by path,
`Sfx.play("combat/hit")`, through the runtime addon. No more opening JSON
files by hand.

What Tuning Fork is, and why, is defined in [`docs/`](docs/Home.md), a set of
linked notes (open the folder as an Obsidian vault). Where this README and the
definition differ, [`docs/Gaps.md`](docs/Gaps.md) lists the gap.

## Run

Open `tools/tuning_fork/project.godot` in Godot 4.7 and press F5.

It opens the newest prototype that has an `sfx/` folder (today
`prototypes/prototype_02`). The folder button opens another game folder: any
folder holding `sfx/`, such as the exported Windows build
(`export/ShapeshiftersDuel/`). The tool remembers the last folder, the
selected event and the auto-play switch.

## Export

```powershell
.\tools\tuning_fork\export_windows.ps1
```

Writes `export/TuningFork/TuningFork.exe` at the repository root (ignored by
git): one executable with the fork icon, launched without Godot. The script
finds Godot like the game's export script (`-Godot <path>` or `$env:GODOT`
otherwise) and first regenerates `icon.ico` from `icon.svg` with
`tools/make_windows_icon.gd`. It also copies `oggenc2.exe` (about 2 MB) beside
the executable, so the tool converts dropped WAV files on any machine. Get
oggenc2 once from <https://www.rarewares.org/ogg-oggenc.php> (the x64 build)
and put it in `%USERPROFILE%\Tools\oggenc\`; the script also takes
`-Oggenc <path>`, `$env:OGGENC` or one on the PATH. Run from
anywhere inside the repository, the executable finds the prototypes by looking
upward from its folder; elsewhere, open the game folder once with the folder
button and it is remembered.

## What it does

- **List**: events by folder (folders nest), then **Groups**. `×N` follows
  an event with several files, `↪` one that plays another event's files. The
  filter box narrows the list by path. Unsaved events show `●` in amber; an
  event with a problem (unknown key or value, no file, unknown group,
  unreadable OGG) shows in orange.
- **Events**: the `+` button beside the filter creates an event from a
  folder, a name and a description; its JSON file is written at once. The
  pencil renames or moves the selected event with its files (the game's code
  must then play the new path; events whose `files_from` names it follow).
  The bin moves the event and its files to the recycle bin, unless another
  event plays its files.
- **Files**: the top of the event shows one card per file (`hit.ogg`,
  `hit_2.ogg`...) with its waveform and length. Click a waveform or its play
  button to hear that file; the card of the file that played last is outlined
  and shows a playhead. The bin button moves a file to the recycle bin after a
  confirmation, and the files after it are renumbered. WAV or OGG files
  dropped on the window (or chosen from the `+` card) become the event's next
  numbered files at once: OGG files are copied, WAV files converted to OGG
  with oggenc2 (quality 5). An event with `files_from` shows the other
  event's files and a link to it, and takes no files of its own.
- **Edit**: `group`, `files_from` and `pick` are choices, `loop` and
  `protected` switches, and `volume_db`, `volume_jitter_db`, `pitch`,
  `pitch_jitter`, `cooldown_ms` and `shuffle_refill_after` a slider and a
  number box each; plus the description and a reset arrow back to the
  game's default. Hover a value name for its meaning. Values that do not
  apply (refill without shuffle, variation and repeat delay of a loop) are
  greyed out.
- **Groups**: the last entry of the list shows each group with its volume
  and its number of events. Add a group, rename one (its events follow and
  are saved, unless they have other unsaved changes) or remove an unused one.
- **Play**: Play (or Space, or double-click in the list) plays one file,
  picked as the game picks it, with the random variation, the repeat delay
  and the group's volume. A looping event loops until Stop (Esc). The chart
  shows where the last plays landed: pitch across, volume up, the random
  range as a box.
- **Auto-play** (speaker switch, top right): replays the event a moment after
  each change, so dragging a slider and letting go is enough to hear it.
- **Save**: the save button or Ctrl+S saves the open event or the groups,
  the bottom-right button or Ctrl+Shift+S saves all. The revert arrow reloads
  the file on disk. Files are written in the game's layout (tabs, fixed key
  order, unknown keys kept), so an unchanged file stays byte for byte the
  same. An event without a JSON file gets one on its first save. Closing or
  changing folder with unsaved changes asks to save or discard them.
- **Files changed elsewhere** reload by themselves within a second: a replaced
  OGG, a JSON edited in another editor, an event added or removed. If that
  JSON also has unsaved changes here, the tool warns and keeps your version
  until you save or revert.

The running game picks up everything saved here when its window regains focus:
settings, groups, sound files and new events. That holds for a game run from
the Godot editor (F5), which reads `sfx/` from disk, and for an exported
Windows build with Tuning Fork opened on its folder.

## Keeping it in sync with the game

The playback rules are a copy of the game's runtime addon,
`addons/tuning_fork/sfx.gd` (`Sfx`): `scripts/sound_library.gd` holds the
defaults, the known keys, the file numbering and the event and group files,
and `scripts/sound_player.gd` the playback and file picking. When the
runtime's rules change, change them here too. `scripts/oggenc.gd` looks for
oggenc2 beside the exported executable, then in the places the export script
checks, so editor runs convert WAV files too. Music is the game's own system
and is not shown here.

## Tests

```bash
godot --headless --path tools/tuning_fork res://tests/run_tests.tscn
```

Checks that every event file and groups.json of the newest prototype is
written back unchanged; that the defaults, known keys, groups file, pick
modes, file numbering, file picking (same draws for the same random seed),
voice count and loop fade match the game's runtime; borrowed files
(`files_from`); waveform measurement; number formatting; an edit-save-reload
cycle in a scratch folder (unknown keys kept, JSON created for an event
without one); numbered files grouped under their event, OGG files added, a WAV
file converted (when oggenc2 is found), and removals with renumbering; event
creation, renaming (files and `files_from` follow, empty folders removed) and
deletion; and group creation, renaming, removal and saving.

`-- --select=<path> --screenshot=<file.png>` starts on an event (or
`--select=groups`), plays it a few times muted, saves the window and quits.
