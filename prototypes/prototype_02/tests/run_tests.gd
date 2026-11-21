extends Node
## Headless rule tests and combat simulations for Prototype 02.
## Run from prototypes/prototype_02:
##   godot --headless --path . res://tests/run_tests.tscn

var _failures := 0
var _checks := 0


func _ready() -> void:
	# Games created by the tests deal from scratch decks, never the player's.
	PackDeck.save_path = "user://pack_decks_test_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
	# Nor do they read or change the player's art style.
	ArtStyle.save_path = "user://art_style_test_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
	ArtStyle.reload()
	# Nor the player's sound set.
	SoundSet.save_path = "user://sound_set_test_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
	SoundSet.reload()
	SoundSet.apply()
	# Art-style checks instantiate the game, which also loads the sound set.
	_test_art_style()
	_test_sound_set()
	_test_shape_atlas()
	_test_terrain()
	_test_network()
	_test_charges()
	_test_transformation_rules()
	_test_immunity_and_invalid_casts()
	_test_economy()
	_test_shop_and_merges()
	_test_starting_packs()
	_test_preparation_input()
	_test_loss_gold()
	_test_peasant_harvest()
	_test_fight_layout_animation()
	_test_round_frieze()
	_test_shop_drag_and_enemy_preparation()
	_test_phase_music()
	preload("res://tests/audio_workspace_tests.gd").run(self, check)
	_test_result_recordings()
	_test_sound_files()
	_test_round_reset_and_damage()
	_test_frenzy()
	_test_abilities()
	_test_animal_roles()
	_test_mage_attacks()
	_test_crossbow_bolts()
	_test_mage_interruptions()
	_test_bard_song()
	_test_overlapping_blizzards()
	_test_combat_click_casts()
	_test_blizzard_and_recharge_upgrade()
	_test_ai_strategy()
	_test_difficulty()
	_test_journey_rules()
	_test_forest_lessons()
	_test_rule_spotlight()
	_test_learning_pause()
	_test_learning_cue_spares_tank()
	_test_abandon_replay()
	_test_screen_transition()
	_test_screen_layout()
	_test_merge_lesson_and_full_board()
	_test_scroll_shows_introduced_upgrades()
	_test_day_night_cycle()
	_test_journey_health()
	_test_journey_discovery()
	await _test_progress_reset_shortcuts()
	await _test_journey_navigation()
	_simulate_duels()
	DirAccess.remove_absolute(PackDeck.save_path)
	print("\n%d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: " + label)


## The atlas file the game loads matches the shapes drawn by Shapes.build_image
## (run tools/make_shapes_atlas.gd after changing them).
func _test_shape_atlas() -> void:
	var drawn := Shapes.build_image()
	var texture: Texture2D = load(Shapes.ATLAS_FILE)
	check(texture != null, "shape atlas file loads")
	if texture == null:
		return
	check(texture.get_image().has_mipmaps(), "shape atlas is imported with mipmaps")
	var saved: Image = texture.get_image().duplicate()
	saved.clear_mipmaps()
	saved.convert(Image.FORMAT_RGBA8)
	check(saved.get_size() == drawn.get_size(), "shape atlas file has the drawn size")
	if saved.get_size() != drawn.get_size():
		return
	var a := saved.get_data()
	var b := drawn.get_data()
	var worst := 0
	for i in range(3, a.size(), 4):
		worst = maxi(worst, absi(a[i] - b[i]))
	check(worst <= 1, "shape atlas file matches Shapes.build_image (max alpha difference %d)" % worst)


## Every environment's tiles load as cell-sized images and compose a board in
## which touching cells of a family never repeat a drawing or a rare detail.
func _test_terrain() -> void:
	for environment: String in Terrain.ENVIRONMENTS:
		var set := Terrain.tiles(environment)
		check(set.has("light"), "%s has light tiles" % environment)
		var plain := Terrain._commonest(set.get("light", {}), Terrain.ENVIRONMENTS[environment].kinds)
		for family: String in set:
			check(set[family].get(plain, []).size() >= 5, "%s has five plain %s drawings, so neighbours never repeat" % [environment, family])
			for kind: String in set[family]:
				check(Terrain.ENVIRONMENTS[environment].kinds.has(kind), "%s tile kind %s has a weight" % [environment, kind])
				for path: String in set[family][kind]:
					var image = load(path)
					check(image is Image, "%s is imported as an Image" % path)
					if image is Image:
						check(image.get_size() == Vector2i(Rules.CELL, Rules.CELL), "%s is one cell in size" % path)
		var grid := Terrain.layout(environment, 7)
		check(grid == Terrain.layout(environment, 7), "%s layout is deterministic" % environment)
		check(grid != Terrain.layout(environment, 8), "%s layout changes with the seed" % environment)
		check(grid.size() == Rules.ROWS and grid[0].size() == Rules.COLS, "%s layout covers the board" % environment)
		var repeats := 0
		var rare_neighbours := 0
		var kinds := {}
		for y in Rules.ROWS:
			for x in Rules.COLS:
				var path: String = grid[y][x]
				var family := "light" if (x + y) % 2 == 0 or not set.has("dark") else "dark"
				check(path.get_file().begins_with(family + "-"), "%s cell %d,%d follows the checker" % [environment, x, y])
				var kind := path.get_file().split("-")[1]
				kinds[kind] = kinds.get(kind, 0) + 1
				for n: Vector2i in [Vector2i(x + 1, y + 1), Vector2i(x - 1, y + 1), Vector2i(x + 2, y), Vector2i(x, y + 2)]:
					if n.x >= 0 and n.x < Rules.COLS and n.y < Rules.ROWS and grid[n.y][n.x] == path:
						repeats += 1
				for n: Vector2i in [Vector2i(x + 1, y), Vector2i(x, y + 1), Vector2i(x + 1, y + 1), Vector2i(x - 1, y + 1)]:
					if n.x >= 0 and n.x < Rules.COLS and n.y < Rules.ROWS:
						var other: String = grid[n.y][n.x].get_file().split("-")[1]
						if other == kind and kind != plain:
							rare_neighbours += 1
		check(repeats == 0, "%s never repeats a drawing on touching cells (%d)" % [environment, repeats])
		check(rare_neighbours == 0, "%s never puts rare details side by side (%d)" % [environment, rare_neighbours])
		if environment == "forest":
			check(kinds.get("grass", 0) > Rules.ROWS * Rules.COLS / 2 and kinds.has("clover"),
				"the forest is mostly plain grass with some clover %s" % kinds)
		var board := Terrain.board_image(environment, 7)
		check(board.get_size() == Vector2i(Rules.BOARD_SIZE), "%s board image has the board size" % environment)
		check(board.get_pixel(1, 1).a == 1.0 and board.get_pixelv(Vector2i(Rules.BOARD_SIZE) - Vector2i.ONE).a == 1.0,
			"%s board image is fully covered" % environment)
		for tint: Color in Terrain.ENVIRONMENTS[environment].tints:
			check(tint.r <= 1.0 and tint.g <= 1.0 and tint.b <= 1.0, "%s tints only darken" % environment)
	check(Terrain.ENVIRONMENTS.has(Terrain.DEFAULT), "the default environment exists")
	check(Terrain.ENVIRONMENTS.keys() == ["forest", "town", "school"], "the three battlefield environments")


func _test_art_style() -> void:
	check(ArtStyle.current() == ArtStyle.Style.PIXEL, "the game starts in the pixel art style")
	check(ArtStyle.sprite_name("archer", 0) == "Archer-B" and ArtStyle.sprite_name("archer", 1) == "Archer-A",
		"blue player sprites end in -B, red enemy sprites in -A")
	check(ArtStyle.sprite_name("frost_mage", 0) == "FrostMage-B", "sprite names are the ids in PascalCase")
	check(ArtStyle.has_sprite("crossbowman", 1), "the crossbowman uses the artist's Crossbow sprite")
	for path in ArtStyle._paths.values():
		var name: String = path.get_file().get_basename()
		var known := false
		for id in CreatureDB.all_ids():
			for team in 2:
				known = known or ArtStyle.sprite_name(id, team) == name
		check(known, "sprite %s matches a creature and a team" % path)

	var sprite := ArtStyle.creature_texture("archer", 0)
	check(sprite != null and sprite.get_size() == Vector2(64, 64), "the pixel style loads the archer sprite")
	for id in CreatureDB.all_ids():
		if not ArtStyle.has_sprite(id, 0):
			check(ArtStyle.creature_texture(id, 0) == null, "creatures without a sprite keep the vector art")
			break

	check(ArtStyle.toggle() == ArtStyle.Style.VECTOR, "the toggle switches to the vector art")
	check(ArtStyle.creature_texture("archer", 0) == null, "the vector style draws no sprites")
	ArtStyle.reload()
	check(not ArtStyle.is_pixel(), "the vector art choice survives a restart")
	check(ArtStyle.toggle() == ArtStyle.Style.PIXEL, "the toggle switches back to the pixel art")
	ArtStyle.reload()
	check(ArtStyle.is_pixel(), "the pixel art choice survives a restart")

	# The in-game shortcut switches the style and back.
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	var key := InputEventKey.new()
	key.keycode = KEY_P
	key.ctrl_pressed = true
	key.shift_pressed = true
	key.pressed = true
	game._input(key)
	check(not ArtStyle.is_pixel(), "Ctrl+Shift+P switches to the vector art")
	game._input(key)
	check(ArtStyle.is_pixel(), "Ctrl+Shift+P switches back to the pixel art")
	game.queue_free()
	DirAccess.remove_absolute(ArtStyle.save_path)
	ArtStyle.reload()


func _test_sound_set() -> void:
	check(not SoundSet.is_legacy() and Sfx.overlay() == "", "the game starts with the current sound effects")
	var current_hits := Sfx.files_of("combat/hit").size()
	var current_click: float = Sfx.files_of("ui/click")[0].get_length()
	for file in _files_under(SoundSet.LEGACY_DIR):
		var event := file.trim_prefix(SoundSet.LEGACY_DIR).trim_suffix(".import").get_basename()
		check(Sfx.event_paths().has(event), "earlier sound %s belongs to a current event" % file)

	check(SoundSet.toggle() == SoundSet.Set.LEGACY and Sfx.overlay() == SoundSet.LEGACY_DIR,
		"the toggle lays the earlier sounds over the current ones")
	var click: float = Sfx.files_of("ui/click")[0].get_length()
	check(current_hits == 3 and Sfx.files_of("combat/hit").size() == 1, "the earlier sounds had a single hit take")
	check(not is_equal_approx(click, current_click), "the earlier click replaces the current one")
	check(is_equal_approx(Sfx.files_of("ui/battle_start")[0].get_length(), click)
		and is_equal_approx(Sfx.files_of("ui/place")[0].get_length(), click)
		and is_equal_approx(float(Sfx.setting("ui/battle_start", "pitch_jitter")), 0.08),
		"starting a fight and placing a creature play the earlier click")
	check(is_equal_approx(Sfx.files_of("ui/purchase_confirmed")[0].get_length(), Sfx.files_of("ui/buy")[0].get_length())
		and is_equal_approx(Sfx.files_of("ui/insufficient_gold")[0].get_length(), Sfx.files_of("ui/fail")[0].get_length()),
		"purchases play the earlier buy sound and missing gold the earlier fail sound")
	SoundSet.reload()
	check(SoundSet.is_legacy(), "the earlier sounds choice survives a restart")

	# The in-game shortcut switches the set and back.
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	check(Sfx.overlay() == SoundSet.LEGACY_DIR, "the game applies the saved sound set on start")
	var key := InputEventKey.new()
	key.keycode = KEY_S
	key.ctrl_pressed = true
	key.shift_pressed = true
	key.pressed = true
	game._input(key)
	check(not SoundSet.is_legacy() and Sfx.files_of("combat/hit").size() == current_hits,
		"Ctrl+Shift+S switches back to the current sounds")
	game._input(key)
	check(SoundSet.is_legacy() and Sfx.files_of("combat/hit").size() == 1, "Ctrl+Shift+S switches to the earlier sounds")
	game.queue_free()
	SoundSet.set_set(SoundSet.Set.CURRENT)
	DirAccess.remove_absolute(SoundSet.save_path)
	SoundSet.reload()


## Buys every wand upgrade level for free, so AI shop tests see no upgrade left.
func _max_upgrades(state: WizardState) -> void:
	for id in Rules.WAND_UPGRADES:
		state.upgrades[id] = Rules.WAND_UPGRADE_COSTS[id].size()


func _new_battle() -> Battle:
	var b := Battle.new()
	add_child(b)
	b.ai_casting = [false, false]
	b.rng.seed = 7
	return b


# --- Network ----------------------------------------------------------------------

func _test_network() -> void:
	var ids := CreatureDB.all_ids()
	check(ids.size() == 24, "24 forms")
	var fantasy := 0
	for id in ids:
		check(CreatureDB.FORMS.has(id), "form data for " + id)
		if CreatureDB.FORMS[id].family == "fantasy":
			fantasy += 1
		var outs := CreatureDB.outcomes(id)
		check(outs.size() == 3, "3 outcomes for " + id)
		var total := 0.0
		for o in outs:
			total += o.chance
			check(CreatureDB.FORMS[o.id].family != CreatureDB.FORMS[id].family, "cross-roster link " + id + ">" + o.id)
			for back in CreatureDB.outcomes(o.id):
				check(back.id != id, "no direct reverse " + id + "<>" + o.id)
		check(absf(total - 1.0) < 0.0001, "chances sum to 1 for " + id)
	check(fantasy == 12, "12 fantasy forms")
	# Every form reaches every other; shortest return is 8 casts.
	for id in ids:
		var dist := {id: 0}
		var frontier: Array = [id]
		var return_len := -1
		while not frontier.is_empty() and return_len < 0:
			var next: Array = []
			for f in frontier:
				for o in CreatureDB.outcomes(f):
					if o.id == id and return_len < 0:
						return_len = dist[f] + 1
					if not dist.has(o.id):
						dist[o.id] = dist[f] + 1
						next.append(o.id)
			frontier = next
		check(dist.size() == 24, "all forms reachable from " + id)
		check(return_len == 8, "shortest return of 8 for " + id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var counts := {}
	for i in 3000:
		var r := CreatureDB.roll_outcome("peasant", rng)
		counts[r] = counts.get(r, 0) + 1
	for o in CreatureDB.outcomes("peasant"):
		check(absf(counts.get(o.id, 0) / 3000.0 - o.chance) < 0.04, "roll distribution " + o.id)


# --- Spell ----------------------------------------------------------------------------

func _test_charges() -> void:
	var s := ShiftSpell.new()
	check(s.charges == 1, "start with one charge")
	_tick(s, 2.99)
	check(s.charges == 1, "no charge before 3 s")
	_tick(s, 0.02)
	check(s.charges == 2, "two charges at 3 s")
	_tick(s, 3.0)
	check(s.charges == 3, "three charges at 6 s")
	_tick(s, 10.0)
	check(s.charges == 3 and s.recharge == 0.0, "capped at three, timer stopped")
	s.consume()
	s.consume()
	s.consume()
	_tick(s, 1.5)
	check(absf(s.recharge - 1.5) < 0.05, "recharge running")
	_tick(s, 7.45)
	check(s.charges == 2, "two charges just before nine seconds")
	_tick(s, 0.1)
	check(s.charges == 3, "zero to three in nine seconds")
	# A cast during a running recharge keeps the timer.
	s = ShiftSpell.new()
	s.charges = 2
	_tick(s, 1.5)
	s.consume()
	check(absf(s.recharge - 1.5) < 0.05, "cast does not reset recharge timer")


func _tick(s: ShiftSpell, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.00001:
		var dt := minf(0.01, seconds - t)
		s.tick(dt)
		t += dt


func _test_transformation_rules() -> void:
	var b := _new_battle()
	var ally := b.spawn(0, "guardian", Vector2(100, 300))
	var foe := b.spawn(1, "archer", Vector2(400, 50), 0, 1)
	b.spells[0].charges = 3
	ally.hp = ally.max_hp * 0.5
	ally.attack_timer = 1.0
	ally.add_status("poisoned", 3.0, 5.0, false)
	ally.add_status("inspired", 2.0, 0.35, true)
	ally.ability_timer = 2.5
	check(b.cast(0, ally), "cast on ally succeeds")
	check(ally.form_id in ["rabbit", "turtle", "deer"], "guardian becomes a stage-2 animal")
	check(ally.level == 2, "ally cast grants +1 level")
	check(absf(ally.max_hp - ally.data.hp * 1.2) < 0.01, "level 2 max HP is x1.2 base")
	check(absf(ally.hp / ally.max_hp - 0.6) < 0.001, "50% health becomes 60%")
	check(ally.attack_timer == 0.0, "attack readied")
	check(not ally.statuses.has("poisoned"), "negative status cleansed")
	check(ally.statuses.has("inspired"), "positive status kept")
	check(absf(ally.ability_timer - 2.5) < 0.001, "ability cooldown carried over")
	check(absf(ally.attack_damage() - ally.data.dmg * 1.2) < 0.01, "level scales basic damage")
	foe.level = 3
	foe.max_hp = foe.data.hp * foe.stat_mult()
	foe.hp = foe.max_hp * 0.5
	foe.attack_timer = 1.5
	foe.add_status("poisoned", 3.0, 5.0, false)
	check(b.cast(0, foe), "cast on enemy succeeds")
	check(foe.level == 1 and foe.stars == 1, "enemy cast resets temporary levels and preserves stars")
	check(is_equal_approx(foe.max_hp, foe.data.hp * 1.8) and is_equal_approx(foe.attack_damage(), foe.data.dmg * 1.8),
		"enemy cast recalculates max health and damage at level 1 with stars")
	check(is_equal_approx(foe.hp / foe.max_hp, 0.5), "enemy cast preserves health percentage without healing")
	check(foe.attack_timer == 1.5 and foe.statuses.has("poisoned"), "enemy cast preserves attack cooldown and debuffs")
	check(foe.stun_t == 3.0, "enemy cast stuns for three seconds")
	var start_pos := foe.position
	var start_hp := foe.hp
	foe.tick(0.75)
	check(foe.position == start_pos and foe.target == null, "stunned enemy cannot move or act")
	check(foe.attack_timer == 0.75 and foe.hp < start_hp, "attack recharge and poison continue during the stun")
	foe.tick(2.0)
	check(foe.stun_t == 0.25 and foe.position == start_pos, "enemy remains still just before three seconds")
	foe.tick(0.5)
	check(foe.stun_t == 0.0 and foe.position != start_pos, "enemy resumes movement when the stun expires")
	# Entering a form with a ready-on-entry cooldown does not get an instant ability.
	var fresh := b.spawn(0, "peasant", Vector2(200, 300))
	fresh.ability_timer = 0.0
	b.spells[0].charges = 3
	b.cast(0, fresh)
	check(fresh.ability_timer == (0.0 if fresh.data.ability == "hop" else float(fresh.data.get("cd", 0.0))), "rabbit leap is immediate; other ability cooldowns carry over")
	b.queue_free()
	_test_ally_shift_effects()


## Positive post-transformation effects trigger only on a shapeshift by the
## creature's own wizard.
func _test_ally_shift_effects() -> void:
	var b := _new_battle()
	var blessed := b.spawn(0, "peasant", Vector2(100, 400))
	blessed.ability_timer = 0.0
	blessed.transform_to("rabbit", true)
	check(blessed.ability_timer == 0.0, "ally shift into rabbit readies its leap at once")
	var hexed := b.spawn(1, "peasant", Vector2(500, 40))
	hexed.ability_timer = 0.0
	hexed.transform_to("rabbit", false)
	check(is_equal_approx(hexed.ability_timer, CreatureDB.get_form("rabbit").cd), "enemy shift into rabbit gives no immediate leap")
	b.free()

	# Skunk: nearby enemies stop attacking and flee in a zigzag for 2 s.
	b = _new_battle()
	var skunk := b.spawn(0, "spearman", Vector2(300, 300))
	var near := b.spawn(1, "guardian", Vector2(300, 250))
	var mage := b.spawn(1, "pyromancer", Vector2(260, 250))
	var far := b.spawn(1, "archer", Vector2(300, 30))
	var friend := b.spawn(0, "peasant", Vector2(340, 300))
	mage.ability_timer = 0.0
	mage._tick_ability()
	check(mage.channel_t > 0.0, "pyromancer starts channeling before the skunk shift")
	skunk.transform_to("skunk", true)
	check(near.statuses.has("feared") and is_equal_approx(near.statuses.feared.t, 2.0), "ally shift into skunk fears a nearby enemy for 2 s")
	check(not far.statuses.has("feared") and not friend.statuses.has("feared"), "skunk fear spares distant enemies and allies")
	check(mage.statuses.has("feared") and mage.channel_t == 0.0 and mage.ability_timer == mage.data.cd,
		"skunk fear interrupts Fireball and starts its cooldown")
	near.attack_timer = 0.0
	var start_d := near.position.distance_to(skunk.position)
	var hp_before := skunk.hp
	var xs: Array[float] = []
	for i in 30:
		near.tick(1.0 / 60.0)
		xs.append(near.position.x)
	check(near.position.distance_to(skunk.position) > start_d and skunk.hp == hp_before and near.attack_timer == 0.0,
		"feared enemy runs away without attacking")
	var turns := 0
	for i in range(2, xs.size()):
		if signf(xs[i] - xs[i - 1]) != signf(xs[i - 1] - xs[i - 2]):
			turns += 1
	check(turns >= 1, "feared enemy flees in a zigzag")
	near._tick_statuses(1.6)
	check(not near.statuses.has("feared"), "fear expires after 2 s")
	b.free()

	b = _new_battle()
	var cursed := b.spawn(1, "spearman", Vector2(300, 300))
	var bystander := b.spawn(0, "guardian", Vector2(300, 350))
	cursed.transform_to("skunk", false)
	check(not bystander.statuses.has("feared"), "enemy shift into skunk causes no fear")
	b.free()


func _test_immunity_and_invalid_casts() -> void:
	var b := _new_battle()
	var u := b.spawn(0, "archer", Vector2(100, 300))
	b.spawn(1, "archer", Vector2(400, 50))
	b.spells[0].charges = 3
	b.spells[1].charges = 3
	check(b.cast(0, u), "first cast")
	check(not b.cast(0, u), "immune target rejected")
	check(not b.cast(1, u), "immunity applies to both wizards")
	check(b.spells[0].charges == 2, "invalid cast consumed no charge")
	for i in 290:
		b.step(0.01)
	check(u.immune_t > 0.0, "still immune before 3 s")
	for i in 20:
		b.step(0.01)
	check(u.immune_t == 0.0, "immunity ends after 3 s")
	b.spells[0].charges = 0
	check(not b.cast(0, u), "no charge, no cast")
	b.casting_enabled = false
	b.spells[0].charges = 3
	check(not b.cast(0, u), "no-spell mode blocks casts")
	b.queue_free()


# --- Economy and rounds ---------------------------------------------------------------

func _test_economy() -> void:
	check(Rules.income(1) == 3 and Rules.income(2) == 4 and Rules.income(5) == 7, "income 3, 4, 5...")
	var s := WizardState.new(0)
	var rng := RandomNumberGenerator.new()
	s.refresh_offers(rng)
	check(s.offers.size() == 3, "three offers")
	for id in s.offers:
		check(CreatureDB.FORMS[id].family == "fantasy", "shop sells fantasy forms only")
	s.offers = ["peasant", "crossbowman", "guardian"]
	s.gold = 3
	check(s.buy(1) != null and s.gold == 0, "buy a 3-gold creature")
	check(s.buy(1) == null, "each offer bought once")
	check(s.buy(0) == null, "cannot buy without gold")
	var c: OwnedCreature = s.creatures[0]
	s.sell(c)
	check(s.gold == 3 and s.creatures.is_empty(), "sell for purchase price")
	s.gold = 100
	for i in 12:
		s.add_creature("peasant")
	check(s.field_count() == 6 and s.benched().size() == 6, "6 fielded + 6 reserve")
	check(s.add_creature("peasant") == null and not s.has_space(), "capacity reached")
	var benched: OwnedCreature = s.benched()[0]
	var empty_cell := Vector2i(-1, -1)
	for y in Rules.team_rows(0):
		for x in Rules.COLS:
			if s.at_cell(Vector2i(x, y)) == null:
				empty_cell = Vector2i(x, y)
	check(not s.move_to_cell(benched, empty_cell), "field cap blocks a 7th creature")
	var fielded: OwnedCreature = s.fielded()[0]
	fielded.form_id = "guardian" # unlike forms still swap instead of combining
	var cell := fielded.cell
	check(s.move_to_cell(benched, cell) and benched.cell == cell and not fielded.is_fielded(), "swap bench and field")
	check(not s.move_to_cell(fielded, Vector2i(0, 0)), "cannot place in the enemy half")


func _test_shop_and_merges() -> void:
	var s := WizardState.new(0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	s.gold = 100
	s.offers = ["peasant", "archer", "cleric"]
	var bought := s.buy(0)
	check(bought != null and not bought.is_fielded() and bought.slot == 0,
		"purchase goes to bench even with an empty board")
	check(s.field_count() == 0, "purchase never auto-fields")
	check(s.toggle_lock(1), "right-click can lock an offer")
	var gold := s.gold
	check(s.reroll(rng) and s.gold == gold - Rules.REROLL_COST, "reroll charges exactly once")
	check(s.offers[0] != "" and s.offers[1] == "archer" and s.offers[2] != "cleric",
		"reroll fills sold slots, changes unlocked offers and keeps locks")
	s.refresh_offers(rng)
	check(s.offers[1] == "archer" and s.locked[1], "locks persist into next round")
	s.toggle_lock(0)
	s.toggle_lock(2)
	gold = s.gold
	check(not s.reroll(rng) and s.gold == gold, "all locked prevents paid no-op reroll")
	s.buy(1)
	check(not s.locked[1] and s.offers[1] == "", "buying clears the offer lock")
	s.gold = 0
	var offers := s.offers.duplicate()
	check(not s.reroll(rng) and s.offers == offers, "no gold means no reroll")
	check(not s.toggle_lock(1), "empty offer cannot be locked")

	# Buying never combines copies, even if a matching pair is already owned.
	var m := WizardState.new(0)
	m.gold = 100
	m.offers = ["cleric", "cleric", "cleric"]
	var first := m.buy(0)
	var second := m.buy(1)
	var third := m.buy(2)
	check(m.creatures.size() == 3 and first.stars == 0, "three purchases stay separate until manual merge")
	m.move_to_cell(first, Vector2i(3, 3))
	check(m.move_to_cell(second, first.cell), "drop on matching board creature combines copies")
	check(first.merge_copies == 2 and first.stars == 0 and second not in m.creatures,
		"two copies fill two circles without earning a star")
	check(first.price() == CreatureDB.get_form("cleric").price * 2, "partial group preserves resale value")
	var partial := _new_battle()
	var normal_unit := partial.spawn(0, "cleric", Vector2(50, 300))
	var teams_partial: Array[WizardState] = [m, WizardState.new(1)]
	partial.setup(teams_partial, 1)
	var grouped: Unit = partial.living(0)[1]
	check(grouped.merge_copies == 2 and grouped.max_hp == normal_unit.max_hp and grouped.attack_damage() == normal_unit.attack_damage(),
		"partial grouping persists into combat but gives no health or damage bonus")
	partial.free()
	check(m.move_to_cell(third, first.cell) and first.stars == 1 and first.merge_copies == 1,
		"third manually dropped copy earns one star and resets circles")
	check(first.cell == Vector2i(3, 3) and m.creatures.size() == 1, "manual merge preserves chosen recipient cell")
	var next := m.add_creature("cleric")
	next.stars = 1
	var last := m.add_creature("cleric")
	last.stars = 1
	m.merge(next, first)
	check(first.stars == 1 and first.merge_copies == 2, "two one-star copies stay at one star")
	m.merge(last, first)
	check(first.stars == 2 and first.merge_copies == 1 and first.price() == 18, "three one-star copies earn second star with conserved value")
	for i in 2:
		var copy := m.add_creature("cleric")
		copy.stars = 2
		m.merge(copy, first)
	check(first.stars == 3 and first.price() == 54, "27 base copies earn third star")
	var capped := m.add_creature("cleric")
	capped.stars = 3
	check(not m.merge(capped, first) and first.stars == 3, "three-star creatures cannot combine")
	check(not m.merge(first, first), "self-drop cannot duplicate merge material")

	var overflow := WizardState.new(0)
	var recipient := overflow.add_creature("guardian")
	var source := overflow.add_creature("guardian")
	recipient.merge_copies = 2
	source.merge_copies = 2
	var source_cell := source.cell
	var target_cell := recipient.cell
	var invested := source.price() + recipient.price()
	check(overflow.move_to_cell(source, target_cell), "two partial groups can combine")
	check(recipient.stars == 1 and recipient.merge_copies == 1 and source.stars == 0 and source.merge_copies == 1,
		"overflow leaves unconsumed material at its original rank")
	check(source.cell == source_cell and recipient.cell == target_cell and source.price() + recipient.price() == invested,
		"overflow keeps source location and all invested value")
	var other_form := overflow.add_creature("cleric")
	check(not overflow.merge(other_form, recipient) and not overflow.merge(source, recipient), "different forms and different ranks cannot combine")
	var outsider := OwnedCreature.new("guardian")
	check(not overflow.merge(outsider, source), "unowned copies cannot be merged")

	var bench := WizardState.new(0)
	bench.gold = 20
	bench.offers = ["cleric", "cleric", "cleric"]
	var bench_target := bench.buy(0)
	var bench_source := bench.buy(1)
	check(bench.move_to_slot(bench_source, bench_target.slot) and bench_target.merge_copies == 2,
		"manual merge works from bench to bench")
	var field_source := bench.add_creature("cleric")
	check(bench.move_to_slot(field_source, bench_target.slot) and bench_target.stars == 1 and not bench_target.is_fielded(),
		"board to bench merge preserves bench recipient")
	var full := WizardState.new(0)
	full.gold = 100
	for i in Rules.RESERVE_CAP:
		var c := OwnedCreature.new("peasant")
		c.slot = i
		full.creatures.append(c)
	full.offers = ["peasant", "", ""]
	check(not full.can_buy(0) and full.buy(0) == null and full.gold == 100,
		"full bench requires manual space before buying even with matching copies")
	full.move_to_slot(full.at_slot(1), 0)
	check(full.buy(0) != null, "manual grouping frees a slot for purchases")

	var foe := WizardState.new(1)
	foe.add_creature("guardian")
	var b := _new_battle()
	var teams: Array[WizardState] = [m, foe]
	b.setup(teams, 12)
	var u: Unit = b.living(0)[0]
	check(u.stars == 3 and u.level == 1, "combat copies permanent stars separately from levels")
	check(is_equal_approx(u.visual_scale(), 1.0), "merge stars do not enlarge the base combat image")
	check(u.max_hp > CreatureDB.get_form("cleric").hp * 3, "stars improve combat health")
	u.transform_to("rabbit", true)
	check(is_equal_approx(u.visual_scale(), 1.15), "temporary level enlarges image by 15 percent")
	check(u.stars == 3 and u.level == 2 and first.stars == 3, "transformation keeps stars and grants temporary level")
	check(absf(u.attack_damage() - u.data.dmg * Rules.star_mult(3) * Rules.level_mult(2)) < 0.001,
		"star and temporary level bonuses combine")
	u.level = 100
	check(is_equal_approx(u.visual_scale(), Rules.MAX_LEVEL_VISUAL_SCALE), "visual growth is capped without capping combat levels")
	b.free()
	b = _new_battle()
	b.setup(teams, 12)
	u = b.living(0)[0]
	check(u.stars == 3 and u.level == 1 and u.form_id == "cleric", "next combat resets form and level but keeps stars")
	check(is_equal_approx(u.visual_scale(), 1.0), "next combat restores normal image size")
	b.free()


func _test_starting_packs() -> void:
	# Twelve themed compositions of two to four creatures, covering every shop
	# creature. Their balance comes from AI duels (training/pack_matrix.sh).
	check(CreatureDB.PACKS.size() == 12, "twelve starting compositions")
	var emblems := {}
	var uses := {}
	for pack in CreatureDB.PACKS:
		emblems[pack.emblem] = true
		check(pack.forms.size() >= 2 and pack.forms.size() <= 4, "%s has two to four creatures" % pack.name)
		check(int(pack.bonus_gold) >= 0 and int(pack.bonus_gold) <= 3, "%s bonus stays within 0-3 gold" % pack.name)
		check(pack.forms.all(func(id: String) -> bool: return id in CreatureDB.shop_ids()), "%s holds shop creatures" % pack.name)
		for id in pack.forms:
			uses[id] = uses.get(id, 0) + 1
	check(emblems.size() == CreatureDB.PACKS.size(), "every composition has its own crest")
	check(CreatureDB.shop_ids().all(func(id: String) -> bool: return uses.has(id)),
		"every shop creature starts in at least one composition")
	var village: Array = CreatureDB.PACKS.filter(func(p: Dictionary) -> bool:
		return p.forms.all(func(id: String) -> bool: return id == "peasant"))
	check(village.size() == 1, "one composition is all peasants, for an economy opening")

	# Hidden deck: no repeat within the first nine cards, then a full reshuffle.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var deck := PackDeck.new("test")
	var seen := {}
	for duel in 3:
		for card in deck.deal(3, rng):
			seen[card] = true
	check(seen.size() == 9, "three duels deal nine different compositions")
	var fourth := deck.deal(3, rng)
	check(deck.dealt == 3 and deck.order.slice(0, 3) == fourth, "the fourth deal reshuffles the whole deck")
	var solo := PackDeck.new("solo")
	seen.clear()
	for duel in PackDeck.RESHUFFLE_AFTER:
		seen[solo.deal(1, rng)[0]] = true
	check(seen.size() == PackDeck.RESHUFFLE_AFTER, "the opponent's deck deals nine different openings in a row")
	solo.deal(1, rng)
	check(solo.dealt == 1, "the opponent's deck reshuffles after nine openings")
	deck.save_state()
	var reloaded := PackDeck.new("test")
	reloaded.load_state()
	check(reloaded.order == deck.order and reloaded.dealt == deck.dealt, "a deck resumes where it stopped")
	reloaded.order[0] = reloaded.order[1]
	check(reloaded.deal(1, rng).size() == 1 and reloaded.dealt == 1, "a corrupt saved deck is reshuffled")

	var game = load("res://main.tscn").instantiate()
	add_child(game)
	game.player_deck.shuffle(rng)
	game.enemy_deck.shuffle(rng)
	seen.clear()
	var enemy_seen := {}
	for slot in 3:
		game.new_duel()
		game.choose_difficulty(Difficulty.APPRENTICE)
		check(game.offered_packs.size() == 3, "three compositions are offered")
		for card in game.offered_packs:
			seen[card] = true
		var pack: Dictionary = CreatureDB.PACKS[game.offered_packs[slot]]
		game._left_press(Hud.pack_rect(slot).get_center())
		var forms: Array = game.player.fielded().map(func(c: OwnedCreature) -> String: return c.form_id)
		var gold := Rules.income(1) + int(pack.bonus_gold)
		check(forms == pack.forms, "%s fields the selected creatures" % pack.name)
		check(game.round_num == 1 and game.player.gold == gold, "%s grants its first shop budget" % pack.name)
		var enemy_forms: Array = game.enemy.fielded().map(func(c: OwnedCreature) -> String: return c.form_id)
		var enemy_pack := CreatureDB.PACKS.filter(func(choice: Dictionary) -> bool: return choice.forms == enemy_forms)
		check(enemy_pack.size() == 1 and game.enemy.gold == Rules.income(1) + enemy_pack[0].bonus_gold,
			"opponent receives the bonus for its own composition")
		enemy_seen[game.enemy_deck.order[game.enemy_deck.dealt - 1]] = true
		game.choose_pack(slot)
		check(game.round_num == 1 and game.player.gold == gold, "pack cannot be claimed twice")
		game.start_round()
		check(game.player.gold == gold + Rules.income(2), "pack bonus is not granted again in round two")
	check(seen.size() == 9, "the player sees nine different compositions over three duels")
	check(enemy_seen.size() == 3, "the opponent opens with three different compositions")
	game.free()


func _test_preparation_input() -> void:
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	game.choose_difficulty(Difficulty.APPRENTICE)
	game.choose_pack(0)
	game.player.gold = 20
	var state: WizardState = game.player
	state.offers = ["peasant", "archer", "cleric"]
	var offer_pos := Hud.offer_rect(1).get_center()
	game._right_press(offer_pos)
	check(game.player.locked[1], "shop right-click locks offer through game input")
	game._left_press(Hud.reroll_rect().get_center())
	check(game.player.gold == 19 and game.player.offers[1] == "archer", "reroll button refreshes through game input")
	var field_count: int = game.player.field_count()
	game._left_press(offer_pos)
	game._left_release(offer_pos)
	check(game.player.field_count() == field_count and game.player.benched().size() == 1,
		"shop click purchases onto bench")
	var bought: OwnedCreature = game.player.benched()[0]
	game._left_press(Rules.reserve_slot_rect(bought.slot).get_center())
	var cell: Vector2i = game.player.preferred_free_cell("back")
	game._left_release(Rules.BOARD_POS + Rules.cell_center(cell))
	check(bought.cell == cell and game.player.field_count() == field_count + 1,
		"player can drag purchased bench unit onto board")
	game._right_press(Hud.offer_rect(0).get_center())
	game._right_press(Hud.offer_rect(0).get_center())
	check(not game.player.locked[0], "second right-click unlocks an offer")
	state.gold = 20
	state.offers = ["guardian", "guardian", "guardian"]
	for i in 3:
		game._left_press(Hud.offer_rect(i).get_center())
		game._left_release(Hud.offer_rect(i).get_center())
	check(state.benched().size() == 3, "three UI purchases do not auto-merge")
	var recipient: OwnedCreature = state.benched()[0]
	var source: OwnedCreature = state.benched()[1]
	game._left_press(Rules.reserve_slot_rect(source.slot).get_center())
	game._left_release(Rules.reserve_slot_rect(recipient.slot).get_center())
	check(recipient.stars == 0 and recipient.merge_copies == 2 and game.drag == null,
		"drag-and-drop UI creates a two-circle group without a star")
	source = state.benched()[1]
	game._left_press(Rules.reserve_slot_rect(source.slot).get_center())
	game._left_release(Rules.reserve_slot_rect(recipient.slot).get_center())
	check(recipient.stars == 1 and recipient.merge_copies == 1 and state.benched().size() == 1,
		"third UI drop promotes the chosen recipient")
	game.free()


func _test_peasant_harvest() -> void:
	check(Rules.harvest_gold("peasant", 0) == 1 and Rules.harvest_gold("peasant", 1) == 2
		and Rules.harvest_gold("peasant", 2) == 4 and Rules.harvest_gold("peasant", 3) == 8,
		"peasant harvest doubles per star")
	check(Rules.harvest_gold("guardian", 2) == 0, "non-peasants harvest nothing")
	var s := WizardState.new(0)
	s.add_creature("peasant")
	var ranked := s.add_creature("peasant")
	ranked.stars = 2
	s.add_creature("guardian")
	for i in Rules.FIELD_CAP:
		s.add_creature("archer")
	var benched := s.add_creature("peasant")
	check(not benched.is_fielded() and s.harvest_total() == 5, "only fielded peasants harvest")
	check(s.harvest().size() == 2 and s.gold == 5, "harvest grants gold per fielded peasant")

	var game = load("res://main.tscn").instantiate()
	add_child(game)
	game.choose_difficulty(Difficulty.APPRENTICE)
	game.choose_pack(0)
	var player: WizardState = game.player
	var hud: Hud = game.hud
	var gold := player.gold
	player.creatures.clear()
	var lone := player.add_creature("peasant")
	lone.stars = 1
	var benched_peasant := player.add_creature("peasant")
	check(player.move_to_slot(benched_peasant, 0) and not benched_peasant.is_fielded(), "second peasant waits on the bench")
	hud.clear_harvest()
	game.start_round()
	gold += Rules.income(2)
	check(player.gold == gold and hud.harvest_coins.is_empty(), "round start pays no harvest before placement")
	_finish_enemy_preparation(game)
	game.start_combat()
	check(game.phase == game.Phase.COMBAT, "combat starts with a fielded peasant")
	gold += 2
	check(player.gold == gold, "combat start pays only the fielded peasant's gold")
	check(hud.displayed_gold(player) == gold - 2, "harvest coins are shown only once they land")
	check(hud.harvest_coins.filter(func(c): return c.team == 0).size() == 2, "one flying coin per harvested gold")
	for i in 120:
		hud.advance_harvest(1.0 / 30.0)
	check(hud.displayed_gold(player) == gold and hud.harvest_coins.is_empty(), "every harvest coin lands in the purse")
	game.free()


func _test_fight_layout_animation() -> void:
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	game.choose_difficulty(Difficulty.APPRENTICE)
	game.choose_pack(0)
	check(game.shop_out == 1.0, "shop starts off screen before the first shop")
	game._advance_ui(0.1)
	check(game.shop_out > 0.0 and game.shop_out < 1.0, "shop slides in over several frames")
	game._advance_ui(1.0)
	check(game.shop_out == 0.0 and game.bench_dock == 0.0, "shop and bench rest in place while shopping")
	var full: Rect2 = game.bench_slot_rect(2)
	check(full == Rules.reserve_slot_rect(2), "undocked bench matches the shopping layout")
	_finish_enemy_preparation(game)
	game.start_combat()
	game._advance_ui(0.1)
	check(game.shop_out > 0.0 and game.shop_out < 1.0, "shop slides out instead of vanishing")
	check(game.bench_dock > 0.0 and game.bench_dock < 1.0, "bench shrinks over several frames")
	game._advance_ui(1.0)
	var docked: Rect2 = game.bench_slot_rect(2)
	check(game.shop_out == 1.0 and is_equal_approx(docked.size.x, Rules.CELL * 0.5)
		and docked.end.y <= 720.0 and docked.position.y > Rules.reserve_slot_rect(2).end.y,
		"bench docks at half size at the bottom during the fight")
	check(game._reserve_slot_at(docked.get_center()) == 2, "docked bench slots stay hoverable")
	game.battle.ended.emit({"winner": -1, "survivors": 0})
	game._advance_ui(1.0)
	check(game.phase == game.Phase.RESOLVE and game.shop_out == 1.0 and game.bench_dock == 1.0,
		"shop and bench stay away while the result shows")
	game._finish_round()
	game._advance_ui(0.1)
	check(game.phase == game.Phase.PREP and game.shop_out < 1.0 and game.bench_dock < 1.0,
		"next round slides the shop and bench back")
	game.free()


func _test_round_frieze() -> void:
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	var hud: Hud = game.hud
	game.choose_difficulty(Difficulty.APPRENTICE)
	game.choose_pack(0)
	hud.advance_round_frieze(0.0)
	check(game.round_num == 1 and game.round_winners.is_empty() and hud.frieze_time == Hud.FRIEZE_SLIDE,
		"round frieze opens on round 1 without sliding")
	game._on_battle_ended({"winner": 0, "survivors": 2})
	game.phase = game.Phase.PREP
	game.start_round()
	hud.advance_round_frieze(0.1)
	check(game.round_winners == [0] and hud.frieze_round == 2 and hud.frieze_time < Hud.FRIEZE_SLIDE,
		"a finished round is recorded and the frieze slides to the next one")
	hud.advance_round_frieze(1.0)
	check(hud.frieze_time == Hud.FRIEZE_SLIDE, "frieze slide settles")
	game._on_battle_ended({"winner": 1, "survivors": 1})
	game._on_battle_ended({"winner": -1, "survivors": 0})
	check(game.round_winners == [0, 1, -1], "frieze keeps winners and draws in order")
	game.new_duel()
	hud.advance_round_frieze(0.0)
	check(game.round_winners.is_empty() and hud.frieze_round == 1 and hud.frieze_time == Hud.FRIEZE_SLIDE,
		"new duel snaps the frieze back to round 1")
	game.free()


func _finish_enemy_preparation(game) -> void:
	for i in 64:
		if not game.enemy_preparing:
			break
		game._advance_enemy_preparation(1.0)
	check(not game.enemy_preparing, "enemy preparation finishes within a bounded number of actions")


func _test_shop_drag_and_enemy_preparation() -> void:
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	game.choose_difficulty(Difficulty.APPRENTICE)
	game.choose_pack(0)
	var state: WizardState = game.player
	var foe: WizardState = game.enemy
	# A deterministic affordable purchase, with no same-form merge on this team.
	foe.creatures.clear()
	foe.add_creature("guardian")
	foe.gold = 3
	foe.offers = ["archer", "", ""]
	check(game.enemy_preparing and foe.gold == 3 and foe.creatures.size() == 1,
		"round starts without instantly completing enemy purchases")
	game.start_combat()
	check(game.phase == game.Phase.PREP, "combat waits for visible enemy preparation")
	game._advance_enemy_preparation(0.1)
	check(foe.gold == 3, "enemy purchase has an initial readable delay")
	game._advance_enemy_preparation(0.25)
	check(foe.gold == 2 and foe.creatures.size() == 2 and game.enemy_action.kind == "buy",
		"enemy spends on one visible purchase at a time")
	var traveller: OwnedCreature = foe.creatures[-1]
	var origin: Vector2 = game.enemy_display_position(traveller)
	check(game.enemy_is_moving(traveller) and origin.distance_to(Rules.cell_center(traveller.cell)) > 20,
		"purchased enemy starts a movement rather than teleporting")
	game._advance_enemy_preparation(0.2)
	var middle: Vector2 = game.enemy_display_position(traveller)
	check(middle != origin and game.enemy_is_moving(traveller), "enemy placement has an intermediate position")
	_finish_enemy_preparation(game)
	check(not game.enemy_is_moving(traveller) and game.enemy_display_position(traveller).is_equal_approx(Rules.cell_center(traveller.cell)),
		"enemy arrives before combat becomes available")

	state.creatures.clear()
	state.gold = 20
	state.offers = ["guardian", "cleric", "archer"]
	var pos := Hud.offer_rect(0).get_center()
	game._left_press(pos)
	check(state.creatures.is_empty() and state.gold == 20 and state.offers[0] == "guardian",
		"shop mouse-down reserves a gesture without purchasing")
	game._left_release(Rules.BOARD_POS + Rules.cell_center(Vector2i(3, 3)))
	var target := state.at_cell(Vector2i(3, 3))
	check(target != null and state.gold == 18 and state.benched().is_empty(),
		"shop drag buys directly onto board without a bench detour")
	check(not game.show_merge_progress(target), "merge circles hidden when idle")
	game.hover_info = {"owned": target}
	check(game.show_merge_progress(target), "merge circles visible on hover")
	game.hover_info = {}
	state.offers[0] = "guardian"
	game._left_press(pos)
	var motion := InputEventMouseMotion.new()
	motion.position = pos + Vector2(-20, 0)
	game._unhandled_input(motion)
	check(game.show_merge_progress(target), "shop drag reveals compatible target progress")
	game._left_release(Rules.BOARD_POS + Rules.cell_center(target.cell))
	check(target.merge_copies == 2 and state.creatures.size() == 1 and state.gold == 16,
		"shop drag can buy and manually combine with a matching target")
	game._left_press(Hud.offer_rect(1).get_center())
	game._left_release(Vector2(10, 10))
	check(state.offers[1] == "cleric" and state.gold == 16 and game.drag == null,
		"invalid shop drop cancels without spending or consuming offer")
	game._left_press(Hud.offer_rect(1).get_center())
	game._left_release(Rules.BOARD_POS + Rules.cell_center(target.cell))
	check(state.offers[1] == "cleric" and state.gold == 16, "incompatible occupied drop does not charge")
	game._left_press(Hud.offer_rect(1).get_center())
	game._left_release(Hud.offer_rect(1).get_center())
	check(state.benched().size() == 1 and state.gold == 14, "ordinary shop click buys onto bench on release")
	var unrelated: OwnedCreature = state.benched()[0]
	game.drag = unrelated
	check(not game.show_merge_progress(target), "unrelated creatures hide progress during drag")
	game.drag = null
	# Fill the bench, then explicitly buy onto an empty board cell.
	for i in Rules.RESERVE_CAP:
		if state.at_slot(i) == null:
			var c := OwnedCreature.new("peasant")
			c.slot = i
			state.creatures.append(c)
	check(state.free_slot() == -1, "direct-purchase test has a full bench")
	game._left_press(Hud.offer_rect(2).get_center())
	game._left_release(Rules.BOARD_POS + Rules.cell_center(Vector2i(4, 4)))
	check(state.at_cell(Vector2i(4, 4)) != null and state.gold == 13, "direct placement works with a full bench")
	state.offers[0] = "guardian"
	game._left_press(pos)
	game._left_release(Rules.BOARD_POS + Rules.cell_center(target.cell))
	check(target.stars == 1 and state.gold == 11 and state.free_slot() == -1,
		"explicit shop merge works with a full bench and conserves its slots")
	state.offers[0] = "peasant"
	for i in 4:
		state.add_creature("peasant")
	var gold := state.gold
	game._left_press(pos)
	game._left_release(Rules.BOARD_POS + Rules.cell_center(Vector2i(7, 5)))
	check(state.gold == gold and state.offers[0] == "peasant", "field cap blocks direct purchase without charging")
	game.new_duel()
	check(not game.enemy_preparing and game.enemy_moves.is_empty() and game.shop_drag_index == -1,
		"restart clears enemy animations and pending shop gestures")
	game.free()


func _test_loss_gold() -> void:
	var state := WizardState.new(0)
	state.hp = 2
	state.gold = 7
	check(state.take_round_damage(6) == 2 and state.hp == 0 and state.gold == 7,
		"lethal overkill grants no compensation")
	check(state.take_round_damage(1) == 0 and state.gold == 7, "no reward after zero hearts")
	var carry := WizardState.new(0)
	check(carry.take_round_damage(1) == 0.5 and carry.hp == 9.5 and carry.gold == 0,
		"one survivor deals half a heart with no fractional gold")
	carry.take_round_damage(1)
	check(carry.hp == 9 and carry.gold == 1 and carry.loss_gold_progress == 0,
		"half-heart compensation carries across rounds to one whole gold")
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	game.player.gold = 8
	game.enemy.gold = 11
	game._on_battle_ended({"winner": 1, "survivors": 3})
	check(game.player.hp == 8.5 and game.player.gold == 9, "three survivors cost 1.5 hearts and grant one gold")
	check(game.enemy.hp == 10 and game.enemy.gold == 11, "winner gains no loss reward")
	var hud: Hud = game.hud
	check(hud.loss_rewards.size() == 3 and hud.displayed_hp(game.player) == 10 and hud.displayed_gold(game.player) == 8,
		"presentation begins before three half-heart hits")
	hud.advance_loss_rewards(0.23)
	check(hud.displayed_hp(game.player) == 9.5 and hud.displayed_gold(game.player) == 8,
		"first half-heart breaks without granting gold")
	hud.advance_loss_rewards(0.26)
	check(hud.displayed_hp(game.player) == 9, "second half-heart completes a whole heart")
	hud.advance_loss_rewards(0.83)
	check(hud.displayed_gold(game.player) == 9, "whole-heart coin arrives at counter")
	hud.advance_loss_rewards(hud.loss_reward_duration())
	check(hud.displayed_gold(game.player) == 9 and hud.displayed_hp(game.player) == 8.5,
		"HUD finishes at exact fractional health and integer gold")
	game.enemy.hp = 0.5
	game._on_battle_ended({"winner": 0, "survivors": 6})
	check(game.enemy.hp == 0 and game.enemy.gold == 11 and hud.loss_rewards.size() == 1,
		"last half-heart breaks with no overkill reward")
	check(not hud.loss_rewards[0].coin, "lethal half-heart has no coin effect")
	game._on_battle_ended({"winner": -1, "survivors": 0})
	check(hud.loss_rewards.is_empty() and game.player.gold == 9, "draw clears presentation and grants no gold")
	game.player.hp = 10
	game._on_battle_ended({"winner": 1, "survivors": 20})
	check(game.player.gold == 9 and hud.loss_rewards.all(func(reward): return not reward.coin),
		"lethal combat grants no compensation for any lost heart")
	check(game._resolve_t >= hud.loss_reward_duration(), "resolution waits for all half-heart effects")
	game.new_duel()
	check(hud.loss_rewards.is_empty() and game.player.gold == 0, "new duel clears rewards")
	game.free()


func _test_phase_music() -> void:
	var music := PhaseMusic.new()
	add_child(music)
	music.set_process(false)
	var prep: AudioStreamPlayer = music.players.prep
	var combat: AudioStreamPlayer = music.players.battle
	check(prep.stream.loop and combat.stream.loop and prep.stream.get_length() > 5 and combat.stream.get_length() > 5,
		"both supplied OGG tracks load as loops")
	music.transition_to("prep")
	check(prep.playing and is_zero_approx(prep.volume_linear), "preparation playback begins in complete silence")
	music.advance_fades(music.fade_seconds() * 0.5)
	var halfway := prep.volume_linear
	check(halfway > 0.0 and halfway < db_to_linear(music.volume_db()), "preparation fades in gradually")
	prep.seek(10.0)
	music.transition_to("prep")
	check(is_equal_approx(prep.volume_linear, halfway) and prep.get_playback_position() >= 9.9,
		"same track keeps playback position and current volume")
	music.advance_fades(music.fade_seconds() * 0.5)
	check(is_equal_approx(prep.volume_linear, db_to_linear(music.volume_db())), "fade reaches configured music volume")
	music.transition_to("battle")
	check(prep.playing and combat.playing and is_zero_approx(combat.volume_linear), "crossfade starts battle silently without cutting preparation")
	music.advance_fades(music.fade_seconds() * 0.5)
	check(prep.volume_linear > 0.0 and combat.volume_linear > 0.0 and combat.volume_linear < db_to_linear(music.volume_db()),
		"both music voices overlap during crossfade")
	var prep_before := prep.volume_linear
	var battle_before := combat.volume_linear
	music.transition_to("prep")
	check(is_equal_approx(prep.volume_linear, prep_before) and is_equal_approx(combat.volume_linear, battle_before),
		"rapid phase reversal preserves current gains without jumps")
	music.advance_fades(music.fade_seconds())
	check(prep.playing and not combat.playing and is_zero_approx(combat.volume_linear), "outgoing voice stops only at silence")
	music.transition_to("")
	check(prep.playing and prep.volume_linear > 0.0, "music stop request starts a fade instead of cutting playback")
	music.advance_fades(music.fade_seconds() * 0.5)
	check(prep.playing and prep.volume_linear > 0.0 and prep.volume_linear < prep_before * 2,
		"stop fade has an audible intermediate level")
	music.advance_fades(music.fade_seconds())
	check(not prep.playing and not combat.playing and is_zero_approx(prep.volume_linear), "stop fade ends in silence")
	music.free()

	var game = load("res://main.tscn").instantiate()
	add_child(game)
	check(game.music.current == "" and not game.music.players.prep.playing,
		"the startup map begins without music")
	game.show_map()
	check(game.music.current == "", "the world map stays without music")
	game.choose_difficulty(Difficulty.APPRENTICE)
	check(game.music.current == "prep", "choosing a duel starts preparation music")
	game.choose_pack(0)
	check(game.music.current == "prep", "preparation keeps its music")
	_finish_enemy_preparation(game)
	game.start_combat()
	check(game.music.current == "battle", "combat selects battle music")
	game.battle.time = 56.75
	game.battle.step(0.25)
	check(is_equal_approx(game.music.players.battle.pitch_scale, 1.25)
		and is_equal_approx(game.music.players.prep.pitch_scale, 1.0),
		"frenzy speeds up only the battle music")
	game._on_battle_ended({"winner": 1, "survivors": 1})
	check(game.music.current == "", "resolution fades out battle music for heart and gold effects")
	game._finish_round()
	check(game.music.current == "prep", "next round fades preparation music back in")
	_finish_enemy_preparation(game)
	game.start_combat()
	check(is_equal_approx(game.music.players.battle.pitch_scale, 1.0), "next combat starts at normal music speed")
	game.player.hp = 0.5
	game._on_battle_ended({"winner": 1, "survivors": 1})
	game._finish_round()
	check(game.phase == game.Phase.OVER and game.music.current == "", "game over keeps music faded out")
	game.new_duel()
	check(game.music.current == "", "returning to the world map keeps music off")
	game.show_menu()
	check(game.music.current == "", "returning to the menu keeps music off")
	game.free()


func _test_result_recordings() -> void:
	var game = load("res://main.tscn").instantiate()
	game.unlocked_difficulty = Difficulty.ARCHMAGE
	add_child(game)
	var victory: AudioStreamPlayer = Sfx._own_voice("duel/victory")
	var defeat: AudioStreamPlayer = Sfx._own_voice("duel/defeat")
	victory.stop()
	defeat.stop()
	Sfx._last_played.erase("duel/victory")
	Sfx._last_played.erase("duel/defeat")
	game._on_battle_ended({"winner": 0, "survivors": 1})
	check(not victory.playing and not Sfx._last_played.has("duel/victory"), "intermediate victory has no result recording")
	game._on_battle_ended({"winner": 1, "survivors": 1})
	check(not defeat.playing and not Sfx._last_played.has("duel/defeat"), "intermediate defeat has no result recording")
	game._on_battle_ended({"winner": -1, "survivors": 0})
	check(not victory.playing and not defeat.playing, "draw has no result recording")
	game.enemy.hp = 0.5
	game._on_battle_ended({"winner": 0, "survivors": 1})
	check(not victory.playing, "final victory waits for the heart sequence")
	game.battle = Battle.new()
	game.add_child(game.battle)
	game._finish_round()
	check(game.phase == game.Phase.OVER and _file_of(victory) == "victory.ogg" and victory.playing,
		"final duel victory plays supplied victory recording on game over")
	check(victory.pitch_scale == 1.0 and not victory.stream.loop,
		"result recording plays once at its original pitch")
	game.new_duel()
	victory.stop()
	Sfx._last_played.erase("duel/defeat")
	game.music.transition_to("battle")
	game.music.advance_fades(game.music.fade_seconds())
	game.player.hp = 0.5
	game._on_battle_ended({"winner": 1, "survivors": 1})
	check(not defeat.playing and game.music.current == "", "final defeat fades music and waits for the heart sequence")
	game.music.advance_fades(game.music.fade_seconds())
	check(not game.music.players.battle.playing and not game.music.players.prep.playing,
		"music is stopped after defeat fade")
	game.battle = Battle.new()
	game.add_child(game.battle)
	game._finish_round()
	check(game.phase == game.Phase.OVER and _file_of(defeat) == "defeat.ogg" and defeat.playing,
		"final duel defeat plays supplied defeat recording on game over")
	for i in Sfx.VOICES + 2:
		Sfx._last_played.erase("duel/heart_break")
		Sfx.play("duel/heart_break")
	check(_file_of(defeat) == "defeat.ogg" and defeat.playing,
		"protected events have their own voice: effects cannot steal or interrupt it")
	game.free()


## File name of the sound a voice plays.
func _file_of(voice: AudioStreamPlayer) -> String:
	if voice.stream == null:
		return ""
	return str(voice.stream.get_meta("sfx_file", "")).get_file()


## Every event is a JSON file under sfx/ with one-shot OGG files (its own or
## borrowed with files_from); sfx/ holds nothing else besides groups.json, and
## the scripts play exactly the existing events.
func _test_sound_files() -> void:
	var problems: Array[String] = []
	var expected := {Sfx.DIR + Sfx.GROUPS_FILE: true}
	var paths: Array = Sfx.event_paths()
	check(paths.size() >= 29 and paths.has("combat/hit") and paths.has("coins/harvest/8"),
		"events are found under sfx/ by path (%d)" % paths.size())
	for path: String in paths:
		var json: String = Sfx.DIR + path + ".json"
		expected[json] = true
		var streams: Array = Sfx.files_of(path)
		if not FileAccess.file_exists(json) or streams.is_empty():
			problems.append(path)
		for stream in streams:
			if not (stream is AudioStreamOggVorbis) or stream.loop:
				problems.append("%s: %s" % [path, stream])
		var dir: String = (Sfx.DIR + path).get_base_dir()
		for file in Sfx.numbered_files(DirAccess.get_files_at(dir), path.get_file()):
			expected[dir.path_join(file)] = true
			expected[dir.path_join(file) + ".import"] = true
		if not Sfx._groups.has(str(Sfx.setting(path, "group"))):
			problems.append("%s: unknown group" % path)
	check(problems.is_empty(), "every event has a JSON file, one-shot OGG files and a known group %s" % [problems])
	check(Sfx.file_number("hit.ogg", "hit") == 1 and Sfx.file_number("hit_2.ogg", "hit") == 2
		and Sfx.file_number("hit_12.ogg", "hit") == 12 and Sfx.file_number("hit_1.ogg", "hit") == 0
		and Sfx.file_number("hit_02.ogg", "hit") == 0 and Sfx.file_number("hit_x.ogg", "hit") == 0
		and Sfx.file_number("hitch.ogg", "hit") == 0 and Sfx.file_number("hit.json", "hit") == 0,
		"sound files are name.ogg then name_2.ogg, name_3.ogg...")
	var foreign: Array[String] = []
	for path in _files_under(Sfx.DIR):
		if not expected.has(path):
			foreign.append(path)
	check(foreign.is_empty(), "sfx/ holds only events, their sound files and groups.json %s" % [foreign])
	var played := {}
	# String literals in a play or stop call, except those compared in its condition.
	var literal := RegEx.create_from_string("(?<!== )\"([a-z0-9_/%]+)\"")
	for path in _script_files("res://scripts/"):
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if line.contains("Sfx.play(") or line.contains("Sfx.stop("):
				for m in literal.search_all(line):
					played[m.get_string(1)] = true
	var unknown: Array = []
	var used := {}
	for text: String in played:
		var pattern := RegEx.create_from_string("^" + text.replace("%d", "[0-9]+") + "$")
		var matches := paths.filter(func(p: String) -> bool: return pattern.search(p) != null)
		if matches.is_empty():
			unknown.append(text)
		for p in matches:
			used[p] = true
	var unused := paths.filter(func(p: String) -> bool: return not used.has(p))
	check(unknown.is_empty() and unused.is_empty(),
		"scripts play exactly the existing events (unknown %s, unused %s)" % [unknown, unused])
	_test_file_picking()
	_test_sound_settings()
	_test_groups_and_missing_events()
	_test_sound_reload()
	_test_sound_overrides()


func _files_under(dir: String) -> Array[String]:
	var files: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		files.append(dir + file)
	for sub in DirAccess.get_directories_at(dir):
		files.append_array(_files_under(dir + sub + "/"))
	return files


## "shuffle" plays every file once per deal, never twice in a row across deals,
## and can deal again early; "random" draws any file.
func _test_file_picking() -> void:
	seed(7)
	var state := {}
	var deals: Array = []
	for d in 50:
		var deal := {}
		for i in 4:
			deal[Sfx.next_pick(state, 4, "shuffle", 0)] = true
		deals.append(deal.size())
	check(deals.all(func(n: int) -> bool: return n == 4), "shuffle plays every file once before any repeats")
	state = {}
	var picks: Array[int] = []
	for i in 300:
		picks.append(Sfx.next_pick(state, 3, "shuffle", 2))
	var repeats := 0
	var distinct_pairs := true
	for i in range(1, picks.size()):
		if picks[i] == picks[i - 1]:
			repeats += 1
		if i % 2 == 1 and picks[i] == picks[i - 1]:
			distinct_pairs = false
	check(repeats == 0 and distinct_pairs and picks.has(0) and picks.has(1) and picks.has(2),
		"shuffle_refill_after deals again early, never repeating the file just played")
	state = {}
	var counts := [0, 0, 0]
	var random_repeats := 0
	var last := -1
	for i in 600:
		var pick := Sfx.next_pick(state, 3, "random", 0)
		counts[pick] += 1
		random_repeats += 1 if pick == last else 0
		last = pick
	check(counts.all(func(n: int) -> bool: return n > 120) and random_repeats > 0,
		"random draws every file and may repeat one")
	check(Sfx.next_pick({}, 1, "shuffle", 0) == 0 and Sfx.next_pick({}, 1, "random", 0) == 0,
		"a single file always plays")
	state = {"bag": [5, 4], "dealt": 1, "last": 4}
	check(Sfx.next_pick(state, 2, "shuffle", 0) < 2, "a deal of removed files starts over")
	randomize()


## Shipped settings reproduce the tuned playback, and fall back to the
## defaults for missing keys.
func _test_sound_settings() -> void:
	var problems: Array[String] = []
	for path: String in Sfx.event_paths():
		var json: String = Sfx.DIR + path + ".json"
		var data := Sfx.read_settings(json, Sfx.SOUND_DEFAULTS)
		if data.is_empty() or not data.has("description"):
			problems.append("%s unreadable or undescribed" % json)
		for problem in Sfx.settings_problems(data, Sfx.SOUND_DEFAULTS):
			problems.append("%s: %s" % [json, problem])
	var music := PhaseMusic.load_settings()
	problems.append_array(PhaseMusic.settings_problems(music))
	check(problems.is_empty() and not music.is_empty(), "shipped sound settings hold only known keys %s" % [problems])
	check(Sfx.settings_problems({"volme_db": 1, "pitch_step": 0.07}, Sfx.SOUND_DEFAULTS).size() == 2
		and PhaseMusic.settings_problems({"pitch": 1}).size() == 1
		and Sfx.settings_problems({"pick": "cycle"}, Sfx.SOUND_DEFAULTS).size() == 1,
		"misspelled keys, the former pitch_step and unknown pick modes are reported")
	check(is_equal_approx(Sfx.setting("combat/hit", "pitch_jitter"), 0.08)
		and is_equal_approx(Sfx.setting("combat/hit", "volume_db"), -8.0)
		and Sfx.setting("combat/hit", "pick") == "shuffle" and Sfx.setting("combat/hit", "group") == "effects",
		"effects play at -8 dB with a +/-0.08 random pitch, shuffling their files")
	check(Sfx.event_paths().filter(func(p: String) -> bool: return p.begins_with("ui/")).all(
		func(p: String) -> bool: return Sfx.setting(p, "group") == "ui"), "interface events play in the ui group")
	check(is_equal_approx(Sfx.setting("coins/harvest/1", "pitch_jitter"), 0.02)
		and is_equal_approx(Sfx.setting("coins/compensation", "pitch_jitter"), 0.05)
		and is_equal_approx(Sfx.setting("coins/gain", "pitch_jitter"), 0.08),
		"each coin sound has its own settings")
	var rising := true
	for i in range(2, 9):
		var path := "coins/harvest/%d" % i
		rising = rising and Sfx.setting(path, "files_from") == "coins/harvest/1" and not Sfx._streams.has(path) \
			and Sfx.files_of(path) == Sfx.files_of("coins/harvest/1") \
			and is_equal_approx(Sfx.setting(path, "pitch"), 1.0 + 0.07 * (i - 1))
	check(rising, "harvest coins 2 to 8 share the first coin's file, each 0.07 higher")
	check(Sfx.setting("abilities/bard_song", "loop") and is_equal_approx(Sfx.setting("abilities/bard_song", "pitch"), 1.0)
		and Sfx.setting("abilities/bard_song", "pitch_jitter") == 0.0,
		"the bard song loops at its recorded pitch")
	check(Sfx.setting("duel/victory", "protected") and Sfx.setting("duel/defeat", "protected")
		and Sfx.setting("duel/victory", "pitch_jitter") == 0.0 and Sfx.setting("duel/defeat", "pitch_jitter") == 0.0
		and not Sfx.setting("combat/hit", "protected"),
		"result recordings are protected and keep their original pitch")
	check(is_equal_approx(float(music.get("volume_db")), -16.0) and is_equal_approx(float(music.get("fade_seconds")), 1.2),
		"music settings come from music.json")


## Groups are audio buses at their groups.json volume plus the game's change;
## a missing event is silence and one warning.
func _test_groups_and_missing_events() -> void:
	var ui_bus := AudioServer.get_bus_index("ui")
	check(ui_bus > 0 and AudioServer.get_bus_index("effects") > 0 and AudioServer.get_bus_send(ui_bus) == "Master",
		"each group is an audio bus sent to Master")
	var designed := float(Sfx._groups["ui"].get("volume_db", 0.0))
	Sfx.set_group_volume("ui", -6.0)
	check(is_equal_approx(AudioServer.get_bus_volume_db(ui_bus), designed - 6.0),
		"the game's group volume adds to the designed one")
	Sfx.set_group_volume("ui", 0.0)
	Sfx._last_played.erase("ui/click")
	Sfx.play("ui/click")
	var voice: AudioStreamPlayer = Sfx._players[(Sfx._next + Sfx.VOICES - 1) % Sfx.VOICES]
	check(voice.bus == "ui", "an event plays on its group's bus")
	Sfx.play("nowhere/missing")
	Sfx.play("nowhere/missing")
	check(Sfx._warned.has("nowhere/missing"), "a missing event is silent and warned about")


## Runs from the editor read sfx/ from disk: a changed, added or removed event
## or sound file is picked up by reload(). A scratch folder stands in for sfx/.
func _test_sound_reload() -> void:
	var root := ProjectSettings.globalize_path("user://sfx_reload_test_%d" % OS.get_process_id())
	var write := func(rel: String, bytes: PackedByteArray) -> void:
		var path := root.path_join(rel)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(bytes)
		f.close()
	var kept_roots := Sfx._roots.duplicate()
	var kept_disk := Sfx._from_disk.duplicate()
	var hit := FileAccess.get_file_as_bytes(Sfx.DIR + "combat/hit.ogg")
	write.call("groups.json", "{\"effects\": {}}".to_utf8_buffer())
	write.call("a/beep.json", "{\"description\": \"Test.\", \"volume_db\": -2.0}".to_utf8_buffer())
	write.call("a/beep.ogg", hit)
	Sfx._roots.assign([root])
	Sfx._from_disk.assign([true])
	Sfx.reload()
	check(Sfx.event_paths() == ["a/beep"] and Sfx.files_of("a/beep").size() == 1, "an editor run reads sfx/ from disk")
	var first: AudioStream = Sfx.files_of("a/beep")[0]
	write.call("a/beep_2.ogg", hit)
	write.call("a/beep.json", "{\"description\": \"Test.\", \"volume_db\": -4.0}".to_utf8_buffer())
	write.call("a/boop.json", "{\"description\": \"New.\"}".to_utf8_buffer())
	Sfx._signature = ""
	Sfx.reload()
	check(Sfx.files_of("a/beep").size() == 2 and Sfx.files_of("a/beep")[0] == first
		and is_equal_approx(Sfx.setting("a/beep", "volume_db"), -4.0) and Sfx.event_paths().has("a/boop"),
		"added files, changed settings and new events reload; unchanged files are kept")
	DirAccess.remove_absolute(root.path_join("a/boop.json"))
	Sfx.reload()
	check(not Sfx.event_paths().has("a/boop"), "a removed event is gone after a reload")
	_remove_tree(root)
	Sfx._roots.assign(kept_roots)
	Sfx._from_disk.assign(kept_disk)
	Sfx._signature = ""
	Sfx.reload()




func _remove_tree(dir: String) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_remove_tree(dir.path_join(sub))
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)


## An exported build reads sound files and settings beside its executable on
## top of the packed ones; here a temporary folder stands in for it.
func _test_sound_overrides() -> void:
	check(Sfx._roots.size() == 1, "editor runs read only the project's sfx/ folder")
	var root := ProjectSettings.globalize_path("user://sfx_override_test_%d" % OS.get_process_id())
	var write := func(rel: String, bytes: PackedByteArray) -> void:
		var path := root.path_join(rel)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(bytes)
		f.close()
	var hit_ogg := Sfx.DIR + "combat/hit.ogg"
	var death_ogg := Sfx.DIR + "combat/death.ogg"
	write.call("ui/click.ogg", FileAccess.get_file_as_bytes(hit_ogg))
	write.call("ui/click_2.ogg", FileAccess.get_file_as_bytes(death_ogg))
	write.call("combat/hit.json", "{\"volume_db\": -3.0}".to_utf8_buffer())
	write.call("extra/chime.json", "{\"description\": \"Only beside the executable.\"}".to_utf8_buffer())
	write.call("extra/chime.ogg", FileAccess.get_file_as_bytes(hit_ogg))
	write.call("groups.json", "{\"ui\": {\"volume_db\": -2.0}}".to_utf8_buffer())
	var packed: Array = Sfx.files_of("ui/click")
	Sfx._add_root(root, true)
	Sfx.reload()
	var loaded: Array = Sfx.files_of("ui/click")
	check(loaded.size() == 2 and loaded[0] != packed[0]
		and is_equal_approx(loaded[0].get_length(), load(hit_ogg).get_length())
		and is_equal_approx(loaded[1].get_length(), load(death_ogg).get_length()),
		"sound files beside the executable replace all the packed files of the event")
	check(is_equal_approx(Sfx.setting("combat/hit", "volume_db"), -3.0)
		and is_equal_approx(Sfx.setting("combat/hit", "pitch_jitter"), 0.08)
		and is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("ui")), -2.0),
		"JSON files beside the executable apply over the packed values key by key")
	check(Sfx.event_paths().has("extra/chime") and Sfx.files_of("extra/chime").size() == 1,
		"an event that exists only beside the executable plays too")
	write.call("combat/hit.json", "{\"volume_db\": ".to_utf8_buffer())
	Sfx._signature = ""
	Sfx.reload()
	check(is_equal_approx(Sfx.setting("combat/hit", "volume_db"), -3.0),
		"an unreadable replacement JSON file keeps the current values")
	DirAccess.remove_absolute(root.path_join("ui/click.ogg"))
	DirAccess.remove_absolute(root.path_join("ui/click_2.ogg"))
	Sfx.reload()
	check(Sfx.files_of("ui/click").size() == packed.size()
		and is_equal_approx(Sfx.files_of("ui/click")[0].get_length(), packed[0].get_length()),
		"once the replacement files are gone, the packed files play again")
	Sfx._roots.pop_back()
	Sfx._from_disk.pop_back()
	_remove_tree(root)
	Sfx._signature = ""
	Sfx.reload()


func _script_files(dir: String) -> Array[String]:
	var files: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			files.append(dir + file)
	for sub in DirAccess.get_directories_at(dir):
		files.append_array(_script_files(dir + sub + "/"))
	return files


func _test_round_reset_and_damage() -> void:
	var p := WizardState.new(0)
	var e := WizardState.new(1)
	p.add_creature("guardian")
	e.add_creature("peasant")
	var b := _new_battle()
	var teams: Array[WizardState] = [p, e]
	b.setup(teams, 11)
	b.spells[0].charges = 3
	b.cast(0, b.living(0)[0])
	check(p.creatures[0].form_id == "guardian", "owned creature keeps its purchased form")
	var result := {}
	b.ended.connect(func(r): result.merge(r)) # lambdas capture locals by value
	for i in 6000:
		b.step(1.0 / 60.0)
		if b.finished:
			break
	check(b.finished and result.has("winner"), "combat ends")
	b.queue_free()
	# Draw on mutual elimination / timeout.
	var d := _new_battle()
	d.spawn(0, "turtle", Vector2(30, 400))
	d.spawn(1, "turtle", Vector2(540, 30))
	d.casting_enabled = false
	for i in 4000:
		d.step(1.0 / 60.0)
		if d.finished:
			break
	check(d.finished, "timeout ends combat")
	d.queue_free()


func _test_frenzy() -> void:
	var b := _new_battle()
	var ally := b.spawn(0, "peasant", Vector2(200, 300))
	var foe := b.spawn(1, "peasant", Vector2(200, 80))
	var speed := ally.move_speed()
	var interval := ally.attack_interval()
	ally.stun_t = 60.0
	foe.stun_t = 60.0
	b.time = 44.5
	b.step(0.25)
	check(b.frenzy_level == 0, "combat has no frenzy before 45 seconds")

	ally.attack_timer = interval
	b.spells[0].charges = 0
	b.spells[1].charges = 0
	b.spells[0].recharge = 0.0
	b.spells[1].recharge = 0.0
	b.spells[1].recharge_time = Rules.UPGRADED_RECHARGE_TIME
	b.step(0.25)
	check(b.frenzy_level == 1 and is_equal_approx(ally.move_speed(), speed * 1.2),
		"frenzy starts at 45 seconds and boosts movement by 20%")
	check(is_equal_approx(ally.attack_interval(), interval / 1.2)
		and is_equal_approx(ally.attack_timer, interval - 0.25 * 1.2),
		"frenzy speeds up basic attacks already on cooldown")
	check(is_equal_approx(b.spells[0].recharge, 0.25) and is_equal_approx(b.spells[1].recharge, 0.25)
		and b.spells[0].recharge_time == Rules.RECHARGE_TIME
		and b.spells[1].recharge_time == Rules.UPGRADED_RECHARGE_TIME,
		"frenzy leaves normal and upgraded shapeshift recharge rates intact")
	b.damage(ally, foe, 10.0, "melee")
	check(is_equal_approx(foe.hp, foe.max_hp - 12.0), "frenzy boosts damage dealt by 20%")

	for level in range(2, 6):
		b.step(3.0)
		check(b.frenzy_level == level, "frenzy gains a level every three seconds")
	check(is_equal_approx(b.frenzy_multiplier(), 2.0), "frenzy doubles damage and speed at 57 seconds")
	b.step(3.0)
	check(b.finished and b.result.winner == -1, "surviving teams still draw at 60 seconds")
	b.free()


func _test_abilities() -> void:
	# Duelist parry negates the first basic hit.
	var b := _new_battle()
	var duelist := b.spawn(0, "duelist", Vector2(200, 200))
	var archer := b.spawn(1, "archer", Vector2(200, 100))
	duelist.tick(0.01)
	check(duelist.parry_ready, "duelist starts with parry")
	b.damage(archer, duelist, 10.0, "ranged")
	check(duelist.hp == duelist.max_hp and not duelist.parry_ready, "parry negates a hit")
	# Armour reduction and piercing.
	var guard := b.spawn(0, "guardian", Vector2(300, 300))
	b.damage(null, guard, 100.0, "ability")
	check(absf(guard.max_hp - guard.hp - 60.0) < 0.01, "40% armour")
	guard.hp = guard.max_hp
	b.damage(null, guard, 100.0, "ranged", true)
	check(absf(guard.max_hp - guard.hp - 100.0) < 0.01, "piercing ignores armour")
	# Hedgehog thorns.
	var hog := b.spawn(1, "hedgehog", Vector2(400, 100))
	var peasant := b.spawn(0, "peasant", Vector2(420, 120))
	b.damage(peasant, hog, 5.0, "melee")
	check(absf(peasant.max_hp - peasant.hp - 5.0) < 0.01, "thorns reflect melee damage")
	# Poison ticks (measured on an isolated unit so it does not fight).
	var lone := _new_battle()
	var victim := lone.spawn(0, "peasant", Vector2(100, 100))
	victim.add_status("poisoned", 2.0, 5.0, false)
	for i in 100:
		victim.tick(0.01)
	check(absf(victim.max_hp - victim.hp - 5.0) < 0.2, "poison 5 HP/s")
	lone.queue_free()
	# Berserker attacks faster when hurt.
	var berserker := b.spawn(0, "berserker", Vector2(100, 400))
	var full := berserker.attack_interval()
	berserker.hp = berserker.max_hp * 0.2
	check(berserker.attack_interval() < full * 0.6, "berserker speeds up")
	b.queue_free()


## Animal transformations must offer useful combat niches, including the
## previously weak stage-2 outcomes. These checks exercise their actual effects.
func _test_animal_roles() -> void:
	var b := _new_battle()
	var rabbit := b.spawn(0, "rabbit", Vector2(200, 200))
	var guardian := b.spawn(1, "guardian", Vector2(240, 200))
	check(rabbit.attack_damage() / rabbit.attack_interval() > guardian.attack_damage() / guardian.attack_interval() * 2.0,
		"rabbit trades guardian durability for substantially higher basic DPS")
	var rear := b.spawn(1, "archer", Vector2(240, 50))
	rabbit.tick(0.01)
	check(rabbit.jump_t > 0.0 and rabbit.jump_target == rear, "rabbit leaps to deepest enemy rather than nearby frontline")
	rabbit._tick_jump(0.5)
	check(rabbit.target == rear and rabbit.position.y < rear.position.y, "rabbit lands behind and engages its backline target")
	var deer := b.spawn(0, "deer", Vector2(200, 230))
	guardian.hp = guardian.max_hp * 0.5
	rabbit.hp = rabbit.max_hp * 0.5
	deer.hp = deer.max_hp * 0.5
	deer.tick(0.01)
	var rabbit_hp := rabbit.hp
	var deer_hp := deer.hp
	rabbit._tick_statuses(0.3)
	deer._tick_statuses(0.3)
	check(rabbit.hp > rabbit_hp and deer.hp > deer_hp, "deer sustains nearby allies and itself")
	check(not guardian.statuses.has("regen"), "deer does not heal enemies")
	var skunk := b.spawn(0, "skunk", Vector2(220, 240))
	skunk.ability_timer = 0.0
	skunk.tick(0.01)
	check(guardian.armour() < guardian.data.armour, "skunk weakens an armoured frontline")
	var peacock := b.spawn(0, "peacock", Vector2(220, 260))
	peacock.ability_timer = 0.0
	var interval := guardian.attack_interval()
	peacock.tick(0.01)
	check(guardian.attack_interval() > interval, "peacock slows enemy attacks")
	b.free()


func _test_bard_song() -> void:
	var b := _new_battle()
	var bard := b.spawn(0, "bard", Vector2(40, 400))
	var far := b.spawn(0, "duelist", Vector2(540, 40)) # opposite corner of the board
	var foe := b.spawn(1, "guardian", Vector2(300, 60))
	var interval := far.attack_interval()
	bard._tick_ability()
	b.update_song()
	check(bard.ability_timer > 0.0 and not far.statuses.has("inspired") and not Sfx.is_looping("abilities/bard_song"),
		"song waits for its first beat, music included")
	bard.ability_timer = 0.0
	bard._tick_ability()
	b.update_song()
	check(Sfx.is_looping("abilities/bard_song") and b.song_playing, "the first beat starts the looping bard song")
	check(far.statuses.has("inspired") and bard.statuses.has("inspired") and not foe.statuses.has("inspired"),
		"one beat inspires every ally on the battlefield, the bard included, and no enemy")
	check(is_equal_approx(far.statuses.inspired.t, 3.0) and is_equal_approx(bard.ability_timer, 1.0),
		"song beats every second and inspires for three seconds")
	check(is_equal_approx(far.attack_interval(), interval / 1.35), "inspired allies attack 35% faster")
	var second := b.spawn(0, "bard", Vector2(80, 400))
	second.singing = true
	second.transform_to("duelist", true)
	b.update_song()
	check(Sfx.is_looping("abilities/bard_song") and not second.singing, "a bard turned into another form stops singing; another still sings")
	b.damage(null, bard, bard.max_hp, "ability")
	b._reap()
	b.update_song()
	check(not Sfx.is_looping("abilities/bard_song") and not b.song_playing, "the song fades out once no bard sings")
	far._tick_statuses(2.9)
	check(far.statuses.has("inspired"), "inspiration outlasts the bard's death until it expires")
	far._tick_statuses(0.2)
	check(not far.statuses.has("inspired"), "inspiration expires three seconds after the last beat")
	b.free()


## Fires one crossbowman bolt at the first of a row of guardians and returns the
## damage taken by each guardian once every hop has landed.
func _crossbow_volley(stars: int, row: int, kill_first := false) -> Array[float]:
	var b := _new_battle()
	var cell := Rules.CELL
	var bow := b.spawn(0, "crossbowman", Vector2(200, 200 + cell * 3.0), 0, stars)
	var row_units: Array[Unit] = []
	for i in row:
		row_units.append(b.spawn(1, "guardian", Vector2(200 + i * cell * 0.8, 200)))
	bow._attack(row_units[0])
	if kill_first:
		b.damage(null, row_units[0], row_units[0].max_hp * 10.0, "ability")
	for step in 200:
		b._update_projectiles(0.02)
	var taken: Array[float] = []
	for u in row_units:
		taken.append(u.max_hp - u.hp)
	b.free()
	return taken


func _test_crossbow_bolts() -> void:
	var d: float = CreatureDB.get_form("crossbowman").dmg
	check(is_equal_approx(d, 26.0 * 1.2), "crossbowman base damage is 20% higher (31.2)")
	var plain := _crossbow_volley(0, 3)
	check(is_equal_approx(plain[0], d) and plain[1] == 0.0 and plain[2] == 0.0,
		"0-star bolt hits a single target, ignoring armour")
	var m1 := d * Rules.star_mult(1)
	var one := _crossbow_volley(1, 4)
	check(is_equal_approx(one[0], m1) and is_equal_approx(one[1], m1 * 0.7)
		and is_equal_approx(one[2], m1 * 0.49) and one[3] == 0.0,
		"1-star seeker bolt chains to 3 targets, -30% per hop")
	var m2 := d * Rules.star_mult(2)
	var two := _crossbow_volley(2, 6)
	check(is_equal_approx(two[4], m2 * pow(0.7, 4)) and two[5] == 0.0,
		"2-star seeker bolt chains to 5 targets")
	var homing := _crossbow_volley(1, 4, true)
	check(is_equal_approx(homing[1], m1) and is_equal_approx(homing[2], m1 * 0.7) and homing[3] > 0.0,
		"seeker bolt retargets when its target dies in flight")


func _test_mage_attacks() -> void:
	var b := _new_battle()
	var frost := b.spawn(0, "frost_mage", Vector2(200, 300))
	var guard := b.spawn(1, "guardian", Vector2(200, 170))
	var speed := guard.move_speed()
	var interval := guard.attack_interval()
	guard.attack_timer = interval
	frost._attack(guard)
	b._update_projectiles(1.0)
	check(is_equal_approx(guard.move_speed(), speed * 0.5) and is_equal_approx(guard.attack_interval(), interval * 2.0),
		"frost shot halves movement and basic attack rates")
	guard.tick(0.4)
	check(is_equal_approx(guard.attack_timer, interval - 0.2), "chill slows a basic attack already recharging")
	guard.tick(0.8)
	check(is_equal_approx(guard.attack_timer, interval - 0.7) and is_equal_approx(guard.move_speed(), speed),
		"attack recharge returns to full speed when chill expires mid-tick")
	b.free()

	b = _new_battle()
	var fire := b.spawn(0, "pyromancer", Vector2(240, 300))
	guard = b.spawn(1, "guardian", Vector2(240, 140))
	var neighbour := b.spawn(1, "turtle", Vector2(280, 140))
	var unburned := b.spawn(1, "guardian", Vector2(410, 300))
	fire._tick_ability()
	check(b.projectiles.is_empty(), "fireball has an initial cooldown")
	fire._attack(guard)
	b._update_projectiles(1.0)
	check(guard.statuses.has("burning") and neighbour.statuses.has("burning") and not unburned.statuses.has("burning"),
		"basic fire shot burns its target and enemies in splash range")
	var hp := guard.hp
	guard._tick_statuses(0.5)
	check(is_equal_approx(hp - guard.hp, 1.5), "burn ticks for damage reduced by armour")
	fire.target = guard
	fire.attack_timer = 0.0
	fire.tick(0.0)
	check(fire.target == unburned, "pyromancer switches to an unburned enemy when the next shot is ready")
	b._update_projectiles(1.0)

	fire.ability_timer = 0.0
	fire._tick_ability()
	fire.tick(0.75)
	check(b.projectiles.is_empty() and fire.channel_t > 0.0, "pyromancer does not attack during its fireball channel")
	fire.tick(0.25)
	check(b.projectiles.size() == 1 and fire.ability_timer == 15.0,
		"fireball starts its own long cooldown at launch")
	var projectile := b.projectiles[0]
	check(b.cast(1, fire), "enemy can transform pyromancer after launch")
	guard.position += Vector2(12, -20)
	b._update_projectiles(0.1)
	check(projectile.aim == guard.position and is_equal_approx(fire.position.distance_to(projectile.pos), 0.35 * Rules.CELL),
		"launched fireball still follows a moving enemy after caster transforms")
	b.damage(null, guard, guard.max_hp, "ability", true)
	b._reap()
	hp = neighbour.hp
	b._update_projectiles(2.0)
	check(is_equal_approx(hp - neighbour.hp, 120.0), "fireball retargets after a kill and ignores armour")
	b.free()


func _test_mage_interruptions() -> void:
	for form in ["pyromancer", "frost_mage"]:
		var b := _new_battle()
		var mage := b.spawn(1, form, Vector2(240, 150))
		b.spawn(0, "guardian", Vector2(240, 300))
		mage.ability_timer = 0.0
		mage.tick(0.0)
		check(mage.channel_t == 1.0 and b.projectiles.is_empty() and b.blizzards.is_empty(),
			"%s channels before releasing its ability" % form)
		var cooldown: float = mage.data.cd
		check(b.cast(0, mage), "channeling mage can be transformed")
		check(mage.channel_t == 0.0 and mage.ability_timer == cooldown,
			"%s loses the cast and starts its cooldown on interruption" % form)
		mage.tick(1.0)
		check(b.projectiles.is_empty() and b.blizzards.is_empty(), "interrupted ability never fires")
		b.free()


# --- Simulations ------------------------------------------------------------------------

## Plays AI-vs-AI duels to check the loop terminates and to report pacing.
func _test_overlapping_blizzards() -> void:
	var b := _new_battle()
	var mage := b.spawn(0, "frost_mage", Vector2(200, 300))
	var other_mage := b.spawn(0, "frost_mage", Vector2(260, 300))
	var victim := b.spawn(1, "peasant", Vector2(200, 170))
	var lone := b.spawn(1, "peasant", Vector2(380, 170))
	b.add_blizzard(mage, Vector2(200, 170))
	b.add_blizzard(other_mage, Vector2(236, 170)) # overlaps the first storm
	b.add_blizzard(other_mage, Vector2(380, 170))
	b._tick_blizzards(1.0)
	var single_storm_damage: float = mage.data.storm_dps
	check(absf(victim.max_hp - victim.hp - single_storm_damage) < 0.01
		and absf(lone.max_hp - lone.hp - single_storm_damage) < 0.01,
		"overlapping blizzards deal the damage of one storm, not their sum")
	check(victim.statuses.has("chilled") and is_equal_approx(victim.statuses.chilled.v, 0.5),
		"overlapping blizzards still chill once at full strength")
	b.free()


func _test_combat_click_casts() -> void:
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	game.choose_difficulty(Difficulty.APPRENTICE)
	game.choose_pack(0)
	game.enemy_preparing = false
	game.enemy_moves.clear()
	game.enemy_action.clear()
	if game.enemy.field_count() == 0:
		game.enemy.add_creature("peasant")
	game.start_combat()
	var b: Battle = game.battle
	b.spells[0].charges = 2
	var ally: Unit = b.living(0)[0]
	var foe: Unit = b.living(1)[0]
	game._right_press(Rules.BOARD_POS + foe.position)
	check(b.casts[0] == 0, "right-click no longer casts during combat")
	game._left_press(Rules.BOARD_POS + ally.position)
	check(b.casts[0] == 1 and game.fx.items.any(func(i): return i.kind == "shift_bless"),
		"left click shapeshifts an own creature with the blessing effect")
	game._left_press(Rules.BOARD_POS + foe.position)
	check(b.casts[0] == 2 and game.fx.items.any(func(i): return i.kind == "shift_hex"),
		"left click shapeshifts an enemy creature with the hex effect")
	var effects: int = game.fx.items.size()
	game._left_press(Vector2(20, 20))
	check(game.fx.items.size() == effects, "clicks outside the board neither cast nor fizzle")
	game.queue_free()


func _test_blizzard_and_recharge_upgrade() -> void:
	var b := _new_battle()
	var mage := b.spawn(0, "frost_mage", Vector2(200, 300))
	var victim := b.spawn(1, "archer", Vector2(200, 170))
	var neighbour := b.spawn(1, "cleric", Vector2(270, 160))
	var outside := b.spawn(1, "archer", Vector2(500, 150))
	var friend := b.spawn(0, "archer", Vector2(200, 170))
	mage.ability_timer = 0
	mage._tick_ability()
	mage.tick(1.0)
	check(b.blizzards.size() == 1 and b.blizzards[0].rect.size == Vector2.ONE * Rules.CELL * 3,
		"frost mage casts an exact 3x3 square blizzard")
	check(mage.ability_timer >= 8, "blizzard has a long cooldown")
	var speed := victim.move_speed()
	var interval := victim.attack_interval()
	b._tick_blizzards(1.0)
	check(victim.hp < victim.max_hp and neighbour.hp < neighbour.max_hp,
		"blizzard damages multiple enemies inside square")
	check(outside.hp == outside.max_hp and friend.hp == friend.max_hp,
		"blizzard spares allies and enemies outside square")
	check(is_equal_approx(victim.move_speed(), speed * 0.5) and is_equal_approx(victim.attack_interval(), interval * 2.0),
		"blizzard halves movement and basic attack rates")
	mage.transform_to("peacock", false)
	b._tick_blizzards(10.0)
	check(b.blizzards.is_empty() and absf(victim.max_hp - victim.hp - 21.6) < 0.01,
		"cast blizzard persists after form change and damage stops at duration")
	b.free()

	var p := WizardState.new(0)
	var e := WizardState.new(1)
	var recharge_cost: int = Rules.WAND_UPGRADE_COSTS.recharge[0]
	p.gold = recharge_cost - 1
	check(not p.buy_upgrade("recharge"), "recharge upgrade requires its gold cost")
	p.gold = recharge_cost
	check(p.buy_upgrade("recharge") and p.gold == 0, "recharge upgrade consumes exactly its cost")
	p.gold = 100
	check(not p.buy_upgrade("recharge") and p.gold == 100, "single recharge upgrade cannot be bought twice")
	check(Rules.WAND_UPGRADES == ["recharge", "charges", "heal", "hex"]
		and Rules.WAND_UPGRADE_COSTS.charges == [3, 5],
		"four wand upgrades in shop order, starting charges in two levels")
	check(p.start_charges() == 1 and p.upgrade_cost("charges") == 3, "one starting charge before upgrades")
	p.gold = 8
	check(p.buy_upgrade("charges") and p.start_charges() == 2 and p.gold == 5 and p.upgrade_cost("charges") == 5,
		"first charges level grants a second starting charge")
	check(p.buy_upgrade("charges") and p.start_charges() == 3 and p.gold == 0 and p.upgrade_maxed("charges")
		and p.upgrade_cost("charges") == -1, "second charges level starts combat with three charges")
	p.gold = 100
	check(not p.buy_upgrade("charges") and p.gold == 100, "maxed charges upgrade cannot be bought again")
	check(p.shift_heal() == Rules.SHIFT_HEAL and p.hex_stun() == Rules.ENEMY_SHIFT_STUN, "heal and hex start at base")
	check(p.buy_upgrade("heal") and p.buy_upgrade("hex") and p.shift_heal() == Rules.UPGRADED_SHIFT_HEAL
		and p.hex_stun() == Rules.UPGRADED_ENEMY_SHIFT_STUN and p.gold == 92, "heal and hex upgrades apply their values")
	p.add_creature("guardian")
	e.add_creature("guardian")
	b = _new_battle()
	var teams: Array[WizardState] = [p, e]
	b.setup(teams, 3)
	check(b.spells[0].recharge_time == 2.4 and b.spells[1].recharge_time == 3.0,
		"recharge upgrade applies only to owning wizard")
	check(b.spells[0].charges == 3 and b.spells[1].charges == 1, "starting charges upgrade applies only to its owner")
	check(b.shift_heal == [Rules.UPGRADED_SHIFT_HEAL, Rules.SHIFT_HEAL]
		and b.hex_stun == [Rules.UPGRADED_ENEMY_SHIFT_STUN, Rules.ENEMY_SHIFT_STUN],
		"heal and hex upgrades apply only to the casting wizard")
	b.spells[0].charges = 1
	b.spells[0].tick(2.39)
	check(b.spells[0].charges == 1, "upgraded charge is not granted early")
	b.spells[0].tick(0.02)
	check(b.spells[0].charges == 2 and b.spells[1].charges == 1,
		"upgraded charge recharges at 2.4 seconds")
	var own: Unit = b.living(0)[0]
	own.hp = own.max_hp * 0.5
	b.cast(0, own)
	check(absf(own.hp / own.max_hp - 0.75) < 0.001, "upgraded allied shapeshift heals a quarter of max HP")
	var foe: Unit = b.living(1)[0]
	b.cast(0, foe)
	check(foe.stun_t == Rules.UPGRADED_ENEMY_SHIFT_STUN, "upgraded hex stuns the enemy longer")
	var mine: Unit = b.living(0)[0]
	mine.immune_t = 0.0
	b.spells[1].charges = 1
	b.cast(1, mine)
	check(mine.stun_t == Rules.ENEMY_SHIFT_STUN, "enemy without the hex upgrade stuns for the base time")
	b.free()
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	game.choose_difficulty(Difficulty.APPRENTICE)
	game.choose_pack(0)
	game.player.gold = recharge_cost
	game._left_press(Hud.upgrade_rect(0).get_center())
	check(game.player.shift_recharge_upgraded and game.player.gold == 0, "recharge upgrade shop row works")
	game.player.gold = 3
	game._left_press(Hud.upgrade_rect(1).get_center())
	check(game.player.upgrade_level("charges") == 1 and game.player.gold == 0, "charges upgrade shop row works")
	game.player.gold = 8
	game._left_press(Hud.upgrade_rect(2).get_center())
	game._left_press(Hud.upgrade_rect(3).get_center())
	check(game.player.upgrade_level("heal") == 1 and game.player.upgrade_level("hex") == 1 and game.player.gold == 0,
		"heal and hex upgrade shop rows work")
	for i in Rules.WAND_UPGRADES.size():
		var row := Hud.upgrade_rect(i)
		var fight := Rules.FIGHT_RADIUS * Hud.FIGHT_HOVER_SCALE
		check(not row.intersects(Hud.shop_rect()) and row.end.y <= 720.0
			and not row.intersects(Rect2(Rules.FIGHT_CENTER - Vector2(fight, fight), Vector2(fight, fight) * 2.0))
			and row.end.y <= Hud.scroll_top() + Hud.SCROLL_LENGTH, "wand upgrade row %d sits on the scroll" % i)
	check(Rules.FIGHT_CENTER.x + Rules.FIGHT_RADIUS + 8 <= 1280 and Rules.FIGHT_CENTER.y + Rules.FIGHT_RADIUS + 8 <= 720,
		"fight button fits in the bottom-right corner")
	check(Hud.fight_glint(0.0) == 0.0 and is_equal_approx(Hud.fight_glint(Hud.FIGHT_GLINT_SWEEP * 0.5), 0.5)
		and Hud.fight_glint(Hud.FIGHT_GLINT_SWEEP + 0.01) == -1.0
		and is_equal_approx(Hud.fight_glint(Hud.FIGHT_GLINT_PERIOD + 0.36), 0.36 / Hud.FIGHT_GLINT_SWEEP),
		"fight button glint sweeps once at the start of every period")
	var hud: Hud = game.hud
	game.player.creatures.clear()
	check(not hud._fight_ready(), "fight button is idle without a fielded creature")
	check(Rules.wand_value("recharge", 0) == Rules.RECHARGE_TIME and Rules.wand_value("recharge", 1) == Rules.UPGRADED_RECHARGE_TIME
		and Rules.wand_value("charges", 0) == 1 and Rules.wand_value("charges", 2) == 3
		and Rules.wand_value("heal", 1) == Rules.UPGRADED_SHIFT_HEAL and Rules.wand_value("hex", 0) == Rules.ENEMY_SHIFT_STUN,
		"tooltip scenes read each wand upgrade value per level")
	game.scroll_open = 0.0
	check(hud.hovered_upgrade() == -1, "no wand upgrade tooltip while the scroll is rolled up")
	game.new_duel()
	check(not game.player.shift_recharge_upgraded and game.player.upgrades.is_empty(),
		"new duel resets permanent duel upgrades")
	game.free()
	check(CreatureDB.get_form("assassin").price == 2, "assassin costs two gold")
	var guardian_outcomes := CreatureDB.outcomes("guardian")
	check(guardian_outcomes[0].id == "turtle" and guardian_outcomes[0].chance == 0.55,
		"dominant transformation follows guardian defensive identity")
	for id in CreatureDB.all_ids():
		var outcomes := CreatureDB.outcomes(id)
		check(outcomes[0].chance == 0.55 and outcomes[1].chance == 0.30 and outcomes[2].chance == 0.15,
			"ordered decreasing probabilities for " + id)


func _test_ai_strategy() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	var state := WizardState.new(1)
	state.add_creature("guardian")
	state.add_creature("guardian")
	state.offers = ["", "", ""]
	EnemyAI.shop_step(state, rng, EnemyAI.DEFAULT_PROFILE)
	check(state.field_count() == 2 and state.creatures[0].merge_copies == 1,
		"AI keeps two fielded bodies instead of merging for no star")
	state = WizardState.new(1)
	for id in ["guardian", "berserker", "spearman", "archer", "cleric", "frost_mage"]:
		state.add_creature(id)
	var guard: OwnedCreature = state.creatures[0]
	guard.merge_copies = 2
	state.gold = 2
	state.offers = ["guardian", "", ""]
	var action := EnemyAI.shop_step(state, rng, EnemyAI.DEFAULT_PROFILE)
	check(action.get("kind") == "buy" and state.gold == 0 and state.creatures.size() == 7,
		"AI buys a completing duplicate with a full field instead of stopping")
	action = EnemyAI.shop_step(state, rng, EnemyAI.DEFAULT_PROFILE)
	check(action.get("kind") == "merge" and guard.stars == 1 and state.field_count() == 6,
		"AI upgrades a full team without removing a fielded body")
	_max_upgrades(state)
	state.gold = 4
	state.offers = ["peasant", "", ""]
	action = EnemyAI.shop_step(state, rng, EnemyAI.DEFAULT_PROFILE)
	check(action.get("kind") == "reroll" and state.gold == 3, "AI spends gold rerolling unhelpful offers")
	state.shift_recharge_upgraded = false
	state.gold = 4
	state.offers = ["", "", ""]
	action = EnemyAI.shop_step(state, rng, EnemyAI.DEFAULT_PROFILE)
	check(action.get("kind") == "upgrade" and state.shift_recharge_upgraded and state.gold == 0,
		"AI buys recharge upgrade from its own gold")
	var saver := WizardState.new(1)
	for id in ["guardian", "berserker", "spearman", "archer", "cleric"]:
		saver.add_creature(id)
	saver.offers = ["", "", ""]
	var bought := []
	for i in 5:
		saver.gold = 5
		bought.append(EnemyAI.shop_step(saver, rng, EnemyAI.DEFAULT_PROFILE).get("id", ""))
	check(bought == ["recharge", "charges", "charges", "hex", "heal"] and saver.start_charges() == 3,
		"AI buys wand upgrade levels in its saving order")
	state.gold = 10
	state.ai_rerolls = 2
	state.offers = ["peasant", "", ""]
	action = EnemyAI.shop_step(state, rng, EnemyAI.DEFAULT_PROFILE)
	check(action.get("kind") == "reroll" and state.gold == 9, "AI keeps looking for improvements after two rerolls")
	state.gold = Rules.REROLL_COST
	state.offers = ["peasant", "", ""]
	check(EnemyAI.shop_step(state, rng, EnemyAI.DEFAULT_PROFILE).is_empty() and state.gold == Rules.REROLL_COST,
		"AI keeps its last coin when a reroll would leave nothing for a purchase")
	state.gold = 2
	state.offers = ["guardian", "", ""]
	action = EnemyAI.shop_step(state, rng, EnemyAI.DEFAULT_PROFILE)
	check(action.get("kind") == "buy" and state.gold == 0,
		"AI starts collecting copies towards the next star of a fielded unit")

	state = WizardState.new(1)
	for id in ["guardian", "berserker", "spearman", "archer", "cleric", "frost_mage"]:
		state.add_creature(id)
	for id in ["peasant", "duelist", "assassin", "crossbowman", "pyromancer", "bard"]:
		state.add_creature(id)
	guard = state.creatures[0]
	guard.merge_copies = 2
	state.gold = 2
	state.offers = ["guardian", "", ""]
	action = EnemyAI.shop_step(state, rng, EnemyAI.DEFAULT_PROFILE)
	check(action.get("kind") == "merge" and action.get("cost") == 2 and state.gold == 0
		and guard.stars == 1 and state.free_slot() == -1 and state.field_count() == Rules.FIELD_CAP,
		"AI pays for a direct promotion even when the field and bench are full")
	state = WizardState.new(1)
	for id in ["guardian", "berserker", "spearman", "archer", "cleric", "frost_mage"]:
		state.add_creature(id).stars = Rules.MAX_STARS
	_max_upgrades(state)
	state.gold = 10
	state.offers = ["guardian", "pyromancer", ""]
	check(EnemyAI.shop_step(state, rng, EnemyAI.DEFAULT_PROFILE).is_empty() and state.gold == 10,
		"AI skips rerolls when the shop has no way to improve a max-rank team")
	var b := _new_battle()
	var weak_enemy := b.spawn(0, "peasant", Vector2(100, 350))
	b.spawn(1, "guardian", Vector2(100, 100))
	b.spells[1].charges = 3
	check(EnemyAI.choose_cast(b, 1) != weak_enemy, "AI avoids transforming a weak enemy into stronger expected forms")
	b.free()

	# Archmage strategy: its own profile and harvest economy; its opening is dealt.
	check(EnemyAI.profile_for(Difficulty.ARCHMAGE) == EnemyAI.ARCHMAGE_PROFILE
		and EnemyAI.profile_for(Difficulty.ADEPT) == EnemyAI.DEFAULT_PROFILE
		and EnemyAI.profile_for(Difficulty.APPRENTICE) == EnemyAI.DEFAULT_PROFILE,
		"only the archmage uses the tuned strategy profile")
	check(not EnemyAI.ARCHMAGE_PROFILE.has("pack"), "the archmage has no fixed opening")
	check(EnemyAI.choose_pack(rng, {"pack": 4}) == CreatureDB.PACKS[4], "simulations can force an opening")
	state = WizardState.new(1)
	for id in ["guardian", "berserker", "archer"]:
		state.add_creature(id)
	_max_upgrades(state)
	state.gold = 1
	state.offers = ["peasant", "", ""]
	action = EnemyAI.shop_step(state, rng)
	check(action.get("kind") == "buy" and state.harvest_total() == 1, "archmage fields a peasant for its harvest")
	var hexed := _new_battle()
	var leveled := hexed.spawn(0, "duelist", Vector2(100, 350))
	leveled.level = 4
	hexed.spawn(1, "guardian", Vector2(100, 100))
	hexed.spells[1].charges = 3
	check(EnemyAI.choose_cast(hexed, 1, EnemyAI.ARCHMAGE_PROFILE) == leveled,
		"archmage hexes a leveled enemy, counting the reset to level 1")
	hexed.free()


func _test_difficulty() -> void:
	var archmage := Difficulty.profile(Difficulty.ARCHMAGE)
	check(archmage.shop_noise == 0.05 and archmage.max_rerolls == -1 and not archmage.has("upgrade_gold")
		and archmage.replace and archmage.lock and archmage.smart_field,
		"archmage keeps the full-strength shopping policy")
	check(archmage.first_delay == Vector2(1.0, 2.0) and archmage.cast_delay == Vector2(0.6, 1.6)
		and archmage.retry_delay == 0.3 and archmage.threshold == 0.0 and archmage.blunder == 0.0,
		"archmage keeps the full-strength casting policy")
	var apprentice := Difficulty.profile(Difficulty.APPRENTICE)
	var adept := Difficulty.profile(Difficulty.ADEPT)
	check(apprentice.blunder > adept.blunder and adept.blunder > 0.0
		and apprentice.cast_delay.x > adept.cast_delay.x and adept.cast_delay.x > archmage.cast_delay.x,
		"easier levels cast more slowly and less accurately")

	# Exercise the real menu -> map -> duel -> map flow with an isolated save.
	var progress_path := "user://difficulty_test_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
	var game = load("res://main.tscn").instantiate()
	game.difficulty_progress_path = progress_path
	add_child(game)
	check(game.map_screen.visible and game.map_screen.on_title() and game.map_screen.title.visible and not game.hud.visible,
		"startup opens on the title, in the sky above the world map")
	for screen in [game.map_screen]:
		var no_text := true
		for button: Button in screen.buttons:
			no_text = no_text and button.text.is_empty() and button.tooltip_text.is_empty()
		check(no_text, "%s controls show neither text nor textual tooltips" % screen.name)
	var map = game.map_screen
	map._activate(0)
	check(game.phase == game.Phase.DIFFICULTY, "stages cannot be chosen from the title")
	map._tap_at(Vector2(640, 360))
	check(not map.title.animating(), "a tap finishes the title's animation")
	map._tap_at(map.title.get_global_transform_with_canvas() * map.title.medallion_center())
	check(map.visible and not map.on_title() and game.journey.available(0),
		"the island medallion takes the camera down to the islands, first stage available")
	map._process(map.PAN_TIME)
	check(map.menu_blend == 0.0 and not map.title.visible, "the camera pans down to the islands")
	game.show_menu()
	check(map.visible and map.on_title(), "Esc's show_menu pans back up to the title without leaving the map")
	game.show_map()
	map._process(map.PAN_TIME)
	game.choose_stage(6)
	check(game.phase == game.Phase.DIFFICULTY, "locked map stages cannot launch")
	game.map_screen._activate(0)
	_finish_transition(game)
	check(game.phase == game.Phase.PACK and game.hud.visible and not game.map_screen.visible,
		"a map seal starts pack selection")
	game.choose_pack(0)
	game.player.hp = 0.5
	game._on_battle_ended({"winner": 1, "survivors": 1})
	game.battle = Battle.new()
	game.add_child(game.battle)
	game._finish_round()
	check(game.journey.completed.is_empty(), "a defeat never completes a stage")
	game._left_press(Hud.RESTART_POS)
	_finish_transition(game)
	check(game.map_screen.visible, "the end-of-duel button returns to the map")
	for index in Journey.stage_count():
		game.choose_stage(index)
		check(game.enemy.ai_level == OpponentDB.ai_level(index), "stage %d selects its AI tier" % index)
		game.choose_pack(0)
		_finish_test_difficulty_win(game)
		check(index in game.journey.completed, "winning stage %d saves completion" % index)
		game._left_press(Hud.RESTART_POS)
		_finish_transition(game)
	check(game.journey.available(1) and game.journey.available(4), "completed intermediate stages remain replayable")
	check(game.journey.available(6), "the final seal remains replayable")
	game.free()
	game = load("res://main.tscn").instantiate()
	game.difficulty_progress_path = progress_path
	add_child(game)
	check(game.journey.completed == range(Journey.stage_count()), "map progress survives reloading")
	game._reset_difficulty_progress()
	check(game.journey.completed.is_empty() and not game.journey.available(1), "reset clears the map")
	game.free()
	var legacy := ConfigFile.new()
	legacy.set_value("progress", "unlocked_difficulty", Difficulty.ARCHMAGE)
	legacy.save(progress_path)
	game = load("res://main.tscn").instantiate()
	game.difficulty_progress_path = progress_path
	add_child(game)
	check(game.journey.available(10), "legacy archmage access migrates to the school entrance")
	game.free()
	DirAccess.remove_absolute(progress_path)

	# Apprentice shopping never buys the upgrade, locks, or sells a fielded creature.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var state := WizardState.new(1)
	state.ai_level = Difficulty.APPRENTICE
	for id in ["guardian", "berserker", "spearman", "archer", "cleric", "frost_mage"]:
		state.add_creature(id)
	state.gold = 1
	state.offers = ["guardian", "assassin", ""]
	EnemyAI.shop_step(state, rng)
	check(not state.locked[0], "apprentice does not lock unaffordable duplicates")
	state.gold = 12
	state.offers = ["", "", ""]
	EnemyAI.shop(state, rng)
	check(state.upgrades.is_empty(), "apprentice never buys wand upgrades")
	state.offers = ["pyromancer", "", ""]
	state.gold = 3
	state.ai_rerolls = 1
	var before := state.field_count()
	var action := EnemyAI.shop_step(state, rng)
	check(action.get("kind") != "sell" and state.field_count() == before, "apprentice never sells to replace")

	# Apprentice whims: one taste per creature for the whole duel, used both to
	# buy and to field. Sparring is the whimless reference kept for balancing.
	var spread: float = apprentice.get("whims", 0.0)
	var whims_ok := spread > 0.0 and state.ai_whims.size() == CreatureDB.shop_ids().size()
	for id in state.ai_whims:
		whims_ok = whims_ok and absf(state.ai_whims[id]) <= spread
	var drawn: Dictionary = state.ai_whims.duplicate()
	EnemyAI.shop_step(state, rng)
	check(whims_ok and state.ai_whims == drawn, "apprentice draws its whims once per duel")
	var sparring := Difficulty.profile(Difficulty.SPARRING)
	check(Difficulty.SPARRING >= Difficulty.COUNT and EnemyAI.profile_for(Difficulty.SPARRING) == EnemyAI.DEFAULT_PROFILE
		and sparring.get("whims", 0.0) == 0.0 and adept.get("whims", 0.0) == 0.0 and archmage.get("whims", 0.0) == 0.0
		and sparring.merged({"whims": spread}) == apprentice, "sparring is the apprentice without whims, outside the hat choice")
	for level in [Difficulty.ADEPT, Difficulty.SPARRING]:
		var calm := WizardState.new(1)
		calm.ai_level = level
		calm.offers = ["", "", ""]
		EnemyAI.shop_step(calm, rng)
		check(calm.ai_whims.is_empty(), "level %d has no whims" % level)
	var fan := WizardState.new(1)
	fan.ai_level = Difficulty.APPRENTICE
	fan.ai_whims = {"peasant": 500.0, "pyromancer": -500.0}
	fan.gold = 3
	fan.offers = ["pyromancer", "peasant", ""]
	action = EnemyAI.shop_step(fan, rng)
	check(action.get("kind") == "buy" and fan.creatures[0].form_id == "peasant", "apprentice buys its favourite creature")
	fan = WizardState.new(1)
	fan.ai_level = Difficulty.APPRENTICE
	fan.ai_whims = {"pyromancer": -500.0}
	for id in ["pyromancer", "peasant", "peasant", "spearman", "archer", "cleric", "bard"]:
		fan.add_creature(id)
	EnemyAI.arrange(fan)
	check(fan.creatures[0].form_id == "pyromancer" and not fan.creatures[0].is_fielded()
		and fan.field_count() == Rules.FIELD_CAP, "apprentice benches a creature it dislikes")

	var b := _new_battle()
	var ally := b.spawn(1, "guardian", Vector2(100, 100))
	var foe := b.spawn(0, "peasant", Vector2(100, 350))
	foe.immune_t = 1.0
	var picks := {}
	for i in 20:
		picks[EnemyAI.random_cast_target(b)] = true
	check(picks.size() == 1 and picks.has(ally), "clumsy casts only pick creatures that can be shapeshifted")
	b.free()


## Every transition covers the map, starts the duel only once covered, blocks
## input meanwhile, and brings the player back to the map the same way.
func _test_screen_transition() -> void:
	var game = load("res://main.tscn").instantiate()
	game.difficulty_progress_path = "user://transition_test_%d.cfg" % OS.get_process_id()
	add_child(game)
	game.map_screen.show_islands(true)
	for style in 2: # twice in a row: the transition can run again
		game.enter_stage(0)
		check(game.transition.active() and game.phase == game.Phase.DIFFICULTY, "style %d covers the map before the duel" % style)
		game.enter_stage(0)
		game.transition._process(ScreenTransition.COVER * 0.5)
		check(game.phase == game.Phase.DIFFICULTY and game.transition.coverage() > 0.3, "style %d is half way over the map" % style)
		game.transition._process(ScreenTransition.COVER * 0.5 + 0.01)
		check(game.phase == game.Phase.PACK and game.hud.visible, "style %d starts the duel once the screen is covered" % style)
		game.transition._process(ScreenTransition.HOLD + ScreenTransition.REVEAL)
		check(not game.transition.active() and game.map_screen.scale == Vector2.ONE and game.map_screen.position == Vector2.ZERO,
			"style %d ends with the map at its normal scale" % style)
		game.leave_duel()
		_finish_transition(game)
		check(game.phase == game.Phase.DIFFICULTY and game.map_screen.visible, "style %d brings the player back to the map" % style)
	game.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://transition_test_%d.cfg" % OS.get_process_id()))


## Plays the map <-> duel transition to its end at once (screens swap while covered).
func _finish_transition(game: Node) -> void:
	game.transition._process(10.0)


func _finish_test_difficulty_win(game: Node) -> void:
	game.enemy.hp = 0.5
	game.battle = Battle.new()
	game.add_child(game.battle)
	game._on_battle_ended({"winner": 0, "survivors": 1})
	game._finish_round()


func _simulate_duels() -> void:
	for casting in [true, false]:
		var durations := []
		var rounds := []
		var draws := 0
		var combats := 0
		for duel in 20:
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 + duel
			var states: Array[WizardState] = [WizardState.new(0), WizardState.new(1)]
			for s in states:
				s.take_starting_pack(EnemyAI.choose_pack(rng))
			var round_num := 0
			while states[0].hp > 0 and states[1].hp > 0 and round_num < 40:
				round_num += 1
				for s in states:
					s.gold += Rules.income(round_num)
					s.refresh_offers(rng)
					EnemyAI.shop(s, rng)
				var b := _new_battle()
				b.rng.seed = rng.randi()
				b.ai_casting = [casting, casting]
				b.casting_enabled = casting
				b.setup(states, rng.randi())
				while not b.finished:
					b.step(1.0 / 60.0)
				combats += 1
				durations.append(b.result.time)
				if b.result.winner >= 0:
					states[1 - b.result.winner].take_round_damage(b.result.survivors)
				else:
					draws += 1
				b.free()
			rounds.append(round_num)
			check(round_num < 40, "duel ends (casting=%s, duel %d)" % [casting, duel])
		var avg_t := 0.0
		for t in durations:
			avg_t += t
		avg_t /= durations.size()
		var avg_r := 0.0
		for r in rounds:
			avg_r += r
		avg_r /= rounds.size()
		print("casting=%s: %d combats, avg combat %.1f s, avg duel %.1f rounds, draws %d" % [casting, combats, avg_t, avg_r, draws])


func _test_day_night_cycle() -> void:
	var cycle = preload("res://scripts/ui/day_night_sky.gd").new()
	for index in 4:
		var state: Dictionary = cycle.palette(index / 4.0)
		check(state.top.is_equal_approx(cycle.TOP[index]) and state.bottom.is_equal_approx(cycle.BOTTOM[index]),
			"sky cycle reaches palette %d" % index)
	check(cycle.palette(0.75).night == 1.0 and cycle.palette(0.0).night == 0.0,
		"stars and moon belong to the night phase")
	var between: Dictionary = cycle.palette(0.125)
	check(not between.top.is_equal_approx(cycle.TOP[0]) and not between.top.is_equal_approx(cycle.TOP[1]),
		"sky interpolates between daytime palettes")
	for boundary in [0.0, 0.25, 0.5, 0.75, 1.0]:
		check(cycle.palette(boundary - 0.000001).top.is_equal_approx(cycle.palette(boundary + 0.000001).top),
			"sky has no colour jump at phase %s" % boundary)
	cycle.elapsed = cycle.cycle_seconds - 1.0
	cycle.advance(2.0)
	check(is_equal_approx(cycle.elapsed, 1.0), "sky clock wraps after a full cycle")
	for phase in [0.0, 0.1, 0.33, 0.5, 0.62, 0.9]:
		var weights: PackedFloat32Array = cycle.weights(phase)
		check(is_equal_approx(weights[0] + weights[1] + weights[2] + weights[3], 1.0), "sky state weights add up to 1 at %s" % phase)
	check(cycle.weights(0.0)[0] == 1.0 and cycle.weights(0.75)[3] == 1.0, "full day and full night have their own weight")
	_test_map_ambience()


## The map's nature ambience follows the sky and fades with the map.
func _test_map_ambience() -> void:
	var game = load("res://main.tscn").instantiate()
	game.difficulty_progress_path = "user://ambience_test_%d.cfg" % OS.get_process_id()
	add_child(game)
	var map = game.map_screen
	var ambience: MapAmbience = map.ambience
	ambience.set_process(false)
	game.show_map()
	map.sky.elapsed = 0.0
	check(ambience.bed_level("wind_day") == 1.0 and ambience.bed_level("crickets") == 0.0
		and ambience.call_rate("bird") > 0.0 and ambience.call_rate("owl") == 0.0,
		"by day the map has wind and birds, no crickets or owl")
	map.sky.elapsed = map.sky.cycle_seconds * 0.75
	check(ambience.bed_level("wind_day") == 0.0 and ambience.bed_level("crickets") > 0.0
		and ambience.call_rate("bird") == 0.0 and ambience.call_rate("owl") > 0.0,
		"at night the map has crickets and an owl, no birds")
	map.sky.elapsed = map.sky.cycle_seconds * 0.25
	check(ambience.call_rate("chime") > 0.0, "wind chimes ring in the golden mist")
	ambience.advance(10.0)
	check(ambience.presence == 1.0 and ambience.beds["wind_day"].playing, "the ambience fades in on the map")
	game.choose_stage(0)
	ambience.advance(10.0)
	check(ambience.presence == 0.0 and not ambience.beds["wind_day"].playing, "a duel fades the ambience out and stops it")
	game.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ambience_test_%d.cfg" % OS.get_process_id()))


func _test_journey_navigation() -> void:
	# Give injected pointer events the same window coordinates as the viewport.
	var previous_size := get_window().size
	get_window().size = Vector2i(1280, 720)
	var game = load("res://main.tscn").instantiate()
	game.difficulty_progress_path = "user://journey_ui_test_%d.cfg" % OS.get_process_id()
	add_child(game)
	game.set_physics_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	var map = game.map_screen
	map.show_islands(true) # the game opens on the title, one screen above
	check(map.find_children("*", "ScrollContainer", true, false).is_empty(), "map has no scrolling container")
	check(map.get_children().filter(func(c): return c is CanvasItem and not c is TitleScreen).size() == 2,
		"map shows only the sky and islands, without a UI banner")
	_check_whole_map_visible(map, "landscape")
	var initial_transform: Transform2D = map.world.transform
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(640, 400)
	Input.parse_input_event(motion)
	await get_tree().process_frame
	var wheel := InputEventMouseButton.new()
	wheel.position = motion.position
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	Input.parse_input_event(wheel)
	await get_tree().process_frame
	check(map.world.transform == initial_transform, "mouse wheel does not move the fitted map")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(640, 400)
	touch.pressed = true
	Input.parse_input_event(touch)
	await get_tree().process_frame
	var swipe := InputEventScreenDrag.new()
	swipe.index = 0
	swipe.position = Vector2(640, 550)
	swipe.relative = Vector2(0, 150)
	Input.parse_input_event(swipe)
	await get_tree().process_frame
	touch = touch.duplicate()
	touch.position = swipe.position
	touch.pressed = false
	Input.parse_input_event(touch)
	await get_tree().process_frame
	check(map.world.transform == initial_transform and game.phase == game.Phase.DIFFICULTY,
		"swipes neither move the map nor launch a duel")
	var pos: Vector2 = map.buttons[0].get_global_transform_with_canvas() * (map.buttons[0].size * 0.5)
	motion = InputEventMouseMotion.new()
	motion.position = pos
	Input.parse_input_event(motion)
	await get_tree().process_frame
	var click := InputEventMouseButton.new()
	click.position = pos
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await get_tree().process_frame
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	await get_tree().process_frame
	_finish_transition(game)
	check(game.phase == game.Phase.PACK and game.hud.visible, "a fitted map button launches its duel")
	check(get_window().content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "duel restores its original viewport layout")
	var sky_time: float = map.sky.elapsed
	map.sky._process(15.0)
	check(is_equal_approx(map.sky.elapsed, sky_time), "hidden map pauses its sky clock")
	game.new_duel()
	check(is_equal_approx(map.sky.elapsed, sky_time), "returning to the map retains its time of day")
	# Every selectable stage must choose its own board, even after a school duel.
	game.journey.completed.assign(range(Journey.stage_count()))
	for index in [14, 5, 0, 1, 2, 6, 9, 10]:
		game.new_duel()
		game.choose_stage(index)
		var expected: String = ["forest", "town", "school"][OpponentDB.zone(index)]
		check(game.board_view.environment == expected, "stage %d selects %s tiles" % [index, expected])
		var hearts: int = [3, 6, 10][OpponentDB.zone(index)]
		var enemy_hearts: int = 1 if index == 0 else hearts # the hunter falls after one round
		check(game.player.hp == hearts and game.enemy.hp == enemy_hearts
			and game.player.max_hp == hearts and game.enemy.max_hp == enemy_hearts,
			"stage %d gives the player %d and the opponent %d full hearts" % [index, hearts, enemy_hearts])
		game.choose_pack(0)
		check(game.board_view.environment == expected, "stage %d keeps its terrain during preparation" % index)
		if index in [0, 5, 10]:
			_finish_enemy_preparation(game)
			game.start_combat()
			check(game.phase == game.Phase.COMBAT and game.board_view.environment == expected,
				"%s terrain persists during combat" % expected)
	game.new_duel()
	game.choose_difficulty(Difficulty.APPRENTICE)
	check(game.board_view.environment == Terrain.DEFAULT, "direct test duels restore the default forest terrain")
	check(game.player.hp == Rules.WIZARD_HP and game.enemy.hp == Rules.WIZARD_HP,
		"direct developer duels retain the default ten hearts")
	game.new_duel()
	get_window().size = Vector2i(390, 844)
	await get_tree().process_frame
	await get_tree().process_frame
	_check_whole_map_visible(map, "portrait")
	# A touch tap on the portrait map must use the same transformed hit target.
	pos = map.buttons[0].get_global_transform_with_canvas() * (map.buttons[0].size * 0.5)
	touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = pos
	touch.pressed = true
	map._input(touch)
	touch = touch.duplicate()
	touch.pressed = false
	map._input(touch)
	_finish_transition(game)
	check(game.phase == game.Phase.PACK, "portrait map opponents can be selected by touch")
	game.free()
	get_window().size = previous_size


func _test_progress_reset_shortcuts() -> void:
	var path := "user://reset_shortcuts_%d.cfg" % OS.get_process_id()
	var game = load("res://main.tscn").instantiate()
	game.difficulty_progress_path = path
	add_child(game)
	game.set_physics_process(false)
	for use_alt in [false, true]:
		for on_map in [false, true]:
			game.journey.completed.assign(range(5))
			game.journey.introduced.assign([Ruleset.FRENZY])
			game.journey.lessons_done.assign([Ruleset.FRENZY])
			game._save_difficulty_progress(Difficulty.ADEPT)
			if on_map:
				game.show_map()
			else:
				game.show_menu()
			await get_tree().process_frame
			var key := InputEventKey.new()
			key.keycode = KEY_R
			key.shift_pressed = true
			key.alt_pressed = use_alt
			key.ctrl_pressed = not use_alt
			key.pressed = true
			Input.parse_input_event(key)
			await get_tree().process_frame
			check(game.journey.completed.is_empty() and game.journey.introduced.is_empty()
				and game.journey.lessons_done.is_empty(), "reset shortcut clears progress with focused menu/map controls")
			var saved := ConfigFile.new()
			saved.load(path)
			check(saved.get_value("journey", "opponents", [0]).is_empty(), "reset shortcut persists the empty journey")
	game.choose_stage(0)
	game.journey.completed.assign([0])
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.shift_pressed = true
	key.alt_pressed = true
	key.pressed = true
	game._input(key)
	check(game.journey.completed == [0], "reset shortcut does not erase progress during a duel")
	game.free()
	DirAccess.remove_absolute(path)


func _check_whole_map_visible(map: Node2D, orientation: String) -> void:
	var viewport := map.get_viewport_rect()
	for index in map.buttons.size():
		check(viewport.encloses(map.buttons[index].get_global_rect()), "%s stage %d fits on screen" % [orientation, index])
	# Includes treetops, tower roofs, cliffs and detached rock fragments.
	var art_bounds := Rect2(-245, -185, 490, 475)
	var island_bounds: Array[Rect2] = []
	for index in map.islands.size():
		var bounds: Rect2 = map.islands[index].get_global_transform_with_canvas() * art_bounds
		island_bounds.append(bounds)
		check(viewport.encloses(bounds), "%s island %d fits entirely on screen" % [orientation, index])
	for first in island_bounds.size():
		for second in range(first + 1, island_bounds.size()):
			check(not island_bounds[first].intersects(island_bounds[second]),
				"%s islands %d and %d never overlap" % [orientation, first, second])
	check(map.bridges.size() == 2, "%s map has two continuous bridges" % orientation)
	for index in map.bridges.size():
		var bridge = map.bridges[index]
		var start: Vector2 = map.islands[index].transform.affine_inverse() * bridge.from_point
		var finish: Vector2 = map.islands[index + 1].transform.affine_inverse() * bridge.to_point
		var shore := Rect2(-240, -96, 480, 192)
		if index == 1:
			# The crystal steps rise from the keep's roof, beside the king.
			check(start.is_equal_approx(map.STEPS_START) and shore.has_point(finish),
				"%s crystal steps leave the keep for the school's shore" % orientation)
			continue
		check(shore.has_point(start) and shore.has_point(finish),
			"%s bridge %d joins the islands at their shores" % [orientation, index])
	_check_map_paths(map, orientation)


## Every road between consecutive opponents is a clean dotted line: evenly
## spaced dots that never overlap, a few on short hops, none on an opponent,
## and never beside another road.
func _check_map_paths(map: Node2D, orientation: String) -> void:
	var diameter := 7.0 # the dots' dark rim
	for stage in range(1, map.buttons.size()):
		var dots: PackedVector2Array = map._paths[stage]
		check(dots.size() >= map.MIN_DOTS and dots.size() <= map.MAX_DOTS,
			"%s road %d has %d dots" % [orientation, stage, dots.size()])
		var gaps: Array[float] = []
		for index in range(1, dots.size()):
			gaps.append(dots[index - 1].distance_to(dots[index]))
		check(gaps.min() > diameter + 1.0 and gaps.max() < map.DOT_SPACING * 1.4,
			"%s road %d spaces its dots evenly without overlap (%.1f-%.1f)" % [orientation, stage, gaps.min(), gaps.max()])
		var on_opponent := false
		for dot in dots:
			for other in map.buttons.size():
				on_opponent = on_opponent or map.in_footprint(dot, other)
		check(not on_opponent, "%s road %d never runs over an opponent" % [orientation, stage])
		for other in range(stage + 1, map.buttons.size()):
			var nearest := INF
			for dot in dots:
				for other_dot: Vector2 in map._paths[other]:
					nearest = minf(nearest, dot.distance_to(other_dot))
			check(nearest > diameter + 1.0, "%s roads %d and %d stay apart" % [orientation, stage, other])
	var town: Node2D = map.islands[1]
	var gate: Vector2 = town.position + map.ROAD_ENDS[9] * town.scale
	check(map._paths[9][-1].distance_to(gate) < 1.0, "%s the road to the king ends at his keep's gate" % orientation)


func _test_journey_health() -> void:
	var game = load("res://main.tscn").instantiate()
	var progress_path := "user://journey_health_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
	game.difficulty_progress_path = progress_path
	add_child(game)
	game.set_physics_process(false)
	game.journey.completed.assign(range(Journey.stage_count()))
	for index in [0, 5, 10, 0]:
		game.new_duel()
		game.choose_stage(index)
		game.choose_pack(0)
		var hearts: int = {0: 3, 5: 6, 10: 10}[index]
		var lost: float = game.player.take_round_damage(1)
		check(lost == 0.5 and game.player.hp == hearts - 0.5 and game.player.max_hp == hearts,
			"%d-heart duels preserve half-heart damage and capacity" % hearts)
		var previous: Array = game.hud._wizard_key(game.player)
		game.player.max_hp += 1
		check(previous != game.hud._wizard_key(game.player), "changing heart capacity invalidates the cached HUD")
		game.player.max_hp = hearts
		game.battle = Battle.new()
		game.add_child(game.battle)
		var enemy_hearts: int = 1 if index == 0 else hearts
		check(game.enemy.max_hp == enemy_hearts, "the hunter has a single heart; other opponents their zone's")
		game._on_battle_ended({"winner": 0, "survivors": hearts * 2 + 2})
		check(game.enemy.hp == 0 and game.last_damage == enemy_hearts,
			"lethal damage is capped at %d remaining hearts" % enemy_hearts)
		game._finish_round()
		check(game.phase == game.Phase.OVER and index in game.journey.completed,
			"a %d-heart duel ends and records the stage victory" % hearts)
	game.free()
	DirAccess.remove_absolute(progress_path)


func _test_journey_discovery() -> void:
	var game = load("res://main.tscn").instantiate()
	var path := "user://discovery_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
	game.difficulty_progress_path = path
	add_child(game)
	game.set_physics_process(false)
	var map = game.map_screen
	map.set_process(false)
	check(map.discovered == [0] and map.buttons[0].visible,
		"a new journey shows only the first encounter")
	for index in range(1, Journey.stage_count()):
		check(not map.buttons[index].visible and map.visible_path_points(index) == 0,
			"undiscovered stage %d has no opponent, lock or path" % index)
	check(map.bridges[0].visible and map.bridges[1].visible,
		"both complete bridges are visible from the beginning")
	map._activate(1)
	check(game.phase == game.Phase.DIFFICULTY, "hidden encounter cannot be activated")
	game.choose_stage(0)
	game.choose_pack(0)
	_finish_test_difficulty_win(game)
	game.new_duel()
	check(game.journey.available(1) and not game.journey.available(2),
		"winning reveals only the immediate successor in the linear journey")
	check(map.revealing == 1 and not map.buttons[1].visible and map.visible_path_points(1) == 0,
		"returning from victory starts a path before showing its opponent")
	var ticks: Array[int] = []
	map.path_point_appeared.connect(func(stage: int, point: int):
		if stage == 1:
			ticks.append(point))
	Sfx._last_played.erase("ui/map_step")
	map.advance_discovery(1.0)
	var count: int = map.visible_path_points(1)
	check(count > 0 and count < map._paths[1].size() and ticks.size() == count,
		"the trace emits points progressively and in order")
	check(not Sfx.enabled or Sfx._last_played.has("ui/map_step"), "new points play a muffled tap")
	map._activate(1)
	check(game.phase == game.Phase.DIFFICULTY, "the successor cannot launch during its reveal")
	var elapsed: float = map.reveal_elapsed
	game.show_menu()
	map._process(2.0)
	check(map.reveal_elapsed == elapsed, "leaving the map pauses its reveal")
	game.show_map()
	check(map.reveal_elapsed == elapsed and map.revealing == 1,
		"returning resumes the same reveal without replaying its beginning")
	Sfx._last_played.erase("ui/map_opponent_appear")
	map.advance_discovery(map.TRACE_DURATION - elapsed + 0.001)
	check(map.buttons[1].visible and map.buttons[1].disabled,
		"the opponent appears only when the path reaches it")
	check(map.appearing == 1 and map.figures[1].clip_contents and map._rise(map.appear_elapsed) == 0.0,
		"the opponent starts below the ground at the end of its path")
	map.advance_discovery(map.RISE_START + 0.05)
	check(not Sfx.enabled or Sfx._last_played.has("ui/map_opponent_appear"), "the opponent pops out of the ground")
	map.advance_discovery(map.REVEAL_DURATION - map.TRACE_DURATION)
	check(map.revealing == -1 and not map.buttons[1].disabled and not map.figures[1].clip_contents,
		"the reveal finishes with a playable opponent standing on the ground")
	check(map.appearing == 1, "its island bits still settle once it is playable")
	map.advance_discovery(map.BURST_DURATION)
	check(map.appearing == -1, "the appearance ends once its bits have settled")
	var old_ticks := ticks.size()
	game.new_duel()
	check(map.revealing == -1 and ticks.size() == old_ticks,
		"known paths are not redrawn on later visits")
	for index in range(1, Journey.stage_count() - 1):
		game.choose_stage(index)
		game.choose_pack(0)
		_finish_test_difficulty_win(game)
		game.new_duel()
		check(map.revealing == index + 1, "stage %d discovers its successor" % index)
		if index == 4:
			var start: Vector2 = map.bridges[0].from_point
			var finish: Vector2 = map.bridges[0].to_point
			map.advance_discovery(2.0)
			check(map.bridges[0].visible and map.bridges[1].visible
				and map.bridges[0].from_point == start and map.bridges[0].to_point == finish
				and not map.buttons[5].visible,
				"points advance while both bridges stay complete and the next opponent remains hidden")
		map.advance_discovery(map.REVEAL_DURATION + 0.1)
		check(map.buttons[index + 1].visible and not map.buttons[index + 1].disabled,
			"the next stage becomes available after its animation")
	check(map.bridges[0].visible and map.bridges[1].visible,
		"discovery never changes bridge visibility")
	game._reset_difficulty_progress()
	check(map.discovered == [0] and map.revealing == -1
		and map.bridges[0].visible and map.bridges[1].visible,
		"reset removes discoveries while keeping the complete bridges")
	game.free()
	DirAccess.remove_absolute(path)
	var legacy := ConfigFile.new()
	legacy.set_value("journey", "completed", [0, 2, 3, 5])
	var journey := Journey.new()
	journey.restore(legacy, Difficulty.APPRENTICE)
	check(journey.completed == range(10) and journey.available(10),
		"branching saves retain their furthest earned access on the linear route")
	for entry in [[[], 0], [[0], 1], [[0, 1, 2], 5], [[0, 1, 2, 3, 4, 5], 10], [[0, 1, 2, 3, 4, 5, 6], 15]]:
		var old_save := ConfigFile.new()
		old_save.set_value("journey", "completed", entry[0])
		var migrated := Journey.new()
		migrated.restore(old_save, Difficulty.APPRENTICE)
		check(migrated.completed.size() == entry[1], "seven-stage saves migrate to %d completed opponents" % entry[1])


func _test_journey_rules() -> void:
	check(OpponentDB.count() == 15 and OpponentDB.zone(4) == 0 and OpponentDB.zone(5) == 1 and OpponentDB.zone(14) == 2,
		"fifteen opponents, five per zone")
	check(OpponentDB.is_boss(4) and OpponentDB.is_boss(9) and OpponentDB.is_boss(14) and not OpponentDB.is_boss(3),
		"the fifth opponent of each zone is its boss")
	var introduced := []
	for index in OpponentDB.count():
		var o: Dictionary = OpponentDB.get_opponent(index)
		if o.rule != "":
			check(o.rule in Ruleset.ALL and o.rule not in introduced, "opponent %d introduces a new existing rule" % index)
			introduced.append(o.rule)
		var rules := OpponentDB.ruleset(index)
		var pack := OpponentDB.pack_index(index)
		check((pack >= 0) == (o.pack != ""), "opponent %d names an existing composition" % index)
		if pack >= 0:
			check(rules.allows_pack(OpponentDB.packs_for(index)[pack]), "opponent %d opens with creatures already introduced" % index)
		for id in rules.shop_ids():
			check(rules.allows_form(id), "stage %d offers only introduced creatures" % index)
	check(introduced.size() == Ruleset.ALL.size(), "the journey introduces every rule")
	check(OpponentDB.ruleset(13).is_complete() and not OpponentDB.ruleset(12).is_complete()
		and OpponentDB.get_opponent(14).rule == "", "the last rule arrives before the archmage, who adds none")
	check(not OpponentDB.ruleset(5).allows_form("peasant") and OpponentDB.ruleset(6).allows_form("peasant")
		and not OpponentDB.ruleset(7).allows_form("pyromancer") and OpponentDB.ruleset(8).allows_form("frost_mage"),
		"peasants arrive with the innkeeper and casters with the court mage")

	# Wizard state: shop, trade, merge, harvest and upgrades follow the rules.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var s := WizardState.new(0)
	s.rules = OpponentDB.ruleset(0)
	s.gold = 20
	s.refresh_offers(rng)
	check(s.offers.count("") == Rules.SHOP_SIZE and not s.can_buy(0), "no stall before the lumberjack")
	s.take_round_damage(2)
	check(s.gold == 20, "no gold for lost hearts before the shop")
	s.rules = OpponentDB.ruleset(4)
	s.refresh_offers(rng)
	check(s.offers[0] != "" and s.can_buy(0), "the stall is open from the lumberjack on")
	check(not s.can_reroll() and not s.toggle_lock(0), "no reroll or lock before the merchant")
	var a := s.add_creature("archer")
	var b := s.add_creature("archer")
	check(not s.can_merge(a, b) and not s.can_sell(a) and not s.sell(a), "no merge before the thief and no selling before the merchant")
	s.add_creature("peasant")
	check(s.harvest_total() == 0, "no harvest before the innkeeper")
	check(not s.can_buy_upgrade("recharge") and EnemyAI.next_upgrade(s) == "", "no wand upgrade before the school")
	s.rules = OpponentDB.ruleset(10)
	check(s.can_reroll() and s.can_merge(a, b) and s.harvest_total() == 1, "the town introduces trading, harvest and merging")
	check(s.can_buy_upgrade("recharge") and not s.can_buy_upgrade("hex") and EnemyAI.next_upgrade(s) == "recharge",
		"the apprentice introduces only the fast recharge")

	# Enemy shopping does nothing before the shop.
	var e := WizardState.new(1)
	e.rules = OpponentDB.ruleset(0)
	e.ai_level = Difficulty.ARCHMAGE
	e.add_creature("archer")
	e.gold = 20
	check(EnemyAI.shop_step(e, rng).is_empty() and e.gold == 20, "the hunter never shops")

	# Combat: wand, hex, animal bonuses and frenzy.
	var player := WizardState.new(0)
	var foe := WizardState.new(1)
	foe.magic = false
	for state in [player, foe]:
		state.rules = OpponentDB.ruleset(2)
	var battle := Battle.new()
	add_child(battle)
	var teams: Array[WizardState] = [player, foe]
	battle.setup(teams, 3)
	var mine := battle.spawn(0, "guardian", Vector2(200, 300))
	var theirs := battle.spawn(1, "guardian", Vector2(200, 80))
	check(battle.can_cast[0] and not battle.can_cast[1], "a wizard without magic never casts")
	check(not battle.cast(0, theirs) and battle.cast(0, mine), "the druid's duel allows blessings but no hex")
	battle.time = 50.0
	battle.step(0.1)
	check(battle.frenzy_level == 0, "no frenzy before the king")
	var blessed := battle.spawn(0, "peasant", Vector2(100, 400))
	blessed.ability_timer = 0.0
	blessed.transform_to("rabbit", true)
	check(is_equal_approx(blessed.ability_timer, CreatureDB.get_form("rabbit").cd), "no animal bonus before the archdruid")
	battle.free()
	var hunter_player := WizardState.new(0)
	hunter_player.rules = OpponentDB.ruleset(0)
	check(not hunter_player.can_cast(), "the player has no wand before the druid")


## The wand scroll holds only the upgrades the journey has introduced: no locked
## rows, and the parchment is just long enough for them.
func _test_scroll_shows_introduced_upgrades() -> void:
	var full := Ruleset.new()
	check(Hud.scroll_length(full) == Hud.SCROLL_LENGTH and Hud.upgrade_rect(3, full) == Hud.upgrade_rect(3),
		"the complete rules keep the four-row scroll")
	var apprentice := OpponentDB.ruleset(10)
	check(Hud.scroll_length(apprentice) == Hud.SCROLL_LENGTH - 3 * Hud.UPGRADE_STEP,
		"the apprentice's scroll holds a single row")
	var caretaker := OpponentDB.ruleset(11)
	var hex := Rules.WAND_UPGRADES.find("hex")
	check(Hud.upgrade_rect(hex, caretaker) == Hud.upgrade_rect(1), "the long hex closes up under the fast recharge")
	check(Hud.upgrade_rect(hex, caretaker).end.y <= Hud.scroll_top() + Hud.scroll_length(caretaker),
		"introduced rows fit the shortened scroll")
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	game.set_physics_process(false)
	game.difficulty_progress_path = "user://scroll_rows_test_%d.cfg" % OS.get_process_id()
	game.journey.completed.assign(range(Journey.stage_count()))
	game.choose_stage(11)
	game.choose_pack(0)
	game.player.gold = 50
	game._left_press(Hud.upgrade_rect(hex, game.ruleset).get_center())
	check(game.player.upgrade_level("hex") == 1, "clicking the closed-up row buys the long hex")
	game.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://scroll_rows_test_%d.cfg" % OS.get_process_id()))


## The thief demonstrates a merge until the player's first one; a full board
## refuses an empty-cell drop visibly and identical creatures can still be placed.
func _test_merge_lesson_and_full_board() -> void:
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	game.set_physics_process(false)
	game.difficulty_progress_path = "user://merge_lesson_test_%d.cfg" % OS.get_process_id()
	game.journey.completed.assign(range(Journey.stage_count()))
	game.journey.lessons_done.clear()
	game.choose_stage(7)
	game.choose_pack(0)
	game.enemy_preparing = false
	game.shop_out = 0.0
	var form: String = game.player.creatures[0].form_id
	game.player.gold = 30
	for c: OwnedCreature in game.player.creatures.duplicate():
		if c != game.player.creatures[0]:
			game.player.creatures.erase(c)
	for i in Rules.SHOP_SIZE:
		game.player.offers[i] = ""
	check(game.merge_demo().is_empty(), "no merge demonstration without a copy to merge")
	game.player.offers[0] = form
	var demo: Dictionary = game.merge_demo()
	check(not demo.is_empty() and demo.from == Hud.offer_token_pos(0), "an identical offer is demonstrated onto its copy")
	# A second identical creature can be placed on an empty cell.
	var empty := Vector2i(0, 5)
	game._left_press(Hud.offer_rect(0).get_center())
	game.shop_drag_position = Rules.BOARD_POS + Rules.cell_center(empty)
	game.shop_drag_active = true
	game._left_release(Rules.BOARD_POS + Rules.cell_center(empty))
	check(game.player.at_cell(empty) != null and game.player.at_cell(empty).form_id == form and game.player.field_count() == 2,
		"an identical creature can be placed beside its copy")
	demo = game.merge_demo()
	check(not demo.is_empty() and demo.target in game.player.creatures, "two copies on the board are demonstrated")
	game._left_press(demo.from)
	game._left_release(demo.to)
	check(game.merge_lesson_done and game.merge_demo().is_empty(), "the first merge ends the demonstration")
	check(Ruleset.MERGE in game.journey.lessons_done, "the merge lesson is remembered")
	# Replaying the thief: an identical pair, but no demonstration any more.
	game.new_duel()
	game.choose_stage(7)
	game.choose_pack(0)
	game.enemy_preparing = false
	game.shop_out = 0.0
	game.player.offers[0] = game.player.creatures[0].form_id
	check(game.merge_demo().is_empty(), "the merge demonstration never returns once done")
	var legacy := ConfigFile.new()
	legacy.set_value("journey", "cast_lessons", [Ruleset.WAND])
	var restored := Journey.new()
	restored.restore(legacy, Difficulty.APPRENTICE)
	check(restored.lessons_done == [Ruleset.WAND], "lessons saved under the earlier key are kept")
	# Full board: an empty cell refuses a new creature and the pips flash.
	while game.player.field_count() < Rules.FIELD_CAP:
		game.player.add_creature("guardian")
	game.player.offers[1] = "archer"
	var free := Vector2i(-1, -1)
	for x in Rules.COLS:
		if game.player.at_cell(Vector2i(x, 5)) == null:
			free = Vector2i(x, 5)
	check(game.board_full_for(OwnedCreature.new("archer")), "a full board refuses a creature from outside it")
	game._left_press(Hud.offer_rect(1).get_center())
	game.shop_drag_position = Rules.BOARD_POS + Rules.cell_center(free)
	game.shop_drag_active = true
	game._left_release(Rules.BOARD_POS + Rules.cell_center(free))
	check(game.player.at_cell(free) == null and game.field_full_flash > 0.0, "a refused drop on a full board flashes the capacity pips")
	game.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://merge_lesson_test_%d.cfg" % OS.get_process_id()))


## The druid's and the witch's duels stop until the player tries their cast;
## other forest duels keep running.
func _test_learning_pause() -> void:
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	game.set_physics_process(false)
	game.difficulty_progress_path = "user://learning_pause_test_%d.cfg" % OS.get_process_id()
	game.journey.completed.assign(range(Journey.stage_count()))
	game.journey.lessons_done.clear()
	for index in [1, 2, 3]:
		game.new_duel()
		game.choose_stage(index)
		game.choose_pack(0)
		game._advance_enemy_preparation(1.0)
		game.start_combat()
		var stops: bool = index != 2
		check(game.awaiting_learning_cast() == stops and (game.learning_cast_target() != null) == stops,
			"forest %d %s" % [index, "stops while its cast cue shows" if stops else "shows no cast cue and keeps running"])
		var before: float = game.battle.time
		game._physics_process(0.5)
		check((game.battle.time == before) == stops, "forest %d combat time %s" % [index, "is frozen" if stops else "runs"])
		if stops:
			var target: Unit = game.learning_cast_target()
			check(target.team == (0 if index == 1 else 1), "the cue aims at an ally, then at a foe")
			game._cast_at(Rules.BOARD_POS + target.position)
			check(game.learning_cast_tried and not game.awaiting_learning_cast(), "the cast releases the duel")
			game._physics_process(0.5)
			check(game.battle.time > before, "combat resumes after the lesson cast")
	check(game.journey.lessons_done == [Ruleset.WAND, Ruleset.HEX], "tried lesson casts are remembered")
	for index in [1, 3]:
		game.new_duel()
		game.choose_stage(index)
		game.choose_pack(0)
		game._advance_enemy_preparation(1.0)
		game.start_combat()
		check(game.learning_cast_target() == null and not game.awaiting_learning_cast(),
			"forest %d shows its cast cue only until it was tried once" % index)
	var restored := Journey.new()
	var config := ConfigFile.new()
	game.journey.save(config)
	restored.restore(config, Difficulty.APPRENTICE)
	check(restored.lessons_done == game.journey.lessons_done, "tried lesson casts are saved")
	game.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://learning_pause_test_%d.cfg" % OS.get_process_id()))


## The druid's cue never invites a shapeshift of the tank (the shield guardian,
## the most armoured ally) while another ally can take it: the least armoured
## one goes first, the farthest from the enemies on a tie, and the tank only
## when it is the last creature to cast on.
func _test_learning_cue_spares_tank() -> void:
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	game.set_physics_process(false)
	game.difficulty_progress_path = "user://learning_cue_tank_test_%d.cfg" % OS.get_process_id()
	game.journey.completed.assign(range(Journey.stage_count()))
	for slot in OpponentDB.learning_packs().size():
		game.journey.lessons_done.clear()
		game.new_duel()
		game.choose_stage(1)
		game.choose_pack(slot)
		game._advance_enemy_preparation(1.0)
		game.start_combat()
		var allies: Array[Unit] = game.battle.living(0)
		var tank: Unit = null
		for u in allies:
			if tank == null or u.armour() > tank.armour():
				tank = u
		check(tank.form_id == "guardian", "pack %d: the shield guardian is the tank" % slot)
		var target: Unit = game.learning_cast_target()
		check(target != null and target.team == 0 and target != tank,
			"pack %d: the druid's cue spares the tank" % slot)
		var least := INF
		for u in allies:
			least = minf(least, u.armour())
		check(target != null and is_equal_approx(target.armour(), least),
			"pack %d: the cue picks the least armoured ally" % slot)
		for u in allies:
			if u != target and is_equal_approx(u.armour(), target.armour()):
				check(game._distance_to_foes(target) >= game._distance_to_foes(u),
					"pack %d: on a tie the cue picks the ally farthest from the enemies" % slot)
		for u in allies:
			if u != tank:
				u.alive = false
		check(game.learning_cast_target() == tank,
			"pack %d: the tank is invited only when it is the last ally" % slot)
	game.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://learning_cue_tank_test_%d.cfg" % OS.get_process_id()))


## A journey duel spotlights its opponent's rule once, when it first shows up;
## merge pips stay hidden until merging exists.
func _test_rule_spotlight() -> void:
	var journey := Journey.new()
	check(journey.rule_to_introduce(5) == Ruleset.TRADE and journey.rule_to_introduce(0) == ""
		and journey.rule_to_introduce(-1) == "", "the merchant introduces trading; the hunter and test duels nothing")
	journey.completed.append(5)
	check(journey.rule_to_introduce(5) == "", "a beaten opponent's rule needs no spotlight")
	var spot := RuleSpotlight.new()
	spot.reset(Ruleset.FRENZY)
	check(spot.pending() and not spot.active() and spot.time_scale() == 1.0, "the spotlight waits for its rule")
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	game.difficulty_progress_path = "user://rule_spotlight_test_%d.cfg" % OS.get_process_id()
	game.journey.completed.assign(range(5))
	game.journey.introduced.clear()
	game.choose_stage(5)
	game.choose_pack(0)
	check(game.spotlight.rule == Ruleset.TRADE and game.spotlight.pending(), "the merchant's duel waits to show trading")
	game.shop_out = 0.0
	game.enemy_preparing = false
	game._watch_rule_spotlight()
	check(game.spotlight.active() and Ruleset.TRADE in game.journey.introduced,
		"the reroll button is spotlit as soon as the shop is in place, and remembered")
	check(game.spotlight.center == Hud.reroll_rect().get_center(), "the spotlight opens on the reroll button")
	game.spotlight.advance(RuleSpotlight.FADE_IN)
	check(game.spotlight.time_scale() < 0.5, "the duel slows while the spotlight is on")
	game.spotlight.advance(RuleSpotlight.DURATION)
	check(not game.spotlight.active() and not game.spotlight.pending(), "the spotlight plays once per duel")
	# The innkeeper's harvest: the light shows the coins, following them into the purse.
	game.new_duel()
	game.journey.completed.assign(range(6))
	game.choose_stage(6)
	game.choose_pack(0)
	check(game.spotlight.rule == Ruleset.HARVEST and game.spotlight.pending(), "the innkeeper's duel waits to show the harvest")
	game.hud.set_process(false)
	game.player.add_creature("peasant")
	game.enemy_preparing = false
	game.start_combat()
	var hud: Hud = game.hud
	check(game.spotlight.active() and hud.harvest_lesson.get("team", -1) == 0 and hud.harvest_speed < 1.0,
		"the first harvest is spotlit on the player's harvester and plays slower")
	var lesson_coin: Dictionary = hud.harvest_coins.filter(func(c): return c.uid == hud.harvest_lesson.uid)[0]
	var step := func(seconds: float) -> void:
		hud.advance_harvest(seconds)
		game.spotlight.advance(seconds)
	step.call(0.0)
	check(game.spotlight.center.y < lesson_coin.from.y, "the light opens above the harvester, on its coin fan")
	step.call((lesson_coin.fly + Hud.HARVEST_FLIGHT * 0.6 - hud.harvest_time) / hud.harvest_speed)
	check(game.spotlight.center.distance_to(hud._coin_position(lesson_coin)) < 12.0, "the light follows the flying coin")
	step.call((hud.harvest_lesson.landed - hud.harvest_time) / hud.harvest_speed + 0.3)
	check(game.spotlight.active() and game.spotlight.center.distance_to(Hud.gold_pos(0)) < 45.0,
		"the light rests on the purse once the coin has landed")
	check(not hud.harvest_lesson.is_empty(), "the gold earned rises beside the purse")
	step.call(Hud.HARVEST_LESSON_PURSE_HOLD + RuleSpotlight.FADE_OUT)
	check(not game.spotlight.active() and hud.harvest_lesson.is_empty() and hud.harvest_speed == 1.0,
		"the harvest lesson ends and the harvest plays at its normal speed again")
	hud.set_process(true)
	game.journey.completed.assign(range(5))
	game.new_duel()
	game.choose_stage(5)
	check(not game.spotlight.pending(), "a rule already introduced is not spotlit again")
	game.choose_pack(0)
	var hovered: OwnedCreature = game.player.creatures[0]
	game.hover_info = {"owned": hovered}
	check(not game.show_merge_progress(hovered), "merge pips stay hidden before merging is introduced")
	game.ruleset = OpponentDB.ruleset(7)
	check(game.show_merge_progress(hovered), "merge pips appear once the thief introduces merging")
	var restored := Journey.new()
	var config := ConfigFile.new()
	game.journey.save(config)
	restored.restore(config, Difficulty.APPRENTICE)
	check(Ruleset.TRADE in restored.introduced, "introduced rules are saved")
	game.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://rule_spotlight_test_%d.cfg" % OS.get_process_id()))


## The duel screen grows with the rules the journey has introduced: before the
## shop the board and the medallions are centred together with the fight button
## under the board; with the shop the bench and the fight button share the row
## under the board. Hearts keep a fixed spacing on one or two arcs.
func _test_screen_layout() -> void:
	Hud.layout_screen(OpponentDB.ruleset(0))
	var shopless_board := Rect2(Rules.BOARD_POS, Rules.BOARD_SIZE)
	check(absf(Rules.FIGHT_CENTER.x - shopless_board.get_center().x) < 0.5 and Rules.FIGHT_CENTER.y - Rules.FIGHT_RADIUS > shopless_board.end.y,
		"before the shop the fight button sits under the board's centre")
	var left := Hud.medallion_centers[0].x - Hud.MEDALLION_RADIUS
	check(absf((left + shopless_board.end.x) * 0.5 - 640.0) < 30.0, "before the shop the board and the medallions are centred together")
	for team in 2:
		check(Hud.medallion_centers[team].x + Hud.MEDALLION_RADIUS + 4.0 < shopless_board.position.x,
			"medallion %d stays clear of the board" % team)
	Hud.layout_screen(OpponentDB.ruleset(5))
	var board := Rect2(Rules.BOARD_POS, Rules.BOARD_SIZE)
	var bench_end := Rules.reserve_slot_rect(Rules.RESERVE_CAP - 1).end
	check(board.position.x < shopless_board.position.x and Rules.FIGHT_CENTER.x - Rules.FIGHT_RADIUS > bench_end.x
		and Rules.FIGHT_CENTER.x + Rules.FIGHT_RADIUS * Hud.FIGHT_HOVER_SCALE < Hud.stall_rect().position.x,
		"with the shop the fight button sits right of the bench, clear of the stall")
	for count in [1, 3, 6, 10]:
		var gaps: Array[float] = []
		var inner: int = count if count <= Hud.HEART_ARC else ceili(count / 2.0)
		for i in count - 1:
			if i + 1 != inner:
				gaps.append(Hud.heart_pos(0, i, count).distance_to(Hud.heart_pos(0, i + 1, count)))
		var even := gaps.all(func(g: float) -> bool: return absf(g - gaps[0]) < 1.5 and g > Hud.HEART_SPACING * 0.95)
		check(gaps.is_empty() or even, "%d hearts keep a fixed spacing" % count)
		check(Hud.heart_pos(1, count - 1, count).y > board.position.y - 4.0, "%d opponent hearts stay below the board's top" % count)
	check(Hud.heart_pos(0, 9, 10).distance_to(Hud.medallion_centers[0]) > Hud.heart_pos(0, 0, 10).distance_to(Hud.medallion_centers[0]),
		"ten hearts use two arcs, the last on the outer one")
	check(Hud.crystal_pos(0, 2).y + 16.0 < board.end.y + 4.0, "the player's crystals stay above the board's bottom")
	Hud.layout_screen(Ruleset.new())
	# The fight button's lesson: spotlit at the hunter's first preparation, then a
	# halo until the very first fight.
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	game.difficulty_progress_path = "user://fight_lesson_test_%d.cfg" % OS.get_process_id()
	game._reset_difficulty_progress()
	game.choose_stage(0)
	game.choose_pack(0)
	game.shop_out = 0.0
	game.enemy_preparing = false
	game._watch_rule_spotlight()
	check(game.spotlight.active() and game.spotlight.center == Rules.FIGHT_CENTER and game.fight_lesson_waiting(),
		"the hunter's first preparation spotlights the fight button, which waits for its first fight")
	game.start_combat()
	check(not game.fight_lesson_waiting() and game.FIGHT_LESSON in game.journey.lessons_done, "the first fight ends the fight lesson for good")
	game.new_duel()
	game.choose_stage(0)
	game.choose_pack(0)
	check(not game.spotlight.pending() and not game.fight_lesson_waiting(), "the fight button is not spotlit again")
	game.free()
	Hud.layout_screen(Ruleset.new())
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://fight_lesson_test_%d.cfg" % OS.get_process_id()))


## A replayed duel can be left for the map after a confirmation that pauses
## it; a first attempt cannot be abandoned.
func _test_abandon_replay() -> void:
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	game.difficulty_progress_path = "user://abandon_test_%d.cfg" % OS.get_process_id()
	game.journey.completed.assign([0])
	game.choose_stage(1)
	check(not game.can_abandon(), "a first attempt cannot be abandoned")
	game.ask_abandon()
	check(not game.abandon_asked, "asking to abandon a first attempt does nothing")
	game.new_duel()
	game.choose_stage(0)
	check(game.can_abandon(), "a replay can be abandoned from the composition choice")
	game.choose_pack(0)
	game.enemy_preparing = false
	game.start_combat()
	check(game.phase == game.Phase.COMBAT and game.can_abandon(), "a replay can be abandoned during combat")
	game._left_press(Hud.ABANDON_POS)
	check(game.abandon_asked, "the island medallion asks to abandon")
	var time: float = game.battle.time
	game._physics_process(0.5)
	check(game.battle.time == time, "the duel is paused while the confirmation waits")
	game.cancel_abandon()
	game._physics_process(0.1)
	check(not game.abandon_asked and game.battle.time > time, "the cross resumes the duel")
	game.ask_abandon()
	game.abandon_duel()
	_finish_transition(game)
	check(game.phase == game.Phase.DIFFICULTY and game.map_screen.visible and not game.abandon_asked,
		"the check leaves the duel for the map")
	check(game.journey.completed == [0] and not game.journey.available(2), "abandoning changes nothing on the journey")
	game.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://abandon_test_%d.cfg" % OS.get_process_id()))


## The town adds three humans and three animals to the forest's six forms;
## its transformations stay inside the town roster.
func _test_town_roster() -> void:
	for form in Ruleset.FOREST_HUMANS:
		check(form in Ruleset.TOWN_HUMANS, "the town keeps the forest humans")
	for form in Ruleset.FOREST_ANIMALS:
		check(form in Ruleset.TOWN_ANIMALS, "the town keeps the forest animals")
	for form in ["cleric", "assassin", "bard"]:
		check(form in Ruleset.TOWN_HUMANS and form not in Ruleset.FOREST_HUMANS, "the town introduces the %s" % form)
	check(Ruleset.TOWN_ANIMALS.size() == 6 and "skunk" not in Ruleset.TOWN_ANIMALS, "the town adds three animals, not the skunk")
	var incoming := {}
	for index in range(OpponentDB.ZONE_SIZE, OpponentDB.ZONE_SIZE * 2):
		var rules := OpponentDB.ruleset(index)
		check(rules.roster == Ruleset.TOWN, "town opponent %d uses the town roster" % index)
		for form in CreatureDB.all_ids():
			check(rules.in_roster(form) == (form in Ruleset.TOWN_HUMANS or form in Ruleset.TOWN_ANIMALS),
				"town %d roster contains exactly its fifteen forms" % index)
		for id in rules.shop_ids():
			check(id in Ruleset.TOWN_HUMANS, "town %d offers only town humans" % index)
		for pack: Dictionary in OpponentDB.TOWN_PACKS:
			for form in pack.forms:
				check(form in Ruleset.TOWN_HUMANS, "town composition %s uses town humans" % pack.name)
		for card in _town_offered_cards(index):
			check(rules.allows_pack(OpponentDB.TOWN_PACKS[card]), "town %d deals allowed compositions" % index)
	var town := OpponentDB.ruleset(5)
	for form: String in Ruleset.TOWN_OUTCOMES:
		var options := town.outcomes(form)
		check(options.size() == 3, "every town form has three outcomes")
		for option: Dictionary in options:
			incoming[option.id] = incoming.get(option.id, 0) + 1
			check(town.in_roster(option.id), "town transformations stay in the town roster")
			check((form in Ruleset.TOWN_HUMANS) != (option.id in Ruleset.TOWN_HUMANS),
				"town transformations cross between humans and animals")
	check(Ruleset.TOWN_OUTCOMES.size() == 15 and incoming.size() == 15, "every town form can be reached")
	for form in Ruleset.FOREST_OUTCOMES:
		check(Ruleset.TOWN_OUTCOMES[form][0] == Ruleset.FOREST_OUTCOMES[form][0],
			"%s keeps its most likely forest outcome in town" % form)


func _town_offered_cards(index: int) -> Array[int]:
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	game.difficulty_progress_path = "user://town_roster_test_%d.cfg" % OS.get_process_id()
	game.journey.completed.assign(range(Journey.stage_count()))
	game.choose_stage(index)
	var cards: Array[int] = game.offered_packs.duplicate()
	check(cards.size() == 3, "town %d offers three compositions" % index)
	game.choose_pack(0)
	for c: OwnedCreature in game.enemy.creatures:
		check(c.form_id in Ruleset.TOWN_HUMANS, "town %d opponent opens with town humans" % index)
	game.free()
	return cards


func _test_forest_lessons() -> void:
	check(OpponentDB.get_opponent(1).id == "druid" and OpponentDB.get_opponent(2).id == "lumberjack",
		"the wand is introduced before the shop")
	check(OpponentDB.ruleset(1).has(Ruleset.WAND) and not OpponentDB.ruleset(1).has(Ruleset.SHOP),
		"the druid teaches casting without shopping")
	for form: String in OpponentDB.learning_army(0):
		check(CreatureDB.get_form(form).family == "animal", "the hunter fields animals only")
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	game.difficulty_progress_path = "user://forest_lesson_test_%d.cfg" % OS.get_process_id()
	game.journey.completed.assign(range(Journey.stage_count()))
	for lesson in 15:
		var index := lesson / 3
		var choice := lesson % 3
		game.choose_stage(index)
		check(game.offered_packs == OpponentDB.learning_packs(), "forest %d offers small thematic teams" % index)
		game.choose_pack(choice)
		for creature: OwnedCreature in game.player.creatures:
			check(creature.form_id in Ruleset.FOREST_HUMANS, "forest openings use only the three humans")
		check(game.enemy.creatures.size() == OpponentDB.learning_army(index).size(), "forest %d uses its small army" % index)
		check(game.bench_visible() == (index >= 2), "the bench appears with the shop")
		check(EnemyAI.shop_step(game.enemy, game.rng).is_empty(), "forest enemies never expand their army")
		for offer: String in game.player.offers:
			check(offer == "" or offer in Ruleset.FOREST_HUMANS, "forest offers stay inside the thematic roster")
		game._advance_enemy_preparation(1.0)
		game.start_combat()
		check(game.battle.learning_duel, "forest battles enable the learning safety net")
		# Observe an ordinary opening without shopping or casting. This is a
		# bounded lesson smoke test, not a balance or win-rate investigation.
		for tick in 3700: # a little past Rules.COMBAT_TIMEOUT
			game.battle.step(1.0 / 60.0)
			if game.battle.finished:
				break
		# Difficulty rises gently: the first three lessons fall to the opening
		# alone; later ones expect purchases, but the safety net still holds.
		if index <= 2:
			check(game.battle.finished and game.battle.result.winner == 0,
				"forest %d can be won without buying or casting" % index)
		else:
			check(game.battle.finished and game.battle.result.winner != 1,
				"forest %d never beats the player's opening" % index)
		if index > 0:
			check(OpponentDB.learning_army(index).size() > OpponentDB.learning_army(index - 1).size(),
				"forest %d fields more creatures than the previous lesson" % index)
		game.new_duel()
	game.free()
	var forest := OpponentDB.ruleset(1)
	for form: String in Ruleset.FOREST_OUTCOMES:
		var options := forest.outcomes(form)
		check(options.size() == 3, "every forest form has three outcomes")
		for option: Dictionary in options:
			check(forest.allows_form(option.id), "forest transformations cannot escape the six-form roster")
			check((form in Ruleset.FOREST_HUMANS) != (option.id in Ruleset.FOREST_HUMANS),
				"forest transformations cross between humans and animals")
	check(not forest.allows_form("turtle") and not forest.allows_form("crossbowman"),
		"forest excludes other animals and humans")
	_test_town_roster()
	check(OpponentDB.ruleset(10).outcomes("archer") == CreatureDB.outcomes("archer")
		and OpponentDB.ruleset(10).allows_form("crossbowman") and OpponentDB.ruleset(10).allows_form("skunk"),
		"the school restores every creature and the full transformation graph")
	var battle := Battle.new()
	add_child(battle)
	battle.learning_duel = true
	var first := battle.spawn(0, "archer", Vector2(100, 300))
	var last := battle.spawn(0, "archer", Vector2(200, 300))
	var foe := battle.spawn(1, "wolf", Vector2(100, 100))
	battle.damage(foe, first, 10000, "dot", true)
	battle.damage(foe, last, 10000, "dot", true)
	check(not first.alive and last.alive and last.hp == 1.0,
		"creatures can fall but poison cannot kill the learner's last creature")
	battle.learning_duel = false
	battle.damage(foe, last, 10000, "dot", true)
	check(not last.alive, "ordinary battles retain lethal damage")
	battle.free()
