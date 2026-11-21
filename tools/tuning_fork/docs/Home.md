# Tuning Fork

Tuning Fork is a small sound tool for games, in the spirit of Wwise and FMOD
but much simpler. A sound designer creates and tunes **[[Event|events]]** in
the tool. A programmer plays them in the game by their **[[Event path|path]]**,
for example `Sfx.play("combat/hit")`. The [[Runtime|runtime]] reads the event's
settings and plays it right.

The sound designer never touches code; the programmer never tunes a sound.

## Who it is for

Small indie and game jam teams: one or two people on sound, one or two on
code, little time. Learning interactive sound is a welcome side effect, not
the goal. See [[Principles]].

## Map

- Why it is shaped this way: [[Principles]], [[Out of scope]]
- What a sound is: [[Event]], [[Event path]], [[Sound files]], [[Settings]],
  [[Groups]]
- How it plays: [[Playback]], [[Runtime]], [[File format]]
- How people work with it: [[Workflow]], [[Hot reload]], [[Tool]]
- Music and replaceable procedural references: [[Music]]
- Words: [[Glossary]]
- Where the code is today against this definition: [[Gaps]]

## In one paragraph

An event is a folder path and a name, one or more sound files, and a handful
of settings. It plays once or loops. It belongs to a mixing group. The game
passes no values to it: a sound that must differ is another event. There are
no layers, no parameters, no effects and no 3D. Everything the tool shows
serves one purpose: hearing and understanding the sound quickly.
