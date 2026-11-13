extends Node2D
## Prototype 02 game controller: the duel loop
## difficulty -> pack choice -> (shop + preparation -> combat -> resolution) x N
## -> game over -> difficulty again.

enum Phase { DIFFICULTY, PACK, PREP, COMBAT, RESOLVE, OVER }

const RESOLVE_TIME := 2.4
const ENEMY_ACTION_TIME := 0.55
const ENEMY_MOVE_TIME := 0.42
const SHOP_DRAG_DISTANCE := 8.0

var phase := Phase.PACK
var player: WizardState
var enemy: WizardState
var states: Array[WizardState] = []
var round_num := 0
var difficulty := Difficulty.ARCHMAGE # last chosen opponent level
var pack_choices: Array = []
var battle: Battle = null
var rng := RandomNumberGenerator.new()
var no_spells := false # experiment toggle: disables casting for both wizards
var fast := false # combat speed x2
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

var board_view: BoardView
var fx: FxLayer
var hud: Hud
var music: PhaseMusic


func _ready() -> void:
	rng.randomize()
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
	new_duel()


func new_duel() -> void:
	if battle != null:
		battle.queue_free()
		battle = null
	player = WizardState.new(0)
	enemy = WizardState.new(1)
	enemy.ai_level = difficulty
	states = [player, enemy]
	round_num = 0
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
	var packs := CreatureDB.PACKS.duplicate()
	packs.shuffle()
	pack_choices = packs.slice(0, 3)
	phase = Phase.DIFFICULTY
	music.transition_to("prep")


## Every duel starts by picking the opponent's hat; the level holds for the duel.
func choose_difficulty(level: int) -> void:
	difficulty = clampi(level, 0, Difficulty.COUNT - 1)
	enemy.ai_level = difficulty
	phase = Phase.PACK
	Sfx.play("click")


func choose_pack(index: int) -> void:
	for id in pack_choices[index]:
		player.add_creature(id)
	for id in EnemyAI.choose_pack(rng, CreatureDB.PACKS):
		enemy.add_creature(id)
	Sfx.play("buy")
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
		Sfx.play("fail")
		return
	hud.clear_loss_rewards()
	battle = Battle.new()
	battle.position = Rules.BOARD_POS
	add_child(battle)
	move_child(battle, board_view.get_index() + 1)
	battle.casting_enabled = not no_spells
	battle.setup(states)
	battle.unit_died.connect(_on_unit_died)
	battle.unit_transformed.connect(_on_unit_transformed)
	battle.fx_requested.connect(fx.add)
	battle.ended.connect(_on_battle_ended)
	drag = null
	phase = Phase.COMBAT
	music.transition_to("battle")
	Sfx.play("click")


func _physics_process(dt: float) -> void:
	match phase:
		Phase.PREP:
			_advance_enemy_preparation(dt)
		Phase.COMBAT:
			battle.step(dt)
			if fast and phase == Phase.COMBAT:
				battle.step(dt)
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
		Sfx.play("lose" if player.hp == 0 else "win")
	else:
		start_round()


func _on_unit_died(u: Unit) -> void:
	fx.add("rocket", u.position, {"form": u.form_id, "team": u.team})
	Sfx.play("death")


## Blessing (own creature) and hex (enemy creature) have distinct effects and
## sounds; both flash the creature and shake the board briefly.
func _on_unit_transformed(u: Unit, caster: int, _from: String) -> void:
	var blessing := u.team == caster
	fx.add("shift_bless" if blessing else "shift_hex", u.position)
	Sfx.play("shift_bless" if blessing else "shift_hex", 0.03)
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
		Sfx.play("buy")
	elif action.kind == "merge":
		for c in enemy.fielded():
			if c.uid == action.uid:
				fx.add("merge" if action.promoted else "combine", Rules.cell_center(c.cell))
		Sfx.play("merge" if action.promoted else "combine")
	elif action.kind == "sell":
		Sfx.play("coin_gain")
	else:
		Sfx.play("buy" if action.kind == "upgrade" else "click")


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


func show_merge_progress(c: OwnedCreature) -> bool:
	return hover_info.get("owned") == c or can_drop_merge(c)

func board_cell(screen_pos: Vector2) -> Vector2i:
	var local := (screen_pos - Rules.BOARD_POS) / Rules.CELL
	return Vector2i(floori(local.x), floori(local.y))


func _reserve_slot_at(pos: Vector2) -> int:
	for s in Rules.RESERVE_CAP:
		if Rules.reserve_slot_rect(s).has_point(pos):
			return s
	return -1


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
	if event.keycode != KEY_ENTER or not event.alt_pressed or Engine.is_embedded_in_editor():
		return
	var window := get_window()
	if window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		window.mode = Window.MODE_WINDOWED
	else:
		window.mode = Window.MODE_FULLSCREEN
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
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
		if event.keycode == KEY_SPACE and phase == Phase.PREP:
			start_combat()
		elif phase == Phase.DIFFICULTY and event.keycode >= KEY_1 and event.keycode < KEY_1 + Difficulty.COUNT:
			choose_difficulty(event.keycode - KEY_1)


func _left_press(pos: Vector2) -> void:
	if pos.distance_to(Hud.TOGGLE_FAST) < Hud.TOGGLE_R:
		fast = not fast
		Sfx.play("click")
		return
	if pos.distance_to(Hud.TOGGLE_NOSPELL) < Hud.TOGGLE_R:
		if phase != Phase.COMBAT and phase != Phase.RESOLVE:
			no_spells = not no_spells
			Sfx.play("click")
		else:
			Sfx.play("fail")
		return
	match phase:
		Phase.DIFFICULTY:
			for i in Difficulty.COUNT:
				if Hud.difficulty_rect(i).has_point(pos):
					choose_difficulty(i)
					return
		Phase.PACK:
			for i in pack_choices.size():
				if Hud.pack_rect(i).has_point(pos):
					choose_pack(i)
					return
		Phase.PREP:
			if Hud.SHIFT_UPGRADE_RECT.has_point(pos):
				Sfx.play("buy" if player.upgrade_shift_recharge() else "fail")
				return
			if Hud.REROLL_RECT.has_point(pos):
				Sfx.play("click" if player.reroll(rng) else "fail")
				return
			if pos.distance_to(Rules.FIGHT_CENTER) < Rules.FIGHT_RADIUS:
				start_combat()
				return
			for i in Rules.SHOP_SIZE:
				if Hud.offer_rect(i).has_point(pos):
					if player.offers[i] != "" and player.gold >= CreatureDB.get_form(player.offers[i]).price:
						shop_drag_index = i
						shop_drag_origin = pos
						shop_drag_position = pos
						shop_drag_active = false
						drag = OwnedCreature.new(player.offers[i])
					else:
						Sfx.play("fail")
					return
			drag = _owned_at(pos)
			if drag != null:
				Sfx.play("click")
		Phase.COMBAT:
			_cast_at(pos)
		Phase.OVER:
			if pos.distance_to(Hud.RESTART_POS) < 46:
				Sfx.play("click")
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
	if Rules.SHOP_RECT.has_point(pos):
		player.sell(c)
		Sfx.play("buy")
		return
	var recipient := _owned_at(pos)
	var combining := player.can_merge(c, recipient)
	var previous_stars := recipient.stars if combining else -1
	var slot := _reserve_slot_at(pos)
	var ok := false
	if slot >= 0:
		ok = player.move_to_slot(c, slot)
	elif player.owns_cell(board_cell(pos)):
		ok = player.move_to_cell(c, board_cell(pos))
	if ok and combining:
		_merge_feedback(recipient, previous_stars)
	else:
		Sfx.play("click" if ok else "fail")


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
		bought = player.buy_to_cell(index, board_cell(pos))
	else:
		var slot := _reserve_slot_at(pos)
		if slot >= 0:
			bought = player.buy_to_slot(index, slot)
	if bought == null:
		Sfx.play("fail")
	elif combining:
		_merge_feedback(bought, previous_stars)
	else:
		Sfx.play("buy")


func _merge_feedback(recipient: OwnedCreature, previous_stars: int) -> void:
	var ranked_up := recipient.stars > previous_stars
	var centre := Rules.BOARD_POS + Rules.cell_center(recipient.cell) if recipient.is_fielded() else Rules.reserve_slot_rect(recipient.slot).get_center()
	fx.add("merge" if ranked_up else "combine", centre - Rules.BOARD_POS)
	Sfx.play("merge" if ranked_up else "combine")


func _right_press(pos: Vector2) -> void:
	if phase == Phase.PREP:
		for i in Rules.SHOP_SIZE:
			if Hud.offer_rect(i).has_point(pos):
				Sfx.play("click" if player.toggle_lock(i) else "fail")
				return


## Left click / tap on a living creature during combat casts the shapeshift.
## Clicks on empty board cells fizzle; clicks outside the board are ignored.
func _cast_at(pos: Vector2) -> void:
	if not Rect2(Rules.BOARD_POS, Rules.BOARD_SIZE).has_point(pos):
		return
	var u := battle.unit_at(pos - Rules.BOARD_POS)
	if u == null or not battle.cast(0, u):
		fx.add("fizzle", pos - Rules.BOARD_POS)
		Sfx.play("fail")


# --- Hover ---------------------------------------------------------------------------

func _process(dt: float) -> void:
	_apply_shake(dt)
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
			for i in pack_choices.size():
				for j in pack_choices[i].size():
					if Hud.pack_token_pos(i, j).distance_to(mouse) < 24:
						hover_info = {"form": pack_choices[i][j], "team": 0, "pos": mouse}
	queue_redraw()


func _draw() -> void:
	# Table background.
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.16, 0.12, 0.1))
	for i in 12:
		draw_line(Vector2(0, i * 64 + 20), Vector2(1280, i * 64 + 4), Color(0.19, 0.14, 0.11), 18.0)
