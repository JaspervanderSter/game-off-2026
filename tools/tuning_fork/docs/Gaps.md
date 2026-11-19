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

## Beyond the definition

- **Runtime:** `Sfx.set_overlay("res://<folder>/")` lays another folder laid
  out like `sfx/` over every folder the runtime reads. It works like the
  `sfx/` folder beside the executable: its sound files replace all the files
  of their event, and its JSON files apply key by key. `Sfx.set_overlay("")`
  removes it. Shapeshifters Duel uses it to compare its sounds with an earlier
  set (Ctrl+Shift+S). [[Playback]] lists only `play`, `stop` and
  `set_group_volume` as the programmer's calls, and the tool ignores overlays.
