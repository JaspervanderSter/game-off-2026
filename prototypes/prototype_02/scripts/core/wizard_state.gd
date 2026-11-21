class_name WizardState
extends RefCounted
## Persistent state of one wizard across the duel: health, gold, roster, shop.

var team: int
var max_hp := Rules.WIZARD_HP # starting heart capacity for this duel
var hp := float(Rules.WIZARD_HP)
var loss_gold_progress := 0.0 # half-heart compensation carries across rounds
var upgrades := {} # wand upgrade id -> purchased level (see Rules.WAND_UPGRADES)
var shift_recharge_upgraded: bool:
	get:
		return upgrade_level("recharge") > 0
	set(value):
		upgrades["recharge"] = 1 if value else 0
var ai_level := Difficulty.ARCHMAGE # opponent strength; the player ignores it
## EnemyAI profile keys this opponent plays differently from its level
## (OpponentDB.ai_overrides); see EnemyAI.profile_of.
var ai_overrides := {}
## Rules of the duel, shared by both wizards (complete outside the journey).
var rules := Ruleset.new()
## False for journey opponents without magic: they never cast.
var magic := true
## Forest-only guided encounters: fixed enemy army and a last-creature safety net.
var learning_duel := false
var ai_rerolls := 0
var ai_whims := {} # form id -> taste drawn once per duel by whimsical AI levels
var gold := 0
var creatures: Array[OwnedCreature] = []
var offers: Array[String] = [] # "" once bought
var locked: Array[bool] = [false, false, false]


func _init(team_id: int) -> void:
	team = team_id


func take_starting_pack(pack: Dictionary) -> void:
	for id in pack.forms:
		add_creature(id)
	gold += pack.bonus_gold


## A surviving loser receives one gold per heart lost once the shop is
## introduced. Lethal losses grant none.
func take_round_damage(survivors: int) -> float:
	var lost := minf(maxi(survivors, 0) * Rules.DAMAGE_PER_SURVIVOR, hp)
	hp -= lost
	if hp > 0 and rules.has(Ruleset.SHOP):
		loss_gold_progress += lost
		var reward := floori(loss_gold_progress)
		gold += reward
		loss_gold_progress -= reward
	return lost


## Fielded harvesters (peasants) as [{"creature", "gold"}]; benched ones idle.
func harvest_yields() -> Array[Dictionary]:
	var yields: Array[Dictionary] = []
	if not rules.has(Ruleset.HARVEST):
		return yields
	for c in fielded():
		var amount := Rules.harvest_gold(c.form_id, c.stars)
		if amount > 0:
			yields.append({"creature": c, "gold": amount})
	return yields


func harvest_total() -> int:
	var total := 0
	for y in harvest_yields():
		total += y.gold
	return total


## Round-start harvest: grants every harvester's gold and returns the yields.
func harvest() -> Array[Dictionary]:
	var yields := harvest_yields()
	for y in yields:
		gold += y.gold
	return yields


func upgrade_level(id: String) -> int:
	return upgrades.get(id, 0)


func upgrade_maxed(id: String) -> bool:
	return upgrade_level(id) >= Rules.WAND_UPGRADE_COSTS[id].size()


## Gold cost of the next level of a wand upgrade; -1 once it is maxed.
func upgrade_cost(id: String) -> int:
	return -1 if upgrade_maxed(id) else Rules.WAND_UPGRADE_COSTS[id][upgrade_level(id)]


func can_buy_upgrade(id: String) -> bool:
	return rules.allows_upgrade(id) and not upgrade_maxed(id) and gold >= upgrade_cost(id)


func buy_upgrade(id: String) -> bool:
	if not can_buy_upgrade(id):
		return false
	gold -= upgrade_cost(id)
	upgrades[id] = upgrade_level(id) + 1
	return true


func shift_recharge_time() -> float:
	return Rules.wand_value("recharge", upgrade_level("recharge"))


func start_charges() -> int:
	return int(Rules.wand_value("charges", upgrade_level("charges")))


func shift_heal() -> float:
	return Rules.wand_value("heal", upgrade_level("heal"))


func hex_stun() -> float:
	return Rules.wand_value("hex", upgrade_level("hex"))


## Whether this wizard casts at all: the wand is introduced and it has magic.
func can_cast() -> bool:
	return magic and rules.has(Ruleset.WAND)


func fielded() -> Array[OwnedCreature]:
	var result: Array[OwnedCreature] = []
	for c in creatures:
		if c.is_fielded():
			result.append(c)
	return result


func benched() -> Array[OwnedCreature]:
	var result: Array[OwnedCreature] = []
	for c in creatures:
		if not c.is_fielded():
			result.append(c)
	return result


func field_count() -> int:
	return fielded().size()


func at_cell(cell: Vector2i) -> OwnedCreature:
	for c in creatures:
		if c.cell == cell:
			return c
	return null


func at_slot(slot: int) -> OwnedCreature:
	for c in creatures:
		if not c.is_fielded() and c.slot == slot:
			return c
	return null


func owns_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < Rules.COLS and cell.y in Rules.team_rows(team)


func free_slot() -> int:
	for s in Rules.RESERVE_CAP:
		if at_slot(s) == null:
			return s
	return -1


func has_space() -> bool:
	return field_count() < Rules.FIELD_CAP or free_slot() >= 0


## Row preferred for a role: front rows face the centre of the board.
func preferred_row(role: String) -> int:
	var rows := Rules.team_rows(team)
	if team == 1:
		rows.reverse() # enemy front row is row 2; the player's is row 3
	match role:
		"front":
			return rows[0]
		"mid":
			return rows[1]
		_:
			return rows[2]


## Free cell near the centre of the preferred row, falling back to other rows.
func preferred_free_cell(role: String) -> Vector2i:
	var rows: Array[int] = [preferred_row(role)]
	for r in Rules.team_rows(team):
		if r not in rows:
			rows.append(r)
	var cols := [3, 4, 2, 5, 1, 6, 0, 7]
	for r in rows:
		for c in cols:
			var cell := Vector2i(c, r)
			if at_cell(cell) == null:
				return cell
	return Vector2i(-1, -1)


## Adds a creature to the field when there is room, otherwise to the reserve.
func add_creature(form_id: String) -> OwnedCreature:
	if not has_space():
		return null
	var c := OwnedCreature.new(form_id)
	if field_count() < Rules.FIELD_CAP:
		c.cell = preferred_free_cell(CreatureDB.get_form(form_id).role)
	else:
		c.slot = free_slot()
	creatures.append(c)
	return c


func refresh_offers(rng: RandomNumberGenerator) -> void:
	var pool := rules.shop_ids()
	offers.resize(Rules.SHOP_SIZE)
	if not rules.has(Ruleset.SHOP):
		offers.fill("") # no stall before the journey introduces it
		return
	for i in Rules.SHOP_SIZE:
		if not locked[i] or offers[i] == "":
			# Draw a different offer in this slot when replacing an existing one.
			var choices := pool.duplicate()
			choices.erase(offers[i])
			offers[i] = choices[rng.randi_range(0, choices.size() - 1)]
			locked[i] = false


func toggle_lock(index: int) -> bool:
	if not rules.has(Ruleset.TRADE) or index < 0 or index >= offers.size() or offers[index] == "":
		return false
	locked[index] = not locked[index]
	return true


func can_reroll() -> bool:
	if not rules.has(Ruleset.TRADE) or gold < Rules.REROLL_COST:
		return false
	for i in offers.size():
		if not locked[i] or offers[i] == "":
			return true
	return false


## A reroll makes sense once nothing left on the stall can be bought, while the
## gold still covers the reroll and the cheapest creature it could deal, and
## there is room for that creature. The reroll button glints only then.
func reroll_makes_sense() -> bool:
	if not can_reroll() or not has_space():
		return false
	var cheapest := -1
	for id in rules.shop_ids():
		var price: int = CreatureDB.get_form(id).price
		cheapest = price if cheapest < 0 else mini(cheapest, price)
	if cheapest < 0 or gold < Rules.REROLL_COST + cheapest:
		return false
	for id in offers:
		if id != "" and gold >= CreatureDB.get_form(id).price:
			return false
	return true


func reroll(rng: RandomNumberGenerator) -> bool:
	if not can_reroll():
		return false
	gold -= Rules.REROLL_COST
	refresh_offers(rng)
	return true


func can_buy(index: int) -> bool:
	return _offer_affordable(index) and free_slot() >= 0


func _offer_affordable(index: int) -> bool:
	if not rules.has(Ruleset.SHOP) or index < 0 or index >= offers.size() or offers[index] == "":
		return false
	return gold >= CreatureDB.get_form(offers[index]).price


func buy(index: int) -> OwnedCreature:
	if not can_buy(index):
		return null
	var slot := free_slot()
	var c := _purchase(index)
	c.slot = slot
	return c


## Direct shop drops are validated before charging; they need no spare bench
## slot when placing on an empty board cell or explicitly combining a copy.
func buy_to_cell(index: int, cell: Vector2i) -> OwnedCreature:
	if not _offer_affordable(index) or not owns_cell(cell):
		return null
	var target := at_cell(cell)
	if target == null:
		if field_count() >= Rules.FIELD_CAP:
			return null
	elif not can_merge_offer(index, target):
		return null
	var c := _purchase(index)
	if target != null:
		merge(c, target)
		return target
	c.cell = cell
	return c


func buy_to_slot(index: int, slot: int) -> OwnedCreature:
	if not _offer_affordable(index) or slot < 0 or slot >= Rules.RESERVE_CAP:
		return null
	var target := at_slot(slot)
	if target != null and not can_merge_offer(index, target):
		return null
	var c := _purchase(index)
	if target != null:
		merge(c, target)
		return target
	c.slot = slot
	return c


func can_merge_offer(index: int, target: OwnedCreature) -> bool:
	return rules.has(Ruleset.MERGE) and _offer_affordable(index) and target != null and target in creatures \
		and target.form_id == offers[index] and target.stars == 0


func _purchase(index: int) -> OwnedCreature:
	var id := offers[index]
	gold -= CreatureDB.get_form(id).price
	offers[index] = ""
	locked[index] = false
	var c := OwnedCreature.new(id)
	creatures.append(c)
	return c


## A manual drop combines only identical forms at the same permanent rank.
func can_merge(source: OwnedCreature, target: OwnedCreature) -> bool:
	return rules.has(Ruleset.MERGE) and source != null and target != null and source != target \
		and source in creatures and target in creatures \
		and source.form_id == target.form_id and source.stars == target.stars \
		and target.stars < Rules.MAX_STARS


## Partial groups grant no stats. Consume only what completes the target;
## overflow stays in the source at its original board cell or bench slot.
func merge(source: OwnedCreature, target: OwnedCreature) -> bool:
	if not can_merge(source, target):
		return false
	var used := mini(source.merge_copies, 3 - target.merge_copies)
	target.merge_copies += used
	source.merge_copies -= used
	if source.merge_copies == 0:
		creatures.erase(source)
	if target.merge_copies == 3:
		target.stars += 1
		target.merge_copies = 1
	return true


## Sells for the purchase price (delegated default), once trading is introduced.
func can_sell(c: OwnedCreature) -> bool:
	return rules.has(Ruleset.TRADE) and c in creatures


func sell(c: OwnedCreature) -> bool:
	if not can_sell(c):
		return false
	gold += c.price()
	creatures.erase(c)
	return true


## Moves a creature to a board cell (own half) or reserve slot, swapping with
## an occupant. Returns false when the move would break the field capacity.
func move_to_cell(c: OwnedCreature, cell: Vector2i) -> bool:
	if c not in creatures or not owns_cell(cell):
		return false
	var other := at_cell(cell)
	if other == c:
		return true
	if can_merge(c, other):
		return merge(c, other)
	if other == null:
		if not c.is_fielded() and field_count() >= Rules.FIELD_CAP:
			return false
	else:
		other.cell = c.cell
		other.slot = c.slot
	c.cell = cell
	c.slot = -1
	return true


func move_to_slot(c: OwnedCreature, slot: int) -> bool:
	if c not in creatures or slot < 0 or slot >= Rules.RESERVE_CAP:
		return false
	var other := at_slot(slot)
	if other == c:
		return true
	if can_merge(c, other):
		return merge(c, other)
	if other != null:
		other.cell = c.cell
		other.slot = c.slot
	c.cell = Vector2i(-1, -1)
	c.slot = slot
	return true
