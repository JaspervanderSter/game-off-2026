# Tuning Fork runtime (Godot addon)

Plays the sound events made with the Tuning Fork tool. Copy this folder to
`res://addons/tuning_fork/` in a Godot 4 game and enable "Tuning Fork" under
Project Settings > Plugins: it registers the `Sfx` autoload.

```gdscript
Sfx.play("combat/hit")             # plays an event; a looping one keeps going
Sfx.stop("abilities/bard_song")    # fades a looping event out
Sfx.set_group_volume("ui", -6.0)   # the game's own change of a group's volume
```

Events live in `res://sfx/`: `<folder>/<name>.json` with `<name>.ogg`,
`<name>_2.ogg`... beside it, and `groups.json` for the mixing groups. The
format and the rules are defined in the Tuning Fork docs
(`tools/tuning_fork/docs/` in the repository this addon comes from).

The addon holds nothing specific to a game. Keep `sfx/*.json` in the export
preset's "Filters to export non-resource files" so the settings ship.
