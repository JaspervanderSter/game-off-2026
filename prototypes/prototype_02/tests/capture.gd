extends Node
## Visual smoke test: plays a few scripted steps of the real game and saves
## screenshots to user://captures. Needs a rendering window (not --headless).
##   godot --path . res://tests/capture.tscn
## With -- --check-redraw, also checks after each screenshot that the layers
## which redraw only on change are up to date (see RedrawCheck).

var game: Node
var capture_dir := "user://captures"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(capture_dir)
	PackDeck.save_path = capture_dir.path_join("pack_decks.cfg")
	# Pixel art unless --vector-art asks for the vector art only.
	ArtStyle.save_path = capture_dir.path_join("art_style.cfg")
	ArtStyle.set_style(ArtStyle.Style.VECTOR if "--vector-art" in OS.get_cmdline_user_args() else ArtStyle.Style.PIXEL)
	game =load("res://main.tscn").instantiate()
	add_child(game)
	await _frames(10)
	if "--forest-only" in OS.get_cmdline_user_args():
		await _capture_forest()
		get_tree().quit()
		return
	if "--map-reveal-only" in OS.get_cmdline_user_args():
		await _capture_map_reveal()
		get_tree().quit()
		return
	if "--journey-only" in OS.get_cmdline_user_args():
		await _capture_journey()
		get_tree().quit()
		return
	if "--abandon-only" in OS.get_cmdline_user_args():
		# A replayed duel: the island medallion, hovered, then the confirmation.
		game.difficulty_progress_path = capture_dir.path_join("abandon_progress.cfg")
		game.journey.completed.assign(range(6))
		game.choose_stage(5)
		await _frames(4)
		await _shot("abandon_0_pack")
		game.choose_pack(0)
		await _seconds(1.0)
		get_viewport().warp_mouse(Hud.ABANDON_POS)
		await _frames(4)
		await _shot("abandon_1_hovered")
		game.ask_abandon()
		get_viewport().warp_mouse(Hud.CONFIRM_YES)
		await _frames(4)
		await _shot("abandon_2_confirm")
		get_tree().quit()
		return
	if "--map-icons-only" in OS.get_cmdline_user_args():
		# Every way to the map: the title's medallion and the game-over button.
		game.show_menu(true)
		for i in 5:
			await _seconds(0.6)
			await _shot("title_%d" % i)
		game.show_map()
		await _seconds(0.7)
		await _shot("title_pan")
		await _seconds(1.0)
		await _shot("title_islands")
		game.show_menu()
		await _seconds(1.6)
		await _shot("map_icon_menu")
		game.difficulty_progress_path = capture_dir.path_join("icons_progress.cfg")
		game.choose_stage(0)
		game.choose_pack(0)
		game.enemy.hp = 0.5
		game.battle = Battle.new()
		game.add_child(game.battle)
		game._on_battle_ended({"winner": 0, "survivors": 1})
		game._finish_round()
		await _seconds(1.5)
		await _shot("map_icon_game_over")
		get_tree().quit()
		return
	if "--harvest-lesson-only" in OS.get_cmdline_user_args():
		await _capture_harvest_lesson()
		get_tree().quit()
		return
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
	game._left_press(Hud.reroll_rect().get_center())
	game.shop_out = 0.0
	game.scroll_open = 0.0
	await _seconds(game.SCROLL_UNROLL_TIME * 0.5) # wand scroll halfway unrolled
	await _shot("02c_scroll_unrolling")
	await _seconds(game.SCROLL_UNROLL_TIME)
	game.hover_info = {}
	await _shot("02_prep")
	# The other battlefield environments, then back to the forest.
	for environment in Terrain.ENVIRONMENTS.size():
		game.cycle_environment()
		if game.board_view.environment != Terrain.DEFAULT:
			await _frames(2)
			await _shot("02_prep_" + game.board_view.environment)
	if "--merges-only" in OS.get_cmdline_user_args():
		get_tree().quit()
		return
	if "--rewards-only" in OS.get_cmdline_user_args():
		await _capture_rewards()
		get_tree().quit()
		return
	while game.enemy_preparing:
		await _frames(1)
	# The ready fight button, mid-glint, then hovered.
	while absf(Hud.fight_glint(Time.get_ticks_msec() / 1000.0) - 0.45) > 0.06:
		await _frames(1)
	await _shot("02d_fight_glint")
	get_viewport().warp_mouse(Rules.FIGHT_CENTER)
	await _frames(3)
	await _shot("02e_fight_hover")
	# Each wand upgrade tooltip, mid-scene.
	for i in Rules.WAND_UPGRADES.size():
		get_viewport().warp_mouse(Hud.upgrade_rect(i).get_center())
		await _seconds(1.0)
		await _shot("02f_upgrade_tooltip_%d" % i)
	get_viewport().warp_mouse(Vector2(340, 650))
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
	game._left_press(Hud.upgrade_rect(0).get_center())
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


func _capture_forest() -> void:
	game.difficulty_progress_path = capture_dir.path_join("forest_progress.cfg")
	game.journey.completed.assign(range(Journey.stage_count()))
	for index in 5:
		game.choose_stage(index)
		await _frames(4)
		if index == 0:
			await _shot("forest_00_choices")
		game.choose_pack(0)
		await _seconds(0.8)
		await _shot("forest_%d_preparation" % index)
		if index == 1:
			game.start_combat()
			await _seconds(2.0)
			await _shot("forest_1_cast_hint")
			var ally: Unit = game.battle.living(0)[0]
			game._cast_at(Rules.BOARD_POS + ally.position)
			await _seconds(0.3)
			await _shot("forest_1_transformation")
		game.new_duel()
		await _frames(3)


## The next opponent springing out of the ground on each island, frame by frame:
## the whole map, then a close-up (three times larger) around the opponent.
func _capture_map_reveal() -> void:
	game.difficulty_progress_path = capture_dir.path_join("map_progress.cfg")
	var map: Node2D = game.map_screen
	for stage in [1, 6, 11]:
		game.journey.completed.assign(range(stage))
		game.show_map()
		map.set_process(false)
		# Only `stage` is left to discover, whatever the save already knew.
		map.revealing = -1
		map._pending.clear()
		map.discovered.assign(range(stage))
		map._sync_discovery()
		map.advance_discovery(map.TRACE_DURATION - map.reveal_elapsed)
		var elapsed := 0.0
		for u in [0.04, 0.14, 0.22, 0.3, 0.38, 0.5, 0.62, 0.8, 1.1]:
			map.age += u - elapsed
			map.advance_discovery(u - elapsed)
			elapsed = u
			for index in map.buttons.size():
				map.buttons[index].queue_redraw()
				map.figures[index].queue_redraw()
			await _frames(2)
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			var at: Vector2 = map.get_global_transform_with_canvas() * map.stage_position(stage)
			var region := Rect2i(Vector2i(at) - Vector2i(70, 95), Vector2i(140, 120)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
			var close := image.get_region(region)
			close.resize(region.size.x * 3, region.size.y * 3, Image.INTERPOLATE_NEAREST)
			var path := capture_dir.path_join("map_reveal_%02d_%03d.png" % [stage, roundi(u * 100)])
			close.save_png(path)
			print("saved ", ProjectSettings.globalize_path(path))
		await _shot("map_reveal_%02d_full" % stage)
		map.advance_discovery(map.BURST_DURATION)
		map.set_process(true)


## Every journey opponent's duel as a returning player sees it (rules already
## introduced, lessons done): the composition choice, the preparation and the
## fight, for screen-layout reviews.
func _capture_journey() -> void:
	game.difficulty_progress_path = capture_dir.path_join("journey_progress.cfg")
	for stage in Journey.stage_count():
		game.journey.completed.assign(range(stage))
		for index in Journey.stage_count():
			var rule: String = OpponentDB.get_opponent(index).rule
			if rule != "" and rule not in game.journey.introduced:
				game.journey.introduced.append(rule)
				game.journey.lessons_done.append(rule)
		for lesson in [game.FIGHT_LESSON]:
			if lesson not in game.journey.introduced:
				game.journey.introduced.append(lesson)
				game.journey.lessons_done.append(lesson)
		game.choose_stage(stage)
		await _frames(4)
		if game.phase == game.Phase.PACK:
			await _shot("stage_%02d_0_pack" % (stage + 1))
			game.choose_pack(0)
		await _seconds(0.5)
		while game.enemy_preparing:
			await _frames(1)
		await _seconds(1.2)
		await _shot("stage_%02d_1_prep" % (stage + 1))
		game.start_combat()
		await _seconds(2.5)
		await _shot("stage_%02d_2_combat" % (stage + 1))
		game.new_duel()
		await _frames(3)


## The innkeeper's first harvest: the light follows the coin into the purse.
func _capture_harvest_lesson() -> void:
	game.difficulty_progress_path = capture_dir.path_join("harvest_progress.cfg")
	game.journey.completed.assign(range(6))
	game.journey.introduced.erase(Ruleset.HARVEST)
	game.choose_stage(6)
	game.choose_pack(0)
	game.player.add_creature("peasant")
	await _seconds(0.3)
	while game.enemy_preparing:
		await _frames(1)
	game.start_combat()
	var elapsed := 0.0
	for t in [0.3, 0.9, 1.4, 1.8, 2.1, 2.4, 2.7, 3.1, 3.6]:
		await _seconds(t - elapsed)
		elapsed = t
		await _shot("harvest_lesson_%03d" % roundi(t * 100))


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
	if "--check-redraw" in OS.get_cmdline_user_args():
		var result := await RedrawCheck.run(game)
		if RedrawCheck.is_stale(result):
			print("STALE cached layer at %s near %s (difference %.2f)" % [name, result.where, result.difference])
			result.before.save_png(capture_dir.path_join(name + "_stale_cached.png"))
			result.after.save_png(capture_dir.path_join(name + "_stale_redrawn.png"))
		else:
			print("cached layers up to date at ", name)
