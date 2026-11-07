class_name CreatureDB
extends RefCounted
## Shared roster and transformation data for Prototype 02.
##
## The six purchasable archetypes each own a four-form transformation family.
## Adding an archetype means adding one base form, three animal forms, one
## family entry and optional pack membership. Combat code reads this data and
## does not branch on individual form ids.
##
## Units:
##   hp: HP, dmg: HP per basic hit, interval: s between attacks,
##   range: cells edge to edge, speed: cells/s, armour: % damage reduced,
##   price: gold. Permanent merge stars scale HP and basic damage; ability
##   magnitudes remain fixed.

const BASE_FORMS := [
	"vanguard", "striker", "ranger", "mystic", "support", "berserker",
]

# Ordered family forms. The first entry is the purchasable fantasy base form.
const FAMILIES := {
	"vanguard": ["vanguard", "bear", "turtle", "rhino"],
	"striker": ["striker", "fox", "panther", "rabbit"],
	"ranger": ["ranger", "hawk", "eagle", "phoenix"],
	"mystic": ["mystic", "raven", "shadow_raven", "owl"],
	"support": ["support", "doe", "songbird", "unicorn"],
	"berserker": ["berserker", "boar", "wolverine", "badger"],
}

# Family accent colours used by the interface. Team colours remain blue/red.
const FAMILY_COLORS := {
	"vanguard": Color(0.45, 0.68, 0.95),
	"striker": Color(1.0, 0.52, 0.28),
	"ranger": Color(0.42, 0.86, 0.52),
	"mystic": Color(0.72, 0.48, 1.0),
	"support": Color(1.0, 0.84, 0.38),
	"berserker": Color(0.95, 0.28, 0.24),
}

# Generic combo effect. A form can override this with a "combo" dictionary.
const COMBO_DEFAULT := {
	"duration": 4.0,
	"attack_speed": 0.25,
	"damage": 0.15,
}

# Normalisation maxima for the hover-card bars.
const STAT_MAX := {
	"hp": 330.0,
	"dps": 20.0,
	"interval": 2.0,
	"range": 5.0,
	"speed": 3.0,
	"armour": 45.0,
}

const FORMS := {
	# --- Vanguard family -------------------------------------------------
	"vanguard": {
		"family": "vanguard", "base": true, "role": "front", "price": 2,
		"hp": 260.0, "dmg": 8.0, "interval": 1.40, "range": 0.35,
		"speed": 1.10, "armour": 40.0,
		"attack_kind": "melee", "attack_style": "thrust", "windup": 0.30, "lunge": 8.0,
		"ability": "guard", "radius": 2.2, "power": 12.0,
	},
	"bear": {
		"family": "vanguard", "base": false, "role": "front", "price": 0,
		"hp": 250.0, "dmg": 15.0, "interval": 1.60, "range": 0.40,
		"speed": 1.20, "armour": 25.0,
		"attack_kind": "melee", "attack_style": "smash", "windup": 0.40, "lunge": 16.0,
		"ability": "cleave", "radius": 1.0,
		"special": {
			"id": "roar", "type": "burst_damage", "radius": 1.6, "power": 14.0,
			"status": "exposed", "status_power": 15.0, "status_duration": 2.0,
			"auto": {"type": "nearby_enemies", "count": 2, "radius": 1.6},
		},
	},
	"turtle": {
		"family": "vanguard", "base": false, "role": "front", "price": 0,
		"hp": 330.0, "dmg": 6.0, "interval": 1.70, "range": 0.35,
		"speed": 0.80, "armour": 35.0,
		"attack_kind": "melee", "attack_style": "bite", "windup": 0.30, "lunge": 6.0,
		"ability": "shell", "cd": 5.0, "cd_start": 0.0, "duration": 2.0, "power": 40.0,
		"special": {
			"id": "fortify", "type": "buff_allies", "radius": 2.6,
			"status": "guarded", "power": 25.0, "duration": 4.0,
			"auto": {"type": "self_low", "ratio": 0.55},
		},
	},
	"rhino": {
		"family": "vanguard", "base": false, "role": "front", "price": 0,
		"hp": 225.0, "dmg": 18.0, "interval": 2.00, "range": 0.35,
		"speed": 1.50, "armour": 20.0,
		"attack_kind": "melee", "attack_style": "smash", "windup": 0.50, "lunge": 18.0,
		"ability": "charge", "cd": 7.0, "cd_start": 0.0, "power": 2.2, "knock": 1.4,
		"special": {
			"id": "stampede", "type": "knockback", "radius": 2.4, "knock": 1.6,
			"status": "dazzled", "status_power": 1.6, "status_duration": 2.5,
			"auto": {"type": "nearby_enemies", "count": 2, "radius": 2.4},
		},
	},

	# --- Striker family --------------------------------------------------
	"striker": {
		"family": "striker", "base": true, "role": "front", "price": 2,
		"hp": 130.0, "dmg": 14.0, "interval": 0.80, "range": 0.35,
		"speed": 2.20, "armour": 5.0,
		"attack_kind": "melee", "attack_style": "slash", "windup": 0.12, "lunge": 16.0,
		"ability": "backline",
	},
	"fox": {
		"family": "striker", "base": false, "role": "front", "price": 0,
		"hp": 115.0, "dmg": 11.0, "interval": 0.70, "range": 0.35,
		"speed": 2.80, "armour": 0.0,
		"attack_kind": "melee", "attack_style": "slash", "windup": 0.10, "lunge": 18.0,
		"ability": "backline",
		"special": {
			"id": "pounce", "type": "leap", "target": "farthest", "power": 22.0,
			"auto": {"type": "backline_in_range", "range": 5.0},
		},
	},
	"panther": {
		"family": "striker", "base": false, "role": "front",
		"hp": 145.0, "dmg": 15.0, "interval": 0.85, "range": 0.35,
		"speed": 2.40, "armour": 5.0,
		"attack_kind": "melee", "attack_style": "slash", "windup": 0.15, "lunge": 18.0,
		"ability": "hunt", "radius": 4.0,
		"special": {
			"id": "frenzy", "type": "self_buff", "status": "inspired",
			"power": 0.55, "duration": 4.0,
			"auto": {"type": "nearby_enemies", "count": 1, "radius": 1.2},
		},
	},
	"rabbit": {
		"family": "striker", "base": false, "role": "front", "price": 0,
		"hp": 100.0, "dmg": 9.0, "interval": 0.60, "range": 0.35,
		"speed": 3.00, "armour": 0.0,
		"attack_kind": "melee", "attack_style": "bite", "windup": 0.10, "lunge": 10.0,
		"ability": "hop", "cd": 4.0, "cd_start": 0.0, "power": 0.8,
		"special": {
			"id": "evade", "type": "evade", "distance": 1.2, "dodge": 1.0,
			"auto": {"type": "self_low", "ratio": 0.55},
		},
	},

	# --- Ranger family ---------------------------------------------------
	"ranger": {
		"family": "ranger", "base": true, "role": "back", "price": 1,
		"hp": 90.0, "dmg": 8.0, "interval": 0.90, "range": 4.50,
		"speed": 1.80, "armour": 0.0,
		"attack_kind": "projectile", "attack_style": "bow", "windup": 0.35,
		"projectile": "arrow",
		"ability": "kite",
	},
	"hawk": {
		"family": "ranger", "base": false, "role": "back", "price": 0,
		"hp": 95.0, "dmg": 9.0, "interval": 0.80, "range": 4.00,
		"speed": 2.00, "armour": 0.0,
		"attack_kind": "projectile", "attack_style": "bow", "windup": 0.30,
		"projectile": "feather",
		"ability": "kite",
		"special": {
			"id": "volley", "type": "volley", "count": 3, "power_mult": 0.8,
			"auto": {"type": "nearby_enemies", "count": 2, "radius": 4.0},
		},
	},
	"eagle": {
		"family": "ranger", "base": false, "role": "back", "price": 0,
		"hp": 120.0, "dmg": 12.0, "interval": 1.10, "range": 3.00,
		"speed": 2.20, "armour": 0.0,
		"attack_kind": "projectile", "attack_style": "bow", "windup": 0.35,
		"projectile": "arrow",
		"ability": "dive", "cd": 6.0, "cd_start": 1.5, "power": 34.0,
		"special": {
			"id": "skyfall", "type": "leap", "target": "farthest", "power": 45.0,
			"auto": {"type": "backline_in_range", "range": 5.0},
		},
	},
	"phoenix": {
		"family": "ranger", "base": false, "role": "back", "price": 0,
		"hp": 130.0, "dmg": 14.0, "interval": 1.50, "range": 4.00,
		"speed": 1.60, "armour": 5.0,
		"attack_kind": "projectile", "attack_style": "cast", "windup": 0.40,
		"projectile": "fire",
		"ability": "splash", "splash_radius": 1.2,
		"special": {
			"id": "firestorm", "type": "burst_damage", "at_target": true,
			"radius": 1.8, "power": 26.0,
			"auto": {"type": "enemy_cluster", "count": 2, "radius": 1.8},
		},
	},

	# --- Mystic family ---------------------------------------------------
	"mystic": {
		"family": "mystic", "base": true, "role": "back", "price": 3,
		"hp": 105.0, "dmg": 11.0, "interval": 1.60, "range": 4.00,
		"speed": 1.30, "armour": 0.0,
		"attack_kind": "projectile", "attack_style": "cast", "windup": 0.45,
		"projectile": "frost",
		"ability": "chill", "duration": 2.5, "power": 0.35,
	},
	"raven": {
		"family": "mystic", "base": false, "role": "back", "price": 0,
		"hp": 95.0, "dmg": 8.0, "interval": 1.20, "range": 4.00,
		"speed": 1.80, "armour": 0.0,
		"attack_kind": "projectile", "attack_style": "cast", "windup": 0.35,
		"projectile": "shadow",
		"ability": "chill", "duration": 2.5, "power": 0.40,
		"special": {
			"id": "frost_nova", "type": "debuff_enemies", "radius": 2.4,
			"status": "chilled", "power": 0.5, "duration": 3.0,
			"auto": {"type": "nearby_enemies", "count": 2, "radius": 2.4},
		},
	},
	"shadow_raven": {
		"family": "mystic", "base": false, "role": "back", "price": 0,
		"hp": 115.0, "dmg": 13.0, "interval": 1.60, "range": 4.20,
		"speed": 1.50, "armour": 0.0,
		"attack_kind": "projectile", "attack_style": "cast", "windup": 0.45,
		"projectile": "shadow",
		"ability": "splash", "splash_radius": 1.0,
		"special": {
			"id": "shadow_nova", "type": "burst_damage", "at_target": true,
			"radius": 1.8, "power": 28.0,
			"auto": {"type": "enemy_cluster", "count": 2, "radius": 1.8},
		},
	},
	"owl": {
		"family": "mystic", "base": false, "role": "support", "price": 0,
		"hp": 110.0, "dmg": 7.0, "interval": 1.40, "range": 3.50,
		"speed": 1.40, "armour": 5.0,
		"attack_kind": "projectile", "attack_style": "cast", "windup": 0.35,
		"projectile": "moon",
		"ability": "dazzle", "cd": 5.0, "cd_start": 2.0, "radius": 2.4,
		"duration": 3.0, "power": 1.5,
		"special": {
			"id": "screech", "type": "debuff_enemies", "radius": 2.8,
			"status": "dazzled", "power": 1.8, "duration": 4.0,
			"auto": {"type": "nearby_enemies", "count": 2, "radius": 2.8},
		},
	},

	# --- Support family --------------------------------------------------
	"support": {
		"family": "support", "base": true, "role": "support", "price": 2,
		"hp": 125.0, "dmg": 5.0, "interval": 1.50, "range": 3.00,
		"speed": 1.40, "armour": 10.0,
		"attack_kind": "projectile", "attack_style": "cast", "windup": 0.35,
		"projectile": "holy",
		"ability": "heal", "cd": 3.5, "cd_start": 2.0, "radius": 3.5, "power": 28.0,
	},
	"doe": {
		"family": "support", "base": false, "role": "support", "price": 0,
		"hp": 150.0, "dmg": 6.0, "interval": 1.40, "range": 0.40,
		"speed": 1.90, "armour": 5.0,
		"attack_kind": "melee", "attack_style": "bite", "windup": 0.25, "lunge": 8.0,
		"ability": "heal", "cd": 3.5, "cd_start": 2.0, "radius": 3.0, "power": 20.0,
		"special": {
			"id": "bloom", "type": "burst_heal", "radius": 2.8, "power": 35.0,
			"auto": {"type": "ally_wounded", "ratio": 0.6, "count": 1},
		},
	},
	"unicorn": {
		"family": "support", "base": false, "role": "support", "price": 0,
		"hp": 175.0, "dmg": 9.0, "interval": 1.60, "range": 0.50,
		"speed": 1.60, "armour": 10.0,
		"attack_kind": "melee", "attack_style": "thrust", "windup": 0.30, "lunge": 8.0,
		"ability": "heal", "cd": 4.0, "cd_start": 2.0, "radius": 3.5,
		"power": 30.0, "cleanse": true,
		"special": {
			"id": "purify", "type": "burst_heal", "radius": 3.2, "power": 45.0,
			"cleanse": true,
			"auto": {"type": "ally_wounded", "ratio": 0.6, "count": 1},
		},
	},
	"songbird": {
		"family": "support", "base": false, "role": "support", "price": 0,
		"hp": 90.0, "dmg": 5.0, "interval": 1.20, "range": 3.50,
		"speed": 2.00, "armour": 0.0,
		"attack_kind": "projectile", "attack_style": "cast", "windup": 0.25,
		"projectile": "note",
		"ability": "inspire", "radius": 2.5, "power": 0.30,
		"special": {
			"id": "crescendo", "type": "buff_allies", "radius": 2.8,
			"status": "inspired", "power": 0.45, "duration": 4.0,
			"auto": {"type": "nearby_allies", "count": 2, "radius": 2.8},
		},
	},

	# --- Berserker family ------------------------------------------------
	"berserker": {
		"family": "berserker", "base": true, "role": "front", "price": 3,
		"hp": 180.0, "dmg": 16.0, "interval": 1.30, "range": 0.35,
		"speed": 1.60, "armour": 10.0,
		"attack_kind": "melee", "attack_style": "smash", "windup": 0.45, "lunge": 18.0,
		"ability": "berserk", "power": 0.60,
	},
	"boar": {
		"family": "berserker", "base": false, "role": "front", "price": 0,
		"hp": 190.0, "dmg": 16.0, "interval": 1.50, "range": 0.35,
		"speed": 1.70, "armour": 10.0,
		"attack_kind": "melee", "attack_style": "smash", "windup": 0.40, "lunge": 16.0,
		"ability": "charge", "cd": 6.0, "cd_start": 0.0, "power": 2.0, "knock": 1.0,
		"special": {
			"id": "gore", "type": "leap", "target": "nearest", "power": 30.0,
			"knock": 1.2,
			"auto": {"type": "nearby_enemies", "count": 1, "radius": 2.5},
		},
	},
	"wolverine": {
		"family": "berserker", "base": false, "role": "front", "price": 0,
		"hp": 170.0, "dmg": 13.0, "interval": 1.00, "range": 0.35,
		"speed": 1.90, "armour": 0.0,
		"attack_kind": "melee", "attack_style": "slash", "windup": 0.20, "lunge": 8.0,
		"ability": "berserk", "power": 0.70,
		"special": {
			"id": "frenzy_burst", "type": "self_buff", "status": "inspired",
			"power": 0.6, "duration": 2.5,
			"auto": {"type": "self_low", "ratio": 0.6},
		},
	},
	"badger": {
		"family": "berserker", "base": false, "role": "front", "price": 0,
		"hp": 185.0, "dmg": 14.0, "interval": 1.40, "range": 0.35,
		"speed": 1.50, "armour": 0.0,
		"attack_kind": "melee", "attack_style": "slash", "windup": 0.25, "lunge": 13.0,
		"ability": "thorns", "power": 7.0,
		"special": {
			"id": "quills", "type": "self_buff", "status": "retaliate",
			"power": 15.0, "duration": 5.0,
			"auto": {"type": "nearby_enemies", "count": 2, "radius": 1.6},
		},
	},
}

# Thematic starting packs. Three are drawn at random for the opening choice.
const PACKS := [
	["vanguard", "berserker", "ranger"],
	["vanguard", "support", "ranger"],
	["mystic", "support", "vanguard"],
	["striker", "ranger", "support"],
	["ranger", "mystic", "vanguard"],
	["berserker", "striker", "support"],
]


static func get_form(id: String) -> Dictionary:
	return FORMS[id]


static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for family in FAMILIES:
		for id in FAMILIES[family]:
			ids.append(id)
	return ids


static func shop_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in BASE_FORMS:
		ids.append(id)
	return ids


static func family_of(id: String) -> String:
	return FORMS[id].family


static func family_forms(family: String) -> Array:
	return FAMILIES[family]


static func stage_of(id: String) -> int:
	return FAMILIES[family_of(id)].find(id)


static func family_color(id: String) -> Color:
	return FAMILY_COLORS.get(family_of(id), Color.WHITE)


static func family_ladder(id: String) -> Array:
	return FAMILIES[family_of(id)]


static func family_size(id: String) -> int:
	return FAMILIES[family_of(id)].size()


static func is_final_stage(id: String) -> bool:
	return stage_of(id) == family_size(id) - 1


## Next form in the family ladder. At the final stage this returns the same id
## (a refresh rather than an upgrade).
static func next_form(id: String) -> String:
	var ladder: Array = FAMILIES[family_of(id)]
	var index := ladder.find(id)
	return ladder[mini(index + 1, ladder.size() - 1)]


static func combo_for(id: String) -> Dictionary:
	var combo: Dictionary = COMBO_DEFAULT.duplicate()
	combo.merge(FORMS[id].get("combo", {}), true)
	return combo
