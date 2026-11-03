extends Node
## Live-combat visual check + victory overlay screenshot.
## Run: Godot --path . -- --livecap

var main: Node2D
var combat: CombatManager


func run(main_ref: Node2D) -> void:
	main = main_ref
	combat = main.combat
	await _wait_real(0.6)
	main.player_ctrl.set_physics_process(false)

	await _capture("10_live_start")
	await _drive(1.6)
	await _capture("11_live_fight")
	await _drive(2.2)
	await _capture("12_live_later")

	var p := combat.player
	for e in combat.enemy_team:
		if e.alive:
			e.take_damage(99999.0, p.global_position, 0.0, 1.0, p)
	await _wait_real(0.6)
	await _capture("13_victory")
	print("LIVECAP state=", combat.state, " time_scale=", Engine.time_scale, " blue=", combat.alive_on_team(0), " red=", combat.alive_on_team(1))


func _drive(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	var p := combat.player
	while Time.get_ticks_msec() < until:
		if not p.alive:
			await get_tree().process_frame
			continue
		var target := p.nearest_opponent()
		if target != null:
			p.set_aim(target.global_position)
			p.move_dir = (target.global_position - p.global_position).normalized()
			p.try_basic_attack()
			p.try_special()
		await get_tree().process_frame
	p.move_dir = Vector2.ZERO


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
