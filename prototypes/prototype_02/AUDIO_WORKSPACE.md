# Windows audio workspace

The game always starts with its original audio. **Ctrl+Shift+M** opens the
Default / Cobiora dialog on Windows only; Escape closes it. Switching audio
does not restart the duel. The choice is deliberately not saved. Web exports
have no selector and do not include the alternate tracks or SFX workspace.

Open this game folder in Tuning Fork. It needs neither Godot nor game source.

## Music

The Music tab discovers every OGG/WAV under `music/`, recursively. A track's
settings are in the adjacent JSON with the same basename. A track without a
sidecar appears too; Save creates its JSON. Other JSON files appear as editable
project configurations. Unknown settings are preserved. New files appear while
the tool is open. Use **Replace audio** or overwrite a file in your audio editor;
the running Windows game reloads the alternate workspace when it regains focus.

`music/alternate.json` maps the game's `prep`, `battle` and `ambience` roles to
paths relative to `music/`, plus `sfx_directory` relative to the game folder.
These bindings belong to this game, not to Tuning Fork. Changing them does not
affect default playback. Select this configuration in the tool to preview its
phase transitions using the track settings.

| Track setting | Meaning |
| --- | --- |
| `volume_db` | Track level, in dB |
| `fade_seconds` | Full fade duration in seconds; must be positive |
| `loop` | Repeat the whole track or chosen segment |
| `playback_mode` | `continuous`, `restart`, or `segments` |
| `duck_db` | Preparation volume reduction during battle; -40 is very quiet |
| `frenzy_speed_per_level` | Battle speed increase per frenzy level; 0 keeps pitch unchanged |
| `segments` | Regions with `start_seconds` and `end_seconds`, picked on each phase entry |

Continuous preparation keeps advancing behind combat at the reduced volume,
then returns at its new position. Restart begins at zero on each phase entry.
Segments mode chooses a region without immediately repeating the previous one;
`loop` controls whether that region repeats. Define regions before selecting
segments mode. All regions must fit inside the audio file.

### Complete world map reference

`music/Cobiora/world_map_cycle.ogg` is a complete baked mix of the existing
procedural ambience. It is **160 seconds**, beginning in day, golden mist at
40 s, dusk at 80 s, night at 120 s and day again at 160 s. These are the sky
palette anchors; the transitions blend between them. Replace this entire
recording freely: its individual birds, winds and timing are not constraints.

The alternate mode replaces the procedural ambience with this recording. It
aligns playback to the sky clock when entering the map and stops outside it.
A replacement of a different length is fitted to the visual cycle by playback
speed, so use a 160-second file to keep the intended musical speed and pitch.
The live procedural system is untouched in Default and Web.

The reference is reproducible with `python tools/bake_map_cycle.py` from the
repository (Python, numpy, ffmpeg). It uses the existing generated OGG sounds,
the sky weights, random-call rates and gaps, a fixed seed, circular call tails
and a boundary splice. Fixed 6 dB storage headroom plus -8 dB sidecar volume
matches the procedural mix's -14 dB level; it is not peak-normalized.

## SFX and generated sounds

In SFX, choose **sfx_cobiora** to edit the alternate workspace. Its initial
files are baked copies of the current sound events. `sfx` remains the original
workspace and `sfx_legacy` the older comparison set. A file saved in
`sfx_cobiora` affects only the alternate mode. Settings and recordings reload
when the game regains focus; no build is needed. The current SFX are already
recordings, so no runtime synthesizer is replaced to expose them.

For procedural systems, keep their live implementation as the fallback and
offer a baked replacement in the alternate workspace. The world map demonstrates
both paths: the default generator and the editable full-cycle recording. Adding
a future synthesizer requires its own bake function; Tuning Fork does not infer
or modify synthesis code.

## Collaboration

For Git, share changes to `music/Cobiora/`, `music/alternate.json` and
`sfx_cobiora/`. Do not edit `music/music.json` or `sfx/` when experimenting with
the alternate mode: those are the original game's settings. Builds contain
these same plain files beside the executable, so sharing those folders also
works without a source checkout.
