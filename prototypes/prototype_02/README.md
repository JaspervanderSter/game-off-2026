# Prototype 02 — Shapeshift Auto-battler

Godot 4.7 project built from the design notes in `docs/design/`, especially
[Prototype 02](../../docs/design/Prototype%2002.md),
[Shapeshifting](../../docs/design/Shapeshifting.md),
[Roster and Transformation Map](../../docs/design/prototype_02/Roster%20and%20Transformation%20Map.md)
and [Combat and Transformation Spec](../../docs/design/prototype_02/Combat%20and%20Transformation%20Spec.md).

This is the second iteration (6 November 2026). The previous 24-form, eight-stage
network is replaced by six archetypes with compact four-form transformation
families. Temporary transformation levels are removed.

## Run

Open `prototypes/prototype_02/project.godot` in Godot 4.7 and press F5.

## How to play (icon-first interface)

| Action | Control |
| --- | --- |
| Pick a starting pack | Left-click one of the three cards |
| Buy a creature | Left-click a shop card (coins = price) |
| Reroll shop | Click the circular-arrow button below the offers (1 gold) |
| Lock / unlock an offer | Right-click its shop card; a gold padlock marks a lock |
| Place / move / swap | Drag between your half of the board (bottom) and the reserve slots |
| Sell | Drag a creature onto the shop panel (refund = price) |
| Start combat | Crossed-swords button (or Space) |
| Transform | Right-click any living creature during combat, friend or foe |
| Trigger an animal special | Left-click a friendly animal during combat (costs 1 charge) |
| Inspect | Hover a creature: its family ladder, next upgrade, special state and stat bars |
| Experiment toggles | Wand: no-spell mode. Double chevron: combat speed x2. Momentum chevrons: enable/disable combos (outside combat) |

Reading the board: blue ring = yours, red ring = the AI's. Three small coloured
dots on the ring show the transformation family. Purple orbs = spell charges (the
arc shows recharge). Gold stars = permanent merge rank (1–3). A white dashed ring
= shapeshift immunity. An orange pulsing ring = momentum combo window. A gold
burst = combo. A small rune on an animal = its one-use special: bright means
ready, dim/check means used. A padlock on the next ladder step means the special
must be used before upgrading. Small pips beside a creature = status effects
(green rim positive, red rim negative). Hearts = wizard health.

## Six archetypes

| Archetype | Role | Signature |
| --- | --- | --- |
| Vanguard | Tank | Guard aura gives nearby allies armour. |
| Striker | Melee DPS | Initial backline target priority. |
| Ranger | Ranged DPS | Kites away from melee. |
| Mystic | Magic / control | Frost attacks slow movement. |
| Support | Healing / buffs | Heals the most wounded ally. |
| Berserker | Heavy melee DPS | Attacks faster as health falls. |

Each archetype owns a directed four-form ladder. Base → Animal I always succeeds.
Animal I and II must use their one-use special before the next upgrade. Animal III
refreshes instead of upgrading.

| Family | Ladder |
| --- | --- |
| Vanguard | Vanguard → Bear → Turtle → Rhino |
| Striker | Striker → Fox → Panther → Rabbit |
| Ranger | Ranger → Hawk → Eagle → Phoenix |
| Mystic | Mystic → Raven → Shadow Raven → Owl |
| Support | Support → Doe → Songbird → Unicorn |
| Berserker | Berserker → Boar → Wolverine → Badger |

## Rules implemented

### Duel loop

- Free starting pack, then every round shop + preparation, real-time combat,
  resolution; until a wizard has 0 of 10 health.
- Gold income 3, 4, 5... per round, unspent gold kept. Three random base-archetype
  offers per round, each bought once; prices 1–3; selling refunds the price.
- Purchases go to the bench for manual placement. A full bench blocks purchases
  unless the incoming copy immediately merges. Starting packs remain fielded.
- Reroll costs 1 gold and replaces all unlocked offers, including sold slots.
  Right-click toggles an offer lock, retained across rerolls and round refreshes.
- Three copies of the same purchased form and star rank merge automatically on
  purchase. Three 1-star copies yield one 2-star; three 2-star copies yield one
  3-star. Rank is capped at three. Permanent ranks multiply HP and basic damage
  by 1 / 1.8 / 3.24 and persist through transformations and between rounds.
- 8 x 6 board, 8 x 3 half per team; up to 6 fielded creatures and 6 in reserve.
- Continuous movement, nearest-target default, soft separation, board bounds.
- Loser loses 1 health per surviving enemy creature; mutual elimination or
  60-second timeout is a draw with no damage.
- Death: the entity is removed; a visual-only copy is rocketed off the board.

### Shapeshifting

- One starting charge, maximum three, one recharged every 3 s. Invalid casts
  consume nothing.
- Three-second per-creature immunity, both wizards.
- Base → Animal I always succeeds. Animal I → II and II → III require the
  current animal's one-use special. Animal III refreshes instead of upgrading.
- Keeps health percentage, then heals 10% of the new maximum health (capped at
  full). Keeps positive statuses, removes negative statuses.
- Readies the basic attack, except when an attack was interrupted.
- Ability cooldowns carry over; entering a form never grants an instant ability.
- No temporary levels. Permanent merge stars remain.
- Forms, specials, momentum and statuses reset at the end of combat.

### Animal specials

- Only animal forms have specials. Each is usable once per form.
- Auto-trigger is free and checks the form's data condition.
- Manual trigger is left-click on a friendly animal and costs one charge.
- Using the special unlocks the next ladder upgrade.
- Entering a new form resets the special; refreshing Animal III resets it too.
- Examples: Bear Roar, Turtle Fortify, Rhino Stampede, Fox Pounce,
  Panther Frenzy, Rabbit Evade, Hawk Volley, Eagle Skyfall, Phoenix Firestorm,
  Raven Frost Nova, Shadow Raven Shadow Nova, Owl Screech, Doe Bloom,
  Songbird Crescendo, Unicorn Purify, Boar Gore, Wolverine Frenzy, Badger Quills.

### Attack timing

- Every basic attack has a visible windup.
- Transforming the attacker during the windup cancels the attack and applies a
  0.4 s recovery.
- Once the windup ends, the attack is committed.
- Transforming the target grants a 0.3 s projectile-dodge window. Projectiles
  that arrive during that window are deflected. Melee attacks already in windup
  are not automatically dodged.

### Momentum combos

- After a transformation, momentum waits for the three-second immunity.
- When immunity expires, a 2.5 s momentum window opens.
- A transformation during that window triggers a combo: +25% attack speed and
  +15% damage for 4 s.
- If the window expires, momentum resets.
- The layer can be disabled with the momentum toggle or `Rules.MOMENTUM_ENABLED`.

## Architecture

The combat system is shared across all forms. `Unit` reads statistics, attack
style, windup, projectile type, ability parameters and the one-use `special`
block from `CreatureDB.FORMS`. `Battle` handles the shared simulation and special
triggering. Adding an archetype is a data task:

1. Add one base form and three animal forms to `CreatureDB.FORMS`.
2. Order them in `CreatureDB.FAMILIES`.
3. Add a `special` block to each animal form.
4. Add the base form to `CreatureDB.BASE_FORMS` and optionally a pack.
5. Add procedural art in `Icons.creature`.
6. Add tests for the ladder, specials and auto conditions.

No changes to `Unit` or `Battle` are needed unless the archetype introduces a
genuinely new special type or ability behaviour.

### Key files

| File | Purpose |
| --- | --- |
| `scripts/data/creature_db.gd` | Archetypes, 24 forms, ladders, specials, packs. |
| `scripts/core/rules.gd` | All timing, spell, momentum and economy tuning values. |
| `scripts/combat/unit.gd` | Shared unit simulation, windups, abilities, specials, drawing. |
| `scripts/combat/battle.gd` | Shared combat loop, casting, projectiles, damage. |
| `scripts/ai/enemy_ai.gd` | AI purchases, placement and casting heuristics. |
| `scripts/ui/icons.gd` | Procedural creatures, family accents, telegraphs, FX icons. |

## Tuning values

All values are first-pass and live in `scripts/core/rules.gd` or
`scripts/data/creature_db.gd`.

| Value | Initial |
| --- | --- |
| Starting / maximum charges | 1 / 3 |
| Recharge interval | 3 s |
| Target immunity | 3 s |
| Transformation heal | 10% of new max HP |
| Interrupted attack recovery | 0.4 s |
| Projectile dodge window | 0.3 s |
| Momentum window | 2.5 s |
| Momentum duration | 4 s |
| Momentum attack speed / damage | +25% / +15% |
| Combat timeout | 60 s |
| Wizard health | 10 |
| Starting income | 3 gold, +1 per round |
| Reroll cost | 1 gold |
| Star multipliers | 1 / 1.8 / 3.24 |

## Tests

```bash
godot --headless --path prototypes/prototype_02 res://tests/run_tests.tscn
```

Checks the six ladders and 24 forms, staged upgrade gating, manual and automatic
specials, charges and recharge timing, transformation rules, immunity, attack
interruption, projectile dodging, momentum windows and combos, economy and
capacities, shop locks and rerolls, bench-only purchases, chained merges and star
persistence, preparation controls, round reset, the shared ability vocabulary,
then simulates 20 AI-vs-AI duels with and without casting and prints average
combat and duel lengths.

`res://tests/capture.tscn` (not headless) plays a scripted sequence of the real
game and saves screenshots to `user://captures/`.

Latest simulation (AI vs AI): combats average about 35 s with casting and 33 s
without; duels last about 4 rounds. Short duels still mean income rarely exceeds
6 gold; wizard health or damage per survivor are the first knobs to try if the
economy needs more rounds to matter.

## Known limitations

- Animal forms use procedural placeholder art.
- Families are role-preserving; cross-family transformations are not used.
- The momentum combo is generic.
- Specials use a small shared set of effect types; they are not fully unique
  bespoke abilities.
- Auto-trigger conditions are simple distance/health checks.
- The AI casting heuristic does not predict projectile travel time.
- Balance values have not been playtested with external players.

## Design decisions and deviations

- Temporary levels from the previous iteration were removed. Stacking power made
  repeated transformations generically strong and conflicted with the new
  "different form, different trade-off" goal.
- Six compact four-form families replaced the previous 24-form network. The
  complete graph was then replaced by a directed ladder because immediate
  reversals caused ping-pong (Ranger → Hawk → Ranger).
- Animal upgrades are gated by a one-use special. This prevents free progression
  and makes the player choose between spending a charge on the special or on
  another creature.
- Animal III refreshes instead of upgrading, so late-game charges remain useful.
- Base forms do not have specials; only animals do, matching the "special is part
  of the animal identity" idea.
- Enemy transformations still heal and cleanse the target. This keeps enemy
  casts a tactical trade-off rather than a free debuff.
- Attack windups were added so interruption and dodging have clear commit points.
- Projectile dodging is a short timing window rather than an automatic dodge.
