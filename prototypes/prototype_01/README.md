# SHIFT — Attribute-Swapping Combat

A Godot 4.7 top-down arena prototype built to test one mechanic: **swapping real
attributes, basic attacks and special abilities between living entities in the middle of a fight.**

No external assets are required. Everything is drawn procedurally with GDScript.

## Run

Open the folder in Godot 4.x and press **F5**, or:

```sh
godot --path .
```

## Controls

| Input | Action |
|---|---|
| W / A / S / D | Move |
| Left mouse (hold) | Basic attack toward cursor |
| Right mouse | Special attack toward cursor |
| Shift | Enter SHIFT targeting |
| Left mouse | Select first / second target |
| Shift picker | Click an attribute, then **Confirm Shift** |
| Right mouse / Esc | Cancel targeting or picker |
| R | Restart match |
| F11 | Toggle fullscreen |

## What is in the match

- Player team (blue, 4): Runner player **VECTOR**, Tank **BULWARK**, Ranger
  **VESPER**, Trickster **JINX**.
- Enemy team (red, 4): Bruiser **CRUSHER**, Tank **AEGIS**, Ranger **LONGSHOT**,
  Trickster **SHADE**.
- All five archetypes are present. Each has its own silhouette, base stats,
  basic attack and modular special ability.
- Basic attacks are swappable profiles too: Hammer Fist, Quick Jab, Piston Blow,
  Longshot Rifle and Phase Slash. Ranged basics launch projectiles toward the
  aim direction (cursor for the player, target for AI).
- Special abilities: Ground Slam, Dash Strike, Aegis Shield, Split Volley and
  Blink Burst. Any ability can be used by any character; damage and behaviour
  read the caster's swapped stats at cast time.

## SHIFT rules as implemented

- **5 s cooldown** between *successful* swaps. Cancelling targeting or the picker
  is free. The cooldown starts when the swap is confirmed.
- Two **distinct living** entities must be selected; either may be the player,
  an ally or an enemy. Dead units cannot be selected.
- Every attribute is same-type exchangeable: speed with speed, strength with
  strength, etc. Both the **basic attack profile** and the **special ability
  object** are exchanged as whole objects, so a Ranger can receive a Bruiser's
  hammer fist and a Tank can receive a rifle.
- **Swaps last 10 seconds real time.** An attribute + entity pair can only take
  part in one active swap at a time. Conflicts are locked in the picker, which
  makes restoration deterministic. Multiple non-conflicting swaps can coexist.
- HP is exchanged as a **percentage of maximum HP**, not as raw HP. Restoring a
  health swap also preserves the current percentage.
- On death, any swaps involving the dead unit are ended immediately and the
  living partner is restored.
- **The battle pauses while the attribute picker is open** (after two targets
  are selected). The picker, HUD and transport keys keep running; confirming
  unpauses and starts the 0.05× transfer, cancelling resumes at 1.0×.
- **Opening SHIFT slows the world to 0.40×** while you pick targets and an
  attribute. The HUD states the current time scale, and cancelling returns to
  1.0× immediately.
- Player swap animation: **0.05× time scale for 1.0 s real**, with a beam,
  opposing particle streams, pulsing target rings, value tags, a screen flash
  and a large `TIME DILATION ×0.05` indicator. The stat exchange is applied
  0.45 s in so the new values are visible during the second half of the
  transfer. Time always returns to 1.0, including through an interrupting
  restart (watchdog + generation token).
- Swap duration and shift cooldown use wall-clock time, so their countdowns are
  accurate during slow motion and visible in the HUD.

## Window and camera

- The window is resizable and the canvas expands to fill it. F11 toggles
  fullscreen. The HUD anchors to the current viewport rather than a fixed
  1280×720 canvas, and the swap picker re-centres itself on resize.
- The camera dynamically frames **every living character** with screen margins:
  it zooms out when the fight spreads out and zooms in when it clumps. The
  selected zoom range is 0.30× to 1.30×.
- HUD panels fade to 34% opacity when a living character is underneath them, so
  a framed unit is never completely hidden by an overlay.

## Enemy counter-shift

When the player swaps anything between a player-team entity and an enemy, the
enemy team responds after a short delay:

1. A banner announces an incoming counter.
2. A utility model scores every legal `(targeted enemy, living player-team
   member, attribute)` combination, excluding the attribute the player just
   used. The counter is always performed by the enemy the player targeted, not
   by a different enemy.
3. The best scoring swap is executed with its own 0.22× slow-motion transfer and
   UI notification naming that enemy.

The scoring considers archetype affinity, current/max health, melee/ranged
preference, current stats and how suitable an ability is for the receiving
character. It prefers stealing useful values from the player team and rebalancing
enemy attributes, rather than randomly swapping.

## Tuning and code map

All balance lives in `scripts/autoload/game_config.gd`:

- swap duration, shift cooldown, targeting slow-motion, slow-motion
  scale/duration/apply timing
- counter-swap delay and slow-motion timing
- movement scale, damage scale, knockback
- all archetype stats and basic-attack data
- all ability data and archetype-fit weights

Key components:

- `scripts/character/character.gd` — shared simulation, combat, drawing
- `scripts/character/character_stats.gd` — base vs current attribute dictionaries
- `scripts/character/basic_attack.gd` — swappable normal-attack profiles
- `scripts/abilities/*.gd` — modular, stateless special abilities
- `scripts/managers/swap_manager.gd` — selection flow, transactions, timers,
  conflicts, restoration, death cleanup
- `scripts/managers/combat_manager.gd` — teams, spawn, win/loss, restart
- `scripts/ai/base_ai.gd`, `ally_ai.gd`, `enemy_ai.gd` — combat AI
- `scripts/ai/counter_swap_ai.gd` — utility-based counter-shift
- `scripts/autoload/time_manager.gd` — single owner of `Engine.time_scale`
- `scripts/autoload/fx.gd` — world-space effects layer
- `scripts/ui/*` — immediate-mode HUD, inspector, picker

## Verification tools

Optional CLI modes (after `--` so Godot does not consume them):

```sh
# 70 assertions: exchange, restore, health %, conflicts, ability and basic
# attack use, projectile aim, expiry, death cleanup, counter choice
godot --headless --path . -- --selftest

# Unpaused live soak with repeated player swaps and counters, checks that
# time scale returns to 1.0
godot --headless --path . -- --soak

# Restart during slow motion, then verify fresh state and normal time
godot --headless --path . -- --restarttest

# Visual walkthrough; writes /tmp/shift_cap_*.png (needs a display)
godot --path . -- --demo

# Live fight + victory overlay screenshots
godot --path . -- --livecap

# Resize to 1600×900, 1500×1000 and fullscreen, check every unit remains on
# screen, then verify the 0.05× slowdown and screenshots
godot --path . -- --sizetest
```

## Deliberate decisions / limitations

- **Two targets must differ.** "Select yourself and ..." means yourself plus one
  other entity; swapping a value with itself is meaningless.
- **Cooldown starts on confirm, not on opening targeting.** This makes
  inspecting and cancelling safe.
- **Special cooldown is a character attribute**, separate from the ability
  object. Swapping abilities therefore does not reset the character's current
  cooldown; swapping the special-cooldown stat does change the timer. The same
  split applies to the basic attack profile and the attack-cooldown stat.
- **Health changes preserve percentage.** This is what the brief asks for and
  avoids both instant death and a free full heal from a max-HP swap.
- **Counter-shift excludes the original attribute globally**, not just for the
  same pair, so the player's swap is never instantly undone. The counter source
  is always the enemy the player targeted.
- **Only the player initiates SHIFT manually.** Enemy SHIFTs are limited to the
  counter response; this keeps the experiment controllable and readable.
- The only pause is the combat freeze while the SHIFT attribute picker is open;
  there is no general pause menu.
- No story, progression, audio, navigation mesh or destructible environment. AI
  uses direct steering; the arena is obstacle-free.
- Placeholder graphics are intentional; silhouettes and team colors carry
  readability.
