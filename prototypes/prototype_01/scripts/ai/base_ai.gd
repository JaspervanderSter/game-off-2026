class_name BaseAI
extends Node
## Shared combat AI. Teammates leash to the player; enemies roam freely.
## The AI uses whatever special ability is currently equipped, including
## abilities acquired through swaps.

var character: Character
var combat: CombatManager
var target: Character
var player_ref: Character = null
var leash_to_player := false

var think_timer: float = 0.0
var strafe_timer: float = 0.0
var strafe_dir: float = 1.0
var special_timer: float = 0.0
var formation_offset := Vector2.ZERO

var _rng := RandomNumberGenerator.new()


func setup(c: Character, combat_ref: CombatManager, leash: bool, p_ref: Character) -> void:
	character = c
	combat = combat_ref
	leash_to_player = leash
	player_ref = p_ref
	_rng.randomize()
	formation_offset = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(55.0, 130.0)
	strafe_dir = -1.0 if _rng.randf() < 0.5 else 1.0
	strafe_timer = _rng.randf_range(0.6, 1.6)
	special_timer = _rng.randf_range(0.25, 0.9)


func _physics_process(delta: float) -> void:
	if character == null or not is_instance_valid(character) or not character.alive:
		return
	if combat == null or not combat.is_playing():
		character.move_dir = Vector2.ZERO
		return

	think_timer -= delta
	strafe_timer -= delta
	special_timer -= delta

	if target == null or not is_instance_valid(target) or not target.alive:
		_rethink()
	if think_timer <= 0.0:
		_rethink()
		think_timer = _rng.randf_range(0.15, 0.3)

	if strafe_timer <= 0.0:
		strafe_dir *= -1.0
		strafe_timer = _rng.randf_range(0.7, 1.9)

	if target == null:
		if leash_to_player and is_instance_valid(player_ref) and player_ref.alive:
			var anchor := player_ref.global_position + formation_offset
			var to_anchor := anchor - character.global_position
			character.move_dir = _avoidance(to_anchor).normalized() if to_anchor.length() > 26.0 else Vector2.ZERO
			character.set_aim(character.global_position + character.aim_dir * 40.0)
		else:
			character.move_dir = Vector2.ZERO
		return

	var to_target := target.global_position - character.global_position
	var dist := to_target.length()
	var aim_pos := target.global_position
	if not character.is_melee():
		aim_pos += target.velocity * 0.09
	character.set_aim(aim_pos)

	# Teammates fall back toward the player if they are chasing too far.
	if leash_to_player and is_instance_valid(player_ref) and player_ref.alive:
		var d_player := character.global_position.distance_to(player_ref.global_position)
		if dist > 430.0 and d_player > 290.0:
			var anchor := player_ref.global_position + formation_offset
			var to_anchor := anchor - character.global_position
			if to_anchor.length() > 26.0:
				character.move_dir = _avoidance(to_anchor).normalized()
			else:
				character.move_dir = Vector2.ZERO
			_try_attacks(dist)
			return

	var desired := character.radius + target.radius + 12.0
	if not character.is_melee():
		desired = 235.0

	var move := Vector2.ZERO
	if dist > desired + 28.0:
		move = to_target.normalized()
	elif dist < desired - 46.0:
		move = -to_target.normalized()
	else:
		move = to_target.normalized().orthogonal() * strafe_dir
		move += to_target.normalized() * clampf((desired - dist) * 0.02, -0.3, 0.3)

	if target.shield_time > 0.0 and not character.is_melee() and dist < 120.0:
		move -= to_target.normalized()

	move = _avoidance(move)
	character.move_dir = move.normalized() if move.length() > 0.01 else Vector2.ZERO
	_try_attacks(dist)


func _rethink() -> void:
	var best: Character = null
	var best_score := INF
	for o_v in character.get_living_opponents():
		var o: Character = o_v
		var d: float = character.global_position.distance_to(o.global_position)
		var score: float = d - (1.0 - o.health_pct()) * 220.0
		if o.is_player:
			score -= 35.0
		if score < best_score:
			best_score = score
			best = o
	target = best


func _avoidance(move: Vector2) -> Vector2:
	var steer := move
	for ally in character.get_living_allies():
		var delta_pos: Vector2 = character.global_position - ally.global_position
		var d := delta_pos.length()
		if d > 0.1 and d < 72.0:
			steer += delta_pos.normalized() * (1.0 - d / 72.0) * 1.3

	var margin := 90.0
	var p := character.global_position
	var r: Rect2 = GameConfig.arena_rect
	if p.x < r.position.x + margin:
		steer.x += (r.position.x + margin - p.x) / margin
	if p.x > r.end.x - margin:
		steer.x -= (p.x - (r.end.x - margin)) / margin
	if p.y < r.position.y + margin:
		steer.y += (r.position.y + margin - p.y) / margin
	if p.y > r.end.y - margin:
		steer.y -= (p.y - (r.end.y - margin)) / margin
	return steer


func _try_attacks(dist: float) -> void:
	var basic_range := 70.0
	var ba := character.current_basic()
	if ba != null:
		basic_range = ba.range
	if dist <= basic_range + target.radius + 4.0:
		character.try_basic_attack()

	if special_timer <= 0.0 and character.special_cd <= 0.05:
		if _should_use_special(dist):
			if character.try_special():
				special_timer = _rng.randf_range(0.55, 1.35)


func _should_use_special(dist: float) -> bool:
	var ability: Ability = character.current_ability()
	if ability == null:
		return false
	match ability.id:
		"ground_slam":
			var r := float(GameConfig.ability_def("ground_slam").get("radius", 120.0))
			return character.count_opponents_within(r) >= 2 or (dist < 90.0 and target.health_pct() < 0.65)
		"dash":
			return dist > 65.0 and dist < 265.0
		"shield":
			return character.health_pct() < 0.55 or character.count_opponents_within(150.0) >= 2
		"multishot":
			return dist < 400.0
		"blink":
			return (dist > 120.0 and dist < 270.0) or character.count_opponents_within(90.0) >= 2
	return false
