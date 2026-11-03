class_name SwapEffect
extends FxNode
## Dramatic transfer animation. Runs on unscaled time so it completes even at
## 0.05x game speed.

var char_a: Character
var char_b: Character
var attr: String = "speed"
var color: Color = Color.WHITE
var duration: float = 0.95
var elapsed: float = 0.0
var value_a_before: Variant = null
var value_b_before: Variant = null
var font: Font = ThemeDB.fallback_font


func setup(a: Character, b: Character, p_attr: String, p_duration: float) -> void:
	char_a = a
	char_b = b
	attr = p_attr
	duration = maxf(0.2, p_duration)
	color = Palette.attr_color(attr)
	if is_instance_valid(a):
		value_a_before = a.get_stat(attr)
	if is_instance_valid(b):
		value_b_before = b.get_stat(attr)
	queue_redraw()


func _process(_delta: float) -> void:
	elapsed += udelta()
	queue_redraw()
	if elapsed >= duration:
		queue_free()


func _draw() -> void:
	if not is_instance_valid(char_a) or not is_instance_valid(char_b):
		return
	var p1: Vector2 = char_a.global_position
	var p2: Vector2 = char_b.global_position
	var fade_in := clampf(elapsed / 0.12, 0.0, 1.0)
	var fade_out := clampf((duration - elapsed) / 0.18, 0.0, 1.0)
	var alpha := minf(fade_in, fade_out)
	if alpha <= 0.0:
		return

	var perp := (p2 - p1).normalized().orthogonal()
	if perp == Vector2.ZERO:
		perp = Vector2.UP
	var mid := (p1 + p2) * 0.5
	var pulse := 0.65 + 0.35 * sin(elapsed * 12.0)

	# Glow rings around both targets.
	for p in [p1, p2]:
		var r: float = 26.0 + 7.0 * pulse
		draw_arc(p, r + 10.0, 0, TAU, 40, Color(color, 0.10 * alpha), 12.0, true)
		draw_arc(p, r + 6.0, 0, TAU, 40, Color(color, 0.18 * alpha), 8.0, true)
		draw_arc(p, r, 0, TAU, 40, Color(color, 0.9 * alpha), 2.5, true)

	# Main beam.
	draw_circle(mid, 26.0 + 10.0 * pulse, Color(color, 0.06 * alpha))
	draw_line(p1, p2, Color(color, 0.10 * alpha), 24.0)
	draw_line(p1, p2, Color(color, 0.24 * alpha), 9.0)
	draw_line(p1, p2, Color(color, 0.9 * alpha), 2.4)
	draw_line(p1, p2, Color(1, 1, 1, 0.65 * alpha), 1.0)

	# Two opposing streams of energy.
	for lane in [-1.0, 1.0]:
		for i in range(16):
			var t: float = fmod(elapsed * 0.85 + float(i) / 16.0, 1.0)
			var wobble: float = sin(t * PI) * 10.0 * lane
			var pos := p1.lerp(p2, t) + perp * wobble
			var s := 1.8 + 2.2 * sin(t * PI)
			draw_circle(pos, s * 2.8, Color(color, 0.16 * alpha))
			draw_circle(pos, s, Color(color, 0.95 * alpha))

	# Direction chevrons for both flows.
	_draw_chevron(p1.lerp(p2, 0.34) + perp * 5.0, (p2 - p1).normalized(), color, alpha)
	_draw_chevron(p1.lerp(p2, 0.66) - perp * 5.0, (p1 - p2).normalized(), color, alpha)

	# Attribute name plate.
	var label := str(GameConfig.ATTR_LABELS.get(attr, attr.to_upper()))
	var label_size := 15
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
	var plate_w := lw + 34.0
	var plate_h := 28.0
	var center := mid - perp * 0.0 + Vector2(0, -58)
	var rect := Rect2(center.x - plate_w * 0.5, center.y - plate_h * 0.5, plate_w, plate_h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, 0.92 * alpha)
	sb.border_color = Color(color, 0.9 * alpha)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	draw_style_box(sb, rect)
	draw_string(font, Vector2(rect.position.x, rect.position.y + 19.0), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, label_size, Color(color, alpha))

	var status := "EXCHANGED" if elapsed >= duration * 0.5 else "TRANSFERRING"
	draw_string(font, Vector2(rect.position.x - 30.0, rect.position.y - 6.0), status, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x + 60.0, 9, Color(color, 0.65 * alpha))

	# Values at each endpoint.
	_draw_value_tag(p1 + Vector2(0, -char_a.radius - 42.0), value_a_before, value_b_before, alpha)
	_draw_value_tag(p2 + Vector2(0, -char_b.radius - 42.0), value_b_before, value_a_before, alpha)


func _draw_chevron(pos: Vector2, dir: Vector2, col: Color, alpha: float) -> void:
	if dir == Vector2.ZERO:
		return
	var side := dir.orthogonal() * 6.0
	draw_line(pos + side, pos + dir * 8.0, Color(col, 0.9 * alpha), 2.0, true)
	draw_line(pos - side, pos + dir * 8.0, Color(col, 0.9 * alpha), 2.0, true)


func _draw_value_tag(pos: Vector2, before: Variant, after: Variant, alpha: float) -> void:
	var before_text := GameConfig.attr_text(attr, before)
	var after_text := GameConfig.attr_text(attr, after)
	var text := "%s → %s" % [before_text, after_text]
	var size := 12
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var rect := Rect2(pos.x - w * 0.5 - 7.0, pos.y - 13.0, w + 14.0, 20.0)
	draw_rect(rect, Color(0.02, 0.03, 0.05, 0.8 * alpha))
	draw_rect(rect, Color(color, 0.55 * alpha), false, 1.0)
	draw_string(font, Vector2(rect.position.x, rect.position.y + 14.0), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, Color(Palette.TEXT, alpha))
