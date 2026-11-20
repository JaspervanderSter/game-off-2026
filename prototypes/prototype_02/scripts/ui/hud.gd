class_name Hud
extends Node2D
## Side panels, buttons, overlays and the hover card.

const ENEMY_BLOCK := Rect2(24, 84, 300, 140)
const PLAYER_BLOCK := Rect2(24, 376, 300, 156)
# Round frieze centred above the board, clear of the combat timer bar (y 50).
const FRIEZE_CENTER := Vector2(640, 26)
const FRIEZE_STEP := 36.0
const FRIEZE_PAST := 7 # finished rounds shown left of the current one
const FRIEZE_FUTURE := 3
const FRIEZE_RADIUS := 17.0
const FRIEZE_PIP := 9.0
const FRIEZE_SLIDE := 0.45
const FRIEZE_LINE := Color(0.42, 0.35, 0.28)
const FRIEZE_DRAW := Color(0.55, 0.5, 0.45)
const RESTART_POS := Vector2(640, 420)
const VICTORY_POS := Vector2(640, 255)
const UNLOCK_CLICK := 0.48
const UNLOCK_OPEN_TIME := 0.24
const UNLOCK_DURATION := 1.40
const VictoryFx := preload("res://scripts/ui/victory_fx.gd")
const OFFER_SIZE := Vector2(288, 112)
const REROLL_RECT := Rect2(1000, 458, 224, 42)
const SHIFT_UPGRADE_RECT := Rect2(976, 636, 272, 54)
const PACK_TOP := 222.0
const PACK_CARD_SIZE := Vector2i(176, 168)
const DIFFICULTY_CARD_SIZE := Vector2i(168, 260)
const CHOICE_HALO_MARGIN := 12
const CHOICE_HALO_FADE := 0.16
const SHOP_SLIDE := 360.0 # pushes the whole shop column past the right edge
const HEART_STAGGER := 0.26
const HEART_BURST := 0.20
const COIN_FLIGHT := 0.62
const REWARD_TAIL := 0.45
# Combat-start harvest: each fielded harvester hops in turn, its coins burst out
# in a fan above it, hover a beat, then fly one by one into the wizard's purse.
const HARVEST_DELAY := 0.35
const HARVEST_STAGGER := 0.26
const HARVEST_HOP := 0.42
const HARVEST_POP := 0.34
const HARVEST_HOVER := 0.18
const HARVEST_COIN_STAGGER := 0.09
const HARVEST_FLIGHT := 0.58
## Harvest coin sound events, coins/harvest/1 to /8, each a step higher; later
## coins of the same harvester replay the last one.
const HARVEST_COIN_SOUNDS := 8

var game # main.gd
var font: Font
var loss_rewards: Array[Dictionary] = []
var reward_time := 0.0
var harvest_time := 0.0
var harvest_sources: Array[Dictionary] = []
var harvest_coins: Array[Dictionary] = []
var victory := VictoryFx.new()
var unlock_level := -1
var unlock_time := 0.0
var difficulty_halo: Texture2D
var pack_halo: Texture2D
var choice_hover := PackedFloat32Array()
var choice_phase := -1
var frieze_round := 0
var frieze_time := FRIEZE_SLIDE
## Canvas item the drawing functions draw on: one of the layers below.
var _ci: CanvasItem = self
## Child canvas items in drawing order, each {"node", "key"}. Every redraw
## rebuilds a layer's draw commands, so the side panels and the shop column
## redraw only when what they show changes (their key); the others every frame.
var _layers := {}


func _ready() -> void:
	font = ThemeDB.fallback_font
	difficulty_halo = _make_choice_halo(DIFFICULTY_CARD_SIZE)
	pack_halo = _make_choice_halo(PACK_CARD_SIZE)
	for layer_name in ["panels", "base", "shop", "overlay"]:
		var layer := Node2D.new()
		layer.name = layer_name.capitalize()
		layer.draw.connect(_draw_layer.bind(layer_name, layer))
		add_child(layer)
		_layers[layer_name] = {"node": layer, "key": null}
	set_process_internal(true)


func _process(dt: float) -> void:
	advance_loss_rewards(dt)
	advance_harvest(dt)
	advance_round_frieze(dt)
	if game.phase == game.Phase.OVER:
		victory.advance(dt)
	elif game.phase == game.Phase.DIFFICULTY:
		advance_difficulty_unlock(dt)
	if game.phase == game.Phase.DIFFICULTY or game.phase == game.Phase.PACK:
		_advance_choice_hover(dt)
	else:
		choice_phase = -1
	_refresh_layers()


## Layers refresh at the end of _process, after this frame's animation steps.
## Tests that stop the HUD's processing to step animations by hand still need
## them refreshed: internal processing does it then.
func _notification(what: int) -> void:
	if what == NOTIFICATION_INTERNAL_PROCESS and not is_processing():
		_refresh_layers()


func _advance_choice_hover(dt: float) -> void:
	var picking_difficulty: bool = game.phase == game.Phase.DIFFICULTY
	var card_count: int = Difficulty.COUNT if picking_difficulty else game.offered_packs.size()
	if choice_phase != game.phase:
		choice_phase = game.phase
		choice_hover.resize(card_count)
		choice_hover.fill(0.0)
	var mouse := get_global_mouse_position()
	for i in card_count:
		var rect := difficulty_rect(i) if picking_difficulty else pack_rect(i)
		var selectable: bool = not picking_difficulty or (game.is_difficulty_unlocked(i) and not unlock_animation_active())
		var target := 1.0 if selectable and rect.has_point(mouse) else 0.0
		choice_hover[i] = move_toward(choice_hover[i], target, dt / CHOICE_HALO_FADE)


## The frieze slides one step left when the next round of the same duel begins;
## a new duel snaps back to round 1.
func advance_round_frieze(dt: float) -> void:
	var shown := maxi(1, game.round_num)
	if shown != frieze_round:
		frieze_time = 0.0 if frieze_round > 0 and shown == frieze_round + 1 else FRIEZE_SLIDE
		frieze_round = shown
	frieze_time = minf(frieze_time + dt, FRIEZE_SLIDE)


func begin_difficulty_unlock(level: int) -> void:
	unlock_level = level
	unlock_time = 0.0


func unlock_animation_active() -> bool:
	return unlock_level >= 0


func advance_difficulty_unlock(dt: float) -> void:
	if not unlock_animation_active():
		return
	var previous := unlock_time
	unlock_time += dt
	if previous < UNLOCK_CLICK and unlock_time >= UNLOCK_CLICK:
		Sfx.play("ui/difficulty_unlock")
	if unlock_time >= UNLOCK_DURATION:
		unlock_level = -1


func begin_victory() -> void:
	victory.start(VICTORY_POS)


func clear_victory() -> void:
	victory.clear()


func clear_harvest() -> void:
	harvest_sources.clear()
	harvest_coins.clear()
	harvest_time = 0.0


## Queues the harvest animation for one wizard. Rules already granted the gold;
## displayed_gold() hides each coin until it lands. sources: [{uid, pos, gold}]
## with screen positions.
func begin_harvest(team: int, sources: Array[Dictionary]) -> void:
	var base := harvest_time + HARVEST_DELAY
	for i in sources.size():
		var src: Dictionary = sources[i]
		var start := base + i * HARVEST_STAGGER
		var from: Vector2 = src.pos
		harvest_sources.append({"team": team, "uid": src.uid, "pos": from, "start": start, "popped": false})
		var n: int = src.gold
		var fan := minf(1.25, 0.3 * (n - 1))
		for j in n:
			var spread := 0.0 if n == 1 else (j - (n - 1) / 2.0) / ((n - 1) / 2.0)
			var radius := 42.0 + (12.0 if n > 4 and j % 2 == 1 else 0.0)
			harvest_coins.append({"team": team, "uid": src.uid, "from": from, "index": j, "start": start + j * 0.025,
				"offset": Vector2.from_angle(-PI / 2 + spread * fan) * radius,
				"fly": start + HARVEST_POP + HARVEST_HOVER + j * HARVEST_COIN_STAGGER, "arrived": false})


## Seconds until the last queued coin of a team has landed (0 when none).
func harvest_remaining(team: int) -> float:
	var remaining := 0.0
	for coin in harvest_coins:
		if coin.team == team:
			remaining = maxf(remaining, coin.fly + HARVEST_FLIGHT - harvest_time)
	return remaining


func advance_harvest(dt: float) -> void:
	if harvest_sources.is_empty() and harvest_coins.is_empty():
		return
	harvest_time += dt
	for src in harvest_sources:
		if not src.popped and harvest_time >= src.start:
			src.popped = true
			_pop_harvester(src)
			Sfx.play("coins/pop")
	for coin in harvest_coins:
		if not coin.arrived and harvest_time >= coin.fly + HARVEST_FLIGHT:
			coin.arrived = true
			# Each landing coin rings a little higher: a rising cash-register run.
			Sfx.play("coins/harvest/%d" % mini(coin.index + 1, HARVEST_COIN_SOUNDS))
	harvest_sources = harvest_sources.filter(func(s): return harvest_time < s.start + HARVEST_HOP + 0.3)
	harvest_coins = harvest_coins.filter(func(c): return harvest_time < c.fly + HARVEST_FLIGHT + REWARD_TAIL)


## The harvester's combat unit hops where it now stands, and its coins burst
## out from there (it may have walked since the fight began).
func _pop_harvester(src: Dictionary) -> void:
	var b: Battle = game.battle if game != null else null
	if b == null:
		return
	for u in b.units:
		if u.alive and u.team == src.team and u.source_uid == src.uid:
			u.beat_t = HARVEST_HOP
			u.beat_len = HARVEST_HOP
			src.pos = Rules.BOARD_POS + u.position
			for coin in harvest_coins:
				if coin.team == src.team and coin.uid == src.uid:
					coin.from = src.pos
			return


func clear_loss_rewards() -> void:
	loss_rewards.clear()
	reward_time = 0.0


func begin_loss_rewards(team: int, hp_before: float, count: float, coin_count: int = 0, compensation_before: float = 0.0) -> void:
	clear_loss_rewards()
	var halves := roundi(count * 2.0)
	for i in halves:
		var half_index := roundi(hp_before * 2.0) - 1 - i
		var coin := coin_count > 0 and floori(compensation_before + (i + 1) * 0.5) > floori(compensation_before + i * 0.5)
		loss_rewards.append({"team": team, "heart": floori(half_index / 2.0), "half": half_index % 2,
			"start": 0.22 + i * HEART_STAGGER, "burst": false, "arrived": false, "coin": coin})


func loss_reward_duration() -> float:
	var duration := 0.0
	for reward in loss_rewards:
		var tail := HEART_BURST + COIN_FLIGHT + REWARD_TAIL if reward.coin else 0.48 + 0.3
		duration = maxf(duration, reward.start + tail)
	return duration


func advance_loss_rewards(dt: float) -> void:
	reward_time += dt
	for reward in loss_rewards:
		var age: float = reward_time - reward.start
		if age >= 0.0 and not reward.burst:
			reward.burst = true
			Sfx.play("duel/heart_break")
		if age >= HEART_BURST + COIN_FLIGHT and not reward.arrived:
			reward.arrived = true
			if reward.coin:
				Sfx.play("coins/compensation")


## Rules settle immediately; presentation reveals each loss and coin in order.
func displayed_hp(state: WizardState) -> float:
	var value := state.hp
	for reward in loss_rewards:
		if reward.team == state.team and not reward.burst:
			value += 0.5
	return value


func displayed_gold(state: WizardState) -> int:
	var value := state.gold
	for reward in loss_rewards:
		if reward.team == state.team and reward.coin and not reward.arrived:
			value -= 1
	for coin in harvest_coins:
		if coin.team == state.team and not coin.arrived:
			value -= 1
	return value


static func heart_pos(team: int, index: int) -> Vector2:
	var block := PLAYER_BLOCK if team == 0 else ENEMY_BLOCK
	return block.position + Vector2(92 + index * 20.5, 36)


static func gold_pos(team: int) -> Vector2:
	var block := PLAYER_BLOCK if team == 0 else ENEMY_BLOCK
	return block.position + Vector2(42, 124)


# --- Geometry used for hit tests -------------------------------------------------

static func offer_rect(i: int) -> Rect2:
	return Rect2(Rules.SHOP_RECT.position + Vector2(0, i * 124), OFFER_SIZE)


static func pack_rect(i: int) -> Rect2:
	return Rect2(Vector2(364 + i * 188, PACK_TOP), Vector2(PACK_CARD_SIZE))


static func difficulty_rect(i: int) -> Rect2:
	return Rect2(Vector2(372 + i * 184, 170), Vector2(DIFFICULTY_CARD_SIZE))


## Opponent hat shown in the enemy panel: the hovered card previews its level.
func shown_difficulty() -> int:
	if game.phase == game.Phase.DIFFICULTY and not unlock_animation_active():
		for i in Difficulty.COUNT:
			if game.is_difficulty_unlocked(i) and difficulty_rect(i).has_point(get_global_mouse_position()):
				return i
	return game.enemy.ai_level


## Creature j of the n shown on card i, centred; four creatures sit closer.
static func pack_token_pos(i: int, j: int, n: int) -> Vector2:
	var spacing := 54.0 if n <= 3 else 40.0
	var r := pack_rect(i)
	return Vector2(r.get_center().x + (j - (n - 1) * 0.5) * spacing, r.position.y + 88)


static func pack_token_radius(n: int) -> float:
	return 24.0 if n <= 3 else 19.0


static func charge_pos(i: int) -> Vector2:
	return Vector2(640 + (i - 1) * 64, 584)


# --- Drawing ------------------------------------------------------------------------

func _refresh_layers() -> void:
	for layer_name in _layers:
		var layer: Dictionary = _layers[layer_name]
		var key: Variant = _layer_key(layer_name)
		if key == null or key != layer.key:
			layer.key = key
			layer.node.queue_redraw()


## What a layer shows, compared each frame to skip unchanged redraws; null for
## layers that animate every frame.
func _layer_key(layer_name: String) -> Variant:
	match layer_name:
		"panels":
			return [game.phase, game.round_num, _wizard_key(game.enemy), _wizard_key(game.player)]
		"shop":
			return _shop_key()
	return null


func _wizard_key(state: WizardState) -> Array:
	var key := [displayed_hp(state), displayed_gold(state), _wizard_pulse(state.team), state.harvest_total()]
	if game.battle != null:
		var spell: ShiftSpell = game.battle.spells[state.team]
		key.append_array([spell.charges, spell.progress()])
	return key


func _shop_key() -> Array:
	var player: WizardState = game.player
	var key := [game.shop_out, game.phase, player.gold, player.offers.duplicate(), player.locked.duplicate(),
		game.drag != null, game.shop_drag_index, player.can_reroll(), player.field_count(), game.enemy_preparing,
		player.shift_recharge_upgraded, player.can_upgrade_shift_recharge()]
	if smoothstep(0.0, 1.0, float(game.shop_out)) >= 1.0:
		return key # off screen: nothing else shows
	var mouse := get_global_mouse_position()
	for i in Rules.SHOP_SIZE:
		key.append(offer_rect(i).has_point(mouse))
	key.append(Rules.FIGHT_CENTER.distance_to(mouse) < Rules.FIGHT_RADIUS)
	key.append(Rect2(Rules.SHOP_RECT.position, Vector2(OFFER_SIZE.x, 124 * Rules.SHOP_SIZE - 12)).has_point(mouse))
	if game.enemy_preparing:
		key.append(Time.get_ticks_msec()) # the spinner around the fight button turns
	return key


## Draws one layer, from the bottom: side panels, then the round frieze and
## phase screens, then the shop column, then hover card and travelling effects.
func _draw_layer(layer_name: String, layer: CanvasItem) -> void:
	_ci = layer
	match layer_name:
		"panels":
			_draw_wizard(game.enemy, ENEMY_BLOCK)
			_draw_wizard(game.player, PLAYER_BLOCK)
		"base":
			_draw_enemy_hat()
			_draw_round_frieze()
			match game.phase:
				game.Phase.DIFFICULTY, game.Phase.PACK:
					_ci.draw_rect(get_viewport_rect(), Color(0, 0, 0, 0.45))
					if game.phase == game.Phase.DIFFICULTY:
						_draw_difficulty_choice()
					else:
						_draw_pack_choice()
				game.Phase.COMBAT:
					_draw_combat_hud()
				game.Phase.RESOLVE:
					_draw_combat_hud()
					_draw_result()
				game.Phase.OVER:
					_draw_game_over()
		"shop":
			_draw_shop_column()
		"overlay":
			if not game.hover_info.is_empty() and game.drag == null and game.phase != game.Phase.RESOLVE:
				_draw_hover_card(game.hover_info)
			_draw_loss_rewards()
			_draw_harvest()
			_draw_enemy_preparation()
			if game.shop_drag_index >= 0 and game.drag_visual_active():
				# Shop previews travel above the cards and side panels, without being
				# purchased or placed on the bench until the mouse is released.
				var p: Vector2 = game.shop_drag_position
				Shapes.circle(_ci, p + Vector2(4, 10), 22, Color(0, 0, 0, 0.3))
				Icons.token(_ci, game.drag.form_id, p, Rules.BODY_RADIUS * Rules.CELL * 1.1, 0, true)
	_ci = self


func _panel(r: Rect2, col := Color(0.12, 0.09, 0.08, 0.85)) -> void:
	_ci.draw_rect(r, col)
	_ci.draw_rect(r, Color(0.45, 0.32, 0.2), false, 2.0)


## Panel shake after a lost heart (x) and gold coin pulse (y) of a wizard.
func _wizard_pulse(team: int) -> Vector2:
	var impact := 0.0
	var coin_pulse := 0.0
	for reward in loss_rewards:
		if reward.team != team:
			continue
		var age: float = reward_time - reward.start
		if age >= 0.0 and age < 0.24:
			impact = maxf(impact, 1.0 - age / 0.24)
		var arrival_age := age - HEART_BURST - COIN_FLIGHT
		if reward.coin and arrival_age >= 0.0 and arrival_age < REWARD_TAIL:
			coin_pulse = maxf(coin_pulse, 1.0 - arrival_age / REWARD_TAIL)
	for coin in harvest_coins:
		var landed: float = harvest_time - coin.fly - HARVEST_FLIGHT
		if coin.team == team and landed >= 0.0 and landed < REWARD_TAIL:
			coin_pulse = maxf(coin_pulse, 1.0 - landed / REWARD_TAIL)
	if team == 1 and game.phase == game.Phase.PREP and not game.enemy_action.is_empty():
		var action: Dictionary = game.enemy_action
		if action.kind == "buy" and action.t < 0.45:
			coin_pulse = maxf(coin_pulse, (1.0 - action.t / 0.45) * 0.7)
	return Vector2(impact, coin_pulse)


func _hat_position(team: int) -> Vector2:
	var block := PLAYER_BLOCK if team == 0 else ENEMY_BLOCK
	var impact := _wizard_pulse(team).x
	var shake := Vector2(sin(reward_time * 95.0) * 5.0, cos(reward_time * 80.0) * 2.0) * impact
	return block.position + Vector2(42, 48) + shake


## The opponent's hat animates (its level shows on hover during the choice), so
## it is drawn every frame above its panel.
func _draw_enemy_hat() -> void:
	var impact := _wizard_pulse(1).x
	Icons.difficulty_hat(_ci, shown_difficulty(), _hat_position(1) + Vector2(0, 5), 22 * (1.0 + impact * 0.12), Time.get_ticks_msec() / 1000.0)


func _draw_wizard(state: WizardState, block: Rect2) -> void:
	_panel(block)
	var team := state.team
	var pulse := _wizard_pulse(team)
	var impact := pulse.x
	var coin_pulse := pulse.y
	if impact > 0.0:
		_ci.draw_rect(block, Color(1.0, 0.15, 0.2, 0.23 * impact))
	var hat_pos := _hat_position(team)
	if team == 1:
		# The opponent wears the hat of the chosen difficulty (drawn by
		# _draw_enemy_hat), over its red team glow.
		Shapes.circle(_ci, hat_pos, 31, Color(Icons.team_color(1), 0.2))
		Shapes.arc(_ci, hat_pos, 31, 0, TAU, 32, Color(Icons.team_color(1), 0.55), 2.0, true)
	else:
		Icons.wizard_hat(_ci, hat_pos, 26 * (1.0 + impact * 0.12), team)
	var shown_hp := displayed_hp(state)
	for i in Rules.WIZARD_HP:
		var p := block.position + Vector2(92 + i * 20.5, 36)
		Icons.wizard_heart(_ci, p, 9, clampf(shown_hp - i, 0.0, 1.0))
	# Spell charges (live in combat; the starting charge otherwise).
	var spell: ShiftSpell = null
	if game.battle != null:
		spell = game.battle.spells[team]
	for i in Rules.MAX_CHARGES:
		var p := block.position + Vector2(100 + i * 34, 84)
		var count: int = spell.charges if spell else Rules.START_CHARGES
		var filled: bool = count > i
		var prog := 0.0
		if spell and i == spell.charges:
			prog = spell.progress()
		Icons.charge_orb(_ci, p, 12, filled, prog)
	Icons.coin(_ci, gold_pos(team), 15 * (1.0 + coin_pulse * 0.45))
	_ci.draw_string(font, block.position + Vector2(66, 135 - coin_pulse * 5), str(displayed_gold(state)), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Icons.GOLD.lerp(Color.WHITE, coin_pulse))
	if team == 0 and game.phase != game.Phase.PACK:
		var next_income := Rules.income(game.round_num + 1)
		if game.phase == game.Phase.PREP:
			# The current board's harvest is paid when this round's fight begins.
			next_income += state.harvest_total()
		Icons.coin(_ci, block.position + Vector2(150, 124), 9)
		_ci.draw_string(font, block.position + Vector2(163, 132), "+" + str(next_income), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.8, 0.5, 0.7))


func _draw_loss_rewards() -> void:
	for reward in loss_rewards:
		var age: float = reward_time - reward.start
		var origin := heart_pos(reward.team, reward.heart)
		var dest := gold_pos(reward.team)
		# Anticipation: the next heart swells and flashes before it breaks.
		if age >= -0.16 and age < 0.0:
			var anticipation := (age + 0.16) / 0.16
			Icons.heart_half(_ci, origin, 9.0 + anticipation * 7.0, reward.half, Color(1, 0.3, 0.4).lerp(Color.WHITE, anticipation))
		if age < 0.0:
			continue
		if age < 0.48:
			var k := age / 0.48
			Shapes.arc(_ci, origin, 7 + 33 * k, 0, TAU, 32, Color(1, 0.35, 0.4, 1.0 - k), 4.0 * (1.0 - k) + 1.0, true)
			for j in 9:
				var direction := Vector2.from_angle(TAU * j / 9.0 + reward.heart * 0.7)
				var p := origin + direction * (12 + 38 * k) + Vector2(0, 30 * k * k)
				Icons.heart_half(_ci, p, 4.5 * (1.0 - k), reward.half, Color(1, 0.18, 0.3, 1.0 - k))
		if age < HEART_BURST:
			var k := age / HEART_BURST
			Icons.heart_half(_ci, origin + Vector2(0, -8 * k), 16 * (1.0 - k), reward.half, Color(1, 0.65, 0.7, 1.0 - k))
		if not reward.coin:
			continue
		var flight := (age - HEART_BURST) / COIN_FLIGHT
		if flight >= 0.0 and flight < 1.0:
			var control := origin.lerp(dest, 0.5) + Vector2(100, -45)
			# Curved, accelerating flight, with a gold trail and spinning coin.
			var progress := flight * flight
			for j in 7:
				var t := maxf(0.0, progress - j * 0.035)
				var trail := origin.bezier_interpolate(control, control, dest, t)
				Shapes.circle(_ci, trail, 6.0 - j * 0.65, Color(1, 0.75, 0.12, (1.0 - j / 7.0) * 0.5))
			var p := origin.bezier_interpolate(control, control, dest, progress)
			Shapes.set_transform(_ci, p, sin(flight * TAU * 2) * 0.2, Vector2(0.35 + absf(cos(flight * TAU * 2)) * 0.65, 1))
			Icons.coin(_ci, Vector2.ZERO, 13 + sin(flight * PI) * 4)
			Shapes.set_transform(_ci, Vector2.ZERO, 0, Vector2.ONE)
		var arrived := age - HEART_BURST - COIN_FLIGHT
		if arrived >= 0.0 and arrived < REWARD_TAIL:
			var k := arrived / REWARD_TAIL
			Shapes.arc(_ci, dest, 16 + 30 * k, 0, TAU, 32, Color(1, 0.85, 0.3, 1.0 - k), 4 * (1.0 - k), true)
			for j in 7:
				Icons.star(_ci, dest + Vector2.from_angle(TAU * j / 7.0) * (18 + k * 28), 5 * (1.0 - k), Color(1, 0.9, 0.35, 1.0 - k))


func _draw_harvest() -> void:
	# Harvester burst: a golden flash and ring with sparkles under the hop.
	for src in harvest_sources:
		var age: float = harvest_time - src.start
		if age < 0.0 or age >= 0.5:
			continue
		var k := age / 0.5
		var p: Vector2 = src.pos
		Shapes.circle(_ci, p, 30.0 * (1.0 - k * 0.4), Color(1.0, 0.85, 0.3, 0.35 * (1.0 - k)))
		Shapes.arc(_ci, p, 18.0 + 36.0 * k, 0, TAU, 32, Color(1.0, 0.85, 0.3, 1.0 - k), 5.0 * (1.0 - k) + 1.0, true)
		for j in 8:
			var q := p + Vector2.from_angle(TAU * j / 8.0 + 0.4) * (22.0 + 30.0 * k)
			Icons.star(_ci, q, 5.0 * (1.0 - k), Color(1.0, 0.92, 0.45, 1.0 - k))
	for coin in harvest_coins:
		var age: float = harvest_time - coin.start
		if age < 0.0:
			continue
		var from: Vector2 = coin.from
		var hover: Vector2 = from + coin.offset
		var dest := gold_pos(coin.team)
		var flight: float = (harvest_time - coin.fly) / HARVEST_FLIGHT
		var spin: float = harvest_time * 9.0 + coin.index * 0.8
		if flight < 0.0:
			# Pop out with an overshoot, then hover, bobbing, spinning and twinkling.
			var k := clampf(age / HARVEST_POP, 0.0, 1.0)
			var e := 1.0 + 2.70158 * pow(k - 1.0, 3) + 1.70158 * pow(k - 1.0, 2)
			var p := from.lerp(hover, e) + Vector2(0, -sin(k * PI) * 14.0 + sin(harvest_time * 10.0 + coin.index) * 2.0 * k)
			_spinning_coin(p, 13.0 * (0.35 + 0.65 * e), spin)
			if k >= 1.0 and fmod(harvest_time * 3.0 + coin.index * 0.37, 1.0) < 0.3:
				var tw := fmod(harvest_time * 3.0 + coin.index * 0.37, 1.0) / 0.3
				Icons.star(_ci, p + Vector2(9, -9), 5.0 * sin(tw * PI), Color(1, 1, 0.85))
		elif flight < 1.0:
			# Curved, accelerating flight with a fading gold trail.
			var control := hover.lerp(dest, 0.5) + Vector2(0, -90)
			var progress := flight * flight
			for j in 8:
				var t := maxf(0.0, progress - j * 0.03)
				var trail := hover.bezier_interpolate(control, control, dest, t)
				Shapes.circle(_ci, trail, 6.5 - j * 0.7, Color(1, 0.75, 0.12, (1.0 - j / 8.0) * 0.55))
			var p := hover.bezier_interpolate(control, control, dest, progress)
			_spinning_coin(p, 13.0 + sin(flight * PI) * 5.0, spin)
		else:
			# Landing: a ring and a little star burst on the purse.
			var k := clampf((flight - 1.0) * HARVEST_FLIGHT / REWARD_TAIL, 0.0, 1.0)
			Shapes.arc(_ci, dest, 16 + 26 * k, 0, TAU, 32, Color(1, 0.85, 0.3, 1.0 - k), 4 * (1.0 - k) + 0.5, true)
			for j in 5:
				var a: float = TAU * j / 5.0 + coin.index * 0.6
				Icons.star(_ci, dest + Vector2.from_angle(a) * (16 + k * 24), 4.5 * (1.0 - k), Color(1, 0.9, 0.35, 1.0 - k))


## A coin seen turning on its vertical axis, with a bright rim on its edge.
func _spinning_coin(p: Vector2, r: float, spin: float) -> void:
	Shapes.circle(_ci, p + Vector2(2, 4), r * 0.9, Color(0, 0, 0, 0.25))
	Shapes.set_transform(_ci, p, 0.0, Vector2(0.25 + absf(cos(spin)) * 0.75, 1.0))
	Icons.coin(_ci, Vector2.ZERO, r)
	Shapes.set_transform(_ci, Vector2.ZERO, 0.0, Vector2.ONE)
	Shapes.circle(_ci, p + Vector2(-r * 0.3, -r * 0.35), r * 0.18, Color(1, 1, 0.9, 0.8))


## Finished rounds as pips in the winner's colour (grey for a draw), the current
## round as a gold medallion with its number, upcoming rounds as fading dashes.
## Once the round resolves, the medallion's ring takes the winner's colour.
func _draw_round_frieze() -> void:
	var current := maxi(1, game.round_num)
	var winners: Array[int] = game.round_winners
	var k := smoothstep(0.0, 1.0, frieze_time / FRIEZE_SLIDE)
	var center := FRIEZE_CENTER + Vector2(FRIEZE_STEP * (1.0 - k), 0)
	# The oldest pip fades out while the frieze slides.
	var oldest := maxi(1, current - FRIEZE_PAST - (1 if k < 1.0 else 0))
	Shapes.line(_ci, center - Vector2((current - oldest) * FRIEZE_STEP, 0),
		center + Vector2(FRIEZE_FUTURE * FRIEZE_STEP, 0), FRIEZE_LINE, 3.0, true)
	for r in range(oldest, current):
		var p := center - Vector2((current - r) * FRIEZE_STEP, 0)
		var alpha := 1.0 - k if current - r > FRIEZE_PAST else 1.0
		var winner: int = winners[r - 1] if r - 1 < winners.size() else -1
		var col := Icons.team_color(winner) if winner >= 0 else FRIEZE_DRAW
		Shapes.circle(_ci, p, FRIEZE_PIP, Color(col, alpha))
		Shapes.arc(_ci, p, FRIEZE_PIP, 0, TAU, 20, Color(0, 0, 0, 0.35 * alpha), 1.5, true)
	for i in FRIEZE_FUTURE:
		var p := center + Vector2((i + 1) * FRIEZE_STEP, 0)
		_dashed_ring(p, FRIEZE_PIP - 1.0, Color(FRIEZE_LINE.lightened(0.2), 0.75 * (1.0 - float(i) / FRIEZE_FUTURE)))
	# Current round: pops up from pip size while sliding into the centre.
	var s := lerpf(FRIEZE_PIP / FRIEZE_RADIUS, 1.0, k)
	var radius := FRIEZE_RADIUS * s
	var resolved: bool = winners.size() >= current and game.phase in [game.Phase.RESOLVE, game.Phase.OVER]
	if resolved:
		var winner: int = winners[current - 1]
		var col := Icons.team_color(winner) if winner >= 0 else FRIEZE_DRAW
		Shapes.arc(_ci, center, radius + 4, 0, TAU, 32, col, 4.0, true)
	else:
		var pulse := fmod(Time.get_ticks_msec() / 1000.0, 1.6) / 1.6
		Shapes.arc(_ci, center, radius + 2 + 6 * pulse, 0, TAU, 32, Color(Icons.GOLD, 0.7 * (1.0 - pulse)), 3.0, true)
	Shapes.circle(_ci, center, radius, Color(0.15, 0.1, 0.12))
	Shapes.arc(_ci, center, radius, 0, TAU, 32, Icons.GOLD, 3.0, true)
	var font_size := int(round(22 * s))
	_ci.draw_string(font, center + Vector2(-20, 8 * s), str(current), HORIZONTAL_ALIGNMENT_CENTER, 40, font_size, Color(1.0, 0.92, 0.7))


func _dashed_ring(p: Vector2, radius: float, color: Color) -> void:
	const DASHES := 8
	for i in DASHES:
		var a := TAU * i / DASHES
		Shapes.arc(_ci, p, radius, a, a + TAU / DASHES * 0.55, 4, color, 2.0, true)


## Offers, reroll, fight button and spell upgrade slide together off the right
## edge when the fight begins and back in when the next shop opens.
func _draw_shop_column() -> void:
	var k := smoothstep(0.0, 1.0, float(game.shop_out))
	if k >= 1.0:
		return
	Shapes.set_transform(_ci, Vector2(SHOP_SLIDE * k, 0), 0.0, Vector2.ONE)
	_draw_shop()
	_draw_fight_button()
	_draw_shift_upgrade()
	Shapes.set_transform(_ci, Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_shop() -> void:
	var selling: bool = game.drag != null and game.shop_drag_index < 0
	for i in Rules.SHOP_SIZE:
		var r := offer_rect(i)
		var id: String = game.player.offers[i] if i < game.player.offers.size() else ""
		if id == "":
			_ci.draw_rect(r, Color(0.1, 0.08, 0.07, 0.6))
			_ci.draw_rect(r, Color(0.35, 0.25, 0.18), false, 2.0)
			continue
		var affordable: bool = game.player.gold >= CreatureDB.get_form(id).price
		# Shown read-only during the fight: no purchase highlight.
		var hovered: bool = r.has_point(get_global_mouse_position()) and not selling and game.phase == game.Phase.PREP
		_panel(r, Color(0.2, 0.14, 0.1) if hovered and affordable else Color(0.14, 0.1, 0.08))
		Icons.token(_ci, id, r.position + Vector2(60, 56), 38, 0, hovered and affordable)
		var price: int = CreatureDB.get_form(id).price
		for j in price:
			Icons.coin(_ci, r.position + Vector2(140 + j * 36, 56), 14)
		if not affordable:
			_ci.draw_rect(r, Color(0, 0, 0, 0.55))
		if game.player.locked[i]:
			_ci.draw_rect(r.grow(-2), Icons.GOLD, false, 3.0)
			Icons.padlock(_ci, r.position + Vector2(264, 22))
	var reroll_ok: bool = game.player.can_reroll()
	_panel(REROLL_RECT, Color(0.23, 0.18, 0.12) if reroll_ok else Color(0.1, 0.09, 0.08))
	Icons.restart(_ci, REROLL_RECT.position + Vector2(30, 21), 12, Icons.GOLD if reroll_ok else Color.DIM_GRAY)
	Icons.coin(_ci, REROLL_RECT.position + Vector2(116, 21), 11)
	_ci.draw_string(font, REROLL_RECT.position + Vector2(136, 28), str(Rules.REROLL_COST), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Icons.GOLD)
	if not reroll_ok:
		_ci.draw_rect(REROLL_RECT, Color(0, 0, 0, 0.35))
	if selling:
		var r := Rect2(Rules.SHOP_RECT.position, Vector2(OFFER_SIZE.x, 124 * Rules.SHOP_SIZE - 12))
		var over := r.has_point(get_global_mouse_position())
		_ci.draw_rect(r, Color(0.9, 0.7, 0.1, 0.35 if over else 0.18))
		_ci.draw_rect(r, Icons.GOLD, false, 3.0)
		Icons.coin(_ci, r.get_center(), 34)
		Icons.arrow_right(_ci, r.get_center() + Vector2(0, -60), 22, Icons.GOLD)


func _draw_fight_button() -> void:
	var ok: bool = game.player.field_count() > 0 and not game.enemy_preparing and game.drag == null
	var hovered := Rules.FIGHT_CENTER.distance_to(get_global_mouse_position()) < Rules.FIGHT_RADIUS
	var base := Color(0.6, 0.15, 0.12) if ok else Color(0.25, 0.2, 0.2)
	if hovered and ok:
		base = base.lightened(0.2)
	Shapes.circle(_ci, Rules.FIGHT_CENTER, Rules.FIGHT_RADIUS, base)
	Shapes.arc(_ci, Rules.FIGHT_CENTER, Rules.FIGHT_RADIUS, 0, TAU, 40, Icons.GOLD if ok else Color(0.4, 0.35, 0.3), 4.0, true)
	Icons.swords(_ci, Rules.FIGHT_CENTER, 30, Color(0.95, 0.92, 0.85) if ok else Color(0.5, 0.45, 0.4))
	if game.enemy_preparing:
		var t := Time.get_ticks_msec() / 1000.0
		Shapes.arc(_ci, Rules.FIGHT_CENTER, Rules.FIGHT_RADIUS + 8, t * 3, t * 3 + PI * 1.4, 32, Icons.GOLD, 3, true)


func _draw_shift_upgrade() -> void:
	var owned: bool = game.player.shift_recharge_upgraded
	var available: bool = game.phase == game.Phase.PREP and game.player.can_upgrade_shift_recharge()
	var fill := Color(0.18, 0.11, 0.24)
	if owned:
		fill = Color(0.12, 0.23, 0.16)
	elif available:
		fill = Color(0.35, 0.19, 0.48)
	_panel(SHIFT_UPGRADE_RECT, fill)
	if available:
		_ci.draw_rect(SHIFT_UPGRADE_RECT, Icons.GOLD, false, 3.0)
	var p := SHIFT_UPGRADE_RECT.position
	Icons.wand(_ci, p + Vector2(28, 27), 16)
	Icons.restart(_ci, p + Vector2(67, 27), 12, Icons.MAGIC.lightened(0.4) if available else Icons.MAGIC)
	if owned:
		var check := p + Vector2(175, 27)
		Shapes.line(_ci, check + Vector2(-10, 0), check + Vector2(-2, 8), Color(0.5, 1, 0.65), 3, true)
		Shapes.line(_ci, check + Vector2(-2, 8), check + Vector2(13, -10), Color(0.5, 1, 0.65), 3, true)
	else:
		for i in Rules.SHIFT_RECHARGE_COST:
			Icons.coin(_ci, p + Vector2(120 + i * 31, 27), 11)
	if not owned and not available:
		_ci.draw_rect(SHIFT_UPGRADE_RECT, Color(0, 0, 0, 0.4))


func _draw_enemy_preparation() -> void:
	if game.phase != game.Phase.PREP:
		return
	for c in game.enemy.fielded():
		if game.enemy_is_moving(c):
			var p: Vector2 = game.enemy_display_position(c) + Rules.BOARD_POS
			Icons.token(_ci, c.form_id, p, Rules.BODY_RADIUS * Rules.CELL, 1)
			Icons.merge_stars(_ci, p + Vector2(0, -32), c.stars)
	if game.enemy_action.is_empty():
		return
	var action: Dictionary = game.enemy_action
	if not action.has("cost"):
		return
	for i in int(action.cost):
		var k := (float(action.t) - i * 0.05) / 0.40
		if k < 0.0 or k >= 1.0:
			continue
		var start := gold_pos(1)
		var end := ENEMY_BLOCK.position + Vector2(42, 48)
		var p := start.lerp(end, k) + Vector2(sin(k * PI) * 45, 0)
		Icons.coin(_ci, p, 9 * (1.0 - 0.35 * k))
		Shapes.arc(_ci, p, 13, 0, TAU, 16, Color(1, 0.8, 0.2, 1.0 - k), 2, true)


func _draw_combat_hud() -> void:
	var b: Battle = game.battle
	if b == null:
		return
	# Timer bar above the board.
	var bar := Rect2(Rules.BOARD_POS + Vector2(0, -34), Vector2(Rules.BOARD_SIZE.x, 10))
	_ci.draw_rect(bar, Color(0, 0, 0, 0.5))
	var left := clampf(1.0 - b.time / Rules.COMBAT_TIMEOUT, 0.0, 1.0)
	var timer_color := Color(0.9, 0.8, 0.5).lerp(Color(1, 0.3, 0.2), 1.0 - left)
	if b.frenzy_level > 0:
		timer_color = Color(1.0, 0.24, 0.16)
		if not b.finished:
			_draw_frenzy(b, bar, timer_color)
	_ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * left, bar.size.y)), timer_color)
	# Large player charges under the board.
	var spell: ShiftSpell = b.spells[0]
	for i in Rules.MAX_CHARGES:
		var prog: float = spell.progress() if i == spell.charges else 0.0
		Icons.charge_orb(_ci, charge_pos(i), 24, spell.charges > i, prog)


func _draw_frenzy(b: Battle, bar: Rect2, color: Color) -> void:
	var step_start := Rules.FRENZY_START + (b.frenzy_level - 1) * Rules.FRENZY_STEP_SECONDS
	var flash := clampf(1.0 - (b.time - step_start) / 0.55, 0.0, 1.0)
	var outline := Rect2(Rules.BOARD_POS, Rules.BOARD_SIZE).grow(3.0)
	_ci.draw_rect(outline, Color(color, 0.45 + flash * 0.55), false, 2.0 + flash * 3.0)
	var bonus := roundi((b.frenzy_multiplier() - 1.0) * 100.0)
	_ci.draw_string(font, bar.position + Vector2(0, -7), "+%d%%" % bonus,
		HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 18, Color(1.0, 0.65, 0.35).lerp(Color.WHITE, flash))


func _draw_result() -> void:
	var c := Rules.BOARD_POS + Rules.BOARD_SIZE * 0.5
	Shapes.circle(_ci, c, 70, Color(0, 0, 0, 0.55))
	match int(game.last_result.get("winner", -1)):
		0:
			Icons.crown(_ci, c, 46)
		1:
			Icons.skull(_ci, c, 50)
		_:
			Icons.draw_mark(_ci, c, 40)


## Precompute the alpha falloff from the edge of a card, including its corners.
static func _make_choice_halo(card_size: Vector2i) -> Texture2D:
	var margin := CHOICE_HALO_MARGIN
	var size := card_size + Vector2i.ONE * (margin * 2)
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		var dy := maxf(margin - (y + 0.5), y + 0.5 - (size.y - margin))
		for x in size.x:
			var dx := maxf(margin - (x + 0.5), x + 0.5 - (size.x - margin))
			var distance := Vector2(maxf(dx, 0.0), maxf(dy, 0.0)).length()
			var alpha := 1.0 - smoothstep(0.0, float(margin), distance)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)


func _draw_choice_halo(card: Rect2, texture: Texture2D, index: int) -> void:
	var hover := choice_hover[index] if choice_phase == game.phase else 0.0
	var opacity := lerpf(0.26, 0.78, smoothstep(0.0, 1.0, hover))
	_ci.draw_texture_rect(texture, card.grow(CHOICE_HALO_MARGIN), false, Color(Color.WHITE, opacity))


## Three opponent hats, from the modest apprentice to the glowing archmage.
func _draw_difficulty_choice() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var mouse := get_global_mouse_position()
	for i in Difficulty.COUNT:
		var r := difficulty_rect(i)
		var unlocked: bool = game.is_difficulty_unlocked(i)
		var revealing := i == unlock_level
		var hovered := unlocked and not unlock_animation_active() and r.has_point(mouse)
		var reveal_age := unlock_time - UNLOCK_CLICK
		var opening := smoothstep(0.0, UNLOCK_OPEN_TIME, reveal_age) if revealing else 0.0
		var pulse := sin(PI * smoothstep(0.0, 0.58, reveal_age)) if revealing else 0.0
		var lift := 6.0 if hovered else pulse * 9.0
		var card := Rect2(r.position - Vector2(0, lift), r.size)
		if unlocked and not revealing:
			_draw_choice_halo(card, difficulty_halo, i)
		_panel(card, Color(0.22, 0.16, 0.1) if hovered else Color(0.14, 0.1, 0.08))
		var hat_scale: float = [46.0, 48.0, 54.0][i] * (1.06 if hovered else 1.0)
		var bob := sin(t * 4.0) * 3.0 if hovered else 0.0
		var centre := card.get_center() + Vector2(0, -9)
		# Soft pool of light under each hat, brighter for stronger opponents.
		var glow: Color = [Color(0.85, 0.65, 0.4), Color(0.4, 0.6, 1.0), Icons.MAGIC][i]
		for k in 5:
			var w := 70.0 - k * 11.0
			Shapes.set_transform(_ci, centre + Vector2(0, hat_scale * 0.62), 0.0, Vector2(1.0, 0.28))
			Shapes.circle(_ci, Vector2.ZERO, w, Color(glow, (0.05 + i * 0.025) * (1.4 if hovered else 1.0)))
		Shapes.set_transform(_ci, Vector2.ZERO, 0.0, Vector2.ONE)
		Icons.difficulty_hat(_ci, i, centre + Vector2(0, bob), hat_scale, t)
		if not unlocked or revealing:
			_ci.draw_rect(card.grow(-2), Color(0.06, 0.04, 0.06, 0.65 * (1.0 - opening)))
			var lock_pos := Vector2(centre.x, card.end.y - 40)
			if revealing:
				_draw_difficulty_unlock(card, lock_pos, opening, reveal_age)
			else:
				Shapes.circle(_ci, lock_pos, 19, Color(0.13, 0.09, 0.08), true)
				Icons.padlock(_ci, lock_pos)


func _draw_difficulty_unlock(card: Rect2, lock_pos: Vector2, opening: float, age: float) -> void:
	var anticipation := smoothstep(0.0, UNLOCK_CLICK, unlock_time)
	var wobble := sin(unlock_time * 46.0) * anticipation * (1.0 - opening) * 3.0
	var fade := 1.0 - smoothstep(0.40, 0.78, age)
	var scale_factor := 1.0 + anticipation * 0.25 + opening * 0.18
	lock_pos += Vector2(wobble, -opening * 8.0)
	Shapes.circle(_ci, lock_pos, 19.0 * scale_factor, Color(0.13, 0.09, 0.08, fade), true)
	Icons.padlock(_ci, lock_pos, opening, scale_factor, fade)
	var flash := smoothstep(0.0, 0.10, age) * (1.0 - smoothstep(0.17, 0.92, age))
	_ci.draw_rect(card.grow(3), Color(Icons.GOLD, flash), false, 2.5)
	if age > 0.0 and age < 0.60:
		var burst := age / 0.60
		Shapes.arc(_ci, lock_pos, 21.0 + burst * 38.0, 0.0, TAU, 32, Color(Icons.GOLD, 0.75 * (1.0 - burst)), 2.0, true)
		for i in 10:
			var direction := Vector2.from_angle(TAU * i / 10.0)
			var distance := 24.0 + burst * (45.0 + (i % 3) * 12.0)
			Icons.star(_ci, lock_pos + direction * distance, 5.0 * (1.0 - burst), Color(Icons.GOLD, 1.0 - burst))


func _draw_pack_choice() -> void:
	var mouse := get_global_mouse_position()
	for i in game.offered_packs.size():
		var pack: Dictionary = CreatureDB.PACKS[game.offered_packs[i]]
		var r := pack_rect(i)
		var hovered := r.has_point(mouse)
		_draw_choice_halo(r, pack_halo, i)
		_panel(r, Color(0.22, 0.16, 0.1) if hovered else Color(0.14, 0.1, 0.08))
		var emblem_pos := Vector2(r.get_center().x, r.position.y + 31)
		Icons.pack_emblem(_ci, pack.emblem, emblem_pos, hovered)
		var n: int = pack.forms.size()
		for j in n:
			Icons.token(_ci, pack.forms[j], pack_token_pos(i, j, n), pack_token_radius(n), 0)
		var coin_row := Vector2(emblem_pos.x, r.end.y - 24)
		var divider := Color(0.45, 0.32, 0.2, 0.65)
		Shapes.line(_ci, coin_row + Vector2(-66, -17), coin_row + Vector2(66, -17), divider, 1.0)
		var starting_gold := Rules.income(1) + int(pack.bonus_gold)
		for j in starting_gold:
			Icons.coin(_ci, coin_row + Vector2((j - (starting_gold - 1) * 0.5) * 21, 0), 8)


func _draw_game_over() -> void:
	_ci.draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0, 0, 0, 0.6))
	var won: bool = game.player.hp > 0
	if won:
		victory.draw(_ci)
		var pop := 1.0 + 0.35 * sin(victory.age * 16.0) * exp(-5.5 * victory.age)
		Icons.crown(_ci, VICTORY_POS, 90 * pop)
	else:
		Icons.skull(_ci, Vector2(640, 280), 95)
	var hovered := RESTART_POS.distance_to(get_global_mouse_position()) < 46
	Shapes.circle(_ci, RESTART_POS, 46, Color(0.25, 0.18, 0.3) if hovered else Color(0.15, 0.1, 0.18))
	Icons.restart(_ci, RESTART_POS, 24, Color(0.9, 0.85, 1.0))


## Hover card: current form, its three possible outcomes with chances, and
## stat bars for the current form.
func _draw_hover_card(info: Dictionary) -> void:
	var form: String = info.form
	var team: int = info.get("team", 0)
	var u: Unit = info.get("unit")
	var owned: OwnedCreature = info.get("owned")
	var stars: int = u.stars if u != null else owned.stars if owned != null else 0
	var size := Vector2(236, 162)
	var pos: Vector2 = info.pos + Vector2(24, 16)
	pos.x = clampf(pos.x, 8, 1280 - size.x - 8)
	pos.y = clampf(pos.y, 8, 720 - size.y - 8)
	_panel(Rect2(pos, size), Color(0.08, 0.06, 0.1, 0.93))
	var main := pos + Vector2(36, 40)
	Icons.token(_ci, form, main, 26, team)
	Icons.merge_stars(_ci, main + Vector2(0, 34), stars)
	var copies: int = u.merge_copies if u != null else owned.merge_copies if owned != null else 1
	Icons.merge_progress(_ci, main + Vector2(0, 46), copies, stars)
	if u != null:
		if u.immune_t > 0.0:
			Icons.immunity_ring(_ci, main, 31, u.immune_t / Rules.TARGET_IMMUNITY, u.anim_t)
	Icons.arrow_right(_ci, pos + Vector2(78, 40), 9, Icons.MAGIC)
	var outs := CreatureDB.outcomes(form)
	for i in outs.size():
		var op := pos + Vector2(116 + i * 46, 32)
		Icons.token(_ci, outs[i].id, op, 18, team)
		Icons.chance_pie(_ci, op + Vector2(0, 29), 7, outs[i].chance)
	# Harvesters: one coin per gold they bring at the start of each round.
	var harvest := Rules.harvest_gold(form, stars)
	for i in harvest:
		Icons.coin(_ci, pos + Vector2(100 + i * 15, 84), 6)
	# Stat bars (normalised against the roster's high values).
	var d := CreatureDB.get_form(form)
	var mult: float = u.stat_mult() if u != null else Rules.star_mult(stars)
	var stats := [
		["hp", d.hp * mult / 250.0], ["dmg", d.dmg * mult / d.interval / 14.0],
		["speed", 1.0 / d.interval / 1.3], ["range", d.range / 5.0],
		["move", d.speed / 3.0], ["armour", d.armour / 50.0],
	]
	for i in stats.size():
		var col := i % 2
		var row := floori(i / 2.0)
		var sp := pos + Vector2(20 + col * 112, 104 + row * 20)
		Icons.stat_icon(_ci, stats[i][0], sp, 7)
		_ci.draw_rect(Rect2(sp + Vector2(12, -4), Vector2(80, 8)), Color(0.2, 0.18, 0.22))
		_ci.draw_rect(Rect2(sp + Vector2(12, -4), Vector2(80 * clampf(stats[i][1], 0.03, 1.0), 8)), Color(0.85, 0.8, 0.6))
