class_name EnemyAI
extends RefCounted
## Opponent wizard: combat-value purchases, merges, paid rerolls, permanent
## upgrades and expected-value casting. It follows the same rules as the player.
## `WizardState.ai_level` selects a `Difficulty` profile: easier levels make
## noisier, more limited decisions but never receive or lose resources.

# Target share of each role in a full team.
const ROLE_TARGET := {"front": 0.45, "mid": 0.15, "back": 0.25, "support": 0.15}

const BASE_PROFILE := {
	"fireball_value": 12.0, "blizzard_value": 24.0,
	"star_ability_scaling": 0.0,
	"duplicate_value": 10.0, "promotion_value": 28.0, "price_weight": 0.35,
	"replacement_margin": 1.12, "rerolls": 2, "reroll_reserve": 2,
	"upgrade_field": 5, "upgrade_gold": 7, "spread_front": false,
	"cast_threshold": 0.18, "full_cast_threshold": 0.03,
	"target_power_weight": 0.0, "ally_cast_bias": 0.0,
	"low_health_bonus": 0.25, "stun_value": 0.1, "interrupt_value": 0.6,
}
# Based on the profile selected by self-play, with budget-driven rerolls.
const DEFAULT_PROFILE := {
	"fireball_value": 32.0, "blizzard_value": 32.0,
	"star_ability_scaling": 1.0,
	"duplicate_value": 10.0, "promotion_value": 28.0, "price_weight": 0.18,
	"replacement_margin": 1.12, "rerolls": -1, "reroll_reserve": 0,
	"upgrade_field": 5, "upgrade_gold": 7, "spread_front": false,
	"cast_threshold": 0.22, "full_cast_threshold": 0.03,
	"target_power_weight": 0.0, "ally_cast_bias": 0.0,
	"low_health_bonus": 0.25, "stun_value": 0.16, "interrupt_value": 1.1,
}
# Archmage strategy, tuned in full AI-vs-AI duels (training/arena.gd):
# peasant harvest valued while hearts remain, seeker-bolt crossbowmen, a wide
# frontline and hexes that count the level reset. Its opening is dealt from its
# deck like every other level's.
const ARCHMAGE_PROFILE := {
	"fireball_value": 32.0, "blizzard_value": 8.0,
	"star_ability_scaling": 1.0, "chain_value": 25.0,
	"harvest_value": 35.0, "harvest_hp_power": 1.0,
	"duplicate_value": 10.0, "promotion_value": 28.0, "price_weight": 0.05,
	"replacement_margin": 1.25, "rerolls": -1, "reroll_reserve": 0,
	"upgrade_field": 5, "upgrade_gold": 7, "spread_front": true,
	"front_cols": [0, 7, 1, 6, 2, 5, 3, 4],
	"cast_threshold": 0.22, "full_cast_threshold": 0.03,
	"target_power_weight": 0.9, "ally_cast_bias": 0.1,
	"low_health_bonus": 0.12, "stun_value": 0.3, "interrupt_value": 1.1,
	"hex_level_reset": true,
}
# Wand upgrades the AI saves for, first unmaxed one first: faster recharge, then
# both starting charges, then the longer hex and the stronger heal.
const UPGRADE_ORDER: Array[String] = ["recharge", "charges", "hex", "heal"]


## Strategy of a difficulty level. Easier levels keep DEFAULT_PROFILE and decide
## worse through Difficulty; the Archmage plays its own tuned strategy.
static func profile_for(level: int) -> Dictionary:
	return ARCHMAGE_PROFILE if level == Difficulty.ARCHMAGE else DEFAULT_PROFILE


## Simulations draw an opening uniformly, unless the profile forces one
## ("pack": index). The live game deals the opponent's opening from a PackDeck.
static func choose_pack(rng: RandomNumberGenerator, profile: Dictionary = DEFAULT_PROFILE) -> Dictionary:
	var index := rng.randi_range(0, CreatureDB.PACKS.size() - 1)
	return CreatureDB.PACKS[int(profile.get("pack", index))]


## The simulation consumes the same actions immediately; the live game spaces
## them out so spending, combining and placement remain visible.
static func shop(state: WizardState, rng: RandomNumberGenerator, profile: Dictionary = {}) -> void:
	if profile.is_empty():
		profile = profile_for(state.ai_level)
	state.ai_rerolls = 0
	while not shop_step(state, rng, profile).is_empty():
		pass


## Combat value ignores resale value and partial copies: a 2/3 group has exactly
## the same combat stats as a single copy of that rank.
static func form_value(id: String, stars: int = 0, profile: Dictionary = DEFAULT_PROFILE) -> float:
	var d := CreatureDB.get_form(id)
	var mult := Rules.star_mult(stars)
	var ehp: float = d.hp * mult / (1.0 - d.armour / 100.0)
	var dps: float = d.dmg * mult / d.interval
	var value := sqrt(ehp * dps) * (1.0 + minf(d.range, 5.0) * 0.06)
	match d.ability:
		"berserk": value *= 1.18
		"parry", "backline", "hop", "hunt", "dive", "charge": value += 8
		"pierce", "poison": value += 10
		"cleave", "song": value += 12
		"fireball": value += profile.fireball_value * lerpf(1.0, mult, profile.star_ability_scaling)
		"blizzard": value += profile.blizzard_value # Includes the chill applied by basic shots.
		"heal": value += 15
		"graze": value += 14
		"spray", "display": value += 13
		"thorns", "shell", "pack": value += 7
		"kite": value += 6
	# Seeker bolts chain to more targets from one star (crossbowman).
	var chain: Array = d.get("chain_targets", [])
	if not chain.is_empty():
		value += profile.get("chain_value", 0.0) * (int(chain[clampi(stars, 0, chain.size() - 1)]) - 1)
	return value


## Fielding value: combat value plus the gold a harvester pays when the fight
## begins, plus the wizard's whim for that creature (whimsical levels only).
static func field_value(state: WizardState, form_id: String, stars: int, profile: Dictionary) -> float:
	# Early harvests pay for more rounds; a wizard low on hearts has fewer left.
	var weight: float = profile.get("harvest_value", 0.0) * pow(state.hp / Rules.WIZARD_HP, profile.get("harvest_hp_power", 0.0))
	return form_value(form_id, stars, profile) + weight * Rules.harvest_gold(form_id, stars) + state.ai_whims.get(form_id, 0.0)


## Draw once per duel how much a whimsical wizard likes or dislikes each creature.
## The taste lasts the whole duel, so its mistakes add up into an odd but
## consistent team instead of averaging out like per-purchase noise.
static func draw_whims(state: WizardState, rng: RandomNumberGenerator) -> void:
	var spread: float = Difficulty.profile(state.ai_level).get("whims", 0.0)
	if spread <= 0.0 or not state.ai_whims.is_empty():
		return
	for id in CreatureDB.shop_ids():
		state.ai_whims[id] = rng.randf_range(-spread, spread)


static func _protected_value(state: WizardState, c: OwnedCreature, profile: Dictionary) -> float:
	var value := field_value(state, c.form_id, c.stars, profile)
	var role: String = CreatureDB.get_form(c.form_id).role
	var same_role := 0
	for other in state.fielded():
		if CreatureDB.get_form(other.form_id).role == role:
			same_role += 1
	if same_role <= 1:
		value += 15 if role == "front" else 8
	return value


static func _weakest_fielded(state: WizardState, profile: Dictionary) -> OwnedCreature:
	var weakest: OwnedCreature = null
	for c in state.fielded():
		if weakest == null or _protected_value(state, c, profile) < _protected_value(state, weakest, profile):
			weakest = c
	return weakest


static func shop_step(state: WizardState, rng: RandomNumberGenerator, profile: Dictionary = {}) -> Dictionary:
	if profile.is_empty():
		profile = profile_for(state.ai_level)
	var difficulty := Difficulty.profile(state.ai_level)
	draw_whims(state, rng)
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
			arrange(state, profile)
			return {"kind": "merge", "uid": target.uid, "promoted": target.stars > old_stars}
	# Before the journey introduces the shop, the opening is all there is.
	if not state.rules.has(Ruleset.SHOP):
		return {}
	var full := state.field_count() >= Rules.FIELD_CAP
	var weakest := _weakest_fielded(state, profile) if full else null
	var replacement_value := _protected_value(state, weakest, profile) * float(profile.replacement_margin) if full else 0.0
	var bench_full := state.free_slot() < 0
	var plans := {}
	for id in state.rules.shop_ids():
		var role: String = CreatureDB.get_form(id).role
		var value: float = field_value(state, id, 0, profile) + profile.get("focus", {}).get(id, 0.0)
		var need := _role_need(state, role)
		var target: OwnedCreature = null
		var copies := 0
		var can_build := false
		for c in state.creatures:
			# Copies only count once merging is introduced.
			if c.form_id != id or not state.rules.has(Ruleset.MERGE):
				continue
			if c.stars == 0:
				copies += c.merge_copies
				if target == null or (c.is_fielded() and not target.is_fielded()):
					target = c
			elif c.is_fielded() and c.stars < Rules.MAX_STARS:
				can_build = true
		var replace := false
		if full and target == null and (bench_full or not can_build):
			if not difficulty.replace or not state.rules.has(Ruleset.TRADE) or value + need * 20 < replacement_value:
				continue
			replace = true
		var price: int = CreatureDB.get_form(id).price
		var score := value / pow(float(price), profile.price_weight) + need * 25
		if copies > 0 or can_build:
			score += profile.promotion_value if copies % 3 == 2 else profile.duplicate_value
		plans[id] = {"price": price, "score": score, "target": target, "replace": replace, "duplicate": copies > 0 or can_build}
	var best := -1
	var best_score := -INF
	for i in state.offers.size():
		var id := state.offers[i]
		if not plans.has(id):
			state.locked[i] = false
			continue
		var plan: Dictionary = plans[id]
		state.locked[i] = difficulty.lock and state.rules.has(Ruleset.TRADE) and plan.duplicate and plan.price > state.gold
		if plan.price > state.gold:
			continue
		var score: float = plan.score + rng.randf() * difficulty.shop_noise
		if score > best_score:
			best_score = score
			best = i
	# Permanent wand investments, paid from the same gold as the player's, one
	# level at a time in UPGRADE_ORDER.
	var upgrade_gold: int = difficulty.get("upgrade_gold", profile.upgrade_gold)
	var upgrade_ok: bool = upgrade_gold >= 0 and (best < 0 or state.gold >= upgrade_gold)
	var upgrade := next_upgrade(state)
	if upgrade_ok and state.field_count() >= profile.upgrade_field and upgrade != "" and state.can_buy_upgrade(upgrade):
		var cost := state.upgrade_cost(upgrade)
		state.buy_upgrade(upgrade)
		return {"kind": "upgrade", "id": upgrade, "cost": cost}
	if best >= 0:
		var plan: Dictionary = plans[state.offers[best]]
		if plan.replace:
			var event := {"kind": "sell", "form": weakest.form_id, "cell": weakest.cell, "value": weakest.price()}
			state.sell(weakest)
			return event
		var bought: OwnedCreature
		var target: OwnedCreature = plan.target
		var old_stars := target.stars if target != null else 0
		if not bench_full:
			bought = state.buy(best)
		elif not full:
			var role: String = CreatureDB.get_form(state.offers[best]).role
			bought = state.buy_to_cell(best, state.preferred_free_cell(role))
		elif target.is_fielded():
			bought = state.buy_to_cell(best, target.cell)
		else:
			bought = state.buy_to_slot(best, target.slot)
		if bought != null:
			arrange(state, profile)
			if bench_full and full:
				return {"kind": "merge", "uid": bought.uid, "promoted": bought.stars > old_stars, "cost": plan.price}
			return {"kind": "buy", "uid": bought.uid, "cost": plan.price}
	# Keep enough gold for an eligible offer after paying for the refresh.
	var remaining := state.gold - Rules.REROLL_COST
	var within_difficulty_cap: bool = difficulty.max_rerolls < 0 or state.ai_rerolls < difficulty.max_rerolls
	if within_difficulty_cap and (profile.rerolls < 0 or state.ai_rerolls < profile.rerolls) and remaining >= profile.reroll_reserve and state.can_reroll():
		for plan in plans.values():
			if plan.price <= remaining:
				state.reroll(rng)
				state.ai_rerolls += 1
				return {"kind": "reroll", "cost": Rules.REROLL_COST}
	return {}


## Select by fighting power, preserve a frontline and keep support close enough
## to cover it. Spread ranged units to reduce exposure to 3x3 blizzards.
static func arrange(state: WizardState, profile: Dictionary = {}) -> void:
	if profile.is_empty():
		profile = profile_for(state.ai_level)
	var sorted := state.creatures.duplicate()
	sorted.sort_custom(func(a, b): return field_value(state, a.form_id, a.stars, profile) > field_value(state, b.form_id, b.stars, profile))
	var selected: Array[OwnedCreature] = []
	var roles: Array = ["front", "back"] if Difficulty.profile(state.ai_level).smart_field else []
	for role in roles:
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
		if role == "back" or (role == "front" and profile.spread_front) or profile.has(role + "_cols"):
			var row := state.preferred_row(role)
			for col in profile.get(role + "_cols", [1, 6, 3, 4, 0, 7, 2, 5]):
				var cell := Vector2i(col, row)
				if state.at_cell(cell) == null:
					c.cell = cell
					break
		if not c.is_fielded():
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


## The wand upgrade the AI buys next, or "" once all the introduced ones are maxed.
static func next_upgrade(state: WizardState) -> String:
	for id in UPGRADE_ORDER:
		if state.rules.allows_upgrade(id) and not state.upgrade_maxed(id):
			return id
	return ""


static func _cheapest(state: WizardState) -> OwnedCreature:
	var best: OwnedCreature = null
	for c in state.creatures:
		if best == null or c.price() < best.price():
			best = c
	return best


## Evaluate expected form value using the same visible 55/30/15 distribution
## as the player. Never inspect the next random roll or grant free resources.
static func choose_cast(battle: Battle, team: int, profile: Dictionary = DEFAULT_PROFILE, extra_threshold := 0.0) -> Unit:
	var full := battle.spells[team].charges >= Rules.MAX_CHARGES
	var best: Unit = null
	var best_score: float = (profile.full_cast_threshold if full else profile.cast_threshold) + extra_threshold
	for u in battle.units:
		if not u.alive or u.immune_t > 0.0 or not battle.can_target(team, u):
			continue
		var allied := u.team == team
		if allied and (u.jump_t > 0 or u.dive_target != null or u.charging or u.channel_t > 0.0):
			continue
		var ratio := u.hp / u.max_hp
		var shifted_ratio := minf(1.0, ratio + battle.shift_heal[team]) if allied else ratio
		var power := form_value(u.form_id, u.stars, profile) * Rules.level_mult(u.level)
		var current := power * sqrt(maxf(ratio, 0.05))
		var expected := 0.0
		# An allied cast adds a level; a hex resets the target to level 1.
		var new_level := u.level + 1 if allied else (1 if profile.get("hex_level_reset", false) else u.level)
		for outcome in CreatureDB.outcomes(u.form_id):
			var value := form_value(outcome.id, u.stars, profile) * Rules.level_mult(new_level)
			value *= sqrt(shifted_ratio)
			var d := CreatureDB.get_form(outcome.id)
			if d.range > 2.0 and u.target != null and u.edge_dist(u.target) < Rules.CELL:
				value *= 0.85
			expected += outcome.chance * value
		var score := (expected - current) / maxf(current, 20.0)
		if allied:
			for key in u.statuses:
				if not u.statuses[key].positive:
					score += 0.2
			score += profile.ally_cast_bias
			if ratio < 0.3:
				score += profile.low_health_bonus
			if u.data.has("channel_duration") and u.ability_timer < 0.6:
				score -= 0.35
			if u.shell_t > 0:
				score -= 0.3
		else:
			score = -score + profile.stun_value
			if u.channel_t > 0.0:
				score += profile.interrupt_value
		score *= lerpf(1.0, power / 65.0, profile.target_power_weight)
		if score > best_score:
			best_score = score
			best = u
	return best


## Clumsy cast of easier wizards: any living creature that can be shapeshifted
## (by `team` under the duel's rules, when given).
static func random_cast_target(battle: Battle, team := -1) -> Unit:
	var targets: Array[Unit] = []
	for u in battle.units:
		if u.alive and u.immune_t <= 0.0 and (team < 0 or battle.can_target(team, u)):
			targets.append(u)
	return null if targets.is_empty() else targets[battle.rng.randi_range(0, targets.size() - 1)]
