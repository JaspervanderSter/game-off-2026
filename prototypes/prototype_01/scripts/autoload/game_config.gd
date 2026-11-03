extends Node
## Central tuning + content definitions for SHIFT.
## All balance values live here so the prototype can be iterated quickly.

# ---------------------------------------------------------------------------
# Arena
# ---------------------------------------------------------------------------
var arena_rect := Rect2(0, 0, 1600, 1000)
var arena_inset := 26.0

# ---------------------------------------------------------------------------
# Attributes
# ---------------------------------------------------------------------------
const ATTRS := ["speed", "strength", "weight", "health", "attack_cooldown", "special_cooldown", "basic", "special"]

const ATTR_LABELS := {
	"speed": "SPEED",
	"strength": "STRENGTH",
	"weight": "WEIGHT",
	"health": "MAX HEALTH",
	"attack_cooldown": "ATTACK CD",
	"special_cooldown": "SPECIAL CD",
	"basic": "BASIC ATTACK",
	"special": "SPECIAL",
}

const ATTR_SHORT := {
	"speed": "SPD",
	"strength": "STR",
	"weight": "WGT",
	"health": "HP",
	"attack_cooldown": "ACD",
	"special_cooldown": "SCD",
	"basic": "BASIC",
	"special": "SPEC",
}

# ---------------------------------------------------------------------------
# SHIFT / time
# ---------------------------------------------------------------------------
var swap_duration := 10.0            # seconds (real time)
var shift_cooldown := 5.0            # seconds (real time)
var targeting_scale := 0.40          # tactical time while SHIFT targeting is open
var slowmo_scale := 0.05
var slowmo_duration := 1.0           # real seconds
var slowmo_apply_at := 0.45          # real seconds into the sequence

var counter_swap_delay := 1.25       # real seconds after the player's swap lands
var counter_slowmo_scale := 0.22
var counter_slowmo_duration := 0.62
var counter_slowmo_apply_at := 0.24

# ---------------------------------------------------------------------------
# Combat
# ---------------------------------------------------------------------------
var move_speed_scale := 24.0         # px/s per speed point
var damage_scale := 2.2
var knockback_decay := 1400.0
var shield_knockback_resist := 0.12

# ---------------------------------------------------------------------------
# Ability definitions
# ---------------------------------------------------------------------------
var ABILITY_DEFS := {
	"ground_slam": {
		"name": "GROUND SLAM",
		"short": "SLAM",
		"glyph": "◉",
		"color": Palette.ABILITY_SLAM,
		"origin": "Bruiser",
		"desc": "AoE shockwave. Huge knockback + brief stun.",
		"radius": 120.0,
		"damage_mult": 2.0,
		"flat": 10.0,
		"knockback": 840.0,
		"stun": 0.45,
		"fit": {"Bruiser": 1.0, "Tank": 0.9, "Trickster": 0.3, "Ranger": 0.2, "Runner": 0.15},
	},
	"dash": {
		"name": "DASH STRIKE",
		"short": "DASH",
		"glyph": "»",
		"color": Palette.ABILITY_DASH,
		"origin": "Runner",
		"desc": "Blink-dash forward, cutting everything in the path.",
		"distance": 200.0,
		"speed": 950.0,
		"damage_mult": 1.45,
		"flat": 8.0,
		"knockback": 320.0,
		"hit_radius": 30.0,
		"fit": {"Runner": 1.0, "Trickster": 0.9, "Ranger": 0.55, "Bruiser": 0.25, "Tank": 0.2},
	},
	"shield": {
		"name": "AEGIS SHIELD",
		"short": "SHIELD",
		"glyph": "⬡",
		"color": Palette.ABILITY_SHIELD,
		"origin": "Tank",
		"desc": "Absorbs damage and heavily resists knockback.",
		"amount_base": 40.0,
		"amount_weight": 4.5,
		"duration": 4.0,
		"fit": {"Tank": 1.0, "Bruiser": 0.85, "Trickster": 0.5, "Ranger": 0.4, "Runner": 0.35},
	},
	"multishot": {
		"name": "SPLIT VOLLEY",
		"short": "VOLLEY",
		"glyph": "⋔",
		"color": Palette.ABILITY_VOLLEY,
		"origin": "Ranger",
		"desc": "Five projectiles in a wide fan.",
		"count": 5,
		"spread": 34.0,
		"damage_mult": 0.75,
		"flat": 3.0,
		"knockback": 90.0,
		"projectile_speed": 620.0,
		"fit": {"Ranger": 1.0, "Runner": 0.5, "Trickster": 0.4, "Tank": 0.3, "Bruiser": 0.2},
	},
	"blink": {
		"name": "BLINK BURST",
		"short": "BLINK",
		"glyph": "✦",
		"color": Palette.ABILITY_BLINK,
		"origin": "Trickster",
		"desc": "Teleport toward aim, detonating at the departure point.",
		"distance": 210.0,
		"radius": 105.0,
		"damage_mult": 1.7,
		"flat": 8.0,
		"knockback": 460.0,
		"fit": {"Trickster": 1.0, "Runner": 0.8, "Ranger": 0.6, "Bruiser": 0.3, "Tank": 0.25},
	},
}

# ---------------------------------------------------------------------------
# Archetypes
# ---------------------------------------------------------------------------
var ARCHETYPES := {
	"Bruiser": {
		"display": "BRUISER",
		"shape": "bruiser",
		"radius": 21.0,
		"speed": 4.2,
		"strength": 8.5,
		"weight": 9.0,
		"health": 155.0,
		"attack_cooldown": 0.95,
		"special_cooldown": 7.0,
		"ability": "ground_slam",
		"desc": "Heavy hitter. Slow, durable, enormous knockback.",
		"basic": {
			"name": "HAMMER FIST",
			"short": "HAMMER",
			"desc": "Slow, crushing melee blow.",
			"kind": "melee",
			"range": 76.0,
			"arc": 110.0,
			"damage_mult": 1.15,
			"knockback": 340.0,
			"swing": 0.18,
			"color": Palette.ATTR_STRENGTH,
			"fit": {"Bruiser": 1.0, "Tank": 0.9, "Trickster": 0.55, "Runner": 0.4, "Ranger": 0.25},
		},
	},
	"Runner": {
		"display": "RUNNER",
		"shape": "runner",
		"radius": 14.0,
		"speed": 9.0,
		"strength": 3.2,
		"weight": 3.0,
		"health": 70.0,
		"attack_cooldown": 0.34,
		"special_cooldown": 3.4,
		"ability": "dash",
		"desc": "Glass-cannon skirmisher. Fastest feet in the arena.",
		"basic": {
			"name": "QUICK JAB",
			"short": "JAB",
			"desc": "Very fast short-range jab.",
			"kind": "melee",
			"range": 60.0,
			"arc": 80.0,
			"damage_mult": 0.85,
			"knockback": 130.0,
			"swing": 0.1,
			"color": Palette.ATTR_SPEED,
			"fit": {"Runner": 1.0, "Trickster": 0.8, "Ranger": 0.5, "Bruiser": 0.35, "Tank": 0.35},
		},
	},
	"Tank": {
		"display": "TANK",
		"shape": "tank",
		"radius": 24.0,
		"speed": 3.0,
		"strength": 5.5,
		"weight": 11.0,
		"health": 200.0,
		"attack_cooldown": 1.15,
		"special_cooldown": 8.0,
		"ability": "shield",
		"desc": "Immovable anvil. Hard to move, hard to kill.",
		"basic": {
			"name": "PISTON BLOW",
			"short": "PISTON",
			"desc": "Heavy melee strike with huge knockback.",
			"kind": "melee",
			"range": 78.0,
			"arc": 120.0,
			"damage_mult": 1.25,
			"knockback": 460.0,
			"swing": 0.22,
			"color": Palette.ATTR_WEIGHT,
			"fit": {"Tank": 1.0, "Bruiser": 0.9, "Trickster": 0.4, "Runner": 0.3, "Ranger": 0.25},
		},
	},
	"Ranger": {
		"display": "RANGER",
		"shape": "ranger",
		"radius": 15.0,
		"speed": 6.3,
		"strength": 3.4,
		"weight": 4.0,
		"health": 75.0,
		"attack_cooldown": 0.62,
		"special_cooldown": 5.0,
		"ability": "multishot",
		"desc": "Skilled marksman. Fragile at close range.",
		"basic": {
			"name": "LONGSHOT RIFLE",
			"short": "RIFLE",
			"desc": "Aimed projectile toward the cursor.",
			"kind": "ranged",
			"range": 460.0,
			"arc": 0.0,
			"damage_mult": 0.95,
			"knockback": 100.0,
			"projectile_speed": 640.0,
			"projectile_radius": 6.0,
			"swing": 0.08,
			"color": Palette.ATTR_HEALTH,
			"fit": {"Ranger": 1.0, "Runner": 0.85, "Trickster": 0.75, "Bruiser": 0.8, "Tank": 0.75},
		},
	},
	"Trickster": {
		"display": "TRICKSTER",
		"shape": "trickster",
		"radius": 15.0,
		"speed": 7.4,
		"strength": 4.6,
		"weight": 4.2,
		"health": 95.0,
		"attack_cooldown": 0.42,
		"special_cooldown": 5.5,
		"ability": "blink",
		"desc": "Balanced duelist with a teleporting burst.",
		"basic": {
			"name": "PHASE SLASH",
			"short": "SLASH",
			"desc": "Quick arc slash.",
			"kind": "melee",
			"range": 66.0,
			"arc": 90.0,
			"damage_mult": 0.92,
			"knockback": 150.0,
			"swing": 0.12,
			"color": Palette.ATTR_SPECIAL,
			"fit": {"Trickster": 1.0, "Runner": 0.85, "Ranger": 0.5, "Bruiser": 0.4, "Tank": 0.4},
		},
	},
}


func make_ability(id: String) -> Ability:
	var a: Ability
	match id:
		"ground_slam":
			a = GroundSlamAbility.new()
		"dash":
			a = DashAbility.new()
		"shield":
			a = ShieldAbility.new()
		"multishot":
			a = MultishotAbility.new()
		"blink":
			a = BlinkAbility.new()
		_:
			a = Ability.new()
	var d: Dictionary = ABILITY_DEFS.get(id, {})
	a.id = id
	a.display_name = d.get("name", id.to_upper())
	a.short_name = d.get("short", id.to_upper())
	a.color = d.get("color", Palette.WHITE)
	a.glyph = d.get("glyph", "◆")
	a.description = d.get("desc", "")
	a.origin_archetype = d.get("origin", "")
	return a


func make_basic(archetype_id: String) -> BasicAttack:
	var def: Dictionary = ARCHETYPES.get(archetype_id, {})
	var b: Dictionary = def.get("basic", {})
	var ba := BasicAttack.new()
	ba.id = archetype_id.to_lower() + "_basic"
	ba.display_name = str(b.get("name", archetype_id.to_upper() + " STRIKE"))
	ba.short_name = str(b.get("short", "BASIC"))
	ba.description = str(b.get("desc", ""))
	ba.kind = str(b.get("kind", "melee"))
	ba.range = float(b.get("range", 70.0))
	ba.arc = float(b.get("arc", 90.0))
	ba.damage_mult = float(b.get("damage_mult", 1.0))
	ba.knockback = float(b.get("knockback", 100.0))
	ba.swing = float(b.get("swing", 0.15))
	ba.projectile_speed = float(b.get("projectile_speed", 600.0))
	ba.projectile_radius = float(b.get("projectile_radius", 6.0))
	ba.color = b.get("color", Palette.WHITE)
	ba.origin_archetype = archetype_id
	ba.fit = b.get("fit", {})
	return ba


func ability_def(id: String) -> Dictionary:
	return ABILITY_DEFS.get(id, {})


func archetype(id: String) -> Dictionary:
	return ARCHETYPES.get(id, {})


func is_melee(archetype_id: String) -> bool:
	var d: Dictionary = ARCHETYPES.get(archetype_id, {})
	return d.get("basic", {}).get("kind", "melee") == "melee"


func attr_text(attr: String, value: Variant) -> String:
	if value == null:
		return "—"
	if attr == "basic":
		if value is BasicAttack:
			return (value as BasicAttack).short_name
		return "—"
	if attr == "special":
		if value is Ability:
			return (value as Ability).short_name
		return "—"
	if attr == "health":
		return "%d" % int(round(float(value)))
	if attr == "attack_cooldown" or attr == "special_cooldown":
		return "%.2fs" % float(value)
	return "%.1f" % float(value)


func attr_quality(attr: String, current: Variant, base: Variant) -> int:
	# -1 reduced, 0 normal, 1 improved
	if attr == "basic" or attr == "special":
		return 0
	if attr == "attack_cooldown" or attr == "special_cooldown":
		if float(current) < float(base) - 0.001:
			return 1
		if float(current) > float(base) + 0.001:
			return -1
		return 0
	if float(current) > float(base) + 0.001:
		return 1
	if float(current) < float(base) - 0.001:
		return -1
	return 0
