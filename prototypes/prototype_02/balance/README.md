# Balance suite (on demand only)

Measures the raw combat strength of every form so tuning decisions can rely on
data rather than intuition. **This is not a regression test.** It is kept out of
`tests/` on purpose: run it only when the user explicitly asks for a balance run.

## What it does

- Every ordered pair of the 24 forms (fantasy and animals) fights a 1v1 duel at
  the same star rank, for each requested rank (default 0, 1, 2 and 3).
- No shapeshifting: both wizards' casting is disabled, so only stats and
  abilities are measured.
- Each repetition places both units on random cells of their own half. Seeds are
  derived from the duel itself (base seed, rank, forms, repetition), so results are
  reproducible and independent of the worker count or the form selection.
- Ordered pairs mean each matchup is played from both board sides. Mirror duels
  (a form against itself) are run only to check side bias and are excluded from
  rankings.
- Duels run in parallel headless Godot processes with all audio muted
  (`--headless --audio-driver Dummy` plus the game's `--no-sound` argument).

The full default run (23,040 duels) takes about 40 seconds on a 24-thread machine.

## Run

From PowerShell, in `prototypes/prototype_02/balance/`:

```powershell
./run_balance.ps1
./run_balance.ps1 -Reps 20 -Workers 16
./run_balance.ps1 -Stars 0 -Forms peasant,guardian,archer
```

The script finds Godot from `-Godot <path>`, `$env:GODOT`, the `PATH`, or
`%USERPROFILE%\Tools\Godot`. It imports the project first when `.godot/` is
missing (or with `-Import`).

Equivalent direct command, from the repository root:

```bash
godot --headless --audio-driver Dummy --path prototypes/prototype_02 res://balance/balance.tscn -- --no-sound
```

User arguments after `--`: `--workers=N` (default: CPU threads - 2),
`--reps=N` (duels per ordered pair and rank, default 10), `--stars=0,1,2,3`,
`--forms=all|id,id,...`, `--seed=N` (default 1), `--out=DIR`, `--help`.

## Output

Each run writes a timestamped folder in `balance/results/` (gitignored, and
hidden from the Godot importer by a generated `.gdignore`):

| File | Content |
| --- | --- |
| `duels.csv` | One row per duel: rank, forms (`a` = bottom team 0, `b` = top team 1), seed, spawn cells, start distance (cells), winner (0 / 1 / -1 draw), duration, timeout flag, final and max HP, damage taken, healing received and parries per side. |
| `matchups.csv` | Each form against each opponent at each rank, both sides combined: wins / losses / draws, score, average HP margin, duration, damage dealt / taken, healing. |
| `ranking.csv` | Per rank, forms sorted by score, with family, role, price, Bradley-Terry rating, opponents beaten / lost to and averages. |
| `summary.json` | Run configuration, rankings, price-vs-score Spearman correlation (fantasy only and all forms), side bias, draw rate and timeouts per rank. |

Metric definitions:

- **score**: (wins + 0.5 x draws) / games against the whole field. 0.5 is average.
- **bt_rating**: Bradley-Terry strength on an Elo-like scale (mean 1500; +400 =
  10:1 odds). It accounts for whom each form beat. Each pair gets one virtual draw
  to keep undefeated or winless forms finite.
- **hp_margin**: own remaining HP fraction minus the opponent's, from -1 to +1.
  It shows how decisive a matchup is, beyond win/loss.
- **price_vs_score_spearman**: +1 means price perfectly orders strength; near 0
  means price does not predict 1v1 strength. Animal prices are only AI value
  estimates.

## Limits

1v1 duels undervalue supports (cleric, bard, deer, peacock) and area abilities
(pyromancer splash, blizzard, cleave). They also ignore price and team synergies.
Treat the ranking as raw dueling strength, not overall value. Equal-gold budgets,
units inside reference teams and shapeshifting runs are possible later extensions.
