class_name Icons
extends RefCounted
## Procedural drawing of every creature, status and interface icon.
## Information is carried by shapes and colours rather than text.

const TEAM_COLORS := [Color(0.25, 0.55, 1.0), Color(1.0, 0.3, 0.3)]
const SKIN := Color(0.98, 0.82, 0.66)
const DARK := Color(0.1, 0.08, 0.08)
const GOLD := Color(1.0, 0.82, 0.25)
const MAGIC := Color(0.72, 0.42, 1.0)


static func team_color(team: int) -> Color:
	return TEAM_COLORS[team]


# --- Low-level helpers --------------------------------------------------------

static func _pts(p: Vector2, s: float, arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in arr:
		out.append(p + v * s)
	return out


static func _poly(ci: CanvasItem, p: Vector2, s: float, arr: Array, col: Color) -> void:
	ci.draw_colored_polygon(_pts(p, s, arr), col)


static func _line(ci: CanvasItem, p: Vector2, s: float, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	Shapes.line(ci, p + a * s, p + b * s, col, maxf(1.0, w * s), true)


static func _circ(ci: CanvasItem, p: Vector2, s: float, c: Vector2, r: float, col: Color) -> void:
	Shapes.circle(ci, p + c * s, r * s, col)


static func _ellipse(ci: CanvasItem, p: Vector2, s: float, c: Vector2, rx: float, ry: float, col: Color, rot := 0.0) -> void:
	Shapes.ellipse(ci, p + c * s, rx * s, ry * s, col, rot)


static func _eyes(ci: CanvasItem, p: Vector2, s: float, c: Vector2, gap: float, col := DARK) -> void:
	_circ(ci, p, s, c + Vector2(-gap, 0), 0.06, col)
	_circ(ci, p, s, c + Vector2(gap, 0), 0.06, col)


## Robe + head shared by the heroic fantasy forms.
static func _humanoid(ci: CanvasItem, p: Vector2, s: float, robe: Color) -> void:
	_poly(ci, p, s, [Vector2(-0.55, 0.85), Vector2(0.55, 0.85), Vector2(0.32, -0.05), Vector2(-0.32, -0.05)], robe)
	_circ(ci, p, s, Vector2(0, -0.35), 0.3, SKIN)
	_eyes(ci, p, s, Vector2(0, -0.33), 0.11)


static func _pointed_hat(ci: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	_poly(ci, p, s, [Vector2(-0.42, -0.5), Vector2(0.42, -0.5), Vector2(0.05, -1.15)], col)


static func _helmet(ci: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	Shapes.arc(ci, p + Vector2(0, -0.38) * s, 0.31 * s, PI, TAU, 12, col, 0.16 * s, true)


# --- Creatures --------------------------------------------------------------------

## Draws a creature form centred on p, fitting roughly in a circle of radius s.
static func creature(ci: CanvasItem, id: String, p: Vector2, s: float) -> void:
	match id:
		"peasant":
			_line(ci, p, s, Vector2(0.62, 0.95), Vector2(0.62, -0.8), Color(0.55, 0.35, 0.18), 0.09)
			_humanoid(ci, p, s, Color(0.6, 0.45, 0.28))
			_poly(ci, p, s, [Vector2(-0.52, -0.5), Vector2(0.52, -0.5), Vector2(0.22, -0.72), Vector2(-0.22, -0.72)], Color(0.95, 0.82, 0.35))
			var prong := Color(0.75, 0.75, 0.8)
			_line(ci, p, s, Vector2(0.45, -0.8), Vector2(0.79, -0.8), prong, 0.07)
			for x in [0.45, 0.62, 0.79]:
				_line(ci, p, s, Vector2(x, -0.8), Vector2(x, -1.08), prong, 0.06)
		"guardian":
			_humanoid(ci, p, s, Color(0.55, 0.6, 0.68))
			_helmet(ci, p, s, Color(0.7, 0.72, 0.78))
			var shield := [Vector2(-0.8, -0.15), Vector2(0.1, -0.15), Vector2(0.1, 0.35), Vector2(-0.35, 0.9), Vector2(-0.8, 0.35)]
			_poly(ci, p, s, shield, Color(0.25, 0.4, 0.75))
			Shapes.polyline(ci, _pts(p, s, shield + [shield[0]]), GOLD, maxf(1.0, 0.07 * s), true)
			_line(ci, p, s, Vector2(-0.35, -0.05), Vector2(-0.35, 0.7), GOLD, 0.07)
		"berserker":
			var steel := Color(0.8, 0.82, 0.86)
			var wood := Color(0.5, 0.3, 0.15)
			_line(ci, p, s, Vector2(-0.85, 0.7), Vector2(0.55, -0.9), wood, 0.09)
			_line(ci, p, s, Vector2(0.85, 0.7), Vector2(-0.55, -0.9), wood, 0.09)
			_poly(ci, p, s, [Vector2(0.4, -0.95), Vector2(0.8, -0.95), Vector2(0.65, -0.55)], steel)
			_poly(ci, p, s, [Vector2(-0.4, -0.95), Vector2(-0.8, -0.95), Vector2(-0.65, -0.55)], steel)
			_humanoid(ci, p, s, Color(0.7, 0.18, 0.15))
			for a in [-0.5, 0.0, 0.5]:
				_poly(ci, p, s, [Vector2(a - 0.15, -0.55), Vector2(a + 0.15, -0.55), Vector2(a * 1.4, -0.9)], Color(1.0, 0.5, 0.1))
		"duelist":
			_line(ci, p, s, Vector2(0.25, 0.45), Vector2(1.0, -0.85), Color(0.9, 0.92, 0.95), 0.05)
			_circ(ci, p, s, Vector2(0.3, 0.35), 0.1, GOLD)
			_humanoid(ci, p, s, Color(0.25, 0.3, 0.6))
			_poly(ci, p, s, [Vector2(-0.5, -0.52), Vector2(0.5, -0.52), Vector2(0.3, -0.7), Vector2(-0.3, -0.7)], Color(0.15, 0.15, 0.25))
			_line(ci, p, s, Vector2(0.2, -0.68), Vector2(0.6, -1.05), Color(1.0, 0.3, 0.35), 0.1)
		"assassin":
			_poly(ci, p, s, [Vector2(0.5, 0.2), Vector2(0.62, 0.2), Vector2(0.56, -0.25)], Color(0.85, 0.85, 0.9))
			_poly(ci, p, s, [Vector2(-0.55, 0.85), Vector2(0.55, 0.85), Vector2(0.32, -0.05), Vector2(-0.32, -0.05)], Color(0.25, 0.12, 0.35))
			_poly(ci, p, s, [Vector2(-0.42, -0.05), Vector2(0.42, -0.05), Vector2(0.0, -0.95)], Color(0.32, 0.16, 0.45))
			_circ(ci, p, s, Vector2(0, -0.3), 0.2, Color(0.08, 0.05, 0.1))
			_eyes(ci, p, s, Vector2(0, -0.32), 0.08, Color(1.0, 0.35, 0.35))
		"spearman":
			_line(ci, p, s, Vector2(0.6, 1.0), Vector2(0.6, -1.0), Color(0.55, 0.35, 0.18), 0.08)
			_poly(ci, p, s, [Vector2(0.48, -0.95), Vector2(0.72, -0.95), Vector2(0.6, -1.3)], Color(0.85, 0.87, 0.9))
			_humanoid(ci, p, s, Color(0.45, 0.5, 0.25))
			_helmet(ci, p, s, Color(0.7, 0.6, 0.3))
		"archer":
			_humanoid(ci, p, s, Color(0.2, 0.55, 0.25))
			_poly(ci, p, s, [Vector2(-0.38, -0.3), Vector2(0.38, -0.3), Vector2(0.2, -0.62), Vector2(0.0, -0.95), Vector2(-0.2, -0.62)], Color(0.15, 0.45, 0.2))
			Shapes.arc(ci, p + Vector2(0.3, 0.1) * s, 0.65 * s, -1.2, 1.2, 14, Color(0.6, 0.38, 0.18), maxf(1.0, 0.08 * s), true)
			_line(ci, p, s, Vector2(0.3, 0.1) + Vector2.from_angle(-1.2) * 0.65, Vector2(0.3, 0.1) + Vector2.from_angle(1.2) * 0.65, Color(0.95, 0.95, 0.9), 0.03)
		"crossbowman":
			_humanoid(ci, p, s, Color(0.55, 0.25, 0.2))
			_helmet(ci, p, s, Color(0.6, 0.62, 0.66))
			_line(ci, p, s, Vector2(-0.2, 0.3), Vector2(0.95, 0.3), Color(0.45, 0.28, 0.12), 0.12)
			Shapes.arc(ci, p + Vector2(0.6, 0.55) * s, 0.42 * s, -PI * 0.85, -PI * 0.15, 12, Color(0.35, 0.35, 0.4), maxf(1.0, 0.08 * s), true)
		"pyromancer":
			_humanoid(ci, p, s, Color(0.85, 0.3, 0.1))
			_pointed_hat(ci, p, s, Color(0.7, 0.12, 0.08))
			_flame(ci, p + Vector2(0.65, 0.0) * s, s * 0.45)
		"frost_mage":
			_humanoid(ci, p, s, Color(0.45, 0.7, 0.95))
			_pointed_hat(ci, p, s, Color(0.25, 0.45, 0.85))
			_snowflake(ci, p + Vector2(0.68, 0.05) * s, s * 0.32, Color(0.85, 0.97, 1.0))
		"cleric":
			_humanoid(ci, p, s, Color(0.95, 0.95, 0.92))
			heart(ci, p + Vector2(0, 0.4) * s, 0.26 * s, GOLD)
			Shapes.arc(ci, p + Vector2(0, -0.75) * s, 0.25 * s, 0, TAU, 16, GOLD, maxf(1.0, 0.07 * s), true)
		"bard":
			_humanoid(ci, p, s, Color(0.75, 0.25, 0.6))
			_poly(ci, p, s, [Vector2(-0.4, -0.52), Vector2(0.4, -0.52), Vector2(0.1, -0.78)], Color(0.2, 0.6, 0.55))
			_line(ci, p, s, Vector2(0.1, -0.7), Vector2(-0.35, -1.0), Color(1.0, 0.85, 0.3), 0.07)
			_line(ci, p, s, Vector2(0.5, 0.3), Vector2(1.0, -0.25), Color(0.4, 0.22, 0.1), 0.08)
			_circ(ci, p, s, Vector2(0.42, 0.42), 0.27, Color(0.7, 0.45, 0.2))
			_circ(ci, p, s, Vector2(0.42, 0.42), 0.08, Color(0.25, 0.12, 0.05))
		"turtle":
			for v in [Vector2(-0.6, 0.6), Vector2(0.6, 0.6), Vector2(-0.6, -0.25), Vector2(0.6, -0.25)]:
				_circ(ci, p, s, v, 0.18, Color(0.55, 0.8, 0.45))
			_circ(ci, p, s, Vector2(0, -0.72), 0.25, Color(0.55, 0.8, 0.45))
			_eyes(ci, p, s, Vector2(0, -0.78), 0.1)
			_circ(ci, p, s, Vector2(0, 0.15), 0.68, Color(0.2, 0.5, 0.25))
			for v in [Vector2(0, 0.15), Vector2(-0.35, -0.05), Vector2(0.35, -0.05), Vector2(-0.3, 0.42), Vector2(0.3, 0.42)]:
				_circ(ci, p, s, v, 0.16, Color(0.35, 0.68, 0.35))
		"rhino":
			_ellipse(ci, p, s, Vector2(0, 0.25), 0.7, 0.6, Color(0.55, 0.57, 0.6))
			_circ(ci, p, s, Vector2(0, -0.35), 0.42, Color(0.62, 0.64, 0.68))
			_poly(ci, p, s, [Vector2(-0.45, -0.55), Vector2(-0.25, -0.62), Vector2(-0.45, -0.85)], Color(0.5, 0.5, 0.55))
			_poly(ci, p, s, [Vector2(0.45, -0.55), Vector2(0.25, -0.62), Vector2(0.45, -0.85)], Color(0.5, 0.5, 0.55))
			_poly(ci, p, s, [Vector2(-0.14, -0.5), Vector2(0.14, -0.5), Vector2(0.0, -1.15)], Color(0.95, 0.93, 0.85))
			_eyes(ci, p, s, Vector2(0, -0.3), 0.2)
		"gorilla":
			_circ(ci, p, s, Vector2(-0.72, 0.3), 0.3, Color(0.2, 0.18, 0.2))
			_circ(ci, p, s, Vector2(0.72, 0.3), 0.3, Color(0.2, 0.18, 0.2))
			_circ(ci, p, s, Vector2(0, 0.15), 0.68, Color(0.25, 0.22, 0.25))
			_ellipse(ci, p, s, Vector2(0, -0.3), 0.36, 0.3, Color(0.55, 0.5, 0.5))
			_eyes(ci, p, s, Vector2(0, -0.38), 0.13)
			_line(ci, p, s, Vector2(-0.12, -0.15), Vector2(0.12, -0.15), DARK, 0.05)
		"wolf":
			var fur := Color(0.55, 0.57, 0.62)
			_poly(ci, p, s, [Vector2(-0.6, -0.3), Vector2(-0.25, -0.6), Vector2(-0.55, -1.0)], fur)
			_poly(ci, p, s, [Vector2(0.6, -0.3), Vector2(0.25, -0.6), Vector2(0.55, -1.0)], fur)
			_circ(ci, p, s, Vector2(0, -0.15), 0.62, fur)
			_ellipse(ci, p, s, Vector2(0, 0.25), 0.3, 0.32, Color(0.85, 0.85, 0.88))
			_circ(ci, p, s, Vector2(0, 0.12), 0.1, DARK)
			_eyes(ci, p, s, Vector2(0, -0.3), 0.22, Color(1.0, 0.8, 0.2))
		"leopard":
			var coat := Color(0.95, 0.72, 0.25)
			_circ(ci, p, s, Vector2(-0.45, -0.55), 0.18, coat)
			_circ(ci, p, s, Vector2(0.45, -0.55), 0.18, coat)
			_circ(ci, p, s, Vector2(0, -0.05), 0.65, coat)
			for v in [Vector2(-0.35, 0.2), Vector2(0.38, 0.22), Vector2(-0.2, -0.45), Vector2(0.25, -0.5), Vector2(0.0, 0.45), Vector2(-0.48, -0.15), Vector2(0.5, -0.12)]:
				_circ(ci, p, s, v, 0.07, Color(0.35, 0.22, 0.1))
			_ellipse(ci, p, s, Vector2(0, 0.15), 0.22, 0.18, Color(1.0, 0.95, 0.85))
			_circ(ci, p, s, Vector2(0, 0.08), 0.07, DARK)
			_eyes(ci, p, s, Vector2(0, -0.2), 0.2)
		"rabbit":
			var fur := Color(0.95, 0.95, 0.95)
			_ellipse(ci, p, s, Vector2(-0.22, -0.7), 0.14, 0.42, fur, -0.15)
			_ellipse(ci, p, s, Vector2(0.22, -0.7), 0.14, 0.42, fur, 0.15)
			_ellipse(ci, p, s, Vector2(-0.22, -0.7), 0.06, 0.3, Color(1.0, 0.7, 0.75), -0.15)
			_ellipse(ci, p, s, Vector2(0.22, -0.7), 0.06, 0.3, Color(1.0, 0.7, 0.75), 0.15)
			_circ(ci, p, s, Vector2(0, 0.15), 0.55, fur)
			_circ(ci, p, s, Vector2(0, 0.25), 0.08, Color(1.0, 0.55, 0.65))
			_eyes(ci, p, s, Vector2(0, 0.05), 0.2)
		"snake":
			var body := PackedVector2Array()
			for i in 16:
				var t := i / 15.0
				body.append(p + Vector2(sin(t * TAU * 1.1) * 0.5, 0.85 - t * 1.5) * s)
			Shapes.polyline(ci, body, Color(0.3, 0.7, 0.25), maxf(2.0, 0.28 * s), true)
			_circ(ci, p, s, Vector2(sin(TAU * 1.1) * 0.5, -0.7), 0.25, Color(0.35, 0.78, 0.3))
			_line(ci, p, s, Vector2(sin(TAU * 1.1) * 0.5, -0.9), Vector2(sin(TAU * 1.1) * 0.5, -1.15), Color(0.9, 0.15, 0.2), 0.05)
			_eyes(ci, p, s, Vector2(sin(TAU * 1.1) * 0.5, -0.75), 0.1, Color(1.0, 0.9, 0.2))
		"skunk":
			_circ(ci, p, s, Vector2(0.45, -0.4), 0.45, Color(0.12, 0.12, 0.14))
			_ellipse(ci, p, s, Vector2(0.45, -0.4), 0.12, 0.38, Color(0.95, 0.95, 0.95), 0.6)
			_circ(ci, p, s, Vector2(-0.1, 0.2), 0.55, Color(0.15, 0.15, 0.17))
			_poly(ci, p, s, [Vector2(-0.18, -0.3), Vector2(-0.02, -0.3), Vector2(0.0, 0.6), Vector2(-0.2, 0.6)], Color(0.95, 0.95, 0.95))
			_eyes(ci, p, s, Vector2(-0.1, 0.1), 0.2, Color(0.95, 0.95, 0.95))
		"eagle":
			var wing := Color(0.45, 0.28, 0.15)
			_poly(ci, p, s, [Vector2(-1.05, -0.2), Vector2(-0.2, -0.1), Vector2(-0.2, 0.4), Vector2(-0.8, 0.25)], wing)
			_poly(ci, p, s, [Vector2(1.05, -0.2), Vector2(0.2, -0.1), Vector2(0.2, 0.4), Vector2(0.8, 0.25)], wing)
			_ellipse(ci, p, s, Vector2(0, 0.2), 0.3, 0.55, Color(0.4, 0.25, 0.12))
			_circ(ci, p, s, Vector2(0, -0.45), 0.3, Color(0.97, 0.97, 0.95))
			_poly(ci, p, s, [Vector2(-0.1, -0.35), Vector2(0.1, -0.35), Vector2(0.0, -0.1)], Color(1.0, 0.75, 0.1))
			_eyes(ci, p, s, Vector2(0, -0.52), 0.13)
		"hedgehog":
			var spikes := []
			for i in 24:
				var a := TAU * i / 24.0
				spikes.append(Vector2.from_angle(a) * (0.85 if i % 2 == 0 else 0.55) + Vector2(0, 0.05))
			_poly(ci, p, s, spikes, Color(0.4, 0.27, 0.15))
			_circ(ci, p, s, Vector2(0, 0.2), 0.42, Color(0.9, 0.78, 0.6))
			_circ(ci, p, s, Vector2(0, 0.38), 0.08, DARK)
			_eyes(ci, p, s, Vector2(0, 0.1), 0.17)
		"deer":
			var antler := Color(0.55, 0.38, 0.2)
			_line(ci, p, s, Vector2(-0.2, -0.45), Vector2(-0.55, -1.05), antler, 0.07)
			_line(ci, p, s, Vector2(-0.4, -0.75), Vector2(-0.75, -0.8), antler, 0.06)
			_line(ci, p, s, Vector2(0.2, -0.45), Vector2(0.55, -1.05), antler, 0.07)
			_line(ci, p, s, Vector2(0.4, -0.75), Vector2(0.75, -0.8), antler, 0.06)
			_ellipse(ci, p, s, Vector2(-0.5, -0.35), 0.22, 0.1, Color(0.8, 0.55, 0.32), 0.4)
			_ellipse(ci, p, s, Vector2(0.5, -0.35), 0.22, 0.1, Color(0.8, 0.55, 0.32), -0.4)
			_ellipse(ci, p, s, Vector2(0, 0.0), 0.42, 0.55, Color(0.8, 0.55, 0.32))
			_ellipse(ci, p, s, Vector2(0, 0.38), 0.2, 0.15, Color(0.97, 0.92, 0.85))
			_circ(ci, p, s, Vector2(0, 0.32), 0.07, DARK)
			_eyes(ci, p, s, Vector2(0, -0.12), 0.18)
		"peacock":
			for i in 7:
				var a := lerpf(-PI * 0.95, -PI * 0.05, i / 6.0)
				var c := Vector2.from_angle(a) * 0.72 + Vector2(0, 0.25)
				_circ(ci, p, s, c, 0.26, Color(0.1, 0.55, 0.45))
				_circ(ci, p, s, c, 0.13, Color(0.2, 0.3, 0.85))
				_circ(ci, p, s, c, 0.06, GOLD)
			_ellipse(ci, p, s, Vector2(0, 0.35), 0.24, 0.42, Color(0.15, 0.3, 0.8))
			_circ(ci, p, s, Vector2(0, -0.12), 0.17, Color(0.15, 0.35, 0.9))
			_line(ci, p, s, Vector2(0, -0.28), Vector2(0, -0.45), Color(0.15, 0.35, 0.9), 0.04)
			_circ(ci, p, s, Vector2(0, -0.47), 0.05, GOLD)
			_eyes(ci, p, s, Vector2(0, -0.14), 0.07)
		_:
			_circ(ci, p, s, Vector2.ZERO, 0.6, Color.MAGENTA)


static func _flame(ci: CanvasItem, p: Vector2, s: float) -> void:
	ci.draw_colored_polygon(_pts(p, s, [Vector2(-0.5, 0.3), Vector2(-0.3, -0.4), Vector2(0.0, -1.0), Vector2(0.3, -0.4), Vector2(0.5, 0.3), Vector2(0.0, 0.6)]), Color(1.0, 0.45, 0.1))
	ci.draw_colored_polygon(_pts(p, s, [Vector2(-0.25, 0.3), Vector2(0.0, -0.45), Vector2(0.25, 0.3), Vector2(0.0, 0.45)]), Color(1.0, 0.9, 0.3))


static func _snowflake(ci: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	for i in 3:
		var d := Vector2.from_angle(PI * i / 3.0) * s
		Shapes.line(ci, p - d, p + d, col, maxf(1.0, s * 0.22), true)


## Team base under a creature: coloured disc with a strong ring.
static func team_base(ci: CanvasItem, p: Vector2, r: float, team: int, highlight := false) -> void:
	var col := team_color(team)
	Shapes.circle(ci, p, r, col.darkened(0.65))
	Shapes.arc(ci, p, r, 0, TAU, 32, col, 4.0 if not highlight else 6.0, true)
	if highlight:
		Shapes.arc(ci, p, r + 5.0, 0, TAU, 32, Color(1, 1, 1, 0.8), 2.0, true)


## Full token used outside combat (prep board, reserve, shop, tooltip).
## In the pixel art style, a creature's sprite replaces both base and drawing.
static func token(ci: CanvasItem, id: String, p: Vector2, r: float, team: int, highlight := false) -> void:
	var sprite := ArtStyle.creature_texture(id, team)
	if sprite != null:
		sprite_token(ci, sprite, p, r, highlight)
		return
	team_base(ci, p, r, team, highlight)
	creature(ci, id, p, r * 0.92)


## Pixel art token whose painted team disc has radius r, with the same
## highlight ring as team_base.
static func sprite_token(ci: CanvasItem, sprite: Texture2D, p: Vector2, r: float, highlight := false) -> void:
	ArtStyle.draw_token(ci, sprite, p, r)
	if highlight:
		Shapes.arc(ci, p, r + 5.0, 0, TAU, 32, Color(1, 1, 1, 0.8), 2.0, true)


# --- Combat overlays ----------------------------------------------------------

static func health_bar(ci: CanvasItem, pos: Vector2, w: float, ratio: float, team: int) -> void:
	ci.draw_rect(Rect2(pos, Vector2(w, 6)), Color(0, 0, 0, 0.7))
	ci.draw_rect(Rect2(pos + Vector2(1, 1), Vector2((w - 2) * clampf(ratio, 0, 1), 4)), team_color(team).lightened(0.25))


static func star(ci: CanvasItem, p: Vector2, r: float, col := GOLD) -> void:
	Shapes.star(ci, p, r, col)


static func merge_stars(ci: CanvasItem, center: Vector2, count: int) -> void:
	var shown := clampi(count, 0, Rules.MAX_STARS)
	for i in shown:
		star(ci, center + Vector2((i - (shown - 1) * 0.5) * 11.0, 0), 6.0)


static func merge_progress(ci: CanvasItem, center: Vector2, copies: int, stars: int) -> void:
	if stars >= Rules.MAX_STARS:
		return
	for i in 3:
		var p := center + Vector2((i - 1) * 10, 0)
		Shapes.circle(ci, p, 4, Color(0.08, 0.06, 0.04, 0.95))
		Shapes.arc(ci, p, 3.4, 0, TAU, 16, GOLD, 1.1, true)
		if i < copies:
			Shapes.circle(ci, p, 2.3, GOLD)


## Round-cut gem of radius r in a team's colour, seen from above: a darker
## girdle, a lighter table, one lit facet and a white reflection. Lights the
## board's capacity settings (BoardView).
static func gem(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	if r < 0.5:
		return
	var girdle := PackedVector2Array()
	var table := PackedVector2Array()
	for i in 8:
		var dir := Vector2.from_angle(PI / 8 + i * PI / 4)
		girdle.append(p + dir * r)
		table.append(p + dir * r * 0.55)
	ci.draw_colored_polygon(girdle, col.darkened(0.25))
	ci.draw_colored_polygon(table, col.lightened(0.28))
	ci.draw_colored_polygon(PackedVector2Array([girdle[4], girdle[5], table[5], table[4]]), col.lightened(0.45))
	Shapes.circle(ci, p + Vector2(-r * 0.3, -r * 0.3), r * 0.22, Color(1, 1, 1, 0.85))


static func padlock(ci: CanvasItem, p: Vector2, opening := 0.0, scale_factor := 1.0, opacity := 1.0) -> void:
	var gold := Color(GOLD, opacity)
	var hinge := Vector2(-6, -4)
	var shackle := PackedVector2Array()
	for i in 17:
		var point := Vector2.from_angle(PI + PI * i / 16.0) * 6.0 + Vector2(0, -4)
		point = hinge + (point - hinge).rotated(-0.85 * opening) + Vector2(0, -2.0 * opening)
		shackle.append(p + point * scale_factor)
	Shapes.polyline(ci, shackle, gold, 3.0 * scale_factor, true)
	ci.draw_rect(Rect2(p + Vector2(-8, -4) * scale_factor, Vector2(16, 13) * scale_factor), gold)
	Shapes.circle(ci, p + Vector2(0, 1) * scale_factor, 2.0 * scale_factor, Color(DARK, opacity))


## Hover reticle for the shapeshift spell. Ally: a cyan blessing circle with
## orbiting runes and rising sparkles (cyan, so it never reads as the bard's
## golden inspiration). Enemy: a violet hex reticle whose fangs close in.
## Greyed out when the cast is impossible (no charge or immunity).
static func shift_reticle(ci: CanvasItem, p: Vector2, r: float, t: float, ally: bool, ready: bool) -> void:
	var main_col := Color(0.45, 0.95, 1.0) if ally else Color(0.78, 0.35, 1.0)
	var glow_col := Color(0.7, 1.0, 1.0) if ally else Color(0.35, 0.05, 0.45)
	if not ready:
		main_col = Color(0.6, 0.6, 0.65, 0.55)
		glow_col = Color(0.3, 0.3, 0.35, 0.0)
	var pulse := 0.5 + 0.5 * sin(t * 7.0)
	var ring_r := r * (1.55 + 0.05 * pulse) # outside the bard's inspiration ring
	var fill := glow_col
	fill.a = 0.16 + 0.1 * pulse if ready else 0.0
	Shapes.circle(ci, p, ring_r, fill)
	# Dashed rotating ring: blessings turn clockwise, hexes anticlockwise.
	var spin := t * (1.6 if ally else -2.2)
	for i in 8:
		var a := spin + TAU * i / 8.0
		Shapes.arc(ci, p, ring_r, a, a + TAU / 8.0 * 0.62, 6, main_col, 4.0, true)
	if ally:
		for i in 4:
			var a := -spin * 0.7 + TAU * i / 4.0
			var q := p + Vector2.from_angle(a) * (ring_r + 7.0)
			var d := 4.5 + 1.5 * pulse
			ci.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -d), q + Vector2(d * 0.7, 0), q + Vector2(0, d), q + Vector2(-d * 0.7, 0)]), main_col)
		if ready:
			for i in 3:
				var k := fposmod(t * 0.9 + i / 3.0, 1.0)
				var sx := sin(i * 2.4 + t * 2.0) * r * 0.9
				var sc := Color(0.85, 1.0, 1.0, 1.0 - k)
				star(ci, p + Vector2(sx, r * 0.6 - k * r * 2.4), 3.5 * (1.0 - k) + 1.5, sc)
	else:
		# Four fangs pointing at the target, closing in and out.
		for i in 4:
			var a := spin * 0.5 + TAU * i / 4.0 + PI / 4.0
			var dir := Vector2.from_angle(a)
			var tip := p + dir * (ring_r - 2.0 - 5.0 * pulse)
			var base := p + dir * (ring_r + 11.0 - 3.0 * pulse)
			var side := dir.orthogonal() * 5.0
			ci.draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), main_col)


static func immunity_ring(ci: CanvasItem, p: Vector2, r: float, ratio: float, t: float) -> void:
	var segs := 10
	for i in segs:
		var a := t * 2.0 + TAU * i / segs
		Shapes.arc(ci, p, r, a, a + TAU / segs * 0.5, 4, Color(1, 1, 1, 0.75), 2.5, true)
	Shapes.arc(ci, p, r + 4.0, -PI / 2, -PI / 2 + TAU * ratio, 24, MAGIC, 3.0, true)


static func parry_mark(ci: CanvasItem, p: Vector2, r: float) -> void:
	Shapes.line(ci, p + Vector2(-r, r), p + Vector2(r, -r), Color(0.9, 0.95, 1.0), 2.5, true)
	Shapes.line(ci, p + Vector2(-r, -r), p + Vector2(r, r), Color(0.9, 0.95, 1.0), 2.5, true)


## Fear above a fleeing creature: a wobbling purple exclamation mark with a
## dark outline so it reads on the light board.
static func fear_mark(ci: CanvasItem, p: Vector2, r: float, t: float) -> void:
	var q := p + Vector2(sin(t * 30.0) * 1.5, 0)
	for pass_i in 2:
		var col := Color(0.12, 0.05, 0.15) if pass_i == 0 else Color(0.85, 0.55, 1.0)
		var w := 6.0 if pass_i == 0 else 3.5
		Shapes.line(ci, q + Vector2(0, -r), q + Vector2(0, r * 0.35), col, w, true)
		Shapes.circle(ci, q + Vector2(0, r * 0.9), w * 0.5, col)


## Small status pip: negative effects use a dark red rim, positive a green rim.
static func status(ci: CanvasItem, key: String, p: Vector2, r: float) -> void:
	var good := key in ["inspired", "regen", "pack"]
	Shapes.circle(ci, p, r + 1.5, Color(0.1, 0.5, 0.15) if good else Color(0.55, 0.05, 0.05))
	Shapes.circle(ci, p, r, Color(0.08, 0.08, 0.1))
	match key:
		"poisoned":
			Shapes.circle(ci, p + Vector2(0, 1.5), r * 0.55, Color(0.5, 1.0, 0.3))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.5, 1.0), p + Vector2(r * 0.5, 1.0), p + Vector2(0, -r * 0.8)]), Color(0.5, 1.0, 0.3))
		"chilled":
			_snowflake(ci, p, r * 0.8, Color(0.7, 0.9, 1.0))
		"burning":
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.65, r * 0.25), p + Vector2(r * 0.15, -r * 0.9), p + Vector2(r * 0.65, r * 0.25)]), Color(1.0, 0.45, 0.1))
			Shapes.circle(ci, p + Vector2(0, r * 0.25), r * 0.5, Color(1.0, 0.7, 0.2))
		"exposed":
			ci.draw_rect(Rect2(p - Vector2(r * 0.5, r * 0.6), Vector2(r, r * 1.2)), Color(0.75, 0.75, 0.8))
			Shapes.line(ci, p + Vector2(-r * 0.6, -r * 0.6), p + Vector2(r * 0.6, r * 0.6), Color(1, 0.3, 0.3), 2.0)
		"dazzled":
			Shapes.arc(ci, p, r * 0.6, 0, TAU, 10, Color(0.4, 0.6, 1.0), 2.0)
			Shapes.circle(ci, p, r * 0.25, GOLD)
		"feared":
			Shapes.line(ci, p + Vector2(0, -r * 0.7), p + Vector2(0, r * 0.2), Color(0.85, 0.55, 1.0), 2.5)
			Shapes.circle(ci, p + Vector2(0, r * 0.6), 1.4, Color(0.85, 0.55, 1.0))
		"inspired":
			note(ci, p, r * 0.9, GOLD)
		"regen":
			Shapes.line(ci, p + Vector2(-r * 0.6, 0), p + Vector2(r * 0.6, 0), Color(0.5, 1.0, 0.5), 2.5)
			Shapes.line(ci, p + Vector2(0, -r * 0.6), p + Vector2(0, r * 0.6), Color(0.5, 1.0, 0.5), 2.5)
		"pack":
			Shapes.circle(ci, p + Vector2(-r * 0.3, 0), r * 0.35, Color(0.8, 0.8, 0.85))
			Shapes.circle(ci, p + Vector2(r * 0.3, 0), r * 0.35, Color(0.8, 0.8, 0.85))


static func note(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	Shapes.circle(ci, p + Vector2(-r * 0.3, r * 0.45), r * 0.35, col)
	Shapes.line(ci, p + Vector2(r * 0.02, r * 0.45), p + Vector2(r * 0.02, -r * 0.7), col, 2.0)
	Shapes.line(ci, p + Vector2(r * 0.02, -r * 0.7), p + Vector2(r * 0.6, -r * 0.4), col, 2.0)


## Note with a dark drop shadow so it stays readable on the light board.
static func note_shadowed(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	note(ci, p + Vector2(1.5, 1.5), r, Color(0.15, 0.1, 0.05, col.a * 0.7))
	note(ci, p, r, col)


static func projectile(ci: CanvasItem, kind: String, p: Vector2, dir: Vector2) -> void:
	match kind:
		"arrow":
			Shapes.line(ci, p - dir * 12.0, p, Color(0.85, 0.7, 0.45), 2.5, true)
			Shapes.circle(ci, p, 2.5, Color(0.9, 0.9, 0.95))
		"bolt":
			Shapes.line(ci, p - dir * 10.0, p, Color(0.35, 0.3, 0.3), 4.5, true)
			Shapes.circle(ci, p, 3.5, Color(0.9, 0.9, 0.95))
		"seeker_bolt":
			# Homing bolt: same shaft with a glowing cyan trail and tip.
			Shapes.line(ci, p - dir * 22.0, p - dir * 8.0, Color(0.4, 0.95, 1.0, 0.35), 6.0, true)
			Shapes.line(ci, p - dir * 10.0, p, Color(0.35, 0.3, 0.3), 4.5, true)
			Shapes.circle(ci, p, 5.5, Color(0.4, 0.95, 1.0, 0.45))
			Shapes.circle(ci, p, 3.5, Color(0.85, 1.0, 1.0))
		"fire", "fireball":
			var size := 2.2 if kind == "fireball" else 1.0
			Shapes.circle(ci, p - dir * 6.0 * size, 5.0 * size, Color(1.0, 0.4, 0.1, 0.5))
			Shapes.circle(ci, p, 6.5 * size, Color(1.0, 0.5, 0.1))
			Shapes.circle(ci, p, 3.5 * size, Color(1.0, 0.95, 0.4))
		"frost":
			_snowflake(ci, p, 6.0, Color(0.75, 0.95, 1.0))
		"holy":
			Shapes.circle(ci, p, 5.0, Color(1.0, 0.95, 0.6))
		"note":
			note(ci, p, 7.0, Color(1.0, 0.6, 0.9))
		_:
			Shapes.circle(ci, p, 4.0, Color.WHITE)


# --- Interface icons -------------------------------------------------------------

static func heart(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	Shapes.heart(ci, p, r, col)


## Left (side 0) or right (side 1) half of a heart.
static func heart_half(ci: CanvasItem, p: Vector2, r: float, side: int, col: Color) -> void:
	Shapes.heart(ci, p, r, col, side)


static func wizard_heart(ci: CanvasItem, p: Vector2, r: float, amount: float) -> void:
	heart(ci, p, r, Color(0.25, 0.2, 0.2))
	if amount >= 1.0:
		heart(ci, p, r, Color(0.9, 0.2, 0.28))
	elif amount >= 0.5:
		heart_half(ci, p, r, 0, Color(0.9, 0.2, 0.28))


static func coin(ci: CanvasItem, p: Vector2, r: float) -> void:
	Shapes.circle(ci, p, r, Color(0.75, 0.55, 0.1))
	Shapes.circle(ci, p, r * 0.8, GOLD)
	Shapes.arc(ci, p, r * 0.5, 0, TAU, 12, Color(0.85, 0.6, 0.1), maxf(1.0, r * 0.15), true)


static func wizard_hat(ci: CanvasItem, p: Vector2, r: float, team: int) -> void:
	var col := team_color(team)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r, r * 0.6), p + Vector2(r, r * 0.6), p + Vector2(r * 0.15, -r)]), col.darkened(0.2))
	ci.draw_rect(Rect2(p + Vector2(-r * 1.2, r * 0.5), Vector2(r * 2.4, r * 0.3)), col.darkened(0.45))
	star(ci, p + Vector2(0, r * 0.05), r * 0.3)


## Spell charge crystal: a hexagonal prism pointed at both ends, r being the
## size of the round charge it replaced. Empty, it is dark glass; recharging, magic
## rises from the bottom to `progress` under a bright surface; full, it is purple
## with a light outline and a white reflection. A visible `outline` colour
## replaces the outline (gold for the charge an upgrade adds).
static func charge_crystal(ci: CanvasItem, p: Vector2, r: float, filled: bool, progress := 0.0, outline := Color(0, 0, 0, 0)) -> void:
	var h := r * 1.2
	var w := r * 0.52
	var shape := PackedVector2Array([p + Vector2(0, -h), p + Vector2(w, -h * 0.62), p + Vector2(w, h * 0.62),
		p + Vector2(0, h), p + Vector2(-w, h * 0.62), p + Vector2(-w, -h * 0.62)])
	ci.draw_colored_polygon(shape, Color(0.11, 0.08, 0.19))
	var level := 1.0 if filled else clampf(progress, 0.0, 1.0)
	if level >= 1.0:
		ci.draw_colored_polygon(shape, MAGIC)
	elif level > 0.0:
		var top := p.y + h - 2.0 * h * level
		_fill_clipped(ci, shape, _band(p.x - w - 1, p.x + w + 1, top, p.y + h + 1), MAGIC)
		_fill_clipped(ci, shape, _band(p.x - w - 1, p.x + w + 1, top, top + maxf(1.5, r * 0.09)), MAGIC.lightened(0.6))
	if filled:
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-w * 0.72, -h * 0.5), p + Vector2(-w * 0.3, -h * 0.6),
			p + Vector2(-w * 0.3, h * 0.3), p + Vector2(-w * 0.72, h * 0.4)]), Color(1, 1, 1, 0.35))
	var facet := Color(1, 1, 1, 0.3)
	var fw := maxf(1.0, r * 0.06)
	Shapes.line(ci, p + Vector2(0, -h), p + Vector2(0, h), facet, fw, true)
	Shapes.polyline(ci, PackedVector2Array([p + Vector2(-w, -h * 0.62), p + Vector2(0, -h * 0.38), p + Vector2(w, -h * 0.62)]), facet, fw, true)
	Shapes.polyline(ci, PackedVector2Array([p + Vector2(-w, h * 0.62), p + Vector2(0, h * 0.38), p + Vector2(w, h * 0.62)]), Color(1, 1, 1, 0.18), fw, true)
	var edge := MAGIC.lightened(0.45) if filled else MAGIC.darkened(0.3)
	if outline.a > 0.0:
		edge = outline
	shape.append(shape[0])
	Shapes.polyline(ci, shape, edge, maxf(1.5, r * 0.11), true)


## Fills the part of shape inside clip, skipping slivers too thin to see (and to
## triangulate), such as the bottom tip of a crystal that has just started filling.
static func _fill_clipped(ci: CanvasItem, shape: PackedVector2Array, clip: PackedVector2Array, col: Color) -> void:
	for piece in Geometry2D.intersect_polygons(shape, clip):
		var area := 0.0
		for i in piece.size():
			area += piece[i].cross(piece[(i + 1) % piece.size()])
		if absf(area) > 1.0: # twice the area, in square pixels
			ci.draw_colored_polygon(piece, col)


static func _band(x0: float, x1: float, y0: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


static func swords(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	Shapes.line(ci, p + Vector2(-r, r), p + Vector2(r * 0.8, -r * 0.8), col, r * 0.18, true)
	Shapes.line(ci, p + Vector2(r, r), p + Vector2(-r * 0.8, -r * 0.8), col, r * 0.18, true)
	Shapes.line(ci, p + Vector2(-r * 0.75, r * 0.35), p + Vector2(-r * 0.35, r * 0.75), col, r * 0.2, true)
	Shapes.line(ci, p + Vector2(r * 0.75, r * 0.35), p + Vector2(r * 0.35, r * 0.75), col, r * 0.2, true)


## Fight button emblem for a medallion of radius r: a sword, tip to the upper
## left, crossed with a wand, star to the upper right. dim greys it out.
static func sword_and_wand(ci: CanvasItem, p: Vector2, r: float, dim := false) -> void:
	var steel := Color(0.95, 0.92, 0.85)
	var edge := Color(0.79, 0.76, 0.69)
	var gold := GOLD
	var grip := Color(0.42, 0.25, 0.13)
	var wood := Color(0.66, 0.43, 0.24)
	var glow := Color(1.0, 0.96, 0.69)
	if dim:
		steel = Color(0.5, 0.45, 0.4)
		edge = Color(0.42, 0.38, 0.34)
		gold = Color(0.45, 0.4, 0.33)
		grip = Color(0.3, 0.25, 0.22)
		wood = Color(0.33, 0.28, 0.24)
		glow = Color(0.55, 0.5, 0.45)
	# Sword along u (pommel to tip), wand along w (handle to star); v and x across.
	var u := Vector2(-1, -1).normalized()
	var v := u.orthogonal()
	var w := Vector2(1, -1).normalized()
	var x := w.orthogonal()
	var star := p + w * 0.62 * r
	# A dark outline pass (o > 0) under the coloured pass keeps both readable on
	# either half of the medallion.
	var draw_tools := func(o: float, outline := Color()) -> void:
		var pick := func(col: Color) -> Color: return outline if o > 0.0 else col
		_blade_quad(ci, p, u, v, -0.25 * r - o, 0.68 * r, 0.075 * r + o, pick.call(steel))
		ci.draw_colored_polygon(PackedVector2Array([p + u * 0.68 * r + v * (0.075 * r + o),
			p + u * (0.84 * r + o * 1.6), p + u * 0.68 * r - v * (0.075 * r + o)]), pick.call(steel))
		if o == 0.0:
			_blade_quad(ci, p, u, v, -0.22 * r, 0.66 * r, 0.018 * r, edge)
		_blade_quad(ci, p, u, v, -0.33 * r - o, -0.25 * r + o, 0.25 * r + o, pick.call(gold))
		_blade_quad(ci, p, u, v, -0.6 * r, -0.33 * r, 0.05 * r + o, pick.call(grip))
		Shapes.circle(ci, p - u * 0.65 * r, 0.085 * r + o, pick.call(gold))
		_blade_quad(ci, p, w, x, -0.74 * r - o, 0.52 * r, 0.065 * r + o, pick.call(wood))
		_blade_quad(ci, p, w, x, -0.46 * r - o, -0.39 * r + o, 0.08 * r + o, pick.call(gold))
		var points := PackedVector2Array()
		for i in 8:
			points.append(star + Vector2.from_angle(-PI / 2 + i * PI / 4) * ((0.27 * r if i % 2 == 0 else 0.075 * r) + o * 1.4))
		ci.draw_colored_polygon(points, pick.call(glow))
	draw_tools.call(0.045 * r, Color(0.08, 0.04, 0.03, 0.8 if not dim else 0.4))
	draw_tools.call(0.0)
	Shapes.circle(ci, star, 0.07 * r, MAGIC.lightened(0.6) if not dim else glow)


## Rectangle from a0 to a1 along unit axis u, half-width hw across it (along v).
static func _blade_quad(ci: CanvasItem, p: Vector2, u: Vector2, v: Vector2, a0: float, a1: float, hw: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([p + u * a0 + v * hw, p + u * a1 + v * hw,
		p + u * a1 - v * hw, p + u * a0 - v * hw]), col)


static func wand(ci: CanvasItem, p: Vector2, r: float) -> void:
	Shapes.line(ci, p + Vector2(-r * 0.7, r * 0.7), p + Vector2(r * 0.4, -r * 0.4), Color(0.55, 0.35, 0.2), r * 0.18, true)
	star(ci, p + Vector2(r * 0.5, -r * 0.5), r * 0.42, MAGIC.lightened(0.3))


## Icon of a wand upgrade (Rules.WAND_UPGRADES), drawn rightward from its
## left-middle point, r tall on each side:
##   recharge  a recharging charge crystal with speed lines
##   charges   three charge crystals: the starting ones filled, then the one the
##             next level adds, filled and outlined in gold under a gold plus (all
##             filled once maxed)
##   heal      the wand beside a green cross
##   hex       the wand beside a stun spiral
static func wand_upgrade(ci: CanvasItem, id: String, left: Vector2, r: float, charges := 1) -> void:
	match id:
		"recharge":
			for i in 3:
				var y := (i - 1) * r * 0.45
				Shapes.line(ci, left + Vector2(r * (0.0 if i == 1 else 0.3), y), left + Vector2(r * 0.95, y), Color(0.95, 0.92, 0.85), r * 0.15, true)
			charge_crystal(ci, left + Vector2(r * 1.65, 0), r * 0.85, false, 0.6)
		"charges":
			for i in Rules.MAX_CHARGES:
				var p := left + Vector2(r * 0.5 + i * r * 1.25, r * 0.1)
				var gold := i == charges
				if gold:
					var plus := p + Vector2(r * 0.6, -r * 0.78)
					Shapes.line(ci, plus + Vector2(-r * 0.28, 0), plus + Vector2(r * 0.28, 0), GOLD, r * 0.18)
					Shapes.line(ci, plus + Vector2(0, -r * 0.28), plus + Vector2(0, r * 0.28), GOLD, r * 0.18)
				charge_crystal(ci, p, r * 0.72, i <= charges, 0.0, GOLD if gold else Color(0, 0, 0, 0))
		"heal":
			wand(ci, left + Vector2(r * 0.95, 0), r * 1.2)
			var c := left + Vector2(r * 2.55, 0)
			var green := Color(0.5, 1, 0.65)
			Shapes.line(ci, c + Vector2(-r * 0.62, 0), c + Vector2(r * 0.62, 0), green, r * 0.38)
			Shapes.line(ci, c + Vector2(0, -r * 0.62), c + Vector2(0, r * 0.62), green, r * 0.38)
		"hex":
			wand(ci, left + Vector2(r * 0.95, 0), r * 1.2)
			stun_spiral(ci, left + Vector2(r * 2.6, 0), r * 0.78)


## Stun spiral: a curl winding out from its centre over about 1.6 turns.
static func stun_spiral(ci: CanvasItem, c: Vector2, r: float, rotation := 0.0, col := MAGIC.lightened(0.45)) -> void:
	var points := PackedVector2Array()
	var turns := 3.2 * PI
	for i in 33:
		var a := turns * i / 32.0
		points.append(c + Vector2.from_angle(a + rotation) * r * (0.12 + 0.88 * a / turns))
	Shapes.polyline(ci, points, col, r * 0.2, true)


static func crown(ci: CanvasItem, p: Vector2, r: float) -> void:
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r, r * 0.5), p + Vector2(-r, -r * 0.5), p + Vector2(-r * 0.5, 0), p + Vector2(0, -r * 0.8), p + Vector2(r * 0.5, 0), p + Vector2(r, -r * 0.5), p + Vector2(r, r * 0.5)]), GOLD)
	for x in [-r, 0.0, r]:
		Shapes.circle(ci, p + Vector2(x, -r * (0.8 if x == 0.0 else 0.5)), r * 0.13, Color(1.0, 0.4, 0.4))


static func skull(ci: CanvasItem, p: Vector2, r: float) -> void:
	Shapes.circle(ci, p + Vector2(0, -r * 0.15), r * 0.75, Color(0.92, 0.9, 0.85))
	ci.draw_rect(Rect2(p + Vector2(-r * 0.4, r * 0.3), Vector2(r * 0.8, r * 0.45)), Color(0.92, 0.9, 0.85))
	Shapes.circle(ci, p + Vector2(-r * 0.3, -r * 0.15), r * 0.2, DARK)
	Shapes.circle(ci, p + Vector2(r * 0.3, -r * 0.15), r * 0.2, DARK)
	for x in [-0.2, 0.0, 0.2]:
		Shapes.line(ci, p + Vector2(x * r, r * 0.4), p + Vector2(x * r, r * 0.75), DARK, 2.0)


static func draw_mark(ci: CanvasItem, p: Vector2, r: float) -> void:
	Shapes.line(ci, p + Vector2(-r, -r * 0.3), p + Vector2(r, -r * 0.3), Color(0.85, 0.85, 0.9), r * 0.25)
	Shapes.line(ci, p + Vector2(-r, r * 0.3), p + Vector2(r, r * 0.3), Color(0.85, 0.85, 0.9), r * 0.25)


static func restart(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	Shapes.arc(ci, p, r, -PI * 0.3, PI * 1.4, 28, col, r * 0.22, true)
	var tip := p + Vector2.from_angle(-PI * 0.3) * r
	ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-r * 0.4, -r * 0.1), tip + Vector2(r * 0.25, -r * 0.45), tip + Vector2(r * 0.2, r * 0.35)]), col)


## Small pie showing a probability.
static func chance_pie(ci: CanvasItem, p: Vector2, r: float, chance: float) -> void:
	Shapes.circle(ci, p, r, Color(0.15, 0.1, 0.2))
	var pts := PackedVector2Array([p])
	var steps := maxi(3, int(24 * chance))
	for i in steps + 1:
		pts.append(p + Vector2.from_angle(-PI / 2 + TAU * chance * i / steps) * r)
	if chance >= 0.999:
		Shapes.circle(ci, p, r, MAGIC)
	else:
		ci.draw_colored_polygon(pts, MAGIC)
	Shapes.arc(ci, p, r, 0, TAU, 20, MAGIC.lightened(0.3), 1.5, true)


static func arrow_right(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	Shapes.line(ci, p + Vector2(-r, 0), p + Vector2(r * 0.5, 0), col, r * 0.3, true)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(r * 0.2, -r * 0.55), p + Vector2(r, 0), p + Vector2(r * 0.2, r * 0.55)]), col)


## Stat icons used by the hover card's bars.
static func stat_icon(ci: CanvasItem, key: String, p: Vector2, r: float) -> void:
	match key:
		"hp":
			heart(ci, p, r, Color(0.9, 0.25, 0.3))
		"dmg":
			Shapes.line(ci, p + Vector2(-r * 0.8, r * 0.8), p + Vector2(r * 0.8, -r * 0.8), Color(0.85, 0.88, 0.92), r * 0.3, true)
			Shapes.line(ci, p + Vector2(-r * 0.75, r * 0.2), p + Vector2(-r * 0.2, r * 0.75), GOLD, r * 0.3, true)
		"speed":
			for i in 2:
				var dx := (i - 0.5) * r * 0.8
				Shapes.polyline(ci, PackedVector2Array([p + Vector2(dx - r * 0.35, -r * 0.6), p + Vector2(dx + r * 0.25, 0), p + Vector2(dx - r * 0.35, r * 0.6)]), Color(1.0, 0.85, 0.3), r * 0.25, true)
		"range":
			Shapes.arc(ci, p, r * 0.9, 0, TAU, 16, Color(0.9, 0.5, 0.4), r * 0.2, true)
			Shapes.arc(ci, p, r * 0.45, 0, TAU, 12, Color(0.9, 0.5, 0.4), r * 0.2, true)
			Shapes.circle(ci, p, r * 0.15, Color(0.9, 0.5, 0.4))
		"move":
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.5, -r * 0.8), p + Vector2(r * 0.1, -r * 0.8), p + Vector2(r * 0.1, r * 0.3), p + Vector2(r * 0.9, r * 0.4), p + Vector2(r * 0.9, r * 0.8), p + Vector2(-r * 0.5, r * 0.8)]), Color(0.65, 0.45, 0.3))
		"armour":
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.8, -r * 0.8), p + Vector2(r * 0.8, -r * 0.8), p + Vector2(r * 0.8, 0), p + Vector2(0, r * 0.95), p + Vector2(-r * 0.8, 0)]), Color(0.55, 0.65, 0.85))


## Small crests for the starting cards, using the same motifs as the creatures.
static func pack_emblem(ci: CanvasItem, kind: String, p: Vector2, highlighted: bool) -> void:
	var rim := Color(0.62, 0.45, 0.26)
	if highlighted:
		rim = rim.lerp(GOLD, 0.45)
	for side in [-1, 1]:
		Shapes.line(ci, p + Vector2(26 * side, 0), p + Vector2(59 * side, 0), Color(rim, 0.65), 1.0, true)
		Shapes.circle(ci, p + Vector2(59 * side, 0), 1.5, rim, true)
	Shapes.circle(ci, p + Vector2(0, 2), 22, DARK, true)
	Shapes.circle(ci, p, 21, Color(0.22, 0.16, 0.12), true)
	Shapes.circle(ci, p, 21, rim, false, 1.5, true)
	match kind:
		"frost_shield":
			var shield := [Vector2(-0.8, -0.8), Vector2(0.8, -0.8), Vector2(0.8, 0.23),
				Vector2(0, 1.0), Vector2(-0.8, 0.23)]
			_poly(ci, p, 15, shield, Color(0.25, 0.4, 0.75))
			Shapes.polyline(ci, _pts(p, 15, shield + [shield[0]]), Color(0.78, 0.86, 0.95), 1.5, true)
			_snowflake(ci, p + Vector2(0, -2), 6, Color(0.85, 0.97, 1.0))
		"song":
			note_shadowed(ci, p + Vector2(7, 2), 10, Color(1.0, 0.6, 0.9))
			note_shadowed(ci, p + Vector2(-5, -2), 14, GOLD)
		"spear":
			var shaft := Color(0.77, 0.49, 0.27)
			Shapes.line(ci, p + Vector2(-12, 12), p + Vector2(8, -8), shaft, 3, true)
			Shapes.line(ci, p + Vector2(-14, 2), p + Vector2(-7, -5), Color(shaft, 0.8), 2, true)
			Shapes.line(ci, p + Vector2(0, 13), p + Vector2(7, 6), Color(shaft, 0.8), 2, true)
			_poly(ci, p, 1, [Vector2(3, -9), Vector2(14, -14), Vector2(9, -3)], Color(0.85, 0.87, 0.9))
		"pitchfork":
			# Wheat ear behind a peasant's pitchfork.
			var straw := Color(0.95, 0.8, 0.35)
			Shapes.line(ci, p + Vector2(-9, 13), p + Vector2(-3, -6), Color(straw, 0.8), 1.5, true)
			for k in 4:
				var q := p + Vector2(-3, -6).lerp(Vector2(-8, 9), k / 4.0)
				_ellipse(ci, q + Vector2(-2.5, 0), 1, Vector2.ZERO, 3.2, 1.6, straw, -0.9)
				_ellipse(ci, q + Vector2(2.0, -1), 1, Vector2.ZERO, 3.2, 1.6, straw, 0.6)
			var wood := Color(0.6, 0.38, 0.2)
			var prong := Color(0.8, 0.8, 0.85)
			Shapes.line(ci, p + Vector2(8, 15), p + Vector2(2, -4), wood, 3, true)
			Shapes.line(ci, p + Vector2(-3, -4), p + Vector2(8, -4), prong, 2, true)
			for x in [-3.0, 2.5, 8.0]:
				Shapes.line(ci, p + Vector2(x, -4), p + Vector2(x, -14), prong, 1.8, true)
		"halo":
			# Rising sun of the temple, ringed by a halo.
			for k in 8:
				var d := Vector2.from_angle(TAU * k / 8.0 + 0.2)
				Shapes.line(ci, p + d * 9, p + d * 15, Color(GOLD, 0.85), 2, true)
			Shapes.circle(ci, p, 7, Color(1.0, 0.97, 0.85), true)
			Shapes.arc(ci, p, 10.5, 0, TAU, 24, GOLD, 2, true)
		"fire_ice":
			_flame(ci, p + Vector2(-6, 3), 11)
			_snowflake(ci, p + Vector2(7, -2), 6.5, Color(0.85, 0.97, 1.0))
		"bow":
			var wood := Color(0.72, 0.46, 0.22)
			Shapes.arc(ci, p + Vector2(-6, 0), 14, -1.15, 1.15, 16, wood, 3, true)
			var top := p + Vector2(-6, 0) + Vector2.from_angle(-1.15) * 14
			var bottom := p + Vector2(-6, 0) + Vector2.from_angle(1.15) * 14
			Shapes.line(ci, top, bottom, Color(0.95, 0.95, 0.9), 1, true)
			Shapes.line(ci, p + Vector2(-12, 0), p + Vector2(12, 0), Color(0.85, 0.8, 0.7), 1.6, true)
			_poly(ci, p, 1, [Vector2(15, 0), Vector2(9, -4), Vector2(9, 4)], Color(0.85, 0.87, 0.9))
			_poly(ci, p, 1, [Vector2(-12, 0), Vector2(-15, -4), Vector2(-10, 0), Vector2(-15, 4)], Color(0.3, 0.6, 0.3))
		"spear_wall":
			# Three raised spears behind a row of shields.
			var shaft := Color(0.72, 0.47, 0.25)
			for x in [-8.0, 0.0, 8.0]:
				Shapes.line(ci, p + Vector2(x, 8), p + Vector2(x, -9), shaft, 2, true)
				_poly(ci, p, 1, [Vector2(x - 3, -9), Vector2(x + 3, -9), Vector2(x, -16)], Color(0.85, 0.87, 0.9))
			for x in [-8.0, 0.0, 8.0]:
				Shapes.circle(ci, p + Vector2(x, 7), 5, Color(0.45, 0.5, 0.25), true)
				Shapes.arc(ci, p + Vector2(x, 7), 5, 0, TAU, 12, Color(0.75, 0.62, 0.3), 1.2, true)
		"moon_dagger":
			Shapes.circle(ci, p + Vector2(-3, -3), 11, Color(0.95, 0.92, 0.75), true)
			Shapes.circle(ci, p + Vector2(2, -6), 10, Color(0.22, 0.16, 0.12), true)
			Shapes.line(ci, p + Vector2(-6, 13), p + Vector2(-2, 9), Color(0.35, 0.18, 0.45), 3, true)
			Shapes.line(ci, p + Vector2(-6, 7), p + Vector2(0, 11), GOLD, 2, true)
			_poly(ci, p, 1, [Vector2(-4, 8), Vector2(-1, 11), Vector2(12, -8)], Color(0.85, 0.87, 0.92))
		"flame":
			_flame(ci, p + Vector2(0, 4), 15)
			for v in [Vector2(-11, -8), Vector2(10, -11), Vector2(12, 2)]:
				Shapes.circle(ci, p + v, 1.6, Color(1.0, 0.7, 0.2), true)
		"mug":
			var wood := Color(0.62, 0.4, 0.2)
			Shapes.arc(ci, p + Vector2(8, 1), 5.5, -PI * 0.5, PI * 0.5, 10, wood.darkened(0.2), 2.5, true)
			ci.draw_rect(Rect2(p + Vector2(-9, -6), Vector2(17, 19)), wood)
			for y in [-1.0, 7.0]:
				Shapes.line(ci, p + Vector2(-9, y), p + Vector2(8, y), Color(0.45, 0.45, 0.5), 1.5)
			for v in [Vector2(-6, -7), Vector2(0, -9), Vector2(5, -7)]:
				Shapes.circle(ci, p + v, 4.2, Color(0.98, 0.96, 0.9), true)
		"banner":
			Shapes.line(ci, p + Vector2(-9, 15), p + Vector2(-9, -15), Color(0.72, 0.47, 0.25), 2, true)
			Shapes.circle(ci, p + Vector2(-9, -15), 2, GOLD, true)
			var cloth := [Vector2(-8, -13), Vector2(12, -13), Vector2(12, 6), Vector2(2, 1), Vector2(-8, 6)]
			_poly(ci, p, 1, cloth, Color(0.95, 0.93, 0.88))
			Shapes.polyline(ci, _pts(p, 1, cloth + [cloth[0]]), GOLD, 1.2, true)
			Shapes.line(ci, p + Vector2(2, -10), p + Vector2(2, -1), GOLD, 2.5)
			Shapes.line(ci, p + Vector2(-2, -7), p + Vector2(6, -7), GOLD, 2.5)


# --- Difficulty hats ------------------------------------------------------------
# One hat per opponent level, from a patched apprentice cap to a glowing
# archmage hat. `p` is the middle of the crown, `r` its scale, `t` animation time.

static func difficulty_hat(ci: CanvasItem, level: int, p: Vector2, r: float, t: float) -> void:
	match level:
		Difficulty.APPRENTICE:
			_apprentice_hat(ci, p, r)
		Difficulty.ADEPT:
			_adept_hat(ci, p, r, t)
		_:
			_archmage_hat(ci, p, r, t)


## A journey opponent drawn full length (OpponentDB id), centred on p; s is
## about half its width, `t` animation time. See OpponentArt.
static func opponent(ci: CanvasItem, id: String, p: Vector2, s: float, t: float) -> void:
	OpponentArt.draw(ci, id, p, s, t)


## Ring polygon of an ellipse, for brims and trims.
static func _ellipse_points(c: Vector2, rx: float, ry: float, from := 0.0, to := TAU, steps := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var a := lerpf(from, to, float(i) / steps)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## Band following a straight cone between two heights (cone tip, base half-width).
static func _cone_band(ci: CanvasItem, p: Vector2, s: float, tip: Vector2, base_y: float, half: float, y0: float, y1: float, col: Color) -> void:
	var w0 := half * (y0 - tip.y) / (base_y - tip.y)
	var w1 := half * (y1 - tip.y) / (base_y - tip.y)
	var c0 := lerpf(tip.x, 0.0, (y0 - tip.y) / (base_y - tip.y))
	var c1 := lerpf(tip.x, 0.0, (y1 - tip.y) / (base_y - tip.y))
	_poly(ci, p, s, [Vector2(c0 - w0, y0), Vector2(c0 + w0, y0), Vector2(c1 + w1, y1), Vector2(c1 - w1, y1)], col)


## Modest: short, faded felt cap with a drooping tip and a stitched patch.
static func _apprentice_hat(ci: CanvasItem, p: Vector2, s: float) -> void:
	var felt := Color(0.56, 0.45, 0.31)
	_ellipse(ci, p, s, Vector2(0, 0.62), 0.92, 0.2, Color(0, 0, 0, 0.25))
	_ellipse(ci, p, s, Vector2(0, 0.5), 0.9, 0.19, felt.darkened(0.3))
	_poly(ci, p, s, [Vector2(-0.55, 0.5), Vector2(0.55, 0.5), Vector2(0.28, -0.12), Vector2(0.66, -0.06),
		Vector2(0.1, -0.5), Vector2(-0.12, -0.42)], felt)
	_poly(ci, p, s, [Vector2(-0.55, 0.5), Vector2(-0.2, 0.5), Vector2(-0.02, -0.44), Vector2(-0.12, -0.42)], felt.darkened(0.12))
	# Patch with stitches.
	var patch := Color(0.42, 0.5, 0.34)
	_poly(ci, p, s, [Vector2(-0.2, 0.08), Vector2(0.08, 0.04), Vector2(0.11, 0.3), Vector2(-0.18, 0.33)], patch)
	for k in 3:
		var y := 0.1 + k * 0.08
		_line(ci, p, s, Vector2(-0.24, y + 0.01), Vector2(-0.15, y), Color(0.9, 0.85, 0.7, 0.8), 0.035)
	_circ(ci, p, s, Vector2(0.66, -0.06), 0.07, felt.darkened(0.2))


## Respectable: tall straight blue hat, gold band and a single star.
static func _adept_hat(ci: CanvasItem, p: Vector2, s: float, t: float) -> void:
	var cloth := Color(0.2, 0.36, 0.78)
	var tip := Vector2(0.06, -1.05)
	_ellipse(ci, p, s, Vector2(0, 0.64), 1.02, 0.22, Color(0, 0, 0, 0.25))
	_ellipse(ci, p, s, Vector2(0, 0.52), 1.0, 0.21, cloth.darkened(0.35))
	_poly(ci, p, s, [Vector2(-0.56, 0.52), Vector2(0.56, 0.52), tip], cloth)
	_poly(ci, p, s, [Vector2(-0.56, 0.52), Vector2(-0.18, 0.52), tip], cloth.darkened(0.15))
	_cone_band(ci, p, s, tip, 0.52, 0.56, 0.28, 0.46, GOLD.darkened(0.1))
	var twinkle := 1.0 + sin(t * 3.0) * 0.08
	star(ci, p + Vector2(0.02, -0.22) * s, 0.2 * s * twinkle, GOLD)


## Impressive: tall purple hat with a curled tip, moon and stars, jewelled
## band, gold-trimmed brim, a pulsing aura and orbiting sparks.
static func _archmage_hat(ci: CanvasItem, p: Vector2, s: float, t: float) -> void:
	var cloth := Color(0.44, 0.17, 0.66)
	var pulse := 0.5 + 0.5 * sin(t * 2.2)
	for k in 4:
		Shapes.circle(ci, p + Vector2(0, -0.25) * s, s * (1.05 + k * 0.12 + pulse * 0.06), Color(MAGIC, 0.07 - k * 0.012))
	var orbit := func(front: bool) -> void:
		for k in 5:
			var a := t * 0.9 + TAU * k / 5.0
			if (sin(a) > 0.0) != front:
				continue
			var q := p + Vector2(cos(a) * 1.25, -0.2 + sin(a) * 0.38) * s
			star(ci, q, s * (0.07 + 0.04 * (sin(a) + 1.0)), Color(1, 0.92, 0.55, 0.55 + 0.4 * sin(a + 1.0)))
	orbit.call(false)
	_ellipse(ci, p, s, Vector2(0, 0.66), 1.12, 0.24, Color(0, 0, 0, 0.3))
	_ellipse(ci, p, s, Vector2(0, 0.52), 1.12, 0.25, cloth.darkened(0.4))
	Shapes.polyline(ci, _pts(p, s, Array(_ellipse_points(Vector2(0, 0.52), 1.12, 0.25, 0.0, PI))), GOLD, maxf(1.5, 0.05 * s), true)
	var curl_tip := Vector2(0.62, -1.02)
	_poly(ci, p, s, [Vector2(-0.6, 0.52), Vector2(0.6, 0.52), Vector2(0.24, -0.62), Vector2(curl_tip.x, curl_tip.y + 0.12),
		curl_tip, Vector2(0.1, -1.04), Vector2(-0.14, -0.66)], cloth)
	_poly(ci, p, s, [Vector2(-0.6, 0.52), Vector2(-0.22, 0.52), Vector2(-0.02, -0.68), Vector2(-0.14, -0.66)], cloth.darkened(0.18))
	_circ(ci, p, s, curl_tip, 0.09, GOLD)
	# Jewelled band.
	_poly(ci, p, s, [Vector2(-0.53, 0.3), Vector2(0.53, 0.3), Vector2(0.58, 0.47), Vector2(-0.58, 0.47)], GOLD)
	_circ(ci, p, s, Vector2(0, 0.385), 0.1, Color(0.9, 0.15, 0.3))
	_circ(ci, p, s, Vector2(-0.03, 0.36), 0.035, Color(1, 0.8, 0.85))
	# Crescent moon and stars.
	_circ(ci, p, s, Vector2(-0.2, -0.05), 0.17, Color(1, 0.95, 0.7))
	_circ(ci, p, s, Vector2(-0.13, -0.09), 0.15, cloth)
	star(ci, p + Vector2(0.2, -0.32) * s, 0.13 * s, GOLD)
	star(ci, p + Vector2(0.02, -0.68) * s, 0.09 * s, GOLD.lightened(0.2))
	star(ci, p + Vector2(0.28, 0.1) * s, 0.08 * s, GOLD.lightened(0.3))
	orbit.call(true)


## A tiny floating island, about 22 * s wide: a grass top with a fir and a
## cottage over a jagged rock that tapers into the void.
static func floating_island(ci: CanvasItem, p: Vector2, s: float) -> void:
	_poly(ci, p, s, [Vector2(-10, 0), Vector2(-3, 12), Vector2(1, 9), Vector2(4, 15), Vector2(10, 0)], Color("7a5a3e"))
	_poly(ci, p, s, [Vector2(1, 9), Vector2(4, 15), Vector2(10, 0)], Color("5e4430"))
	_ellipse(ci, p, s, Vector2.ZERO, 11, 4, Color("6f9a4f"))
	_poly(ci, p, s, [Vector2(-6, -1), Vector2(-3.5, -8), Vector2(-1, -1)], Color("3f6b3a"))
	_poly(ci, p, s, [Vector2(2, -4.5), Vector2(7, -4.5), Vector2(7, -1), Vector2(2, -1)], Color("c9b58b"))
	_poly(ci, p, s, [Vector2(1.2, -4.2), Vector2(4.5, -7.5), Vector2(7.8, -4.2)], Color("805544"))


## Sky-blue medallion ringed in gold with a floating island bobbing inside: the
## way back to the journey map. `t` drives the bob; `hot` brightens the ring.
static func island_medallion(ci: CanvasItem, p: Vector2, r: float, t: float, hot := false) -> void:
	var k := r / 20.0
	Shapes.circle(ci, p, r, Color("9cc0d4").lightened(0.08 if hot else 0.0))
	Shapes.ellipse(ci, p + Vector2(-9, 9) * k, 6 * k, 2.5 * k, Color(1, 1, 1, 0.6))
	Shapes.ellipse(ci, p + Vector2(8, -10) * k, 4 * k, 1.6 * k, Color(1, 1, 1, 0.45))
	floating_island(ci, p + Vector2(1, sin(t * 2.0) * 1.5 - 1) * k, 1.05 * k)
	Shapes.arc(ci, p, r, 0, TAU, 40, GOLD.lightened(0.45) if hot else GOLD, 2.5 * k, true)
