class_name BoardView
extends Node2D
## Draws the game board, the preparation tokens and the player's reserve.
## Positioned at Rules.BOARD_POS; combat units are drawn by the Battle node.
##
## A child layer draws the frame and terrain once, behind this node, then
## refreshes when a new duel selects its island's environment (Terrain).
## This node redraws only when what it shows changes (see
## _redraw_key), since every redraw rebuilds its draw commands.

const CELL := Rules.CELL

var game # main.gd
var environment := Terrain.DEFAULT
var terrain_seed := 7 # same layout every game: the field stays calm and familiar
var _key := []
var _terrain: Texture2D


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


func _process(_dt: float) -> void:
	var key := _redraw_key()
	if key != _key:
		_key = key
		queue_redraw()


## Everything the tokens, reserve and drag highlights depend on.
func _redraw_key() -> Array:
	var key := [game.phase, game.bench_dock, position, game.drag, game.shop_drag_index, game.shop_drag_active,
		game.hover_info.get("owned"), game.player.gold, game.bench_visible(), snappedf(game.field_full_flash, 0.03)]
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
	# Field capacity pips, in a row under the board's right edge (clear of the
	# shop column at every height). While a full board refuses the dragged creature they
	# are ringed in red; a refused drop makes the rings blink.
	var fielded: int = game.player.field_count()
	var warn := 0.0
	if game.field_full_flash > 0.0:
		warn = absf(sin(game.field_full_flash * 10.5)) # three blinks over the flash
	elif game.drag_visual_active() and game.board_full_for(game.drag):
		warn = 0.55
	for i in Rules.FIELD_CAP:
		var p := Vector2(Rules.BOARD_SIZE.x - 14 - (Rules.FIELD_CAP - 1 - i) * 22, Rules.BOARD_SIZE.y + 23)
		Shapes.circle(self, p, 7, Color(0.2, 0.14, 0.1))
		if i < fielded:
			Shapes.circle(self, p, 5, Icons.team_color(0))
		if warn > 0.0:
			Shapes.arc(self, p, 9.5, 0, TAU, 20, Color(0.95, 0.25, 0.2, warn), 2.5, true)


func _draw_drag() -> void:
	var p := get_global_mouse_position() - position
	Shapes.circle(self, p + Vector2(4, 10), 22, Color(0, 0, 0, 0.3))
	Icons.token(self, game.drag.form_id, p, Rules.BODY_RADIUS * CELL * 1.1, 0, true)
	Icons.merge_stars(self, p + Vector2(0, -34), game.drag.stars)
