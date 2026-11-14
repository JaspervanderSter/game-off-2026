# Groups

The only mixing in [[Home|Tuning Fork]]: every [[Event]] belongs to one
group, set by its `group` [[Settings|setting]], and each group has a volume.

- Groups are listed in `sfx/groups.json` with their volume in decibels
  ([[File format]]). The sound designer adds, renames and tunes them in the
  [[Tool]].
- The game can change a group's volume at run time, for example from an
  options menu: `Sfx.set_group_volume("effects", -6.0)`.
- An event's own `volume_db` adds to its group's volume.
- Groups are not folders: folders sort events for people
  ([[Event path]]), groups set how loud they are together.
- No effects, ducking or side-chain on groups ([[Out of scope]]).

Suggested groups for a new project: `effects`, `ui`, `ambience`. Music is
not a group: it is the game's own system ([[Out of scope]]).
