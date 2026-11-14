# Hot reload

Saved changes reach a running game without restarting it.

- **When:** each time the game window regains focus. Nothing is watched in
  the background.
- **How:** the [[Runtime]] compares the modification times of the `sfx/`
  files with the last ones it read (a few milliseconds for a few dozen
  files) and reloads only what changed.
- **What:** everything when possible: event [[Settings|settings]],
  [[Groups|group]] volumes, added, replaced and removed
  [[Sound files|sound files]], new and removed [[Event|events]].
- **Where:** in a game run from the Godot editor, which reads the project's
  `sfx/` folder straight from disk (not through the Godot import), and in an
  exported build (from the `sfx/` folder beside the executable, on top of
  the packed files).
- **Fallback:** a change that cannot be reloaded needs a restart; the rule
  for people is "if in doubt, restart the game".

A sound already playing finishes as it started; the next play uses the new
values.
