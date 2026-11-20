# Design reflections

This folder is a workshop for questions, competing hypotheses and disposable
prototypes. Its contents are **not approved design**, an implementation backlog,
or a description of the current game.

Shared notes are written in English; discussion may happen in French.

## Active investigations

- [Game rules](../how-to-play.html) — the single rules
  document, with shortcuts. Its teaching order is still under exploration;
  reflection and progression hypotheses remain in this folder. Source:
  `tools/pages/content/how-to-play.html`; rebuild with
  `python tools/pages/build_resources.py`.

- [Progressive introduction and creature tiers](Progressive%20Introduction.md)
  — reducing the initial learning load while preserving wizard duels and
  meaningful shapeshifting.

## Working agreement

Keep observations, user preferences, assistant hypotheses and experiment results
distinct. An unanswered question or suggested default is not a decision.

Explore a small, reversible example before expanding a system. Record why a
candidate helped or failed. Only move a validated outcome into `docs/design/`
after explicit agreement; do not promote an entire exploration document.
