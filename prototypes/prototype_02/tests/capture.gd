extends Node
## Visual smoke test: plays a few scripted steps of the real game and saves
## screenshots to user://captures. Needs a rendering window (not --headless).
##   godot --path . res://tests/capture.tscn

var game: Node
var capture_dir := "user://captures"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(capture_dir)
	game = load("res://main.tscn").instantiate()
	add_child(game)
	await _frames(10)
	_shot("01_pack")
	game.choose_pack(0)
	game.player.gold += 6
	# Exercise the visible shop additions: a two-star fielded creature, a
	# purchased bench creature, and a locked offer retained across a reroll.
	var first: OwnedCreature = game.player.fielded()[0]
	for i in 2:
		game.player.offers[0] = first.form_id
		game._left_press(Hud.offer_rect(0).get_center())
	game.player.offers[0] = "archer"
	game._left_press(Hud.offer_rect(0).get_center())
	game._right_press(Hud.offer_rect(1).get_center())
	game._left_press(Hud.REROLL_RECT.get_center())
	await _frames(5)
	game.hover_info = {}
	_shot("02_prep")
	game.start_combat()
	await _seconds(2.0)
	# Cast on the first ally and the first enemy.
	game.battle.spells[0].charges = 3
	var allies: Array = game.battle.living(0)
	var foes: Array = game.battle.living(1)
	if not allies.is_empty():
		game.battle.cast(0, allies[0])
	if not foes.is_empty():
		game.battle.cast(0, foes[0])
	await _frames(12)
	_shot("03_cast")
	if not allies.is_empty() and allies[0].alive:
		get_viewport().warp_mouse(Rules.BOARD_POS + allies[0].position)
		await _frames(3)
		_shot("03b_hover")
	await _seconds(5.0)
	_shot("04_combat")
	while game.phase == game.Phase.COMBAT:
		await _frames(5)
	await _frames(20)
	_shot("05_result")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := capture_dir.path_join(name + ".png")
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
