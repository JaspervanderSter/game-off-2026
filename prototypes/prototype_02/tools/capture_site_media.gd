extends SceneTree
## Reproducible website media from the live game, in the default pixel style.
## Run with --write-movie=<temporary .avi> --fixed-fps 60 and -- --output-dir=<dir>.
## No player settings or decks are changed; use a temporary user-data directory.

var output_dir := ""
var game: Node


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="):
			output_dir = arg.trim_prefix("--output-dir=")
	if output_dir.is_empty():
		push_error("Pass --output-dir=<temporary directory>")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	ArtStyle.save_path = output_dir.path_join("art_style.cfg")
	PackDeck.save_path = output_dir.path_join("pack_decks.cfg")
	ArtStyle.set_style(ArtStyle.Style.PIXEL)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.difficulty_progress_path = output_dir.path_join("difficulty.cfg")
	game.rng.seed = 20261120
	await _frames(12)
	game.unlocked_difficulty = Difficulty.ADEPT
	game.choose_difficulty(Difficulty.ADEPT)
	game.offered_packs.assign([1, 2, 8])
	game.choose_pack(0)
	game.enemy_preparing = false
	game.enemy_action.clear()
	game.enemy_moves.clear()
	game.round_num = 4
	game.player.creatures.clear()
	game.enemy.creatures.clear()
	var player_forms := ["guardian", "berserker", "spearman", "archer", "cleric", "bard"]
	var enemy_forms := ["guardian", "duelist", "assassin", "crossbowman", "frost_mage", "pyromancer"]
	var player_cells := [Vector2i(2, 3), Vector2i(4, 3), Vector2i(5, 4), Vector2i(1, 5), Vector2i(3, 5), Vector2i(6, 5)]
	var enemy_cells := [Vector2i(2, 2), Vector2i(4, 2), Vector2i(6, 2), Vector2i(1, 0), Vector2i(3, 0), Vector2i(5, 0)]
	for i in 6:
		var ally: OwnedCreature = game.player.add_creature(player_forms[i])
		ally.cell = player_cells[i]
		var foe: OwnedCreature = game.enemy.add_creature(enemy_forms[i])
		foe.cell = enemy_cells[i]
		# Durable enough to show several casts in one continuous recording.
		ally.stars = 1
		foe.stars = 1
	game.player.add_creature("pyromancer")
	game.player.add_creature("archer")
	game.player.gold = 8
	game.enemy.gold = 6
	game.player.offers.assign(["guardian", "archer", "pyromancer"])
	game.player.locked.assign([false, true, false])
	root.warp_mouse(Vector2(320, 680))
	await _frames(48)
	await _shot("preparation")
	print("MEDIA preparation frame=60")
	await _frames(60)
	game.start_combat()
	if game.battle == null:
		push_error("Website capture could not start combat")
		quit(1)
		return
	game.battle.rng.seed = 20261120
	for frame in 900:
		if game.phase == game.Phase.COMBAT:
			if frame == 240:
				game.battle.spells[0].charges = 3
				var allies: Array = game.battle.living(0)
				var enemies: Array = game.battle.living(1)
				for ally in allies:
					if ally.immune_t <= 0.0:
						game.battle.cast(0, ally)
						break
				for foe in enemies:
					if foe.immune_t <= 0.0:
						game.battle.cast(0, foe)
						break
				print("MEDIA shapeshift frame=360")
			if frame == 480:
				var targets: Array = game.battle.living(1)
				if not targets.is_empty():
					# Exercise the real death presentation without waiting for a duel end.
					game.battle.damage(null, targets[0], 100000.0, "ability")
					print("MEDIA exit frame=600")
		await _frames(1)
	await _shot("combat")
	print("Website media capture complete")
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output_dir.path_join(name + ".png"))
	if error != OK:
		push_error("Cannot save %s: %s" % [name, error_string(error)])
		quit(1)
