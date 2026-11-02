class_name CharacterStats
extends RefCounted
## Pure attribute data. `base` is the character's birth-right values, `current`
## is what the simulation actually uses. Swaps exchange entries in `current`;
## `base` stays untouched so the UI can always show where things came from.

var base: Dictionary = {}
var current: Dictionary = {}


func setup(def: Dictionary, ability: Ability, basic: BasicAttack) -> void:
	base = {
		"speed": float(def["speed"]),
		"strength": float(def["strength"]),
		"weight": float(def["weight"]),
		"health": float(def["health"]),
		"attack_cooldown": float(def["attack_cooldown"]),
		"special_cooldown": float(def["special_cooldown"]),
		"basic": basic,
		"special": ability,
	}
	current = base.duplicate()


func get_value(attr: String) -> Variant:
	return current.get(attr)


func base_value(attr: String) -> Variant:
	return base.get(attr)
