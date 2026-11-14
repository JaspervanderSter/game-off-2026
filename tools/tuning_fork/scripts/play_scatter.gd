class_name PlayScatter
extends Control
## Where the last plays of an effect landed: pitch across, volume (dB) up.
## The box is the random range around the base pitch and volume of the last step.

const MAX_POINTS := 24
const BACKGROUND := Color("16181d")
const BOX := Color(0.37, 0.70, 0.85)
const POINT := Color(0.98, 0.72, 0.30)
const AXIS := Color(1, 1, 1, 0.35)

var _center := Vector2(1.0, -8.0)
var _box := Rect2(Vector2(1.0, -8.0), Vector2.ZERO)
var _points: Array[Vector2] = []


func _init() -> void:
	custom_minimum_size = Vector2(360, 150)


func set_range(pitch: float, pitch_jitter: float, volume_db: float, volume_jitter: float) -> void:
	_center = Vector2(pitch, volume_db)
	_box = Rect2(pitch - pitch_jitter, volume_db - volume_jitter, pitch_jitter * 2.0, volume_jitter * 2.0)
	queue_redraw()


func add_point(pitch: float, volume_db: float) -> void:
	_points.append(Vector2(pitch, volume_db))
	if _points.size() > MAX_POINTS:
		_points.pop_front()
	queue_redraw()


func clear_points() -> void:
	_points.clear()
	queue_redraw()


func _domain() -> Rect2:
	var d := _box
	for p in _points:
		d = d.expand(p)
	var pad_x := maxf(d.size.x * 0.15, 0.05)
	var pad_y := maxf(d.size.y * 0.15, 2.0)
	return d.grow_individual(pad_x, pad_y, pad_x, pad_y)


func _inner() -> Rect2:
	return Rect2(Vector2(48, 10), size - Vector2(60, 34))


func _to_screen(v: Vector2, d: Rect2) -> Vector2:
	var r := _inner()
	return Vector2(
		r.position.x + (v.x - d.position.x) / d.size.x * r.size.x,
		r.end.y - (v.y - d.position.y) / d.size.y * r.size.y)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	var d := _domain()
	var r := _inner()
	var font := get_theme_default_font()
	var font_size := 12
	draw_rect(r, AXIS, false, 1.0)
	var top_left := _to_screen(Vector2(_box.position.x, _box.end.y), d)
	var bottom_right := _to_screen(Vector2(_box.end.x, _box.position.y), d)
	draw_rect(Rect2(top_left, bottom_right - top_left), Color(BOX, 0.18))
	draw_rect(Rect2(top_left, bottom_right - top_left), BOX, false, 1.5)
	var center := _to_screen(_center, d)
	draw_dashed_line(Vector2(center.x, r.position.y), Vector2(center.x, r.end.y), AXIS, 1.0, 4.0)
	draw_dashed_line(Vector2(r.position.x, center.y), Vector2(r.end.x, center.y), AXIS, 1.0, 4.0)
	for i in _points.size():
		var age := float(_points.size() - 1 - i) / MAX_POINTS
		var newest := i == _points.size() - 1
		draw_circle(_to_screen(_points[i], d), 6.0 if newest else 4.0, Color(POINT, 1.0 if newest else 0.75 - age * 0.6))
	# Axis values: pitch below, volume (dB) at the left.
	var color := Color(1, 1, 1, 0.6)
	draw_string(font, Vector2(r.position.x, r.end.y + 16), "%.3f" % d.position.x, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	draw_string(font, Vector2(r.end.x - 40, r.end.y + 16), "%.3f" % d.end.x, HORIZONTAL_ALIGNMENT_RIGHT, 40, font_size, color)
	draw_string(font, Vector2(center.x - 20, r.end.y + 16), "%.3f" % _center.x, HORIZONTAL_ALIGNMENT_CENTER, 40, font_size, BOX)
	draw_string(font, Vector2(4, r.position.y + 10), "%.1f" % d.end.y, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	draw_string(font, Vector2(4, r.end.y), "%.1f" % d.position.y, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	draw_string(font, Vector2(4, center.y + 4), "%.1f" % _center.y, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, BOX)
