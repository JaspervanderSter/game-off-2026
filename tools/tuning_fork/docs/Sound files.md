# Sound files

The audio of an [[Event]]: one or more OGG Vorbis files beside its JSON.

```
sfx/combat/hit.json
sfx/combat/hit.ogg      first file
sfx/combat/hit_2.ogg    more takes, numbered from 2
sfx/combat/hit_3.ogg
```

- Files are interchangeable takes of the same intent; each play picks one,
  by the event's `pick` [[Settings|setting]]:
  - `shuffle`: every file once in a random order before any repeats. With
    `shuffle_refill_after`, the files are dealt again after that many plays.
  - `random`: any file each time; repeats can happen.
  - A new shuffle never starts with the file that just played.
- Numbers have no gaps. Removing a file renumbers the files after it.
- The [[Tool]] adds WAV or OGG files dropped on its window. OGG files are
  copied; WAV files are converted to OGG (oggenc2, quality 5).
- Effects such as reverb or filters are made in the audio editor before the
  file is exported; Tuning Fork plays files as they are ([[Out of scope]]).
- A looping event plays one picked file from its start, over and over
  ([[Playback]]).
