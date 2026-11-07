# Combat and Transformation Spec

**Status:** implementation reference for the 6 November 2026 Prototype 02 update.

This document defines the shared data layer and the combat rules that every form
uses. The goal is that adding an archetype is a data-authoring task: one base
form, three animal forms, one family entry and optional pack membership.

## Data layers

All data lives in `scripts/data/creature_db.gd` unless noted. Tuning rules live in
`scripts/core/rules.gd`.

### Archetype entry

```gdscript
"vanguard": {
    "family": "vanguard",
    "base": true,
    "role": "front",
    "price": 2,
}
```

- `family` — transformation family id.
- `base` — true for the six purchasable forms.
- `role` — `front`, `mid`, `back` or `support`, used by AI purchases and
  auto-placement.
- `price` — gold cost for base forms.

### Form entry

```gdscript
"bear": {
    "family": "vanguard",
    "base": false,
    "hp": 250.0,
    "dmg": 15.0,
    "interval": 1.60,
    "range": 0.40,
    "speed": 1.20,
    "armour": 25.0,
    "role": "front",
    "attack_kind": "melee",
    "attack_style": "smash",
    "windup": 0.40,
    "lunge": 16.0,
    "ability": "cleave",
    "radius": 1.0,
    "special": {
        "id": "roar",
        "type": "burst_damage",
        "radius": 1.6,
        "power": 14.0,
        "status": "exposed",
        "status_power": 15.0,
        "status_duration": 2.0,
        "auto": {"type": "nearby_enemies", "radius": 2.2, "count": 2},
    },
}
```

Required fields:

| Field | Type | Description |
|-------|------|-------------|
| `family` | string | Family key in `FAMILIES`. |
| `base` | bool | Whether this is a purchasable base form. |
| `hp` | float | Base hit points. |
| `dmg` | float | Basic attack damage. |
| `interval` | float | Seconds between attacks. |
| `range` | float | Attack range in field units. |
| `speed` | float | Move speed in units per second. |
| `armour` | float | Damage reduction percentage. |
| `role` | string | AI/placement role. |
| `attack_kind` | string | `melee` or `projectile`. |
| `attack_style` | string | Visual/feel style. |
| `windup` | float | Attack windup before commit. |
| `ability` | string | Passive/automatic ability id. |

Optional fields include `lunge`, `projectile`, `pierce`, `splash_radius`,
`slow_duration`, `slow_power`, `radius`, `duration`, `power`, `cd`, `cd_start`,
`knock`, `cleanse`, and the animal-only `special` block.

### Special entry

```gdscript
"special": {
    "id": "stampede",
    "type": "knockback",
    "radius": 2.4,
    "knock": 1.6,
    "status": "dazzled",
    "status_power": 1.6,
    "status_duration": 2.5,
    "auto": {"type": "nearby_enemies", "radius": 2.4, "count": 2},
}
```

Supported `type` values:

| Type | Effect |
|------|--------|
| `burst_damage` | Damage enemies around self or the current target. |
| `burst_heal` | Heal and optionally cleanse allies in radius. |
| `buff_allies` | Apply a positive status to allies in radius. |
| `debuff_enemies` | Apply a negative status to enemies in radius. |
| `knockback` | Push nearby enemies away and optionally apply a status. |
| `leap` | Move to a target and deal damage, optionally knock back. |
| `volley` | Fire projectiles at the nearest N enemies. |
| `self_buff` | Apply a positive status to self. |
| `evade` | Dash away from the nearest enemy and open a dodge window. |
| `retaliate` | Apply a temporary melee-damage reflection status. |

`auto` conditions: `nearby_enemies`, `nearby_allies`, `ally_wounded`,
`enemy_cluster`, `backline_in_range`, `self_low`. Missing radius/count/ratio
values fall back to safe defaults.

### Family entry

```gdscript
const FAMILIES := {
    "vanguard": ["vanguard", "bear", "turtle", "rhino"],
    "striker": ["striker", "fox", "panther", "rabbit"],
    "ranger": ["ranger", "hawk", "eagle", "phoenix"],
    "mystic": ["mystic", "raven", "shadow_raven", "owl"],
    "support": ["support", "doe", "songbird", "unicorn"],
    "berserker": ["berserker", "boar", "wolverine", "badger"],
}
```

`next_form(form_id)` returns the next form in the ladder. At the final stage it
returns the same id, meaning a refresh. `stage_of(form_id)` returns the zero-based
ladder position. `is_final_stage(form_id)` identifies Animal III.

### Rules entry

All timing and economy values are constants in `Rules`:

- `START_CHARGES`, `MAX_CHARGES`, `RECHARGE_TIME`, `TARGET_IMMUNITY`.
- `SHIFT_HEAL`, `SHIFT_ATTACK_RECOVERY`.
- `MOMENTUM_ENABLED`, `MOMENTUM_WINDOW`, `MOMENTUM_DURATION`,
  `MOMENTUM_ATTACK_SPEED`, `MOMENTUM_DAMAGE`.
- `DODGE_WINDOW`.
- `COMBAT_TIMEOUT`, `WIZARD_HP`, `FIRST_INCOME`.

## Shared combat pipeline

Every unit uses the same simulation:

1. Tick statuses.
2. Tick immunity, momentum, special lockout and visual timers.
3. Check the animal special's auto condition.
4. Resolve a pending attack if its windup has finished.
5. Resolve special movement states (`charge`, `dive`, `hop`, `dash`, `shell`).
6. Tick abilities.
7. Choose a target.
8. Move, or start an attack windup when in range.

### Transformation gating

`Battle.cast(team, unit)` applies the ladder rules:

- Base form: always advance to Animal I.
- Animal I / II: advance only if `unit.special_used` is true.
- Animal III: refresh the current form, heal/cleanse, and reset the special.
- Blocked upgrade: return false without consuming a charge.
- Valid cast: consume one charge, transform, then apply the normal effects.

The main controller checks `needs_special_for_upgrade()` before casting so it can
show the padlock/need-special feedback.

### Animal specials

A special is available only on animal forms, only once per form, and only if
`special_used` is false.

- **Auto:** `Unit._tick_special` checks the `auto` condition every 0.2 s after a
  0.5 s lockout. A met condition calls `Battle.trigger_special(team, unit, false)`
  without spending a charge.
- **Manual:** left-click calls `Battle.trigger_special(team, unit, true)`, which
  spends one charge and applies the effect.
- `_execute_special()` reads the `special.type` and applies the effect.
- Using it sets `special_used = true`, which unlocks the next upgrade.
- The special resets when entering a new form or refreshing Animal III.

Ranged/projectile-style specials reuse `Battle.spawn_projectile` with a damage
multiplier. Melee/AoE specials use `Battle.damage` with kind `"special"`.

### Attack windup

- `Unit._attack(target)` starts a windup instead of applying damage immediately.
- `pending_attack_t` counts down. When it reaches zero, `_resolve_attack()`
  applies the melee hit or spawns the projectile.
- `attack_timer` is set to the form's interval when the windup starts.
- If the target dies or the windup is cancelled, the pending attack is cleared.
- The windup is drawn as a form-specific telegraph.

### Interruption

`Battle.cast(team, unit)` checks whether the unit has a pending attack or is in a
charge/dive state. If so:

- The pending attack is cleared.
- The charge/dive is cancelled.
- `attack_timer` is set to `Rules.SHIFT_ATTACK_RECOVERY`.
- An `interrupt` effect and sound are emitted.

A normal transformation with no pending attack sets `attack_timer = 0`, keeping
the existing "transformation readies the basic attack" behaviour.

### Dodge

When a unit is transformed:

- `dodge_t = Rules.DODGE_WINDOW`.
- While `dodge_t > 0`, incoming projectiles aimed at the unit are deflected when
  they arrive.
- Deflected projectiles are removed and emit a `dodge` effect and sound.
- Melee attacks are not affected by the target's dodge window.

This makes the dodge timing-based: the projectile must arrive during the short
window. Transforming early or late does not help.

### Momentum

Per unit:

- `momentum_pending` — true after a transformation.
- `momentum_window_t` — remaining combo window.

Flow:

1. Transform: set `momentum_pending = true`, `momentum_window_t = 0`.
2. Immunity ticks down. When it reaches zero and `momentum_pending` is true, open
   the window: `momentum_window_t = Rules.MOMENTUM_WINDOW`.
3. If the unit is transformed while `momentum_window_t > 0`, the cast is a combo.
4. On combo, apply a `momentum` status with attack-speed and damage bonuses.
5. After the combo, the new transformation starts a new immunity and momentum
   cycle.
6. If the window expires, momentum resets.

The combo status is a normal positive status, so it is preserved by later
transformations until its duration ends. This is intentional: a well-timed combo
can carry into the next form.

### Transformation effects

`Unit.transform_to(new_form, combo)`:

1. Store `hp / max_hp`.
2. Replace form data.
3. Set `max_hp` from the new form and merge stars.
4. Restore health percentage, then add `Rules.SHIFT_HEAL * max_hp`.
5. Clear negative statuses; keep positive statuses.
6. Clear form-specific state (shell, charge, dive, hunt, dash).
7. Set immunity.
8. Set or preserve attack recovery according to interruption.
9. Reset the one-use special and its 0.5 s lockout.
10. Set `pop_t` for the scale-pop animation.
11. If `combo`, apply the momentum status.

No temporary levels are applied. Refreshing Animal III uses the same routine with
the same form id, which resets its special.

## AI behaviour

The AI uses the same combat and spell rules.

- **Purchases:** role-balanced, with a preference for affordable offers.
- **Placement:** front/mid/back/support rows from the form's `role`.
- **Casting:** scores targets by:
  - wounded or debuffed allies (heal/cleanse value),
  - enemies with a pending attack or charge (interrupt value),
  - allies with an incoming projectile (dodge value),
  - valid ladder upgrades and final-stage refreshes,
  - blocked upgrades are avoided.
- **Specials:** auto-triggers are free; the AI also spends a charge on a manual
  special when it has at least two charges.
- The AI avoids sitting on maximum charges.

The heuristic is deliberately simple and can be tuned in `EnemyAI`.

## Readability contract

The UI must show:

- Team ring and family accent.
- Health bar, permanent stars and status pips.
- Shapeshift immunity ring and remaining time.
- Momentum window accent and combo burst.
- Attack windup telegraph.
- Dodge flash and interrupt marker.
- Full family ladder on hover with the current stage highlighted.
- Special rune state (ready/used) and a padlock on the next gated stage.
- Charge orbs and recharge progress.

The interface remains icon-first, with as little text as possible.

## Adding an archetype

1. Add one base form and three animal forms to `FORMS`.
2. Order them in the family ladder in `FAMILIES`.
3. Add one `special` block to each animal form.
4. Add the base form to the shop pool and optionally to a starting pack.
5. Add procedural art for the four forms in `Icons.creature`.
6. Add a family colour in `FAMILY_COLORS`.
7. Add tests for the ladder, every special, and the auto conditions.
8. Run the headless tests and the capture scene.

No changes to `Unit`, `Battle` or the main loop should be needed unless the new
archetype introduces a genuinely new special type or ability behaviour.
