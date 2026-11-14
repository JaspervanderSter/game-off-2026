# Gaps

Where the code stands against this definition. The definition wins; this
page lists what the code does not do yet. The game here is
`prototypes/prototype_02`; its runtime is the addon
`addons/tuning_fork/sfx.gd`.

Aligned on 14 November 2026: event paths, the runtime as a Godot addon,
`files_from`, `protected`, `loop`, groups as audio buses, warnings for
missing events, hot reload of everything in editor runs and exported
builds, music outside Tuning Fork, the tool's event and group management,
and its project window.

## Known limits

- **Runtime:** the settings of a looping event that is already playing apply
  the next time it starts ([[Hot reload]]).
- **Tool:** it plays groups at their groups.json volume; the game's own
  changes (`Sfx.set_group_volume`) exist only in the game.
