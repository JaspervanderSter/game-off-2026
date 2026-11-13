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
	ci.draw_line(p + a * s, p + b * s, col, maxf(1.0, w * s), true)


static func _circ(ci: CanvasItem, p: Vector2, s: float, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(p + c * s, r * s, col)


static func _ellipse(ci: CanvasItem, p: Vector2, s: float, c: Vector2, rx: float, ry: float, col: Color, rot := 0.0) -> void:
	var pts := []
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	_poly(ci, p, s, pts, col)


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
	ci.draw_arc(p + Vector2(0, -0.38) * s, 0.31 * s, PI, TAU, 12, col, 0.16 * s, true)


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
			ci.draw_polyline(_pts(p, s, shield + [shield[0]]), GOLD, maxf(1.0, 0.07 * s), true)
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
			ci.draw_arc(p + Vector2(0.3, 0.1) * s, 0.65 * s, -1.2, 1.2, 14, Color(0.6, 0.38, 0.18), maxf(1.0, 0.08 * s), true)
			_line(ci, p, s, Vector2(0.3, 0.1) + Vector2.from_angle(-1.2) * 0.65, Vector2(0.3, 0.1) + Vector2.from_angle(1.2) * 0.65, Color(0.95, 0.95, 0.9), 0.03)
		"crossbowman":
			_humanoid(ci, p, s, Color(0.55, 0.25, 0.2))
			_helmet(ci, p, s, Color(0.6, 0.62, 0.66))
			_line(ci, p, s, Vector2(-0.2, 0.3), Vector2(0.95, 0.3), Color(0.45, 0.28, 0.12), 0.12)
			ci.draw_arc(p + Vector2(0.6, 0.55) * s, 0.42 * s, -PI * 0.85, -PI * 0.15, 12, Color(0.35, 0.35, 0.4), maxf(1.0, 0.08 * s), true)
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
			_line(ci, p, s, Vector2(0, 0.1), Vector2(0, 0.7), GOLD, 0.12)
			_line(ci, p, s, Vector2(-0.2, 0.3), Vector2(0.2, 0.3), GOLD, 0.12)
			ci.draw_arc(p + Vector2(0, -0.75) * s, 0.25 * s, 0, TAU, 16, GOLD, maxf(1.0, 0.07 * s), true)
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
			ci.draw_polyline(body, Color(0.3, 0.7, 0.25), maxf(2.0, 0.28 * s), true)
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
		ci.draw_line(p - d, p + d, col, maxf(1.0, s * 0.22), true)


## Team base under a creature: coloured disc with a strong ring.
static func team_base(ci: CanvasItem, p: Vector2, r: float, team: int, highlight := false) -> void:
	var col := team_color(team)
	ci.draw_circle(p, r, col.darkened(0.65))
	ci.draw_arc(p, r, 0, TAU, 32, col, 4.0 if not highlight else 6.0, true)
	if highlight:
		ci.draw_arc(p, r + 5.0, 0, TAU, 32, Color(1, 1, 1, 0.8), 2.0, true)


## Full token used outside combat (prep board, reserve, shop, tooltip).
static func token(ci: CanvasItem, id: String, p: Vector2, r: float, team: int, highlight := false) -> void:
	team_base(ci, p, r, team, highlight)
	creature(ci, id, p, r * 0.92)


# --- Combat overlays ----------------------------------------------------------

static func health_bar(ci: CanvasItem, pos: Vector2, w: float, ratio: float, team: int) -> void:
	ci.draw_rect(Rect2(pos, Vector2(w, 6)), Color(0, 0, 0, 0.7))
	ci.draw_rect(Rect2(pos + Vector2(1, 1), Vector2((w - 2) * clampf(ratio, 0, 1), 4)), team_color(team).lightened(0.25))


static func star(ci: CanvasItem, p: Vector2, r: float, col := GOLD) -> void:
	if r < 0.5:
		return # fading effects shrink stars to nothing; degenerate polygons fail to triangulate
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + TAU * i / 10.0
		pts.append(p + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.45))
	ci.draw_colored_polygon(pts, col)


static func merge_stars(ci: CanvasItem, center: Vector2, count: int) -> void:
	var shown := clampi(count, 0, Rules.MAX_STARS)
	for i in shown:
		star(ci, center + Vector2((i - (shown - 1) * 0.5) * 11.0, 0), 6.0)


static func merge_progress(ci: CanvasItem, center: Vector2, copies: int, stars: int) -> void:
	if stars >= Rules.MAX_STARS:
		return
	for i in 3:
		var p := center + Vector2((i - 1) * 10, 0)
		ci.draw_circle(p, 4, Color(0.08, 0.06, 0.04, 0.95))
		ci.draw_arc(p, 3.4, 0, TAU, 16, GOLD, 1.1, true)
		if i < copies:
			ci.draw_circle(p, 2.3, GOLD)


static func padlock(ci: CanvasItem, p: Vector2, opened := false) -> void:
	var shackle := p + (Vector2(4, -9) if opened else Vector2(0, -4))
	ci.draw_arc(shackle, 6, PI, TAU + (PI / 2.0 if opened else 0.0), 16, GOLD, 3.0, true)
	ci.draw_rect(Rect2(p + Vector2(-8, -4), Vector2(16, 13)), GOLD)
	ci.draw_circle(p + Vector2(0, 1), 2, DARK)


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
	ci.draw_circle(p, ring_r, fill)
	# Dashed rotating ring: blessings turn clockwise, hexes anticlockwise.
	var spin := t * (1.6 if ally else -2.2)
	for i in 8:
		var a := spin + TAU * i / 8.0
		ci.draw_arc(p, ring_r, a, a + TAU / 8.0 * 0.62, 6, main_col, 4.0, true)
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
		ci.draw_arc(p, r, a, a + TAU / segs * 0.5, 4, Color(1, 1, 1, 0.75), 2.5, true)
	ci.draw_arc(p, r + 4.0, -PI / 2, -PI / 2 + TAU * ratio, 24, MAGIC, 3.0, true)


static func parry_mark(ci: CanvasItem, p: Vector2, r: float) -> void:
	ci.draw_line(p + Vector2(-r, r), p + Vector2(r, -r), Color(0.9, 0.95, 1.0), 2.5, true)
	ci.draw_line(p + Vector2(-r, -r), p + Vector2(r, r), Color(0.9, 0.95, 1.0), 2.5, true)


## Fear above a fleeing creature: a wobbling purple exclamation mark with a
## dark outline so it reads on the light board.
static func fear_mark(ci: CanvasItem, p: Vector2, r: float, t: float) -> void:
	var q := p + Vector2(sin(t * 30.0) * 1.5, 0)
	for pass_i in 2:
		var col := Color(0.12, 0.05, 0.15) if pass_i == 0 else Color(0.85, 0.55, 1.0)
		var w := 6.0 if pass_i == 0 else 3.5
		ci.draw_line(q + Vector2(0, -r), q + Vector2(0, r * 0.35), col, w, true)
		ci.draw_circle(q + Vector2(0, r * 0.9), w * 0.5, col)


## Small status pip: negative effects use a dark red rim, positive a green rim.
static func status(ci: CanvasItem, key: String, p: Vector2, r: float) -> void:
	var good := key in ["inspired", "regen", "pack"]
	ci.draw_circle(p, r + 1.5, Color(0.1, 0.5, 0.15) if good else Color(0.55, 0.05, 0.05))
	ci.draw_circle(p, r, Color(0.08, 0.08, 0.1))
	match key:
		"poisoned":
			ci.draw_circle(p + Vector2(0, 1.5), r * 0.55, Color(0.5, 1.0, 0.3))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.5, 1.0), p + Vector2(r * 0.5, 1.0), p + Vector2(0, -r * 0.8)]), Color(0.5, 1.0, 0.3))
		"chilled":
			_snowflake(ci, p, r * 0.8, Color(0.7, 0.9, 1.0))
		"burning":
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.65, r * 0.25), p + Vector2(r * 0.15, -r * 0.9), p + Vector2(r * 0.65, r * 0.25)]), Color(1.0, 0.45, 0.1))
			ci.draw_circle(p + Vector2(0, r * 0.25), r * 0.5, Color(1.0, 0.7, 0.2))
		"exposed":
			ci.draw_rect(Rect2(p - Vector2(r * 0.5, r * 0.6), Vector2(r, r * 1.2)), Color(0.75, 0.75, 0.8))
			ci.draw_line(p + Vector2(-r * 0.6, -r * 0.6), p + Vector2(r * 0.6, r * 0.6), Color(1, 0.3, 0.3), 2.0)
		"dazzled":
			ci.draw_arc(p, r * 0.6, 0, TAU, 10, Color(0.4, 0.6, 1.0), 2.0)
			ci.draw_circle(p, r * 0.25, GOLD)
		"feared":
			ci.draw_line(p + Vector2(0, -r * 0.7), p + Vector2(0, r * 0.2), Color(0.85, 0.55, 1.0), 2.5)
			ci.draw_circle(p + Vector2(0, r * 0.6), 1.4, Color(0.85, 0.55, 1.0))
		"inspired":
			note(ci, p, r * 0.9, GOLD)
		"regen":
			ci.draw_line(p + Vector2(-r * 0.6, 0), p + Vector2(r * 0.6, 0), Color(0.5, 1.0, 0.5), 2.5)
			ci.draw_line(p + Vector2(0, -r * 0.6), p + Vector2(0, r * 0.6), Color(0.5, 1.0, 0.5), 2.5)
		"pack":
			ci.draw_circle(p + Vector2(-r * 0.3, 0), r * 0.35, Color(0.8, 0.8, 0.85))
			ci.draw_circle(p + Vector2(r * 0.3, 0), r * 0.35, Color(0.8, 0.8, 0.85))


static func note(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(p + Vector2(-r * 0.3, r * 0.45), r * 0.35, col)
	ci.draw_line(p + Vector2(r * 0.02, r * 0.45), p + Vector2(r * 0.02, -r * 0.7), col, 2.0)
	ci.draw_line(p + Vector2(r * 0.02, -r * 0.7), p + Vector2(r * 0.6, -r * 0.4), col, 2.0)


## Note with a dark drop shadow so it stays readable on the light board.
static func note_shadowed(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	note(ci, p + Vector2(1.5, 1.5), r, Color(0.15, 0.1, 0.05, col.a * 0.7))
	note(ci, p, r, col)


static func projectile(ci: CanvasItem, kind: String, p: Vector2, dir: Vector2) -> void:
	match kind:
		"arrow":
			ci.draw_line(p - dir * 12.0, p, Color(0.85, 0.7, 0.45), 2.5, true)
			ci.draw_circle(p, 2.5, Color(0.9, 0.9, 0.95))
		"bolt":
			ci.draw_line(p - dir * 10.0, p, Color(0.35, 0.3, 0.3), 4.5, true)
			ci.draw_circle(p, 3.5, Color(0.9, 0.9, 0.95))
		"seeker_bolt":
			# Homing bolt: same shaft with a glowing cyan trail and tip.
			ci.draw_line(p - dir * 22.0, p - dir * 8.0, Color(0.4, 0.95, 1.0, 0.35), 6.0, true)
			ci.draw_line(p - dir * 10.0, p, Color(0.35, 0.3, 0.3), 4.5, true)
			ci.draw_circle(p, 5.5, Color(0.4, 0.95, 1.0, 0.45))
			ci.draw_circle(p, 3.5, Color(0.85, 1.0, 1.0))
		"fire", "fireball":
			var size := 2.2 if kind == "fireball" else 1.0
			ci.draw_circle(p - dir * 6.0 * size, 5.0 * size, Color(1.0, 0.4, 0.1, 0.5))
			ci.draw_circle(p, 6.5 * size, Color(1.0, 0.5, 0.1))
			ci.draw_circle(p, 3.5 * size, Color(1.0, 0.95, 0.4))
		"frost":
			_snowflake(ci, p, 6.0, Color(0.75, 0.95, 1.0))
		"holy":
			ci.draw_circle(p, 5.0, Color(1.0, 0.95, 0.6))
		"note":
			note(ci, p, 7.0, Color(1.0, 0.6, 0.9))
		_:
			ci.draw_circle(p, 4.0, Color.WHITE)


# --- Interface icons -------------------------------------------------------------

static func heart(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(p + Vector2(-r * 0.45, -r * 0.2), r * 0.5, col)
	ci.draw_circle(p + Vector2(r * 0.45, -r * 0.2), r * 0.5, col)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.93, 0.0), p + Vector2(r * 0.93, 0.0), p + Vector2(0, r * 0.95)]), col)


static func heart_half(ci: CanvasItem, p: Vector2, r: float, side: int, col: Color) -> void:
	var points := PackedVector2Array()
	for i in 16:
		var angle := lerpf(-0.45, -3.55, i / 15.0)
		var x := (-0.45 + cos(angle) * 0.5) * r
		points.append(p + Vector2(x if side == 0 else -x, (-0.2 + sin(angle) * 0.5) * r))
	points.append(p + Vector2(0, r * 0.95))
	ci.draw_colored_polygon(points, col)


static func wizard_heart(ci: CanvasItem, p: Vector2, r: float, amount: float) -> void:
	heart(ci, p, r, Color(0.25, 0.2, 0.2))
	if amount >= 1.0:
		heart(ci, p, r, Color(0.9, 0.2, 0.28))
	elif amount >= 0.5:
		heart_half(ci, p, r, 0, Color(0.9, 0.2, 0.28))


static func coin(ci: CanvasItem, p: Vector2, r: float) -> void:
	ci.draw_circle(p, r, Color(0.75, 0.55, 0.1))
	ci.draw_circle(p, r * 0.8, GOLD)
	ci.draw_arc(p, r * 0.5, 0, TAU, 12, Color(0.85, 0.6, 0.1), maxf(1.0, r * 0.15), true)


static func wizard_hat(ci: CanvasItem, p: Vector2, r: float, team: int) -> void:
	var col := team_color(team)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r, r * 0.6), p + Vector2(r, r * 0.6), p + Vector2(r * 0.15, -r)]), col.darkened(0.2))
	ci.draw_rect(Rect2(p + Vector2(-r * 1.2, r * 0.5), Vector2(r * 2.4, r * 0.3)), col.darkened(0.45))
	star(ci, p + Vector2(0, r * 0.05), r * 0.3)


## Charge orb with recharge progress arc.
static func charge_orb(ci: CanvasItem, p: Vector2, r: float, filled: bool, progress := 0.0) -> void:
	ci.draw_circle(p, r, Color(0.1, 0.07, 0.15))
	if filled:
		ci.draw_circle(p, r * 0.8, MAGIC)
		ci.draw_circle(p + Vector2(-r * 0.25, -r * 0.25), r * 0.25, Color(1, 1, 1, 0.6))
	elif progress > 0.0:
		ci.draw_arc(p, r * 0.7, -PI / 2, -PI / 2 + TAU * progress, 20, MAGIC, r * 0.3, true)
	ci.draw_arc(p, r, 0, TAU, 20, MAGIC.darkened(0.3), 2.0, true)


static func swords(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	ci.draw_line(p + Vector2(-r, r), p + Vector2(r * 0.8, -r * 0.8), col, r * 0.18, true)
	ci.draw_line(p + Vector2(r, r), p + Vector2(-r * 0.8, -r * 0.8), col, r * 0.18, true)
	ci.draw_line(p + Vector2(-r * 0.75, r * 0.35), p + Vector2(-r * 0.35, r * 0.75), col, r * 0.2, true)
	ci.draw_line(p + Vector2(r * 0.75, r * 0.35), p + Vector2(r * 0.35, r * 0.75), col, r * 0.2, true)


static func wand(ci: CanvasItem, p: Vector2, r: float) -> void:
	ci.draw_line(p + Vector2(-r * 0.7, r * 0.7), p + Vector2(r * 0.4, -r * 0.4), Color(0.55, 0.35, 0.2), r * 0.18, true)
	star(ci, p + Vector2(r * 0.5, -r * 0.5), r * 0.42, MAGIC.lightened(0.3))


static func crown(ci: CanvasItem, p: Vector2, r: float) -> void:
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r, r * 0.5), p + Vector2(-r, -r * 0.5), p + Vector2(-r * 0.5, 0), p + Vector2(0, -r * 0.8), p + Vector2(r * 0.5, 0), p + Vector2(r, -r * 0.5), p + Vector2(r, r * 0.5)]), GOLD)
	for x in [-r, 0.0, r]:
		ci.draw_circle(p + Vector2(x, -r * (0.8 if x == 0.0 else 0.5)), r * 0.13, Color(1.0, 0.4, 0.4))


static func skull(ci: CanvasItem, p: Vector2, r: float) -> void:
	ci.draw_circle(p + Vector2(0, -r * 0.15), r * 0.75, Color(0.92, 0.9, 0.85))
	ci.draw_rect(Rect2(p + Vector2(-r * 0.4, r * 0.3), Vector2(r * 0.8, r * 0.45)), Color(0.92, 0.9, 0.85))
	ci.draw_circle(p + Vector2(-r * 0.3, -r * 0.15), r * 0.2, DARK)
	ci.draw_circle(p + Vector2(r * 0.3, -r * 0.15), r * 0.2, DARK)
	for x in [-0.2, 0.0, 0.2]:
		ci.draw_line(p + Vector2(x * r, r * 0.4), p + Vector2(x * r, r * 0.75), DARK, 2.0)


static func draw_mark(ci: CanvasItem, p: Vector2, r: float) -> void:
	ci.draw_line(p + Vector2(-r, -r * 0.3), p + Vector2(r, -r * 0.3), Color(0.85, 0.85, 0.9), r * 0.25)
	ci.draw_line(p + Vector2(-r, r * 0.3), p + Vector2(r, r * 0.3), Color(0.85, 0.85, 0.9), r * 0.25)


static func restart(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	ci.draw_arc(p, r, -PI * 0.3, PI * 1.4, 28, col, r * 0.22, true)
	var tip := p + Vector2.from_angle(-PI * 0.3) * r
	ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-r * 0.4, -r * 0.1), tip + Vector2(r * 0.25, -r * 0.45), tip + Vector2(r * 0.2, r * 0.35)]), col)


## Small pie showing a probability.
static func chance_pie(ci: CanvasItem, p: Vector2, r: float, chance: float) -> void:
	ci.draw_circle(p, r, Color(0.15, 0.1, 0.2))
	var pts := PackedVector2Array([p])
	var steps := maxi(3, int(24 * chance))
	for i in steps + 1:
		pts.append(p + Vector2.from_angle(-PI / 2 + TAU * chance * i / steps) * r)
	if chance >= 0.999:
		ci.draw_circle(p, r, MAGIC)
	else:
		ci.draw_colored_polygon(pts, MAGIC)
	ci.draw_arc(p, r, 0, TAU, 20, MAGIC.lightened(0.3), 1.5, true)


static func arrow_right(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	ci.draw_line(p + Vector2(-r, 0), p + Vector2(r * 0.5, 0), col, r * 0.3, true)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(r * 0.2, -r * 0.55), p + Vector2(r, 0), p + Vector2(r * 0.2, r * 0.55)]), col)


## Stat icons used by the hover card's bars.
static func stat_icon(ci: CanvasItem, key: String, p: Vector2, r: float) -> void:
	match key:
		"hp":
			heart(ci, p, r, Color(0.9, 0.25, 0.3))
		"dmg":
			ci.draw_line(p + Vector2(-r * 0.8, r * 0.8), p + Vector2(r * 0.8, -r * 0.8), Color(0.85, 0.88, 0.92), r * 0.3, true)
			ci.draw_line(p + Vector2(-r * 0.75, r * 0.2), p + Vector2(-r * 0.2, r * 0.75), GOLD, r * 0.3, true)
		"speed":
			for i in 2:
				var dx := (i - 0.5) * r * 0.8
				ci.draw_polyline(PackedVector2Array([p + Vector2(dx - r * 0.35, -r * 0.6), p + Vector2(dx + r * 0.25, 0), p + Vector2(dx - r * 0.35, r * 0.6)]), Color(1.0, 0.85, 0.3), r * 0.25, true)
		"range":
			ci.draw_arc(p, r * 0.9, 0, TAU, 16, Color(0.9, 0.5, 0.4), r * 0.2, true)
			ci.draw_arc(p, r * 0.45, 0, TAU, 12, Color(0.9, 0.5, 0.4), r * 0.2, true)
			ci.draw_circle(p, r * 0.15, Color(0.9, 0.5, 0.4))
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
		ci.draw_line(p + Vector2(26 * side, 0), p + Vector2(59 * side, 0), Color(rim, 0.65), 1.0, true)
		ci.draw_circle(p + Vector2(59 * side, 0), 1.5, rim, true)
	ci.draw_circle(p + Vector2(0, 2), 22, DARK, true)
	ci.draw_circle(p, 21, Color(0.22, 0.16, 0.12), true)
	ci.draw_circle(p, 21, rim, false, 1.5, true)
	match kind:
		"frost_shield":
			var shield := [Vector2(-0.8, -0.8), Vector2(0.8, -0.8), Vector2(0.8, 0.23),
				Vector2(0, 1.0), Vector2(-0.8, 0.23)]
			_poly(ci, p, 15, shield, Color(0.25, 0.4, 0.75))
			ci.draw_polyline(_pts(p, 15, shield + [shield[0]]), Color(0.78, 0.86, 0.95), 1.5, true)
			_snowflake(ci, p + Vector2(0, -2), 6, Color(0.85, 0.97, 1.0))
		"song":
			note_shadowed(ci, p + Vector2(7, 2), 10, Color(1.0, 0.6, 0.9))
			note_shadowed(ci, p + Vector2(-5, -2), 14, GOLD)
		"spear":
			var shaft := Color(0.77, 0.49, 0.27)
			ci.draw_line(p + Vector2(-12, 12), p + Vector2(8, -8), shaft, 3, true)
			ci.draw_line(p + Vector2(-14, 2), p + Vector2(-7, -5), Color(shaft, 0.8), 2, true)
			ci.draw_line(p + Vector2(0, 13), p + Vector2(7, 6), Color(shaft, 0.8), 2, true)
			_poly(ci, p, 1, [Vector2(3, -9), Vector2(14, -14), Vector2(9, -3)], Color(0.85, 0.87, 0.9))


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
		ci.draw_circle(p + Vector2(0, -0.25) * s, s * (1.05 + k * 0.12 + pulse * 0.06), Color(MAGIC, 0.07 - k * 0.012))
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
	ci.draw_polyline(_pts(p, s, Array(_ellipse_points(Vector2(0, 0.52), 1.12, 0.25, 0.0, PI))), GOLD, maxf(1.5, 0.05 * s), true)
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
