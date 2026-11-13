class_name Rules
extends RefCounted
## Tunable rule values for Prototype 02.
## Source: docs/design/Prototype 02.md (confirmed rules + delegated defaults).

# Board geometry. Distances in creature data are expressed in cells.
const CELL := 72.0
const COLS := 8
const ROWS := 6
const BOARD_SIZE := Vector2(COLS * CELL, ROWS * CELL)
const BODY_RADIUS := 0.32 # cells

# Capacities.
const FIELD_CAP := 6
const RESERVE_CAP := 6

# Duel.
const WIZARD_HP := 10
const DAMAGE_PER_SURVIVOR := 0.5
const FIRST_INCOME := 3 # +1 gold each subsequent round
const SHOP_SIZE := 3
const REROLL_COST := 1
const MAX_STARS := 3
const COMBAT_TIMEOUT := 60.0
const FRENZY_START := 45.0
const FRENZY_STEP_SECONDS := 3.0
const FRENZY_BONUS_PER_STEP := 0.20
const FRENZY_MAX_LEVEL := 5

# Shapeshift spell.
const START_CHARGES := 1
const MAX_CHARGES := 3
const RECHARGE_TIME := 3.0
const SHIFT_RECHARGE_COST := 4
const UPGRADED_RECHARGE_TIME := 2.4
const TARGET_IMMUNITY := 3.0
const SHIFT_HEAL := 0.10 # fraction of the new max HP
const ENEMY_SHIFT_STUN := 3.0
const LEVEL_VISUAL_GROWTH := 0.15 # additive image scale per temporary level
const MAX_LEVEL_VISUAL_SCALE := 1.6 # keep crowded fights readable
const LEVEL_SCALE := 0.20 # max HP and basic damage per level above 1

# Screen layout (1280 x 720).
const BOARD_POS := Vector2(352, 84)
const RESERVE_POS := Vector2(424, 548)
const SHOP_RECT := Rect2(968, 84, 288, 372)
const FIGHT_CENTER := Vector2(1112, 560)
const FIGHT_RADIUS := 58.0


static func income(round_num: int) -> int:
	return FIRST_INCOME + round_num - 1


static func star_mult(stars: int) -> float:
	return pow(1.8, clampi(stars, 0, MAX_STARS))


static func level_mult(level: int) -> float:
	return 1.0 + LEVEL_SCALE * (level - 1)


static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * CELL, (cell.y + 0.5) * CELL)


static func team_rows(team: int) -> Array[int]:
	# Player (team 0) owns the bottom half, the enemy the top half.
	if team == 0:
		return [3, 4, 5]
	return [0, 1, 2]


static func reserve_slot_rect(slot: int) -> Rect2:
	return Rect2(RESERVE_POS + Vector2(slot * CELL, 0), Vector2(CELL, CELL))
