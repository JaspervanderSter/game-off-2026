# Gaps

Where the code stands today (November 2026) against this definition. The
definition wins; this page shrinks as the code catches up. The game here is
`prototypes/prototype_02`, whose `scripts/audio/sfx.gd` is today's runtime.

## Runtime

- **Paths:** the game plays bare names (`Sfx.play("hit")`) from a fixed list
  in `sfx.gd` (`SOUNDS`). It should play [[Event path|paths]]
  (`Sfx.play("combat/hit")`) of every event found under `sfx/`.
- **Addon:** the runtime is a script of the game, mixed with game-specific
  rules (the victory and defeat sounds have their own voice). It should be a
  game-independent Godot addon ([[Runtime]]).
- **Parameters:** `play(sound, step)` and the `pitch_step` setting make the
  harvest coins rise. They go: one event per step instead
  ([[Settings]], [[Out of scope]]).
- **Loops:** looping is chosen in code (`Sfx.set_loop("bard_song", on)`). It
  should be the event's `loop` setting, with `Sfx.play` / `Sfx.stop`
  ([[Playback]]).
- **Groups:** none yet; no `group` setting, no `groups.json`, no
  `set_group_volume` ([[Groups]]).
- **Missing events:** unknown names are silently ignored; there should be one
  warning per path ([[Playback]]).
- **Hot reload:** a game run from the editor reloads settings only; added or
  replaced files need a restart. An exported build reloads both
  ([[Hot reload]]).

## Music

Music is a separate system of the game ([[Out of scope]]): the game keeps
`scripts/audio/phase_music.gd`, `music/music.json` and the frenzy speed-up.
The tool still lists the music settings and previews the tracks with fades
and frenzy; that preview goes.

## Tool

- **Events:** no way to create, rename, move or delete an event; only files
  inside existing sounds ([[Tool]]).
- **Groups:** no group editing.
- **Series and step:** the step box, series and loop-series buttons exist for
  `pitch_step`; they go with it.
- **Visualizations:** the waveform cards and the pitch/volume chart fit
  [[Principles|principle 7]]; keep them minimal.
