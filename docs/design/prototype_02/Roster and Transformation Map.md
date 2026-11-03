# Roster and Transformation Map

**Status:** design draft, 3 November 2026. [[Prototype 02]] selects 12 fantasy
forms and 12 animal forms. Individual candidates, abilities, statistics and links
remain proposals for review.

## Open the maps in Obsidian

Open the repository root as the vault so file paths resolve correctly. Enable
Obsidian's built-in Canvas plugin if needed, then open:

- [[Transformation Map.canvas|Complete transformation map]] — 24 forms, 72 arrows.
- [[Fantasy to Animals.canvas|Fantasy → animals]] — 36 arrows from fantasy forms.
- [[Animals to Fantasy.canvas|Animals → fantasy]] — 36 arrows from animal forms.

Zoom to fit for the overview, then zoom into a creature. Cards embed the `Card`
section of each Markdown note. Open the underlying note to edit the complete
sheet; changes to that section appear in all three canvases. Drag cards to
rearrange them. Layout changes are independent in each canvas.

Cyan cards are fantasy forms; green cards are animals. Arrows point from a source
to a possible outcome. Three outgoing options exist per creature. Each has an
exact draft chance of 1/3. This neutral baseline is not an approved probability
model. The revised eight-stage graph has three incoming links per form too,
and forbids direct reverse links.

The map now uses eight labelled stages, with three forms per stage. Read stages
1-4 left to right on the top row, then stages 5-8 left to right below. Each
form points to all three forms in the next stage; stage 8 leads to stage 1.
The complete map can be busy; use the directional views and source notes too.

## Proposed common statistics

Start with a small set that makes creatures mechanically distinguishable. All
numeric values are TBD; the definitions below are assistant proposals to discuss.

| Field | Definition | Design purpose |
| --- | --- | --- |
| Maximum health | Damage a creature can take before death. | Durability. |
| Basic attack damage | Damage per basic attack before reduction. | Heavy hits versus light hits. |
| Basic attack interval | Seconds between attacks; lower means faster. | Attack rhythm; keep separate from damage. |
| Basic attack range | Distance measured in placement-cell widths. | Melee, reach and ranged roles. |
| Movement speed | Placement-cell widths per second. | Reaching targets, chasing and repositioning. |
| Armour | Percentage of incoming damage reduced. | Distinguish protection from health. Damage-type exceptions remain undefined. |
| Purchase price | Gold cost; an economy field rather than a combat statistic. | Immediate strength versus transformation potential. |

The placement grid supplies a distance unit only: combat movement remains
continuous. Exact world scale and whether ranges include creature radii are TBD.
Armour limits, piercing, poison interaction and stacking need explicit rules
before numerical balancing. Do not assume a physical/magical damage split.

Abilities use their own necessary parameters (effect strength, cooldown,
duration, radius, trigger); they are behaviours, not an additional shared
statistic every creature must have. Target priority and melee/projectile attack
type are also behaviours. No mana, critical chance, dodge chance or wizard upgrade
systems are introduced by this draft. Temporary combat levels are now selected:
start at level 1, gain +1 per allied cast, preserve levels on enemy casts, reset
between rounds. Delegated scaling default: +20% of the current form's base maximum
health and basic attack damage per level above 1; all other base stats stay fixed. The Duelist's proposed parry is
a creature ability, not a universal random dodge statistic.

## What each creature sheet contains

- A concise embedded card with role, weakness and placeholders for shared stats.
- A statistics table with explicit units.
- The proposed ability and parameters still to define.
- Three proposed outgoing transformations and an incoming-link reference list.
- Playtest questions and unresolved transformation interactions.

## Network proposal and review

The previous role-based draft contained immediate reverse routes. It has been
replaced by an eight-stage proposal in response to the user's anti-cancellation
rule. Each stage contains three alternatives:

| Stage | Forms | Next stage |
| --- | --- | --- |
| 1 | Pitchfork Peasant, Shield Guardian, Cleric | 2 |
| 2 | Rabbit, Turtle, Deer | 3 |
| 3 | Berserker, Duelist, Bard | 4 |
| 4 | Gorilla, Hedgehog, Wolf | 5 |
| 5 | Assassin, Archer, Frost Mage | 6 |
| 6 | Eagle, Snake, Peacock | 7 |
| 7 | Spearman, Crossbowman, Pyromancer | 8 |
| 8 | Rhinoceros, Leopard, Skunk | 1 |

Every form points to all three forms in the next stage, at equal draft chances.
All 24 forms are reachable. No direct reversal is possible, and the shortest
return to any form is exactly eight casts. Repeatedly transforming one creature
therefore requires at least 21 seconds from the first cast to an eight-cast
return, even before charge availability, because target immunity lasts three
seconds. This is a provisional long-route interpretation, not a guarantee of
visiting almost all 24 forms before returning. That stronger goal remains unmet
by this draft. The grouping and chances remain design proposals.

This structure makes routes easier to understand but groups of three currently
share identical outgoing options. Test whether this reduces variety too much.
Health restoration, attack resets, cleansing and retained levels are specified
in [[Prototype 02]]. Opposing casts cannot remove earned levels. The old generic
enemy debuff is superseded: enemy targets keep their level, and can still receive
the general heal, cleanse and attack reset. Evaluate whether targeting enemies
is useful despite these benefits. Do not silently apply an allied-only exception.

## Editing and synchronisation

This is a native Obsidian design artifact, not a Godot editor or live game data.
Creature notes are the reference for intended roles, statistics and outgoing
probabilities. The Canvas files visualize those proposals.

When changing a connection or chance, update its source note and the corresponding
edge in both the complete map and the appropriate directional map. Update incoming
references in affected destination notes as well. These edits are not automatically
synchronised. Embedded card summaries must also be kept consistent with their
sheet's statistics table. No import pipeline into Godot is implemented.

## Next decisions

1. Review the 24 candidates and their defining behaviours.
2. Approve or change the common statistics and their definitions.
3. Test the selected health, attack-reset, status and temporary-level rules.
4. Assign a first numerical baseline and shop prices, then revisit every link.
5. Tune probabilities once the consequences of each destination are understood.
