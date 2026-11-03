extends Node2D
## Prototype 02 game controller: the duel loop
## pack choice -> (shop + preparation -> combat -> resolution) x N -> game over.

enum Phase { PACK, PREP, COMBAT, RESOLVE, OVER }

const RESOLVE_TIME := 2.4

var phase := Phase.PACK
var player: WizardState
var enemy: WizardState
var states: Array[WizardState] = []
var round_num := 0
var pack_choices: Array = []
var battle: Battle = null
var rng := RandomNumberGenerator.new()
var no_spells := false # experiment toggle: disables casting for both wizards
var fast := false # combat speed x2
var drag: OwnedCreature = null
var hover_info := {}
var last_result := {}
var last_damage := 0
var last_damage_team := -1
var _resolve_t := 0.0

var board_view: BoardView
var fx: FxLayer
var hud: Hud


func _ready() -> void:
	rng.randomize()
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
	states = [player, enemy]
	round_num = 0
	drag = null
	last_result = {}
	var packs := CreatureDB.PACKS.duplicate()
	packs.shuffle()
	pack_choices = packs.slice(0, 3)
	phase = Phase.PACK


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
		s.gold += Rules.income(round_num)
		s.refresh_offers(rng)
	EnemyAI.shop(enemy, rng)
	phase = Phase.PREP


func start_combat() -> void:
	if player.field_count() == 0:
		Sfx.play("fail")
		return
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
	Sfx.play("click")


func _physics_process(dt: float) -> void:
	match phase:
		Phase.COMBAT:
			battle.step(dt)
			if fast and phase == Phase.COMBAT:
				battle.step(dt)
		Phase.RESOLVE:
			_resolve_t -= dt
			if _resolve_t <= 0.0:
				_finish_round()


func _on_battle_ended(result: Dictionary) -> void:
	last_result = result
	last_damage = 0
	last_damage_team = -1
	var winner: int = result.winner
	if winner >= 0:
		var loser := states[1 - winner]
		last_damage = mini(result.survivors, loser.hp)
		last_damage_team = loser.team
		loser.hp -= result.survivors
	Sfx.play("win" if winner == 0 else "lose" if winner == 1 else "click")
	if last_damage > 0:
		Sfx.play("damage")
	_resolve_t = RESOLVE_TIME
	phase = Phase.RESOLVE


func _finish_round() -> void:
	battle.queue_free()
	battle = null
	if player.hp <= 0 or enemy.hp <= 0:
		player.hp = maxi(0, player.hp)
		enemy.hp = maxi(0, enemy.hp)
		phase = Phase.OVER
	else:
		start_round()


func _on_unit_died(u: Unit) -> void:
	fx.add("rocket", u.position, {"form": u.form_id, "team": u.team})
	Sfx.play("death")


func _on_unit_transformed(u: Unit, _caster: int, _from: String) -> void:
	fx.add("shift", u.position)
	Sfx.play("shift")


# --- Input ---------------------------------------------------------------------------

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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
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
		Phase.PACK:
			for i in pack_choices.size():
				if Hud.pack_rect(i).has_point(pos):
					choose_pack(i)
					return
		Phase.PREP:
			if Hud.REROLL_RECT.has_point(pos):
				Sfx.play("click" if player.reroll(rng) else "fail")
				return
			if pos.distance_to(Rules.FIGHT_CENTER) < Rules.FIGHT_RADIUS:
				start_combat()
				return
			for i in Rules.SHOP_SIZE:
				if Hud.offer_rect(i).has_point(pos):
					if player.buy(i) != null:
						Sfx.play("buy")
					else:
						Sfx.play("fail")
					return
			drag = _owned_at(pos)
			if drag != null:
				Sfx.play("click")
		Phase.OVER:
			if pos.distance_to(Hud.RESTART_POS) < 46:
				Sfx.play("click")
				new_duel()


func _left_release(pos: Vector2) -> void:
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
	var slot := _reserve_slot_at(pos)
	var ok := false
	if slot >= 0:
		ok = player.move_to_slot(c, slot)
	elif player.owns_cell(board_cell(pos)):
		ok = player.move_to_cell(c, board_cell(pos))
	Sfx.play("click" if ok else "fail")


func _right_press(pos: Vector2) -> void:
	if phase == Phase.PREP:
		for i in Rules.SHOP_SIZE:
			if Hud.offer_rect(i).has_point(pos):
				Sfx.play("click" if player.toggle_lock(i) else "fail")
				return
	if phase != Phase.COMBAT:
		return
	var u := battle.unit_at(pos - Rules.BOARD_POS)
	if u == null or not battle.cast(0, u):
		fx.add("fizzle", pos - Rules.BOARD_POS)
		Sfx.play("fail")


# --- Hover ---------------------------------------------------------------------------

func _process(_dt: float) -> void:
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
				var cell := board_cell(mouse)
				var e: OwnedCreature = enemy.at_cell(cell) if enemy.owns_cell(cell) else null
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
