# Journey and Opponents — Prototype 02

## Status

Confirmed direction, decided with the user on 20 November 2026. The journey map
and its opponents are the way the existing rules are taught, one at a time.
Values that are only implementation defaults are marked as such.

Related notes: [[Prototype 02]], [[Roster and Transformation Map]],
[[Economy and Progression]], [[Art Direction]].

## Principles — confirmed

- **The player is a mage.** Opponents are other players of the duel: mages,
  druids, witches, but also people without magic.
- **Opponents are not creatures.** Each opponent is a complete character with its
  own silhouette, drawn full length, never as a creature token. Rabbits, peasants,
  archers and the other forms remain creatures.
- **Opponents add no rules.** No opponent has a special power, bonus gold or any
  other mechanic of its own. There are already enough rules; the journey exists to
  introduce the current rules gradually, never to add new ones.
- **One rule per opponent.** Each opponent introduces exactly one existing rule
  (or one small group of closely related rules). A duel uses only the rules
  introduced by its opponent and by the opponents before it, for both wizards.
- **With or without magic.** Some opponents are wizards and shapeshift; others
  have no magic and never cast. An opponent without magic follows the same rules
  as the player; it simply never uses the wand.
- **Linear zones.** Three zones of five opponents. Inside a zone the opponents are
  played in order; every opponent must be beaten to finish the zone. The fifth
  opponent of a zone opens the next zone. Beaten opponents remain replayable.
- **No interface text.** On screen, opponents are recognised by their drawing; rules
  are shown through icons, as everywhere else ([[Art Direction]]).

## The fifteen opponents — confirmed

| # | Zone | Opponent | Magic | Rule introduced | Opening |
| ---: | --- | --- | --- | --- | --- |
| 1 | Forest | Hunter | No | Placing creatures, automatic combat, hearts lost per surviving enemy | One wolf |
| 2 | Forest | Druid | Yes | The wand: shapeshifting one's own creatures (blessing), charge crystals | Deer and wolf |
| 3 | Forest | Lumberjack | No | Creature shop: buying, income every round, gold for lost hearts | Two spearmen and a wolf |
| 4 | Forest | Swamp witch | Yes | Hex: shapeshifting and stunning enemy creatures | Two wolves, a deer and an archer |
| 5 | Forest (boss) | Archdruid | Yes | Animal bonuses after an allied shapeshift (rabbit leap within the forest roster) | Two wolves, two rabbits and a spearman |
| 6 | Town | Merchant | No | Selling, rerolling and locking offers | Troupe |
| 7 | Town | Innkeeper | No | Peasants and their harvest | Tavern |
| 8 | Town | Thief | No | Merging three identical creatures into a star | Shadows |
| 9 | Town | Court mage | Yes | Casters (pyromancer, frost mage) and cancelling their spell by shapeshifting them | Arcane |
| 10 | Town (boss) | King | No | Frenzy after 45 seconds | Crusade |
| 11 | School | Apprentice | Yes | Wand scroll: fast recharge | Village |
| 12 | School | Caretaker | No | Wand scroll: long hex | Phalanx |
| 13 | School | Adept | Yes | Wand scroll: starting charges | Fortress |
| 14 | School | Transmutation teacher | Yes | Wand scroll: healing shift | Inferno |
| 15 | School (boss) | Archmage | Yes | Nothing new: the complete game | Random, from its deck |

### Zone themes

- **Forest:** a gentle introduction without challenge. Placement comes first,
  then the wand with the druid, then shopping with the lumberjack. The player
  keeps the wand against the lumberjack, who never casts.
- **Town:** managing an army (trading, harvest, merging), casters and frenzy.
- **School of magic:** the four wand upgrades of the scroll, then the archmage.

### Characters

Visual descriptions used by the procedural drawings (`Icons.opponent`):

- **Hunter:** feathered brown cap, green tunic, longbow and quiver, horn at the belt.
- **Lumberjack:** red checked shirt, ginger braids, axe over the shoulder.
- **Druid:** green hooded robe, white beard, crown of leaves, leafy staff.
- **Swamp witch:** ragged dark-teal robe, crooked hat with a red mushroom, pale
  green skin, a snake and a glowing potion.
- **Archdruid:** bark cloak with moss, antlers, long moss beard, glowing green
  eyes, an owl on the shoulder, a pale green aura.
- **Merchant:** headscarf, blue dress with an apron, a large gold coin and a purse.
- **Innkeeper:** bald, moustache, round belly, apron, a foaming tankard.
- **Thief:** slate hood, black eye mask, dagger and a bag of gold.
- **Court mage:** crimson robe trimmed with gold, tall crimson hat with a gold
  band and crown motif, black goatee, a wand with fire and frost sparks.
- **King:** golden crown, red cape with an ermine collar, brown beard, sceptre.
- **Apprentice:** the apprentice hat (patched, drooping felt), oversized faded
  robe, freckles, a wand that sputters.
- **Caretaker:** grey-blue overalls, flat cap, grey moustache, broom and key ring.
- **Adept:** the adept hat (tall blue, gold band and star), blue robe, a book.
- **Transmutation teacher:** dark-teal robe and bent-tipped hat with a silver
  buckle, square glasses, grey bun, a wand drawing a spiral.
- **Archmage:** the archmage hat (curled purple, moon, jewelled band), long white
  beard, starry purple robe, staff with a glowing orb, a purple aura.

The apprentice, adept and archmage wear the three existing difficulty hats, now
with the whole character under them.

## Forest learning encounters — revised 20 November 2026

The user's opening playtest found the hunter uninteresting: too few choices,
an unused bench and no shop. The revised direction introduces transformations
before shopping, keeps the lumberjack extremely simple, and makes the entire
island safe to explore without losing. These are learning encounters, not a
difficulty test. The hunter must field animals only.

The forest roster is thematic, not a general tier system:

- Humans: **Archer, Shield Guardian, Spearman**.
- Animals: **Rabbit, Wolf, Deer**.
- No other creature may appear in either opening, either shop or a transformation
  by either wizard. The town widens this roster (below); only the school opens
  every creature.

Current implementation defaults, available for playtest revision:

- Three small starting choices: guardian + two archers; guardian + two spearmen;
  guardian + archer + spearman. No bonus gold. All creatures start on the board.
- Opponents use small fixed armies. They never buy, replace, merge or optimise
  their army. **Revised after playtest (20 November 2026):** single-creature
  armies were too trivial; each lesson now fields one creature more than the
  previous one, a gentle rise in difficulty (confirmed request; the armies are
  implementation choices): hunter a wolf; druid a deer and a wolf; lumberjack two
  spearmen and a wolf; swamp witch two wolves, a deer and an archer; archdruid two
  wolves, two rabbits and a spearman. The first three fall to the player's
  opening alone; the witch and the archdruid need purchases. In simulation a
  player buying whatever is affordable, without casting, beats the witch in two
  rounds and the archdruid in six or seven. An archdruid army with a healing
  deer stalemated every round, so the boss has none.
- Magical opponents demonstrate at most one cast per round, after six seconds:
  an allied transformation before hexes, an enemy transformation afterwards.
- Normal damage and creature deaths remain visible, but damage cannot kill the
  player's last creature. The safety net applies only in forest encounters;
  timeout remains a draw. It prevents defeat without requiring a successful cast.
- Hide the empty bench before the shop and disable its invisible drop targets.
  Show it with shopping, or if reserves already exist.
- An animated wand and target ring invite an allied cast from the druid, then an
  enemy cast from the witch. The cue stops after the corresponding player cast.
  No lesson popup blocks progress.
- **Confirmed after playtest (20 November 2026):** the hunter has a **single
  heart**, so the first duel ends after one won round; the player keeps the
  forest's three.
- **Confirmed after playtest:** in the druid's duel, combat time **stops while
  the cast cue waits** and resumes once the player has tried the allied cast, so
  the lesson cannot be passed by doing nothing. The swamp witch's duel does the
  same for its hex (implementation choice, same reasoning).
- **Confirmed after playtest:** the invitation ring appears only in the duel
  that teaches its cast and only until the player has tried that cast once,
  ever (saved as `journey.lessons_done`). It no longer appears with the
  lumberjack or the archdruid, nor when replaying the druid or the witch.

### Closed forest transformation graph

Filtering shop offers alone would still expose the full roster through casting.
The forest therefore uses this explicit practice graph. Each row lists outcomes
in **55 / 30 / 15 percent** order; previews and rolls use the same graph.

| Form | 55% | 30% | 15% |
| --- | --- | --- | --- |
| Archer | Rabbit | Wolf | Deer |
| Shield Guardian | Deer | Wolf | Rabbit |
| Spearman | Wolf | Rabbit | Deer |
| Rabbit | Archer | Spearman | Shield Guardian |
| Wolf | Spearman | Shield Guardian | Archer |
| Deer | Shield Guardian | Archer | Spearman |

This is an intentional island-specific departure from the complete eight-stage
graph: forms can return after two casts. The roster restriction is confirmed;
these particular routes and probabilities are implementation choices.

## Town roster — confirmed 20 November 2026

After a playtest the user found every creature available in town. Each island
now unlocks three more humans and three more animals; only the last island
(school) gives access to every creature and the complete eight-stage graph.

- **Humans (confirmed):** the forest three plus **Cleric, Assassin and Bard**.
  Peasants (innkeeper) and the pyromancer and frost mage (court mage) also belong
  to the town, behind their own rules, in addition to these three.
- **Animals:** the forest three plus **Turtle, Hedgehog and Peacock** (animals of
  the moat, hedges and royal gardens). The user left the choice open except that
  the skunk must not be among them; this selection is an implementation choice.
- **Transformations (confirmed):** a shapeshift only produces forms of the island
  roster. The town uses its own closed graph below; forest forms keep their most
  likely forest outcome so the first routes learned still work.

| Form | 55% | 30% | 15% |
| --- | --- | --- | --- |
| Archer | Rabbit | Wolf | Peacock |
| Shield Guardian | Deer | Turtle | Wolf |
| Spearman | Wolf | Hedgehog | Rabbit |
| Peasant | Rabbit | Turtle | Deer |
| Cleric | Deer | Peacock | Turtle |
| Assassin | Wolf | Rabbit | Hedgehog |
| Bard | Peacock | Deer | Hedgehog |
| Pyromancer | Hedgehog | Peacock | Wolf |
| Frost mage | Turtle | Hedgehog | Peacock |
| Rabbit | Archer | Assassin | Peasant |
| Wolf | Spearman | Assassin | Shield Guardian |
| Deer | Shield Guardian | Cleric | Bard |
| Turtle | Peasant | Spearman | Cleric |
| Hedgehog | Bard | Frost mage | Pyromancer |
| Peacock | Pyromancer | Archer | Frost mage |

Every town human is reached from two animals and every animal from four or five
humans. The routes are implementation choices.

Town openings use town compositions with familiar names (implementation
defaults): Troupe (guardian, archer, bard), Tavern (bard, peasant, spearman),
Shadows (two assassins, archer), Arcane (pyromancer, frost mage), Crusade (cleric,
guardian, spearman), plus Temple, Phalanx, Village, Fortress and Hunt (two
archers, spearman) for the player's cards. A form outside the town was replaced
by a town human and bonus gold adjusted for the price difference; these have not
been balanced.

## How a rule is withheld — implementation defaults

The gating keeps every rule's behaviour unchanged once it is introduced; before
that, the rule is absent for both wizards. These choices are implementation
defaults and can be revised.

- **Before the shop (opponents 1–2):** no creature stall, no gold counter and no
  gold for lost hearts. Each round both sides fight with their opening.
- **Before trading (opponents 1–5):** no reroll button; selling and locking
  offers do nothing.
- **Before the wand (opponent 1):** neither side can cast; charge crystals are
  hidden. With the druid, casts on one's own creatures only; hexes on enemy
  creatures come with the swamp witch.
- **Before the animal bonuses (opponents 1–4):** rabbits and skunks reached by
  an allied shapeshift have no special effect.
- **Before peasants (opponents 1–6):** the peasant is never offered and no
  opening containing one is dealt; harvest is off.
- **Before merging (opponents 1–7):** identical creatures do not combine, and
  the merge-progress pips never appear (confirmed after playtest: an element of
  a mechanic that does not exist yet is not shown). Harvest coins on the hover
  card likewise appear only once harvest exists.
- **Before casters (opponents 1–8):** the pyromancer and frost mage are never
  offered and no opening containing one is dealt. They can still appear through a
  shapeshift, with their normal behaviour.
- **Before frenzy (opponents 1–9):** combat keeps normal speed until the
  60-second timeout.
- **Wand scroll (opponents 11–14):** the scroll appears with the apprentice. An
  upgrade not yet introduced has no row at all (confirmed after playtest, 20
  November 2026, replacing the former padlocked rows): the introduced upgrades
  close up from the top, in their usual order, and the parchment unrolls only as
  far as they need (one row with the apprentice, four from the transmutation
  teacher onwards).
- **Openings:** forest uses the learning armies and choices above. Later opponents
  start with the listed composition; the archmage draws from its deck. Outside
  forest, player cards contain only creatures already allowed.
- **AI strength:** forest uses the guided behaviour above, town uses Adept AI and
  school uses Archmage AI. Opponents without magic never cast.
- **Duels outside the journey** (tests, balance tools) use the complete rules.

## Map

The journey map keeps the existing triangle of forest, town and school islands,
with five full-length opponents placed on each island without changing its shape
or buildings. After a playtest found them lined up along the island edge, they
stand at natural spots spread over each island's surface (confirmed request;
spots are implementation choices): forest clearings between the groves, town
streets, and the school courtyard ending with the archmage at the tower door.
The last opponent of the forest (archdruid) and of the town (king) stands just
inland of the landing of the bridge to the next island, as its guard (confirmed
request); the spot follows the bridge in landscape and portrait. The road winds between them and passes in
front of the tower, never behind it. Opponents further back are drawn slightly
smaller. It fits the whole screen with no scroll or header. Both bridges
are complete and visible from the start. Only the first opponent is visible on a
new journey. Winning discovers the immediate successor: only the route dots
animate over about four seconds, with muffled taps, before its opponent appears.
Confirmed after a playtest (21 November 2026): the opponent **springs out of the
ground** at the end of the path, with more juice than the former fade-in: a gold
ring opens, the opponent jumps out with a squash and stretch, a shock wave and a
burst of island-themed bits (leaves, stone chips and dust, magic sparks) and a
pop (the chosen proposal among four: drop from the sky, pillar of light, rise from
the ground, spotlight and greeting). The bits per island are implementation
choices.
Unknown opponents and paths have no silhouette, label, tooltip or padlock. The
player's wizard is not represented on the map. Beaten opponents stand on a soft gold ring;
the star they used to carry was removed after a playtest (21 November 2026):
the ring and the drawn route already show the win.
During a duel the opponent's portrait replaces the difficulty hat in the enemy panel.

Duels use their zone's terrain and starting hearts for both sides: forest grass
and 3 hearts, town paving and 6 hearts, school gold-inlaid slabs and 10 hearts.
Old seven-stage saves preserve proportional advancement through each zone; the
new fifteen-opponent saves use their own `journey.opponents` key.

## Introducing a rule — first pass, 20 November 2026

Every new mechanic gets a short sequence that draws the player's attention to
it. Confirmed by the user: as simple as possible, **no text**, played **only at
the first encounter** with the rule, and for rules without a control **at the
moment the rule first happens**. A second pass will follow if this is not clear
enough.

First pass (implementation choices): the screen dims around an elliptical
opening on the new element, a gold ring pulses there with orbiting sparkles and
the unlock chime plays; after about 2.7 seconds the dimming lifts. Input is never
blocked, and combat slows to a quarter speed while the dimming is full.

| Rule | Spotlit element | When |
| --- | --- | --- |
| Wand (druid) | Charge crystals | First fight |
| Shop (lumberjack) | Creature stall | Shop in place |
| Hex (swamp witch) | First enemy creature, followed | First fight |
| Animal bonus (archdruid) | The creature, followed | First allied shapeshift into a bonus form |
| Trading (merchant) | Reroll button | Shop in place |
| Harvest (innkeeper) | First harvester | First fight with a harvester |
| Merging (thief) | The player's first identical pair | Shop in place with a pair |
| Casters (court mage) | The caster, followed | First spell channel |
| Frenzy (king) | Timer bar | Frenzy starts |
| Wand upgrades (school) | The new scroll row | Scroll unrolled |

A rule is remembered once shown (`journey.introduced` in the save), and a beaten
opponent never replays it. The hunter and the archmage introduce nothing.

### Merge lesson — playtest revision, 20 November 2026

The user found the thief's merge instruction unclear. During preparation in the
thief's duel, a looping demonstration now shows the gesture itself until the
player's first merge of the duel: a translucent copy of the creature rises from
one copy (a benched one first, or an identical shop offer) along a dotted gold
arc with an arrowhead, lands on the identical creature, which pulses in gold
while its merge pips fill by one. No text; it never blocks. Confirmed after a
later playtest: like the cast invitation, it plays only until the player's first
merge against the thief, ever (saved in `journey.lessons_done`), and never again
when the thief is replayed.

The same playtest reported that a second identical creature could not be placed
on an empty cell. The cause was the existing limit of **six creatures on the
board** (`Rules.FIELD_CAP`): once six were fielded, only a merge or the bench
could take another creature, and no opponent introduces that limit. Confirmed:
keep the limit and make it visible. While a full board refuses the dragged
creature, empty cells no longer light up and the six capacity pips are ringed in
red; a refused drop makes the rings blink. The bench still accepts the creature.

## Open questions

- Is the first-pass spotlight clear enough without text? To check in playtest.
