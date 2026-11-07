class_name EnemyAI
extends RefCounted
## Opponent wizard: role-balanced purchases, role-based placement and a simple
## casting heuristic. It follows the same rules as the player.

# Target share of each role in a full team. Lowering the front share makes the
# AI build less of a static tank wall and more varied armies.
const ROLE_TARGET := {"front": 0.40, "mid": 0.0, "back": 0.35, "support": 0.25}


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


## Picks a cast target, or null to keep the charge. The heuristic values
## interrupting an enemy windup, dodging an incoming projectile, and chaining
## a momentum combo.
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
			if battle.incoming_projectile_to(u):
				score += 0.45 # a well-timed transformation can dodge it
			if u.momentum_window_t > 0.0:
				score += 0.20 # a combo is available
			if u.needs_special_for_upgrade():
				score -= 0.6 # the upgrade is blocked until the special is used
			elif u.stage() == 0 or u.special_used:
				score += 0.3 # a valid upgrade is available
			if u.is_final_stage() and ratio < 0.7:
				score += 0.15 # a refresh is useful at max stage
		else:
			score = 0.2 + 0.12 * float(u.data.get("price", 0)) + 0.15 * (u.stars - 1) + 0.20 * (u.max_hp / 300.0)
			if ratio < 0.45:
				score -= 0.25 # transforming a low-health enemy also heals it
			if u.has_pending_attack():
				score += 0.35 # interrupt the windup or special movement
			if u.momentum_window_t > 0.0:
				score += 0.10
			if u.needs_special_for_upgrade():
				score -= 0.5 # the cast would be rejected by the special gate
		score += battle.rng.randf() * 0.1
		if score > best_score:
			best_score = score
			best = u
	return best
