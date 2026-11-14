# Tool

The Tuning Fork application: a standalone program for the sound designer,
exported for Windows, that needs neither Godot nor the game's code.

## What it does

- **Opens a game folder** and lists its [[Event|events]] by folder, with a
  filter.
- **Creates events**: a folder, a name ([[Event path]]) and a description.
  The event exists at once, even before the game uses it ([[Workflow]]).
  Renames, moves and deletes them too, warning that the game's code must
  follow a rename.
- **Manages [[Sound files|files]]**: one card per file with its waveform;
  drop WAV or OGG files to add takes; move a file to the recycle bin.
- **Edits [[Settings|settings]]**: a slider and a number per value, a choice
  for `pick`, `group` and `loop`, a reset to the default.
- **Edits [[Groups|groups]]** and their volumes.
- **Plays** an event the way the game does ([[Playback]]): file picking,
  jitter, cooldown, loop.
- **Saves** to the [[File format]], which the running game picks up
  ([[Hot reload]]).

## Helping people learn

Only what helps hear and understand a sound ([[Principles]]):

- a tooltip on every setting;
- the waveform of each file and a playhead;
- a small chart of where the last plays landed in pitch and volume.

No tutorials, wizards or guided tours.
