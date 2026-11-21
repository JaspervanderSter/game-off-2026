# File format

Everything is plain files under one `sfx/` folder at the configured audio root,
readable without the [[Tool]] and friendly to version control
([[Principles]]).

```
sfx/
  groups.json             mixing groups and their volumes
  combat/
    hit.json              settings of the event combat/hit
    hit.ogg               its first sound file
    hit_2.ogg             more takes
  abilities/
    bard_song.json
    bard_song.ogg
```

## Event JSON

Tabs, keys in a fixed order, unknown keys kept, so an unchanged file stays
byte for byte the same when the tool saves it. Every key is optional
([[Settings]]).

```json
{
	"description": "A melee hit lands.",
	"group": "effects",
	"volume_db": -8.0,
	"pitch_jitter": 0.08,
	"cooldown_ms": 40
}
```

An [[Event]] exists when its JSON exists. Sound files without a JSON are
shown by the tool, which creates the JSON on the first save.

## groups.json

```json
{
	"effects": { "volume_db": 0.0 },
	"ui": { "volume_db": -3.0 },
	"ambience": { "volume_db": -6.0 }
}
```

## Sound files

OGG Vorbis, named after the event and numbered from 2
([[Sound files]]).

## Editor project configuration

An optional `tuning_fork.json` at the selected project root chooses the editable
audio folder, using a relative `audio_root` path. Without this file, the selected
folder itself is the audio root. Both tabs open its `sfx/` and `music/` folders;
no sibling audio roots are offered. This configuration belongs to the editor,
not to the game runtime. Include it beside the executable when distributing a
game whose editable audio lives in a subfolder.
