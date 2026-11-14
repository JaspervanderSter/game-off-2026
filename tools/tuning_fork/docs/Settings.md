# Settings

The values in an [[Event]]'s JSON file ([[File format]]). Each has a
default, so a new event needs none of them. The [[Tool]] shows each one with
a tooltip and a reset to its default.

| Setting | Meaning | Default |
| --- | --- | --- |
| `description` | When the game plays the event, in a sentence | `""` |
| `group` | The mixing [[Groups\|group]] it plays in | `"effects"` |
| `loop` | Plays until stopped instead of once ([[Playback]]) | `false` |
| `protected` | Plays on a voice of its own that no other sound can take | `false` |
| `files_from` | Path of another event whose [[Sound files\|files]] it plays, with its own settings | none |
| `volume_db` | Loudness in decibels: 0 as recorded, -6 about half | `-8.0` |
| `volume_jitter_db` | Random loudness change per play, up to ± this | `0.0` |
| `pitch` | 1 as recorded, 2 one octave up (also plays faster) | `1.0` |
| `pitch_jitter` | Random pitch change per play, up to ± this | `0.08` |
| `cooldown_ms` | The same event again sooner than this is skipped | `40` |
| `pick` | How a play picks a [[Sound files\|file]]: `shuffle` or `random` | `"shuffle"` |
| `shuffle_refill_after` | Shuffle only: deal again after this many plays (0 = all) | `0` |

## No parameters

The game passes nothing to an event: it plays it or stops it. When a sound
must change with the game (rising coin pitch, a bigger hit), the sound
designer makes one event per case and the programmer picks the path. This
keeps every sound audible and tunable on its own in the [[Tool]].

## Variation, not parameters

`volume_jitter_db`, `pitch_jitter` and several [[Sound files|files]] make an
event sound alive when it repeats. They are random, not driven by the game.
