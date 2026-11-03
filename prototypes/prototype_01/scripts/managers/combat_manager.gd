class_name CombatManager
extends Node

enum State { PLAYING, VICTORY, DEFEAT }

var state: int = State.PLAYING
var player_team: Array = []
var enemy_team: Array = []
var player: Character
var world: Node2D
var main: Node2D
var counter_ai: CounterSwapAI

var player_shift_count: int = 0
var enemy_shift_count: int = 0
var kill_count: int = 0


func setup(main_ref: Node2D, world_ref: Node2D) -> void:
	main = main_ref
	world = world_ref
	_spawn_teams()

	counter_ai = CounterSwapAI.new()
	add_child(counter_ai)
	counter_ai.setup(self)

	for c in player_team + enemy_team:
		c.died.connect(_on_character_died)
	SwapManager.swap_started.connect(_on_swap_started)


func _spawn(archetype: String, team: int, is_player_char: bool, display: String, pos: Vector2) -> Character:
	var c := Character.new()
	c.setup(archetype, team, is_player_char, display)
	world.add_child(c)
	c.global_position = pos
	return c


func _spawn_teams() -> void:
	player = _spawn("Runner", Character.TEAM_PLAYER, true, "VECTOR", Vector2(380, 500))
	player_team.append(player)
	SwapManager.set_player(player)

	player_team.append(_spawn("Tank", Character.TEAM_PLAYER, false, "BULWARK", Vector2(300, 360)))
	player_team.append(_spawn("Ranger", Character.TEAM_PLAYER, false, "VESPER", Vector2(300, 640)))
	player_team.append(_spawn("Trickster", Character.TEAM_PLAYER, false, "JINX", Vector2(480, 700)))

	enemy_team.append(_spawn("Bruiser", Character.TEAM_ENEMY, false, "CRUSHER", Vector2(1220, 500)))
	enemy_team.append(_spawn("Tank", Character.TEAM_ENEMY, false, "AEGIS", Vector2(1300, 360)))
	enemy_team.append(_spawn("Ranger", Character.TEAM_ENEMY, false, "LONGSHOT", Vector2(1300, 640)))
	enemy_team.append(_spawn("Trickster", Character.TEAM_ENEMY, false, "SHADE", Vector2(1120, 700)))

	for c in player_team:
		if c.is_player:
			continue
		var ai := AllyAI.new()
		c.add_child(ai)
		ai.setup_ally(c, self, player)
		c.controller = ai

	for c in enemy_team:
		var ai := EnemyAI.new()
		c.add_child(ai)
		ai.setup_enemy(c, self)
		c.controller = ai


func is_playing() -> bool:
	return state == State.PLAYING


func alive_on_team(team: int) -> int:
	var arr: Array = player_team if team == Character.TEAM_PLAYER else enemy_team
	var n := 0
	for c in arr:
		if is_instance_valid(c) and c.alive:
			n += 1
	return n


func team_array(team: int) -> Array:
	return player_team if team == Character.TEAM_PLAYER else enemy_team


func _on_character_died(c: Character) -> void:
	kill_count += 1
	if c == player and alive_on_team(Character.TEAM_PLAYER) > 0 and is_playing():
		SwapManager.notice.emit("YOU ARE DOWN — SPECTATING", Palette.WARN)
	_check_match_end()


func _on_swap_started(rec: Dictionary) -> void:
	match str(rec.get("owner", "")):
		"player":
			player_shift_count += 1
		"counter":
			enemy_shift_count += 1


func _check_match_end() -> void:
	if state != State.PLAYING:
		return
	if alive_on_team(Character.TEAM_ENEMY) == 0:
		state = State.VICTORY
		_finish_match()
	elif alive_on_team(Character.TEAM_PLAYER) == 0:
		state = State.DEFEAT
		_finish_match()


func _finish_match() -> void:
	SwapManager.match_active = false
	SwapManager.cancel_selection()
	TimeManager.reset()
	for c in player_team + enemy_team:
		if is_instance_valid(c):
			c.move_dir = Vector2.ZERO
	Fx.shake(0.0)
	var center := GameConfig.arena_rect.get_center()
	Fx.ring(center, Palette.SWAP, 40.0, 380.0, 1.2, 2.0)


func restart() -> void:
	TimeManager.reset()
	SwapManager.reset_all()
	Fx.reset()
	get_tree().reload_current_scene()
