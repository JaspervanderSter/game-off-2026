class_name Palette
extends RefCounted

# --- Environment ---
const BG := Color("#05080f")
const ARENA := Color("#0b1422")
const ARENA_ALT := Color("#0e1828")
const ARENA_EDGE := Color("#204058")
const GRID := Color(0.35, 0.70, 0.90, 0.055)
const GRID_STRONG := Color(0.35, 0.80, 1.00, 0.10)

# --- Teams ---
const PLAYER := Color("#3fd6ff")
const PLAYER_DIM := Color("#1b6d8c")
const PLAYER_DARK := Color("#0c2a3a")
const ENEMY := Color("#ff5f4a")
const ENEMY_DIM := Color("#9c3527")
const ENEMY_DARK := Color("#3a120d")

# --- Text / UI ---
const TEXT := Color("#d9e8f7")
const MUTED := Color("#7d94ad")
const DIM := Color("#45586c")
const PANEL := Color(0.027, 0.047, 0.078, 0.93)
const PANEL_2 := Color(0.05, 0.085, 0.13, 0.96)
const PANEL_EDGE := Color(0.25, 0.55, 0.75, 0.28)
const EDGE_BRIGHT := Color(0.35, 0.85, 1.00, 0.70)
const WHITE := Color("#ffffff")

# --- Semantic ---
const BUFF := Color("#54ffb4")
const DEBUFF := Color("#ff9a5c")
const SWAP := Color("#c98bff")
const WARN := Color("#ffd166")
const GOOD := Color("#6bffb8")
const BAD := Color("#ff5468")

# --- Attributes ---
const ATTR_SPEED := Color("#ffe066")
const ATTR_STRENGTH := Color("#ff8b5c")
const ATTR_WEIGHT := Color("#89b4d6")
const ATTR_HEALTH := Color("#67e8a0")
const ATTR_ACD := Color("#5ce1e6")
const ATTR_SCD := Color("#a78bfa")
const ATTR_BASIC := Color("#ffc46b")
const ATTR_SPECIAL := Color("#f472ff")

# --- Abilities ---
const ABILITY_SLAM := Color("#ffb347")
const ABILITY_DASH := Color("#ffe66d")
const ABILITY_SHIELD := Color("#6ee7ff")
const ABILITY_VOLLEY := Color("#7dffb0")
const ABILITY_BLINK := Color("#e07bff")


static func team_color(team: int) -> Color:
	return PLAYER if team == 0 else ENEMY


static func team_dim(team: int) -> Color:
	return PLAYER_DIM if team == 0 else ENEMY_DIM


static func team_dark(team: int) -> Color:
	return PLAYER_DARK if team == 0 else ENEMY_DARK


static func attr_color(attr: String) -> Color:
	match attr:
		"speed":
			return ATTR_SPEED
		"strength":
			return ATTR_STRENGTH
		"weight":
			return ATTR_WEIGHT
		"health":
			return ATTR_HEALTH
		"attack_cooldown":
			return ATTR_ACD
		"special_cooldown":
			return ATTR_SCD
		"basic":
			return ATTR_BASIC
		"special":
			return ATTR_SPECIAL
	return TEXT
