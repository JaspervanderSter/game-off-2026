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
| 2 | Forest | Druid | Yes | The wand: shapeshifting one's own creatures (blessing), charge crystals | One deer |
| 3 | Forest | Lumberjack | No | Creature shop: buying, income every round, gold for lost hearts | One spearman |
| 4 | Forest | Swamp witch | Yes | Hex: shapeshifting and stunning enemy creatures | One wolf |
| 5 | Forest (boss) | Archdruid | Yes | Animal bonuses after an allied shapeshift (rabbit leap within the forest roster) | Wolf and rabbit |
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
  by either wizard. Town and school retain their existing roster rules.

Current implementation defaults, available for playtest revision:

- Three small starting choices: guardian + two archers; guardian + two spearmen;
  guardian + archer + spearman. No bonus gold. All creatures start on the board.
- Opponents use the small fixed armies above. They never buy, replace, merge or
  optimise their army. They remain beatable without purchases or player casts.
- Magical opponents demonstrate at most one cast per round, after six seconds:
  an allied transformation before hexes, an enemy transformation afterwards.
- Normal damage and creature deaths remain visible, but damage cannot kill the
  player's last creature. The safety net applies only in forest encounters;
  timeout remains a draw. It prevents defeat without requiring a successful cast.
- Hide the empty bench before the shop and disable its invisible drop targets.
  Show it with shopping, or if reserves already exist.
- An animated wand and target ring invite an allied cast from the druid, then an
  enemy cast from the witch. The cue stops after the corresponding player cast.
  No lesson popup or mandatory cast blocks progress.

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
graph: forms can return after two casts. The full graph resumes in town, so
learned forest routes do not all transfer there. How to present that transition
still needs playtest feedback. The roster restriction is confirmed; these
particular routes and probabilities are implementation choices.

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
- **Before merging (opponents 1–7):** identical creatures do not combine.
- **Before casters (opponents 1–8):** the pyromancer and frost mage are never
  offered and no opening containing one is dealt. They can still appear through a
  shapeshift, with their normal behaviour.
- **Before frenzy (opponents 1–9):** combat keeps normal speed until the
  60-second timeout.
- **Wand scroll (opponents 11–14):** the scroll appears with the apprentice; an
  upgrade not yet introduced shows a padlock in its row and cannot be bought.
- **Openings:** forest uses the learning armies and choices above. Later opponents
  start with the listed composition; the archmage draws from its deck. Outside
  forest, player cards contain only creatures already allowed.
- **AI strength:** forest uses the guided behaviour above, town uses Adept AI and
  school uses Archmage AI. Opponents without magic never cast.
- **Duels outside the journey** (tests, balance tools) use the complete rules.

## Map

The journey map keeps the existing triangle of forest, town and school islands,
with five full-length opponents placed on each island without changing its shape
or buildings. It fits the whole screen with no scroll or header. Both bridges
are complete and visible from the start. Only the first opponent is visible on a
new journey. Winning discovers the immediate successor: only the route dots
animate over about four seconds, with muffled taps, before its opponent appears.
Unknown opponents and paths have no silhouette, label, tooltip or padlock. The
player's wizard is not represented on the map. Beaten opponents carry a gold star.
During a duel the opponent's portrait replaces the difficulty hat in the enemy panel.

Duels use their zone's terrain and starting hearts for both sides: forest grass
and 3 hearts, town paving and 6 hearts, school gold-inlaid slabs and 10 hearts.
Old seven-stage saves preserve proportional advancement through each zone; the
new fifteen-opponent saves use their own `journey.opponents` key.

## Open questions

- Should the player be told which rule a duel introduces (an icon on the stage,
  or an animation at the start of the duel)? Not decided yet.
