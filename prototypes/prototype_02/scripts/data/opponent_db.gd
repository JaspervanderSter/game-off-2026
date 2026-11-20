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
## CreatureDB.PACKS name of its opening ("" = dealt from its deck).
const OPPONENTS := [
	{"id": "hunter", "name": "Hunter", "magic": false, "rule": "", "pack": "Hunt"},
	{"id": "lumberjack", "name": "Lumberjack", "magic": false, "rule": Ruleset.SHOP, "pack": "Raid"},
	{"id": "druid", "name": "Druid", "magic": true, "rule": Ruleset.WAND, "pack": "Temple"},
	{"id": "swamp_witch", "name": "Swamp witch", "magic": true, "rule": Ruleset.HEX, "pack": "Shadows"},
	{"id": "archdruid", "name": "Archdruid", "magic": true, "rule": Ruleset.ANIMAL_BONUS, "pack": "Hunt"},
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
	return Ruleset.new(rules)


## CreatureDB.PACKS index of the opponent's opening, or -1 to deal from its deck.
static func pack_index(index: int) -> int:
	var name: String = OPPONENTS[index].pack
	for i in CreatureDB.PACKS.size():
		if CreatureDB.PACKS[i].name == name:
			return i
	return -1
