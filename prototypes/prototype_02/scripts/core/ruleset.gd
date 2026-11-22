class_name Ruleset
extends RefCounted
## The existing rules a duel uses. Journey opponents introduce them one at a
## time (docs/design/prototype_02/Journey and Opponents.md); a rule not yet
## introduced is absent for both wizards. Duels outside the journey (tests,
## balance tools) use the complete set, which is the default.

const SHOP := "shop" # creature stall, income and gold for lost hearts
const WAND := "wand" # shapeshifting one's own creatures, charge crystals
const HEX := "hex" # shapeshifting enemy creatures
const ANIMAL_BONUS := "animal_bonus" # ally_shift effects (rabbit leap, skunk fear)
const TRADE := "trade" # selling, rerolling and locking offers
const HARVEST := "harvest" # peasants and their harvest
const MERGE := "merge" # three identical creatures make a star
const CASTERS := "casters" # pyromancer and frost mage in the shop and openings
const FRENZY := "frenzy" # combat speeds up after Rules.FRENZY_START
## Wand upgrade rules are "upgrade_" + an id of Rules.WAND_UPGRADES.
const ALL: Array[String] = [SHOP, WAND, HEX, ANIMAL_BONUS, TRADE, HARVEST, MERGE, CASTERS, FRENZY,
	"upgrade_recharge", "upgrade_hex", "upgrade_charges", "upgrade_heal"]
## Forms that carry a rule: never offered nor dealt in an opening before it.
const FORM_RULES := {"peasant": HARVEST, "pyromancer": CASTERS, "frost_mage": CASTERS}

var enabled := {}
## Island roster: FOREST or TOWN restricts every creature (shop, openings and
## transformations) to that island's forms and closed graph; COMPLETE_ROSTER
## keeps all 24 forms and the eight-stage graph (school, duels outside the journey).
var roster := COMPLETE_ROSTER
const COMPLETE_ROSTER := -1
const FOREST := 0
const TOWN := 1
const FOREST_HUMANS := ["archer", "guardian", "spearman"]
const FOREST_ANIMALS := ["rabbit", "wolf", "deer"]
## A closed forest practice graph: three cross-family outcomes per form.
## This deliberately replaces the eight-stage full-roster graph on this island.
const FOREST_OUTCOMES := {
	"archer": ["rabbit", "wolf", "deer"],
	"guardian": ["deer", "wolf", "rabbit"],
	"spearman": ["wolf", "rabbit", "deer"],
	"rabbit": ["archer", "spearman", "guardian"],
	"wolf": ["spearman", "guardian", "archer"],
	"deer": ["guardian", "archer", "spearman"],
}
## The town adds three humans (cleric, assassin, bard) and three animals of the
## moat and gardens (turtle, porcupine, peacock) to the forest roster. Peasants and
## the two casters belong to it too, behind their own rules (FORM_RULES).
const TOWN_HUMANS := ["archer", "guardian", "spearman", "cleric", "assassin", "bard",
	"peasant", "pyromancer", "frost_mage"]
const TOWN_ANIMALS := ["rabbit", "wolf", "deer", "turtle", "porcupine", "peacock"]
## Closed town graph. Forest forms keep their most likely forest outcome; every
## town human is reached from two animals, every animal from four or five humans.
const TOWN_OUTCOMES := {
	"archer": ["rabbit", "wolf", "peacock"],
	"guardian": ["deer", "turtle", "wolf"],
	"spearman": ["wolf", "porcupine", "rabbit"],
	"peasant": ["rabbit", "turtle", "deer"],
	"cleric": ["deer", "peacock", "turtle"],
	"assassin": ["wolf", "rabbit", "porcupine"],
	"bard": ["peacock", "deer", "porcupine"],
	"pyromancer": ["porcupine", "peacock", "wolf"],
	"frost_mage": ["turtle", "porcupine", "peacock"],
	"rabbit": ["archer", "assassin", "peasant"],
	"wolf": ["spearman", "assassin", "guardian"],
	"deer": ["guardian", "cleric", "bard"],
	"turtle": ["peasant", "spearman", "cleric"],
	"porcupine": ["bard", "frost_mage", "pyromancer"],
	"peacock": ["pyromancer", "archer", "frost_mage"],
}
const ROSTER_FORMS := [FOREST_HUMANS + FOREST_ANIMALS, TOWN_HUMANS + TOWN_ANIMALS]
const ROSTER_OUTCOMES := [FOREST_OUTCOMES, TOWN_OUTCOMES]


func _init(rules: Array = ALL) -> void:
	for rule in rules:
		enabled[rule] = true


func has(rule: String) -> bool:
	return enabled.has(rule)


func is_complete() -> bool:
	for rule in ALL:
		if not has(rule):
			return false
	return true


static func upgrade_rule(id: String) -> String:
	return "upgrade_" + id


func allows_upgrade(id: String) -> bool:
	return has(upgrade_rule(id))


## True once at least one wand upgrade is introduced: the scroll appears.
func any_upgrade() -> bool:
	for id in Rules.WAND_UPGRADES:
		if allows_upgrade(id):
			return true
	return false


## True when `id` may be offered or dealt: inside the island roster, and its
## own rule (FORM_RULES) already introduced.
func allows_form(id: String) -> bool:
	if not in_roster(id):
		return false
	return not FORM_RULES.has(id) or has(FORM_RULES[id])


## True when `id` exists on this island at all, even before its own rule: a
## transformation may still produce it.
func in_roster(id: String) -> bool:
	return roster == COMPLETE_ROSTER or id in ROSTER_FORMS[roster]


func allows_pack(pack: Dictionary) -> bool:
	for id in pack.forms:
		if not allows_form(id):
			return false
	return true


## Shop pool restricted to the forms already introduced.
func shop_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in CreatureDB.shop_ids():
		if allows_form(id):
			ids.append(id)
	return ids


func outcomes(id: String) -> Array:
	if roster == COMPLETE_ROSTER:
		return CreatureDB.outcomes(id)
	var result := []
	var next: Array = ROSTER_OUTCOMES[roster].get(id, [])
	for i in next.size():
		result.append({"id": next[i], "chance": CreatureDB.OUTCOME_CHANCES[i]})
	return result


func roll_outcome(id: String, rng: RandomNumberGenerator) -> String:
	var options := outcomes(id)
	if options.is_empty():
		return id
	var roll := rng.randf()
	for option in options:
		roll -= option.chance
		if roll <= 0.0:
			return option.id
	return options[-1].id
