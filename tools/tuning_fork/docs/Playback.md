# Playback

What the [[Runtime]] does when the game asks for an [[Event]].

## The calls

```gdscript
Sfx.play("combat/hit")        # once; a looping event starts and keeps going
Sfx.stop("abilities/bard_song")  # stops a looping event, with a short fade
Sfx.set_group_volume("effects", -6.0)
```

That is the whole interface for the programmer. No handles, no parameters
([[Settings]]).

## One play

1. Skip it if the same event played less than `cooldown_ms` ago.
2. Pick a [[Sound files|file]] by `pick`.
3. Apply `pitch` and `volume_db`, each with its random jitter, plus the
   [[Groups|group]] volume.
4. Play it on the next shared voice: when every voice is busy, the oldest
   effect stops. The voice count is a runtime-wide limit. A `protected`
   event plays on a voice of its own that no other sound can take.

## Loops

An event with `loop` on plays one picked file from its start, over and over,
until `Sfx.stop`. Playing it while it already plays does nothing. Stopping it
fades it out briefly.

## Missing events

If the path matches no event, or the event has no file, nothing plays and
the runtime prints one warning per path to the console. The game never
crashes on sound ([[Principles]]).
