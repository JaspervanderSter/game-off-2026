# Prototype 02 — Design and Experiment Plan

## Status

Updated on 6 November 2026 for the second Prototype 02 iteration.

This iteration narrows the roster to **six purchasable archetypes**, gives each
archetype a compact **transformation family**, and makes the shared combat
system data-driven. The previous 24-form, eight-stage network is superseded.
The earlier draft remains available in Git history.

The complete duel loop is still the target: shop and preparation between rounds,
real-time automatic combat with player shapeshifting, then round resolution until
one wizard has no health.

Learning goal: does shapeshifting make a complete auto-battler duel more fun, and
does it add tactical decisions that the underlying auto-battler does not have on
its own?

## Source documents

- [[Game Vision]] — concept, opponent and intended experience.
- [[Gameplay Loop]] — combat, preparation and round structure.
- [[Shapeshifting]] — casting, immunity, families and momentum.
- [[Roster and Transformation Map]] — the six families, forms and links.
- [[Combat and Transformation Spec]] — shared data schema, attack behaviours and
  implementation rules.
- [[Economy and Progression]] — purchases, resources and progression proposals.
- [[Art Direction]] — readability and presentation preferences.
- [[Ideas to Explore]] — optional features awaiting validation.

## Core loop

A single-player duel against an AI wizard. The player and the AI each control a
wizard, an army and a shapeshift spell.

1. **Pack choice.** Choose one free starting pack of three creatures.
2. **Shop.** Spend gold on new creatures, or improve the army by replacing or
   selling creatures. The existing merge rules remain available.
3. **Preparation.** Place creatures on the player's half of the board.
4. **Combat.** Both armies fight automatically. The player observes and
   intervenes by shapeshifting friendly or enemy units.
5. **Resolution.** The losing wizard loses health equal to the number of
   surviving enemy creatures. The duel ends at zero health.

The shop determines what tools the player brings. Shapeshifting determines how
cleverly those tools are used.

## Six archetypes

The purchasable roster is reduced to six distinct archetypes. Each archetype has
a different combat identity and a different attack behaviour, not merely
different statistics.

| Archetype | Role | Combat identity | Signature behaviour |
| --- | --- | --- | --- |
| Vanguard | Tank | Durable frontline, absorbs damage. | Guard aura: nearby allies gain armour. |
| Striker | Melee DPS | Fast attacks, agile, reaches the backline. | Initial backline target priority. |
| Ranger | Ranged DPS | Attacks from distance, relatively fragile. | Kites away from melee pressure. |
| Mystic | Magic / control | Magical attacks, slows and special effects. | Frost attacks slow movement. |
| Support | Healing / buffs | Keeps allies alive and improves them. | Periodic heal of the most wounded ally. |
| Berserker | Heavy melee DPS | Slow, powerful attacks, aggressive. | Attacks faster as health falls. |

The six archetypes reuse the visual language of the previous roster:
Shield Guardian / Spearman for Vanguard, Duelist / Assassin for Striker,
Archer / Crossbowman for Ranger, Frost Mage / Pyromancer for Mystic,
Cleric / Bard for Support, and Berserker for Berserker.

## Transformation families and stages

Each archetype owns a **directed family ladder** of four forms: the purchasable
fantasy base form and three animal forms. The current form always determines the
next step, so the player can learn and anticipate the progression.

| Family | Base form | Animal I | Animal II | Animal III |
| --- | --- | --- | --- | --- |
| Vanguard | Vanguard | Bear | Turtle | Rhino |
| Striker | Striker | Fox | Panther | Rabbit |
| Ranger | Ranger | Hawk | Eagle | Phoenix |
| Mystic | Mystic | Raven | Shadow Raven | Owl |
| Support | Support | Doe | Songbird | Unicorn |
| Berserker | Berserker | Boar | Wolverine | Badger |

Progression rules:

- Base → Animal I always succeeds.
- Animal I → Animal II and Animal II → Animal III require that animal's special
  to have been used.
- Animal III is the final stage. A cast on Animal III refreshes its form, heals
  and cleanses it, and resets its special.
- A blocked upgrade consumes no charge.

This replaces the previous complete four-form graph. The old graph allowed
immediate reversals such as Ranger → Hawk → Ranger, which caused the observed
back-and-forth. The ladder removes that loop and makes each cast meaningful.

Animal forms remain **tactical sidegrades overall**, but their specials escalate
within the ladder. A turtle is more durable but slower; a phoenix trades speed
for area damage; a rabbit trades durability for evasion. Stage position describes
graph order and special strength, not a uniform stat upgrade.

## Animal specials

Every animal form has one **one-use special**. Base forms do not.

- **Automatic:** triggers for free when its data condition is met.
- **Manual:** left-click a friendly animal during combat and spend one
  shapeshift charge.
- Using the special marks it as used and unlocks the next transformation stage.
- The special resets when the animal enters a new form or refreshes at Animal III.

Auto conditions are data-driven, for example: two nearby enemies, an enemy
backline in range, an enemy cluster around the current target, a wounded ally, or
low self-health.

The Rhino's **Stampede** is the flagship disruption special: it knocks nearby
enemies away and briefly staggers them, breaking up a static tank wall.

## Shapeshifting rules

- The player can store up to three charges; the current starting value is one.
- Charges regenerate over time; the initial value is one charge every three
  seconds.
- Right-click transforms a creature one ladder step. Left-click triggers a
  friendly animal's special manually.
- A manual special and an upgrade each consume one charge. An auto-triggered
  special is free.
- A creature becomes immune to further shapeshifting for three seconds after a
  transformation.
- Immunity is per creature and applies to both wizards.
- The player can save charges and spend them in quick succession on different
  creatures.
- Invalid casts consume neither a charge nor recharge progress.

Transformation effects:

- The new form's statistics replace the old form's statistics.
- Current health percentage is preserved, then the creature heals 10% of the new
  maximum health (capped at full).
- Positive status effects are preserved; negative status effects are removed.
- The basic attack is readied, except when an attack was interrupted (see below).
- Ability cooldowns carry over; entering a form never grants an instant ability.
- The animal's one-use special resets on entering a new form and on an Animal III
  refresh.
- **Temporary levels are removed in this iteration.** Transformations no longer
  add stacking levels or permanent power. Permanent merge stars remain and are
  independent of shapeshifting.

These effects apply to both teams. Transforming an enemy therefore also heals and
cleanses it, which makes enemy casts a real trade-off rather than a free debuff.

## Momentum and combos

Momentum is an experimental layer. It is enabled by default and can be disabled
or tuned in `Rules`.

1. A creature is transformed and receives its three-second immunity.
2. When immunity expires, a short momentum window opens.
3. If the creature is transformed again during that window, a combo activates.
4. If the window expires, momentum resets without a combo.

The combo grants a temporary, situational bonus rather than a permanent power
increase. The initial implementation grants a short attack-speed and damage
bonus. The effect is data-driven per form, with a generic default.

The intended decision is not "always transform the same creature". Charges are
limited, immunity is per creature, and the window is short. The player must decide
which creature deserves the next cast and whether to wait for a combo or use the
cast elsewhere.

## Attack timing, interruption and dodging

Combat uses a short **windup** before every basic attack lands. The windup is
visible, and its length is part of each form's attack behaviour.

Rules:

- **Interruption.** Transforming the *attacker* during its windup cancels the
  pending attack. The attack is not committed until the windup ends.
- **Commitment.** Once the windup ends, a melee hit or projectile is committed.
  Transforming the attacker afterwards does not undo it.
- **Dodge.** Transforming the *target* grants a brief projectile-dodge window.
  Projectiles that arrive during that window are deflected. Melee attacks already
  in windup are not automatically dodged; only transforming the attacker
  interrupts them.
- **Recovery.** An interrupted attack does not become instantly ready. The
  interrupted creature receives a short recovery before it can attack again.
  A normal transformation still readies the basic attack.
- **Feedback.** Interrupts and dodges produce distinct visuals and sounds so the
  player can understand why an attack did not land.

This gives transformations two different tactical uses: disrupt an enemy's
committed attack, or protect a friendly unit from an incoming projectile. Neither
is automatic; both depend on timing.

## Combat readability and feedback

Every form needs a readable idle, attack, hit reaction, death and transformation
presentation. The procedural art is intentionally simple, but the six archetypes
must not look or attack identically.

| Archetype | Attack presentation |
| --- | --- |
| Vanguard | Short weapon thrust or shield-assisted strike. |
| Striker | Quick lunge and slash. |
| Ranger | Draw and release a projectile. |
| Mystic | Casting motion with a magical projectile. |
| Support | Supportive pulse or holy projectile. |
| Berserker | Slow overhead smash with a heavy impact. |

Animal forms reuse the same animation vocabulary but select a style that fits the
animal. The transformation itself uses a family-coloured burst, a ring, a scale
pop and a sound. Immunity, the momentum window, a combo, a blocked cast, an
interrupt and a dodge each need distinct feedback.

## Between-round persistence

Temporary forms, specials, momentum, statuses and attack state reset between
rounds. The player's purchased creatures, permanent merge stars, gold and army
composition persist according to the existing economy rules. No permanent
transformation progression is introduced.

## Scope decisions

| Area | Decision |
| --- | --- |
| Core combat | Automatic real-time combat with player shapeshifting. |
| Active spell | Single-target shapeshifting; friendly and enemy targets. |
| Opponent | Single-player against an AI wizard. |
| Roster | Six purchasable archetypes; 24 forms total including animal families. |
| Transformation graph | Six directed four-form ladders; base always upgrades. |
| Animal specials | One per animal; auto or manual; manual costs a charge; using it unlocks the next stage. |
| Final stage | Animal III refreshes form, heal/cleanse and special instead of upgrading. |
| Spell charges | Three maximum; one starting charge; one recharge every three seconds. |
| Target immunity | Three seconds per creature, both teams. |
| Temporary levels | Removed in this iteration. |
| Momentum | Enabled by default; generic temporary combo bonus; tunable. |
| Attack timing | Visible windup; attacker transformation interrupts; target transformation dodges projectiles during a short window. |
| Persistence | Forms and momentum reset between rounds; purchases and stars persist. |
| Wizard progression | Excluded. |
| Creature merging | Retained from the existing prototype. |
| Bench casting | Deferred. |
| Additional spells | Outside scope. |
| Multiplayer | Outside scope. |

## Data-driven architecture

The combat system is shared across every form. Adding an archetype later should
mean adding data, not writing a new combat loop.

The shared layer contains:

- **Archetype data** — identity, role, family, base form, price and shop pool.
- **Form data** — statistics, attack behaviour, ability behaviour, visual
  identity and an optional one-use `special` block.
- **Family data** — ordered form ids for each transformation ladder.
- **Special data** — type, effect parameters and automatic trigger condition.
- **Rules** — charge, immunity, momentum, windup, dodge, recovery and economy
  tuning values.

A new archetype requires one base form, three animal forms, one family entry and
shop-pack membership. The unit, battle, AI and UI systems read the same data.

See [[Combat and Transformation Spec]] for the field-level schema.

## Provisional tuning values

All values are first-pass and live in `scripts/core/rules.gd` or
`scripts/data/creature_db.gd`.

| Value | Initial |
| --- | --- |
| Starting charges | 1 |
| Maximum charges | 3 |
| Recharge interval | 3 s |
| Target immunity | 3 s |
| Transformation heal | 10% of new max HP |
| Momentum window | 2.5 s after immunity |
| Momentum duration | 4 s |
| Momentum attack speed | +25% |
| Momentum damage | +15% |
| Projectile dodge window | 0.30 s |
| Interrupted attack recovery | 0.40 s |
| Combat timeout | 60 s |
| Wizard health | 10 |
| Starting income | 3 gold, +1 per round |

## Decision log

### 6 November 2026 — second prototype update

- Reduced the purchasable roster to six archetypes with distinct attack
  behaviours.
- Replaced the 24-form eight-stage network with six compact four-form families.
- Removed temporary transformation levels to avoid stacking power and to keep
  repeated transformations from becoming universally optimal.
- Kept health-percentage preservation, the 10% heal, positive-status retention
  and negative-status cleansing for both teams.
- Added an experimental momentum window and combo bonus.
- Added visible attack windups, attacker interruption and target projectile
  dodging.
- Made the combat data shared and configurable so a new archetype is a data task.

### 7 November 2026 — staged progression and animal specials

- Replaced the complete four-form family graph with a directed ladder:
  Base → Animal I → Animal II → Animal III.
- Base forms always upgrade. Animal I and II require their one-use special to be
  used before the next upgrade.
- Animal III refreshes instead of upgrading.
- Added one special per animal, with automatic conditions and optional manual
  triggering by spending a charge.
- Added left-click manual special input; right-click remains transformation.
- Added the Rhino Stampede: knockback plus a brief stagger to break up static
  front walls.
- Lowered the AI front-line target share so armies vary more.

## Playtest questions

- Does each of the six archetypes have a meaningful combat purpose?
- Are different forms in the same family tactically useful in different
  situations?
- Is there a reason to save charges rather than cast immediately?
- Does transformation timing matter?
- Do attack interruptions and dodges create interesting decisions?
- Does momentum encourage interesting combos without becoming mandatory?
- Can players understand the six families and anticipate possible outcomes?
- Does the same army offer different tactical possibilities against different
  opponents?
- Does removing temporary levels make transformations feel tactical rather than
  generically powerful?

## Remaining limitations

- Animal forms use procedural placeholder art, not final assets.
- The six ladders are role-preserving; cross-family transformations are not used.
- The AI casting heuristic does not predict projectile travel time.
- Specials share a small set of generic effect types.
- Auto conditions are simple distance/health checks.
- The momentum combo is generic.
- Balance values have not been playtested with external players.
