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
| Pick the opponent's difficulty | Left-click an unlocked hat or press its number (1 / 2 / 3) |
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

Reading the board: blue ring = yours, red ring = the AI's. The opponent's panel
shows the hat of the chosen difficulty. Purple orbs = spell
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
- The three starting cards show a themed crest, the creatures and one coin per
  gold available in the first shop. The AI
  picks one of the same packs at random. Both sides receive their pack's bonus
  once, on top of the first round's 3 gold.

  | Pack | Creatures | Bonus gold |
  | --- | --- | ---: |
  | Control | Shield Guardian, Frost Mage, Pitchfork Peasant | +1 |
  | Tempo | Duelist, Archer, Bard | 0 |
  | Breakthrough | Berserker, Assassin, Spearman | +1 |

- Gold income 3, 4, 5... per round, unspent gold kept. Three random fantasy offers
  per round, each bought once; prices 1-3; selling refunds the price.
- Peasant harvest: when each fight begins, every Pitchfork Peasant placed on the
  board gives 1 gold, doubled per star (1, 2, 4, 8). Benched peasants give
  nothing, so the gold competes with a stronger board slot. The peasant hops
  with a golden burst, its coins pop out in a fan above it and fly one by one
  into the purse with a rising chime; the counter ticks up as each coin lands.
  The gold is spent in the next shop phase. The hover card shows one small coin
  per harvested gold, and during preparation the next-income hint includes the
  current board's harvest.
- When the fight begins, the shop column (offers, reroll, fight button, spell
  upgrade) slides off the right edge and the bench shrinks to half size and docks
  at the bottom of the screen, where hovering it still shows the creature card.
  Both stay away during the result and slide back when the next shop opens
  (0.45 s each way).
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
- At 45 seconds, frenzy increases all damage, basic attack speed and movement
  speed by 20% for both teams. The bonus grows by 20 percentage points every
  three seconds, reaching 100% at 57 seconds. The timer and arena outline show
  the current phase, and battle music speeds up by 5% per level. Shapeshift
  charges recharge at their normal rate.
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
  form (dominant outcome follows its tactical identity). Both casts preserve health
  percentage. Allied casts then heal 10% of new max HP, ready the basic attack,
  cleanse negative statuses and grant +1 level (+20% base HP and damage per level).
  Enemy casts reset the target to temporary level 1, keep its statuses and
  basic-attack cooldown, and stun it for three seconds. Status effects and
  cooldowns continue during the stun.
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
    using abilities, interrupt a channel, charge, dive or shell, and flee from
    the skunk in sharp zigzags at 130% speed. A green stink cloud with a violet ring bursts
    from the skunk; feared creatures tremble under a violet exclamation mark.
    An allied shapeshift cleanses fear.
- The pyromancer and frost mage channel Fireball and Blizzard for one second.
  An orange or blue ring shows the cast's progress. A shapeshift during the
  channel cancels the ability and starts its cooldown. A launched fireball
  or active blizzard continues after the caster changes form.
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
- Top-down camera, synthesized sound effects, icon-based interface.
- All 24 abilities implemented; short combats (~20-30 s); visible homing projectiles.
- Hover shows the three outcomes with chances (no outcome-stat comparison).
- Three thematic starting packs. The AI evaluates purchases and transformations
  using combat value (see below).
- Tools: headless tests.

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
  The area deals 7.2 damage/s before armour and chills enemies inside. Basic shots
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
  protects frontline/ranged coverage, and rerolls while it can still afford a
  useful offer after paying for the refresh. It can buy a copy directly into a
  matching group when the bench is full and collect copies for fielded units
  that already have stars. Valuable unaffordable duplicates can be locked for
  the next round.
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

## AI self-play

The training cycle plays full duels with the live creature data, shop, combat
and spell timing. It screens ten strategies, runs a round-robin league with
the strongest variants and their combinations, then checks the league leader
against the reference and three finalists on fresh seeds. Each match is played
from both board sides, with paired shop seeds. Duels still in progress at round
35 count as draws.

From the repository root, with Python 3 and an imported Godot project:

```powershell
python prototypes/prototype_02/training/train.py --godot "C:/path/to/godot_console.exe"
```

The runner writes each duel and the proposed profile to
`.godot/self-play/` within this prototype. It uses the pre-training strategy
as its reference and leaves the game's settings alone. The active settings
are in `EnemyAI.DEFAULT_PROFILE`.

The cycle with seed 84000 played 1,216 duels. The selected profile won 80 of
100 validation duels against the reference and 168 of 300 against the three
other finalists combined. It values pyromancer and frost mage more highly,
accounts for fireball and burn scaling with stars, and prioritises
interrupting enemy casts.

## Difficulty levels (13 November 2026)

Each duel opens on a difficulty screen with three hats, from modest to impressive:
a patched brown apprentice cap, a blue adept hat with a gold band and star, and a
glowing purple archmage hat with a curled tip, moon, stars, jewel and orbiting
sparks. Hovering a card lifts it, bobs its hat and previews that hat in the
opponent's panel, where the chosen hat stays as a reminder for the whole duel.
The restart button returns to this screen; the last choice is kept as the
opponent's hat until a new one is picked.

Only Apprentice is available on a fresh profile. Winning a duel against
Apprentice unlocks Adept, and winning against Adept unlocks Archmage. The game
saves unlocked difficulties locally. The victory screen shows the newly
unlocked hat with an open padlock.

- **Archmage** uses the full-strength AI strategy, including budget-driven shop rerolls.
- **Adept** and **Apprentice** follow the same rules, gold and spell charges as
  the player. They only decide worse: noisier shop scoring, fewer rerolls, a later
  (adept) or no (apprentice) recharge upgrade, no locks, no selling to replace
  (apprentice), naive field selection (apprentice), and slower, less selective
  casting that sometimes targets a random creature (15% adept, 40% apprentice).

Difficulty settings live in `scripts/core/difficulty.gd`. Before the combat
and AI updates above, calibration against Archmage in AI-vs-AI duels
(alternating sides, live casting loop, 400 duels per
level on fresh seeds): Apprentice wins about 6%, Adept about 28%, Archmage mirror
about 50%. Archmage wins against the Apprentice with about 7.3 hearts left on
average, against the Adept with about 5.6. These measure relative strength, not
expected win rates against a human player.

```bash
godot --headless --path prototypes/prototype_02 res://tests/difficulty_benchmark.tscn -- --level=0 --duels=100 --seed=1
```

Run this benchmark separately from the regression tests. `--set=key=value` overrides
one profile key of the tested level for tuning experiments.

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
