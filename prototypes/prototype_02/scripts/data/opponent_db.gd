class_name OpponentDB
extends RefCounted
## The fifteen journey opponents, in play order: five per zone (forest, town,
## school). Each introduces one existing rule (Ruleset) and adds none; the
## fifth of a zone opens the next one.
## Source: docs/design/prototype_02/Journey and Opponents.md.

const ZONE_SIZE := 5
## AI strength per zone: forest, town, school.
const ZONE_LEVELS := [Difficulty.APPRENTICE, Difficulty.ADEPT, Difficulty.ARCHMAGE]
## id: drawing in Icons.opponent; magic: casts the shapeshift once the wand is
## introduced; rule: the Ruleset rule it introduces ("" for none); pack: the
## CreatureDB.PACKS name of its opening ("" = forest army or archmage deck).
const OPPONENTS := [
	{"id": "hunter", "name": "Hunter", "magic": false, "rule": "", "pack": ""},
	{"id": "druid", "name": "Druid", "magic": true, "rule": Ruleset.WAND, "pack": ""},
	{"id": "lumberjack", "name": "Lumberjack", "magic": false, "rule": Ruleset.SHOP, "pack": ""},
	{"id": "swamp_witch", "name": "Swamp witch", "magic": true, "rule": Ruleset.HEX, "pack": ""},
	{"id": "archdruid", "name": "Archdruid", "magic": true, "rule": Ruleset.ANIMAL_BONUS, "pack": ""},
	{"id": "merchant", "name": "Merchant", "magic": false, "rule": Ruleset.TRADE, "pack": "Troupe"},
	{"id": "innkeeper", "name": "Innkeeper", "magic": false, "rule": Ruleset.HARVEST, "pack": "Tavern"},
	{"id": "thief", "name": "Thief", "magic": false, "rule": Ruleset.MERGE, "pack": "Shadows"},
	{"id": "court_mage", "name": "Court mage", "magic": true, "rule": Ruleset.CASTERS, "pack": "Arcane"},
	{"id": "king", "name": "King", "magic": false, "rule": Ruleset.FRENZY, "pack": "Crusade"},
	{"id": "apprentice", "name": "Apprentice", "magic": true, "rule": "upgrade_recharge", "pack": "Village"},
	{"id": "caretaker", "name": "Caretaker", "magic": false, "rule": "upgrade_hex", "pack": "Phalanx"},
	{"id": "adept", "name": "Adept", "magic": true, "rule": "upgrade_charges", "pack": "Fortress"},
	{"id": "transmutation_teacher", "name": "Transmutation teacher", "magic": true, "rule": "upgrade_heal", "pack": "Inferno"},
	{"id": "archmage", "name": "Archmage", "magic": true, "rule": "", "pack": ""},
]

## Forest encounters are demonstrations, not competitive duels. Their small,
## fixed armies never grow; ordinary creature stats and abilities still apply.
const FOREST_ARMIES := [
	["wolf"],
	["deer"],
	["spearman"],
	["wolf"],
	["wolf", "rabbit"],
]


static func is_learning_encounter(index: int) -> bool:
	return index >= 0 and index < ZONE_SIZE


static func learning_army(index: int) -> Array:
	return FOREST_ARMIES[index].duplicate() if is_learning_encounter(index) else []


const LEARNING_PACKS := [
	{"name": "Forest guard", "emblem": "bow", "forms": ["guardian", "archer", "archer"], "bonus_gold": 0},
	{"name": "Forest patrol", "emblem": "spear", "forms": ["guardian", "spearman", "spearman"], "bonus_gold": 0},
	{"name": "Forest scouts", "emblem": "spear_wall", "forms": ["guardian", "spearman", "archer"], "bonus_gold": 0},
]

## Small thematic choices, separate from the hidden full-roster deck.
static func learning_packs() -> Array[int]:
	return [0, 1, 2]


## Town compositions: only creatures of the town roster (Ruleset.TOWN_HUMANS).
## Familiar names keep their emblem; a form outside the town is replaced by a
## town human, and bonus gold covers the price difference (implementation default).
const TOWN_PACKS := [
	{"name": "Troupe", "emblem": "song", "forms": ["guardian", "archer", "bard"], "bonus_gold": 3},
	{"name": "Tavern", "emblem": "mug", "forms": ["bard", "peasant", "spearman"], "bonus_gold": 0},
	{"name": "Shadows", "emblem": "moon_dagger", "forms": ["assassin", "assassin", "archer"], "bonus_gold": 2},
	{"name": "Arcane", "emblem": "fire_ice", "forms": ["pyromancer", "frost_mage"], "bonus_gold": 3},
	{"name": "Crusade", "emblem": "banner", "forms": ["cleric", "guardian", "spearman"], "bonus_gold": 3},
	{"name": "Temple", "emblem": "halo", "forms": ["cleric", "cleric", "guardian"], "bonus_gold": 3},
	{"name": "Phalanx", "emblem": "spear_wall", "forms": ["spearman", "spearman", "guardian"], "bonus_gold": 1},
	{"name": "Village", "emblem": "pitchfork", "forms": ["peasant", "peasant"], "bonus_gold": 0},
	{"name": "Fortress", "emblem": "frost_shield", "forms": ["guardian", "frost_mage"], "bonus_gold": 3},
	{"name": "Hunt", "emblem": "bow", "forms": ["archer", "archer", "spearman"], "bonus_gold": 2},
]


## Compositions dealt against opponent `index`: the forest's learning teams, the
## town's compositions, or the complete CreatureDB.PACKS (school, outside the journey).
static func packs_for(index: int) -> Array:
	if index < 0:
		return CreatureDB.PACKS
	match zone(index):
		0:
			return LEARNING_PACKS
		1:
			return TOWN_PACKS
	return CreatureDB.PACKS


static func count() -> int:
	return OPPONENTS.size()


static func get_opponent(index: int) -> Dictionary:
	return OPPONENTS[index]


static func zone(index: int) -> int:
	return index / ZONE_SIZE


static func ai_level(index: int) -> int:
	return ZONE_LEVELS[zone(index)]


static func is_boss(index: int) -> bool:
	return index % ZONE_SIZE == ZONE_SIZE - 1


## Rules of a duel against opponent `index`: those introduced by it and by
## every opponent before it.
static func ruleset(index: int) -> Ruleset:
	var rules: Array[String] = []
	for i in index + 1:
		var rule: String = OPPONENTS[i].rule
		if rule != "":
			rules.append(rule)
	var result := Ruleset.new(rules)
	# Forest and town keep their own rosters; the school opens all creatures.
	result.roster = zone(index) if zone(index) <= Ruleset.TOWN else Ruleset.COMPLETE_ROSTER
	return result


## Index in packs_for(index) of the opponent's opening, or -1 to deal from its deck.
static func pack_index(index: int) -> int:
	var name: String = OPPONENTS[index].pack
	var packs := packs_for(index)
	for i in packs.size():
		if name != "" and packs[i].name == name:
			return i
	return -1
