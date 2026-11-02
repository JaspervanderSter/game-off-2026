extends Node
## Window-scaling + camera-framing visual test.
## Run: Godot --path . -- --sizetest

var main: Node2D
var combat: CombatManager


func run(main_ref: Node2D) -> void:
	main = main_ref
	combat = main.combat
	await _wait_real(0.6)
	await _report("initial")
	await _capture("30_initial")

	# Buttons must remain interactive while the picker pauses combat.
	SwapManager.enter_targeting()
	SwapManager.select_char(combat.player)
	SwapManager.select_char(combat.enemy_team[0])
	print("PAUSE button open paused=", get_tree().paused, " mode=", SwapManager.mode)
	await _wait_real(0.1)
	var row_press := InputEventMouseButton.new()
	row_press.button_index = MOUSE_BUTTON_LEFT
	row_press.pressed = true
	row_press.position = Vector2(400, 289)
	Input.parse_input_event(row_press)
	var row_release := InputEventMouseButton.new()
	row_release.button_index = MOUSE_BUTTON_LEFT
	row_release.pressed = false
	row_release.position = Vector2(400, 289)
	Input.parse_input_event(row_release)
	await _wait_real(0.15)
	print("PAUSE row selected=", main.ui.picker.selected_attr)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(336, 528)
	Input.parse_input_event(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(336, 528)
	Input.parse_input_event(release)
	await _wait_real(0.15)
	print("PAUSE after cancel button paused=", get_tree().paused, " mode=", SwapManager.mode, " time=", Engine.time_scale)
	if SwapManager.mode != SwapManager.Mode.IDLE:
		SwapManager.cancel_selection()

	DisplayServer.window_set_size(Vector2i(1600, 900))
	await _wait_real(0.7)
	await _report("1600x900")
	await _capture("31_1600x900")

	DisplayServer.window_set_size(Vector2i(1500, 1000))
	await _wait_real(0.7)
	await _report("1500x1000")
	await _capture("32_1500x1000")

	SwapManager.enter_targeting()
	print("HOLD targeting time_scale=", Engine.time_scale)
	SwapManager.select_char(combat.player)
	SwapManager.select_char(combat.enemy_team[0])
	print("PAUSE picker paused=", get_tree().paused, " mode=", SwapManager.mode)
	var player_before := combat.player.global_position
	await _wait_real(0.3)
	print("PAUSE world moved=", player_before.distance_to(combat.player.global_position), " paused=", get_tree().paused)
	await _capture("32b_picker_1500x1000")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await _wait_real(0.2)
	print("PAUSE after ESC paused=", get_tree().paused, " mode=", SwapManager.mode, " time=", Engine.time_scale)
	if SwapManager.mode != SwapManager.Mode.IDLE:
		SwapManager.cancel_selection()

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	await _wait_real(1.2)
	await _report("fullscreen")
	await _capture("33_fullscreen")

	var p := combat.player
	var e: Character = combat.enemy_team[0]
	SwapManager.enter_targeting()
	SwapManager.select_char(p)
	SwapManager.select_char(e)
	print("PAUSE before confirm paused=", get_tree().paused, " mode=", SwapManager.mode)
	var ok := SwapManager.confirm_swap("strength")
	print("PAUSE after confirm paused=", get_tree().paused, " time=", Engine.time_scale, " swap=", ok)
	await _wait_real(0.25)
	await _report("slowmo")
	await _capture("34_slowmo")

	var start_positions := {}
	for n in get_tree().get_nodes_in_group("characters"):
		if n is Character and n.alive:
			start_positions[n] = n.global_position
	var t0 := Time.get_ticks_msec()
	await _wait_real(0.30)
	var elapsed := float(Time.get_ticks_msec() - t0) / 1000.0
	var max_move := 0.0
	for n in start_positions.keys():
		if is_instance_valid(n):
			max_move = maxf(max_move, (start_positions[n] as Vector2).distance_to(n.global_position))
	print("SLOWMOVE max displacement=", max_move, " px over ", elapsed, "s real, time_scale=", Engine.time_scale)

	await _wait_real(1.1)
	await _report("after-slowmo")
	await _capture("35_after")

	get_tree().quit(0)


func _report(tag: String) -> void:
	var hud_size: Vector2 = main.ui.hud.size
	var vp := main.get_viewport_rect().size
	var zoom: Vector2 = main.camera.zoom
	var view := hud_size / zoom
	var cam: Vector2 = main.camera.global_position
	var left := cam.x - view.x * 0.5
	var top := cam.y - view.y * 0.5
	var minx := INF
	var maxx := -INF
	var miny := INF
	var maxy := -INF
	var outside := 0
	for n in get_tree().get_nodes_in_group("characters"):
		if n is Character and n.alive:
			var ch: Character = n
			var sx: float = (ch.global_position.x - left) * zoom.x
			var sy: float = (ch.global_position.y - top) * zoom.y
			minx = minf(minx, sx)
			maxx = maxf(maxx, sx)
			miny = minf(miny, sy)
			maxy = maxf(maxy, sy)
			if sx < 0.0 or sy < 0.0 or sx > hud_size.x or sy > hud_size.y:
				outside += 1
			if tag == "fullscreen":
				var in_player: bool = main.ui.hud._player_rect().has_point(Vector2(sx, sy))
				print("   char ", ch.display_name, " screen=", Vector2(sx, sy), " under_player_hud=", in_player)
	print("SIZETEST [", tag, "] window=", DisplayServer.window_get_size(), " vp=", vp, " hud=", hud_size, " zoom=", zoom.x, " time=", Engine.time_scale)
	print("          screen x=", minx, "..", maxx, " y=", miny, "..", maxy, " outside=", outside)


func _wait_real(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _capture(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "/tmp/shift_cap_%s.png" % tag
	var err := img.save_png(path)
	print("CAPTURE ", tag, " -> ", path, " (err ", err, ")")
