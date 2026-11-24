# Prototype 02 — Shapeshifters Duel

Godot 4.7 project built from scratch from the design notes
([Prototype 02](../../docs/design/Prototype%2002.md) and the shared notes in
`docs/design/`). Nothing is reused from Prototype 01.

Learning goal: does shapeshifting make a complete auto-battler duel more fun?

## Run

Open `prototypes/prototype_02/project.godot` in Godot 4.7 and press F5.

To use fullscreen when launching from the editor, turn off **Embed Game on Next
Play** in the **Game** tab's window options, then relaunch with F5.

## Web loading screen

The Web preset uses `web/loading.html`: the Godot mark sits inside a gold progress
ring, surrounded by the game's creature sprites on the magic school's tiled
floor. Creatures light up as the download advances; small clouds accompany a
rabbit/turtle metamorphosis. Once the engine and its first scene are ready, the
ring stays visible with a Play medallion. One click unlocks audio, fades through
white to the waiting sky, then starts the title and jingle after one second.
There is no second Play button in Godot. It uses existing artwork only, with no external
image requests. Unknown download sizes and engine startup use an indeterminate
orbit instead of an invented percentage.

After changing its artwork or `web/loading.template.html`, run
`python tools/build_web_shell.py` from the repository root and commit the rebuilt
shell with its sources. Ordinary Web exports need no additional step. See
[`web/README.md`](web/README.md) for artwork sources and browser verification.

## How to play (no text in game: everything is icons)

| Action | Control |
| --- | --- |
| Open the journey | Click the island medallion under the title (or Enter): the camera pans down to the islands. A click or key during the title's animation finishes it |
| Return to the map after a duel | Click the island medallion under the crown or skull |
| Pick a stage | Click an unlocked opponent on an island; Tab / arrow keys and Enter also work |
| Return to the title | Esc on the map: the camera pans back up to the title |
| Leave a replayed duel | Click the sky-blue island medallion in the top-left corner (or press Esc): the duel pauses under a green check (back to the map, or Enter) and a red cross (resume, or Esc). Only replays of beaten opponents show it |
| Pick a starting composition | Left-click one of the three cards |
| Buy a creature | Click and release a shop card for the bench, or drag it directly to a board cell / reserve slot |
| Reroll shop | Click the circular-arrow button below the offers, inside the stall (1 gold) |
| Buy a wand upgrade | Click a row of the purple scroll below the stall; its coins show the next level's price, a green check marks a maxed upgrade. Hover a row for an animated before / after card |
| Lock / unlock an offer | Right-click its shop card; a gold padlock marks a lock |
| Place / move / swap | Drag between your half of the board (bottom) and the reserve slots |
| Combine / merge | Drag onto an identical creature of the same star rank; gold highlights show compatible targets |
| Sell | Drag a creature onto the creature stall (refund = price) |
| Start combat | Round sword-and-wand button under the board, right of the bench once the shop exists (or Space) |
| Toggle fullscreen | Alt+Enter |
| Toggle performance counter | Shift+F8 (click the game first in a browser) |
| Shapeshift | Left-click (or tap) any living creature during combat, friend or foe |
| Inspect | Hover a creature: its three possible outcomes with their chances, plus stat bars. In combat, a reticle previews the cast: cyan blessing circle on your creatures, violet hex fangs on enemies, grey when no charge is ready or the target is immune |

The optional performance counter updates four times per second. It shows FPS,
the latest frame interval, and the longest frame interval since it was enabled
(Peak, in milliseconds). Toggle it off and on to reset the peak; switching tabs
can itself produce a large interval. It does no sampling while hidden and does
not intercept mouse input.

Reading the board: blue ring = yours, red ring = the AI's. Each wizard is a medallion beside the board: the opponent's shows its portrait
(or the hat of the chosen difficulty outside the journey), the player's the blue
wizard hat. Purple crystals = spell
charges: hexagonal prisms pointed at both ends, dark glass when empty, filling with
magic from the bottom as they recharge, bright with a white reflection when full;
the same crystal stands for a charge under the medallions, under the board in combat,
in the wand upgrade icons and in their tooltips. Base creatures have no stars. Gold stars (1–3) show permanent merge upgrades.
Three small circles show progress towards the next star: a single copy fills one,
a manually combined pair fills two. A pair has no combat-stat bonus.
These circles are hidden at rest. Hover reveals a creature's progress; dragging
reveals progress only on compatible merge recipients, including shop drags.
Temporary combat levels enlarge the creature image by 15% per level (additive,
capped at +60%); no number or extra star is shown. Team bases, health bars,
collision sizes and combat stats are unaffected by this visual scale.
A white dashed ring = shapeshift immunity. Small pips beside a creature = status
effects (green rim positive, red rim negative). Hearts = wizard health.
Six gems set in the board's wooden frame = each side's population, one lit per
creature on the board out of the six allowed (`Rules.FIELD_CAP`): blue under the
right part of the player's lower edge, red over the right part of the
opponent's upper edge (`BoardView._draw_capacity`, shown with the bench once the
shop exists, in combat too). A creature placed lights the next gem with a pop
and a white sparkle; one removed puts the last gem out. They replaced six plain
round pips under the board, the player's only (playtest, 21 November 2026).
A half-filled heart represents 0.5 health. Each wizard starts with 3 hearts on
the forest, 6 in the town and 10 at the magic school. Only that duel's heart
capacity is drawn, including empty and half-filled hearts after damage. Hearts
stand on arcs above their medallion at a fixed spacing: up to six on one arc,
more split evenly over two concentric arcs (ten = five + five), the inner one
first; hearts are lost from the end, the outer arc first.
The round frieze above the board shows the current round as a numbered gold
medallion, the last seven finished rounds as pips in the winner's colour (grey
for a draw) and the next rounds as fading dashed rings. When a round resolves,
the medallion's ring takes the winner's colour; when the next round starts, the
frieze slides one step left.

## Title (22 November 2026)

The game opens on a title island left of the forest, in the world map's own
space (`scripts/ui/title_screen.gd`, `TitleScreen`, a child of the map's
world). DUEL stands on it in earth letters with grass on every ledge and
SHAPESHIFTERS is carved in gold in its cliff, letters built from chamfered
flat pieces (`TitleScreen.glyph_pieces`). The island bursts out of the clouds
on the title jingle (`ui/title`, rendered by `tools/make_title_jingle.gd`),
lands at 0.45 s with a jolt, then keeps moving: it floats, rocks drift, birds
circle, smoke rises, and a creature on the D changes shape every 3.2 s along
its chain of most likely outcomes. At 0.95 s a rope bridge unrolls from its
shore towards the forest (`map_bridge.gd`'s `reach`) and the island medallion,
the only control, appears on it near the screen's right edge with gold
chevrons gliding towards it (`scripts/ui/home_road.gd`, `HomeRoad`). A tap or
a key finishes the animation.

On Web the HTML loading screen keeps its creature ring after loading, with a
pulsing Play medallion below the Godot mark. A click/tap (or Enter/Space on the
button) unlocks the engine's audio. A 0.4-second fade to white hides the ring,
then a 0.4-second fade reveals the waiting sky (`TitleScreen.wait_for_start`).
After one second the HTML-to-Godot callback starts the animation with its jingle;
input stays blocked through that transition so it cannot accidentally skip it.
Godot draws no Play prompt. Reduced-motion users skip the white fades and keep
the one-second pause. Windows launches play the title at once.

The medallion leads the camera from the title's frame (fitted to the screen)
to the whole map over 2.8 s (`world_map.menu_blend`, `PAN_TIME`), while gold
footsteps leave the cottage door, cross the bridge and reach the hunter; the
clouds drift with parallax. Leaving the title after launch replays the journey: every
opponent and road hides; on arrival the hunter rises (new journey) or pops up,
then the footsteps run on along the beaten roads, faster and faster, each
beaten opponent popping up as they reach it; they run on along the current
opponent's road at the same pace and it rises out of the ground as they arrive. The map's ambience is silent on the title and fades
in on the way. Esc on the map leads back to the title (1.4 s) and the way back
is a simple travel, without a replay; a duel returns
straight to the islands, without replay. The old `menu.tscn` diorama and its
quit button are gone (closing the window quits).

`tests/capture.tscn -- --title-replay-only` captures the replay of a seven-win
journey (to a capture folder, never the player's save).

## Map and duel transition (21 November 2026)

Going from the map into a duel, and back (the end-of-duel medallion or leaving
a replay), cloud curtains cover the screen (`ScreenTransition`,
`scripts/ui/screen_transition.gd`, on its own canvas layer):
three layers of clouds roll in from both sides over 0.65 s, the back ones
smaller, slower and a shade darker, and meet in the middle; the screens swap
while covered (0.1 s), then the curtains part over 0.65 s. The clouds keep the
game's flat look: the map's own cloud silhouette in solid tones (a darker
underside, the body, a light crest), tinted with the map's cloud colour of the
moment. A soft whoosh (`ui/clouds`) plays each way, and input waits until the
transition is done. The map enters a duel through `main.enter_stage` and leaves
it through `main.leave_duel`; `choose_stage` and `new_duel` stay immediate for
tests and tools. The whoosh is synthesised (filtered noise sweeping up then
down):

```
godot --path . --headless --script res://tools/make_cloud_whoosh.gd
```

## Screen layout (21 November 2026)

The duel screen grows with the rules the journey has introduced instead of
keeping empty places for the ones still to come (`Hud.layout_screen`, called
when a duel starts; `Rules.BOARD_POS`, `Rules.RESERVE_POS` and
`Rules.FIGHT_CENTER` are set per duel):

- **Before the shop** (hunter, druid): the board and the two medallions are
  centred together (board at x 410, medallions at x 333). The right of the
  screen stays free.
- **With the shop** (from the lumberjack, and every duel outside the journey):
  the medallions stand in the left column (x 130), the board at x 352, the stall
  and the scroll on the right.

In both, the bench and the fight button share the row under the board, the
button just right of the bench: the button the first duels teach never moves
relative to the board.

Each wizard is a **medallion**: a dark disc ringed in its team colour and gold,
holding its portrait, with its hearts on arcs above it (`Hud.heart_pos`: fixed
spacing, up to six per arc, two balanced concentric arcs beyond), its charge
crystals on an arc below once the wand exists (`Hud.crystal_pos`) and its gold
in a pill on its right once the shop exists (`Hud.gold_pos`), followed for the
player by the next income. A lost heart flashes the disc red and shakes it.
The round frieze and the composition cards centre on the board.

The fight button is introduced like a rule: the hunter's first preparation
spotlights it and the light stays on until the player presses it, then goes
out within 0.1 s (`RuleSpotlight.dismiss`). The button itself behaves as in
every duel (`main.FIGHT_LESSON`, saved in `journey.introduced` and
`journey.lessons_done`; a save that already beat the hunter skips it). During
combat the button drops below the bottom edge instead of sliding right.

## Rules implemented

All confirmed rules and delegated defaults of the design note, notably:

- Duel loop: free starting pack, then every round shop + preparation, real-time
  combat, resolution; until either wizard has no health left.
- Twelve themed starting compositions (`CreatureDB.PACKS`) of two to four
  creatures. Each duel offers three cards, each showing a themed crest, the
  creatures and one coin per gold available in the first shop. Both sides receive
  their composition's bonus once, on top of the first round's 3 gold.
- The cards come from a hidden, shuffled deck (`PackDeck`): no composition
  repeats within nine cards (three duels), then the whole deck is reshuffled.
  The opponent draws one card per duel from its own deck, which reshuffles after
  nine openings. Nothing on screen shows the decks, and both resume after a
  restart (`user://pack_decks.cfg`).

  | Composition | Creatures | Bonus gold |
  | --- | --- | ---: |
  | Village | Pitchfork Peasant x2 | 0 |
  | Fortress | Shield Guardian, Frost Mage | +3 |
  | Troupe | Duelist, Archer, Bard | +3 |
  | Raid | Berserker, Assassin, Spearman x2 | +3 |
  | Temple | Cleric x2, Shield Guardian | +3 |
  | Arcane | Pyromancer, Frost Mage | +3 |
  | Hunt | Archer x2, Crossbowman | +1 |
  | Phalanx | Spearman x2, Shield Guardian | +1 |
  | Shadows | Assassin x2, Crossbowman | 0 |
  | Inferno | Pyromancer, Berserker | +2 |
  | Tavern | Bard, Pitchfork Peasant, Berserker | 0 |
  | Crusade | Cleric, Duelist, Spearman | +3 |

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
- The shop column has two sections told apart by their frames, without labels:
  a merchant stall (striped scalloped awning, wooden frame) holds the three
  creature offers and the reroll; below it, a purple scroll between two
  gold-knobbed rods holds the wand upgrades. The stall and scroll move down
  together (`Hud.layout_column`): centred on the board's height when they fit,
  otherwise as low as the screen allows, and always clear of the round
  frieze. The board's population gems sit in its frame, under the right part
  of each side's edge, clear of the column. The round fight button sits under the board, right of
  the bench (see "Screen layout" below): a medallion split vertically, red on the left and wand
  purple on the right, behind a sword (tip up-left) crossed with a wand (star
  up-right), both outlined in dark. When a click would start the fight, a band of
  light sweeps across it every 4 s (0.72 s sweep) and hovering enlarges it by 7%
  and brightens its gold ring. Otherwise it is grey and still, with a turning arc
  while the opponent prepares.
- When the fight begins, the shop column (stall, scroll) slides off the right
  edge, the fight button drops below the bottom edge and the bench shrinks to half size and docks at the bottom of
  the screen, where hovering it still shows the creature card. Both stay away
  during the result and slide back when the next shop opens (0.45 s each way).
  The scroll then unrolls downward over 0.5 s, each upgrade row appearing as the
  bottom rod passes it, and rolls back up as the column leaves. In the journey
  it holds only the upgrades already introduced (`Hud.upgrade_rect(i, rules)`,
  `Hud.scroll_length(rules)`): no row for the others, and a shorter parchment.
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
- A reroll turns each replaced offer over on a horizontal axis (old offer, plain
  wooden back, new offer, left to right, 0.5 s each); a locked offer stays
  still. A new round's offers are already on the stall as it slides in.
- The reroll button glints only while a reroll makes sense
  (`WizardState.reroll_makes_sense`): nothing left on the stall can be bought,
  the gold covers the reroll and the cheapest creature the stall could deal, and
  there is room for one. With the stall in place and nothing dragged, a band of
  light crosses the button 0.5 s after that starts, then every 3 s; no dimming
  and no sound, so it never makes a reroll feel compulsory.
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
- Shapeshift: one starting charge, max three, one recharged every 3 s.
- Wand upgrades (`Rules.WAND_UPGRADES`), bought with gold in the scroll and kept
  for the rest of the duel; they reset in a new duel, apply to future combats and
  are available to both sides:

  | Upgrade | Icon | Effect | Cost |
  | --- | --- | --- | ---: |
  | Fast recharge | Recharging charge crystal with speed lines | Recharge 3 s → 2.4 s | 4 |
  | Starting charges | Three charge crystals: current starting charges filled, the next one outlined in gold under a gold plus | Combat starts with 2, then 3 charges | 3, then 5 |
  | Healing shift | Wand + green cross | Allied casts heal 25% of new max HP instead of 10% | 4 |
  | Long hex | Wand + stun spiral | Enemy casts stun for 4.5 s instead of 3 s | 4 |

  Hovering a row of the unrolled scroll opens a card to its left with no text
  and no price: the same looping scene plays side by side at the current level
  (dim frame) and the next level (gold frame), restarting with each new hover.
  A maxed upgrade compares its last two levels. Recharge: an empty crystal fills in
  3 s, then 2.4 s. Charges: the starting crystals pop in at combat start. Heal: the
  wand's star flashes on an ally, a green cross appears and its health bar gains
  10%, then 25%. Hex: the star flashes on an enemy, which spins under a stun
  spiral while a ring drains over 3 s, then 4.5 s.

- Shapeshift casts give a 3 s target
  immunity for both wizards; invalid casts consume nothing. Result drawn from the
  eight-stage network, with fixed 55% / 30% / 15% outcome priorities per source
  form (dominant outcome follows its tactical identity). Both casts preserve health
  percentage. Allied casts then heal 10% of new max HP (25% with the healing
  shift upgrade), ready the basic attack,
  cleanse negative statuses and grant +1 level (+20% base HP and damage per level).
  Enemy casts reset the target to temporary level 1, keep its statuses and
  basic-attack cooldown, and stun it for three seconds (4.5 with the long hex
  upgrade). Status effects and
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

## Art styles (19 November 2026)

The game draws two art styles. The pixel art, still in progress, is the default
(since 20 November 2026). **Ctrl+Shift+P** switches to the procedural vector art
in `scripts/ui/icons.gd` and back. An icon at the top right announces the
switch: a smooth ring for vector, a blocky ring for pixel. The choice is saved
in `user://art_style.cfg`, so it stays across restarts.

`scripts/core/art_style.gd` finds every PNG under `sprites/` (any subfolder)
and keeps the artist's file names:

- `<Name>-A.png` is the red enemy team (team 1); `<Name>-B.png` is the blue
  player team (team 0).
- `<Name>` is the creature id in PascalCase (`frost_mage` → `FrostMage`).
  `ArtStyle.FILE_NAMES` lists the exceptions (`crossbowman` → `Crossbow`).
- Each sprite is a full token: a team disc with a 24-pixel radius, centred in
  the image, with the creature on it. The sprite replaces both the vector team
  base and the creature drawing. Sprites use nearest filtering, and a draw
  scale close to a whole number snaps to it.
- A creature without a sprite keeps its vector drawing, so the pixel style is
  always complete. The tests fail when a sprite name matches no creature and team.

All 24 creatures have sprites (humans in `sprites/humans/`, animals in
`sprites/animals/`). Only creature tokens have sprites: status icons, projectiles and
interface icons stay vector in both styles. `res://tests/capture.tscn` takes
the visual smoke screenshots in the pixel style; add `-- --vector-art` for the
vector style.

## Battlefield terrain (20 November 2026)

The board is assembled cell by cell from whole-zone tiles: each tile shows one
kind of ground, with no transition inside it. The terrain is scenery only and
never affects the rules, so it stays quiet. Details keep clear of the cell
centre, where tokens stand. The enemy half is very slightly warmer than the
player half, and a thin line marks the middle. The game has three environments:

| Environment | Tiles | Light family | Dark family |
|---|---|---|---|
| `forest` (default) | 18 | Light grass with a few blades | Darker grass with a few blades |
| `town` | 12 | Desaturated stones of all sizes, softened joints | The same stones, a shade darker |
| `school` | 10 | Slate slab with a chamfered double gold fillet and gold corner studs | Quiet slate slab with an engraved square and gold studs |

In the forest, rarer tiles carry clover or two tiny flowers. The town and the
school keep details quiet. A stage selects the environment of its island when
the duel starts. The hidden **Ctrl+Shift+T** switch still cycles forest, town
and school for comparison; starting the next duel restores its island's terrain.

`scripts/ui/terrain.gd` (`Terrain`) defines the environments. Each one is a
folder `tiles/<environment>/` of 72 x 72 PNG tiles named
`<family>-<kind>-<n>.png`:

- **family**: `light` on cells where x + y is even, `dark` on the others (the
  checker). An environment without `dark` tiles uses its `light` tiles everywhere.
- **kind**: how often the tile appears, from the relative weights in
  `Terrain.ENVIRONMENTS` (forest: grass 0.72, clover 0.2, flowers 0.08). The
  commonest kind is the plain ground; touching cells never share a rarer kind.
- **n**: interchangeable drawings of a kind. Touching cells of the same family
  never repeat a drawing, as long as the plain kind has at least five drawings
  per family.

`Terrain.ENVIRONMENTS` also gives each environment its team tints (each half is
multiplied by its tint, so the tiles hold the brightest colours) and its midline
colour. The layout is seeded (`BoardView.terrain_seed`, fixed so the field looks
the same every game) and composed once into a single image, drawn with one call
per half. The tiles are imported as **Image** resources, not textures, so the
board can be composed from their pixels; set this importer on hand-painted tiles.

`tools/make_terrain_tiles.gd` draws all the tiles from one recipe per
environment (per family: forest five grass, two clover, two flowers; town six
stones; school five slabs). Every drawing is seeded, so a new run rewrites
identical files. It needs a rendering window; import afterwards:

```
godot --path . --minimized --script res://tools/make_terrain_tiles.gd
godot --path . --headless --import
```

To add an environment, add its recipe to the tool (or paint the tiles), drop
them in `tiles/<environment>/` and add its entry to `Terrain.ENVIRONMENTS`. The
tests check that every tile loads as a cell-sized image, that every kind has a
weight, and the layout rules.

## Music

`scripts/audio/phase_music.gd` plays the supplied looping OGG tracks in `default/music/`
only during duels. The menu and world map have no music; preparation music starts
when a stage is selected:

- Pack choice and preparation: `cartoon_magic.ogg`.
- Combat: `marching_beat.ogg`.
- Resolution fades battle music to silence so heart-loss and coin sounds remain
  clear; the next preparation fades its track in. Game over remains silent.

Every playback begins at zero volume and every stop happens only after reaching
zero. Phase changes use a 1.2-second crossfade with a smooth amplitude curve.
Rapid reversals continue from the current volumes; selecting the same track
preserves its playback position. Both streams loop in Godot, and combat x2 does
not change music speed. Music volume is initially -16 dB to leave room for effects.

Music is the game's own system, apart from the sound events below and from
Tuning Fork. `default/music/music.json` holds `volume_db`, `fade_seconds`,
`frenzy_speed_per_level`, `ambience_volume_db` and `ambience_fade_seconds`; unknown keys are reported as warnings. It reloads
when the game window regains focus, and an exported build applies a
`default/music/music.json` beside its executable over the packed values, key by key.

### Map ambience (21 November 2026)

The world map has no music but a nature ambience that follows its sky cycle
(`scripts/audio/map_ambience.gd`, `MapAmbience`, a child of the map). Three
looping beds take their loudness from the four sky states (`SkyCycle.weights`):

| Bed | Day | Golden mist | Dusk | Night |
|---|---:|---:|---:|---:|
| `wind_day` | 1 | 0.75 | 0.35 | 0 |
| `wind_night` | 0 | 0.25 | 0.6 | 1 |
| `crickets` | 0 | 0 | 0.45 | 0.8 |

Short calls come at random, a number of times per minute that depends on the
time of day, never twice the same file in a row, from their island (panned
with `AudioStreamPlayer2D`), with ±2 dB and ±5 % pitch variation:

| Call | Files | Day | Golden mist | Dusk | Night | Shortest gap | Island |
|---|---:|---:|---:|---:|---:|---:|---|
| Bird | 6 | 14 | 8 | 3 | 0 | 1.2 s | Forest or town |
| Wind chime | 3 | 0 | 3 | 1 | 0 | 6 s | School |
| Owl | 2 | 0 | 0 | 1 | 3 | 9 s | Forest |

The ambience fades in over `ambience_fade_seconds` (1.5 s) when the map shows
and out when it hides; it stops once silent, and each visit resumes the loops
at a random point. Its loudness at full presence is `ambience_volume_db`
(-14 dB) in `default/music/music.json`. The menu and duels have none.

Web builds, phone browsers included, play a recording instead
(`MapAmbience.baked`): up to seven Vorbis streams decoded and mixed on the
single-threaded Web build's main thread made the sound crackle and frames drop
on mobile. `default/music/ambience/world_map_cycle.ogg` is this same mix baked
over one 160-second sky cycle by `python tools/bake_map_cycle.py` (which also
writes the Windows workspace's editable copy, see `AUDIO_WORKSPACE.md`). It is
one stream, kept on the sky clock (re-seeked beyond 0.5 s of drift), played
6 dB above `ambience_volume_db` to undo its storage headroom, with the same
fades. The birds' panning towards their island is the only loss.

The sounds in `default/music/ambience/` are synthesised by
`tools/make_map_ambience.gd`: filtered noise winds, pulsed cricket tones,
chirped bird calls, inharmonic chime partials and vibrato owl hoots, 22,050 Hz
mono. The beds are 32-second loops whose tail is crossfaded into their start.
Every sound is seeded, so a new run rewrites identical files. It needs oggenc:

```
godot --path . --headless --script res://tools/make_map_ambience.gd
godot --path . --headless --import
```

Recordings can replace these files under the same names.

## Sound effects

Sound effects are Tuning Fork sound events, defined in
[`tools/tuning_fork/docs/`](../../tools/tuning_fork/docs/Home.md). The runtime
is the addon `addons/tuning_fork/` (autoload `Sfx`), which knows nothing about
this game: the game calls `Sfx.play("<path>")`, and `Sfx.stop("<path>")` for
the looping bard song.

An event is `default/sfx/<folder>/<name>.json` with one or more OGG Vorbis files beside
it, `<name>.ogg` then `<name>_2.ogg`, `<name>_3.ogg`...; its path is
`<folder>/<name>`. Every event under `default/sfx/` is found by itself; adding a
numbered file adds a take the game picks among. A different use of a sound,
even slightly, is its own event; `files_from` lets an event play another
event's files with its own settings instead of copying them. The first
versions were rendered once from the former procedural synthesis (22,050 Hz
mono).

How each event plays is data, not code. Its JSON file holds:

| Key | Meaning |
|---|---|
| `description` | When the game plays the event (for reading only) |
| `group` | Mixing group from `default/sfx/groups.json`: `effects` or `ui` |
| `loop` | Plays until stopped instead of once |
| `protected` | Plays on a voice of its own that no other sound can take |
| `files_from` | Plays the files of this other event instead of its own |
| `volume_db` | Loudness in dB (0 = as recorded) |
| `volume_jitter_db` | Random loudness change per play, up to ± this many dB |
| `pitch` | Playback pitch (1 = as recorded); pitch also changes speed |
| `pitch_jitter` | Random pitch change per play, up to ± this amount |
| `cooldown_ms` | A repeat of the same event sooner than this is skipped |
| `pick` | How each play chooses among the files: `shuffle` or `random` |
| `shuffle_refill_after` | `shuffle` only: deal the files again after this many plays (0 = after all) |

With `shuffle`, every file plays once in a random order before any plays again;
`shuffle_refill_after` above 0 deals the files again sooner, so fewer plays pass
before a file can return. A new deal never starts with the file just played.
With `random`, each play draws any file, repeats included. An event with one
file always plays it. Missing keys fall back to `Sfx.SOUND_DEFAULTS`; unknown
keys are reported as warnings. A path with no event, or an event without a
file, plays nothing and warns once.

`default/sfx/groups.json` lists the groups and their volume in dB; each group is a
Godot audio bus of that name sent to Master. `Sfx.set_group_volume(group, db)`
adds the game's own change (an options menu, for example).

[Tuning Fork](../../tools/tuning_fork/README.md) (`tools/tuning_fork`) edits
these files without opening them. Its copy of the defaults, file naming and
playback rules must follow any change to `addons/tuning_fork/sfx.gd`.

In a run from the Godot editor, the addon reads `default/sfx/` straight from disk:
settings, groups, sound files and events saved while the game runs reload when
the game window regains focus.

The Windows build can be re-voiced and re-tuned without Godot.
`export_windows.ps1` exports `export/ShapeshiftersDuel/` and
`export/ShapeshiftersDuel-Windows.zip` at the repository root:
`ShapeshiftersDuel.exe`, an `default/sfx/` folder with every event's `.json` and `.ogg`
files and `groups.json`, plus a `README.txt` explaining the values, and
`default/music/music.json`. The executable carries the game icon, `icon.ico`, which the
script first regenerates from `icon.svg` with `tools/make_windows_icon.gd`; after
changing `icon.svg`, run that script before exporting from the editor. An
exported desktop build reads these files beside its executable on top of the
packed ones: the sound files of an event there replace all its packed files (so
files can be added or removed there too; once none is left, the packed files
play again), a JSON file applies over the packed values key by key, and an
event that exists only there plays too. Changed files reload when the game
window regains focus; an unreadable file keeps the current version. Web builds
use only the packed files and force Godot's Stream playback for both music
and effects (`audio/general/default_playback_type.web = 0`), bypassing the
browser's default Sample playback. This override does not affect Windows.
Approved replacements
are copied back into the project's `default/sfx/` and `default/music/` folders.

| Event | Group | Played when |
|---|---|---|
| `ui/map_step` | ui | Soft, muffled tap as a new journey-path point appears |
| `ui/map_opponent_appear` | ui | The next journey opponent springs out of the ground at the end of its path (plays the files of `coins/pop`, lower) |
| `ui/clouds` | ui | Clouds roll over the screen between the journey map and a duel, and again as they part (two synthesised takes, `tools/make_cloud_whoosh.gd`) |
| `ui/click` | ui | Interface click: difficulty, picking up or reselecting a creature, offer lock, enemy reroll, restart |
| `ui/fail` | ui | Unavailable or invalid action, such as a locked difficulty, fizzled cast or invalid drop |
| `ui/buy` | ui | Starting composition, player sale, enemy purchase or wand upgrade |
| `ui/battle_start` | ui | A fight successfully starts (plays the files of `ui/click`) |
| `ui/place` | ui | The player drops a creature into a new board cell or reserve slot (plays the files of `ui/click`) |
| `ui/purchase_confirmed` | ui | The player spends gold on a creature, shop reroll or wand upgrade (plays the files of `ui/buy`) |
| `ui/insufficient_gold` | ui | The player cannot afford a creature, shop reroll or wand upgrade (plays the files of `ui/fail`) |
| `ui/combine` | ui | Merge without a new star |
| `ui/merge` | ui | Merge that grants a star |
| `ui/difficulty_unlock` | ui | The lock of a newly unlocked difficulty opens |
| `coins/gain` | effects | Coin received from an enemy sale |
| `coins/harvest/1` to `/8` | effects | Landing harvest coins 1 to 8 of a peasant, each higher; later coins replay `/8` |
| `coins/compensation` | effects | Coin given for a lost heart |
| `coins/pop` | effects | A peasant pops its harvest coins at the start of combat |
| `combat/hit` | effects | Melee hit, dive, charge, fireball impact |
| `combat/shoot` | effects | A projectile is fired |
| `combat/death` | effects | A creature dies |
| `abilities/hop` | effects | Rabbit leap |
| `abilities/fear` | effects | Skunk fear burst |
| `abilities/blizzard` | effects | Blizzard cast |
| `abilities/bard_song` | effects | Bard song, looping while a bard sings |
| `shapeshift/bless` | effects | A caster transforms and heals a creature on their own team (Transform 2) |
| `shapeshift/hex` | effects | A caster transforms a creature on the opposing team (Transform 3) |
| `duel/heart_break` | effects | A half-heart breaks after a lost round |
| `duel/victory` | effects | Final duel victory |
| `duel/defeat` | effects | Final duel defeat |

Playback details that replacement sounds should allow for, with the shipped
settings:

- Effects get a random pitch variation (±8 % by default) on every play. Pitch
  also changes speed: a higher pitch plays shorter.
- The same event cannot restart within 40 ms; at most 10 effects play at once
  (a fixed limit of the runtime, not a setting); looping and protected events
  have voices of their own.
- `abilities/bard_song` has `loop` on: it starts from its beginning on a bard's
  first song beat, repeats while a living bard (either team) sings, and fades
  out over 0.25 s once none does or the combat ends. It plays without random
  variation, at any length. The shipped 8 s loop renders the former bard
  melody (C D E G A G E D, one note per second) from the old single note.
- `coins/harvest/2` to `/8` play the file of `coins/harvest/1` (`files_from`),
  each 0.07 higher in pitch than the one before.
- The coin sounds started as copies of the same recording, with their former
  variant settings: harvest coins ±2 % pitch, `coins/compensation` ±5 %.

The final duel result uses `duel/victory` when the opponent has no hearts left
and `duel/defeat` when the player has no hearts left. These recordings start
only on entering the game-over screen, after the final heart-loss sequence.
Intermediate rounds and draws play neither recording; heart and coin effects
provide round feedback. Each recording plays once at its original pitch and is
`protected`, so effects cannot cut it. Music has faded out during resolution
and stays silent at game over.

### Sounds restored (21 November 2026)

The sounds from before the duel sound effects of 14 November 2026 (commit
`b770cb4`) are the game's sounds again, at the user's request after a
playtest: `combat/hit` (a single take again), `duel/victory`, `duel/defeat`,
`shapeshift/bless`, `shapeshift/hex` and `ui/click` have their earlier file
back, and the files of that day were deleted. The four events added that day
play, through `files_from`, the file the game used for the same moment before,
with a ±8 % pitch variation: `ui/battle_start` and `ui/place` play `ui/click`,
`ui/purchase_confirmed` plays `ui/buy` and `ui/insufficient_gold` plays
`ui/fail`. The Ctrl+Shift+S comparison with the earlier set and its
`default/sfx_legacy/` folder are gone. The source recordings of 14 November stay in
`audio_sources/`.

## Choices made for this prototype (3 November 2026)

Answers given by the user while scoping the implementation:

- Procedural shapes and icons only, as little text as possible (rule for all prototypes).
- Top-down camera, synthesized sound effects, icon-based interface. (14 November
  2026: the effects were rendered once to OGG files so they can be replaced.)
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
  eagle dive damage also increases. Porcupine gains durability for its thorns.
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
  Inspiration outlasts the bard's death until it expires. From the first beat,
  the looping bard song plays while a bard sings. A golden sound wave leaves the bard and a note
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
  It buys wand upgrades from its own gold, one level at a time, in the order
  fast recharge, both starting-charge levels, long hex, healing shift. It avoids sacrificing a
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

## Journey map and difficulty levels (20 November 2026)

The game opens directly on `world_map.tscn`. The entire journey fits on one
screen, with no scrolling, banner or progress HUD. The islands form a triangle:
forest and town below, magic school above, with clear sky between their silhouettes.
Portrait uses a taller triangle and scales the whole map to fit. A rope bridge
on stone piers, its handrails swagging between posts and a lantern on each end
post, links forest to town; floating crystal steps rise in an arch from the
keep's roof, beside the king, to the school courtyard (`map_bridge.gd`; both
share their walking line, `point_at`, with the routes). Routes follow curved
trails and the bridges. Their dots keep one even spacing (`DOT_SPACING`, at
least `MIN_DOTS`, capped at `MAX_DOTS` on the long crossings), so short hops
show a few dots; each route stops at the edge of the opponents it joins (their
ground ring, and above them up to past the head: `in_footprint`). Waypoints in
`ROAD_VIAS` steer a route around homes and landmarks (past the lumberjack's
door, in front of the tower and below the archmage's rune circle), and the road
to the king ends at his keep's gate (`ROAD_ENDS`). The tests check every route
in both orientations: even, non-overlapping dots, none on an opponent, and no
two routes side by side.

Each island draws its scenery around its opponents' spots (`MapScenery`,
`scripts/ui/map_scenery.gd`, given the spots by the map): every opponent has
a home, a prop or both (see the design note's "Island scenery" table), a few
firs dot the forest, the tower stands in the school courtyard, and the forest's
waterfall pours out of a jagged opening behind hanging roots in its cliff, then
vanishes into drifting mist. The king stands on top of his keep
(`world_map.KING_SPOT`); the archdruid guards the rope bridge.
The menu is the title island, left of the forest, joined to it by a rope bridge (see "Title"
below). Selecting an opponent starts the duel; completed stages stand
on a soft gold ring, without a star. Unknown opponents and routes have no visible markers,
silhouettes or padlocks. The protagonist does not appear on the map. Controls use
icons and animation only, including hover feedback: no labels or textual tooltips.

The three floating territories are a forest, a fortified medieval town and a
magic school. The town has curtain walls, crenellated towers, a keep, dense
pitched-roof houses and paved streets. Islands and scenery are drawn in code.
Each stage selects its island's existing battlefield tiles when the duel starts:
stages 1-5 use `tiles/forest/` grass, stages 6-10 use `tiles/town/` stone paving,
and stages 11-15 use `tiles/school/` violet slabs with gold inlays. The terrain remains
through preparation, combat and subsequent rounds. Starting a different island's
duel replaces the cached board; direct developer/test duels use the forest default.
The mapping lives in `OpponentDB.zone()` and `Journey.ENVIRONMENTS`. Each side starts
with 3, 6 or 10 full hearts respectively (`Journey.HEARTS`); hearts reset for every
duel. AI health-dependent decisions use the fraction of that duel's capacity.
These are confirmed design decisions, recorded with their rationale and remaining
implementation work in [Prototype 02 — Journey roadmap and progression](../../docs/design/Prototype%2002.md#journey-roadmap-and-progression--confirmed-20-november-2026).

The sky runs a 160-second local cycle: clear blue daylight, golden mist,
rose-and-mauve dusk, starry night, then back to daylight. Colours blend smoothly,
clouds drift slowly, and the moon and stars fade in at
night. Island colours and interaction markers remain readable throughout. The
clock pauses while the map is hidden and resumes on return; it is decorative
and does not alter combat. `scripts/ui/day_night_sky.gd` exposes `cycle_seconds`
for adjusting the duration. `scripts/ui/world_map.gd` owns navigation and layout;
`scripts/ui/map_island.gd` draws the floating land masses.

The linear journey contains fifteen opponents, five on each unchanged island. A fresh map shows
only the first opponent. Winning a full duel completes that stage and discovers
its immediate successor. On return to the map, the curved route draws itself
point by point in about four seconds, with soft taps (`ui/map_step`) as the dots
appear. Both complete bridges are always present from startup; only the dots
animate across their decks. At the end of the route the next opponent springs
out of the ground (`world_map.gd`, `APPEAR_DURATION`): a gold ring opens on a dark
hole, the opponent shoots up through it (cut at the ground line while it rises),
stretching, hops slightly and lands with a short squash, while a shock wave
leaves the ground and bits of the island fly out: leaves in the forest, stone
chips and rolling dust in the town, gold and violet sparks at the school. A pop
(`ui/map_opponent_appear`) marks the jump. The opponent becomes selectable once
it stands, 4.4 s after the trace began; the bits settle a moment later.
Revisiting the map keeps known paths in place; leaving pauses an unfinished trace.
A defeat discovers nothing. Completed stages remain replayable. Old branching
saves are migrated to preserve their furthest earned stage. Every stage starts a
fresh duel; forest uses the small learning compositions described below.

Stages 1-5 use guided learning behaviour, 6-10 use Adept, and 11-15 use Archmage. The
full-length characters in `OpponentDB` replace the old creature markers. Each
introduces one existing rule; `Ruleset` applies the cumulative rules to both
sides, limits creature offers and openings, and hides unavailable controls.
An action that belongs to a rule not met yet gives no feedback at all: before
the hex, clicking an enemy during a fight neither fizzles nor plays `ui/fail`;
before trading, right-clicking an offer to lock it is silent too.
Characters without magic never cast. The Hunter teaches placement; the Druid
introduces the wand in encounter 2, the Lumberjack introduces the shop in encounter
3, and the Swamp witch introduces hexes. The town introduces trading,
harvest, merging, casters and frenzy; the school introduces the wand upgrades.
The enemy panel uses the selected opponent's portrait. See [Journey and
Opponents](../../docs/design/prototype_02/Journey%20and%20Opponents.md) for all
fifteen characters and their starting compositions.

Forest is a safe introduction, not a challenge. Only archer, shield guardian and
spearman humans, and rabbit, wolf and deer animals may appear there. This covers
starting teams, shop offers and both wizards' transformations. Three small player
teams use these humans; enemies field fixed armies that grow by one creature
per lesson, from one to five (`OpponentDB.FOREST_ARMIES`), and never shop. Magical enemies demonstrate one cast after six seconds per round.
Damage cannot kill the player's last creature in forest; normal battles retain
lethal damage. The empty bench and its drop targets stay hidden until shopping.
An animated wand invites the first allied cast, then the first enemy cast. The
allied cue never aims at the tank (the shield guardian) while another ally can
take the cast: it picks the least armoured ally, the farthest from the enemies
on a tie, and the tank only as the last creature left. In
the druid's and the swamp witch's duels, combat stops while that cue waits and
resumes once the player has tried the cast (`awaiting_learning_cast()` in
`main.gd`). The cue appears only in those two duels, until that cast has been
tried once (saved as `journey.lessons_done`). The hunter has a single heart (`"hearts"` in `OpponentDB`), so the
first duel ends after one won round.

`Ruleset.FOREST_OUTCOMES` is an explicit closed six-form practice graph, using the
normal 55/30/15 priorities. Rolls, hover previews and AI evaluations use the duel's
graph (`Ruleset.roster`). The town adds the cleric, assassin and bard, plus the
turtle, porcupine and peacock, to the forest's six forms; peasants and the two
casters also belong to it, behind their own rules. `Ruleset.TOWN_OUTCOMES` is the
town's closed fifteen-form graph, in which forest forms keep their most likely
forest outcome. Town openings and player cards come from `OpponentDB.TOWN_PACKS`.
Only the school opens every creature and the complete eight-stage graph.

Opponents stand at natural spots on their island (`ZONE_SPOTS` in `world_map.gd`):
forest clearings, town streets up to the keep, the school courtyard up to the tower
door. Those further back are drawn slightly smaller, and the road winds between them.

The first time a rule shows up in a journey duel, `RuleSpotlight` dims the screen
around the new element, rings it in gold with orbiting sparkles, and lifts the
dimming after about 2.7 seconds, without text or blocking input. Interface rules
are shown as soon as their element is on screen (stall, upgrade row);
the others when they happen: charge crystals at the druid's first fight, the first
enemy creature for hexes, the first allied bonus shapeshift, the first harvest,
the first mergeable pair, the first caster channelling, and the timer bar when
frenzy starts. Combat slows to a quarter speed while the dimming is full.
Trading (the merchant) has no spotlight: lighting the reroll button as the stall
opened pushed a pointless reroll. The reroll button's glint, played only while a
reroll makes sense (see the shop rules above), shows it instead.

The harvest shows the coin rather than the peasant: the opening starts on a
harvester (the player's first one when it has any) and its coin fan, follows its
coins along their flight (`Hud.harvest_spotlight`, passed to `RuleSpotlight` as
a tracking callable) and rests on the purse, framing the coin icon, the counter
and a rising "+N", the gold that harvester earned. That first harvest plays at
0.6 speed (`Hud.HARVEST_LESSON_SPEED`), and the dimming lasts until the light
has rested on the purse for 0.9 s. Shown
rules are saved under `journey.introduced`; beaten opponents never replay theirs.
Merge pips and harvest coins appear only in duels where their rule exists.

The thief's duel deals the player a fixed opening instead of a choice of
compositions (`"player_pack"` in `OpponentDB`, read by `OpponentDB.player_pack()`):
three shield guardians in the front line and two more coins. A looping
demonstration (`main.merge_demo()`, drawn by the HUD) flies the two outer
guardians in turn along dotted gold arcs into the middle one, whose merge pips
fill to three before a star pops above it. With fewer copies it shows a pair
or an identical offer. It plays until the player's first star there, ever
(saved in `journey.lessons_done`).
The board holds at most six creatures (`Rules.FIELD_CAP`): when it is full,
empty cells stay dark under a drag, the rims of the player's population gems
turn red, and a refused drop makes them blink.

Progress is saved locally in `difficulty_progress.cfg`, under `journey.opponents`.
The previous seven-stage `journey.completed` saves retain proportional advancement
inside each zone, including access to the school. Older difficulty-only saves
retain their unlocked zones. **Alt+Shift+R** on the menu or map resets progression;
click the game first in a browser. **Ctrl+Shift+R** remains available on desktop,
but browsers reserve it for reloading the page without clearing saved progress.

- **Archmage** plays its own tuned strategy (`EnemyAI.ARCHMAGE_PROFILE`), with
  the same rules, gold and information as the player: it draws its opening from
  its deck like every level, fields peasants for their harvest while it has hearts to spare, values
  crossbowman seeker-bolt chains, spreads its frontline from the board edges,
  counts the level reset when choosing hex targets, and rerolls on budget.
- **Adept** and **Apprentice** follow the same rules, gold and spell charges as
  the player. They only decide worse: noisier shop scoring, fewer rerolls, a later
  (adept) or no (apprentice) wand upgrades, no locks, no selling to replace
  (apprentice), naive field selection (apprentice), and slower, less selective
  casting that sometimes targets a random creature (15% adept, 40% apprentice).
- The **Apprentice** also has whims: at its first shop of a duel it draws a
  lasting taste for each creature (up to ±120 value, against creature values of
  about 23-63 unstarred). The taste counts both when buying and when choosing
  who to field, so it builds odd but consistent teams (three clerics, a field of
  peasants, a benched starred creature it dislikes) while still merging copies.
- **Sparring** (`Difficulty.SPARRING`) is never offered in the game. It keeps the
  Apprentice settings from before whims as a fixed reference for balancing.
- A journey opponent can play its level's strategy with a few keys of its own
  (`"ai"` in `OpponentDB`, stored in `WizardState.ai_overrides`; the AI and the
  battle read `EnemyAI.profile_of(state)`). The thief sets `"max_starred": 2`:
  past two creatures with a star, it neither merges unstarred copies nor buys
  copies to merge, so it no longer out-merges the player it teaches.

Apprentice calibration (13 November 2026, `training/arena.sh`, live rules):
the Apprentice beats Sparring 23.9% of 1,760 duels (whims ±60: 32%, ±100: 26%,
±130: 23%). Against the Adept it wins 4.4% of 880 duels, where Sparring wins 13.6%.

```bash
prototypes/prototype_02/training/arena.sh '{"level":0}' '{"level":3}' 22 80 7
```

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

## Archmage strategy arena (13 November 2026)

`training/arena.tscn` plays complete AI-vs-AI duels with the live rules (peasant
harvest included), each seed from both sides with exchanged shop generators.
`training/arena.sh` runs it in parallel; `training/climb.sh` compares one-change
variants against a champion profile. Neither is part of the regression tests.

```bash
prototypes/prototype_02/training/arena.sh '{"level":2}' '{"level":1}' 22 10 1
```

A side is `{"level": 0-3 (3 = Sparring), "profile": {EnemyAI key overrides}, "cast": {Difficulty
casting overrides}}`. With the tuned profile, the Archmage won 220/220 duels
against the Adept and 220/220 against the Apprentice (previously about 75% and
96%); the tuning chain beat the previous Archmage strategy about 89% of the time.

## Starting composition balance (13 November 2026)

`training/pack_matrix.sh` plays every pair of starting compositions in
Archmage-vs-Archmage duels (each seed from both sides) and prints each
composition's score against the others plus the full matrix. An optional JSON
override tries other contents or bonuses without editing the data; `FIELD=n`
scores appended variants against the first n compositions only. Run it on
demand, not as a regression test.

```bash
prototypes/prototype_02/training/pack_matrix.sh 200 22 6 2
```

Shop prices proved a poor guide. With nominal value 6 for every composition,
peasants dominated: three peasants and a spearman scored 83%, two peasants with
a bard and a berserker 76%, and compositions without a peasant 34-53%. Starting
with three identical peasants merges them into a one-star harvester at once
(72% with no bonus); even one extra spearman beside two peasants added about
11 points, because a strong first board saves hearts. One bonus gold is worth
roughly 4-10 points. The tuned table above scored between 45% and 54% against
the others over 13,200 duels (Raid lowest at 45.3%, before it was raised from +2
to +3 gold, which brought it to 51.8% over 2,200 more duels).

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
sound events, groups, files shared with files_from, missing-event warnings,
replacement files beside the executable and sound files saved
during an editor run,
round reset, several
abilities, then simulates 20 AI-vs-AI duels with and without casting and prints
the average combat and duel lengths.

Pass `-- --no-sound` after any Godot command line (game included) to mute all
audio, music included.

To find which file a sound heard in the game comes from, tick Project Settings >
Audio > Tuning Fork > Log Plays and run the game: the Output panel then shows a
`[Sfx]` line per sound event played, with the file it played. Untick it when
done. Release exports never print it.

A separate, on-demand balance suite (parallel 1v1 duels between all forms, CSV/JSON
rankings) lives in [`balance/`](balance/README.md). It is not part of these tests
and runs only on explicit request.

`res://tests/capture.tscn` (not headless) plays a scripted sequence of the real game
and saves screenshots to `user://captures/`. With `-- --check-redraw` it also checks
after each screenshot that no cached layer is out of date (see below).

### Performance

`res://tests/perf_benchmark.tscn` (not headless, about five minutes) plays the real
game by itself: menus, an automated duel of six rounds where both wizards shop and
cast, then a 6-versus-6 fight of three-star casters. It records every frame and
prints, per scenario, the average, median, 95th/99th percentile and worst frame
times, the frames over 16.7 ms and 33 ms, the slowest frames with the events around
them (casts, deaths, sprite loads, purchases, audio gaps), and node, object and
memory counts at each phase change. It writes the report and the per-frame data to
`user://perf/` (or `--out=<file.json>`). Vsync is off by default, which measures the
true cost of a frame; `--vsync` measures dropped frames at the display refresh
instead. Other options: `--rounds=<n>`, `--vector-art`, `--no-sound`, and
`--check-redraw` (below).

```bash
godot --path prototypes/prototype_02 res://tests/perf_benchmark.tscn -- --no-sound
```

`tools/web_benchmark.mjs` runs the same benchmark in a browser, where performance
differs most: it exports the **Web Benchmark** preset (the Web preset with the tests
and `tests/perf_benchmark.tscn` as main scene, through the `web_benchmark` feature),
serves it locally, plays it in a fresh Edge or Chrome window with the sound on and
prints the report, plus the WebGL buffers and vertex arrays created per frame and the
audio gaps (128-sample blocks the browser played as silence because the main thread
had not mixed them in time: the crackling heard when frames are slow). Laptops
usually give browsers their integrated GPU, which the script keeps by default;
`--gpu=high` asks for the high-performance GPU. Needs Node 22 or later; the report
goes to the system temporary folder.

```bash
node prototypes/prototype_02/tools/web_benchmark.mjs --rounds=3
```

How the game keeps frames cheap:

- **No polygons rebuilt every frame.** Godot builds a GPU vertex buffer and vertex
  array for every `draw_circle`, `draw_arc`, `draw_polyline`, antialiased
  `draw_line` and polygon each time a canvas item redraws. Natively that is cheap;
  in a browser each call crosses the WebGL layer, and the Web build ran at 19 fps
  in combat on an integrated GPU with constant audio crackling. `Shapes`
  (`scripts/ui/shapes.gd`) replaces those calls with rectangles cut from one atlas
  (antialiased disc, rings of 16 thicknesses, a line band, a star and hearts), which
  Godot batches without per-frame buffers. Draw through `Shapes.circle`, `arc`,
  `line`, `polyline` and `set_transform` rather than the `CanvasItem` methods.
  The atlas is `ui/shapes_atlas.png` (imported with mipmaps), drawn by
  `Shapes.build_image()`; after changing a shape, run
  `godot --headless --path . --script res://tools/make_shapes_atlas.gd`. The tests
  fail while the file and the code differ.
- **Static and slow-changing layers redraw only on change.** The table background
  is drawn once; the board terrain sits in a child layer drawn once; the tokens and
  bench (`BoardView`), the side panels and the shop column (`Hud` layers) redraw
  only when the values they show change (their `_redraw_key`, `_layer_key`). The
  round frieze, phase screens, hover card, rewards, combat units and effects still
  redraw every frame. When adding something to a cached layer, add what it depends
  on to that layer's key. `--check-redraw` (benchmark and capture) catches a
  forgotten dependency: it freezes time, hides the layers that redraw every frame,
  forces every canvas item to redraw and reports any pixel that changed
  (`tests/redraw_check.gd`).

Latest results (20 November 2026, Windows, i7-14650HX, pixel art):

| Build | Menus | Preparation | Combat (avg / 99th pct / worst) | Audio gaps |
|---|---|---|---|---|
| Windows, RTX 5070 Laptop, before | 3.5 ms | 3.6 ms | 5.7 / 7.5 / 9.6 ms | – |
| Windows, after | 1.0 ms | 1.2 ms | 1.75 / 2.3 / 6.5 ms | – |
| Web (Edge), Intel UHD, before | 32 ms | 32 ms | 52 / 66 / 74 ms | 32,698 |
| Web (Edge), Intel UHD, after | 6.9 ms | 6.9 ms | 6.9 / 7.9 / 10.8 ms | 0 |

Web frames are capped at the 144 Hz display refresh (6.9 ms). WebGL vertex arrays
created per frame fell from 480 to 18. No frame over 16.7 ms outside start-up, node
and object counts stay flat across rounds, and the cached layer check found no stale
layer in 126 benchmark checks and every capture screenshot.

Latest simulation (20 AI-vs-AI duels per mode, after the combat/AI rebalance):
combats average about 25 s with casting and 19 s without; duels average 11.7 and
9.2 rounds respectively. The half-heart rule gives purchases, merges and the
permanent recharge upgrade more rounds to matter.
