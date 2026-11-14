# Tool

The Tuning Fork application: a standalone program for the sound designer,
exported for Windows, that needs neither Godot nor the game's code.

## What it does

- **Opens a game folder** and lists its [[Event|events]] by folder, with a
  filter. The list ends with the [[Groups|groups]].
- **Creates events** with the `+` button: a folder, a name ([[Event path]])
  and a description. The event exists at once, even before the game uses it
  ([[Workflow]]). The pencil renames or moves an event, warning that the
  game's code must follow; events that take its files follow by themselves.
  The bin moves an event and its files to the recycle bin, unless another
  event plays its files.
- **Manages [[Sound files|files]]**: one card per file with its waveform;
  drop WAV or OGG files to add takes; move a file to the recycle bin. An
  event that plays another event's files shows them, with a link to that
  event.
- **Edits [[Settings|settings]]**: a slider and a number per value, a choice
  for `group`, `files_from` and `pick`, a switch for `loop` and `protected`,
  a reset to the default.
- **Edits [[Groups|groups]]**: add, rename (their events follow) and remove
  unused groups, and tune their volumes.
- **Plays** an event the way the game does ([[Playback]]): file picking,
  jitter, cooldown, group volume; a looping event loops until Stop.
- **Saves** to the [[File format]], which the running game picks up
  ([[Hot reload]]). Files changed by another program reload by themselves.

## Helping people learn

Only what helps hear and understand a sound ([[Principles]]):

- a tooltip on every setting;
- the waveform of each file and a playhead;
- a small chart of where the last plays landed in pitch and volume.

No tutorials, wizards or guided tours.
