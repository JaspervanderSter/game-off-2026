class_name HomeRoad
extends Node2D
## What leads from the title island into the journey (playtest decision,
## 22 November 2026), drawn in the map's world coordinates by world_map.gd:
## - the island medallion, standing on the title island's bridge near the
##   screen's right edge, gold chevrons gliding along the deck towards it;
## - the footsteps from the cottage door, over the bridge, to the hunter;
## - during the journey's replay, the gold dots running along the beaten
##   roads and the stars of each opponent popping up as they reach it.

const GOLD := Color("ddba70")
const DOT := Color("e4cb94")

const Retained := preload("res://scripts/ui/retained_drawing.gd")
var _dot_key: Array = []
var _walk_key: Array = []
var _dot_nodes: Array[Node2D] = []
var _walk_nodes: Array[Node2D] = []
var _beacon: Node2D
var _mini: Node2D
var _beacon_face: Node2D
var _beacon_rim: Node2D
var _beacon_hot := false

var map # world_map.gd
## The footsteps' dots, and the distance of each along the road; the bridge
## lies between deck_from and deck_to.
var dots := PackedVector2Array()
var dot_at := PackedFloat32Array()
var deck_from := 0.0
var deck_to := 0.0
## How many footsteps show.
var shown := 0
var clock := 0.0
var _stars: Array[Dictionary] = []


func _ready() -> void:
	_beacon = Node2D.new()
	add_child(_beacon)
	_beacon_face = Retained.make(_beacon, _paint_beacon_face)
	_mini = Retained.make(_beacon, func(canvas: Node2D): Icons.floating_island(canvas, Vector2.ZERO, 1.05))
	_beacon_rim = Retained.make(_beacon, func(canvas: Node2D): Shapes.arc(canvas, Vector2.ZERO, 20.0, 0, TAU, 40, GOLD.lightened(0.45) if _beacon_hot else GOLD, 2.5, true))
	_beacon.visible = false

func _paint_beacon_face(canvas: Node2D) -> void:
	Shapes.circle(canvas, Vector2.ZERO, 20.0, Color("9cc0d4").lightened(0.08 if _beacon_hot else 0.0))
	Shapes.ellipse(canvas, Vector2(-9, 9), 6, 2.5, Color(1, 1, 1, 0.6))
	Shapes.ellipse(canvas, Vector2(8, -10), 4, 1.6, Color(1, 1, 1, 0.45))

func _make_dot() -> Node2D:
	var dot := Node2D.new()
	add_child(dot)
	move_child(dot, 0)
	Retained.make(dot, func(canvas: Node2D):
		Shapes.circle(canvas, Vector2.ZERO, 6.0, Color(GOLD, 0.18))
		Shapes.circle(canvas, Vector2.ZERO, 3.5, Color(0.18, 0.13, 0.10, 0.55))
		Shapes.circle(canvas, Vector2.ZERO, 2.3, GOLD)
	)
	Retained.make(dot, func(canvas: Node2D):
		Shapes.circle(canvas, Vector2.ZERO, 3.5, Color(0.18, 0.13, 0.10, 0.55))
		Shapes.circle(canvas, Vector2.ZERO, 2.3, DOT)
	)
	return dot

func _update_dots() -> void:
	var key: Array = [dots, dot_at, deck_from, deck_to]
	if key != _dot_key:
		_dot_key = key.duplicate(true)
		for node in _dot_nodes:
			remove_child(node)
			node.queue_free()
		_dot_nodes.clear()
		for i in dots.size():
			_dot_nodes.append(_make_dot())
	for i in _dot_nodes.size():
		var dot := _dot_nodes[i]
		dot.visible = i < shown
		if dot.visible:
			dot.position = step_position(i)
			var tip: bool = i == shown - 1 and map.menu_blend > 0.0
			dot.get_child(0).visible = tip
			dot.get_child(1).visible = not tip
	if _walk_key != [map.walk]:
		_walk_key = [map.walk.duplicate()]
		for node in _walk_nodes:
			remove_child(node)
			node.queue_free()
		_walk_nodes.clear()
		for point in map.walk:
			var dot := _make_dot()
			dot.position = point
			_walk_nodes.append(dot)
	for i in _walk_nodes.size():
		var dot := _walk_nodes[i]
		dot.visible = i < int(map.walk_pos) and map.walk_stage[i] not in map.discovered
		var tip: bool = i == int(map.walk_pos) - 1
		dot.get_child(0).visible = tip
		dot.get_child(1).visible = not tip

func _process(dt: float) -> void:
	if not is_visible_in_tree():
		return
	clock += dt
	_update_dots()
	for s in _stars:
		s.age += dt
		s.vel *= 1.0 - minf(1.0, 4.0 * dt)
		s.pos += s.vel * dt
	_stars = _stars.filter(func(s): return s.age < 0.5)
	queue_redraw()


## A burst of stars and puffs where an opponent pops up.
func burst(at: Vector2) -> void:
	for i in 8:
		var dir := Vector2.from_angle(TAU * i / 8.0 + randf() * 0.3)
		_stars.append({"pos": at + Vector2(0, -16), "vel": dir * randf_range(90, 150), "age": 0.0, "star": i % 2 == 0})


## Where footstep i stands now: on the island it floats with it, on the
## bridge it follows the deck.
func step_position(i: int) -> Vector2:
	if dot_at[i] > deck_from and dot_at[i] < deck_to:
		return map.home_bridge.point_at((dot_at[i] - deck_from) / (deck_to - deck_from))
	if dot_at[i] <= deck_from:
		return dots[i] + Vector2(0, map.title.lift()) * map.title.scale.y
	return dots[i]


## Where the medallion stands now, in world coordinates.
func medallion_position() -> Vector2:
	var title: TitleScreen = map.title
	return title.position + (TitleScreen.MEDALLION + Vector2(0, title.lift() + sin(clock * 2.0) * 3.0)) * title.scale.x


func _draw() -> void:
	for s in _stars:
		var k: float = 1.0 - s.age / 0.5
		if s.star:
			Icons.star(self, s.pos, 6.0 * k, Color(GOLD, k))
		else:
			Shapes.circle(self, s.pos, 5.0 * k, Color(1, 1, 1, 0.8 * k))
	_draw_medallion()


## How much larger than its minimum the medallion stands on the title.
const GROW := 1.3


## True if `point`, in canvas coordinates, falls on the medallion.
func medallion_hit(point: Vector2) -> bool:
	var screen_scale := maxf(0.01, get_global_transform_with_canvas().get_scale().x)
	var local := get_global_transform_with_canvas().affine_inverse() * point
	var radius := _button_size() * GROW * 1.1
	return local.distance_to(medallion_position()) < maxf(radius, TitleScreen.MEDALLION_RADIUS / screen_scale)


## The medallion's base radius: at least 30 pixels across the screen, also
## when a portrait screen shrinks the title.
func _button_size() -> float:
	return maxf(38.0, 30.0 / maxf(0.01, get_global_transform_with_canvas().get_scale().x))


## The way to the map, made to read as the thing to press (playtest feedback,
## 24 November 2026: it looked like a loading screen): a large medallion that
## breathes, gold rings rippling out of it like a beacon, and gold chevrons
## gliding along the deck towards it. It fades as the camera leaves the title.
func _draw_medallion() -> void:
	var title: TitleScreen = map.title
	var age := title.medallion_age()
	var leave := clampf(1.0 - (1.0 - map.menu_blend) * 5.0, 0.0, 1.0)
	_beacon.visible = age > 0.0 and leave > 0.0
	if not _beacon.visible:
		return
	var at := medallion_position()
	var r := _button_size() * GROW * minf(1.0, age / 0.25) \
		* (1.0 + 0.25 * sin(minf(age / 0.35, 1.0) * PI) * exp(-age * 2.0)) * leave
	var hot: bool = map.on_title() and not title.animating() \
		and medallion_hit(get_global_transform_with_canvas() * get_local_mouse_position())
	var lit := minf(1.0, age / 0.4) * leave
	for i in 4:
		var u := fmod(clock * 0.5 + i * 0.25, 1.0)
		var p: Vector2 = map.home_bridge.point_at(lerpf(0.05, 0.45, u)) + Vector2(0, -34)
		if p.x > at.x - r - 10.0:
			continue
		Shapes.polyline(self, PackedVector2Array([p + Vector2(-9, -12), p, p + Vector2(-9, 12)]), Color(GOLD, sin(u * PI) * lit), 4.5)
	var big := r * (1.0 + 0.05 * sin(clock * 3.2)) * (1.08 if hot else 1.0)
	for j in 2:
		var u := fmod(clock / 1.6 + j * 0.5, 1.0)
		Shapes.ring(self, at, big * (1.0 + 0.75 * u), 5.0 * (1.0 - u) + 1.0, Color(GOLD, 0.85 * (1.0 - u) * lit))
	_beacon.position = at
	_beacon.scale = Vector2.ONE * big / 20.0
	_mini.position = Vector2(1, sin(clock * 2.0) * 1.5 - 1)
	if hot != _beacon_hot:
		_beacon_hot = hot
		_beacon_face.queue_redraw()
		_beacon_rim.queue_redraw()
