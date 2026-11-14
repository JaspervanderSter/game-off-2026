# Event

The one concept of [[Home|Tuning Fork]]: something that happens in the game
and makes a sound. "A unit is hit", "a coin is harvested", "the bard sings".

An event has:

- a **[[Event path|path]]**, its folder and name, which the game's code uses
  to play it: `combat/hit`;
- one or more **[[Sound files|sound files]]**, interchangeable takes of the
  same sound; each play picks one;
- a few **[[Settings|settings]]**: loudness, pitch, how much they vary, how
  files are picked, whether it loops, its [[Groups|group]];
- a **description**: when the game plays it, in a sentence. It tells the
  programmer where the event belongs.

An event plays **once** or **loops** until the game stops it ([[Playback]]).

An event is **one intent** ([[Principles]]). Variations of the same intent
are extra files of the same event. A sound with a different intent, even a
close one, is another event, with its own copies of the files if needed.
The game never passes values to an event: rising coin sounds are several
events (`coins/harvest_1`, `coins/harvest_2`...), not one event with a pitch
parameter.

An event can exist before the game uses it, and before it has any file: the
sound designer creates it, the programmer adds the call later ([[Workflow]]).
