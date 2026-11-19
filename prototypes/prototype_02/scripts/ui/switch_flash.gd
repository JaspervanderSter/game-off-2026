class_name SwitchFlash
extends Node2D
## Announces a hidden switch without text: an icon pops in at the top right of
## the screen, then fades out.
## - Art style: a circle drawn smooth for the vector art, as blocky pixels for
##   the pixel art.
## - Sound set: a speaker with sparkling waves for the current sounds, with a
##   turning-back arrow for the earlier ones.

enum Icon { VECTOR, PIXEL, SOUND_CURRENT, SOUND_LEGACY }

const DURATION := 1.1
const CENTER := Vector2(1220, 60)
const RADIUS := 26.0

var _t := DURATION
var _icon := Icon.VECTOR


func show_art_style(style: ArtStyle.Style) -> void:
	_show(Icon.PIXEL if style == ArtStyle.Style.PIXEL else Icon.VECTOR)


func show_sound_set(value: SoundSet.Set) -> void:
	_show(Icon.SOUND_LEGACY if value == SoundSet.Set.LEGACY else Icon.SOUND_CURRENT)


func _show(icon: Icon) -> void:
	_icon = icon
	_t = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if _t >= DURATION:
		return
	_t = minf(_t + delta, DURATION)
	queue_redraw()


func _draw() -> void:
	if _t >= DURATION:
		return
	var k := _t / DURATION
	var pop := 1.0 + 0.35 * sin(minf(k / 0.25, 1.0) * PI) # quick overshoot
	var alpha := clampf((1.0 - k) / 0.35, 0.0, 1.0)
	var r := RADIUS * pop
	var col := Color(1, 1, 1, alpha)
	draw_circle(CENTER, r + 10.0, Color(0, 0, 0, 0.55 * alpha))
	match _icon:
		Icon.PIXEL:
			_pixel_ring(r, col)
		Icon.VECTOR:
			_vector_ring(r, col, alpha)
		Icon.SOUND_CURRENT, Icon.SOUND_LEGACY:
			_speaker(r, col, _icon == Icon.SOUND_LEGACY)


## The same ring rasterised on a coarse grid.
func _pixel_ring(r: float, col: Color) -> void:
	var cell := r / 4.0
	for y in range(-5, 5):
		for x in range(-5, 5):
			var c := Vector2(x + 0.5, y + 0.5) * cell
			var d := c.length()
			if d > r * 0.62 and d < r * 1.02:
				draw_rect(Rect2(CENTER + c - Vector2.ONE * cell * 0.5, Vector2.ONE * cell * 0.92), col)


## A smooth ring with a path node and its tangent handle, as in a vector editor.
func _vector_ring(r: float, col: Color, alpha: float) -> void:
	draw_arc(CENTER, r * 0.82, 0, TAU, 48, col, r * 0.3, true)
	var node := CENTER + Vector2(0, -r * 0.82)
	draw_line(node - Vector2(r * 0.6, 0), node + Vector2(r * 0.6, 0), col, 2.0, true)
	draw_rect(Rect2(node - Vector2.ONE * 4.0, Vector2.ONE * 8.0), Color(0.2, 0.2, 0.25, alpha))
	draw_rect(Rect2(node - Vector2.ONE * 4.0, Vector2.ONE * 8.0), col, false, 2.0)
	for side in [-1, 1]:
		draw_circle(node + Vector2(r * 0.6 * side, 0), 3.0, col)


func _speaker(r: float, col: Color, legacy: bool) -> void:
	var o := CENTER + Vector2(-r * 0.3, 0)
	draw_rect(Rect2(o + Vector2(-r * 0.5, -r * 0.22), Vector2(r * 0.25, r * 0.44)), col)
	draw_colored_polygon(PackedVector2Array([
		o + Vector2(-r * 0.3, -r * 0.22), o + Vector2(r * 0.05, -r * 0.55),
		o + Vector2(r * 0.05, r * 0.55), o + Vector2(-r * 0.3, r * 0.22)]), col)
	if legacy:
		# An arrow turning back anticlockwise: the earlier sounds.
		var c := o + Vector2(r * 0.65, 0)
		var rr := r * 0.42
		draw_arc(c, rr, -PI * 0.75, PI * 0.85, 24, col, r * 0.13, true)
		var tip := c + Vector2.from_angle(-PI * 0.75) * rr
		var along := Vector2.from_angle(-PI * 0.75).orthogonal() * -1.0 # anticlockwise
		var side := Vector2.from_angle(-PI * 0.75) * r * 0.2
		draw_colored_polygon(PackedVector2Array([tip + along * r * 0.25, tip + side, tip - side]), col)
	else:
		# Sound waves and a sparkle: the current sounds.
		for i in 2:
			draw_arc(o + Vector2(r * 0.05, 0), r * (0.4 + 0.3 * i), -PI * 0.3, PI * 0.3, 12, col, r * 0.12, true)
		_sparkle(o + Vector2(r * 0.95, -r * 0.6), r * 0.22, col)


func _sparkle(p: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(0, -s), p + Vector2(s * 0.25, -s * 0.25), p + Vector2(s, 0), p + Vector2(s * 0.25, s * 0.25),
		p + Vector2(0, s), p + Vector2(-s * 0.25, s * 0.25), p + Vector2(-s, 0), p + Vector2(-s * 0.25, -s * 0.25)]), col)
