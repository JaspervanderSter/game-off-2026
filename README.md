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
