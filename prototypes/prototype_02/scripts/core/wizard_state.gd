class_name WizardState
extends RefCounted
## Persistent state of one wizard across the duel: health, gold, roster, shop.

var team: int
var hp := Rules.WIZARD_HP
var gold := 0
var creatures: Array[OwnedCreature] = []
var offers: Array[String] = [] # "" once bought
var locked: Array[bool] = [false, false, false]


func _init(team_id: int) -> void:
	team = team_id


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


func _merge_candidates(id: String, rank: int) -> Array[OwnedCreature]:
	var result: Array[OwnedCreature] = []
	for c in creatures:
		if c.form_id == id and c.stars == rank:
			result.append(c)
	return result


func can_buy(index: int) -> bool:
	if index < 0 or index >= offers.size() or offers[index] == "":
		return false
	# A third copy may be bought even with a full bench: it merges immediately.
	return gold >= CreatureDB.get_form(offers[index]).price and (free_slot() >= 0 or _merge_candidates(offers[index], 1).size() >= 2)


func buy(index: int) -> OwnedCreature:
	if not can_buy(index):
		return null
	var id := offers[index]
	gold -= CreatureDB.get_form(id).price
	offers[index] = ""
	locked[index] = false
	var c := OwnedCreature.new(id)
	c.slot = free_slot()
	creatures.append(c)
	return _merge(c)


## Merge chains keep a fielded copy and its cell whenever possible. Otherwise
## the result stays on the bench; consumed copies immediately free their slots.
func _merge(c: OwnedCreature) -> OwnedCreature:
	while c.stars < Rules.MAX_STARS:
		var matches := _merge_candidates(c.form_id, c.stars)
		if matches.size() < 3:
			break
		matches.sort_custom(func(a, b):
			if a.is_fielded() != b.is_fielded():
				return a.is_fielded()
			return a.uid < b.uid)
		var keep: OwnedCreature = matches[0]
		# Include the incoming copy so the caller always receives a live result.
		var consumed: Array[OwnedCreature] = []
		if c != keep:
			consumed.append(c)
		for other in matches:
			if other != keep and other not in consumed and consumed.size() < 2:
				consumed.append(other)
		for other in consumed:
			creatures.erase(other)
		keep.stars += 1
		c = keep
	return c


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
	if other != null:
		other.cell = c.cell
		other.slot = c.slot
	c.cell = Vector2i(-1, -1)
	c.slot = slot
	return true
