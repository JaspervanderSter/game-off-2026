# Roster and Transformation Map

**Status:** design and implementation reference for the 6 November 2026
Prototype 02 update. The previous 24-form, eight-stage network is superseded.

## Roster shape

- **Six purchasable archetypes**: Vanguard, Striker, Ranger, Mystic, Support,
  Berserker.
- **Six directed transformation ladders**, one per archetype.
- **Four forms per ladder**: the fantasy base form and three animal stages.
- **24 forms total**, but only six are sold in the shop. Animals are
  transformation outcomes only.
- Base → Animal I always succeeds. Animal I → Animal II and II → III require the
  current animal's one-use special. Animal III refreshes instead of upgrading.

The ladders are role-preserving. This keeps the possibility sets small and
recognisable. Cross-family links are not used in this iteration.

## Families

| Family | Base | Animal I | Animal II | Animal III | Colour accent |
| --- | --- | --- | --- | --- | --- |
| Vanguard | Vanguard | Bear | Turtle | Rhino | Steel blue |
| Striker | Striker | Fox | Panther | Rabbit | Ember orange |
| Ranger | Ranger | Hawk | Eagle | Phoenix | Forest green |
| Mystic | Mystic | Raven | Shadow Raven | Owl | Arcane violet |
| Support | Support | Doe | Songbird | Unicorn | Warm gold |
| Berserker | Berserker | Boar | Wolverine | Badger | Blood red |

### Transformation ladder

Each family advances in one direction:

```text
Vanguard → Bear → Turtle → Rhino → (refresh Rhino)
Striker  → Fox → Panther → Rabbit → (refresh Rabbit)
Ranger   → Hawk → Eagle → Phoenix → (refresh Phoenix)
Mystic   → Raven → Shadow Raven → Owl → (refresh Owl)
Support  → Doe → Songbird → Unicorn → (refresh Unicorn)
Berserker→ Boar → Wolverine → Badger → (refresh Badger)
```

- A base form always transforms into its Animal I.
- An Animal I or Animal II can only upgrade after its special has been used.
- An Animal III cast refreshes the form: it keeps the form, heals/cleanses, and
  resets the special.
- The previous complete graph caused immediate ping-pong such as
  `Ranger → Hawk → Ranger`; the ladder removes that.

### Animal specials

Every animal has a one-use special. It can trigger automatically when its data
condition is met, or manually by left-clicking the friendly animal and spending
one charge. Using it unlocks the next upgrade.

| Family | Specials in ladder order |
| --- | --- |
| Vanguard | Bear: Roar (area damage + exposed) · Turtle: Fortify (ally armour) · Rhino: Stampede (knockback + stagger) |
| Striker | Fox: Pounce (leap to backline) · Panther: Frenzy (self attack speed) · Rabbit: Evade (dash + dodge) |
| Ranger | Hawk: Volley (multi-shot) · Eagle: Skyfall (long dive) · Phoenix: Firestorm (area fire) |
| Mystic | Raven: Frost Nova (area slow) · Shadow Raven: Shadow Nova (area damage) · Owl: Screech (attack slow) |
| Support | Doe: Bloom (area heal) · Songbird: Crescendo (ally attack speed) · Unicorn: Purify (area heal + cleanse) |
| Berserker | Boar: Gore (leap + knockback) · Wolverine: Frenzy (self attack speed) · Badger: Quills (retaliation) |

Auto conditions include nearby enemies, enemy backline in range, enemy clusters,
wounded allies, and low self-health. They are stored with each special in
`CreatureDB.FORMS`.

## Shared statistics

| Field | Meaning |
| --- | --- |
| `hp` | Maximum health. |
| `dmg` | Damage per basic attack before reduction. |
| `interval` | Seconds between basic attacks. |
| `range` | Basic attack reach in board cells, edge to edge. |
| `speed` | Movement speed in board cells per second. |
| `armour` | Percentage of incoming damage reduced, capped at 85%. |
| `price` | Gold cost for purchasable base forms. |

Temporary levels are removed. Permanent merge stars still multiply maximum health
and basic damage by 1 / 1.8 / 3.24.

## Attack behaviours

| `attack_style` | Used by | Presentation |
| --- | --- | --- |
| `thrust` | Vanguard, Unicorn | Short forward thrust or shield-assisted strike. |
| `slash` | Striker, Fox, Panther, Wolverine, Badger | Quick lunge and slash arc. |
| `smash` | Berserker, Bear, Rhino, Boar | Slow overhead swing with heavy impact. |
| `bite` | Turtle, Rabbit, Doe | Short snapping bite. |
| `bow` | Ranger, Hawk, Eagle | Draw and release a projectile. |
| `cast` | Mystic, Raven, Shadow Raven, Owl, Phoenix, Support, Songbird | Casting motion and magical projectile. |
| `support` | Reserved for pure support motions | Supportive pulse. |

Each form has a `windup` value. The windup is the interruptible part of the
attack. `lunge` controls the forward animation distance for melee styles.

## Form data

All values are first-pass tuning values. They are deliberately varied to give
each form a different tactical profile, not to form a power ladder.

### Vanguard family

| Form | HP | DMG | Interval | Range | Speed | Armour | Price | Attack | Windup | Ability |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Vanguard | 260 | 8 | 1.40 | 0.35 | 1.10 | 40 | 2 | melee thrust | 0.30 | Guard aura |
| Bear | 250 | 15 | 1.60 | 0.40 | 1.20 | 25 | — | melee smash | 0.40 | Cleave |
| Turtle | 330 | 6 | 1.70 | 0.35 | 0.80 | 35 | — | melee bite | 0.30 | Shell |
| Rhino | 225 | 18 | 2.00 | 0.35 | 1.50 | 20 | — | melee smash | 0.50 | Charge |

**Vanguard** is the durable anchor. Its guard aura gives nearby allies extra
armour. **Bear** trades some protection for area melee damage. **Turtle** is the
slowest and most durable form, periodically withdrawing into its shell. **Rhino**
is a burst/displacement form with a long charge and a long windup.

### Striker family

| Form | HP | DMG | Interval | Range | Speed | Armour | Price | Attack | Windup | Ability |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Striker | 130 | 14 | 0.80 | 0.35 | 2.20 | 5 | 2 | melee slash | 0.12 | Backline target |
| Fox | 115 | 11 | 0.70 | 0.35 | 2.80 | 0 | — | melee slash | 0.10 | Backline target |
| Panther | 145 | 15 | 0.85 | 0.35 | 2.40 | 5 | — | melee slash | 0.15 | Hunt wounded |
| Rabbit | 100 | 9 | 0.60 | 0.35 | 3.00 | 0 | — | melee bite | 0.10 | Hop away |

**Striker** is fast and fragile, initially seeking a distant backline target.
**Fox** is the fastest and most extreme version. **Panther** is more durable and
prioritises wounded enemies. **Rabbit** is the most evasive but has the least
health.

### Ranger family

| Form | HP | DMG | Interval | Range | Speed | Armour | Price | Attack | Windup | Ability |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Ranger | 90 | 8 | 0.90 | 4.50 | 1.80 | 0 | 1 | projectile bow | 0.35 | Kite |
| Hawk | 95 | 9 | 0.80 | 4.00 | 2.00 | 0 | — | projectile bow | 0.30 | Kite |
| Eagle | 120 | 12 | 1.10 | 3.00 | 2.20 | 0 | — | projectile bow | 0.35 | Dive |
| Phoenix | 130 | 14 | 1.50 | 4.00 | 1.60 | 5 | — | projectile cast | 0.40 | Splash |

**Ranger** is the cheap, fragile ranged damage dealer. **Hawk** is a faster but
shorter-ranged version. **Eagle** is tougher and periodically dives onto a distant
enemy. **Phoenix** is slower but deals area fire damage.

### Mystic family

| Form | HP | DMG | Interval | Range | Speed | Armour | Price | Attack | Windup | Ability |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Mystic | 105 | 11 | 1.60 | 4.00 | 1.30 | 0 | 3 | projectile cast | 0.45 | Chill |
| Raven | 95 | 8 | 1.20 | 4.00 | 1.80 | 0 | — | projectile cast | 0.35 | Chill |
| Shadow Raven | 115 | 13 | 1.60 | 4.20 | 1.50 | 0 | — | projectile cast | 0.45 | Splash |
| Owl | 110 | 7 | 1.40 | 3.50 | 1.40 | 5 | — | projectile cast | 0.35 | Dazzle |

**Mystic** controls movement with frost attacks. **Raven** trades damage for a
faster, stronger slow. **Shadow Raven** trades control for area damage. **Owl**
slows enemy attack speed instead of movement.

### Support family

| Form | HP | DMG | Interval | Range | Speed | Armour | Price | Attack | Windup | Ability |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Support | 125 | 5 | 1.50 | 3.00 | 1.40 | 10 | 2 | projectile cast | 0.35 | Heal |
| Doe | 150 | 6 | 1.40 | 0.40 | 1.90 | 5 | — | melee bite | 0.25 | Heal |
| Songbird | 90 | 5 | 1.20 | 3.50 | 2.00 | 0 | — | projectile cast | 0.25 | Inspire |
| Unicorn | 175 | 9 | 1.60 | 0.50 | 1.60 | 10 | — | melee thrust | 0.30 | Heal + cleanse |

**Support** is the ranged healer. **Doe** is a mobile melee healer. **Songbird**
is fragile but buffs nearby allies' attack speed. **Unicorn** is the sturdiest
healer, cleanses negative effects, and is the final support stage.

### Berserker family

| Form | HP | DMG | Interval | Range | Speed | Armour | Price | Attack | Windup | Ability |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Berserker | 180 | 16 | 1.30 | 0.35 | 1.60 | 10 | 3 | melee smash | 0.45 | Berserk |
| Boar | 190 | 16 | 1.50 | 0.35 | 1.70 | 10 | — | melee smash | 0.40 | Charge |
| Wolverine | 170 | 13 | 1.00 | 0.35 | 1.90 | 0 | — | melee slash | 0.20 | Berserk |
| Badger | 185 | 14 | 1.40 | 0.35 | 1.50 | 0 | — | melee slash | 0.25 | Thorns |

**Berserker** is the slow, heavy hitter that speeds up as it loses health.
**Boar** adds a charge and knockback. **Wolverine** trades some health for a
faster baseline and a stronger berserk curve. **Badger** punishes melee attackers
with reflected damage.

## Ability vocabulary

The roster uses a small shared vocabulary. A new archetype can reuse any of these
or add one new data-driven ability.

| Ability | Behaviour |
| --- | --- |
| `guard` | Applies a short armour buff to nearby allies. |
| `backline` | First target is the farthest enemy. |
| `kite` | Steps away from melee attackers while reloading. |
| `chill` | Projectile applies a movement slow. |
| `heal` | Periodically heals the most wounded ally in range. |
| `berserk` | Attack interval improves as health falls. |
| `cleave` | Melee attack damages enemies near the target. |
| `shell` | Periodically gains bonus armour and stops attacking briefly. |
| `charge` | Charges a distant target and knocks it back. |
| `hunt` | Retargets the most wounded enemy nearby. |
| `hop` | Hops away from a nearby melee attacker. |
| `dive` | Dives onto a distant enemy for bonus damage. |
| `splash` | Projectile damages enemies in a small area. |
| `dazzle` | Slows the attack speed of nearby enemies. |
| `inspire` | Buffs nearby allies' attack speed. |
| `thorns` | Reflects damage when hit by a melee attack. |

## Shop and starting packs

The shop sells only the six base archetypes. Starting packs are three-creature
combinations drawn from the six archetypes. The implementation uses thematic
packs such as:

- Vanguard, Berserker, Ranger
- Vanguard, Support, Ranger
- Mystic, Support, Vanguard
- Striker, Ranger, Support
- Ranger, Mystic, Vanguard
- Berserker, Striker, Support

Pack contents and prices remain tuning values.

## Next decisions

1. Playtest whether role-preserving ladders create enough tactical variety.
2. Tune each animal's auto-trigger condition and special magnitude.
3. Decide whether manual specials should cost a full charge or a cheaper cost.
4. Tune momentum window and combo strength.
5. Tune windup and dodge windows for readable timing.
6. Decide whether a later iteration needs branching or cross-family links.
