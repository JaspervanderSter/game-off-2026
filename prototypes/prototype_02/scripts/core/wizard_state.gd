class_name WizardState
extends RefCounted
## Persistent state of one wizard across the duel: health, gold, roster, shop.

var team: int
var hp := float(Rules.WIZARD_HP)
var loss_gold_progress := 0.0 # half-heart compensation carries across rounds
var shift_recharge_upgraded := false
var ai_level := Difficulty.ARCHMAGE # opponent strength; the player ignores it
var ai_rerolls := 0
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


## A surviving loser receives one gold per heart lost. Lethal losses grant none.
func take_round_damage(survivors: int) -> float:
	var lost := minf(maxi(survivors, 0) * Rules.DAMAGE_PER_SURVIVOR, hp)
	hp -= lost
	if hp > 0:
		loss_gold_progress += lost
		var reward := floori(loss_gold_progress)
		gold += reward
		loss_gold_progress -= reward
	return lost


func can_upgrade_shift_recharge() -> bool:
	return not shift_recharge_upgraded and gold >= Rules.SHIFT_RECHARGE_COST


func upgrade_shift_recharge() -> bool:
	if not can_upgrade_shift_recharge():
		return false
	gold -= Rules.SHIFT_RECHARGE_COST
	shift_recharge_upgraded = true
	return true


func shift_recharge_time() -> float:
	return Rules.UPGRADED_RECHARGE_TIME if shift_recharge_upgraded else Rules.RECHARGE_TIME


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
	var pool := CreatureDB.shop_ids()
	offers.resize(Rules.SHOP_SIZE)
	for i in Rules.SHOP_SIZE:
		if not locked[i] or offers[i] == "":
			# Draw a different offer in this slot when replacing an existing one.
			var choices := pool.duplicate()
			choices.erase(offers[i])
			offers[i] = choices[rng.randi_range(0, choices.size() - 1)]
			locked[i] = false


func toggle_lock(index: int) -> bool:
	if index < 0 or index >= offers.size() or offers[index] == "":
		return false
	locked[index] = not locked[index]
	return true


func can_reroll() -> bool:
	if gold < Rules.REROLL_COST:
		return false
	for i in offers.size():
		if not locked[i] or offers[i] == "":
			return true
	return false


func reroll(rng: RandomNumberGenerator) -> bool:
	if not can_reroll():
		return false
	gold -= Rules.REROLL_COST
	refresh_offers(rng)
	return true


func can_buy(index: int) -> bool:
	return _offer_affordable(index) and free_slot() >= 0


func _offer_affordable(index: int) -> bool:
	if index < 0 or index >= offers.size() or offers[index] == "":
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
	return _offer_affordable(index) and target != null and target in creatures \
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
	return source != null and target != null and source != target \
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


## Sells for the purchase price (delegated default).
func sell(c: OwnedCreature) -> void:
	if c in creatures:
		gold += c.price()
		creatures.erase(c)


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
