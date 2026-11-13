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
	PackDeck.save_path = capture_dir.path_join("pack_decks.cfg")
	game = load("res://main.tscn").instantiate()
	add_child(game)
	await _frames(10)
	get_viewport().warp_mouse(Hud.difficulty_rect(Difficulty.ADEPT).get_center())
	await _frames(4)
	await _shot("00_difficulty")
	game.choose_difficulty(Difficulty.APPRENTICE)
	await _frames(4)
	await _shot("01_pack")
	if "--packs-only" in OS.get_cmdline_user_args():
		# Every composition card, three per screenshot, the middle one hovered.
		get_viewport().warp_mouse(Hud.pack_rect(1).get_center())
		for page in CreatureDB.PACKS.size() / 3:
			game.offered_packs.assign([page * 3, page * 3 + 1, page * 3 + 2])
			await _frames(4)
			await _shot("pack_cards_%d" % page)
		get_tree().quit()
		return
	game.choose_pack(0)
	if "--balance-only" in OS.get_cmdline_user_args():
		await _capture_balance()
		get_tree().quit()
		return
	if "--preparation-only" in OS.get_cmdline_user_args():
		await _capture_preparation()
		get_tree().quit()
		return
	game.player.gold += 6
	get_viewport().warp_mouse(Vector2(340, 650))
	# Exercise the visible shop additions: a one-star fielded creature, a
	# purchased bench creature, and a locked offer retained across a reroll.
	var first: OwnedCreature = game.player.fielded()[0]
	for i in 2:
		game.player.offers[0] = first.form_id
		game._left_press(Hud.offer_rect(0).get_center())
		game._left_release(Hud.offer_rect(0).get_center())
		var copy: OwnedCreature = game.player.benched()[0]
		game._left_press(Rules.reserve_slot_rect(copy.slot).get_center())
		game._left_release(Rules.BOARD_POS + Rules.cell_center(first.cell))
		await _seconds(0.12)
		await _shot("02a_two_circles" if i == 0 else "02b_manual_star")
	game.player.offers[0] = "archer"
	game._left_press(Hud.offer_rect(0).get_center())
	game._left_release(Hud.offer_rect(0).get_center())
	game._right_press(Hud.offer_rect(1).get_center())
	game._left_press(Hud.REROLL_RECT.get_center())
	await _frames(5)
	game.hover_info = {}
	await _shot("02_prep")
	if "--merges-only" in OS.get_cmdline_user_args():
		get_tree().quit()
		return
	if "--rewards-only" in OS.get_cmdline_user_args():
		await _capture_rewards()
		get_tree().quit()
		return
	while game.enemy_preparing:
		await _frames(1)
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
	await _shot("03_cast")
	if not allies.is_empty() and allies[0].alive:
		get_viewport().warp_mouse(Rules.BOARD_POS + allies[0].position)
		await _frames(3)
		await _shot("03b_hover")
	await _seconds(5.0)
	await _shot("04_combat")
	while game.phase == game.Phase.COMBAT:
		await _frames(5)
	await _frames(20)
	await _shot("05_result")
	await _capture_rewards()
	get_tree().quit()


func _capture_balance() -> void:
	game.set_physics_process(false)
	var player: WizardState = game.player
	var enemy: WizardState = game.enemy
	player.creatures.clear()
	enemy.creatures.clear()
	player.hp = 9.5
	enemy.hp = 8.5
	player.gold = 6
	player.offers = ["assassin", "frost_mage", "guardian"]
	var mage := player.add_creature("frost_mage")
	mage.cell = Vector2i(3, 4)
	var guard := player.add_creature("guardian")
	guard.cell = Vector2i(3, 3)
	var archer := player.add_creature("archer")
	archer.cell = Vector2i(1, 5)
	var enemy_guard := enemy.add_creature("guardian")
	enemy_guard.cell = Vector2i(3, 2)
	var priest := enemy.add_creature("cleric")
	priest.cell = Vector2i(4, 0)
	var enemy_archer := enemy.add_creature("archer")
	enemy_archer.cell = Vector2i(1, 0)
	game.enemy_preparing = false
	game.enemy_moves.clear()
	game.enemy_action.clear()
	get_viewport().warp_mouse(Vector2(340, 650))
	await _frames(3)
	await _shot("20_half_hearts_and_upgrade_offer")
	game._left_press(Hud.SHIFT_UPGRADE_RECT.get_center())
	await _shot("21_recharge_upgrade_owned")
	game.start_combat()
	for u in game.battle.living(0):
		if u.form_id == "frost_mage":
			u.ability_timer = 0
			u._tick_ability()
	var rabbit: Unit = game.battle.spawn(0, "rabbit", Vector2(550, 350))
	rabbit.tick(0.01)
	rabbit._tick_jump(0.25)
	game.battle._projectile_layer.queue_redraw()
	await _frames(3)
	await _shot("22_blizzard_and_backline_leap")
	game.set_process(false)
	game.hover_info = {"owned": guard, "form": "guardian", "team": 0, "pos": Vector2(980, 180)}
	await _shot("23_weighted_outcomes")


func _capture_preparation() -> void:
	game.set_physics_process(false)
	var player: WizardState = game.player
	var enemy: WizardState = game.enemy
	player.creatures.clear()
	enemy.creatures.clear()
	var target := player.add_creature("guardian")
	target.merge_copies = 2
	player.add_creature("cleric")
	enemy.add_creature("guardian")
	player.gold = 10
	enemy.gold = 6
	player.offers = ["guardian", "cleric", "archer"]
	enemy.offers = ["archer", "cleric", "guardian"]
	get_viewport().warp_mouse(Vector2(340, 650))
	await _frames(3)
	await _shot("10_idle_no_merge_circles")
	game._advance_enemy_preparation(0.35)
	game._advance_enemy_preparation(0.15)
	await _shot("11_enemy_spending_and_placing")
	get_viewport().warp_mouse(Rules.BOARD_POS + Rules.cell_center(target.cell))
	await _frames(3)
	game.set_process(false)
	game.hover_info = {"owned": target, "form": target.form_id, "team": 0,
		"pos": Rules.BOARD_POS + Rules.cell_center(target.cell)}
	await _shot("12_hover_merge_progress")
	game.hover_info = {}
	game.set_process(true)
	game._left_press(Hud.offer_rect(0).get_center())
	var destination := Rules.BOARD_POS + Rules.cell_center(Vector2i(4, 3))
	get_viewport().warp_mouse(destination)
	var motion := InputEventMouseMotion.new()
	motion.position = destination
	game._unhandled_input(motion)
	await _frames(3)
	await _shot("13_shop_drag_compatible_progress")
	game._left_release(destination)
	get_viewport().warp_mouse(Vector2(340, 650))
	await _frames(3)
	await _shot("14_direct_purchase_idle")
	player.hp = 3
	game.hud.set_process(false)
	game._on_battle_ended({"winner": 1, "survivors": 3})
	game.hud.advance_loss_rewards(1.08)
	await _shot("15_lethal_loss_no_coin_reward")


func _capture_rewards() -> void:
	# Deterministic close-up sequence of a three-heart loss and its gold reward.
	game.set_physics_process(false)
	game.hud.set_process(false)
	game.player.hp = 7
	game.player.gold = 5
	game._on_battle_ended({"winner": 1, "survivors": 3})
	game.hud.advance_loss_rewards(0.30)
	await _frames(2)
	await _shot("06_heart_impact")
	game.hud.advance_loss_rewards(0.40)
	await _frames(2)
	await _shot("07_coin_flight")
	game.hud.advance_loss_rewards(0.38)
	await _frames(2)
	await _shot("08_coin_arrival")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := capture_dir.path_join(name + ".png")
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
