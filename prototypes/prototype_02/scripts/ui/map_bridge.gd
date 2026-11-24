extends Node2D
## A bridge between two islands, drawn entirely from the game's procedural
## shapes (playtest decision, 21 November 2026):
## - forest to town: a rope bridge sagging between stone piers, its handrails
##   swagging from post to post, a lantern on each end post;
## - town to school (`magic`): floating crystal steps rising in a gentle arch
##   from a crystal pedestal on the keep's roof, bobbing along a ribbon of light.
## point_at() gives the walking line both share with the journey's path.
const Retained := preload("res://scripts/ui/retained_drawing.gd")
var _canvas: Node2D
var _layers: Node2D
var _key: Array = []
var _rope_layer: Node2D
var _built_magic := false
var _updates: Array[Callable] = []

var from_point := Vector2.ZERO
var to_point := Vector2.ZERO
var magic := false
var t := 0.0
## Share of a rope bridge laid out from from_point: the title island's bridge
## unrolls towards the forest (world_map.gd). The far pier and its lanterns
## stand once it is whole.
var reach := 1.0
const STEP_COUNT := 9
const STEP_ARCH := -14.0 # the crystal steps rise in an arch rather than sag

func set_span(a: Vector2, b: Vector2, arcane: bool) -> void:
	if from_point == a and to_point == b and magic == arcane:
		return
	from_point = a
	to_point = b
	magic = arcane
	# Geometry is invalidated by the span key in _process().

func _process(dt: float) -> void:
	if not is_visible_in_tree():
		return
	t += dt
	var key: Array = [from_point, to_point, magic, reach]
	if _key != key:
		_key = key
		if is_instance_valid(_rope_layer) and not magic and not _built_magic and from_point.distance_to(to_point) >= 1.0:
			_rope_layer.queue_redraw()
		else:
			_rebuild()
	for update in _updates:
		update.call()

func _rebuild() -> void:
	_built_magic = magic
	_rope_layer = null
	_updates.clear()
	if is_instance_valid(_layers):
		remove_child(_layers)
		_layers.queue_free()
	_layers = Node2D.new()
	add_child(_layers)
	if from_point.distance_to(to_point) < 1.0:
		return
	if magic:
		_build_crystals()
	else:
		_rope_layer = Retained.make(_layers, func(canvas: Node2D):
			_canvas = canvas
			_rope_bridge()
		)
		for end in 2:
			for direction in [-1, 1]:
				var lantern := Node2D.new()
				_layers.add_child(lantern)
				var glow := Retained.make(lantern, func(canvas: Node2D):
					Shapes.circle(canvas, Vector2(0, -36), 9, Color(1.0, 0.8, 0.4, 0.18))
				)
				Retained.make(lantern, func(canvas: Node2D):
					canvas.draw_rect(Rect2(-4, -40, 8, 9), Color("3a2a20"))
					canvas.draw_rect(Rect2(-3, -39, 6, 7), Color(1.0, 0.85, 0.45))
				)
				_updates.append(func():
					var side := (to_point - from_point).normalized().orthogonal() * 10
					lantern.position = (from_point if end == 0 else to_point) + side * direction
					lantern.visible = end == 0 or reach >= 1.0
					glow.modulate.a = 0.55 + 0.25 * sin(t * 3.0 + lantern.position.x)
				)

## The walking line across the bridge, k from 0 (from_point) to 1 (to_point).
func point_at(k: float) -> Vector2:
	var bend := STEP_ARCH if magic else minf(27, from_point.distance_to(to_point) * 0.10)
	return from_point.lerp(to_point, k) + Vector2(0, sin(k * PI) * bend)

func _rope_bridge() -> void:
	var length := from_point.distance_to(to_point)
	var side := (to_point - from_point).normalized().orthogonal() * 10
	# Stone piers carry both ends (only the near one while it unrolls).
	var ends: Array[Vector2] = [from_point]
	if reach >= 1.0:
		ends.append(to_point)
	for p in ends:
		_poly([p + Vector2(-16, 2), p + Vector2(16, 2), p + Vector2(10, 22), p + Vector2(-10, 22)], Color("8a8480"))
		_poly([p + Vector2(4, 2), p + Vector2(16, 2), p + Vector2(10, 22), p + Vector2(2, 22)], Color("6e6a66"))
	if reach > 0.02:
		var deck := PackedVector2Array()
		for i in mini(64, int(reach * 64.0)) + 1:
			deck.append(point_at(i / 64.0))
		Shapes.polyline(_canvas, deck, Color("463938"), 24)
		Shapes.polyline(_canvas, deck, Color("9b8770"), 18)
	var steps := maxi(12, roundi(length / 8))
	var posts: Array[Vector2] = []
	for i in steps + 1:
		if i / float(steps) > reach + 0.0001:
			break
		var p := point_at(i / float(steps))
		Shapes.line(_canvas, p - side * 0.9, p + side * 0.9, Color("d2b78c").darkened(0.08 * (i % 2)), 5)
		if i % 4 == 0:
			posts.append(p)
	for direction in [-1, 1]:
		var rope := PackedVector2Array()
		for j in posts.size():
			var top: Vector2 = posts[j] + side * direction - Vector2(0, 24)
			Shapes.line(_canvas, posts[j] + side * direction + Vector2(0, 5), top, Color("725642"), 3)
			if j > 0:
				# The handrail swags between posts.
				var previous: Vector2 = posts[j - 1] + side * direction - Vector2(0, 24)
				for k in 9:
					rope.append(previous.lerp(top, k / 8.0) + Vector2(0, sin(k / 8.0 * PI) * 4))
		if rope.size() > 1:
			Shapes.polyline(_canvas, rope, Color("71553e"), 2.5)
	for p in ends:
		for direction in [-1, 1]:
			var q: Vector2 = p + side * direction
			Shapes.line(_canvas, q + Vector2(0, 6), q - Vector2(0, 32), Color("7d6048"), 4)

func _build_crystals() -> void:
	var start := from_point
	Retained.make(_layers, func(canvas: Node2D):
		canvas.draw_colored_polygon(PackedVector2Array([start + Vector2(-7, 0), start + Vector2(0, -10), start + Vector2(7, 0), start + Vector2(0, 4)]), Color("b192c4"))
	)
	var glow := Retained.make(_layers, func(canvas: Node2D): Shapes.circle(canvas, start + Vector2(0, -5), 10, Color(0.85, 0.7, 1.0)))
	_updates.append(func(): glow.modulate.a = 0.18 + 0.08 * sin(t * 2.5))
	var points := PackedVector2Array()
	for i in 33:
		points.append(point_at(i / 32.0))
	var ribbon := Retained.make(_layers, func(canvas: Node2D): Shapes.polyline(canvas, points, Color(0.85, 0.7, 1.0), 8))
	_updates.append(func(): ribbon.modulate.a = 0.25 + 0.1 * sin(t * 2.0))
	for i in STEP_COUNT:
		var origin := point_at((i + 0.5) / STEP_COUNT)
		var step := Retained.make(_layers, func(canvas: Node2D):
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-14, 0), Vector2(-6, -5), Vector2(14, -3), Vector2(8, 4)]), Color("b192c4"))
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-14, 0), Vector2(8, 4), Vector2(0, 14)]), Color("7a5a96"))
			Shapes.circle(canvas, Vector2(0, 16), 2, Color(0.85, 0.7, 1.0, 0.5))
		)
		_updates.append(func(): step.position = origin + Vector2(0, sin(t * 1.8 + i * 0.9) * 3))

func _poly(points: Array, col: Color) -> void:
	_canvas.draw_colored_polygon(PackedVector2Array(points), col)
