class_name CreatureDB
extends RefCounted
## The 24 forms of Prototype 02 and their transformation network.
##
## Statistics and ability parameters are assistant-authored first values
## (the creature sheets leave them TBD). Units:
##   hp: HP, dmg: HP per basic hit, interval: s between attacks,
##   range: cells edge to edge, speed: cells/s, armour: % damage reduced,
##   price: gold. Ability magnitudes do not scale with temporary levels.

# Eight-stage network from docs/design/prototype_02/Roster and Transformation Map.md.
# Every form leads to the three forms of the next stage; stage 8 leads to stage 1.
const STAGES := [
	["peasant", "guardian", "cleric"],
	["rabbit", "turtle", "deer"],
	["berserker", "duelist", "bard"],
	["gorilla", "hedgehog", "wolf"],
	["assassin", "archer", "frost_mage"],
	["eagle", "snake", "peacock"],
	["spearman", "crossbowman", "pyromancer"],
	["rhino", "leopard", "skunk"],
]

# Fixed, visible priorities favour each form's tactical identity.
const OUTCOME_CHANCES := [0.55, 0.30, 0.15]
const OUTCOME_ORDER := {
	"peasant": ["rabbit", "turtle", "deer"],
	"guardian": ["turtle", "deer", "rabbit"],
	"cleric": ["deer", "turtle", "rabbit"],
	"rabbit": ["duelist", "berserker", "bard"],
	"turtle": ["berserker", "bard", "duelist"],
	"deer": ["bard", "duelist", "berserker"],
	"berserker": ["gorilla", "wolf", "hedgehog"],
	"duelist": ["wolf", "gorilla", "hedgehog"],
	"bard": ["hedgehog", "wolf", "gorilla"],
	"gorilla": ["assassin", "frost_mage", "archer"],
	"hedgehog": ["frost_mage", "archer", "assassin"],
	"wolf": ["archer", "assassin", "frost_mage"],
	"assassin": ["eagle", "snake", "peacock"],
	"archer": ["snake", "eagle", "peacock"],
	"frost_mage": ["peacock", "snake", "eagle"],
	"eagle": ["spearman", "crossbowman", "pyromancer"],
	"snake": ["crossbowman", "pyromancer", "spearman"],
	"peacock": ["pyromancer", "spearman", "crossbowman"],
	"spearman": ["rhino", "leopard", "skunk"],
	"crossbowman": ["leopard", "rhino", "skunk"],
	"pyromancer": ["skunk", "leopard", "rhino"],
	"rhino": ["guardian", "peasant", "cleric"],
	"leopard": ["peasant", "guardian", "cleric"],
	"skunk": ["cleric", "guardian", "peasant"],
}

# role: front / mid / back / support (used by AI purchases and auto-placement).
# attack: melee, or the projectile drawn for ranged attacks.
const FORMS := {
	# --- Heroic fantasy (purchasable) ---
	# harvest: gold given at the start of every round, doubled per star (Rules.harvest_gold).
	"peasant": {"family": "fantasy", "hp": 85, "dmg": 6, "interval": 1.0, "range": 0.3, "speed": 1.6, "armour": 0, "price": 1, "role": "front", "attack": "melee", "ability": "", "harvest": 1},
	"guardian": {"family": "fantasy", "hp": 220, "dmg": 7, "interval": 1.3, "range": 0.3, "speed": 1.1, "armour": 40, "price": 2, "role": "front", "attack": "melee", "ability": ""},
	"berserker": {"family": "fantasy", "hp": 155, "dmg": 10, "interval": 1.1, "range": 0.3, "speed": 1.7, "armour": 10, "price": 2, "role": "front", "attack": "melee", "ability": "berserk", "power": 0.55},
	"duelist": {"family": "fantasy", "hp": 135, "dmg": 12, "interval": 0.9, "range": 0.3, "speed": 1.8, "armour": 10, "price": 2, "role": "front", "attack": "melee", "ability": "parry", "cd": 4.0, "cd_start": 0.0},
	"assassin": {"family": "fantasy", "hp": 105, "dmg": 20, "interval": 1.1, "range": 0.3, "speed": 2.6, "armour": 0, "price": 2, "role": "front", "attack": "melee", "ability": "backline"},
	"spearman": {"family": "fantasy", "hp": 110, "dmg": 9, "interval": 1.1, "range": 1.3, "speed": 1.5, "armour": 10, "price": 1, "role": "mid", "attack": "melee", "ability": ""},
	"archer": {"family": "fantasy", "hp": 85, "dmg": 7, "interval": 0.8, "range": 4.5, "speed": 1.8, "armour": 0, "price": 1, "role": "back", "attack": "arrow", "ability": "kite"},
	# chain_targets: bolt targets per star (0 to 3). From 1 star the bolt homes in and
	# chains to the nearest enemy not yet hit within chain_radius cells, each hop
	# dealing chain_falloff less than the previous one (100%, 70%, 49%...).
	"crossbowman": {"family": "fantasy", "hp": 105, "dmg": 31.2, "interval": 2.2, "range": 5.0, "speed": 1.2, "armour": 0, "price": 3, "role": "back", "attack": "bolt", "ability": "pierce",
		"chain_targets": [1, 3, 5, 5], "chain_falloff": 0.3, "chain_radius": 5.0},
	"pyromancer": {"family": "fantasy", "hp": 90, "dmg": 12, "interval": 1.7, "range": 4.0, "speed": 1.3, "armour": 0, "price": 3, "role": "back", "attack": "fire", "ability": "fireball",
		"splash_radius": 1.0, "burn_duration": 4.0, "burn_dps": 5.0, "cd": 15.0, "cd_start": 6.0, "power": 120.0, "fireball_speed": 3.5,
		"channel_duration": 1.0},
	"frost_mage": {"family": "fantasy", "hp": 115, "dmg": 7, "interval": 1.3, "range": 4.0, "speed": 1.3, "armour": 0, "price": 2, "role": "back", "attack": "frost", "ability": "blizzard",
		"cd": 9.0, "cd_start": 2.0, "duration": 3.0, "chill_slow": 0.5, "chill_duration": 1.0, "storm_dps": 7.2,
		"channel_duration": 1.0},
	"cleric": {"family": "fantasy", "hp": 110, "dmg": 5, "interval": 1.4, "range": 3.0, "speed": 1.4, "armour": 10, "price": 2, "role": "support", "attack": "holy", "ability": "heal", "cd": 3.5, "cd_start": 2.0, "radius": 3.5, "power": 22.0},
	# Song: every cd seconds, one beat inspires every ally on the battlefield
	# (bard included) for duration seconds: +power basic attack speed.
	"bard": {"family": "fantasy", "hp": 105, "dmg": 5, "interval": 1.2, "range": 3.0, "speed": 1.4, "armour": 0, "price": 2, "role": "support", "attack": "note", "ability": "song", "cd": 1.0, "cd_start": 0.5, "duration": 3.0, "power": 0.35},
	# --- Animals (transformation outcomes only; price = rough value for AI) ---
	# Sidegrades with distinct combat niches, not a weaker roster. Rabbit trades
	# durability for high DPS and a leap directly onto the enemy backline.
	# Deer/peacock/skunk trade damage for sustained healing or area disruption.
	# ally_shift: positive post-transformation effect, triggered only when the
	# creature's own wizard shapeshifts it into this form (see Unit.transform_to).
	#   "leap": the hop ability is ready at once (immediate backline leap).
	#   "fear": enemies within fear_radius cells stop attacking and flee from the
	#           creature in a zigzag for fear_duration seconds.
	"turtle": {"family": "animal", "hp": 245, "dmg": 6, "interval": 1.4, "range": 0.3, "speed": 0.8, "armour": 30, "price": 2, "role": "front", "attack": "melee", "ability": "shell", "cd": 6.0, "cd_start": 0.0, "duration": 2.0, "power": 50.0},
	"rhino": {"family": "animal", "hp": 215, "dmg": 14, "interval": 1.8, "range": 0.3, "speed": 1.4, "armour": 25, "price": 3, "role": "front", "attack": "melee", "ability": "charge", "cd": 8.0, "cd_start": 0.0, "power": 2.0, "knock": 1.2},
	"gorilla": {"family": "animal", "hp": 200, "dmg": 15, "interval": 1.7, "range": 0.4, "speed": 1.3, "armour": 10, "price": 3, "role": "front", "attack": "melee", "ability": "cleave", "radius": 0.9},
	"wolf": {"family": "animal", "hp": 150, "dmg": 11, "interval": 1.0, "range": 0.3, "speed": 2.2, "armour": 5, "price": 2, "role": "front", "attack": "melee", "ability": "pack", "radius": 2.0, "power": 0.4},
	"leopard": {"family": "animal", "hp": 120, "dmg": 15, "interval": 0.8, "range": 0.3, "speed": 2.8, "armour": 0, "price": 3, "role": "front", "attack": "melee", "ability": "hunt", "radius": 4.0},
	"rabbit": {"family": "animal", "hp": 135, "dmg": 10, "interval": 0.65, "range": 0.3, "speed": 3.0, "armour": 0, "price": 1, "role": "front", "attack": "melee", "ability": "hop", "cd": 8.0, "cd_start": 0.0, "ally_shift": "leap"},
	"snake": {"family": "animal", "hp": 125, "dmg": 6, "interval": 1.0, "range": 0.3, "speed": 1.8, "armour": 0, "price": 2, "role": "front", "attack": "melee", "ability": "poison", "duration": 4.0, "power": 7.0},
	"skunk": {"family": "animal", "hp": 145, "dmg": 7, "interval": 1.2, "range": 0.3, "speed": 1.6, "armour": 5, "price": 2, "role": "front", "attack": "melee", "ability": "spray", "cd": 5.0, "cd_start": 2.0, "radius": 2.0, "duration": 4.0, "power": 30.0,
		"ally_shift": "fear", "fear_radius": 2.5, "fear_duration": 2.0},
	"eagle": {"family": "animal", "hp": 135, "dmg": 13, "interval": 1.0, "range": 0.3, "speed": 2.0, "armour": 0, "price": 2, "role": "front", "attack": "melee", "ability": "dive", "cd": 7.0, "cd_start": 1.5, "power": 30.0},
	"hedgehog": {"family": "animal", "hp": 165, "dmg": 6, "interval": 1.1, "range": 0.3, "speed": 1.3, "armour": 15, "price": 2, "role": "front", "attack": "melee", "ability": "thorns", "power": 5.0},
	"deer": {"family": "animal", "hp": 155, "dmg": 7, "interval": 1.2, "range": 0.3, "speed": 1.9, "armour": 0, "price": 2, "role": "support", "attack": "melee", "ability": "graze", "radius": 2.8, "power": 5.0},
	"peacock": {"family": "animal", "hp": 140, "dmg": 7, "interval": 1.2, "range": 0.3, "speed": 1.7, "armour": 0, "price": 2, "role": "support", "attack": "melee", "ability": "display", "cd": 6.0, "cd_start": 2.0, "radius": 2.6, "duration": 4.0, "power": 1.8},
}

# All three packs are offered. Bonus gold is granted once, before the first shop.
const PACKS := [
	{"name": "Control", "plan": "Protect your backline",
		"forms": ["guardian", "frost_mage", "peasant"], "bonus_gold": 1},
	{"name": "Tempo", "plan": "Build around the song",
		"forms": ["duelist", "archer", "bard"], "bonus_gold": 0},
	{"name": "Breakthrough", "plan": "Hunt enemy backliners",
		"forms": ["berserker", "assassin", "spearman"], "bonus_gold": 1},
]


static func get_form(id: String) -> Dictionary:
	return FORMS[id]


static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for stage in STAGES:
		for id in stage:
			ids.append(id)
	return ids


static func shop_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in all_ids():
		if FORMS[id].family == "fantasy":
			ids.append(id)
	return ids


static func stage_of(id: String) -> int:
	for i in STAGES.size():
		if id in STAGES[i]:
			return i
	return -1


## Outgoing links as [{"id": String, "chance": float}], chances summing to 1.
static func outcomes(id: String) -> Array:
	var next: Array = OUTCOME_ORDER[id]
	var result := []
	for i in next.size():
		result.append({"id": next[i], "chance": OUTCOME_CHANCES[i]})
	return result


static func roll_outcome(id: String, rng: RandomNumberGenerator) -> String:
	var options := outcomes(id)
	var roll := rng.randf()
	for o in options:
		roll -= o.chance
		if roll <= 0.0:
			return o.id
	return options[-1].id
