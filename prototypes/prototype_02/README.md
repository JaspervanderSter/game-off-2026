# Prototype 02 — Shapeshift Auto-battler

Godot 4.7 project built from scratch from the design notes
([Prototype 02](../../docs/design/Prototype%2002.md) and the shared notes in
`docs/design/`). Nothing is reused from Prototype 01.

Learning goal: does shapeshifting make a complete auto-battler duel more fun?

## Run

Open `prototypes/prototype_02/project.godot` in Godot 4.7 and press F5.

## How to play (no text in game: everything is icons)

| Action | Control |
| --- | --- |
| Pick a starting pack | Left-click one of the three cards |
| Buy a creature | Left-click a shop card (coins = price) |
| Place / move / swap | Drag between your half of the board (bottom) and the reserve slots |
| Sell | Drag a creature onto the shop panel (refund = price) |
| Start combat | Crossed-swords button (or Space) |
| Shapeshift | Right-click any living creature during combat, friend or foe |
| Inspect | Hover a creature: its three possible outcomes with their chances, plus stat bars |
| Experiment toggles | Wand: no-spell mode for both wizards (outside combat). Double chevron: combat speed x2 |

Reading the board: blue ring = yours, red ring = the AI's. Purple orbs = spell
charges (the arc shows recharge). Gold stars above a creature = temporary levels.
A white dashed ring = shapeshift immunity. Small pips beside a creature = status
effects (green rim positive, red rim negative). Hearts = wizard health.

## Rules implemented

All confirmed rules and delegated defaults of the design note, notably:

- Duel loop: free starting pack, then every round shop + preparation, real-time
  combat, resolution; until a wizard has 0 of 10 health.
- Gold income 3, 4, 5... per round, unspent gold kept. Three random fantasy offers
  per round, each bought once; prices 1-3; selling refunds the price.
- 8 x 6 board, 8 x 3 half per team; up to 6 fielded creatures and 6 in reserve.
- Continuous movement, nearest-target default, soft separation, board bounds.
- Loser loses 1 health per surviving enemy creature; mutual elimination or
  60-second timeout is a draw with no damage.
- Shapeshift: one starting charge, max three, one recharged every 3 s; 3 s target
  immunity for both wizards; invalid casts consume nothing. Result drawn from the
  eight-stage network (equal 1/3 chances). Keeps health %, heals 10% of new max HP,
  readies the basic attack, keeps positive / removes negative statuses, ally casts
  give +1 level (+20% base HP and damage per level), enemy casts preserve level.
  Everything resets at the end of combat.
- Ability cooldowns carry over across forms; a form never gets an instant ability
  just by being entered.
- Death: the entity is removed; a visual-only copy is rocketed off the board.

## Choices made for this prototype (3 November 2026)

Answers given by the user while scoping the implementation:

- Procedural shapes and icons only, as little text as possible (rule for all prototypes).
- Top-down camera, synthesized sound effects, English as the (rare) UI language.
- All 24 abilities implemented; short combats (~20-30 s); visible homing projectiles.
- Hover shows the three outcomes with chances (no outcome-stat comparison).
- Three thematic starting packs drawn from six; AI casts with a simple heuristic;
  AI buys to balance roles and places frontline in front.
- Tools: no-spell toggle, x2 combat speed, headless tests.

Assistant-authored values (all adjustable in `scripts/data/creature_db.gd` and
`scripts/core/rules.gd`):

- Creature statistics and ability parameters for all 24 forms. HP was scaled by
  1.3 after simulation to reach the requested combat length.
- Packs: vanguard, volley, arcane, skirmish, militia, sanctuary.
- Enemy cast heuristic: favours wounded or debuffed allies (heal, cleanse, level);
  casts on healthy, valuable enemies only occasionally; never sits on three charges.
- Shop purchases land on the field when there is room, otherwise in the reserve.

## Tests

```bash
godot --headless --path prototypes/prototype_02 res://tests/run_tests.tscn
```

Checks the network (24 forms, 3 cross-roster links each, no direct reverse,
everything reachable, shortest return of 8), charges and recharge timing, the
transformation rules, immunity, economy and capacities, round reset, several
abilities, then simulates 20 AI-vs-AI duels with and without casting and prints
the average combat and duel lengths.

`res://tests/capture.tscn` (not headless) plays a scripted sequence of the real game
and saves screenshots to `user://captures/`.

Latest simulation (AI vs AI): combats average about 23 s with casting and 21 s
without; duels last about 3-4 rounds. Short duels mean income rarely exceeds
6 gold; wizard health or damage per survivor are the first knobs to try if the
economy needs more rounds to matter.
