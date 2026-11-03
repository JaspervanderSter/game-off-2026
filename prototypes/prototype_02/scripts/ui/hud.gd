class_name Hud
extends Node2D
## Side panels, buttons, overlays and the hover card. Icon-only by design:
## the only text drawn is a few numbers (gold, round).

const ENEMY_BLOCK := Rect2(24, 84, 300, 140)
const PLAYER_BLOCK := Rect2(24, 376, 300, 156)
const TOGGLE_NOSPELL := Vector2(78, 300)
const TOGGLE_FAST := Vector2(158, 300)
const ROUND_POS := Vector2(270, 300)
const TOGGLE_R := 26.0
const RESTART_POS := Vector2(640, 420)
const OFFER_SIZE := Vector2(288, 112)
const REROLL_RECT := Rect2(1000, 458, 224, 42)
const PACK_TOP := 222.0

var game # main.gd
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font


func _process(_dt: float) -> void:
	queue_redraw()


# --- Geometry used for hit tests -------------------------------------------------

static func offer_rect(i: int) -> Rect2:
	return Rect2(Rules.SHOP_RECT.position + Vector2(0, i * 124), OFFER_SIZE)


static func pack_rect(i: int) -> Rect2:
	return Rect2(Vector2(372 + i * 184, PACK_TOP), Vector2(168, 120))


static func pack_token_pos(i: int, j: int) -> Vector2:
	return pack_rect(i).position + Vector2(30 + j * 54, 60)


static func charge_pos(i: int) -> Vector2:
	return Vector2(640 + (i - 1) * 64, 584)


# --- Drawing ------------------------------------------------------------------------

func _draw() -> void:
	_draw_wizard(game.enemy, ENEMY_BLOCK)
	_draw_wizard(game.player, PLAYER_BLOCK)
	_draw_toggles()
	match game.phase:
		game.Phase.PACK:
			_draw_pack_choice()
		game.Phase.PREP:
			_draw_shop()
			_draw_fight_button()
		game.Phase.COMBAT:
			_draw_combat_hud()
		game.Phase.RESOLVE:
			_draw_combat_hud()
			_draw_result()
		game.Phase.OVER:
			_draw_game_over()
	if not game.hover_info.is_empty() and game.drag == null:
		_draw_hover_card(game.hover_info)


func _panel(r: Rect2, col := Color(0.12, 0.09, 0.08, 0.85)) -> void:
	draw_rect(r, col)
	draw_rect(r, Color(0.45, 0.32, 0.2), false, 2.0)


func _draw_wizard(state: WizardState, block: Rect2) -> void:
	_panel(block)
	var team := state.team
	Icons.wizard_hat(self, block.position + Vector2(42, 48), 26, team)
	var flash: bool = game.phase == game.Phase.RESOLVE and game.last_damage_team == team
	for i in Rules.WIZARD_HP:
		var p := block.position + Vector2(92 + i * 20.5, 36)
		var lost_now: bool = flash and i >= state.hp and i < state.hp + game.last_damage
		var col := Color(0.9, 0.2, 0.28) if i < state.hp else Color(0.25, 0.2, 0.2)
		if lost_now and int(Time.get_ticks_msec() / 120) % 2 == 0:
			col = Color.WHITE
		Icons.heart(self, p, 9, col)
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
	if team == 0:
		Icons.coin(self, block.position + Vector2(42, 124), 15)
		draw_string(font, block.position + Vector2(66, 135), str(state.gold), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Icons.GOLD)
		var next_income := Rules.income(game.round_num + 1)
		Icons.coin(self, block.position + Vector2(150, 124), 9)
		draw_string(font, block.position + Vector2(163, 132), "+" + str(next_income), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.8, 0.5, 0.7))


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
	var selling: bool = game.drag != null
	for i in Rules.SHOP_SIZE:
		var r := offer_rect(i)
		var id: String = game.player.offers[i] if i < game.player.offers.size() else ""
		if id == "":
			draw_rect(r, Color(0.1, 0.08, 0.07, 0.6))
			draw_rect(r, Color(0.35, 0.25, 0.18), false, 2.0)
			continue
		var affordable: bool = game.player.can_buy(i)
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
	var ok: bool = game.player.field_count() > 0
	var hovered := Rules.FIGHT_CENTER.distance_to(get_global_mouse_position()) < Rules.FIGHT_RADIUS
	var base := Color(0.6, 0.15, 0.12) if ok else Color(0.25, 0.2, 0.2)
	if hovered and ok:
		base = base.lightened(0.2)
	draw_circle(Rules.FIGHT_CENTER, Rules.FIGHT_RADIUS, base)
	draw_arc(Rules.FIGHT_CENTER, Rules.FIGHT_RADIUS, 0, TAU, 40, Icons.GOLD if ok else Color(0.4, 0.35, 0.3), 4.0, true)
	Icons.swords(self, Rules.FIGHT_CENTER, 30, Color(0.95, 0.92, 0.85) if ok else Color(0.5, 0.45, 0.4))


func _draw_combat_hud() -> void:
	var b: Battle = game.battle
	if b == null:
		return
	# Timer bar above the board.
	var bar := Rect2(Rules.BOARD_POS + Vector2(0, -34), Vector2(Rules.BOARD_SIZE.x, 10))
	draw_rect(bar, Color(0, 0, 0, 0.5))
	var left := clampf(1.0 - b.time / Rules.COMBAT_TIMEOUT, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * left, bar.size.y)), Color(0.9, 0.8, 0.5).lerp(Color(1, 0.3, 0.2), 1.0 - left))
	# Large player charges under the board.
	var spell: ShiftSpell = b.spells[0]
	for i in Rules.MAX_CHARGES:
		var prog: float = spell.progress() if i == spell.charges else 0.0
		Icons.charge_orb(self, charge_pos(i), 24, spell.charges > i and b.casting_enabled, prog)
	if not b.casting_enabled:
		Icons.wand(self, charge_pos(1), 30, true)


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


func _draw_pack_choice() -> void:
	var dim := Rect2(Rules.BOARD_POS, Rules.BOARD_SIZE)
	draw_rect(dim, Color(0, 0, 0, 0.45))
	Icons.star(self, Vector2(640, PACK_TOP - 50), 26)
	for i in game.pack_choices.size():
		var r := pack_rect(i)
		var hovered := r.has_point(get_global_mouse_position())
		_panel(r, Color(0.22, 0.16, 0.1) if hovered else Color(0.14, 0.1, 0.08))
		if hovered:
			draw_rect(r.grow(3), Icons.GOLD, false, 3.0)
		for j in game.pack_choices[i].size():
			Icons.token(self, game.pack_choices[i][j], pack_token_pos(i, j), 24, 0)


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
	var stars: int = u.stars if u != null else owned.stars if owned != null else 1
	var size := Vector2(236, 150)
	var pos: Vector2 = info.pos + Vector2(24, 16)
	pos.x = clampf(pos.x, 8, 1280 - size.x - 8)
	pos.y = clampf(pos.y, 8, 720 - size.y - 8)
	_panel(Rect2(pos, size), Color(0.08, 0.06, 0.1, 0.93))
	var main := pos + Vector2(36, 40)
	Icons.token(self, form, main, 26, team)
	Icons.level_stars(self, main + Vector2(0, 34), stars)
	if u != null:
		if u.level > 1:
			Icons.temporary_levels(self, main + Vector2(29, -22), u.level - 1)
		if u.immune_t > 0.0:
			Icons.immunity_ring(self, main, 31, u.immune_t / Rules.TARGET_IMMUNITY, u.anim_t)
	Icons.arrow_right(self, pos + Vector2(78, 40), 9, Icons.MAGIC)
	var outs := CreatureDB.outcomes(form)
	for i in outs.size():
		var op := pos + Vector2(116 + i * 46, 32)
		Icons.token(self, outs[i].id, op, 18, team)
		Icons.chance_pie(self, op + Vector2(0, 29), 7, outs[i].chance)
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
		var sp := pos + Vector2(20 + col * 112, 92 + row * 20)
		Icons.stat_icon(self, stats[i][0], sp, 7)
		draw_rect(Rect2(sp + Vector2(12, -4), Vector2(80, 8)), Color(0.2, 0.18, 0.22))
		draw_rect(Rect2(sp + Vector2(12, -4), Vector2(80 * clampf(stats[i][1], 0.03, 1.0), 8)), Color(0.85, 0.8, 0.6))
