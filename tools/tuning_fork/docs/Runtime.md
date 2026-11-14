# Runtime

The code inside the game that plays [[Event|events]]. For Godot it is an
addon: a folder the team copies into the game, which registers the `Sfx`
autoload.

It:

- finds every event under the game's `sfx/` folder ([[File format]]);
- plays and stops events by [[Event path|path]] ([[Playback]]);
- applies [[Groups|group]] volumes;
- reloads changed settings and files when the window regains focus
  ([[Hot reload]]);
- in an exported build, reads `sfx/` beside the executable first, so sound
  files and settings can change without re-exporting.

It contains no game-specific sound: a game that uses the addon only adds
`Sfx.play(...)` calls and an `sfx/` folder.

## Other engines

The format is plain OGG and JSON. Another engine needs its own runtime that
follows [[Playback]] and [[Settings]]; only the Godot one is provided.
