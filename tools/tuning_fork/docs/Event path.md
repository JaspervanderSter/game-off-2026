# Event path

The name the game's code uses to play an [[Event]]: its folders and its
name, separated by `/`, relative to the `sfx/` folder ([[File format]]).

```gdscript
Sfx.play("combat/hit")
Sfx.play("ui/click")
```

- The path **is** the event's place on disk: `combat/hit` is
  `sfx/combat/hit.json` with `sfx/combat/hit.ogg`, `hit_2.ogg`...
- Folders can nest (`enemies/boss/roar`). They sort events for people; the
  [[Groups|group]] decides the mix, not the folder.
- Two events may share a name in different folders: `combat/hit` and
  `ui/hit` are different events.
- Names and folders use lowercase letters, digits and `_`. A name cannot end
  in `_<number>`, which marks extra [[Sound files|files]].
- Renaming or moving an event changes its path: the game's code must change
  too. The [[Tool]] says so before it renames.
