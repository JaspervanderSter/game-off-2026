extends Node2D

var world: Node2D
var combat: CombatManager
var ui: GameUI
var camera: Camera2D
var player_ctrl: PlayerController

var shake_amount: float = 0.0
var _last_usec: int = 0
var hover_override: Character = null


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_min_size(Vector2i(900, 600))

	SwapManager.reset_all()
	TimeManager.reset()
	Fx.reset()
	_last_usec = Time.get_ticks_usec()

	_build_arena()

	world = Node2D.new()
	world.name = "Actors"
	add_child(world)

	combat = CombatManager.new()
	combat.name = "Combat"
	add_child(combat)
	combat.setup(self, world)
	SwapManager.match_active = true

	_build_camera()

	ui = GameUI.new()
	add_child(ui)
	ui.setup(combat, self)

	player_ctrl = PlayerController.new()
	add_child(player_ctrl)
	player_ctrl.setup(combat.player, combat, ui)

	Fx.shake_requested.connect(_on_shake_requested)

	if OS.get_cmdline_user_args().has("--selftest"):
		_run_selftest()
	elif OS.get_cmdline_user_args().has("--restarttest"):
		_run_restarttest()
	elif OS.get_cmdline_user_args().has("--demo"):
		_run_demo()
	elif OS.get_cmdline_user_args().has("--livecap"):
		_run_livecap()
	elif OS.get_cmdline_user_args().has("--soak"):
		_run_soak()
	elif OS.get_cmdline_user_args().has("--sizetest"):
		_run_sizetest()


func _build_arena() -> void:
	_add_wall(Rect2(-80, -80, 1760, 80))
	_add_wall(Rect2(-80, 1000, 1760, 80))
	_add_wall(Rect2(-80, 0, 80, 1000))
	_add_wall(Rect2(1600, 0, 80, 1000))


func _add_wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	shape.position = rect.position + rect.size * 0.5
	body.add_child(shape)
	add_child(body)


func _build_camera() -> void:
	camera = Camera2D.new()
	camera.name = "ArenaCamera"
	camera.zoom = Vector2(0.8, 0.8)
	camera.position_smoothing_enabled = false
	add_child(camera)
	camera.make_current()
	camera.global_position = GameConfig.arena_rect.get_center()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var rdt := clampf(float(now - _last_usec) / 1_000_000.0, 0.0, 0.1)
	_last_usec = now

	if camera != null and combat != null:
		_update_camera_framing()
		if shake_amount > 0.0:
			shake_amount = maxf(0.0, shake_amount - rdt * 60.0)
			camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_amount
		else:
			camera.offset = Vector2.ZERO

	_update_hover()


func _update_camera_framing() -> void:
	var minp := Vector2(INF, INF)
	var maxp := Vector2(-INF, -INF)
	var any_alive := false
	for n in get_tree().get_nodes_in_group("characters"):
		if n is Character and n.alive:
			any_alive = true
			var p: Vector2 = n.global_position
			minp.x = minf(minp.x, p.x)
			minp.y = minf(minp.y, p.y)
			maxp.x = maxf(maxp.x, p.x)
			maxp.y = maxf(maxp.y, p.y)

	if not any_alive:
		minp = GameConfig.arena_rect.position
		maxp = GameConfig.arena_rect.end

	var bbox := Rect2(minp, maxp - minp).grow(80.0)
	var vp := Vector2(1280, 720)
	if ui != null and ui.hud != null and ui.hud.size.x > 1.0:
		vp = ui.hud.size
	elif get_viewport_rect().size.x > 1.0:
		vp = get_viewport_rect().size

	var margin_x := 70.0
	var margin_top := 150.0
	var margin_bottom := 90.0
	var avail := Vector2(
		maxf(240.0, vp.x - margin_x * 2.0),
		maxf(160.0, vp.y - margin_top - margin_bottom)
	)
	var z := minf(avail.x / maxf(1.0, bbox.size.x), avail.y / maxf(1.0, bbox.size.y))
	z = clampf(z, 0.30, 1.30)

	var desired_screen_center := Vector2(vp.x * 0.5, margin_top + avail.y * 0.5)
	var shift := (desired_screen_center - vp * 0.5) / z

	camera.zoom = Vector2(z, z)
	camera.global_position = bbox.get_center() - shift


func _update_hover() -> void:
	if ui == null:
		return
	if hover_override != null and is_instance_valid(hover_override):
		SwapManager.hovered = hover_override
		ui.set_hovered(hover_override)
		return
	var screen_mouse := get_viewport().get_mouse_position()
	if ui.is_ui_at_screen(screen_mouse):
		SwapManager.hovered = null
		ui.set_hovered(null)
		return
	var mouse_world := get_global_mouse_position()
	var best: Character = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("characters"):
		if not (n is Character):
			continue
		var c: Character = n
		if not c.alive:
			continue
		var d := mouse_world.distance_to(c.global_position)
		if d <= c.radius + 15.0 and d < best_d:
			best_d = d
			best = c
	SwapManager.hovered = best
	ui.set_hovered(best)


func _pick_character(world_pos: Vector2) -> Character:
	var best: Character = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("characters"):
		if not (n is Character):
			continue
		var c: Character = n
		if not c.alive:
			continue
		var d := world_pos.distance_to(c.global_position)
		if d <= c.radius + 16.0 and d < best_d:
			best_d = d
			best = c
	return best


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if SwapManager.is_selecting():
			if event.button_index == MOUSE_BUTTON_LEFT:
				if ui != null and ui.is_ui_at_screen(event.position):
					return
				var c := _pick_character(get_global_mouse_position())
				if c != null:
					SwapManager.select_char(c)
				else:
					SwapManager.notice.emit("NO TARGET UNDER CURSOR", Palette.WARN)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				SwapManager.cancel_selection()
		elif SwapManager.mode == SwapManager.Mode.ATTRIBUTE:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				SwapManager.cancel_selection()


func _on_shake_requested(amount: float) -> void:
	shake_amount = maxf(shake_amount, amount)


func _run_selftest() -> void:
	await get_tree().process_frame
	var script: GDScript = load("res://tests/selftest.gd")
	var runner: Node = script.new()
	add_child(runner)
	var code: int = await runner.run(combat)
	get_tree().quit(code)


func _run_demo() -> void:
	print("DEMO: starting runner")
	await get_tree().process_frame
	var script: GDScript = load("res://tests/demo.gd")
	var runner: Node = script.new()
	add_child(runner)
	await runner.run(self)
	print("DEMO: finished")
	get_tree().quit(0)


func _run_livecap() -> void:
	await get_tree().process_frame
	var script: GDScript = load("res://tests/livecap.gd")
	var runner: Node = script.new()
	add_child(runner)
	await runner.run(self)
	get_tree().quit(0)


func _run_soak() -> void:
	await get_tree().process_frame
	var script: GDScript = load("res://tests/soak.gd")
	var runner: Node = script.new()
	add_child(runner)
	await runner.run(self)


func _run_sizetest() -> void:
	await get_tree().process_frame
	var script: GDScript = load("res://tests/sizetest.gd")
	var runner: Node = script.new()
	add_child(runner)
	await runner.run(self)
	get_tree().quit(0)


func _run_restarttest() -> void:
	if get_tree().has_meta("shift_restart_done"):
		print("RESTART TEST: new scene ready. time_scale=", Engine.time_scale, " mode=", SwapManager.mode, " swaps=", SwapManager.swaps.size(), " shift_ready=", SwapManager.is_shift_ready())
		await get_tree().create_timer(0.6, true, false, true).timeout
		print("RESTART TEST: after 0.6s time_scale=", Engine.time_scale, " state=", combat.state, " swaps=", SwapManager.swaps.size())
		get_tree().quit(0)
		return
	await get_tree().create_timer(0.4, true, false, true).timeout
	var p := combat.player
	var e: Character = combat.enemy_team[0]
	SwapManager.enter_targeting()
	SwapManager.select_char(p)
	SwapManager.select_char(e)
	SwapManager.confirm_swap("strength")
	await get_tree().create_timer(0.15, true, false, true).timeout
	print("RESTART TEST: reloading during slowmo time_scale=", Engine.time_scale)
	get_tree().set_meta("shift_restart_done", true)
	combat.restart()


# ---------------------------------------------------------------------------
# Arena visuals
# ---------------------------------------------------------------------------
func _draw() -> void:
	var r: Rect2 = GameConfig.arena_rect
	var center := r.get_center()

	draw_rect(Rect2(-5000, -5000, 12000, 12000), Palette.BG)
	draw_rect(r, Palette.ARENA)

	# Team side washes
	draw_rect(Rect2(r.position.x, r.position.y, 220.0, r.size.y), Color(Palette.PLAYER, 0.032))
	draw_rect(Rect2(r.end.x - 220.0, r.position.y, 220.0, r.size.y), Color(Palette.ENEMY, 0.032))

	# Grid
	var x := 0
	while x <= int(r.size.x):
		var col := Palette.GRID_STRONG if x % 400 == 0 else Palette.GRID
		draw_line(Vector2(r.position.x + x, r.position.y), Vector2(r.position.x + x, r.end.y), col, 1.0)
		x += 80
	var y := 0
	while y <= int(r.size.y):
		var col := Palette.GRID_STRONG if y % 400 == 0 else Palette.GRID
		draw_line(Vector2(r.position.x, r.position.y + y), Vector2(r.end.x, r.position.y + y), col, 1.0)
		y += 80

	# Center emblem
	draw_circle(center, 215.0, Color(Palette.EDGE_BRIGHT, 0.018))
	draw_arc(center, 148.0, 0, TAU, 80, Color(Palette.PANEL_EDGE, 0.55), 1.5, true)
	draw_arc(center, 126.0, 0, TAU, 80, Color(Palette.PANEL_EDGE, 0.3), 1.0, true)
	draw_line(center + Vector2(-200, 0), center + Vector2(200, 0), Color(Palette.PANEL_EDGE, 0.3), 1.0)
	draw_line(center + Vector2(0, -200), center + Vector2(0, 200), Color(Palette.PANEL_EDGE, 0.3), 1.0)

	var font := ThemeDB.fallback_font
	draw_string(font, center + Vector2(-160, -14), "SHIFT", HORIZONTAL_ALIGNMENT_CENTER, 320, 52, Color(Palette.EDGE_BRIGHT, 0.07))

	# Corner brackets
	var bracket := 46.0
	var inset := 18.0
	for corner in [
		Vector2(r.position.x + inset, r.position.y + inset),
		Vector2(r.end.x - inset, r.position.y + inset),
		Vector2(r.position.x + inset, r.end.y - inset),
		Vector2(r.end.x - inset, r.end.y - inset),
	]:
		var sx := 1.0 if corner.x < center.x else -1.0
		var sy := 1.0 if corner.y < center.y else -1.0
		draw_line(corner, corner + Vector2(bracket * sx, 0), Color(Palette.EDGE_BRIGHT, 0.35), 2.0, true)
		draw_line(corner, corner + Vector2(0, bracket * sy), Color(Palette.EDGE_BRIGHT, 0.35), 2.0, true)

	# Border
	draw_rect(r, Palette.ARENA_EDGE, false, 3.0)
	draw_rect(r.grow(5.0), Color(Palette.EDGE_BRIGHT, 0.22), false, 1.0)
