class_name EnemyAI
extends RefCounted
## Opponent wizard: role-balanced purchases, role-based placement and a simple
## casting heuristic. It follows the same rules as the player.

# Target share of each role in a full team.
const ROLE_TARGET := {"front": 0.45, "mid": 0.15, "back": 0.25, "support": 0.15}


static func choose_pack(rng: RandomNumberGenerator, packs: Array) -> Array:
	return packs[rng.randi_range(0, packs.size() - 1)]


static func shop(state: WizardState, rng: RandomNumberGenerator) -> void:
	for _guard in 8:
		var best := -1
		var best_score := -INF
		for i in state.offers.size():
			var id := state.offers[i]
			if id == "" or CreatureDB.get_form(id).price > state.gold:
				continue
			var form := CreatureDB.get_form(id)
			var score: float = form.price + _role_need(state, form.role) * 4.0 + rng.randf() * 0.6
			if score > best_score:
				best_score = score
				best = i
		if best < 0:
			break
		var price: int = CreatureDB.get_form(state.offers[best]).price
		if state.field_count() >= Rules.FIELD_CAP:
			# Full team: only upgrade by replacing the cheapest creature.
			var weakest := _cheapest(state)
			if weakest == null or weakest.price() >= price:
				break
			state.sell(weakest)
		state.buy(best)
	arrange(state)


## Fields the most expensive creatures and sorts them into rows by role.
static func arrange(state: WizardState) -> void:
	var sorted := state.creatures.duplicate()
	sorted.sort_custom(func(a, b): return a.price() > b.price())
	for c in state.creatures:
		c.cell = Vector2i(-1, -1)
		c.slot = -1
	var slot := 0
	for i in sorted.size():
		var c: OwnedCreature = sorted[i]
		if i < Rules.FIELD_CAP:
			c.cell = state.preferred_free_cell(CreatureDB.get_form(c.form_id).role)
		else:
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


## Picks a cast target, or null to keep the charge. Casting on an ally heals,
## cleanses and levels it up; casting on an enemy only reshuffles its form, so
## the AI saves those for healthy, dangerous enemies.
static func choose_cast(battle: Battle, team: int) -> Unit:
	var full := battle.spells[team].charges >= Rules.MAX_CHARGES
	var best: Unit = null
	var best_score := 0.0 if full else 0.55
	for u in battle.units:
		if not u.alive or u.immune_t > 0.0:
			continue
		var ratio := u.hp / u.max_hp
		var score := 0.0
		if u.team == team:
			score = (1.0 - ratio) * 1.6 + 0.15
			for key in u.statuses:
				if not u.statuses[key].positive:
					score += 0.3
			if u.target != null and u.edge_dist(u.target) <= u.range_px():
				score += 0.15 # engaged: the attack reset pays off immediately
		elif ratio > 0.85:
			score = 0.2 + 0.12 * u.data.price + 0.15 * (u.level - 1)
		score += battle.rng.randf() * 0.1
		if score > best_score:
			best_score = score
			best = u
	return best
