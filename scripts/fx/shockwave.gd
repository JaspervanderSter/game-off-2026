class_name Shockwave
extends FxNode

var color: Color = Color.WHITE
var start_radius: float = 10.0
var end_radius: float = 80.0
var duration: float = 0.5
var width: float = 3.0
var elapsed: float = 0.0


func setup(p_color: Color, from_r: float, to_r: float, p_duration: float, p_width: float) -> void:
	color = p_color
	start_radius = from_r
	end_radius = to_r
	duration = maxf(0.05, p_duration)
	width = p_width
	queue_redraw()


func _process(_delta: float) -> void:
	elapsed += udelta()
	queue_redraw()
	if elapsed >= duration:
		queue_free()


func _draw() -> void:
	var t := clampf(elapsed / duration, 0.0, 1.0)
	var r := lerpf(start_radius, end_radius, 1.0 - pow(1.0 - t, 2.2))
	var alpha := 1.0 - t
	draw_circle(Vector2.ZERO, r, Color(color, 0.045 * alpha))
	draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(color, 0.18 * alpha), width * 3.0, true)
	draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(color, 0.95 * alpha), width, true)
