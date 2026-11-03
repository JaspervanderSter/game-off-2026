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

# Optional per-link weights ("from>to": weight). Missing links weigh 1.0, giving
# the draft's equal 1/3 chances.
const LINK_WEIGHTS := {}

# role: front / mid / back / support (used by AI purchases and auto-placement).
# attack: melee, or the projectile drawn for ranged attacks.
const FORMS := {
	# --- Heroic fantasy (purchasable) ---
	"peasant": {"family": "fantasy", "hp": 85, "dmg": 6, "interval": 1.0, "range": 0.3, "speed": 1.6, "armour": 0, "price": 1, "role": "front", "attack": "melee", "ability": ""},
	"guardian": {"family": "fantasy", "hp": 220, "dmg": 7, "interval": 1.3, "range": 0.3, "speed": 1.1, "armour": 40, "price": 2, "role": "front", "attack": "melee", "ability": ""},
	"berserker": {"family": "fantasy", "hp": 155, "dmg": 10, "interval": 1.1, "range": 0.3, "speed": 1.7, "armour": 10, "price": 2, "role": "front", "attack": "melee", "ability": "berserk", "power": 0.55},
	"duelist": {"family": "fantasy", "hp": 135, "dmg": 12, "interval": 0.9, "range": 0.3, "speed": 1.8, "armour": 10, "price": 2, "role": "front", "attack": "melee", "ability": "parry", "cd": 4.0, "cd_start": 0.0},
	"assassin": {"family": "fantasy", "hp": 105, "dmg": 20, "interval": 1.1, "range": 0.3, "speed": 2.6, "armour": 0, "price": 3, "role": "front", "attack": "melee", "ability": "backline"},
	"spearman": {"family": "fantasy", "hp": 110, "dmg": 9, "interval": 1.1, "range": 1.3, "speed": 1.5, "armour": 10, "price": 1, "role": "mid", "attack": "melee", "ability": ""},
	"archer": {"family": "fantasy", "hp": 85, "dmg": 7, "interval": 0.8, "range": 4.5, "speed": 1.8, "armour": 0, "price": 1, "role": "back", "attack": "arrow", "ability": "kite"},
	"crossbowman": {"family": "fantasy", "hp": 105, "dmg": 26, "interval": 2.2, "range": 5.0, "speed": 1.2, "armour": 0, "price": 3, "role": "back", "attack": "bolt", "ability": "pierce"},
	"pyromancer": {"family": "fantasy", "hp": 90, "dmg": 12, "interval": 1.7, "range": 4.0, "speed": 1.3, "armour": 0, "price": 3, "role": "back", "attack": "fire", "ability": "splash", "radius": 1.0},
	"frost_mage": {"family": "fantasy", "hp": 100, "dmg": 6, "interval": 1.3, "range": 4.0, "speed": 1.3, "armour": 0, "price": 2, "role": "back", "attack": "frost", "ability": "chill", "duration": 2.5, "power": 0.5},
	"cleric": {"family": "fantasy", "hp": 110, "dmg": 5, "interval": 1.4, "range": 3.0, "speed": 1.4, "armour": 10, "price": 2, "role": "support", "attack": "holy", "ability": "heal", "cd": 3.5, "cd_start": 2.0, "radius": 3.5, "power": 22.0},
	"bard": {"family": "fantasy", "hp": 105, "dmg": 5, "interval": 1.2, "range": 3.0, "speed": 1.4, "armour": 0, "price": 2, "role": "support", "attack": "note", "ability": "inspire", "radius": 2.2, "power": 0.35},
	# --- Animals (transformation outcomes only; price = rough value for AI) ---
	# Sidegrades with distinct combat niches, not a weaker roster. Rabbit trades
	# durability for high DPS; its short hops limit time lost returning to melee.
	# Deer/peacock/skunk trade damage for sustained healing or area disruption.
	"turtle": {"family": "animal", "hp": 245, "dmg": 6, "interval": 1.4, "range": 0.3, "speed": 0.8, "armour": 30, "price": 2, "role": "front", "attack": "melee", "ability": "shell", "cd": 6.0, "cd_start": 0.0, "duration": 2.0, "power": 50.0},
	"rhino": {"family": "animal", "hp": 215, "dmg": 14, "interval": 1.8, "range": 0.3, "speed": 1.4, "armour": 25, "price": 3, "role": "front", "attack": "melee", "ability": "charge", "cd": 8.0, "cd_start": 0.0, "power": 2.0, "knock": 1.2},
	"gorilla": {"family": "animal", "hp": 200, "dmg": 15, "interval": 1.7, "range": 0.4, "speed": 1.3, "armour": 10, "price": 3, "role": "front", "attack": "melee", "ability": "cleave", "radius": 0.9},
	"wolf": {"family": "animal", "hp": 150, "dmg": 11, "interval": 1.0, "range": 0.3, "speed": 2.2, "armour": 5, "price": 2, "role": "front", "attack": "melee", "ability": "pack", "radius": 2.0, "power": 0.4},
	"leopard": {"family": "animal", "hp": 120, "dmg": 15, "interval": 0.8, "range": 0.3, "speed": 2.8, "armour": 0, "price": 3, "role": "front", "attack": "melee", "ability": "hunt", "radius": 4.0},
	"rabbit": {"family": "animal", "hp": 120, "dmg": 10, "interval": 0.65, "range": 0.3, "speed": 3.0, "armour": 0, "price": 1, "role": "front", "attack": "melee", "ability": "hop", "cd": 4.0, "cd_start": 0.0, "power": 0.8},
	"snake": {"family": "animal", "hp": 125, "dmg": 6, "interval": 1.0, "range": 0.3, "speed": 1.8, "armour": 0, "price": 2, "role": "front", "attack": "melee", "ability": "poison", "duration": 4.0, "power": 7.0},
	"skunk": {"family": "animal", "hp": 145, "dmg": 7, "interval": 1.2, "range": 0.3, "speed": 1.6, "armour": 5, "price": 2, "role": "front", "attack": "melee", "ability": "spray", "cd": 5.0, "cd_start": 2.0, "radius": 2.0, "duration": 4.0, "power": 30.0},
	"eagle": {"family": "animal", "hp": 135, "dmg": 13, "interval": 1.0, "range": 0.3, "speed": 2.0, "armour": 0, "price": 2, "role": "front", "attack": "melee", "ability": "dive", "cd": 7.0, "cd_start": 1.5, "power": 30.0},
	"hedgehog": {"family": "animal", "hp": 165, "dmg": 6, "interval": 1.1, "range": 0.3, "speed": 1.3, "armour": 15, "price": 2, "role": "front", "attack": "melee", "ability": "thorns", "power": 5.0},
	"deer": {"family": "animal", "hp": 155, "dmg": 7, "interval": 1.2, "range": 0.3, "speed": 1.9, "armour": 0, "price": 2, "role": "support", "attack": "melee", "ability": "graze", "radius": 2.8, "power": 5.0},
	"peacock": {"family": "animal", "hp": 140, "dmg": 7, "interval": 1.2, "range": 0.3, "speed": 1.7, "armour": 0, "price": 2, "role": "support", "attack": "melee", "ability": "display", "cd": 6.0, "cd_start": 2.0, "radius": 2.6, "duration": 4.0, "power": 1.8},
}

# Thematic starting packs (three are drawn at random for the choice).
const PACKS := [
	["guardian", "berserker", "peasant"], # vanguard
	["archer", "spearman", "crossbowman"], # volley
	["frost_mage", "cleric", "peasant"], # arcane
	["duelist", "archer", "bard"], # skirmish
	["peasant", "spearman", "berserker"], # militia
	["guardian", "cleric", "peasant"], # sanctuary
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
	var next: Array = STAGES[(stage_of(id) + 1) % STAGES.size()]
	var total := 0.0
	for to in next:
		total += float(LINK_WEIGHTS.get(id + ">" + to, 1.0))
	var result := []
	for to in next:
		result.append({"id": to, "chance": float(LINK_WEIGHTS.get(id + ">" + to, 1.0)) / total})
	return result


static func roll_outcome(id: String, rng: RandomNumberGenerator) -> String:
	var options := outcomes(id)
	var roll := rng.randf()
	for o in options:
		roll -= o.chance
		if roll <= 0.0:
			return o.id
	return options[-1].id
