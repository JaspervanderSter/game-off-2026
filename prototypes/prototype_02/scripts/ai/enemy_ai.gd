class_name EnemyAI
extends RefCounted
## Opponent wizard: combat-value purchases, merges, bounded rerolls, permanent
## upgrades and expected-value casting. It follows the same rules as the player.

# Target share of each role in a full team.
const ROLE_TARGET := {"front": 0.45, "mid": 0.15, "back": 0.25, "support": 0.15}


static func choose_pack(rng: RandomNumberGenerator, packs: Array) -> Array:
	var candidates := packs.duplicate()
	var choices := []
	for i in mini(3, candidates.size()):
		var index := rng.randi_range(0, candidates.size() - 1)
		choices.append(candidates[index])
		candidates.remove_at(index)
	var best: Array = choices[0]
	var best_score := -INF
	for pack in choices:
		var roles := {}
		var score := 0.0
		for id in pack:
			score += form_value(id)
			roles[CreatureDB.get_form(id).role] = true
		score += (12 if roles.has("front") else 0) + (10 if roles.has("back") else 0) + (6 if roles.has("support") else 0)
		if score > best_score:
			best = pack
			best_score = score
	return best


## The simulation consumes the same actions immediately; the live game spaces
## them out so spending, combining and placement remain visible.
static func shop(state: WizardState, rng: RandomNumberGenerator) -> void:
	state.ai_rerolls = 0
	for _guard in 64:
		if shop_step(state, rng).is_empty():
			break


## Combat value ignores resale value and partial copies: a 2/3 group has exactly
## the same combat stats as a single copy of that rank.
static func form_value(id: String, stars: int = 0) -> float:
	var d := CreatureDB.get_form(id)
	var mult := Rules.star_mult(stars)
	var ehp: float = d.hp * mult / (1.0 - d.armour / 100.0)
	var dps: float = d.dmg * mult / d.interval
	var value := sqrt(ehp * dps) * (1.0 + minf(d.range, 5.0) * 0.06)
	match d.ability:
		"berserk": value *= 1.18
		"parry", "backline", "hop", "hunt", "dive", "charge": value += 8
		"pierce", "poison": value += 10
		"cleave", "fireball", "inspire": value += 12
		"blizzard": value += 24 # Includes the chill applied by basic shots.
		"heal": value += 15
		"graze": value += 14
		"spray", "display": value += 13
		"thorns", "shell", "pack": value += 7
		"kite": value += 6
	return value


static func _base_copies(state: WizardState, id: String) -> int:
	var count := 0
	for c in state.creatures:
		if c.form_id == id and c.stars == 0:
			count += c.merge_copies
	return count


static func _protected_value(state: WizardState, c: OwnedCreature) -> float:
	var value := form_value(c.form_id, c.stars)
	var role: String = CreatureDB.get_form(c.form_id).role
	var same_role := 0
	for other in state.fielded():
		if CreatureDB.get_form(other.form_id).role == role:
			same_role += 1
	if same_role <= 1:
		value += 15 if role == "front" else 8
	return value


static func _weakest_fielded(state: WizardState) -> OwnedCreature:
	var weakest: OwnedCreature = null
	for c in state.fielded():
		if weakest == null or _protected_value(state, c) < _protected_value(state, weakest):
			weakest = c
	return weakest


static func shop_step(state: WizardState, rng: RandomNumberGenerator) -> Dictionary:
	var targets := state.creatures.duplicate()
	targets.sort_custom(func(a, b): return a.is_fielded() and not b.is_fielded())
	for target in targets:
		var total := 0
		for c in state.creatures:
			if c.form_id == target.form_id and c.stars == target.stars:
				total += c.merge_copies
		for source in state.creatures:
			if not state.can_merge(source, target):
				continue
			# Do not lose a fielded body for an unfinished two-copy group.
			if source.is_fielded() and (total < 3 or state.field_count() < Rules.FIELD_CAP):
				continue
			var old_stars: int = target.stars
			state.merge(source, target)
			arrange(state)
			return {"kind": "merge", "uid": target.uid, "promoted": target.stars > old_stars}
	var full := state.field_count() >= Rules.FIELD_CAP
	var weakest := _weakest_fielded(state)
	var best := -1
	var best_score := -INF
	var replace := false
	for i in state.offers.size():
		var id := state.offers[i]
		if id == "":
			continue
		var d := CreatureDB.get_form(id)
		var copies := _base_copies(state, id)
		state.locked[i] = copies > 0 and d.price > state.gold
		if d.price > state.gold or state.free_slot() < 0:
			continue
		var value := form_value(id)
		var must_replace := full and copies == 0
		if must_replace and (weakest == null or value + _role_need(state, d.role) * 20 < _protected_value(state, weakest) * 1.12):
			continue
		var score := value / pow(float(d.price), 0.35) + _role_need(state, d.role) * 25
		if copies > 0:
			score += 28 if copies % 3 == 2 else 10
		if not full:
			score += 15 # field a complete team before spending on rerolls/upgrades
		score += rng.randf() * 0.05
		if score > best_score:
			best_score = score
			best = i
			replace = must_replace
	# One permanent investment, paid from the same gold as the player's.
	if state.field_count() >= 5 and state.can_upgrade_shift_recharge() and (best < 0 or state.gold >= 7):
		state.upgrade_shift_recharge()
		return {"kind": "upgrade", "cost": Rules.SHIFT_RECHARGE_COST}
	if best >= 0:
		if replace:
			var event := {"kind": "sell", "form": weakest.form_id, "cell": weakest.cell, "value": weakest.price()}
			state.sell(weakest)
			return event
		var bought := state.buy(best)
		if bought != null:
			arrange(state)
			return {"kind": "buy", "uid": bought.uid, "cost": bought.price()}
	if state.ai_rerolls < 2 and state.gold >= Rules.REROLL_COST + 2 and state.free_slot() >= 0 and state.can_reroll():
		state.reroll(rng)
		state.ai_rerolls += 1
		return {"kind": "reroll", "cost": Rules.REROLL_COST}
	return {}


## Select by fighting power, preserve a frontline and keep support close enough
## to cover it. Spread ranged units to reduce exposure to 3x3 blizzards.
static func arrange(state: WizardState) -> void:
	var sorted := state.creatures.duplicate()
	sorted.sort_custom(func(a, b): return form_value(a.form_id, a.stars) > form_value(b.form_id, b.stars))
	var selected: Array[OwnedCreature] = []
	for role in ["front", "back"]:
		for c in sorted:
			if CreatureDB.get_form(c.form_id).role == role:
				selected.append(c)
				break
	for c in sorted:
		if selected.size() >= Rules.FIELD_CAP:
			break
		if c not in selected:
			selected.append(c)
	for c in state.creatures:
		c.cell = Vector2i(-1, -1)
		c.slot = -1
	for c in selected:
		var d := CreatureDB.get_form(c.form_id)
		var role: String = "mid" if d.role == "support" else d.role
		if role == "back":
			var row := state.preferred_row(role)
			for col in [1, 6, 3, 4, 0, 7, 2, 5]:
				var cell := Vector2i(col, row)
				if state.at_cell(cell) == null:
					c.cell = cell
					break
		else:
			c.cell = state.preferred_free_cell(role)
	var slot := 0
	for c in sorted:
		if c not in selected:
			c.slot = slot
			slot += 1


static func _role_need(state: WizardState, role: String) -> float:
	var count := 0
	var fielded := state.fielded()
	for c in fielded:
		if CreatureDB.get_form(c.form_id).role == role:
			count += 1
	var share := float(count) / maxf(1.0, fielded.size())
	return ROLE_TARGET[role] - share


static func _cheapest(state: WizardState) -> OwnedCreature:
	var best: OwnedCreature = null
	for c in state.creatures:
		if best == null or c.price() < best.price():
			best = c
	return best


## Evaluate expected form value using the same visible 55/30/15 distribution
## as the player. Never inspect the next random roll or grant free resources.
static func choose_cast(battle: Battle, team: int) -> Unit:
	var full := battle.spells[team].charges >= Rules.MAX_CHARGES
	var best: Unit = null
	var best_score := 0.03 if full else 0.18
	for u in battle.units:
		if not u.alive or u.immune_t > 0.0:
			continue
		var allied := u.team == team
		if allied and (u.jump_t > 0 or u.dive_target != null or u.charging):
			continue
		var ratio := u.hp / u.max_hp
		var current := form_value(u.form_id, u.stars) * Rules.level_mult(u.level) * sqrt(maxf(ratio, 0.05))
		var expected := 0.0
		for outcome in CreatureDB.outcomes(u.form_id):
			var value := form_value(outcome.id, u.stars) * Rules.level_mult(u.level + (1 if allied else 0))
			value *= sqrt(minf(1.0, ratio + Rules.SHIFT_HEAL))
			var d := CreatureDB.get_form(outcome.id)
			if d.range > 2.0 and u.target != null and u.edge_dist(u.target) < Rules.CELL:
				value *= 0.85
			expected += outcome.chance * value
		var score := (expected - current) / maxf(current, 20.0) if allied else (current - expected) / maxf(current, 20.0) - 0.2
		for key in u.statuses:
			if not u.statuses[key].positive:
				score += 0.2 if allied else -0.2
		if allied and ratio < 0.3:
			score += 0.25
		if allied and u.data.ability == "blizzard" and u.ability_timer < 0.6:
			score -= 0.35
		if allied and u.shell_t > 0:
			score -= 0.3
		if score > best_score:
			best_score = score
			best = u
	return best
