extends Node2D
## A suspended bridge drawn entirely from the game's procedural shapes.
var from_point := Vector2.ZERO
var to_point := Vector2.ZERO
var magic := false

func set_span(a: Vector2, b: Vector2, arcane: bool) -> void:
	if from_point == a and to_point == b and magic == arcane:
		return
	from_point = a
	to_point = b
	magic = arcane
	queue_redraw()

func _curve(t: float, sag: float) -> Vector2:
	return from_point.lerp(to_point, t) + Vector2(0, sin(t * PI) * sag)

func _draw() -> void:
	var length := from_point.distance_to(to_point)
	if length < 1.0:
		return
	var steps := maxi(12, roundi(length / 8))
	var sag := minf(27, length * 0.10)
	var deck := PackedVector2Array()
	var left_rope := PackedVector2Array()
	var right_rope := PackedVector2Array()
	var side := (to_point - from_point).normalized().orthogonal() * 10
	for i in 65:
		var p := _curve(i / 64.0, sag)
		deck.append(p)
		left_rope.append(p + side - Vector2(0, 22))
		right_rope.append(p - side - Vector2(0, 22))
	Shapes.polyline(self, deck, Color("463938"), 24)
	Shapes.polyline(self, deck, Color("8e8194") if magic else Color("9b8770"), 18)
	for i in steps + 1:
		var p := _curve(i / float(steps), sag)
		Shapes.line(self, p - side * 0.9, p + side * 0.9, Color("b5a7bd") if magic else Color("d2b78c"), 5)
		if i % 4 == 0:
			for direction in [-1, 1]:
				var q: Vector2 = p + side * direction
				Shapes.line(self, q + Vector2(0, 5), q - Vector2(0, 25), Color("64516e") if magic else Color("725642"), 3)
	var rail := Color("d3b571") if magic else Color("71553e")
	Shapes.polyline(self, left_rope, rail, 2.5)
	Shapes.polyline(self, right_rope, rail, 2.5)
	for p in [from_point, to_point]:
		for direction in [-1, 1]:
			var q: Vector2 = p + side * direction
			Shapes.line(self, q + Vector2(0, 6), q - Vector2(0, 30), Color("6b5577") if magic else Color("7d6048"), 4)
			Shapes.circle(self, q - Vector2(0, 31), 3.4, Color("ddba70"))
