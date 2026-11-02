class_name FloatingText
extends FxNode

var text: String = ""
var color: Color = Color.WHITE
var font_size: int = 14
var life: float = 0.9
var max_life: float = 0.9
var rise: float = 46.0
var drift: float = 0.0
var font: Font = ThemeDB.fallback_font


func setup(p_text: String, p_color: Color, p_size: int, p_life: float, p_rise: float) -> void:
	text = p_text
	color = p_color
	font_size = p_size
	life = p_life
	max_life = p_life
	rise = p_rise
	drift = randf_range(-14.0, 14.0)
	queue_redraw()


func _process(_delta: float) -> void:
	var d := udelta()
	life -= d
	position.y -= rise * d
	position.x += drift * d
	queue_redraw()
	if life <= 0.0:
		queue_free()


func _draw() -> void:
	var t := clampf(life / maxf(0.01, max_life), 0.0, 1.0)
	var alpha := minf(1.0, t * 2.8)
	var pop := 1.0
	if t > 0.82:
		pop = 1.0 + (t - 0.82) * 2.4
	var size := int(round(float(font_size) * pop))
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(-w * 0.5, 0)
	for ox in [-1.0, 1.0]:
		for oy in [-1.0, 1.0]:
			draw_string(font, pos + Vector2(ox, oy), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.75 * alpha))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, alpha))
