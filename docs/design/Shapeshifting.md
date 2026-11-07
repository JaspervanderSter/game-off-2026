# Shapeshifting

## Status and scope

Shapeshifting is the core mechanic. This note records the rules for the second
Prototype 02 iteration (6 November 2026). Values remain provisional and tunable.

The spell targets **one creature per cast** and can target friendly or enemy
units. Multi-target transformations remain deferred.

## Casting flow

1. Hover over a friendly or enemy creature.
2. Right-click to transform it one step along its family ladder.
- Left-click a friendly animal to trigger its one-use special instead.
3. Play a short, magical transformation or special effect.
4. When a transformation succeeds, the creature becomes immune to further
   shapeshifting for three seconds.
5. An animal upgrade only succeeds if that animal's special has already been
   used. The hover card shows the ladder and the gate.

The player does not choose a random result. The current form determines the exact
next step. The player still chooses which creature, when to use its special, and
when to spend a charge on the upgrade.

## Charges

- The player can store up to three charges. The current starting value is one.
- Each cast consumes one charge.
- Charges regenerate over time. The initial value is one charge every three
  seconds.
- Charges are independent of creature immunity.
- Stored charges can be spent in succession on different creatures.
- Invalid casts consume neither a charge nor recharge progress.
- Starting charges, maximum charges and recharge time are configurable.

Three charges do not mean one creature can be transformed repeatedly without
waiting: the per-creature immunity still applies.

## Transformation immunity

After a transformation, the creature cannot be transformed again for three
seconds. Immunity is per creature and applies to both wizards. The remaining
immunity is shown as a ring around the creature.

Three seconds is an initial tuning value, not a permanent design decision.

## Transformation families and stages

Each purchasable archetype owns a directed family ladder of four forms. The
current form always determines the next step.

| Family | Base | Animal I | Animal II | Animal III |
| --- | --- | --- | --- | --- |
| Vanguard | Vanguard | Bear | Turtle | Rhino |
| Striker | Striker | Fox | Panther | Rabbit |
| Ranger | Ranger | Hawk | Eagle | Phoenix |
| Mystic | Mystic | Raven | Shadow Raven | Owl |
| Support | Support | Doe | Songbird | Unicorn |
| Berserker | Berserker | Boar | Wolverine | Badger |

Progression rules:

- **Base → Animal I** always succeeds.
- **Animal I → Animal II** and **Animal II → Animal III** require that animal's
  special has been used at least once.
- **Animal III** cannot upgrade further. A cast on Animal III refreshes it:
  keeps the form, applies the normal transformation heal/cleanse, and resets its
  special.
- A blocked upgrade consumes neither a charge nor immunity.

This replaces the previous complete four-form graph. The old graph allowed
`Archer → Hawk` and `Hawk → Archer` on consecutive casts, which caused the
observed ping-pong. The ladder removes immediate reversals and makes progression
readable.

Family membership is visually recognisable: each family has a colour accent and a
stable silhouette language. The hover card shows the full ladder, the current
stage, and the next upgrade.

Transformations do not cross families in this iteration. The data layer can be
extended with branching links later if needed.

## Animal specials

Every animal form has one **one-use special**. The base fantasy forms do not.

A special can be triggered in two ways:

- **Automatically** when its data condition is met, at no charge cost.
- **Manually** by left-clicking the friendly animal during combat. This spends
  one shapeshift charge.

Using a special marks it as used for the current form. That is what unlocks the
next transformation stage. The special resets when the creature enters a new
form or refreshes at Animal III.

Examples of auto conditions:

- Two or more enemies nearby.
- An enemy backline target within range.
- Two or more enemies clustered around the current target.
- An ally below a health threshold.
- The animal itself below a health threshold.

Specials are intentionally short and readable: a roar, a stampede, a pounce, a
volley, a dive, a nova, a heal burst, a rally, a frenzy, or a retaliation buff.
The Rhino's **Stampede** knocks nearby enemies away and briefly staggers them,
which directly breaks up a static tank wall.

## What changes with the form

- The destination form's statistics replace the previous form's statistics.
- Current health percentage is preserved, then the creature heals 10% of the new
  maximum health, capped at full health.
- Positive status effects are preserved; negative status effects are removed.
- The basic attack is readied, except when an attack was interrupted.
- Ability cooldowns carry over. Entering a form never grants an instant ability.
- The animal's one-use special resets on entering a new form.
- The previous form's innate ability is replaced by the new form's ability.
- Permanent merge stars persist; temporary combat state does not.
- **Temporary levels are removed.** Transformations do not add stacking power.

These rules apply to both teams. Transforming an enemy also heals and cleanses
it, which is a deliberate trade-off: the player changes its behaviour, but also
gives it a small recovery.

## Momentum and combos

Momentum is an experimental layer that rewards well-timed consecutive
transformations.

1. A creature is transformed and receives its three-second immunity.
2. When immunity expires, a momentum window opens.
3. If the creature is transformed again during that window, a combo activates.
4. If the window expires, momentum resets.

The combo grants a temporary attack-speed and damage bonus. The initial values are
a 2.5-second window, a 4-second bonus, +25% attack speed and +15% damage. These
are configurable in `Rules`, and the layer can be disabled entirely.

The combo should not make repeated transformations universally optimal. Charges,
per-creature immunity and the short window keep the decision situational.

## Attack timing

Shapeshifting interacts with combat timing through three rules.

### Interruption

Every basic attack has a visible windup. Transforming the attacker during the
windup cancels the pending attack. The attack is not committed until the windup
ends. An interrupted attacker receives a short recovery before attacking again.

### Commitment

Once the windup ends, a melee hit or projectile is committed. Transforming the
attacker afterwards does not undo it.

### Dodging

Transforming the target grants a brief projectile-dodge window. Projectiles that
arrive during that window are deflected. Melee attacks already in windup are not
automatically dodged; the player must transform the attacker to interrupt them.

This means transformations have two distinct tactical uses:

- Disrupt an enemy's windup.
- Protect a friendly unit from an incoming projectile.

Neither is automatic; both depend on timing and on the target's immunity state.

## Feedback requirements

- Transformation: family-coloured burst, ring, scale pop and sound.
- Blocked cast: distinct fizzle and immunity-ring pulse.
- Immunity: visible ring with remaining time.
- Momentum window: subtle pulsing ring around the creature.
- Combo: gold burst plus a momentum status icon.
- Special ready: bright rune on the animal.
- Special used / upgrade unlocked: dim check mark plus a small chevron.
- Upgrade blocked by an unused special: padlock on the next ladder step and a
  distinct "need special" burst.
- Successful special: family-coloured burst and area effect.
- Interrupt: broken-attack marker and sound.
- Dodge: afterimage or deflect flash and sound.

## Rules still to tune

- Charge start, maximum and recharge time.
- Immunity duration.
- Momentum window, duration and bonus magnitudes.
- Dodge window and interrupted-attack recovery.
- Transformation heal percentage.
- Special auto-trigger conditions and magnitudes.
- Whether manual specials should cost a full charge or a cheaper resource.
- Whether cross-family links should be added later.

See [[Prototype 02]], [[Roster and Transformation Map]] and
[[Combat and Transformation Spec]].
