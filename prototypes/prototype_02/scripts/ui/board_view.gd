class_name BoardView
extends Node2D
## Draws the game board, the preparation tokens and the player's reserve.
## Positioned at Rules.BOARD_POS; combat units are drawn by the Battle node.
##
## The frame and squares never change: a child layer draws them once, behind
## this node. This node redraws only when what it shows changes (see
## _redraw_key), since every redraw rebuilds its draw commands.

const CELL := Rules.CELL

var game # main.gd
var _key := []


func _ready() -> void:
	var background := Node2D.new()
	background.name = "Background"
	background.show_behind_parent = true
	background.draw.connect(_draw_board.bind(background))
	add_child(background)


func _process(_dt: float) -> void:
	var key := _redraw_key()
	if key != _key:
		_key = key
		queue_redraw()


## Everything the tokens, reserve and drag highlights depend on.
func _redraw_key() -> Array:
	var key := [game.phase, game.bench_dock, position, game.drag, game.shop_drag_index, game.shop_drag_active,
		game.hover_info.get("owned"), game.player.gold]
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
	for y in Rules.ROWS:
		for x in Rules.COLS:
			var light := (x + y) % 2 == 0
			var base := Color(0.86, 0.8, 0.66) if light else Color(0.78, 0.71, 0.56)
			var tint := Icons.team_color(0 if y >= 3 else 1)
			ci.draw_rect(Rect2(x * CELL, y * CELL, CELL, CELL), base.lerp(tint, 0.1))
	Shapes.line(ci, Vector2(0, 3 * CELL), Vector2(Rules.BOARD_SIZE.x, 3 * CELL), Color(0.3, 0.2, 0.12, 0.6), 3.0)


## Highlights the legal drop cell while dragging.
func _draw_drop_cell() -> void:
	if game.drag_visual_active():
		var mouse: Vector2 = game.shop_drag_position if game.shop_drag_index >= 0 else get_global_mouse_position()
		var cell: Vector2i = game.board_cell(mouse)
		if game.player.owns_cell(cell):
			draw_rect(Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL)), Color(1, 1, 1, 0.35))


func _draw_reserve() -> void:
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
	# Field capacity pips.
	var fielded: int = game.player.field_count()
	for i in Rules.FIELD_CAP:
		var p := Vector2(Rules.BOARD_SIZE.x + 22, Rules.BOARD_SIZE.y - 14 - i * 22)
		Shapes.circle(self, p, 7, Color(0.2, 0.14, 0.1))
		if i < fielded:
			Shapes.circle(self, p, 5, Icons.team_color(0))


func _draw_drag() -> void:
	var p := get_global_mouse_position() - position
	Shapes.circle(self, p + Vector2(4, 10), 22, Color(0, 0, 0, 0.3))
	Icons.token(self, game.drag.form_id, p, Rules.BODY_RADIUS * CELL * 1.1, 0, true)
	Icons.merge_stars(self, p + Vector2(0, -34), game.drag.stars)
