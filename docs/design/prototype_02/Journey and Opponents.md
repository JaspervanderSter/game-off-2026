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
- **Minimal text.** On screen, opponents are recognised by their drawing; rules
  are shown through icons, as everywhere else ([[Art Direction]]).

## The fifteen opponents — confirmed

| # | Zone | Opponent | Magic | Rule introduced | Opening (existing composition) |
| ---: | --- | --- | --- | --- | --- |
| 1 | Forest | Hunter | No | Placing creatures, automatic combat, hearts lost per surviving enemy | Hunt |
| 2 | Forest | Lumberjack | No | Creature shop: buying, income every round, gold for lost hearts | Raid |
| 3 | Forest | Druid | Yes | The wand: shapeshifting one's own creatures (blessing), charge crystals | Temple |
| 4 | Forest | Swamp witch | Yes | Hex: shapeshifting and stunning enemy creatures | Shadows |
| 5 | Forest (boss) | Archdruid | Yes | Animal bonuses after an allied shapeshift (rabbit leap, skunk fear) | Hunt |
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

- **Forest:** the fundamentals, then the wand. The player duels without a wand
  against the hunter and the lumberjack; the wand appears with the druid.
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

## How a rule is withheld — implementation defaults

The gating keeps every rule's behaviour unchanged once it is introduced; before
that, the rule is absent for both wizards. These choices are implementation
defaults and can be revised.

- **Before the shop (opponent 1):** no creature stall, no gold counter and no
  gold for lost hearts. Each round both sides fight with their opening.
- **Before trading (opponents 1–5):** no reroll button; selling and locking
  offers do nothing.
- **Before the wand (opponents 1–2):** neither side can cast; charge crystals are
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
- **Openings:** each opponent starts with the composition listed above; the
  archmage draws from its deck. The player's three cards are drawn only among
  the compositions whose creatures are already allowed.
- **AI strength:** forest opponents use the Apprentice AI, town opponents the
  Adept AI and school opponents the Archmage AI. Opponents without magic never
  cast.
- **Duels outside the journey** (tests, balance tools) use the complete rules.

## Map

The journey map shows one floating island per zone (forest, town, school), with
five opponents on each, connected in order. Opponents are drawn full length at
their stage; beaten ones carry a gold star and locked ones a padlock. During a
duel the opponent's portrait replaces the difficulty hat in the enemy panel.

## Open questions

- Should the player be told which rule a duel introduces (an icon on the stage,
  or an animation at the start of the duel)? Not decided yet.
- Battlefield terrain per zone (forest, town, school tiles) is not yet tied to
  the journey.
