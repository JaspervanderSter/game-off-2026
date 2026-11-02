class_name TrailDot
extends FxNode

var color: Color = Color.WHITE
var size: float = 3.0
var life: float = 0.28
var max_life: float = 0.28


func setup(p_color: Color, p_size: float) -> void:
	color = p_color
	size = p_size
	life = 0.28
	max_life = 0.28
	queue_redraw()


func _process(_delta: float) -> void:
	life -= udelta()
	queue_redraw()
	if life <= 0.0:
		queue_free()


func _draw() -> void:
	var t := clampf(life / max_life, 0.0, 1.0)
	draw_circle(Vector2.ZERO, size * t, Color(color, 0.7 * t))
