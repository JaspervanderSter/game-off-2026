extends Node2D
## Prototype 02 game controller: the duel loop
## journey map -> pack choice -> (preparation -> combat -> resolution)
## -> game over -> journey map.

enum Phase { DIFFICULTY, PACK, PREP, COMBAT, RESOLVE, OVER }

const RESOLVE_TIME := 2.4
const ENEMY_ACTION_TIME := 0.55
const ENEMY_MOVE_TIME := 0.42
const SHOP_DRAG_DISTANCE := 8.0
# Fight layout: the shop column slides off the right edge and the bench shrinks
# and docks at the bottom of the screen, then both come back for the next shop.
const UI_SLIDE_TIME := 0.45
const SCROLL_UNROLL_TIME := 0.5
const BENCH_DOCK_SCALE := 0.5
const BENCH_DOCK_POS := Vector2(640 - Rules.CELL * Rules.RESERVE_CAP * BENCH_DOCK_SCALE * 0.5, 720 - Rules.CELL * BENCH_DOCK_SCALE - 8)

var phase := Phase.DIFFICULTY
var player: WizardState
var enemy: WizardState
var states: Array[WizardState] = []
var round_num := 0
## Winner of each finished round, in order: 0 player, 1 enemy, -1 draw.
var round_winners: Array[int] = []
var difficulty := Difficulty.APPRENTICE
var unlocked_difficulty := Difficulty.APPRENTICE
var newly_unlocked_difficulty := -1
var difficulty_progress_path := "user://difficulty_progress.cfg"
var journey := Journey.new()
## OpponentDB index of the current journey opponent; -1 outside the journey.
var opponent := -1
## Rules of the current duel: those its journey opponent has introduced so far.
var ruleset := Ruleset.new()
var learning_cast_tried := false
## The thief's merge demonstration stops after the player's first merge.
var merge_lesson_done := false
## Seconds left on the full-board warning: the capacity pips flash red after a
## drop refused because the board already holds Rules.FIELD_CAP creatures.
var field_full_flash := 0.0
const FIELD_FULL_FLASH := 0.9
## Spotlight on the rule this duel's opponent introduces, the first time it shows.
var spotlight := RuleSpotlight.new()
var menu_screen: Node2D
var map_screen: Node2D
const PACK_CHOICES := 3
# Starting compositions come from hidden decks: three cards for the player per
# duel, one for the opponent from its own deck.
var player_deck := PackDeck.new("player")
var enemy_deck := PackDeck.new("enemy")
var offered_packs: Array[int] = [] # OpponentDB.packs_for(opponent) indices on the three cards
var battle: Battle = null
var rng := RandomNumberGenerator.new()
var drag: OwnedCreature = null
var shop_drag_index := -1
var shop_drag_origin := Vector2.ZERO
var shop_drag_position := Vector2.ZERO
var shop_drag_active := false
var enemy_preparing := false
var enemy_action := {}
var enemy_moves := {}
var _enemy_wait := 0.0
var hover_info := {}
var last_result := {}
var last_damage := 0.0
var last_damage_team := -1
var _resolve_t := 0.0
var _shake_t := 0.0
var _shake_len := 0.0
var _shake_mag := 0.0
var shop_out := 1.0 # 0 = shop column on screen, 1 = slid off the right edge
var scroll_open := 0.0 # 0 = wand upgrade scroll rolled up, 1 = fully unrolled
var bench_dock := 0.0 # 0 = bench under the board, 1 = half size at the bottom

var board_view: BoardView
var fx: FxLayer
var hud: Hud
var music: PhaseMusic
var switch_flash: SwitchFlash
var fps_counter: Control


func _ready() -> void:
	rng.randomize()
	SoundSet.apply()
	Shapes.warm_up() # builds the shape atlas now rather than on the first frame
	music = PhaseMusic.new()
	add_child(music)
	board_view = BoardView.new()
	board_view.game = self
	board_view.position = Rules.BOARD_POS
	add_child(board_view)
	fx = FxLayer.new()
	fx.position = Rules.BOARD_POS
	fx.z_index = 10
	add_child(fx)
	hud = Hud.new()
	hud.game = self
	hud.z_index = 20
	add_child(hud)
	var top := CanvasLayer.new()
	top.layer = 10
	add_child(top)
	switch_flash = SwitchFlash.new()
	top.add_child(switch_flash)
	fps_counter = preload("res://scripts/ui/fps_counter.gd").new()
	top.add_child(fps_counter)
	_load_difficulty_progress()
	player_deck.load_state()
	enemy_deck.load_state()
	menu_screen = preload("res://menu.tscn").instantiate()
	map_screen = preload("res://world_map.tscn").instantiate()
	for screen in [menu_screen, map_screen]:
		screen.game = self
		screen.z_index = 30
		add_child(screen)
	new_duel()


func show_menu() -> void:
	music.transition_to("")
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	menu_screen.show()
	map_screen.hide()
	board_view.hide()
	hud.hide()
	menu_screen.focus_first()


func show_map() -> void:
	music.transition_to("")
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	menu_screen.hide()
	map_screen.show()
	board_view.hide()
	hud.hide()
	map_screen.focus_first()
	Sfx.play("ui/click")


func choose_stage(index: int) -> void:
	if phase != Phase.DIFFICULTY or not journey.available(index):
		return
	journey.selected = index
	# The roads, rather than the former difficulty locks, grant access.
	opponent = index
	difficulty = OpponentDB.ai_level(index)
	ruleset = OpponentDB.ruleset(index)
	_start_duel()


func new_duel() -> void:
	if battle != null:
		battle.queue_free()
		battle = null
	player = WizardState.new(0)
	enemy = WizardState.new(1)
	enemy.ai_level = difficulty
	states = [player, enemy]
	round_num = 0
	round_winners.clear()
	drag = null
	shop_drag_index = -1
	shop_drag_active = false
	enemy_preparing = false
	enemy_action.clear()
	enemy_moves.clear()
	last_result = {}
	last_damage = 0
	last_damage_team = -1
	hud.clear_loss_rewards()
	hud.clear_harvest()
	hud.clear_victory()
	phase = Phase.DIFFICULTY
	journey.selected = -1
	# Discovery is presented by the map, without the obsolete hidden hat reveal.
	hud.begin_difficulty_unlock(-1)
	newly_unlocked_difficulty = -1
	if map_screen != null:
		show_map()


## Direct difficulty entry retained for rule tests and developer tooling.
## The playable front end chooses stages through choose_stage().
func choose_difficulty(level: int) -> void:
	if phase != Phase.DIFFICULTY or hud.unlock_animation_active():
		return
	if not is_difficulty_unlocked(level):
		Sfx.play("ui/fail")
		return
	difficulty = level
	journey.selected = -1
	opponent = -1
	ruleset = Ruleset.new()
	_start_duel()


func _start_duel() -> void:
	learning_cast_tried = false
	merge_lesson_done = false
	field_full_flash = 0.0
	spotlight.reset(journey.rule_to_introduce(opponent))
	player.max_hp = Journey.hearts_for_stage(journey.selected)
	enemy.max_hp = Journey.enemy_hearts_for_stage(journey.selected)
	for state in states:
		state.hp = float(state.max_hp)
	board_view.set_environment(Journey.environment_for_stage(journey.selected))
	music.transition_to("prep")
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	menu_screen.hide()
	map_screen.hide()
	board_view.show()
	hud.show()
	enemy.ai_level = difficulty
	for state in states:
		state.rules = ruleset
		state.learning_duel = OpponentDB.is_learning_encounter(opponent)
	enemy.magic = opponent < 0 or OpponentDB.get_opponent(opponent).magic
	if OpponentDB.is_learning_encounter(opponent):
		offered_packs = OpponentDB.learning_packs()
	elif ruleset.is_complete():
		offered_packs = player_deck.deal(PACK_CHOICES, rng)
		player_deck.save_state()
	else:
		offered_packs = _allowed_packs(PACK_CHOICES)
	phase = Phase.PACK
	Sfx.play("ui/click")


## Journey duels that still withhold creatures offer only compositions made of
## creatures already introduced, without touching the player's deck.
func _allowed_packs(count: int) -> Array[int]:
	var allowed: Array[int] = []
	var packs := OpponentDB.packs_for(opponent)
	for i in packs.size():
		if ruleset.allows_pack(packs[i]):
			allowed.append(i)
	var cards: Array[int] = []
	while cards.size() < count and not allowed.is_empty():
		cards.append(allowed.pop_at(rng.randi_range(0, allowed.size() - 1)))
	return cards


func is_difficulty_unlocked(level: int) -> bool:
	return level >= Difficulty.APPRENTICE and level <= unlocked_difficulty


func _load_difficulty_progress() -> void:
	var config := ConfigFile.new()
	if config.load(difficulty_progress_path) == OK:
		var saved = config.get_value("progress", "unlocked_difficulty", Difficulty.APPRENTICE)
		if saved is int:
			unlocked_difficulty = clampi(saved, Difficulty.APPRENTICE, Difficulty.COUNT - 1)
	journey.restore(config, unlocked_difficulty)


func _unlock_next_difficulty() -> void:
	journey.record_win()
	var next := difficulty + 1
	if next <= unlocked_difficulty or next >= Difficulty.COUNT:
		_save_difficulty_progress(unlocked_difficulty)
		return
	unlocked_difficulty = next
	newly_unlocked_difficulty = next
	_save_difficulty_progress(next)


func _save_difficulty_progress(level: int) -> bool:
	var config := ConfigFile.new()
	config.set_value("progress", "unlocked_difficulty", level)
	journey.save(config)
	var error := config.save(difficulty_progress_path)
	if error != OK:
		push_warning("Could not save difficulty progress: %s" % error_string(error))
	return error == OK


func _reset_difficulty_progress() -> void:
	var previous := journey.completed.duplicate()
	var shown := journey.introduced.duplicate()
	journey.completed.clear()
	journey.introduced.clear()
	if not _save_difficulty_progress(Difficulty.APPRENTICE):
		journey.completed.assign(previous)
		journey.introduced.assign(shown)
		Sfx.play("ui/fail")
		return
	difficulty = Difficulty.APPRENTICE
	unlocked_difficulty = Difficulty.APPRENTICE
	new_duel()
	Sfx.play("ui/click")


## `slot` is the card position (0 to 2) among the offered compositions.
func pack_at(slot: int) -> Dictionary:
	return OpponentDB.packs_for(opponent)[offered_packs[slot]]


func choose_pack(slot: int) -> void:
	if phase != Phase.PACK or slot < 0 or slot >= offered_packs.size():
		return
	player.take_starting_pack(pack_at(slot))
	# A journey opponent opens with its own composition; the archmage and duels
	# outside the journey deal from the opponent's deck.
	var enemy_pack := OpponentDB.pack_index(opponent) if opponent >= 0 else -1
	if OpponentDB.is_learning_encounter(opponent):
		for form: String in OpponentDB.learning_army(opponent):
			enemy.add_creature(form)
	elif enemy_pack < 0:
		enemy_pack = enemy_deck.deal(1, rng)[0]
		enemy_deck.save_state()
	if not OpponentDB.is_learning_encounter(opponent):
		enemy.take_starting_pack(OpponentDB.packs_for(opponent)[enemy_pack])
	Sfx.play("ui/buy")
	start_round()


func start_round() -> void:
	round_num += 1
	for s in states:
		s.ai_rerolls = 0
		s.gold += Rules.income(round_num)
		s.refresh_offers(rng)
	enemy_preparing = true
	_enemy_wait = 0.3
	enemy_action.clear()
	enemy_moves.clear()
	phase = Phase.PREP
	music.transition_to("prep")


func start_combat() -> void:
	if phase != Phase.PREP or enemy_preparing or drag != null or player.field_count() == 0:
		Sfx.play("ui/fail")
		return
	hud.clear_loss_rewards()
	battle = Battle.new()
	battle.position = Rules.BOARD_POS
	add_child(battle)
	move_child(battle, board_view.get_index() + 1)
	battle.setup(states)
	battle.unit_died.connect(_on_unit_died)
	battle.unit_transformed.connect(_on_unit_transformed)
	battle.fx_requested.connect(fx.add)
	battle.frenzy_changed.connect(music.set_frenzy_level)
	battle.ended.connect(_on_battle_ended)
	# Harvest: every peasant fielded when the fight begins pays its gold now.
	for s in states:
		var sources: Array[Dictionary] = []
		for y in s.harvest():
			sources.append({"uid": y.creature.uid, "pos": Rules.BOARD_POS + Rules.cell_center(y.creature.cell), "gold": y.gold})
		hud.begin_harvest(s.team, sources)
		if spotlight.pending() and spotlight.rule == Ruleset.HARVEST and not sources.is_empty():
			_spotlight(sources[0].pos, Vector2(48, 48))
	drag = null
	phase = Phase.COMBAT
	music.set_frenzy_level(0)
	music.transition_to("battle")
	Sfx.play("ui/battle_start")


func _physics_process(dt: float) -> void:
	match phase:
		Phase.PREP:
			_advance_enemy_preparation(dt)
		Phase.COMBAT:
			if not awaiting_learning_cast():
				battle.step(dt * spotlight.time_scale())
		Phase.RESOLVE:
			_resolve_t -= dt
			if _resolve_t <= 0.0:
				_finish_round()


func _on_battle_ended(result: Dictionary) -> void:
	hud.clear_loss_rewards()
	last_result = result
	last_damage = 0
	last_damage_team = -1
	var winner: int = result.winner
	round_winners.append(winner)
	if winner >= 0:
		var loser := states[1 - winner]
		var hp_before := loser.hp
		var gold_before := loser.gold
		var compensation_before := loser.loss_gold_progress
		last_damage = loser.take_round_damage(result.survivors)
		last_damage_team = loser.team
		hud.begin_loss_rewards(loser.team, hp_before, last_damage, loser.gold - gold_before, compensation_before)
	# Intermediate rounds use only heart/coin feedback. Result recordings are
	# reserved for the final game-over transition, after the last hearts break.
	music.transition_to("")
	_resolve_t = maxf(RESOLVE_TIME, hud.loss_reward_duration())
	phase = Phase.RESOLVE


func _finish_round() -> void:
	battle.queue_free()
	battle = null
	if player.hp <= 0 or enemy.hp <= 0:
		player.hp = maxf(0, player.hp)
		enemy.hp = maxf(0, enemy.hp)
		phase = Phase.OVER
		music.transition_to("")
		if player.hp > 0:
			_unlock_next_difficulty()
			hud.begin_victory()
		Sfx.play("duel/defeat" if player.hp == 0 else "duel/victory")
	else:
		start_round()


func _on_unit_died(u: Unit) -> void:
	fx.add("rocket", u.position, {"form": u.form_id, "team": u.team})
	Sfx.play("combat/death")


## Blessing (own creature) and hex (enemy creature) have distinct effects and
## sounds; both flash the creature and shake the board briefly.
func _on_unit_transformed(u: Unit, caster: int, _from: String) -> void:
	if caster == 0 and u.team == (1 if ruleset.has(Ruleset.HEX) else 0):
		learning_cast_tried = true
	# Animal bonus: the first creature its own wizard turns into a bonus form.
	if spotlight.pending() and spotlight.rule == Ruleset.ANIMAL_BONUS and caster == u.team \
			and u.data.has("ally_shift"):
		_spotlight(Rules.BOARD_POS + u.position, Vector2(52, 52), u)
	var blessing := u.team == caster
	fx.add("shift_bless" if blessing else "shift_hex", u.position)
	Sfx.play("shapeshift/bless" if blessing else "shapeshift/hex")
	u.flash_t = 0.12
	_shake(4.0 if blessing else 6.0, 0.22)


func _shake(magnitude: float, duration: float) -> void:
	_shake_mag = maxf(_shake_mag if _shake_t > 0.0 else 0.0, magnitude)
	_shake_t = maxf(_shake_t, duration)
	_shake_len = _shake_t


## Offsets the board, its creatures and effects (not the HUD) while shaking.
func _apply_shake(dt: float) -> void:
	if _shake_t <= 0.0:
		return
	_shake_t = maxf(0.0, _shake_t - dt)
	var offset := Vector2.ZERO
	if _shake_t > 0.0:
		offset = Vector2.from_angle(randf() * TAU) * _shake_mag * (_shake_t / _shake_len)
	board_view.position = Rules.BOARD_POS + offset
	fx.position = Rules.BOARD_POS + offset
	if battle != null and is_instance_valid(battle):
		battle.position = Rules.BOARD_POS + offset


# --- Input ---------------------------------------------------------------------------

func _advance_enemy_preparation(dt: float) -> void:
	for move in enemy_moves.values():
		move.t = minf(move.t + dt, ENEMY_MOVE_TIME)
	if not enemy_action.is_empty():
		enemy_action.t += dt
	if not enemy_preparing:
		return
	_enemy_wait -= dt
	if _enemy_wait > 0.0:
		return
	var before := {}
	for c in enemy.fielded():
		before[c.uid] = enemy_display_position(c)
	var action := EnemyAI.shop_step(enemy, rng)
	if action.is_empty():
		enemy_preparing = false
		return
	action.t = 0.0
	enemy_action = action
	_enemy_wait = ENEMY_ACTION_TIME
	enemy_moves.clear()
	var entrance := Hud.ENEMY_BLOCK.position + Vector2(42, 48) - Rules.BOARD_POS
	for c in enemy.fielded():
		var dest := Rules.cell_center(c.cell)
		var origin: Vector2 = before.get(c.uid, entrance)
		if origin.distance_to(dest) > 0.1:
			enemy_moves[c.uid] = {"from": origin, "to": dest, "t": 0.0}
	if action.kind == "buy":
		Sfx.play("ui/buy")
	elif action.kind == "merge":
		for c in enemy.fielded():
			if c.uid == action.uid:
				fx.add("merge" if action.promoted else "combine", Rules.cell_center(c.cell))
		Sfx.play("ui/merge" if action.promoted else "ui/combine")
	elif action.kind == "sell":
		Sfx.play("coins/gain")
	else:
		Sfx.play("ui/buy" if action.kind == "upgrade" else "ui/click")


func enemy_display_position(c: OwnedCreature) -> Vector2:
	if not enemy_moves.has(c.uid):
		return Rules.cell_center(c.cell)
	var move: Dictionary = enemy_moves[c.uid]
	var k := clampf(float(move.t) / ENEMY_MOVE_TIME, 0.0, 1.0)
	return Vector2(move.from).lerp(move.to, k * k * (3.0 - 2.0 * k))


func enemy_is_moving(c: OwnedCreature) -> bool:
	return enemy_moves.has(c.uid) and float(enemy_moves[c.uid].t) < ENEMY_MOVE_TIME


func drag_visual_active() -> bool:
	return drag != null and (shop_drag_index < 0 or shop_drag_active)


func can_drop_merge(c: OwnedCreature) -> bool:
	if not drag_visual_active():
		return false
	return player.can_merge_offer(shop_drag_index, c) if shop_drag_index >= 0 else player.can_merge(drag, c)


## Merge pips appear only once merging is introduced (Ruleset.MERGE).
func show_merge_progress(c: OwnedCreature) -> bool:
	return ruleset.has(Ruleset.MERGE) and (hover_info.get("owned") == c or can_drop_merge(c))

func board_cell(screen_pos: Vector2) -> Vector2i:
	var local := (screen_pos - Rules.BOARD_POS) / Rules.CELL
	return Vector2i(floori(local.x), floori(local.y))


## Moves the shop and bench toward their place for the current phase: the shop
## is out except while shopping; the bench docks from the fight to the next shop.
## The wand scroll unrolls once the shop has slid in and rolls up as it leaves.
func _advance_ui(dt: float) -> void:
	var step := dt / UI_SLIDE_TIME
	shop_out = move_toward(shop_out, 0.0 if phase == Phase.PREP else 1.0, step)
	var unrolled := phase == Phase.PREP and shop_out <= 0.0
	scroll_open = move_toward(scroll_open, 1.0 if unrolled else 0.0, dt / SCROLL_UNROLL_TIME)
	var docked := phase == Phase.COMBAT or phase == Phase.RESOLVE or phase == Phase.OVER
	bench_dock = move_toward(bench_dock, 1.0 if docked else 0.0, step)


func bench_scale() -> float:
	return lerpf(1.0, BENCH_DOCK_SCALE, smoothstep(0.0, 1.0, bench_dock))


## On-screen bench slot, following the dock animation.
func bench_slot_rect(slot: int) -> Rect2:
	var s := bench_scale()
	var top_left := Rules.RESERVE_POS.lerp(BENCH_DOCK_POS, smoothstep(0.0, 1.0, bench_dock))
	return Rect2(top_left + Vector2(slot * Rules.CELL * s, 0), Vector2.ONE * Rules.CELL * s)


func _reserve_slot_at(pos: Vector2) -> int:
	if not bench_visible():
		return -1
	for s in Rules.RESERVE_CAP:
		if bench_slot_rect(s).has_point(pos):
			return s
	return -1


func bench_visible() -> bool:
	return ruleset.has(Ruleset.SHOP) or not player.benched().is_empty()


func _owned_at(pos: Vector2) -> OwnedCreature:
	var slot := _reserve_slot_at(pos)
	if slot >= 0:
		return player.at_slot(slot)
	var cell := board_cell(pos)
	if player.owns_cell(cell):
		return player.at_cell(cell)
	return null


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F8 and event.shift_pressed:
		fps_counter.visible = not fps_counter.visible
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_P and event.ctrl_pressed and event.shift_pressed:
		toggle_art_style()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_S and event.ctrl_pressed and event.shift_pressed:
		toggle_sound_set()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_T and event.ctrl_pressed and event.shift_pressed:
		cycle_environment()
		get_viewport().set_input_as_handled()
		return
	if event.keycode != KEY_ENTER or not event.alt_pressed or Engine.is_embedded_in_editor():
		return
	var window := get_window()
	if window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		window.mode = Window.MODE_WINDOWED
	else:
		window.mode = Window.MODE_FULLSCREEN
	get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	ArtStyle.reload() # release the cached sprites before the engine shuts down


## Hidden Ctrl+Shift+P switch between the pixel art (default) and the vector
## art; the choice is remembered (see ArtStyle).
func toggle_art_style() -> void:
	var style := ArtStyle.toggle()
	propagate_call("queue_redraw")
	switch_flash.show_art_style(style)


## Hidden Ctrl+Shift+S switch between the current sound effects (default) and
## the earlier ones, to compare them; the choice is remembered (see SoundSet).
func toggle_sound_set() -> void:
	switch_flash.show_sound_set(SoundSet.toggle())


## Hidden Ctrl+Shift+T switch to the next battlefield environment (forest,
## town, school), to compare them; not remembered.
func cycle_environment() -> void:
	var ids: Array = Terrain.ENVIRONMENTS.keys()
	board_view.set_environment(ids[(ids.find(board_view.environment) + 1) % ids.size()])


func _unhandled_input(event: InputEvent) -> void:
	if menu_screen.visible or map_screen.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				show_menu()
			elif event.keycode == KEY_ENTER and menu_screen.visible:
				show_map()
			elif event.keycode == KEY_R and event.ctrl_pressed and event.shift_pressed:
				_reset_difficulty_progress()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and shop_drag_index >= 0:
		shop_drag_position = event.position
		if event.position.distance_to(shop_drag_origin) >= SHOP_DRAG_DISTANCE:
			shop_drag_active = true
	elif event is InputEventMouseButton:
		var pos: Vector2 = event.position
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_left_press(pos)
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_left_release(pos)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_right_press(pos)
	elif event is InputEventKey and event.pressed and not event.echo:
		if phase == Phase.DIFFICULTY and event.keycode == KEY_R and event.ctrl_pressed and event.shift_pressed:
			_reset_difficulty_progress()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE and phase == Phase.PREP:
			start_combat()
		elif phase == Phase.DIFFICULTY and event.keycode >= KEY_1 and event.keycode < KEY_1 + Difficulty.COUNT:
			choose_difficulty(event.keycode - KEY_1)


func _left_press(pos: Vector2) -> void:
	match phase:
		Phase.DIFFICULTY:
			for i in Difficulty.COUNT:
				if Hud.difficulty_rect(i).has_point(pos):
					choose_difficulty(i)
					return
		Phase.PACK:
			for i in offered_packs.size():
				if Hud.pack_rect(i).has_point(pos):
					choose_pack(i)
					return
		Phase.PREP:
			for i in Rules.WAND_UPGRADES.size():
				if ruleset.any_upgrade() and Hud.upgrade_rect(i).has_point(pos):
					var id := Rules.WAND_UPGRADES[i]
					if player.buy_upgrade(id):
						Sfx.play("ui/purchase_confirmed")
					elif not player.upgrade_maxed(id) and player.gold < player.upgrade_cost(id):
						Sfx.play("ui/insufficient_gold")
					else:
						Sfx.play("ui/fail")
					return
			if ruleset.has(Ruleset.TRADE) and Hud.REROLL_RECT.has_point(pos):
				if player.reroll(rng):
					Sfx.play("ui/purchase_confirmed")
				elif player.gold < Rules.REROLL_COST:
					Sfx.play("ui/insufficient_gold")
				else:
					Sfx.play("ui/fail")
				return
			if pos.distance_to(Rules.FIGHT_CENTER) < Rules.FIGHT_RADIUS:
				start_combat()
				return
			for i in Rules.SHOP_SIZE:
				if Hud.offer_rect(i).has_point(pos):
					if player.offers[i] == "":
						Sfx.play("ui/fail")
					elif player.gold < CreatureDB.get_form(player.offers[i]).price:
						Sfx.play("ui/insufficient_gold")
					else:
						shop_drag_index = i
						shop_drag_origin = pos
						shop_drag_position = pos
						shop_drag_active = false
						drag = OwnedCreature.new(player.offers[i])
					return
			drag = _owned_at(pos)
			if drag != null:
				Sfx.play("ui/click")
		Phase.COMBAT:
			_cast_at(pos)
		Phase.OVER:
			if pos.distance_to(Hud.RESTART_POS) < 46:
				Sfx.play("ui/click")
				new_duel()


func _left_release(pos: Vector2) -> void:
	if shop_drag_index >= 0:
		_release_shop_offer(pos)
		return
	if drag == null:
		return
	var c := drag
	drag = null
	if phase != Phase.PREP:
		return
	if Rules.SHOP_RECT.has_point(pos) and player.can_sell(c):
		player.sell(c)
		Sfx.play("ui/buy")
		return
	var recipient := _owned_at(pos)
	var combining := player.can_merge(c, recipient)
	var previous_stars := recipient.stars if combining else -1
	var slot := _reserve_slot_at(pos)
	var ok := false
	if slot >= 0:
		ok = player.move_to_slot(c, slot)
	elif player.owns_cell(board_cell(pos)):
		var full := board_full_for(c) and player.at_cell(board_cell(pos)) == null
		ok = player.move_to_cell(c, board_cell(pos))
		if not ok and full:
			field_full_flash = FIELD_FULL_FLASH
	if not ok:
		Sfx.play("ui/fail")
	elif combining:
		_merge_feedback(recipient, previous_stars)
	elif recipient == c:
		Sfx.play("ui/click")
	else:
		Sfx.play("ui/place")


func _release_shop_offer(pos: Vector2) -> void:
	var index := shop_drag_index
	var moved := shop_drag_active or pos.distance_to(shop_drag_origin) >= SHOP_DRAG_DISTANCE
	shop_drag_index = -1
	shop_drag_active = false
	drag = null
	if phase != Phase.PREP:
		return
	var recipient := _owned_at(pos)
	var combining := player.can_merge_offer(index, recipient)
	var previous_stars := recipient.stars if combining else -1
	var bought: OwnedCreature = null
	if not moved and Hud.offer_rect(index).has_point(pos):
		bought = player.buy(index)
	elif player.owns_cell(board_cell(pos)):
		var full := player.field_count() >= Rules.FIELD_CAP and player.at_cell(board_cell(pos)) == null
		bought = player.buy_to_cell(index, board_cell(pos))
		if bought == null and full:
			field_full_flash = FIELD_FULL_FLASH
	else:
		var slot := _reserve_slot_at(pos)
		if slot >= 0:
			bought = player.buy_to_slot(index, slot)
	if bought == null:
		Sfx.play("ui/fail")
	else:
		Sfx.play("ui/purchase_confirmed")
		if combining:
			_merge_feedback(bought, previous_stars)
		elif moved:
			Sfx.play("ui/place")


func _merge_feedback(recipient: OwnedCreature, previous_stars: int) -> void:
	merge_lesson_done = true
	var ranked_up := recipient.stars > previous_stars
	var centre := Rules.BOARD_POS + Rules.cell_center(recipient.cell) if recipient.is_fielded() else bench_slot_rect(recipient.slot).get_center()
	fx.add("merge" if ranked_up else "combine", centre - Rules.BOARD_POS)
	Sfx.play("ui/merge" if ranked_up else "ui/combine")


func _right_press(pos: Vector2) -> void:
	if phase == Phase.PREP:
		for i in Rules.SHOP_SIZE:
			if Hud.offer_rect(i).has_point(pos):
				Sfx.play("ui/click" if player.toggle_lock(i) else "ui/fail")
				return


## Left click / tap on a living creature during combat casts the shapeshift.
## Clicks on empty board cells fizzle; clicks outside the board are ignored.
func _cast_at(pos: Vector2) -> void:
	if not Rect2(Rules.BOARD_POS, Rules.BOARD_SIZE).has_point(pos) or not player.can_cast():
		return # before the journey hands the player a wand, clicks do nothing
	var u := battle.unit_at(pos - Rules.BOARD_POS)
	if u == null or not battle.cast(0, u):
		fx.add("fizzle", pos - Rules.BOARD_POS)
		Sfx.play("ui/fail")


# --- Hover ---------------------------------------------------------------------------

func _process(dt: float) -> void:
	_apply_shake(dt)
	_advance_ui(dt)
	_watch_rule_spotlight()
	spotlight.advance(dt)
	field_full_flash = maxf(0.0, field_full_flash - dt)
	var mouse := get_global_mouse_position()
	hover_info = {}
	match phase:
		Phase.COMBAT, Phase.RESOLVE:
			var u: Unit = battle.unit_at(mouse - Rules.BOARD_POS) if battle else null
			if battle:
				for other in battle.units:
					other.hovered = other == u
			if u != null:
				hover_info = {"form": u.form_id, "team": u.team, "unit": u, "pos": mouse}
			else:
				# The docked bench stays readable during the fight.
				var benched := player.at_slot(_reserve_slot_at(mouse))
				if benched != null:
					hover_info = {"form": benched.form_id, "team": 0, "owned": benched, "pos": mouse}
		Phase.PREP:
			var c := _owned_at(mouse)
			if c != null:
				hover_info = {"form": c.form_id, "team": 0, "owned": c, "pos": mouse}
			else:
				var e: OwnedCreature = null
				for candidate in enemy.fielded():
					if enemy_display_position(candidate).distance_to(mouse - Rules.BOARD_POS) < Rules.BODY_RADIUS * Rules.CELL:
						e = candidate
						break
				if e != null:
					hover_info = {"form": e.form_id, "team": 1, "owned": e, "pos": mouse}
				else:
					for i in Rules.SHOP_SIZE:
						if Hud.offer_rect(i).has_point(mouse) and player.offers[i] != "":
							hover_info = {"form": player.offers[i], "team": 0, "pos": mouse}
		Phase.PACK:
			for i in offered_packs.size():
				var forms: Array = pack_at(i).forms
				for j in forms.size():
					if Hud.pack_token_pos(i, j, forms.size()).distance_to(mouse) < Hud.pack_token_radius(forms.size()):
						hover_info = {"form": forms[j], "team": 0, "pos": mouse}


## Forest lesson cue: the creature the player is invited to shapeshift (an ally
## before hexes, an enemy afterwards), or null once tried or when none is ready.
func learning_cast_target() -> Unit:
	if not player.learning_duel or phase != Phase.COMBAT or battle == null or learning_cast_tried:
		return null
	if not player.can_cast() or not battle.spells[0].can_cast():
		return null
	for u in battle.living(1 if ruleset.has(Ruleset.HEX) else 0):
		if u.immune_t <= 0.0 and battle.can_target(0, u):
			return u
	return null


## The druid's and the swamp witch's duels stop the fight while their cast
## waits, so the lesson cannot be skipped by doing nothing.
func awaiting_learning_cast() -> bool:
	if opponent < 0 or OpponentDB.get_opponent(opponent).rule not in [Ruleset.WAND, Ruleset.HEX]:
		return false
	return learning_cast_target() != null


## Starts the spotlight on the rule waiting in this duel and remembers it.
func _spotlight(at: Vector2, radii: Vector2, follow: Unit = null) -> void:
	spotlight.begin(at, radii, follow)
	if spotlight.rule not in journey.introduced:
		journey.introduced.append(spotlight.rule)
		_save_difficulty_progress(unlocked_difficulty)


## Starts the spotlight when its rule first shows up: interface elements as
## soon as they are on screen, the others when they happen. The harvest and
## the animal bonus start theirs from start_combat and _on_unit_transformed.
func _watch_rule_spotlight() -> void:
	if not spotlight.pending():
		return
	var rule := spotlight.rule
	var shop_shown := phase == Phase.PREP and shop_out <= 0.0 and not enemy_preparing
	if rule == Ruleset.SHOP and shop_shown:
		_spotlight(Hud.STALL_RECT.get_center(), Hud.STALL_RECT.size * 0.54)
	elif rule == Ruleset.TRADE and shop_shown:
		_spotlight(Hud.REROLL_RECT.get_center(), Vector2(Hud.REROLL_RECT.size.x * 0.56, 34))
	elif rule.begins_with("upgrade_") and shop_shown and scroll_open >= 1.0:
		var row := Rules.WAND_UPGRADES.find(rule.trim_prefix("upgrade_"))
		_spotlight(Hud.upgrade_rect(row).get_center(), Vector2(Hud.UPGRADE_SIZE.x * 0.58, 32))
	elif rule == Ruleset.MERGE and shop_shown:
		var demo := merge_demo()
		if not demo.is_empty():
			var a: Vector2 = demo.from
			var b: Vector2 = demo.to
			_spotlight((a + b) * 0.5, Vector2(absf(a.x - b.x) * 0.5 + 56, absf(a.y - b.y) * 0.5 + 56))
	elif phase != Phase.COMBAT or battle == null:
		return
	elif rule == Ruleset.WAND and player.can_cast():
		_spotlight(Hud.charge_pos(1), Vector2(120, 46))
	elif rule == Ruleset.HEX:
		var foes := battle.living(1)
		if not foes.is_empty():
			_spotlight(Rules.BOARD_POS + foes[0].position, Vector2(48, 48), foes[0])
	elif rule == Ruleset.CASTERS:
		for u in battle.units:
			if u.alive and u.channel_t > 0.0:
				_spotlight(Rules.BOARD_POS + u.position, Vector2(56, 56), u)
				break
	elif rule == Ruleset.FRENZY and battle.frenzy_level > 0:
		_spotlight(Rules.BOARD_POS + Vector2(Rules.BOARD_SIZE.x * 0.5, -40),
			Vector2(Rules.BOARD_SIZE.x * 0.5 + 24, 34))


## Two of the player's creatures that could merge (same form and stars), or [];
## a benched creature comes first, so it is the one shown moving.
func _first_pair() -> Array:
	for a: OwnedCreature in player.creatures:
		for b: OwnedCreature in player.creatures:
			if a != b and player.can_merge(a, b) and (not a.is_fielded() or b.is_fielded()):
				return [a, b]
	return []


func _owned_screen_position(c: OwnedCreature) -> Vector2:
	if c.slot >= 0:
		return bench_slot_rect(c.slot).get_center()
	return Rules.BOARD_POS + Rules.cell_center(c.cell)


## The thief's merge lesson: which drag to demonstrate, until the player's first
## merge of the duel. {"from", "to" (screen positions), "target": OwnedCreature},
## from a pair the player owns, else from an affordable identical offer; {} when
## there is nothing to show.
func merge_demo() -> Dictionary:
	if merge_lesson_done or phase != Phase.PREP or opponent < 0 or drag != null or shop_out > 0.0:
		return {}
	if OpponentDB.get_opponent(opponent).rule != Ruleset.MERGE or not ruleset.has(Ruleset.MERGE):
		return {}
	var pair := _first_pair()
	if not pair.is_empty():
		return {"from": _owned_screen_position(pair[0]), "to": _owned_screen_position(pair[1]), "target": pair[1]}
	for i in Rules.SHOP_SIZE:
		for c: OwnedCreature in player.creatures:
			if player.can_merge_offer(i, c):
				return {"from": Hud.offer_token_pos(i), "to": _owned_screen_position(c), "target": c}
	return {}


## True when dropping a creature that is not on the board onto an empty cell
## would be refused: the board already holds Rules.FIELD_CAP creatures.
func board_full_for(c: OwnedCreature) -> bool:
	return c != null and not c.is_fielded() and player.field_count() >= Rules.FIELD_CAP


## The table background never changes: drawn once (and again only when
## something calls queue_redraw, such as the art style switch).
func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.16, 0.12, 0.1))
	for i in 12:
		Shapes.line(self, Vector2(0, i * 64 + 20), Vector2(1280, i * 64 + 4), Color(0.19, 0.14, 0.11), 18.0)
