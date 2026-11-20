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


func allows_form(id: String) -> bool:
	return not FORM_RULES.has(id) or has(FORM_RULES[id])


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
