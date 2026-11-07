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
		# --- Fantasy archetypes -----------------------------------------
		"vanguard":
			_humanoid(ci, p, s, Color(0.55, 0.6, 0.68))
			_helmet(ci, p, s, Color(0.7, 0.72, 0.78))
			var shield := [Vector2(-0.8, -0.15), Vector2(0.1, -0.15), Vector2(0.1, 0.35), Vector2(-0.35, 0.9), Vector2(-0.8, 0.35)]
			_poly(ci, p, s, shield, Color(0.25, 0.4, 0.75))
			ci.draw_polyline(_pts(p, s, shield + [shield[0]]), GOLD, maxf(1.0, 0.07 * s), true)
			_line(ci, p, s, Vector2(0.55, 0.75), Vector2(0.55, -0.9), Color(0.8, 0.82, 0.88), 0.07)
			_line(ci, p, s, Vector2(0.35, 0.15), Vector2(0.75, 0.15), GOLD, 0.08)
		"striker":
			_line(ci, p, s, Vector2(0.25, 0.45), Vector2(1.0, -0.85), Color(0.9, 0.92, 0.95), 0.05)
			_circ(ci, p, s, Vector2(0.3, 0.35), 0.1, GOLD)
			_humanoid(ci, p, s, Color(0.25, 0.3, 0.6))
			_poly(ci, p, s, [Vector2(-0.5, -0.52), Vector2(0.5, -0.52), Vector2(0.3, -0.7), Vector2(-0.3, -0.7)], Color(0.15, 0.15, 0.25))
			_line(ci, p, s, Vector2(0.2, -0.68), Vector2(0.6, -1.05), Color(1.0, 0.3, 0.35), 0.1)
		"ranger":
			_humanoid(ci, p, s, Color(0.2, 0.55, 0.25))
			_poly(ci, p, s, [Vector2(-0.38, -0.3), Vector2(0.38, -0.3), Vector2(0.2, -0.62), Vector2(0.0, -0.95), Vector2(-0.2, -0.62)], Color(0.15, 0.45, 0.2))
			ci.draw_arc(p + Vector2(0.3, 0.1) * s, 0.65 * s, -1.2, 1.2, 14, Color(0.6, 0.38, 0.18), maxf(1.0, 0.08 * s), true)
			_line(ci, p, s, Vector2(0.3, 0.1) + Vector2.from_angle(-1.2) * 0.65, Vector2(0.3, 0.1) + Vector2.from_angle(1.2) * 0.65, Color(0.95, 0.95, 0.9), 0.03)
		"mystic":
			_humanoid(ci, p, s, Color(0.45, 0.7, 0.95))
			_pointed_hat(ci, p, s, Color(0.25, 0.45, 0.85))
			_snowflake(ci, p + Vector2(0.68, 0.05) * s, s * 0.32, Color(0.85, 0.97, 1.0))
		"support":
			_humanoid(ci, p, s, Color(0.95, 0.95, 0.92))
			_line(ci, p, s, Vector2(0, 0.1), Vector2(0, 0.7), GOLD, 0.12)
			_line(ci, p, s, Vector2(-0.2, 0.3), Vector2(0.2, 0.3), GOLD, 0.12)
			ci.draw_arc(p + Vector2(0, -0.75) * s, 0.25 * s, 0, TAU, 16, GOLD, maxf(1.0, 0.07 * s), true)
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

		# --- Vanguard family --------------------------------------------
		"bear":
			var fur := Color(0.45, 0.30, 0.18)
			_ellipse(ci, p, s, Vector2(0, 0.25), 0.62, 0.62, fur)
			_circ(ci, p, s, Vector2(-0.38, -0.68), 0.2, fur.darkened(0.15))
			_circ(ci, p, s, Vector2(0.38, -0.68), 0.2, fur.darkened(0.15))
			_circ(ci, p, s, Vector2(0, -0.35), 0.45, fur.lightened(0.08))
			_ellipse(ci, p, s, Vector2(0, -0.2), 0.22, 0.16, Color(0.85, 0.72, 0.55))
			_circ(ci, p, s, Vector2(0, -0.24), 0.07, DARK)
			_eyes(ci, p, s, Vector2(0, -0.45), 0.16)
			for x in [-0.5, -0.3, 0.3, 0.5]:
				_line(ci, p, s, Vector2(x, 0.7), Vector2(x * 1.1, 0.92), Color(0.9, 0.88, 0.8), 0.05)
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

		# --- Striker family --------------------------------------------
		"fox":
			var coat := Color(0.95, 0.48, 0.18)
			_poly(ci, p, s, [Vector2(-0.3, 0.55), Vector2(-1.05, 0.85), Vector2(-0.65, 0.15)], coat)
			_poly(ci, p, s, [Vector2(-0.45, -0.5), Vector2(-0.2, -0.95), Vector2(0.0, -0.45)], coat.darkened(0.1))
			_poly(ci, p, s, [Vector2(0.45, -0.5), Vector2(0.2, -0.95), Vector2(0.0, -0.45)], coat.darkened(0.1))
			_circ(ci, p, s, Vector2(0, -0.05), 0.62, coat)
			_ellipse(ci, p, s, Vector2(0, 0.25), 0.22, 0.16, Color(1.0, 0.95, 0.85))
			_circ(ci, p, s, Vector2(0, 0.18), 0.07, DARK)
			_eyes(ci, p, s, Vector2(0, -0.18), 0.2, DARK)
		"panther":
			var coat := Color(0.2, 0.18, 0.24)
			_poly(ci, p, s, [Vector2(-0.35, 0.5), Vector2(-1.0, 0.7), Vector2(-0.6, 0.1)], coat)
			_poly(ci, p, s, [Vector2(-0.42, -0.5), Vector2(-0.22, -0.9), Vector2(0.0, -0.45)], coat)
			_poly(ci, p, s, [Vector2(0.42, -0.5), Vector2(0.22, -0.9), Vector2(0.0, -0.45)], coat)
			_circ(ci, p, s, Vector2(0, -0.05), 0.62, coat)
			for v in [Vector2(-0.3, 0.15), Vector2(0.3, 0.2), Vector2(-0.15, -0.45), Vector2(0.25, -0.5)]:
				_circ(ci, p, s, v, 0.06, Color(0.45, 0.4, 0.5))
			_ellipse(ci, p, s, Vector2(0, 0.25), 0.2, 0.15, Color(0.75, 0.7, 0.8))
			_circ(ci, p, s, Vector2(0, 0.18), 0.06, DARK)
			_eyes(ci, p, s, Vector2(0, -0.18), 0.2, Color(1.0, 0.85, 0.2))
		"rabbit":
			var fur := Color(0.95, 0.95, 0.95)
			_ellipse(ci, p, s, Vector2(-0.22, -0.7), 0.14, 0.42, fur, -0.15)
			_ellipse(ci, p, s, Vector2(0.22, -0.7), 0.14, 0.42, fur, 0.15)
			_ellipse(ci, p, s, Vector2(-0.22, -0.7), 0.06, 0.3, Color(1.0, 0.7, 0.75), -0.15)
			_ellipse(ci, p, s, Vector2(0.22, -0.7), 0.06, 0.3, Color(1.0, 0.7, 0.75), 0.15)
			_circ(ci, p, s, Vector2(0, 0.15), 0.55, fur)
			_circ(ci, p, s, Vector2(0, 0.25), 0.08, Color(1.0, 0.55, 0.65))
			_eyes(ci, p, s, Vector2(0, 0.05), 0.2)

		# --- Ranger family ---------------------------------------------
		"hawk":
			var wing := Color(0.55, 0.36, 0.18)
			_poly(ci, p, s, [Vector2(-1.0, -0.25), Vector2(-0.2, -0.05), Vector2(-0.2, 0.35), Vector2(-0.75, 0.2)], wing)
			_poly(ci, p, s, [Vector2(1.0, -0.25), Vector2(0.2, -0.05), Vector2(0.2, 0.35), Vector2(0.75, 0.2)], wing)
			_ellipse(ci, p, s, Vector2(0, 0.2), 0.28, 0.52, Color(0.42, 0.27, 0.14))
			_circ(ci, p, s, Vector2(0, -0.45), 0.28, Color(0.75, 0.55, 0.3))
			_poly(ci, p, s, [Vector2(-0.1, -0.35), Vector2(0.1, -0.35), Vector2(0.0, -0.08)], Color(1.0, 0.8, 0.2))
			_eyes(ci, p, s, Vector2(0, -0.5), 0.12)
		"eagle":
			var wing := Color(0.45, 0.28, 0.15)
			_poly(ci, p, s, [Vector2(-1.05, -0.2), Vector2(-0.2, -0.1), Vector2(-0.2, 0.4), Vector2(-0.8, 0.25)], wing)
			_poly(ci, p, s, [Vector2(1.05, -0.2), Vector2(0.2, -0.1), Vector2(0.2, 0.4), Vector2(0.8, 0.25)], wing)
			_ellipse(ci, p, s, Vector2(0, 0.2), 0.3, 0.55, Color(0.4, 0.25, 0.12))
			_circ(ci, p, s, Vector2(0, -0.45), 0.3, Color(0.97, 0.97, 0.95))
			_poly(ci, p, s, [Vector2(-0.1, -0.35), Vector2(0.1, -0.35), Vector2(0.0, -0.1)], Color(1.0, 0.75, 0.1))
			_eyes(ci, p, s, Vector2(0, -0.52), 0.13)
		"phoenix":
			var wing := Color(0.95, 0.35, 0.12)
			_poly(ci, p, s, [Vector2(-1.05, -0.15), Vector2(-0.2, -0.05), Vector2(-0.2, 0.4), Vector2(-0.8, 0.3)], wing)
			_poly(ci, p, s, [Vector2(1.05, -0.15), Vector2(0.2, -0.05), Vector2(0.2, 0.4), Vector2(0.8, 0.3)], wing)
			_ellipse(ci, p, s, Vector2(0, 0.2), 0.3, 0.55, Color(0.85, 0.2, 0.1))
			_circ(ci, p, s, Vector2(0, -0.45), 0.3, Color(1.0, 0.6, 0.15))
			_flame(ci, p + Vector2(0, -0.75) * s, s * 0.45)
			_eyes(ci, p, s, Vector2(0, -0.52), 0.13, Color(1.0, 0.95, 0.5))

		# --- Mystic family ---------------------------------------------
		"raven":
			var feather := Color(0.12, 0.11, 0.16)
			_poly(ci, p, s, [Vector2(-0.95, -0.2), Vector2(-0.2, -0.05), Vector2(-0.2, 0.35), Vector2(-0.75, 0.2)], feather)
			_poly(ci, p, s, [Vector2(0.95, -0.2), Vector2(0.2, -0.05), Vector2(0.2, 0.35), Vector2(0.75, 0.2)], feather)
			_ellipse(ci, p, s, Vector2(0, 0.2), 0.28, 0.52, feather)
			_circ(ci, p, s, Vector2(0, -0.45), 0.28, feather.lightened(0.08))
			_poly(ci, p, s, [Vector2(-0.08, -0.35), Vector2(0.08, -0.35), Vector2(0.0, -0.1)], Color(0.2, 0.2, 0.25))
			_eyes(ci, p, s, Vector2(0, -0.5), 0.12, Color(0.75, 0.45, 1.0))
		"shadow_raven":
			var feather := Color(0.18, 0.08, 0.28)
			_poly(ci, p, s, [Vector2(-1.0, -0.25), Vector2(-0.2, -0.05), Vector2(-0.2, 0.4), Vector2(-0.8, 0.25)], feather)
			_poly(ci, p, s, [Vector2(1.0, -0.25), Vector2(0.2, -0.05), Vector2(0.2, 0.4), Vector2(0.8, 0.25)], feather)
			_ellipse(ci, p, s, Vector2(0, 0.2), 0.3, 0.55, feather.lightened(0.05))
			_circ(ci, p, s, Vector2(0, -0.45), 0.3, Color(0.3, 0.12, 0.45))
			_poly(ci, p, s, [Vector2(-0.09, -0.35), Vector2(0.09, -0.35), Vector2(0.0, -0.08)], Color(0.85, 0.55, 1.0))
			_eyes(ci, p, s, Vector2(0, -0.52), 0.13, Color(1.0, 0.35, 0.8))
		"owl":
			var feather := Color(0.42, 0.30, 0.20)
			_circ(ci, p, s, Vector2(0, 0.0), 0.68, feather)
			_circ(ci, p, s, Vector2(-0.35, 0.15), 0.3, feather.lightened(0.1))
			_circ(ci, p, s, Vector2(0.35, 0.15), 0.3, feather.lightened(0.1))
			_circ(ci, p, s, Vector2(-0.22, -0.2), 0.2, Color(1.0, 0.95, 0.75))
			_circ(ci, p, s, Vector2(0.22, -0.2), 0.2, Color(1.0, 0.95, 0.75))
			_circ(ci, p, s, Vector2(-0.22, -0.2), 0.09, DARK)
			_circ(ci, p, s, Vector2(0.22, -0.2), 0.09, DARK)
			_poly(ci, p, s, [Vector2(-0.08, -0.02), Vector2(0.08, -0.02), Vector2(0.0, 0.12)], Color(1.0, 0.7, 0.2))
			_poly(ci, p, s, [Vector2(-0.55, -0.55), Vector2(-0.35, -0.9), Vector2(-0.2, -0.5)], feather)
			_poly(ci, p, s, [Vector2(0.55, -0.55), Vector2(0.35, -0.9), Vector2(0.2, -0.5)], feather)

		# --- Support family --------------------------------------------
		"doe":
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
		"unicorn":
			var coat := Color(0.95, 0.93, 0.98)
			_ellipse(ci, p, s, Vector2(0, 0.25), 0.55, 0.55, coat)
			_circ(ci, p, s, Vector2(0, -0.35), 0.38, coat)
			_poly(ci, p, s, [Vector2(-0.12, -0.6), Vector2(0.12, -0.6), Vector2(0.0, -1.15)], GOLD)
			_poly(ci, p, s, [Vector2(-0.45, -0.45), Vector2(-0.2, -0.8), Vector2(0.0, -0.5)], Color(0.75, 0.55, 1.0))
			_poly(ci, p, s, [Vector2(0.45, -0.45), Vector2(0.2, -0.8), Vector2(0.0, -0.5)], Color(0.75, 0.55, 1.0))
			_eyes(ci, p, s, Vector2(0, -0.35), 0.16, Color(0.55, 0.35, 0.8))
		"songbird":
			var wing := Color(0.25, 0.55, 0.95)
			_poly(ci, p, s, [Vector2(-0.9, -0.15), Vector2(-0.2, 0.0), Vector2(-0.2, 0.35), Vector2(-0.7, 0.25)], wing)
			_poly(ci, p, s, [Vector2(0.9, -0.15), Vector2(0.2, 0.0), Vector2(0.2, 0.35), Vector2(0.7, 0.25)], wing)
			_ellipse(ci, p, s, Vector2(0, 0.2), 0.28, 0.5, Color(1.0, 0.82, 0.25))
			_circ(ci, p, s, Vector2(0, -0.4), 0.28, Color(1.0, 0.9, 0.35))
			_poly(ci, p, s, [Vector2(-0.08, -0.32), Vector2(0.08, -0.32), Vector2(0.0, -0.08)], Color(0.95, 0.45, 0.2))
			_eyes(ci, p, s, Vector2(0, -0.45), 0.12)
			_note(ci, p + Vector2(0.75, -0.55) * s, s * 0.25, Color(1.0, 0.75, 0.9))

		# --- Berserker family ------------------------------------------
		"boar":
			var fur := Color(0.45, 0.28, 0.18)
			_ellipse(ci, p, s, Vector2(0, 0.25), 0.7, 0.55, fur)
			_circ(ci, p, s, Vector2(0, -0.3), 0.42, fur.lightened(0.08))
			_poly(ci, p, s, [Vector2(-0.5, -0.45), Vector2(-0.25, -0.75), Vector2(-0.1, -0.4)], fur.darkened(0.2))
			_poly(ci, p, s, [Vector2(0.5, -0.45), Vector2(0.25, -0.75), Vector2(0.1, -0.4)], fur.darkened(0.2))
			_ellipse(ci, p, s, Vector2(0, -0.12), 0.24, 0.18, Color(0.75, 0.55, 0.4))
			_circ(ci, p, s, Vector2(-0.09, -0.12), 0.04, DARK)
			_circ(ci, p, s, Vector2(0.09, -0.12), 0.04, DARK)
			_poly(ci, p, s, [Vector2(-0.28, 0.0), Vector2(-0.14, 0.0), Vector2(-0.2, 0.28)], Color(0.95, 0.93, 0.85))
			_poly(ci, p, s, [Vector2(0.28, 0.0), Vector2(0.14, 0.0), Vector2(0.2, 0.28)], Color(0.95, 0.93, 0.85))
			_eyes(ci, p, s, Vector2(0, -0.42), 0.16, Color(1.0, 0.7, 0.2))
		"wolverine":
			var fur := Color(0.35, 0.28, 0.24)
			_ellipse(ci, p, s, Vector2(0, 0.25), 0.65, 0.55, fur)
			_circ(ci, p, s, Vector2(0, -0.3), 0.42, fur.lightened(0.1))
			_circ(ci, p, s, Vector2(-0.38, -0.6), 0.16, fur.darkened(0.15))
			_circ(ci, p, s, Vector2(0.38, -0.6), 0.16, fur.darkened(0.15))
			_ellipse(ci, p, s, Vector2(0, -0.15), 0.22, 0.16, Color(0.85, 0.8, 0.72))
			_circ(ci, p, s, Vector2(0, -0.18), 0.07, DARK)
			_eyes(ci, p, s, Vector2(0, -0.38), 0.17, Color(1.0, 0.8, 0.25))
			for x in [-0.55, -0.35, 0.35, 0.55]:
				_line(ci, p, s, Vector2(x, 0.65), Vector2(x * 1.1, 0.9), Color(0.9, 0.88, 0.8), 0.05)
		"badger":
			var fur := Color(0.22, 0.22, 0.24)
			_ellipse(ci, p, s, Vector2(0, 0.25), 0.68, 0.55, fur)
			_circ(ci, p, s, Vector2(0, -0.3), 0.44, fur)
			_poly(ci, p, s, [Vector2(-0.12, -0.72), Vector2(0.12, -0.72), Vector2(0.0, 0.05)], Color(0.95, 0.95, 0.95))
			_poly(ci, p, s, [Vector2(-0.5, -0.35), Vector2(-0.2, -0.62), Vector2(-0.35, -0.15)], Color(0.95, 0.95, 0.95))
			_poly(ci, p, s, [Vector2(0.5, -0.35), Vector2(0.2, -0.62), Vector2(0.35, -0.15)], Color(0.95, 0.95, 0.95))
			_ellipse(ci, p, s, Vector2(0, -0.12), 0.2, 0.14, Color(0.85, 0.8, 0.75))
			_circ(ci, p, s, Vector2(0, -0.15), 0.06, DARK)
			_eyes(ci, p, s, Vector2(0, -0.35), 0.17, DARK)
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


## Three family-coloured accent dots above the team ring. This is the main
## visual cue for "which archetype family did this creature come from?".
static func family_ring(ci: CanvasItem, p: Vector2, r: float, col: Color, t: float) -> void:
	for i in 3:
		var a := -PI / 2.0 + TAU * i / 3.0 + sin(t * 0.8) * 0.08
		ci.draw_circle(p + Vector2.from_angle(a) * r, 2.6, col)
		ci.draw_circle(p + Vector2.from_angle(a) * r, 1.2, col.lightened(0.35))


## Pulsing ring shown while the momentum combo window is open.
static func momentum_ring(ci: CanvasItem, p: Vector2, r: float, ratio: float, t: float) -> void:
	var pulse := 0.55 + 0.45 * sin(t * 9.0)
	var col := Color(1.0, 0.72, 0.2, 0.75 * pulse)
	var segs := 12
	for i in segs:
		var a := t * 1.5 + TAU * i / segs
		ci.draw_arc(p, r, a, a + TAU / segs * 0.45, 4, col, 2.2, true)
	ci.draw_arc(p, r + 3.0, -PI / 2.0, -PI / 2.0 + TAU * ratio, 24, Color(1.0, 0.85, 0.35, 0.9), 2.0, true)


## Brief shimmer after a transformation, indicating the projectile-dodge window.
static func dodge_shimmer(ci: CanvasItem, p: Vector2, r: float, ratio: float) -> void:
	var col := Color(0.75, 0.9, 1.0, 0.65 * ratio)
	ci.draw_arc(p, r + 2.0, 0.0, TAU, 24, col, 2.0, true)
	for i in 4:
		var a := TAU * i / 4.0 + ratio * 2.0
		ci.draw_circle(p + Vector2.from_angle(a) * (r + 7.0), 2.0, col)


## One-use animal special indicator.
## Ready: bright rune. Used: dim check. The small chevron marks an unlocked upgrade.
static func special_rune(ci: CanvasItem, p: Vector2, r: float, col: Color, used: bool, upgrade_ready: bool) -> void:
	ci.draw_circle(p, r + 1.0, Color(0.08, 0.06, 0.1, 0.9))
	if used:
		ci.draw_arc(p, r, 0, TAU, 16, col.darkened(0.35), 1.5, true)
		ci.draw_line(p + Vector2(-r * 0.5, 0), p + Vector2(-r * 0.1, r * 0.4), col.darkened(0.2), 2.0, true)
		ci.draw_line(p + Vector2(-r * 0.1, r * 0.4), p + Vector2(r * 0.55, -r * 0.4), col.darkened(0.2), 2.0, true)
	else:
		ci.draw_arc(p, r, 0, TAU, 16, col, 1.5, true)
		star(ci, p, r * 0.65, col)
	if upgrade_ready:
		ci.draw_polyline(PackedVector2Array([
			p + Vector2(-r * 0.45, -r * 1.35),
			p + Vector2(0, -r * 1.75),
			p + Vector2(r * 0.45, -r * 1.35),
		]), Color(1.0, 0.9, 0.45), 2.0, true)


## Attack windup telegraph. The shape follows the form's attack style so the
## player can read which attack is about to land and when it is interruptible.
static func windup_telegraph(ci: CanvasItem, style: String, p: Vector2, r: float, dir: Vector2, progress: float, col: Color) -> void:
	var d := dir if dir != Vector2.ZERO else Vector2.RIGHT
	var c := col.lerp(Color.WHITE, 0.35)
	c.a = 0.35 + 0.55 * progress
	var reach := r + 8.0 + 10.0 * progress
	match style:
		"thrust":
			ci.draw_line(p + d * (r + 2.0), p + d * reach, c, 3.0, true)
			ci.draw_arc(p + d * reach, 4.0 + 3.0 * progress, 0, TAU, 12, c, 2.0, true)
		"slash":
			var a := d.angle()
			ci.draw_arc(p, r + 9.0, a - 0.9, a + 0.9 * progress, 12, c, 3.0, true)
		"smash":
			ci.draw_line(p + d * (r + 2.0), p + d * reach, c, 4.0, true)
			ci.draw_arc(p + d * reach, 8.0 + 5.0 * progress, 0, TAU, 12, c, 2.5, true)
		"bite":
			ci.draw_line(p + d * (r + 2.0) + d.orthogonal() * 5.0, p + d * reach, c, 2.5, true)
			ci.draw_line(p + d * (r + 2.0) - d.orthogonal() * 5.0, p + d * reach, c, 2.5, true)
		"bow":
			var a := d.angle()
			ci.draw_arc(p, r + 12.0, a - 1.0, a + 1.0, 14, c, 2.5, true)
			ci.draw_line(p + d * (r + 2.0), p + d * reach, Color(0.95, 0.95, 0.9, c.a), 1.5, true)
		"cast":
			ci.draw_arc(p, r + 6.0 + 8.0 * progress, 0, TAU, 20, c, 2.0, true)
			star(ci, p + d * (r + 6.0), 4.0 + 4.0 * progress, c)
		"support":
			var q := p + Vector2(0, -r - 10.0)
			ci.draw_line(q + Vector2(-6, 0), q + Vector2(6, 0), c, 2.5, true)
			ci.draw_line(q + Vector2(0, -6), q + Vector2(0, 6), c, 2.5, true)
		_:
			ci.draw_line(p + d * (r + 2.0), p + d * reach, c, 3.0, true)


## Strike flash at the moment the attack resolves.
static func attack_strike(ci: CanvasItem, style: String, p: Vector2, r: float, dir: Vector2, progress: float, col: Color) -> void:
	var d := dir if dir != Vector2.ZERO else Vector2.RIGHT
	var c := col.lerp(Color.WHITE, 0.55)
	c.a = 1.0 - progress
	match style:
		"slash":
			ci.draw_arc(p, r + 12.0, d.angle() - 1.1, d.angle() + 1.1, 14, c, 3.0, true)
		"smash":
			ci.draw_circle(p + d * (r + 10.0), 6.0 + 12.0 * progress, c)
		"cast", "support":
			star(ci, p + d * (r + 6.0), 5.0 + 8.0 * progress, c)
		_:
			ci.draw_line(p + d * (r + 2.0), p + d * (r + 18.0), c, 3.0, true)


## Full token used outside combat (prep board, reserve, shop, tooltip).
static func token(ci: CanvasItem, id: String, p: Vector2, r: float, team: int, highlight := false) -> void:
	team_base(ci, p, r, team, highlight)
	family_ring(ci, p, r + 3.0, CreatureDB.family_color(id), 0.0)
	creature(ci, id, p, r * 0.92)


# --- Combat overlays ----------------------------------------------------------

static func health_bar(ci: CanvasItem, pos: Vector2, w: float, ratio: float, team: int) -> void:
	ci.draw_rect(Rect2(pos, Vector2(w, 6)), Color(0, 0, 0, 0.7))
	ci.draw_rect(Rect2(pos + Vector2(1, 1), Vector2((w - 2) * clampf(ratio, 0, 1), 4)), team_color(team).lightened(0.25))


static func star(ci: CanvasItem, p: Vector2, r: float, col := GOLD) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + TAU * i / 10.0
		pts.append(p + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.45))
	ci.draw_colored_polygon(pts, col)


static func level_stars(ci: CanvasItem, center: Vector2, count: int) -> void:
	var shown := mini(count, 5)
	for i in shown:
		star(ci, center + Vector2((i - (shown - 1) * 0.5) * 11.0, 0), 6.0)
	if count > 5:
		ci.draw_circle(center + Vector2(shown * 6.0 + 6.0, 0), 3.0, GOLD)


static func padlock(ci: CanvasItem, p: Vector2) -> void:
	ci.draw_arc(p + Vector2(0, -4), 6, PI, TAU, 12, GOLD, 3.0, true)
	ci.draw_rect(Rect2(p + Vector2(-8, -4), Vector2(16, 13)), GOLD)
	ci.draw_circle(p + Vector2(0, 1), 2, DARK)


static func immunity_ring(ci: CanvasItem, p: Vector2, r: float, ratio: float, t: float) -> void:
	var segs := 10
	for i in segs:
		var a := t * 2.0 + TAU * i / segs
		ci.draw_arc(p, r, a, a + TAU / segs * 0.5, 4, Color(1, 1, 1, 0.75), 2.5, true)
	ci.draw_arc(p, r + 4.0, -PI / 2, -PI / 2 + TAU * ratio, 24, MAGIC, 3.0, true)


## Small status pip: negative effects use a dark red rim, positive a green rim.
static func status(ci: CanvasItem, key: String, p: Vector2, r: float) -> void:
	var good := key in ["inspired", "regen", "guarded", "momentum", "retaliate"]
	ci.draw_circle(p, r + 1.5, Color(0.1, 0.5, 0.15) if good else Color(0.55, 0.05, 0.05))
	ci.draw_circle(p, r, Color(0.08, 0.08, 0.1))
	match key:
		"poisoned":
			ci.draw_circle(p + Vector2(0, 1.5), r * 0.55, Color(0.5, 1.0, 0.3))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.5, 1.0), p + Vector2(r * 0.5, 1.0), p + Vector2(0, -r * 0.8)]), Color(0.5, 1.0, 0.3))
		"chilled":
			_snowflake(ci, p, r * 0.8, Color(0.7, 0.9, 1.0))
		"exposed":
			ci.draw_rect(Rect2(p - Vector2(r * 0.5, r * 0.6), Vector2(r, r * 1.2)), Color(0.75, 0.75, 0.8))
			ci.draw_line(p + Vector2(-r * 0.6, -r * 0.6), p + Vector2(r * 0.6, r * 0.6), Color(1, 0.3, 0.3), 2.0)
		"dazzled":
			ci.draw_arc(p, r * 0.6, 0, TAU, 10, Color(0.4, 0.6, 1.0), 2.0)
			ci.draw_circle(p, r * 0.25, GOLD)
		"inspired":
			_note(ci, p, r * 0.9, GOLD)
		"regen":
			ci.draw_line(p + Vector2(-r * 0.6, 0), p + Vector2(r * 0.6, 0), Color(0.5, 1.0, 0.5), 2.5)
			ci.draw_line(p + Vector2(0, -r * 0.6), p + Vector2(0, r * 0.6), Color(0.5, 1.0, 0.5), 2.5)
		"guarded":
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.7, -r * 0.7), p + Vector2(r * 0.7, -r * 0.7), p + Vector2(r * 0.7, 0), p + Vector2(0, r * 0.8), p + Vector2(-r * 0.7, 0)]), Color(0.55, 0.75, 1.0))
		"momentum":
			for i in 2:
				var dx := (i - 0.5) * r * 0.9
				ci.draw_polyline(PackedVector2Array([p + Vector2(dx - r * 0.3, -r * 0.6), p + Vector2(dx + r * 0.3, 0), p + Vector2(dx - r * 0.3, r * 0.6)]), Color(1.0, 0.75, 0.2), 2.0, true)
		"retaliate":
			for i in 3:
				var a := -PI / 2.0 + TAU * i / 3.0
				ci.draw_line(p, p + Vector2.from_angle(a) * r * 0.8, Color(0.85, 0.9, 1.0), 2.0, true)
			ci.draw_circle(p, r * 0.22, Color(1.0, 0.45, 0.3))
		"pack":
			ci.draw_circle(p + Vector2(-r * 0.3, 0), r * 0.35, Color(0.8, 0.8, 0.85))
			ci.draw_circle(p + Vector2(r * 0.3, 0), r * 0.35, Color(0.8, 0.8, 0.85))


static func _note(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(p + Vector2(-r * 0.3, r * 0.45), r * 0.35, col)
	ci.draw_line(p + Vector2(r * 0.02, r * 0.45), p + Vector2(r * 0.02, -r * 0.7), col, 2.0)
	ci.draw_line(p + Vector2(r * 0.02, -r * 0.7), p + Vector2(r * 0.6, -r * 0.4), col, 2.0)


static func projectile(ci: CanvasItem, kind: String, p: Vector2, dir: Vector2) -> void:
	match kind:
		"arrow":
			ci.draw_line(p - dir * 12.0, p, Color(0.85, 0.7, 0.45), 2.5, true)
			ci.draw_circle(p, 2.5, Color(0.9, 0.9, 0.95))
		"feather":
			ci.draw_line(p - dir * 10.0, p, Color(0.85, 0.65, 0.35), 2.0, true)
			ci.draw_colored_polygon(PackedVector2Array([p, p - dir * 8.0 + dir.orthogonal() * 3.0, p - dir * 12.0, p - dir * 8.0 - dir.orthogonal() * 3.0]), Color(0.95, 0.85, 0.6))
		"bolt":
			ci.draw_line(p - dir * 10.0, p, Color(0.35, 0.3, 0.3), 4.5, true)
			ci.draw_circle(p, 3.5, Color(0.9, 0.9, 0.95))
		"fire":
			ci.draw_circle(p - dir * 6.0, 5.0, Color(1.0, 0.4, 0.1, 0.5))
			ci.draw_circle(p, 6.5, Color(1.0, 0.5, 0.1))
			ci.draw_circle(p, 3.5, Color(1.0, 0.95, 0.4))
		"frost":
			_snowflake(ci, p, 6.0, Color(0.75, 0.95, 1.0))
		"shadow":
			ci.draw_circle(p - dir * 5.0, 6.0, Color(0.35, 0.1, 0.55, 0.45))
			ci.draw_circle(p, 5.5, Color(0.35, 0.12, 0.55))
			ci.draw_circle(p, 2.5, Color(0.85, 0.45, 1.0))
		"moon":
			ci.draw_circle(p, 5.5, Color(0.75, 0.8, 1.0))
			ci.draw_circle(p + dir * 2.5, 4.5, Color(0.25, 0.2, 0.4))
		"holy":
			ci.draw_circle(p, 5.0, Color(1.0, 0.95, 0.6))
		"note":
			_note(ci, p, 7.0, Color(1.0, 0.6, 0.9))
		_:
			ci.draw_circle(p, 4.0, Color.WHITE)


# --- Interface icons -------------------------------------------------------------

static func heart(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(p + Vector2(-r * 0.45, -r * 0.2), r * 0.5, col)
	ci.draw_circle(p + Vector2(r * 0.45, -r * 0.2), r * 0.5, col)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.93, 0.0), p + Vector2(r * 0.93, 0.0), p + Vector2(0, r * 0.95)]), col)


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


static func wand(ci: CanvasItem, p: Vector2, r: float, crossed: bool) -> void:
	ci.draw_line(p + Vector2(-r * 0.7, r * 0.7), p + Vector2(r * 0.4, -r * 0.4), Color(0.55, 0.35, 0.2), r * 0.18, true)
	star(ci, p + Vector2(r * 0.5, -r * 0.5), r * 0.42, MAGIC.lightened(0.3))
	if crossed:
		ci.draw_arc(p, r, 0, TAU, 24, Color(1, 0.3, 0.3), r * 0.14, true)
		ci.draw_line(p + Vector2(-r * 0.7, -r * 0.7), p + Vector2(r * 0.7, r * 0.7), Color(1, 0.3, 0.3), r * 0.14, true)


static func fast_forward(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	for dx in [-r * 0.5, r * 0.35]:
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(dx - r * 0.4, -r * 0.6), p + Vector2(dx + r * 0.45, 0), p + Vector2(dx - r * 0.4, r * 0.6)]), col)


## Momentum chevrons used by the experimental toggle.
static func momentum_icon(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	for i in 2:
		var dx := (i - 0.5) * r * 1.0
		ci.draw_polyline(PackedVector2Array([
			p + Vector2(dx - r * 0.45, -r * 0.7),
			p + Vector2(dx + r * 0.35, 0),
			p + Vector2(dx - r * 0.45, r * 0.7),
		]), col, maxf(1.5, r * 0.22), true)


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


## Arrow used by the hover card to point from the current form to its ladder.
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
