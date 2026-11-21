class_name SwitchFlash
extends Node2D
## Announces a hidden switch without text: an icon pops in at the top right of
## the screen, then fades out.
## - Art style: a circle drawn smooth for the vector art, as blocky pixels for
##   the pixel art.

enum Icon { VECTOR, PIXEL }

const DURATION := 1.1
const CENTER := Vector2(1220, 60)
const RADIUS := 26.0

var _t := DURATION
var _icon := Icon.VECTOR


func show_art_style(style: ArtStyle.Style) -> void:
	_show(Icon.PIXEL if style == ArtStyle.Style.PIXEL else Icon.VECTOR)


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
	Shapes.circle(self, CENTER, r + 10.0, Color(0, 0, 0, 0.55 * alpha))
	match _icon:
		Icon.PIXEL:
			_pixel_ring(r, col)
		Icon.VECTOR:
			_vector_ring(r, col, alpha)


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
	Shapes.arc(self, CENTER, r * 0.82, 0, TAU, 48, col, r * 0.3, true)
	var node := CENTER + Vector2(0, -r * 0.82)
	Shapes.line(self, node - Vector2(r * 0.6, 0), node + Vector2(r * 0.6, 0), col, 2.0, true)
	draw_rect(Rect2(node - Vector2.ONE * 4.0, Vector2.ONE * 8.0), Color(0.2, 0.2, 0.25, alpha))
	draw_rect(Rect2(node - Vector2.ONE * 4.0, Vector2.ONE * 8.0), col, false, 2.0)
	for side in [-1, 1]:
		Shapes.circle(self, node + Vector2(r * 0.6 * side, 0), 3.0, col)
