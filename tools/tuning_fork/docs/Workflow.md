# Workflow

How a sound designer and a programmer work together with
[[Home|Tuning Fork]].

## A new sound

1. The sound designer creates an [[Event]] in the [[Tool]], say
   `enemies/boss/roar`, writes its description ("the boss roars before it
   charges"), drops a few takes, and tunes it.
2. They tell the programmer the [[Event path|path]], by whatever means the
   team already uses. The tool does not track which events the game uses.
3. The programmer adds `Sfx.play("enemies/boss/roar")` where it belongs.
4. Until then the event simply never plays. If the code plays a path that
   does not exist yet, the game stays silent and warns once ([[Playback]]).

## Tuning in the game

The sound designer keeps the game running, saves in the tool, clicks back
into the game and hears the change on the next play ([[Hot reload]]).

## Who touches what

| | Sound designer | Programmer |
| --- | --- | --- |
| Events, files, settings, groups | ✔ in the [[Tool]] | |
| `Sfx.play` / `Sfx.stop` calls | | ✔ in the game |
| Group volumes at run time (options) | sets defaults | ✔ calls `set_group_volume` |
| The [[Runtime]] addon | | installs it once |
