extends Node2D
## A bridge between two islands, drawn entirely from the game's procedural
## shapes (playtest decision, 21 November 2026):
## - forest to town: a rope bridge sagging between stone piers, its handrails
##   swagging from post to post, a lantern on each end post;
## - town to school (`magic`): floating crystal steps rising in a gentle arch
##   from a crystal pedestal on the keep's roof, bobbing along a ribbon of light.
## point_at() gives the walking line both share with the journey's path.
var from_point := Vector2.ZERO
var to_point := Vector2.ZERO
var magic := false
var t := 0.0
const STEP_COUNT := 9
const STEP_ARCH := -14.0 # the crystal steps rise in an arch rather than sag

func set_span(a: Vector2, b: Vector2, arcane: bool) -> void:
	if from_point == a and to_point == b and magic == arcane:
		return
	from_point = a
	to_point = b
	magic = arcane
	queue_redraw()

func _process(dt: float) -> void:
	if is_visible_in_tree():
		t += dt
		queue_redraw()

## The walking line across the bridge, k from 0 (from_point) to 1 (to_point).
func point_at(k: float) -> Vector2:
	var bend := STEP_ARCH if magic else minf(27, from_point.distance_to(to_point) * 0.10)
	return from_point.lerp(to_point, k) + Vector2(0, sin(k * PI) * bend)

func _draw() -> void:
	if from_point.distance_to(to_point) < 1.0:
		return
	if magic:
		_crystal_steps()
	else:
		_rope_bridge()

func _rope_bridge() -> void:
	var length := from_point.distance_to(to_point)
	var side := (to_point - from_point).normalized().orthogonal() * 10
	# Stone piers carry both ends.
	for p in [from_point, to_point]:
		_poly([p + Vector2(-16, 2), p + Vector2(16, 2), p + Vector2(10, 22), p + Vector2(-10, 22)], Color("8a8480"))
		_poly([p + Vector2(4, 2), p + Vector2(16, 2), p + Vector2(10, 22), p + Vector2(2, 22)], Color("6e6a66"))
	var deck := PackedVector2Array()
	for i in 65:
		deck.append(point_at(i / 64.0))
	Shapes.polyline(self, deck, Color("463938"), 24)
	Shapes.polyline(self, deck, Color("9b8770"), 18)
	var steps := maxi(12, roundi(length / 8))
	var posts: Array[Vector2] = []
	for i in steps + 1:
		var p := point_at(i / float(steps))
		Shapes.line(self, p - side * 0.9, p + side * 0.9, Color("d2b78c").darkened(0.08 * (i % 2)), 5)
		if i % 4 == 0:
			posts.append(p)
	for direction in [-1, 1]:
		var rope := PackedVector2Array()
		for j in posts.size():
			var top: Vector2 = posts[j] + side * direction - Vector2(0, 24)
			Shapes.line(self, posts[j] + side * direction + Vector2(0, 5), top, Color("725642"), 3)
			if j > 0:
				# The handrail swags between posts.
				var previous: Vector2 = posts[j - 1] + side * direction - Vector2(0, 24)
				for k in 9:
					rope.append(previous.lerp(top, k / 8.0) + Vector2(0, sin(k / 8.0 * PI) * 4))
		Shapes.polyline(self, rope, Color("71553e"), 2.5)
	for p in [from_point, to_point]:
		for direction in [-1, 1]:
			var q: Vector2 = p + side * direction
			Shapes.line(self, q + Vector2(0, 6), q - Vector2(0, 32), Color("7d6048"), 4)
			# A lantern on each end post.
			var glow := 0.55 + 0.25 * sin(t * 3.0 + q.x)
			Shapes.circle(self, q - Vector2(0, 36), 9, Color(1.0, 0.8, 0.4, 0.18 * glow))
			draw_rect(Rect2(q - Vector2(4, 40), Vector2(8, 9)), Color("3a2a20"))
			draw_rect(Rect2(q - Vector2(3, 39), Vector2(6, 7)), Color(1.0, 0.85, 0.45))

func _crystal_steps() -> void:
	# A crystal pedestal where the first step waits, on the keep's roof.
	var start := from_point
	_poly([start + Vector2(-7, 0), start + Vector2(0, -10), start + Vector2(7, 0), start + Vector2(0, 4)], Color("b192c4"))
	Shapes.circle(self, start + Vector2(0, -5), 10, Color(0.85, 0.7, 1.0, 0.18 + 0.08 * sin(t * 2.5)))
	var ribbon := PackedVector2Array()
	for i in 33:
		ribbon.append(point_at(i / 32.0))
	Shapes.polyline(self, ribbon, Color(0.85, 0.7, 1.0, 0.25 + 0.1 * sin(t * 2.0)), 8)
	for i in STEP_COUNT:
		var p := point_at((i + 0.5) / STEP_COUNT) + Vector2(0, sin(t * 1.8 + i * 0.9) * 3)
		_poly([p + Vector2(-14, 0), p + Vector2(-6, -5), p + Vector2(14, -3), p + Vector2(8, 4)], Color("b192c4"))
		_poly([p + Vector2(-14, 0), p + Vector2(8, 4), p + Vector2(0, 14)], Color("7a5a96"))
		Shapes.circle(self, p + Vector2(0, 16), 2, Color(0.85, 0.7, 1.0, 0.5))

func _poly(points: Array, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), col)
