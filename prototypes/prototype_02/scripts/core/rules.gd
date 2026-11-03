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
const FIRST_INCOME := 3 # +1 gold each subsequent round
const SHOP_SIZE := 3
const REROLL_COST := 1
const MAX_STARS := 3
const COMBAT_TIMEOUT := 60.0

# Shapeshift spell.
const START_CHARGES := 1
const MAX_CHARGES := 3
const RECHARGE_TIME := 3.0
const TARGET_IMMUNITY := 3.0
const SHIFT_HEAL := 0.10 # fraction of the new max HP
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
	return pow(1.8, clampi(stars, 1, MAX_STARS) - 1)


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
