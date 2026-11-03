class_name CounterSwapAI
extends Node
## Enemy-team SHIFT response. Triggered once for every player swap that crosses
## teams. The targeted enemy is always the one that counters, stealing a
## different attribute from a living player-team member.

var combat: CombatManager
var _pending := false


func setup(combat_ref: CombatManager) -> void:
	combat = combat_ref


func _ready() -> void:
	SwapManager.swap_started.connect(_on_swap_started)


func _on_swap_started(rec: Dictionary) -> void:
	if _pending:
		return
	if str(rec.get("owner", "")) != "player":
		return
	if not SwapManager.match_active:
		return
	var a: Character = rec["a"]
	var b: Character = rec["b"]
	if not is_instance_valid(a) or not is_instance_valid(b):
		return
	if a.team == b.team:
		return
	var source_enemy: Character = null
	if a.team == Character.TEAM_ENEMY:
		source_enemy = a
	elif b.team == Character.TEAM_ENEMY:
		source_enemy = b
	if source_enemy == null:
		return
	_schedule(str(rec["attr"]), source_enemy)


func _schedule(excluded_attr: String, source_enemy: Character) -> void:
	_pending = true
	SwapManager.notice.emit("%s COUNTER-SHIFT INBOUND…" % source_enemy.display_name, Palette.ENEMY)
	await get_tree().create_timer(GameConfig.counter_swap_delay, true, false, true).timeout
	_pending = false
	if not is_inside_tree():
		return
	if combat == null or not combat.is_playing():
		return
	if not SwapManager.match_active:
		return
	if not is_instance_valid(source_enemy) or not source_enemy.alive:
		SwapManager.notice.emit("TARGETED ENEMY LOST — NO COUNTER", Palette.MUTED)
		return

	var plan := choose_counter(excluded_attr, source_enemy)
	if plan.is_empty():
		SwapManager.notice.emit("%s HAD NO COUNTER" % source_enemy.display_name, Palette.MUTED)
		return
	SwapManager.perform_swap(plan["a"], plan["b"], str(plan["attr"]), "counter", true)


func choose_counter(excluded_attr: String, source_enemy: Character) -> Dictionary:
	if source_enemy == null or not is_instance_valid(source_enemy) or not source_enemy.alive:
		return {}

	var targets: Array = []
	for n in get_tree().get_nodes_in_group("characters"):
		if n is Character and n.alive and n.team == Character.TEAM_PLAYER:
			targets.append(n)

	var best: Dictionary = {}
	var best_score := 0.2

	for b in targets:
		if b == source_enemy:
			continue
		for attr in GameConfig.ATTRS:
			if attr == excluded_attr:
				continue
			if SwapManager.has_conflict(source_enemy, b, attr):
				continue
			var score := _score_swap(source_enemy, b, attr)
			if score > best_score:
				best_score = score
				best = {"a": source_enemy, "b": b, "attr": attr, "score": score}
	return best


func _score_swap(a: Character, b: Character, attr: String) -> float:
	var va: Variant = a.get_stat(attr)
	var vb: Variant = b.get_stat(attr)
	var ua_old := _utility(a, attr, va)
	var ua_new := _utility(a, attr, vb)
	var ub_old := _utility(b, attr, vb)
	var ub_new := _utility(b, attr, va)

	var score := 0.0
	if a.team == Character.TEAM_ENEMY:
		score += ua_new - ua_old
	else:
		score += ua_old - ua_new
	if b.team == Character.TEAM_ENEMY:
		score += ub_new - ub_old
	else:
		score += ub_old - ub_new

	# Favouring high-impact exchanges makes the counter feel deliberate.
	if attr == "special" or attr == "basic":
		score *= 1.15
	elif attr == "strength" or attr == "speed":
		score *= 1.05

	# Stable tie-break, not a random pick.
	score += randf() * 0.015
	return score


func _utility(c: Character, attr: String, value: Variant) -> float:
	if value == null:
		return 0.0
	var hp := c.health_pct()
	match attr:
		"speed":
			return float(value) * (1.0 + (1.0 - hp) * 0.35)
		"strength":
			return float(value) * (1.3 if c.is_melee() else 0.85)
		"weight":
			return float(value) * (0.5 + (1.0 - hp) * 0.5) * (1.15 if c.is_melee() else 0.85)
		"health":
			return (float(value) / 30.0) * (1.0 + (1.0 - hp) * 0.6)
		"attack_cooldown":
			return (1.0 / maxf(0.2, float(value))) * 3.4 * (0.8 + float(c.stats.current["strength"]) * 0.04)
		"special_cooldown":
			return (1.0 / maxf(1.0, float(value))) * 30.0
		"special":
			return _ability_fit(c, value) * 6.0 + 0.6
		"basic":
			return _basic_fit(c, value) * 6.0 + 0.6
	return 0.0


func _ability_fit(c: Character, ability: Variant) -> float:
	if not (ability is Ability):
		return 0.0
	var d: Dictionary = GameConfig.ability_def((ability as Ability).id)
	var fit: Dictionary = d.get("fit", {})
	return float(fit.get(c.archetype, 0.4))


func _basic_fit(c: Character, basic: Variant) -> float:
	if not (basic is BasicAttack):
		return 0.0
	var fit: Dictionary = (basic as BasicAttack).fit
	return float(fit.get(c.archetype, 0.4))
