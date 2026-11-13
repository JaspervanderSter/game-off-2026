class_name Hud
extends Node2D
## Side panels, buttons, overlays and the hover card.

const ENEMY_BLOCK := Rect2(24, 84, 300, 140)
const PLAYER_BLOCK := Rect2(24, 376, 300, 156)
const TOGGLE_NOSPELL := Vector2(78, 300)
const TOGGLE_FAST := Vector2(158, 300)
const ROUND_POS := Vector2(270, 300)
const TOGGLE_R := 26.0
const RESTART_POS := Vector2(640, 420)
const OFFER_SIZE := Vector2(288, 112)
const REROLL_RECT := Rect2(1000, 458, 224, 42)
const SHIFT_UPGRADE_RECT := Rect2(976, 636, 272, 54)
const PACK_TOP := 222.0
const HEART_STAGGER := 0.26
const HEART_BURST := 0.20
const COIN_FLIGHT := 0.62
const REWARD_TAIL := 0.45
# Round-start harvest: each harvester hops in turn, its coins burst out in a
# fan above it, hover a beat, then fly one by one into the wizard's purse.
const HARVEST_DELAY := 0.35
const HARVEST_STAGGER := 0.26
const HARVEST_HOP := 0.42
const HARVEST_POP := 0.34
const HARVEST_HOVER := 0.18
const HARVEST_COIN_STAGGER := 0.09
const HARVEST_FLIGHT := 0.58

var game # main.gd
var font: Font
var loss_rewards: Array[Dictionary] = []
var reward_time := 0.0
var harvest_time := 0.0
var harvest_sources: Array[Dictionary] = []
var harvest_coins: Array[Dictionary] = []


func _ready() -> void:
	font = ThemeDB.fallback_font


func _process(dt: float) -> void:
	advance_loss_rewards(dt)
	advance_harvest(dt)


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
			harvest_coins.append({"team": team, "from": from, "index": j, "start": start + j * 0.025,
				"hover": from + Vector2.from_angle(-PI / 2 + spread * fan) * radius,
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
			Sfx.play("coin_pop", 0.04)
	for coin in harvest_coins:
		if not coin.arrived and harvest_time >= coin.fly + HARVEST_FLIGHT:
			coin.arrived = true
			# Each landing coin rings a little higher: a rising cash-register run.
			Sfx.play("coin_gain", 0.02, 1.0 + 0.07 * coin.index)
	harvest_sources = harvest_sources.filter(func(s): return harvest_time < s.start + HARVEST_HOP + 0.3)
	harvest_coins = harvest_coins.filter(func(c): return harvest_time < c.fly + HARVEST_FLIGHT + REWARD_TAIL)


## Hop of a harvesting creature (0 at rest, 1 at the top of its jump).
func harvest_hop(uid: int) -> float:
	for src in harvest_sources:
		if src.uid == uid:
			var k: float = (harvest_time - src.start) / HARVEST_HOP
			if k >= 0.0 and k < 1.0:
				return sin(k * PI)
	return 0.0


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
			Sfx.play("heart_break", 0.03)
		if age >= HEART_BURST + COIN_FLIGHT and not reward.arrived:
			reward.arrived = true
			if reward.coin:
				Sfx.play("coin_gain", 0.05)
	queue_redraw()


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
	return Rect2(Vector2(364 + i * 188, PACK_TOP), Vector2(176, 168))


static func difficulty_rect(i: int) -> Rect2:
	return Rect2(Vector2(372 + i * 184, 170), Vector2(168, 260))


## Opponent hat shown in the enemy panel: the hovered card previews its level.
func shown_difficulty() -> int:
	if game.phase == game.Phase.DIFFICULTY:
		for i in Difficulty.COUNT:
			if difficulty_rect(i).has_point(get_global_mouse_position()):
				return i
	return game.enemy.ai_level


static func pack_token_pos(i: int, j: int) -> Vector2:
	return pack_rect(i).position + Vector2(34 + j * 54, 68)


static func charge_pos(i: int) -> Vector2:
	return Vector2(640 + (i - 1) * 64, 584)


# --- Drawing ------------------------------------------------------------------------

func _draw() -> void:
	_draw_wizard(game.enemy, ENEMY_BLOCK)
	_draw_wizard(game.player, PLAYER_BLOCK)
	_draw_toggles()
	match game.phase:
		game.Phase.DIFFICULTY:
			_draw_difficulty_choice()
		game.Phase.PACK:
			_draw_pack_choice()
		game.Phase.PREP:
			_draw_shop()
			_draw_fight_button()
			_draw_shift_upgrade()
		game.Phase.COMBAT:
			_draw_combat_hud()
		game.Phase.RESOLVE:
			_draw_combat_hud()
			_draw_result()
		game.Phase.OVER:
			_draw_game_over()
	if not game.hover_info.is_empty() and game.drag == null and game.phase != game.Phase.RESOLVE:
		_draw_hover_card(game.hover_info)
	_draw_loss_rewards()
	_draw_harvest()
	_draw_enemy_preparation()
	if game.shop_drag_index >= 0 and game.drag_visual_active():
		# Shop previews travel above the cards and side panels, without being
		# purchased or placed on the bench until the mouse is released.
		var p: Vector2 = game.shop_drag_position
		draw_circle(p + Vector2(4, 10), 22, Color(0, 0, 0, 0.3))
		Icons.token(self, game.drag.form_id, p, Rules.BODY_RADIUS * Rules.CELL * 1.1, 0, true)


func _panel(r: Rect2, col := Color(0.12, 0.09, 0.08, 0.85)) -> void:
	draw_rect(r, col)
	draw_rect(r, Color(0.45, 0.32, 0.2), false, 2.0)


func _draw_wizard(state: WizardState, block: Rect2) -> void:
	_panel(block)
	var team := state.team
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
	if impact > 0.0:
		draw_rect(block, Color(1.0, 0.15, 0.2, 0.23 * impact))
	var shake := Vector2(sin(reward_time * 95.0) * 5.0, cos(reward_time * 80.0) * 2.0) * impact
	var hat_pos := block.position + Vector2(42, 48) + shake
	if team == 1:
		# The opponent wears the hat of the chosen difficulty, over its red team glow.
		draw_circle(hat_pos, 31, Color(Icons.team_color(1), 0.2))
		draw_arc(hat_pos, 31, 0, TAU, 32, Color(Icons.team_color(1), 0.55), 2.0, true)
		Icons.difficulty_hat(self, shown_difficulty(), hat_pos + Vector2(0, 5), 22 * (1.0 + impact * 0.12), Time.get_ticks_msec() / 1000.0)
	else:
		Icons.wizard_hat(self, hat_pos, 26 * (1.0 + impact * 0.12), team)
	var shown_hp := displayed_hp(state)
	for i in Rules.WIZARD_HP:
		var p := block.position + Vector2(92 + i * 20.5, 36)
		Icons.wizard_heart(self, p, 9, clampf(shown_hp - i, 0.0, 1.0))
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
		Icons.charge_orb(self, p, 12, filled and not game.no_spells, prog)
	if game.no_spells:
		Icons.wand(self, block.position + Vector2(230, 84), 14, true)
	Icons.coin(self, gold_pos(team), 15 * (1.0 + coin_pulse * 0.45))
	draw_string(font, block.position + Vector2(66, 135 - coin_pulse * 5), str(displayed_gold(state)), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Icons.GOLD.lerp(Color.WHITE, coin_pulse))
	if team == 0 and game.phase != game.Phase.PACK:
		var next_income := Rules.income(game.round_num + 1) + state.harvest_total()
		Icons.coin(self, block.position + Vector2(150, 124), 9)
		draw_string(font, block.position + Vector2(163, 132), "+" + str(next_income), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.8, 0.5, 0.7))


func _draw_loss_rewards() -> void:
	for reward in loss_rewards:
		var age: float = reward_time - reward.start
		var origin := heart_pos(reward.team, reward.heart)
		var dest := gold_pos(reward.team)
		# Anticipation: the next heart swells and flashes before it breaks.
		if age >= -0.16 and age < 0.0:
			var anticipation := (age + 0.16) / 0.16
			Icons.heart_half(self, origin, 9.0 + anticipation * 7.0, reward.half, Color(1, 0.3, 0.4).lerp(Color.WHITE, anticipation))
		if age < 0.0:
			continue
		if age < 0.48:
			var k := age / 0.48
			draw_arc(origin, 7 + 33 * k, 0, TAU, 32, Color(1, 0.35, 0.4, 1.0 - k), 4.0 * (1.0 - k) + 1.0, true)
			for j in 9:
				var direction := Vector2.from_angle(TAU * j / 9.0 + reward.heart * 0.7)
				var p := origin + direction * (12 + 38 * k) + Vector2(0, 30 * k * k)
				Icons.heart_half(self, p, 4.5 * (1.0 - k), reward.half, Color(1, 0.18, 0.3, 1.0 - k))
		if age < HEART_BURST:
			var k := age / HEART_BURST
			Icons.heart_half(self, origin + Vector2(0, -8 * k), 16 * (1.0 - k), reward.half, Color(1, 0.65, 0.7, 1.0 - k))
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
				draw_circle(trail, 6.0 - j * 0.65, Color(1, 0.75, 0.12, (1.0 - j / 7.0) * 0.5))
			var p := origin.bezier_interpolate(control, control, dest, progress)
			draw_set_transform(p, sin(flight * TAU * 2) * 0.2, Vector2(0.35 + absf(cos(flight * TAU * 2)) * 0.65, 1))
			Icons.coin(self, Vector2.ZERO, 13 + sin(flight * PI) * 4)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		var arrived := age - HEART_BURST - COIN_FLIGHT
		if arrived >= 0.0 and arrived < REWARD_TAIL:
			var k := arrived / REWARD_TAIL
			draw_arc(dest, 16 + 30 * k, 0, TAU, 32, Color(1, 0.85, 0.3, 1.0 - k), 4 * (1.0 - k), true)
			for j in 7:
				Icons.star(self, dest + Vector2.from_angle(TAU * j / 7.0) * (18 + k * 28), 5 * (1.0 - k), Color(1, 0.9, 0.35, 1.0 - k))


func _draw_harvest() -> void:
	# Harvester burst: a golden flash and ring with sparkles under the hop.
	for src in harvest_sources:
		var age: float = harvest_time - src.start
		if age < 0.0 or age >= 0.5:
			continue
		var k := age / 0.5
		var p: Vector2 = src.pos
		draw_circle(p, 30.0 * (1.0 - k * 0.4), Color(1.0, 0.85, 0.3, 0.35 * (1.0 - k)))
		draw_arc(p, 18.0 + 36.0 * k, 0, TAU, 32, Color(1.0, 0.85, 0.3, 1.0 - k), 5.0 * (1.0 - k) + 1.0, true)
		for j in 8:
			var q := p + Vector2.from_angle(TAU * j / 8.0 + 0.4) * (22.0 + 30.0 * k)
			Icons.star(self, q, 5.0 * (1.0 - k), Color(1.0, 0.92, 0.45, 1.0 - k))
	for coin in harvest_coins:
		var age: float = harvest_time - coin.start
		if age < 0.0:
			continue
		var from: Vector2 = coin.from
		var hover: Vector2 = coin.hover
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
				Icons.star(self, p + Vector2(9, -9), 5.0 * sin(tw * PI), Color(1, 1, 0.85))
		elif flight < 1.0:
			# Curved, accelerating flight with a fading gold trail.
			var control := hover.lerp(dest, 0.5) + Vector2(0, -90)
			var progress := flight * flight
			for j in 8:
				var t := maxf(0.0, progress - j * 0.03)
				var trail := hover.bezier_interpolate(control, control, dest, t)
				draw_circle(trail, 6.5 - j * 0.7, Color(1, 0.75, 0.12, (1.0 - j / 8.0) * 0.55))
			var p := hover.bezier_interpolate(control, control, dest, progress)
			_spinning_coin(p, 13.0 + sin(flight * PI) * 5.0, spin)
		else:
			# Landing: a ring and a little star burst on the purse.
			var k := clampf((flight - 1.0) * HARVEST_FLIGHT / REWARD_TAIL, 0.0, 1.0)
			draw_arc(dest, 16 + 26 * k, 0, TAU, 32, Color(1, 0.85, 0.3, 1.0 - k), 4 * (1.0 - k) + 0.5, true)
			for j in 5:
				var a: float = TAU * j / 5.0 + coin.index * 0.6
				Icons.star(self, dest + Vector2.from_angle(a) * (16 + k * 24), 4.5 * (1.0 - k), Color(1, 0.9, 0.35, 1.0 - k))


## A coin seen turning on its vertical axis, with a bright rim on its edge.
func _spinning_coin(p: Vector2, r: float, spin: float) -> void:
	draw_circle(p + Vector2(2, 4), r * 0.9, Color(0, 0, 0, 0.25))
	draw_set_transform(p, 0.0, Vector2(0.25 + absf(cos(spin)) * 0.75, 1.0))
	Icons.coin(self, Vector2.ZERO, r)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(p + Vector2(-r * 0.3, -r * 0.35), r * 0.18, Color(1, 1, 0.9, 0.8))


func _draw_toggles() -> void:
	var editable: bool = game.phase != game.Phase.COMBAT and game.phase != game.Phase.RESOLVE
	draw_circle(TOGGLE_NOSPELL, TOGGLE_R, Color(0.2, 0.12, 0.25) if game.no_spells else Color(0.15, 0.1, 0.1))
	draw_arc(TOGGLE_NOSPELL, TOGGLE_R, 0, TAU, 24, Color(0.6, 0.45, 0.8, 1.0 if editable else 0.35), 2.0, true)
	Icons.wand(self, TOGGLE_NOSPELL, 16, game.no_spells)
	draw_circle(TOGGLE_FAST, TOGGLE_R, Color(0.3, 0.25, 0.08) if game.fast else Color(0.15, 0.1, 0.1))
	draw_arc(TOGGLE_FAST, TOGGLE_R, 0, TAU, 24, Color(1.0, 0.85, 0.3), 2.0, true)
	Icons.fast_forward(self, TOGGLE_FAST, 14, Color(1.0, 0.85, 0.3) if game.fast else Color(0.6, 0.55, 0.4))
	# Round counter.
	draw_circle(ROUND_POS, 22, Color(0.15, 0.1, 0.1))
	draw_arc(ROUND_POS, 22, 0, TAU, 24, Color(0.6, 0.5, 0.4), 2.0, true)
	draw_string(font, ROUND_POS + Vector2(-20, 8), str(maxi(1, game.round_num)), HORIZONTAL_ALIGNMENT_CENTER, 40, 22, Color(0.9, 0.85, 0.75))


func _draw_shop() -> void:
	var selling: bool = game.drag != null and game.shop_drag_index < 0
	for i in Rules.SHOP_SIZE:
		var r := offer_rect(i)
		var id: String = game.player.offers[i] if i < game.player.offers.size() else ""
		if id == "":
			draw_rect(r, Color(0.1, 0.08, 0.07, 0.6))
			draw_rect(r, Color(0.35, 0.25, 0.18), false, 2.0)
			continue
		var affordable: bool = game.player.gold >= CreatureDB.get_form(id).price
		var hovered := r.has_point(get_global_mouse_position()) and not selling
		_panel(r, Color(0.2, 0.14, 0.1) if hovered and affordable else Color(0.14, 0.1, 0.08))
		Icons.token(self, id, r.position + Vector2(60, 56), 38, 0, hovered and affordable)
		var price: int = CreatureDB.get_form(id).price
		for j in price:
			Icons.coin(self, r.position + Vector2(140 + j * 36, 56), 14)
		if not affordable:
			draw_rect(r, Color(0, 0, 0, 0.55))
		if game.player.locked[i]:
			draw_rect(r.grow(-2), Icons.GOLD, false, 3.0)
			Icons.padlock(self, r.position + Vector2(264, 22))
	var reroll_ok: bool = game.player.can_reroll()
	_panel(REROLL_RECT, Color(0.23, 0.18, 0.12) if reroll_ok else Color(0.1, 0.09, 0.08))
	Icons.restart(self, REROLL_RECT.position + Vector2(30, 21), 12, Icons.GOLD if reroll_ok else Color.DIM_GRAY)
	Icons.coin(self, REROLL_RECT.position + Vector2(116, 21), 11)
	draw_string(font, REROLL_RECT.position + Vector2(136, 28), str(Rules.REROLL_COST), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Icons.GOLD)
	if not reroll_ok:
		draw_rect(REROLL_RECT, Color(0, 0, 0, 0.35))
	if selling:
		var r := Rect2(Rules.SHOP_RECT.position, Vector2(OFFER_SIZE.x, 124 * Rules.SHOP_SIZE - 12))
		var over := r.has_point(get_global_mouse_position())
		draw_rect(r, Color(0.9, 0.7, 0.1, 0.35 if over else 0.18))
		draw_rect(r, Icons.GOLD, false, 3.0)
		Icons.coin(self, r.get_center(), 34)
		Icons.arrow_right(self, r.get_center() + Vector2(0, -60), 22, Icons.GOLD)


func _draw_fight_button() -> void:
	var ok: bool = game.player.field_count() > 0 and not game.enemy_preparing and game.drag == null
	var hovered := Rules.FIGHT_CENTER.distance_to(get_global_mouse_position()) < Rules.FIGHT_RADIUS
	var base := Color(0.6, 0.15, 0.12) if ok else Color(0.25, 0.2, 0.2)
	if hovered and ok:
		base = base.lightened(0.2)
	draw_circle(Rules.FIGHT_CENTER, Rules.FIGHT_RADIUS, base)
	draw_arc(Rules.FIGHT_CENTER, Rules.FIGHT_RADIUS, 0, TAU, 40, Icons.GOLD if ok else Color(0.4, 0.35, 0.3), 4.0, true)
	Icons.swords(self, Rules.FIGHT_CENTER, 30, Color(0.95, 0.92, 0.85) if ok else Color(0.5, 0.45, 0.4))
	if game.enemy_preparing:
		var t := Time.get_ticks_msec() / 1000.0
		draw_arc(Rules.FIGHT_CENTER, Rules.FIGHT_RADIUS + 8, t * 3, t * 3 + PI * 1.4, 32, Icons.GOLD, 3, true)


func _draw_shift_upgrade() -> void:
	var owned: bool = game.player.shift_recharge_upgraded
	var available: bool = game.player.can_upgrade_shift_recharge()
	_panel(SHIFT_UPGRADE_RECT, Color(0.12, 0.23, 0.16) if owned else Color(0.18, 0.11, 0.24))
	var p := SHIFT_UPGRADE_RECT.position
	Icons.wand(self, p + Vector2(28, 27), 16, false)
	Icons.restart(self, p + Vector2(67, 27), 12, Icons.MAGIC)
	if owned:
		var check := p + Vector2(175, 27)
		draw_line(check + Vector2(-10, 0), check + Vector2(-2, 8), Color(0.5, 1, 0.65), 3, true)
		draw_line(check + Vector2(-2, 8), check + Vector2(13, -10), Color(0.5, 1, 0.65), 3, true)
	else:
		for i in Rules.SHIFT_RECHARGE_COST:
			Icons.coin(self, p + Vector2(120 + i * 31, 27), 11)
	if not owned and not available:
		draw_rect(SHIFT_UPGRADE_RECT, Color(0, 0, 0, 0.4))


func _draw_enemy_preparation() -> void:
	if game.phase != game.Phase.PREP:
		return
	for c in game.enemy.fielded():
		if game.enemy_is_moving(c):
			var p: Vector2 = game.enemy_display_position(c) + Rules.BOARD_POS
			Icons.token(self, c.form_id, p, Rules.BODY_RADIUS * Rules.CELL, 1)
			Icons.merge_stars(self, p + Vector2(0, -32), c.stars)
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
		Icons.coin(self, p, 9 * (1.0 - 0.35 * k))
		draw_arc(p, 13, 0, TAU, 16, Color(1, 0.8, 0.2, 1.0 - k), 2, true)


func _draw_combat_hud() -> void:
	var b: Battle = game.battle
	if b == null:
		return
	# Timer bar above the board.
	var bar := Rect2(Rules.BOARD_POS + Vector2(0, -34), Vector2(Rules.BOARD_SIZE.x, 10))
	draw_rect(bar, Color(0, 0, 0, 0.5))
	var left := clampf(1.0 - b.time / Rules.COMBAT_TIMEOUT, 0.0, 1.0)
	var timer_color := Color(0.9, 0.8, 0.5).lerp(Color(1, 0.3, 0.2), 1.0 - left)
	if b.frenzy_level > 0:
		timer_color = Color(1.0, 0.24, 0.16)
		if not b.finished:
			_draw_frenzy(b, bar, timer_color)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * left, bar.size.y)), timer_color)
	# Large player charges under the board.
	var spell: ShiftSpell = b.spells[0]
	for i in Rules.MAX_CHARGES:
		var prog: float = spell.progress() if i == spell.charges else 0.0
		Icons.charge_orb(self, charge_pos(i), 24, spell.charges > i and b.casting_enabled, prog)
	if not b.casting_enabled:
		Icons.wand(self, charge_pos(1), 30, true)


func _draw_frenzy(b: Battle, bar: Rect2, color: Color) -> void:
	var step_start := Rules.FRENZY_START + (b.frenzy_level - 1) * Rules.FRENZY_STEP_SECONDS
	var flash := clampf(1.0 - (b.time - step_start) / 0.55, 0.0, 1.0)
	var outline := Rect2(Rules.BOARD_POS, Rules.BOARD_SIZE).grow(3.0)
	draw_rect(outline, Color(color, 0.45 + flash * 0.55), false, 2.0 + flash * 3.0)
	var bonus := roundi((b.frenzy_multiplier() - 1.0) * 100.0)
	draw_string(font, bar.position + Vector2(0, -7), "FRENZY +%d%%" % bonus,
		HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 18, Color(1.0, 0.65, 0.35).lerp(Color.WHITE, flash))


func _draw_result() -> void:
	var c := Rules.BOARD_POS + Rules.BOARD_SIZE * 0.5
	draw_circle(c, 70, Color(0, 0, 0, 0.55))
	match int(game.last_result.get("winner", -1)):
		0:
			Icons.crown(self, c, 46)
		1:
			Icons.skull(self, c, 50)
		_:
			Icons.draw_mark(self, c, 40)


## Three opponent hats, from the modest apprentice to the glowing archmage.
func _draw_difficulty_choice() -> void:
	draw_rect(Rect2(Rules.BOARD_POS, Rules.BOARD_SIZE), Color(0, 0, 0, 0.45))
	var t := Time.get_ticks_msec() / 1000.0
	var mouse := get_global_mouse_position()
	for i in Difficulty.COUNT:
		var r := difficulty_rect(i)
		var hovered := r.has_point(mouse)
		var card := Rect2(r.position + Vector2(0, -6 if hovered else 0), r.size)
		_panel(card, Color(0.22, 0.16, 0.1) if hovered else Color(0.14, 0.1, 0.08))
		if hovered:
			draw_rect(card.grow(3), Icons.GOLD, false, 3.0)
		var hat_scale: float = [46.0, 48.0, 54.0][i] * (1.06 if hovered else 1.0)
		var bob := sin(t * 4.0) * 3.0 if hovered else 0.0
		var centre := card.position + Vector2(card.size.x * 0.5, card.size.y * 0.54)
		# Soft pool of light under each hat, brighter for stronger opponents.
		var glow: Color = [Color(0.85, 0.65, 0.4), Color(0.4, 0.6, 1.0), Icons.MAGIC][i]
		for k in 5:
			var w := 70.0 - k * 11.0
			draw_set_transform(centre + Vector2(0, hat_scale * 0.62), 0.0, Vector2(1.0, 0.28))
			draw_circle(Vector2.ZERO, w, Color(glow, (0.05 + i * 0.025) * (1.4 if hovered else 1.0)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		Icons.difficulty_hat(self, i, centre + Vector2(0, bob), hat_scale, t)


func _draw_pack_choice() -> void:
	var dim := Rect2(Rules.BOARD_POS, Rules.BOARD_SIZE)
	draw_rect(dim, Color(0, 0, 0, 0.45))
	for i in CreatureDB.PACKS.size():
		var pack: Dictionary = CreatureDB.PACKS[i]
		var r := pack_rect(i)
		var hovered := r.has_point(get_global_mouse_position())
		_panel(r, Color(0.22, 0.16, 0.1) if hovered else Color(0.14, 0.1, 0.08))
		if hovered:
			draw_rect(r.grow(3), Icons.GOLD, false, 3.0)
		draw_string(font, r.position + Vector2(0, 30), pack.name,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color(0.96, 0.88, 0.75))
		for j in pack.forms.size():
			Icons.token(self, pack.forms[j], pack_token_pos(i, j), 24, 0)
		draw_string(font, r.position + Vector2(0, 115), pack.plan,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, Color(0.84, 0.76, 0.68))
		Icons.coin(self, r.position + Vector2(32, 143), 9)
		var starting_gold := Rules.income(1) + int(pack.bonus_gold)
		for id in pack.forms:
			starting_gold += Rules.harvest_gold(id, 0)
		draw_string(font, r.position + Vector2(47, 148), "%d starting gold" % starting_gold,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Icons.GOLD)


func _draw_game_over() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(0, 0, 0, 0.6))
	var won: bool = game.player.hp > 0
	if won:
		Icons.crown(self, Vector2(640, 280), 90)
	else:
		Icons.skull(self, Vector2(640, 280), 95)
	var hovered := RESTART_POS.distance_to(get_global_mouse_position()) < 46
	draw_circle(RESTART_POS, 46, Color(0.25, 0.18, 0.3) if hovered else Color(0.15, 0.1, 0.18))
	Icons.restart(self, RESTART_POS, 24, Color(0.9, 0.85, 1.0))


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
	Icons.token(self, form, main, 26, team)
	Icons.merge_stars(self, main + Vector2(0, 34), stars)
	var copies: int = u.merge_copies if u != null else owned.merge_copies if owned != null else 1
	Icons.merge_progress(self, main + Vector2(0, 46), copies, stars)
	if u != null:
		if u.immune_t > 0.0:
			Icons.immunity_ring(self, main, 31, u.immune_t / Rules.TARGET_IMMUNITY, u.anim_t)
	Icons.arrow_right(self, pos + Vector2(78, 40), 9, Icons.MAGIC)
	var outs := CreatureDB.outcomes(form)
	for i in outs.size():
		var op := pos + Vector2(116 + i * 46, 32)
		Icons.token(self, outs[i].id, op, 18, team)
		Icons.chance_pie(self, op + Vector2(0, 29), 7, outs[i].chance)
	# Harvesters: one coin per gold they bring at the start of each round.
	var harvest := Rules.harvest_gold(form, stars)
	for i in harvest:
		Icons.coin(self, pos + Vector2(100 + i * 15, 84), 6)
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
		Icons.stat_icon(self, stats[i][0], sp, 7)
		draw_rect(Rect2(sp + Vector2(12, -4), Vector2(80, 8)), Color(0.2, 0.18, 0.22))
		draw_rect(Rect2(sp + Vector2(12, -4), Vector2(80 * clampf(stats[i][1], 0.03, 1.0), 8)), Color(0.85, 0.8, 0.6))
