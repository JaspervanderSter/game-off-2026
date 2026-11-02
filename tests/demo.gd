extends Node
## Visual smoke-test / screenshot walkthrough.
## Run: Godot --path . -- --demo
## Writes PNG captures to /tmp/shift_cap_*.png

var main: Node2D
var combat: CombatManager


func run(main_ref: Node2D) -> void:
	print("DEMO: run() entered")
	main = main_ref
	combat = main.combat
	await _wait_real(0.5)
	print("DEMO: staging arena")

	var p: Character = combat.player
	var ally: Character = combat.player_team[1]
	var enemy: Character = combat.enemy_team[0]
	p.global_position = Vector2(710, 520)
	ally.global_position = Vector2(575, 420)
	enemy.global_position = Vector2(930, 470)
	for c in combat.enemy_team:
		if c != enemy:
			c.global_position = Vector2(1080, 360 + float(combat.enemy_team.find(c)) * 120.0)
	main.camera.global_position = p.global_position
	main.camera.reset_smoothing()
	main.hover_override = enemy
	main.ui.set_hovered(enemy)
	get_tree().paused = true
	await _frames(6)
	await _capture("01_arena")

	# Inspector + selection + picker view
	SwapManager.enter_targeting()
	SwapManager.select_char(p)
	main.ui.set_hovered(enemy)
	await _frames(4)
	await _capture("02_selection")

	SwapManager.select_char(enemy)
	await _frames(5)
	await _capture("02b_picker")

	main.ui.picker._on_row_picked("strength")
	await _frames(3)
	await _capture("02c_picker_selected")

	SwapManager.cancel_selection()
	await _frames(3)

	# Cross-team strength steal (triggers enemy counter-swap)
	SwapManager.enter_targeting()
	SwapManager.select_char(p)
	SwapManager.select_char(enemy)
	var ok := SwapManager.confirm_swap("strength")
	print("demo player swap accepted: ", ok)
	await _wait_real(0.22)
	await _capture("03_transfer_start")
	await _wait_real(0.35)
	await _capture("04_transfer_applied")
	await _wait_real(0.9)
	await _capture("05_counter_incoming")
	await _wait_real(0.6)
	await _capture("06_counter_landed")
	await _wait_real(0.8)
	await _capture("07_aftermath")

	print("player strength=", p.get_stat("strength"), " enemy strength=", enemy.get_stat("strength"))
	print("active swaps=", SwapManager.swaps.size())
	for rec in SwapManager.swaps:
		if str(rec.get("owner", "")) == "counter":
			var src: Character = rec["a"]
			print("DEMO counter source=", src.display_name, " attr=", rec["attr"], " target=", (rec["b"] as Character).display_name)
	get_tree().paused = false


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


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
