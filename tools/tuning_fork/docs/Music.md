# Music

Music is an independent tab after the [[Tool]] opens a project. This extends
Tuning Fork beyond SFX without embedding a particular game's phases, artists
or file names in the tool.

## Files and discovery

Recursively discover every OGG/WAV in `music/` under the project's configured
audio root (see [[Tool]]). The Music tab opens it directly, without a folder selector. Each
recording has an adjacent JSON with the same basename. A recording without a
JSON appears with default values; Save creates its sidecar. Other JSON files
are project configurations, with controls derived from their values. Unknown
keys are preserved, including nested data. A project may contain only music.

The editor shows waveforms, playback position, seeking, replacement/import,
Save, Revert and optional auto-preview. Changes are kept in memory until Save;
imports and replacements update files immediately. Disk changes reload without
discarding unsaved edits; conflicts ask the user to save or revert.

## Track settings

| Key | Default | Meaning |
| --- | --- | --- |
| `description` | empty | Purpose and reference notes |
| `volume_db` | -16 | Recorded level offset in decibels |
| `fade_seconds` | 1.2 | Full fade in/out duration |
| `loop` | true | Repeat the recording or selected segment |
| `playback_mode` | continuous | Keep position, restart on entry, or pick a segment |
| `duck_db` | -40 | Reduction while another phase is active |
| `frenzy_speed_per_level` | 0 | Optional game-driven speed increase per frenzy level |
| `segments` | [] | Objects with start_seconds and end_seconds |

Segments are edited with start/end number controls and add/remove buttons.
They must be non-empty, fit within the recording and have positive duration.
Successive entries avoid choosing the same segment when alternatives exist.
`loop: false` plays a segment once. Preview and game use identical copies of
MusicCatalog and MusicVoice, checked by tests.

## Game integration

The game owns the association between phases and recordings, in a configuration
JSON. Configuration values that name discovered tracks become generic preview
buttons in the tool; no phase names are hardcoded there. Continuous outgoing
tracks keep advancing at their ducked level; other tracks fade out.

A procedural system can keep its original implementation and expose a complete
baked recording as an alternative, with a game-owned selector deciding which
source plays. A reference should document its duration and synchronization
origin. Baking is specific to the generator and happens outside Tuning Fork.
Shapeshifters Duel's Windows workspace supplies a full 160-second day/night
ambience. Windows Default keeps the original audio. Web always plays the packed designer workspace with the same track settings as Windows Custom.

Music files and settings of an active Windows workspace reload on game focus.
Invalid settings or unreadable replacement audio retain the last valid voice.
The game's current music system remains responsible for Windows Default behavior. The designer workspace controller also handles Web using imported resources.
