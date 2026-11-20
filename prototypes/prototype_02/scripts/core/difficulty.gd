class_name Difficulty
extends RefCounted
## Opponent difficulty, chosen on the start screen of every duel.
## Archmage uses the full-strength AI profile without difficulty penalties.
## Easier levels follow the same rules and resources; they only decide worse.

const APPRENTICE := 0
const ADEPT := 1
const ARCHMAGE := 2
const COUNT := 3 # levels offered in the game
## Balance-only reference opponent, never offered in the game: the Apprentice
## before whims. The Apprentice is calibrated to beat it about 20-25% of the time.
const SPARRING := 3

## Shop keys:
##   shop_noise     random bonus added to each offer score (archmage: tie-break only)
##   max_rerolls    rerolls per preparation (-1 = no difficulty cap)
##   upgrade_gold   gold needed besides a purchase to buy a wand upgrade
##                  (-1 = never buys it, absent = use the strategy's setting)
##   replace        sells its weakest fielded creature for a better offer
##   lock           locks valuable unaffordable duplicates for the next round
##   smart_field    keeps one frontline and one ranged creature fielded
##   whims          range of a per-duel taste for each creature, drawn once and
##                  added to its value for both purchases and fielding (0 = none)
## Casting keys:
##   first_delay    seconds before the first cast decision of a combat
##   cast_delay     seconds between two successful casts
##   retry_delay    seconds before re-evaluating when no target is worth it
##   threshold      extra score a target needs before a charge is spent
##   blunder        chance that a cast goes to a random valid creature
const PROFILES := [
	{ # Apprentice: whimsical team building, slow and clumsy spells.
		"shop_noise": 60.0, "max_rerolls": 1, "upgrade_gold": -1,
		"replace": false, "lock": false, "smart_field": false, "whims": 120.0,
		"first_delay": Vector2(3.0, 4.5), "cast_delay": Vector2(2.5, 4.0),
		"retry_delay": 1.0, "threshold": 0.15, "blunder": 0.4,
	},
	{ # Adept: sensible but imperfect shopping, measured spells.
		"shop_noise": 18.0, "max_rerolls": 2, "upgrade_gold": 9,
		"replace": true, "lock": false, "smart_field": true,
		"first_delay": Vector2(2.0, 3.5), "cast_delay": Vector2(1.6, 3.0),
		"retry_delay": 0.6, "threshold": 0.05, "blunder": 0.15,
	},
	{ # Archmage: the full-strength AI.
		"shop_noise": 0.05, "max_rerolls": -1,
		"replace": true, "lock": true, "smart_field": true,
		"first_delay": Vector2(1.0, 2.0), "cast_delay": Vector2(0.6, 1.6),
		"retry_delay": 0.3, "threshold": 0.0, "blunder": 0.0,
	},
	{ # Sparring (balance only): the Apprentice without whims.
		"shop_noise": 60.0, "max_rerolls": 1, "upgrade_gold": -1,
		"replace": false, "lock": false, "smart_field": false,
		"first_delay": Vector2(3.0, 4.5), "cast_delay": Vector2(2.5, 4.0),
		"retry_delay": 1.0, "threshold": 0.15, "blunder": 0.4,
	},
]


## Calibration only (tests/difficulty_benchmark.gd): per-level key overrides.
static var overrides: Array[Dictionary] = [{}, {}, {}, {}]


static func profile(level: int) -> Dictionary:
	var index := clampi(level, 0, PROFILES.size() - 1)
	if overrides[index].is_empty():
		return PROFILES[index]
	return PROFILES[index].merged(overrides[index], true)
