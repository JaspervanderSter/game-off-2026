# game-off-2026

This repository hosts multiple Godot prototypes, each in its own numbered folder
under `prototypes/`.

- [`prototypes/prototype_01`](prototypes/prototype_01/README.md) — SHIFT, an
  attribute-swapping combat prototype.

Tools shared by the prototypes live under `tools/`:

- [`tools/tuning_fork`](tools/tuning_fork/README.md) — Tuning Fork, a Godot
  tool that lists a prototype's sounds, plays them as the game does and edits
  their JSON settings.

To start a new prototype, create `prototypes/prototype_NN/` with its own
self-contained Godot project (its own `project.godot`, scenes, scripts, etc.)
and a `README.md` describing it.

## Automatic itch.io release

`tools/release_itch.ps1` publishes Shapeshifters Duel to
<https://spacemonkeyc.itch.io/shapeshifter-duel> without any manual step:
it fast-forwards `main` from `origin`, runs `tests/run_tests.tscn`, builds the
Windows export (with `export_windows.ps1`) and the Web export, then uploads them
with [butler](https://itchio.itch.io/butler) to the `windows` and `html5`
channels. butler only sends the files that changed. The script refuses to run
on another branch or with uncommitted changes, and stops before uploading if a
test or export fails. It remembers the last uploaded commit in
`%LOCALAPPDATA%\ShapeshiftersDuelRelease\` and does nothing when `main` has not
changed (`-Force` uploads again). Each run's logs are kept there under `logs\`.

One-time setup on the build computer:

1. Install Godot 4.7.2 with its export templates (Windows and Web).
2. Download butler from <https://itchio.itch.io/butler>, unzip it to
   `%USERPROFILE%\Tools\butler\` (or put it on `PATH`), then run
   `butler login` once in a terminal and approve it in the browser.
3. After the first upload, open the game's itch.io edit page: tick
   "This file will be played in the browser" on the `html5` upload, mark the
   `windows` upload as Windows, and delete the old manually uploaded files.

Usage, from the repository root in PowerShell:

| Command | Effect |
| --- | --- |
| `.\tools\release_itch.ps1` | Release the latest `main` if it is new |
| `.\tools\release_itch.ps1 -DryRun` | Test and build without uploading |
| `.\tools\release_itch.ps1 -RegisterTask` | Check `main` every 15 minutes (Windows scheduled task, while logged in) |
| `.\tools\release_itch.ps1 -UnregisterTask` | Remove that scheduled task |

Pass `-Godot` or `-Butler` when the executables are elsewhere, `-SkipTests` to
skip the tests, and `-IntervalMinutes` with `-RegisterTask` to change the delay.
Builds land in `export/ShapeshiftersDuel/`, `export/ShapeshiftersDuel-Web/` and
their `.zip` archives.
