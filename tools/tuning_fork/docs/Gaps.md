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

- **Music (21 November 2026):** the Music tab and shared track player extend
  the original SFX-only scope; [[Music]] defines this addition. Game-specific
  phase bindings, map synchronization and fallback generators remain game code.
  Tuning Fork does not synthesize or bake arbitrary runtime code. Shapeshifters
  Duel supplies its 160-second map reference and separate `default/` and `custom/` Windows workspaces. The game project configures `custom` as its sole editable audio root in
  `tuning_fork.json`; the editor exposes only that root, without mode selectors.
- **Music preview:** configuration buttons preview transitions between tracks;
  the tool does not reproduce the game's sky visuals or frenzy progression.
- **Conversion:** the packaged oggenc remains the preferred WAV encoder.
  FFmpeg with libvorbis can serve as an installed or `OGGENC`-selected fallback.

- **Runtime:** the settings of a looping event that is already playing apply
  the next time it starts ([[Hot reload]]).
- **Tool:** it plays groups at their groups.json volume; the game's own
  changes (`Sfx.set_group_volume`) exist only in the game.

## Beyond the definition

- **Runtime:** `Sfx.set_overlay("res://<folder>/")` lays another folder laid
  out like `sfx/` over every folder the runtime reads. It works like the
  `sfx/` folder beside the executable: its sound files replace all the files
  of their event, and its JSON files apply key by key. `Sfx.set_overlay("")`
  removes it. Shapeshifters Duel uses it for its Windows alternate audio mode
  (`custom/sfx/`, Ctrl+Shift+M). [[Playback]] lists only `play`, `stop` and
  `set_group_volume` as the programmer's calls, and the tool ignores overlays.
- **Runtime:** the project setting `audio/tuning_fork/log_plays` (Project
  Settings > Audio > Tuning Fork > Log Plays, off by default) prints every
  `Sfx.play` to the output: the event, the sound file it played, or why
  nothing played (no such event, no sound file, cooldown). It is read when the
  game starts and only in debug builds, so release exports never print. It
  serves to find which file a sound heard in the game comes from.

## Release audio (25 November 2026)

Shapeshifters Duel now includes the designer workspace in Web exports and
plays it unconditionally, with no mode selector or saved desktop preference.
Windows retains its editable workspace and saved Default/Custom choice; fresh
Windows installs start in Custom. The shared music reader supports packed
imported resources as well as editable files beside the executable.
