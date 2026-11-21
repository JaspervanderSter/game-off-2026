class_name BoardView
extends Node2D
## Draws the game board, the preparation tokens and the player's reserve.
## Positioned at Rules.BOARD_POS; combat units are drawn by the Battle node.
##
## A child layer draws the frame and terrain once, behind this node, then
## refreshes when a new duel selects its island's environment (Terrain).
## This node redraws only when what it shows changes (see
## _redraw_key), since every redraw rebuilds its draw commands.
##
## The board's population (Rules.FIELD_CAP creatures per side) is a row of six
## gems set in the frame under the right part of each side's edge: blue on the
## player's lower edge, red on the opponent's upper edge, one lit per creature
## on the board (playtest, 21 November 2026: chosen among pawns, banners and
## portraits to replace six plain round pips).

const CELL := Rules.CELL
## Seconds of a capacity gem's sparkle when it lights, and of its pop when it
## lights or shrinking when it goes out.
const GEM_SPARKLE := 0.5
const GEM_POP := 0.3
const GEM_SPACING := 22.0
const GEM_RIM := Color(0.62, 0.46, 0.2)
const GEM_WARN := Color(0.95, 0.25, 0.2)

var game # main.gd
var environment := Terrain.DEFAULT
var terrain_seed := 7 # same layout every game: the field stays calm and familiar
var _key := []
var _terrain: Texture2D
## Game time (stops with Engine.time_scale, as the redraw check expects).
var _clock := 0.0
## Fielded count last seen per team, and per team and gem the _clock when it
## last lit or went out.
var _fielded := [-1, -1]
var _gem_changed := [[], []]


func _ready() -> void:
	var background := Node2D.new()
	background.name = "Background"
	background.show_behind_parent = true
	background.draw.connect(_draw_board.bind(background))
	add_child(background)


## Shows another environment's terrain.
func set_environment(id: String) -> void:
	environment = id
	_terrain = null
	get_node("Background").queue_redraw()


func _process(dt: float) -> void:
	_clock += dt
	_track_gems()
	var key := _redraw_key()
	if key != _key:
		_key = key
		queue_redraw()


## Notes when each side's fielded count changes, so the gems it lights or puts
## out animate.
func _track_gems() -> void:
	for team in 2:
		var state: WizardState = game.player if team == 0 else game.enemy
		var count := state.field_count()
		var changed: Array = _gem_changed[team]
		if changed.is_empty():
			changed.resize(Rules.FIELD_CAP)
			changed.fill(-100.0)
		if _fielded[team] >= 0:
			for i in range(mini(count, _fielded[team]), mini(maxi(count, _fielded[team]), Rules.FIELD_CAP)):
				changed[i] = _clock
		_fielded[team] = count


func _gems_animating() -> bool:
	for changed in _gem_changed:
		for at in changed:
			if _clock - at < GEM_SPARKLE:
				return true
	return false


## Everything the tokens, reserve, drag highlights and capacity gems depend on.
func _redraw_key() -> Array:
	var key := [game.phase, game.bench_dock, position, game.drag, game.shop_drag_index, game.shop_drag_active,
		game.hover_info.get("owned"), game.player.gold, game.bench_visible(), snappedf(game.field_full_flash, 0.03)]
	if _gems_animating():
		key.append(_clock)
	if game.drag_visual_active():
		key.append(game.shop_drag_position if game.shop_drag_index >= 0 else get_global_mouse_position())
	for state in game.states:
		for c in state.creatures:
			key.append_array([c.uid, c.form_id, c.cell, c.slot, c.stars, c.merge_copies])
			if state == game.enemy:
				key.append(game.enemy_display_position(c))
				key.append(game.enemy_is_moving(c))
	return key


func _draw() -> void:
	_draw_drop_cell()
	_draw_reserve()
	_draw_capacity()
	# During the fight the Battle node draws the fielded creatures.
	if game.phase == game.Phase.COMBAT or game.phase == game.Phase.RESOLVE:
		return
	for state in game.states:
		for c in state.fielded():
			if state == game.enemy and game.enemy_is_moving(c):
				continue # the HUD draws travelling units above both side panels
			if c == game.drag:
				continue
			var hl: bool = game.hover_info.get("owned") == c
			var p: Vector2 = game.enemy_display_position(c) if state == game.enemy else Rules.cell_center(c.cell)
			Icons.token(self, c.form_id, p, Rules.BODY_RADIUS * CELL, state.team, hl)
			Icons.merge_stars(self, p + Vector2(0, -32), c.stars)
			if game.show_merge_progress(c):
				Icons.merge_progress(self, p + Vector2(0, 30), c.merge_copies, c.stars)
			if state == game.player and game.can_drop_merge(c):
				Shapes.arc(self, p, 28, 0, TAU, 32, Icons.GOLD, 3.0, true)
	if game.drag_visual_active() and game.shop_drag_index < 0:
		_draw_drag()


func _draw_board(ci: CanvasItem) -> void:
	var frame := Rect2(Vector2(-10, -10), Rules.BOARD_SIZE + Vector2(20, 20))
	ci.draw_rect(frame, Color(0.35, 0.22, 0.14))
	ci.draw_rect(frame.grow(-4), Color(0.45, 0.3, 0.18))
	if _terrain == null:
		_terrain = ImageTexture.create_from_image(Terrain.board_image(environment, terrain_seed))
	Terrain.draw_board(ci, _terrain, environment)


## Highlights the legal drop cell while dragging. An empty cell stays dark when
## the board is already full (Rules.FIELD_CAP): only the bench or a merge works.
func _draw_drop_cell() -> void:
	if game.drag_visual_active():
		var mouse: Vector2 = game.shop_drag_position if game.shop_drag_index >= 0 else get_global_mouse_position()
		var cell: Vector2i = game.board_cell(mouse)
		if game.player.owns_cell(cell) and not (game.board_full_for(game.drag) and game.player.at_cell(cell) == null):
			draw_rect(Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL)), Color(1, 1, 1, 0.35))


func _draw_reserve() -> void:
	if not game.bench_visible():
		return
	# Each slot is drawn at full size around its centre, then scaled with the
	# dock animation; the bench does not shake with the board.
	var scale_k: float = game.bench_scale()
	var r := Rect2(Vector2.ONE * -CELL * 0.5, Vector2.ONE * CELL)
	for s in Rules.RESERVE_CAP:
		var centre: Vector2 = game.bench_slot_rect(s).get_center() - position
		Shapes.set_transform(self, centre, 0.0, Vector2.ONE * scale_k)
		draw_rect(r.grow(-4), Color(0.25, 0.17, 0.12))
		draw_rect(r.grow(-4), Color(0.5, 0.36, 0.24), false, 2.0)
		var c: OwnedCreature = game.player.at_slot(s)
		if c != null and c != game.drag:
			var hl: bool = game.hover_info.get("owned") == c
			Icons.token(self, c.form_id, Vector2.ZERO, Rules.BODY_RADIUS * CELL, 0, hl)
			Icons.merge_stars(self, Vector2(0, -28), c.stars)
			if game.show_merge_progress(c):
				Icons.merge_progress(self, Vector2(0, 28), c.merge_copies, c.stars)
			if game.can_drop_merge(c):
				draw_rect(r.grow(-4), Icons.GOLD, false, 3.0)
	Shapes.set_transform(self, Vector2.ZERO, 0.0, Vector2.ONE)


## Centre of capacity gem i of a team, in the frame: under the board's right
## part for the player (team 0), over it for the opponent; gem 0 is leftmost.
static func gem_position(team: int, i: int) -> Vector2:
	var x := Rules.BOARD_SIZE.x - 14.0 - (Rules.FIELD_CAP - 1 - i) * GEM_SPACING
	return Vector2(x, Rules.BOARD_SIZE.y + 5.0 if team == 0 else -5.0)


## The capacity gems of both sides, shown with the bench (once the shop exists).
## A creature placed lights the next gem with a pop and a sparkle; one removed
## puts the last gem out. While the player's full board refuses the dragged
## creature, the rims of the player's gems turn red; a refused drop makes them blink.
func _draw_capacity() -> void:
	if not game.bench_visible():
		return
	if _gem_changed[0].is_empty():
		_track_gems()
	var warn := 0.0
	if game.field_full_flash > 0.0:
		warn = absf(sin(game.field_full_flash * 10.5)) # three blinks over the flash
	elif game.drag_visual_active() and game.board_full_for(game.drag):
		warn = 0.55
	for team in 2:
		var lit: int = _fielded[team]
		for i in Rules.FIELD_CAP:
			var p := gem_position(team, i)
			Shapes.circle(self, p, 7.0, Color(0.14, 0.09, 0.05))
			Shapes.circle(self, p, 6.2, GEM_RIM.lerp(GEM_WARN, warn if team == 0 else 0.0))
			Shapes.circle(self, p, 4.6, Color(0.07, 0.05, 0.04))
			var age: float = _clock - _gem_changed[team][i]
			if i < lit:
				Icons.gem(self, p, 4.6 * minf(1.25, 1.0 + 0.5 * maxf(0.0, 1.0 - age / GEM_POP)), Icons.team_color(team))
				if age < GEM_SPARKLE:
					var k := age / GEM_SPARKLE
					Icons.star(self, p + Vector2(3, -3), 6.0 * sin(k * PI), Color(1, 1, 1, 1.0 - k))
			elif age < GEM_POP:
				Icons.gem(self, p, 4.6 * (1.0 - age / GEM_POP), Icons.team_color(team))


func _draw_drag() -> void:
	var p := get_global_mouse_position() - position
	Shapes.circle(self, p + Vector2(4, 10), 22, Color(0, 0, 0, 0.3))
	Icons.token(self, game.drag.form_id, p, Rules.BODY_RADIUS * CELL * 1.1, 0, true)
	Icons.merge_stars(self, p + Vector2(0, -34), game.drag.stars)
