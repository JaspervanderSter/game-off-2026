# Prototype 02 — Shapeshift Auto-battler

Godot 4.7 project built from scratch from the design notes
([Prototype 02](../../docs/design/Prototype%2002.md) and the shared notes in
`docs/design/`). Nothing is reused from Prototype 01.

Learning goal: does shapeshifting make a complete auto-battler duel more fun?

## Run

Open `prototypes/prototype_02/project.godot` in Godot 4.7 and press F5.

To use fullscreen when launching from the editor, turn off **Embed Game on Next
Play** in the **Game** tab's window options, then relaunch with F5.

## How to play (no text in game: everything is icons)

| Action | Control |
| --- | --- |
| Pick a starting pack | Left-click one of the three cards |
| Buy a creature | Click and release a shop card for the bench, or drag it directly to a board cell / reserve slot |
| Reroll shop | Click the circular-arrow button below the offers (1 gold) |
| Upgrade shapeshift recharge | Click the wand / circular-arrow panel below the combat button (4 gold, once per duel) |
| Lock / unlock an offer | Right-click its shop card; a gold padlock marks a lock |
| Place / move / swap | Drag between your half of the board (bottom) and the reserve slots |
| Combine / merge | Drag onto an identical creature of the same star rank; gold highlights show compatible targets |
| Sell | Drag a creature onto the shop panel (refund = price) |
| Start combat | Crossed-swords button (or Space) |
| Toggle fullscreen | Alt+Enter |
| Shapeshift | Left-click (or tap) any living creature during combat, friend or foe |
| Inspect | Hover a creature: its three possible outcomes with their chances, plus stat bars. In combat, a reticle previews the cast: cyan blessing circle on your creatures, violet hex fangs on enemies, grey when no charge is ready or the target is immune |
| Experiment toggles | Wand: no-spell mode for both wizards (outside combat). Double chevron: combat speed x2 |

Reading the board: blue ring = yours, red ring = the AI's. Purple orbs = spell
charges (the arc shows recharge). Base creatures have no stars. Gold stars (1–3) show permanent merge upgrades.
Three small circles show progress towards the next star: a single copy fills one,
a manually combined pair fills two. A pair has no combat-stat bonus.
These circles are hidden at rest. Hover reveals a creature's progress; dragging
reveals progress only on compatible merge recipients, including shop drags.
Temporary combat levels enlarge the creature image by 15% per level (additive,
capped at +60%); no number or extra star is shown. Team bases, health bars,
collision sizes and combat stats are unaffected by this visual scale.
A white dashed ring = shapeshift immunity. Small pips beside a creature = status
effects (green rim positive, red rim negative). Hearts = wizard health.
A half-filled heart represents 0.5 health; the starting total remains 10 hearts.

## Rules implemented

All confirmed rules and delegated defaults of the design note, notably:

- Duel loop: free starting pack, then every round shop + preparation, real-time
  combat, resolution; until a wizard has 0 of 10 health.
- Gold income 3, 4, 5... per round, unspent gold kept. Three random fantasy offers
  per round, each bought once; prices 1-3; selling refunds the price.
- A shop click buys onto the bench on mouse release. Dragging an offer instead
  buys directly onto a free board cell, free bench slot, or compatible merge
  recipient. Mouse-down only previews the offer. Invalid drops consume no gold
  or offer. Direct board placement and explicit merge drops work with a full
  bench; field capacity still applies. Purchases never combine unless dropped
  onto a compatible recipient. Starting packs remain fielded.
- Enemy preparation performs one action about every 0.55 s. Gold spending is
  shown with flying coins and a counter pulse; purchased/repositioned creatures
  slide into their cells over 0.42 s. The player can prepare simultaneously, but
  combat waits for the enemy's sequence to finish. Simulations use the same
  individual actions without presentation delays.
- Reroll costs 1 gold and replaces all unlocked offers, including sold slots.
  Right-click toggles an offer lock, retained across rerolls and round refreshes;
  buying clears that slot's lock. All-locked rerolls consume nothing.
- Manually drop a creature onto an identical form of the same star rank, on the
  board or bench. Two copies form a group with two of three circles filled,
  without any health or damage bonus. The third copy completes the group and
  grants one star with a gold burst and a distinct sound; progress resets to 1/3.
  Three unstarred copies yield one 1-star; three 1-star copies yield
  one 2-star; three 2-star copies yield one 3-star (3 / 9 / 27 base copies).
  Rank is capped at three merge stars. Merges use both board and
  bench, preserve the chosen recipient's position, and free consumed slots.
  Combining two 2/3 groups consumes only the one copy needed for promotion;
  the remaining source copy stays at its original location and rank. Maximum
  rank creatures cannot combine. Unlike forms/ranks still swap normally.
  The opposing wizard explicitly combines its copies during preparation.
  Permanent ranks multiply HP and basic damage by 1 / 1.8 / 3.24 / 5.832 for 0 / 1 / 2 / 3 stars, stacking with
  temporary levels and persisting through transformations and between rounds.
  Ability magnitudes remain fixed. Selling refunds the combined base-copy value.
- 8 x 6 board, 8 x 3 half per team; up to 6 fielded creatures and 6 in reserve.
- Continuous movement, nearest-target default, soft separation, board bounds.
- Loser loses 0.5 health per surviving enemy creature; mutual elimination or
  60-second timeout is a draw with no damage.
- A surviving loser gains 1 gold per heart lost. A lethal combat grants no gold
  for any of its lost hearts, with no flying coins, gold sparkle or coin sound;
  only the heart-loss effects remain. Both sides follow this rule; draws grant
  no loss gold. This is in addition to normal round income.
  Half-hearts accumulate across rounds: losing 0.5 grants no coin yet, and
  losing the next 0.5 completes one gold. The HUD animates each half separately,
  with coins only for completed whole hearts.
  Resolution plays each heart loss in sequence: anticipation, heart burst,
  wizard jolt, red fragments, a spinning coin arcing into the gold counter,
  impact sparkles and a counter bounce, with separate break and coin sounds.
  Health and gold settle once in the rules; the HUD reveals them in sync with
  each burst and arrival. Long sequences finish before the next round/game over.
- Shapeshift: one starting charge, max three, one recharged every 3 s; a one-time
  4-gold upgrade reduces recharge to 2.4 s for the rest of this duel. The upgrade
  resets in a new duel, applies to future combats, and is available to both sides.
  3 s target
  immunity for both wizards; invalid casts consume nothing. Result drawn from the
  eight-stage network, with fixed 55% / 30% / 15% outcome priorities per source
  form (dominant outcome follows its tactical identity). Keeps health %, heals 10% of new max HP,
  readies the basic attack, keeps positive / removes negative statuses, ally casts
  give +1 level (+20% base HP and damage per level), enemy casts preserve level.
  Combat forms, temporary levels and statuses reset at the end of combat;
  permanent merge stars remain.
  Feedback differs by target. Blessing (own creature): white flash, golden pillar
  of light, double golden ring, rising sparks, level-up chevrons and a rising
  arpeggio. Hex (enemy creature): a violet vortex implodes into the target, then
  bursts with a shock ring, crackles, dark smoke and a descending growl. Both flash
  the creature and briefly shake the board (stronger for a hex).
- Ability cooldowns carry over across forms; a form never gets an instant ability
  just by being entered.
- Positive post-transformation effects (`ally_shift` in `creature_db.gd`) trigger
  only when a wizard shapeshifts one of its own creatures, never on an enemy hex:
  - Rabbit: its backline leap is ready at once.
  - Skunk: enemies within 2.5 cells are feared for 2 s. They stop attacking and
    using abilities, interrupt a charge, dive or shell, and flee from the skunk
    in sharp zigzags at 130% speed. A green stink cloud with a violet ring bursts
    from the skunk; feared creatures tremble under a violet exclamation mark.
    Fear is a negative status, so a shapeshift cleanses it.
- Death: the entity is removed; a visual-only copy is rocketed off the board.

## Music

`scripts/audio/phase_music.gd` plays the supplied looping OGG tracks in `music/`:

- Pack choice and preparation: `cartoon_magic.ogg`.
- Combat: `marching_beat.ogg`.
- Resolution fades battle music to silence so heart-loss and coin sounds remain
  clear; the next preparation fades its track in. Game over remains silent.

Every playback begins at zero volume and every stop happens only after reaching
zero. Phase changes use a 1.2-second crossfade with a smooth amplitude curve.
Rapid reversals continue from the current volumes; selecting the same track
preserves its playback position. Both streams loop in Godot, and combat x2 does
not change music speed. Music volume is initially -16 dB to leave room for effects.
Fade duration and volume can be tuned with `PhaseMusic.FADE_SECONDS` and `MUSIC_DB`.

The final duel result uses `sfx/victory.wav` when the opponent has no hearts left
and `sfx/defeat.wav` when the player has no hearts left. These recordings start
only on entering the game-over screen, after the final heart-loss sequence.
Intermediate rounds and draws play neither recording; heart and coin effects
provide round feedback. Each recording plays once at its original pitch on a
dedicated voice. Music has faded out during resolution and stays silent at game over.

## Choices made for this prototype (3 November 2026)

Answers given by the user while scoping the implementation:

- Procedural shapes and icons only, as little text as possible (rule for all prototypes).
- Top-down camera, synthesized sound effects, English as the (rare) UI language.
- All 24 abilities implemented; short combats (~20-30 s); visible homing projectiles.
- Hover shows the three outcomes with chances (no outcome-stat comparison).
- Three thematic starting packs drawn from six; the current AI evaluates a
  three-pack sample, purchases and transformations using combat value (see below).
- Tools: no-spell toggle, x2 combat speed, headless tests.

Assistant-authored values (all adjustable in `scripts/data/creature_db.gd` and
`scripts/core/rules.gd`):

- Creature statistics and ability parameters for all 24 forms. HP was scaled by
  1.3 after simulation to reach the requested combat length.
- Packs: vanguard, volley, arcane, skirmish, militia, sanctuary.
- Enemy casting evaluates expected outcome value, health, cleanse, levels and
  the published probabilities; it avoids gifting stronger forms to weak enemies.
- Reroll price and star multipliers are initial tuning values in `Rules`.

## Animal balance pass (3 November 2026)

Animals are intended as useful alternative combat roles. They are not a weaker
roster or guaranteed upgrades in every situation. The shared transformation,
health-percentage and level rules remain the same.

- Rabbit: now 135 base HP and 10 damage every 0.65 s; immediately leaps behind
  the deepest enemy in 0.5 s, then attacks that target (on entering combat as a
  rabbit, or after an ally shapeshift; an enemy hex keeps the normal cooldown). It can leap again after
  an 8-second cooldown when the enemy backline is out of reach.
- Deer: 155 HP, a larger healing aura and 5 HP/s regeneration for nearby allies.
- Peacock: 140 HP, a larger area and a stronger, longer attack-speed debuff.
- Snake: 125 HP, stronger basic attacks and poison at 7 HP/s.
- Wolf, leopard and eagle: stronger attacks and more HP for their offensive roles;
  eagle dive damage also increases. Hedgehog gains durability for its thorns.
- Skunk: more HP, stronger basic attacks and a larger armour-reduction area.
- Turtle, rhino and gorilla retain their existing defensive and area-damage roles.

These are first-pass tuning values. Simulations check pacing and rule behavior;
playtesting is still needed to judge each form's situational value.

## Combat and AI rebalance (3 November 2026)

- Frost mage: 115 HP, 7 basic damage; every 9 s, casts a stationary 3x3-cell
  blizzard for 3 s on an enemy cluster within range. First cast starts at 2 s.
  The area deals 6 damage/s before armour and chills enemies inside. Basic shots
  chill on hit for 1 s. Chill halves movement and basic attack speed, and repeated
  hits refresh it.
  Storms persist after caster death or transformation, then expire normally.
  Overlapping storms do not stack: a creature inside several storms takes the
  damage and chill of the strongest one only.
- Pyromancer: basic shots deal area damage and burn enemies for 5 damage/s before
  armour for 4 s. The pyromancer switches targets between shots when another enemy
  is in range, preferring the shortest remaining burn. A separate homing fireball
  travels at 3.5 cells/s, deals 120 damage through armour to one enemy, and applies
  the same burn. It is ready after 6 s at the start of combat, then every 15 s.
  Unlike other ability magnitudes, fireball and burn damage scale with stars and
  temporary levels exactly like basic damage (the values above are for 0 stars,
  level 1).
- Bard: sings a song instead of a local aura. Every second, a beat inspires every
  ally on the battlefield, the bard included, for 3 s: +35% basic attack speed.
  Inspiration outlasts the bard's death until it expires. Each beat plays one note
  of a looping pentatonic melody. A golden sound wave leaves the bard and a note
  flies to every ally, bursting in a golden ring. The bard hops on the beat;
  inspired creatures hop with it, stand on a golden light and are circled by a note.
- Assassin purchase price is now 2 gold.
- AI no longer stops improving once six creatures are fielded. It buys useful
  duplicates, completes stars, replaces weaker units based on combat value,
  protects frontline/ranged coverage, and spends on at most two rerolls per
  preparation. Valuable unaffordable duplicates can be locked for the next round.
  It can buy the recharge upgrade from its own gold. It avoids sacrificing a
  fielded body just to create an unfinished 2/3 group.
- Placement ranks actual combat power, not resale value (partial groups give no
  extra strength). Supports stay near the frontline; ranged units spread out to
  reduce blizzard exposure. Casting uses expected weighted form value and avoids
  interrupting an airborne attack or a ready blizzard.

An optional comparison against the frozen previous policy won 20/20 duels over
10 seeds with both board orientations. Both policies used the current roster,
health/economy rules and equal spell decision intervals; neither received free
gold or advance knowledge of random outcomes. This measures improvement against
the old policy, not expected win rate against a human player.

```bash
godot --headless --path prototypes/prototype_02 res://tests/ai_benchmark.tscn
```

## Tests

```bash
godot --headless --path prototypes/prototype_02 res://tests/run_tests.tscn
```

Checks the network (24 forms, 3 cross-roster links each, no direct reverse,
everything reachable, shortest return of 8), charges and recharge timing, the
transformation rules, immunity, economy and capacities, shop locks and rerolls,
click and drag purchases, invalid-drop cancellation, animated enemy preparation,
conditional merge-progress visibility, manual partial groups and star persistence, overflow and
resale-value conservation, preparation controls,
half-heart damage, whole-heart compensation carried across rounds, lethal loss
without gold, reward presentation, blizzard area/duration, recharge upgrades,
weighted outcome distributions and AI purchasing/merging/casting decisions,
looping music, fades, crossfade reversals and phase-to-track transitions,
round reset, several
abilities, then simulates 20 AI-vs-AI duels with and without casting and prints
the average combat and duel lengths.

Pass `-- --no-sound` after any Godot command line (game included) to mute all
audio, music included.

A separate, on-demand balance suite (parallel 1v1 duels between all forms, CSV/JSON
rankings) lives in [`balance/`](balance/README.md). It is not part of these tests
and runs only on explicit request.

`res://tests/capture.tscn` (not headless) plays a scripted sequence of the real game
and saves screenshots to `user://captures/`.

Latest simulation (20 AI-vs-AI duels per mode, after the combat/AI rebalance):
combats average about 25 s with casting and 19 s without; duels average 11.7 and
9.2 rounds respectively. The half-heart rule gives purchases, merges and the
permanent recharge upgrade more rounds to matter.
