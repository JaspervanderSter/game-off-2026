---
creature_id: skunk
family: animal
status: candidate
---

# Skunk

## Card

**Skunk** · Animal · CANDIDATE

Short-range area spray temporarily reduces enemy armour.

**Weakness:** Needs allies to exploit the opening.

**HP / damage / attack interval:** TBD / TBD / TBD

**Range / movement / armour:** TBD / TBD / TBD

**Price:** TBD · Stats and ability unapproved.

## Design status

Assistant-proposed candidate for [[Prototype 02]]. Roster size is selected;
this creature, its ability and its links are not yet validated.
Animal abilities are original proposals, not Super Auto Pets rules.

## Proposed statistics

Values remain deliberately undefined. See [[Roster and Transformation Map]] for
shared definitions and open rules. These are base-form values, before the
allied buff / enemy debuff. Temporary combat level starts at 1. Allied casts grant +1; enemy casts preserve it.
Default level scaling adds 20% base maximum health and basic attack damage per
level above 1. Levels reset between rounds and do not represent merging.

| Field | Value | Unit / meaning |
| --- | --- | --- |
| Maximum health | TBD | HP |
| Basic attack damage | TBD | HP per hit, before reduction |
| Basic attack interval | TBD | seconds between attacks |
| Basic attack range | TBD | placement-cell widths |
| Movement speed | TBD | placement-cell widths per second |
| Armour | TBD | percentage of incoming damage reduced |
| Purchase price | TBD | gold; economy field, separate from combat strength |

## Proposed behaviour and ability

Short-range area spray temporarily reduces enemy armour.

Define before implementation: basic attack type (melee/projectile), target
priority, ability trigger, effect magnitude, duration, range/radius, cooldown,
stacking, and whether it replaces or supplements a basic attack. Use only the
parameters needed for this creature. All remain TBD.

## Proposed outgoing transformations

Exactly one destination is drawn per cast. Equal weights are a draft baseline,
not a balance decision. 1/3 is exact; the three chances sum to 100%.

| Destination | Draft chance |
| --- | --- |
| [[Pitchfork Peasant]] | 1/3 |
| [[Shield Guardian]] | 1/3 |
| [[Cleric]] | 1/3 |

**Proposed incoming links:** [[Spearman]], [[Crossbowman]], [[Pyromancer]].

Links are directed. A reverse link exists only when explicitly listed in the
other creature's outgoing table. Card positions do not imply links.

## Playtest questions

- Is the role and its weakness understandable during real-time combat?
- When would the player want to transform into or away from this form?
- Does this form create useful choices at its eventual purchase price?

## Shared transformation rules

Follow [[Prototype 02]]: preserve health percentage, then heal 10% of the new
maximum HP (cap at full); ready the basic attack; retain positive status effects
and cleanse negative effects. This general rule currently applies to either team.
Allied casts grant +1 level; enemy casts preserve the current level. The previous
form's innate ability is replaced. Shared rules define cooldown and aura handling.

Each combat starts with one charge (maximum three), with one charge recharging
in three seconds. Target immunity lasts three seconds. Forms, levels and statuses
reset between rounds. Revised links have no immediate reverse and a shortest
return of eight casts. Base statistics and ability parameters remain to be tuned.
