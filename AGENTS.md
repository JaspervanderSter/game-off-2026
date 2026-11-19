# Project instructions

## Balance suite: on demand only

`prototypes/prototype_02/balance/` holds an on-demand balance suite (thousands of
simulated duels). It is not a regression test. Do not run it after code or data
changes, during verification, or as part of `tests/`. Run it only when the user
explicitly asks for a balance run or balance data. Use `tests/run_tests.tscn` for
normal verification.

## Release exports

For Windows exports, run `prototypes/prototype_02/export_windows.ps1` for
Shapeshifters Duel and `tools/tuning_fork/export_windows.ps1` for Tuning Fork.
Use the scripts' default output paths so each run refreshes its build in place.
Pass `-Godot` if needed to locate the editor. Leave `-Out` unset unless the user
explicitly requests a different destination.

Keep only `export/ShapeshiftersDuel/`, `export/TuningFork/`, their respective
`ShapeshiftersDuel-Windows.zip` and `TuningFork-Windows.zip` archives, and any
requested Web exports under `export/`. Upload the canonical archives when
publishing. Use a temporary directory outside `export/` for logs, test data,
screenshots, extracted copies, and other working files.

## Tuning Fork definition

`tools/tuning_fork/docs/` (start at `Home.md`) defines what Tuning Fork and
its game runtime are. Follow it when working on either; when the code and
the definition differ, update `Gaps.md`.

## Language

Write shared project documentation in English. Conversation with the user may remain in French.

## Project website and shared theme

All public HTML pages under `docs/`, including new pages, must use the shared
game theme in `docs/assets/site.css`. Preserve the dark board background,
purple-and-gold palette, typography and panel treatment; add page-specific
layout rules there rather than introducing an independent visual theme.

Read `tools/pages/README.md` before editing website pages or their builders.
Generated pages must use `tools/pages/page_theme.py` for the shared stylesheet
and standalone fallback. Rebuild all generated HTML documents after a theme change,
refresh the homepage's versioned links, and commit sources with generated HTML.
Verify the homepage and all changed pages on desktop and mobile,
including media and stylesheet loading. Verify the deployed pages before
reporting a publication complete; a successful push alone is insufficient.

## In-game interface

Use icons and animation for in-game labels, controls, and announcements. Display
numbers where they communicate game values.

## Git push authorization

On 3 November 2026, the user explicitly granted standing authorization to push this project's changes to the `main` branch of `https://github.com/JaspervanderSter/game-off-2026.git` (`origin`). The user stated that this authorization applies to all chats for this project.

When carrying out a requested commit-and-push workflow, do not ask again for confirmation of this destination or permission for a normal push to `main`. This authorization does not require automatically committing or pushing every edit.

This authorization does not cover force pushes, branch deletion, other repositories or disclosure of credentials and unrelated private files. Required platform approval checks still apply; this instruction does not override them.
