extends Node
## Unpaused soak test: performs real player swaps, lets the enemy counter-swap,
## and verifies time scale always returns to normal.
## Run: Godot --headless --path . -- --soak

var main: Node2D
var combat: CombatManager


func run(main_ref: Node2D) -> void:
	main = main_ref
	combat = main.combat
	print("=== SHIFT SOAK ===")
	var p := combat.player
	main.player_ctrl.set_physics_process(false)
	p.apply_stat("health", 5000.0, 1.0)
	p.health = 5000.0

	await _wait_real(0.8)
	_try_swap("strength")
	await _wait_real(2.6)
	await _wait_real(3.2)
	_try_swap("speed")
	await _wait_real(3.2)
	await _wait_real(2.8)
	_try_swap("special")

	await _wait_real(1.5)
	print("soak state=", combat.state, " blue=", combat.alive_on_team(0), " red=", combat.alive_on_team(1))
	print("player shifts=", combat.player_shift_count, " counter shifts=", combat.enemy_shift_count)
	print("time_scale=", Engine.time_scale, " active swaps=", SwapManager.swaps.size())
	print("shift ready=", SwapManager.is_shift_ready(), " remaining=", SwapManager.shift_remaining())
	var ok := Engine.time_scale > 0.999
	print("=== SOAK RESULT: ", "PASS" if ok else "FAIL", " ===")
	get_tree().quit(0 if ok else 1)


func _try_swap(attr: String) -> void:
	var p := combat.player
	if not p.alive or not combat.is_playing():
		print("soak: skipped swap (player dead or match over)")
		return
	if not SwapManager.is_shift_ready():
		print("soak: shift not ready yet")
		return
	var target := p.nearest_opponent()
	if target == null:
		print("soak: no target")
		return
	SwapManager.enter_targeting()
	if SwapManager.mode != SwapManager.Mode.SELECT_A:
		print("soak: targeting refused")
		return
	SwapManager.select_char(p)
	SwapManager.select_char(target)
	if SwapManager.mode != SwapManager.Mode.ATTRIBUTE:
		print("soak: selection failed")
		return
	var chosen := ""
	for o in SwapManager.get_attr_options():
		if bool(o["ok"]):
			if str(o["attr"]) == attr:
				chosen = attr
				break
			if chosen == "":
				chosen = str(o["attr"])
	var ok := SwapManager.confirm_swap(chosen)
	print("soak: player swap ", chosen, " with ", target.display_name, " -> ", ok)


func _wait_real(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
