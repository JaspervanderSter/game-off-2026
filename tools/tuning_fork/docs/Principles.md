# Principles

The rules every feature of [[Home|Tuning Fork]] is checked against.

1. **Much simpler than Wwise or FMOD.** A newcomer understands the whole tool
   in an afternoon. When a feature needs a manual, it does not belong here;
   see [[Out of scope]].
2. **Built for small teams.** Indie and jam teams with a sound designer and a
   programmer who want to move fast. No setup, no build step, no server.
3. **Events, not code.** The sound designer creates, tunes and removes
   [[Event|events]] alone. The programmer only writes the [[Event path]] in
   the game's code ([[Workflow]]).
4. **One event, one intent.** If two sounds have a different intent, even
   slightly, they are two events. Files are duplicated rather than shared;
   the game passes no values to an event ([[Settings]]).
5. **Files are the truth.** Everything lives in plain OGG and JSON files next
   to each other ([[File format]]), readable and editable without the tool,
   friendly to version control.
6. **Godot first, open format.** The [[Runtime]] ships for Godot. The format
   does not depend on Godot, so another engine could read it.
7. **Show, minimally.** Tooltips explain each setting; a few small
   visualizations (waveform, where plays land) show what settings do.
   Nothing superfluous ([[Tool]]).
8. **Never break the game.** A missing event or file is silence and one
   warning, never a crash ([[Playback]]).
9. **Hear changes fast.** Saved changes reach the running game when its
   window regains focus ([[Hot reload]]).
