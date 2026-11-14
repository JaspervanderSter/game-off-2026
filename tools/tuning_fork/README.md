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

It starts on the **project window** and opens nothing by itself: click a game
folder (any folder holding `sfx/`) to open it. The window lists:

- **Recent**: the folders opened before, most recent first (at most 12). The
  `×` removes one from the list; the folder stays on disk. A folder that no
  longer holds `sfx/` is greyed out.
- **Found beside Tuning Fork**: the prototypes holding `sfx/` that are not
  already recent, newest first. The tool finds them by looking upward from
  its own folder (or the executable's, once exported), at most six levels, for
  a `prototypes/` folder.

Each folder shows its number of events. **Open a game folder** (or dropping a
folder on the window) opens any other one, such as the exported Windows build
(`export/ShapeshiftersDuel/`). Once a project is open, the folder button of
the top bar comes back to this window (after saving or discarding unsaved
changes); the back arrow or Esc returns to the open project. The tool
remembers the recent folders, the selected event of each and the auto-play
switch.

## Export

```powershell
.\tools\tuning_fork\export_windows.ps1
```

Writes `export/TuningFork/TuningFork.exe` at the repository root (ignored by
git): one executable with the fork icon, launched without Godot. Beside it
goes `Getting started.html`, a five-step guide for the sound designer kept in
[`guide/`](guide/Getting%20started.html); the rest is left to the tooltips.
Then the script zips the folder into `export/TuningFork-Windows.zip`, which
unpacks into a single `TuningFork` folder. The script
finds Godot like the game's export script (`-Godot <path>` or `$env:GODOT`
otherwise) and first regenerates `icon.ico` from `icon.svg` with
`tools/make_windows_icon.gd`. The script copies the repository's Windows x64
`oggenc.exe`, its source archives and licenses into the export. A checkout
with Godot and its Windows export templates can build the ZIP directly.
`-Oggenc <path>` can supply a compatible encoder for a custom build. Run from
anywhere inside the repository, the executable finds the prototypes by looking
upward from its folder; elsewhere, open the game folder once from the project
window and it stays among the recent ones.

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
  with oggenc (quality 5). An event with `files_from` shows the other
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
runtime's rules change, change them here too. `scripts/oggenc.gd` uses the
packaged encoder in the Windows export and the repository copy in Windows
editor runs. It also supports `$OGGENC` and compatible encoders on the PATH.
Music is the game's own system
and is not shown here.

## Tests

```bash
godot --headless --path tools/tuning_fork res://tests/run_tests.tscn
```

Checks that every event file and groups.json of the newest prototype is
written back unchanged; that the defaults, known keys, groups file, pick
modes, file numbering, file picking (same draws for the same random seed),
voice count and loop fade match the game's runtime; borrowed files
(`files_from`); the project window's search (the newest prototype first, only
folders holding `sfx/`), its event count and its recent list; waveform
measurement; number formatting; an edit-save-reload
cycle in a scratch folder (unknown keys kept, JSON created for an event
without one); numbered files grouped under their event, OGG files added, a WAV
file converted (when oggenc2 is found), and removals with renumbering; event
creation, renaming (files and `files_from` follow, empty folders removed) and
deletion; and group creation, renaming, removal and saving.

`-- --root=<game folder>` opens that folder without the project window.
`--select=<path>` starts on an event (or `--select=groups`).
`--screenshot=<file.png>` plays the selected event a few times muted, saves
the window and quits; without `--root` it saves the project window.
