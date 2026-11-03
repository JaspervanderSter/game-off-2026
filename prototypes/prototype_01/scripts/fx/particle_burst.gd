class_name ParticleBurst
extends FxNode

var color: Color = Color.WHITE
var particles: Array = []
var life_left: float = 1.0
var max_size: float = 2.5


func setup(p_color: Color, count: int, speed: float, p_size: float) -> void:
	color = p_color
	max_size = p_size
	life_left = 0.75
	for i in range(count):
		var angle := randf() * TAU
		var spd := randf_range(speed * 0.25, speed)
		var life := randf_range(0.25, 0.6)
		particles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2.from_angle(angle) * spd,
			"life": life,
			"max_life": life,
			"size": randf_range(p_size * 0.55, p_size * 1.25),
		})
	queue_redraw()


func _process(_delta: float) -> void:
	var d := udelta()
	life_left -= d
	for p in particles:
		p["pos"] += p["vel"] * d
		p["vel"] = (p["vel"] as Vector2).lerp(Vector2.ZERO, minf(1.0, d * 4.0))
		p["life"] -= d
	queue_redraw()
	if life_left <= 0.0:
		queue_free()


func _draw() -> void:
	for p in particles:
		var life: float = p["life"]
		if life <= 0.0:
			continue
		var t: float = clampf(life / p["max_life"], 0.0, 1.0)
		var pos: Vector2 = p["pos"]
		var size: float = p["size"] * (0.35 + 0.65 * t)
		draw_circle(pos, size * 1.5, Color(color, 0.14 * t))
		draw_circle(pos, size, Color(color, 0.9 * t))
