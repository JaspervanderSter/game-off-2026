class_name OpponentArt
extends RefCounted
## Full-length journey opponents (docs/design/prototype_02/Journey and
## Opponents.md), drawn with flat shapes like the creatures. Each drawing uses a
## 100 x 120 design space whose point (50, 65) lands on p; s is half the width
## of that space, so a figure is about 2.1 s tall. The apprentice, adept and
## archmage wear the existing difficulty hats (Icons.difficulty_hat).

const SKIN := Color("fad1a8")
const INK := Color("1a1414")
const GOLD := Color("e3b23c")

static var _ci: CanvasItem
static var _p := Vector2.ZERO
static var _s := 1.0


static func draw(ci: CanvasItem, id: String, p: Vector2, s: float, t: float) -> void:
	_ci = ci
	_p = p
	_s = s
	_ell(50, 112, 28, 5, Color(0, 0, 0, 0.2))
	match id:
		"hunter": _hunter()
		"lumberjack": _lumberjack()
		"druid": _druid()
		"swamp_witch": _swamp_witch(t)
		"archdruid": _archdruid(t)
		"merchant": _merchant()
		"innkeeper": _innkeeper()
		"thief": _thief()
		"court_mage": _court_mage(t)
		"king": _king()
		"apprentice": _apprentice(t)
		"caretaker": _caretaker()
		"adept": _adept(t)
		"transmutation_teacher": _teacher(t)
		"archmage": _archmage(t)
	_ci = null


# --- Design-space helpers ---------------------------------------------------------

static func _v(x: float, y: float) -> Vector2:
	return _p + Vector2((x - 50.0) / 50.0, (y - 65.0) / 50.0) * _s


static func _k(r: float) -> float:
	return r / 50.0 * _s


## Filled polygon from flat design coordinates [x0, y0, x1, y1, ...].
static func _poly(flat: Array, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(0, flat.size(), 2):
		pts.append(_v(flat[i], flat[i + 1]))
	_ci.draw_colored_polygon(pts, col)


## Quadratic curve points (flat), start included, end included.
static func _q(x0: float, y0: float, cx: float, cy: float, x1: float, y1: float, steps := 8) -> Array:
	var out := []
	for i in steps + 1:
		var k := float(i) / steps
		var a := Vector2(x0, y0).lerp(Vector2(cx, cy), k)
		var b := Vector2(cx, cy).lerp(Vector2(x1, y1), k)
		var q := a.lerp(b, k)
		out.append_array([q.x, q.y])
	return out


static func _stroke(flat: Array, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in range(0, flat.size(), 2):
		pts.append(_v(flat[i], flat[i + 1]))
	Shapes.polyline(_ci, pts, col, maxf(1.0, _k(w)), true)


static func _circ(x: float, y: float, r: float, col: Color) -> void:
	Shapes.circle(_ci, _v(x, y), _k(r), col)


static func _ring(x: float, y: float, r: float, col: Color, w: float) -> void:
	Shapes.arc(_ci, _v(x, y), _k(r), 0, TAU, 24, col, maxf(1.0, _k(w)), true)


static func _ell(x: float, y: float, rx: float, ry: float, col: Color, degrees := 0.0) -> void:
	Shapes.ellipse(_ci, _v(x, y), _k(rx), _k(ry), col, deg_to_rad(degrees))


static func _seg(x0: float, y0: float, x1: float, y1: float, col: Color, w: float) -> void:
	Shapes.line(_ci, _v(x0, y0), _v(x1, y1), col, maxf(1.0, _k(w)), true)


static func _rect(x: float, y: float, w: float, h: float, col: Color) -> void:
	_poly([x, y, x + w, y, x + w, y + h, x, y + h], col)


static func _robe(col: Color, half_top := 14.0, half_bottom := 24.0, top := 62.0) -> void:
	_poly([50 - half_bottom, 110, 50 + half_bottom, 110, 50 + half_top, top, 50 - half_top, top], col)


static func _head(y := 50.0, r := 14.0, skin := SKIN) -> void:
	_circ(50, y, r, skin)


static func _eyes(y: float, col := INK, r := 2.0) -> void:
	_circ(45, y, r, col)
	_circ(55, y, r, col)


## Upper half-disc (scarves, caps).
static func _dome(x: float, y: float, r: float, col: Color) -> void:
	var flat := []
	for i in 13:
		var a := PI + PI * i / 12.0
		flat.append_array([x + cos(a) * r, y + sin(a) * r])
	_poly(flat, col)


## One of the three difficulty hats, its brim centred on design point (50, 42).
static func _difficulty_hat(level: int, t: float) -> void:
	var r := _k(21)
	Icons.difficulty_hat(_ci, level, _v(50, 42) - Vector2(0, 0.52 * r), r, t)


# --- Forest --------------------------------------------------------------------------

static func _hunter() -> void:
	_stroke(_q(76, 36, 95, 74, 76, 110), Color("7a4a22"), 3)
	_seg(76, 36, 76, 110, Color("f3eedc"), 0.8)
	_seg(30, 74, 22, 44, Color("6b4a2a"), 2)
	_seg(33, 74, 27, 42, Color("6b4a2a"), 2)
	_poly([20, 46, 24, 40, 25, 47], Color("c8402e"))
	_poly([25, 44, 29, 38, 30, 45], Color("c8402e"))
	_robe(Color("6b7f3a"), 14, 24, 64)
	_rect(31, 84, 38, 4, Color("4a3218"))
	_poly([58, 88, 64, 89, 66, 94, 64, 98, 60, 97, 61, 93], Color("eadbb8"))
	_head()
	_eyes(51)
	_poly([34, 45, 66, 45, 62, 32, 46, 30, 38, 34], Color("7a5230"))
	_rect(33, 43, 34, 3, Color("5a3a20"))
	_poly(_q(60, 34, 72, 20, 82, 13) + _q(82, 13, 74, 28, 62, 39), Color("c8402e"))


static func _lumberjack() -> void:
	_seg(72, 108, 82, 38, Color("8b5a2b"), 4)
	_poly([78, 40, 95, 32, 97, 54, 81, 50], Color("b9c0c8"))
	_robe(Color("b53b2e"), 14, 24, 64)
	var check := Color(0, 0, 0, 0.22)
	_seg(44, 64, 40, 110, check, 3)
	_seg(56, 64, 60, 110, check, 3)
	_seg(32, 82, 68, 82, check, 3)
	_seg(29, 98, 71, 98, check, 3)
	_ell(34.5, 60, 3.5, 14, Color("d9893a"))
	_ell(65.5, 60, 3.5, 14, Color("d9893a"))
	_head()
	_ell(50, 40, 15, 8, Color("d9893a"))
	_eyes(52)
	_circ(42, 57, 2.5, Color(0.94, 0.58, 0.58, 0.7))
	_circ(58, 57, 2.5, Color(0.94, 0.58, 0.58, 0.7))


static func _druid() -> void:
	_seg(22, 110, 24, 30, Color("6b4a2a"), 4)
	_circ(24, 28, 7, Color(0.85, 1.0, 0.69, 0.6))
	_ell(19, 31, 5, 2.5, Color("5fa03a"), -30)
	_ell(29, 31, 5, 2.5, Color("5fa03a"), 30)
	_circ(50, 50, 19, Color("3e6a3a"))
	_robe(Color("4e7d4a"))
	_head()
	_poly(_q(37, 54, 50, 84, 63, 54), Color("f2f2ea"))
	_eyes(49)
	for leaf in [[38, 40, -40, "6fb34a"], [44, 36, -15, "7cc255"], [50, 35, 0, "6fb34a"], [56, 36, 15, "7cc255"], [62, 40, 40, "6fb34a"]]:
		_ell(leaf[0], leaf[1], 5, 3, Color(leaf[3]), leaf[2])


static func _swamp_witch(t: float) -> void:
	_retained_swamp_witch_0(t)
	_retained_swamp_witch_1(t)
	_retained_swamp_witch_2(t)


static func _archdruid(t: float) -> void:
	_retained_archdruid_0(t)
	_retained_archdruid_1(t)


# --- Town ----------------------------------------------------------------------------

static func _merchant() -> void:
	_robe(Color("3f6fa0"), 14, 24, 64)
	_poly([38, 76, 62, 76, 66, 110, 34, 110], Color("f1eadb"))
	_circ(74, 82, 8, Color("f2c94c"))
	_ring(74, 82, 8, Color("b8892a"), 1.5)
	_ring(74, 82, 3, Color("b8892a"), 1)
	_ell(34, 86, 6, 7, Color("8a5a3a"))
	_head()
	_eyes(52)
	_stroke(_q(45, 58, 50, 61, 55, 58), INK, 1.2)
	_dome(50, 47, 15.5, Color("d9a23a"))
	_poly([64, 46, 74, 42, 70, 52], Color("c28a2a"))


static func _innkeeper() -> void:
	_robe(Color("8a5a3a"), 18, 30, 64)
	_poly([34, 74, 66, 74, 72, 110, 28, 110], Color("efe6d2"))
	_rect(72, 70, 13, 17, Color("c98a3a"))
	_stroke(_q(85, 74, 91, 78, 85, 83), Color("c98a3a"), 2.5)
	_ell(78.5, 70, 8, 4, Color("fffdf3"))
	_head(50, 15)
	_eyes(48)
	_poly(_q(40, 56, 45, 52, 50, 56) + _q(50, 56, 55, 52, 60, 56) + _q(60, 56, 55, 60, 50, 57) + _q(50, 57, 45, 60, 40, 56), Color("6a3e22"))
	_circ(40, 52, 3, Color(0.94, 0.58, 0.58, 0.7))
	_circ(60, 52, 3, Color(0.94, 0.58, 0.58, 0.7))


static func _thief() -> void:
	_poly(_q(33, 58, 33, 26, 50, 25) + _q(50, 25, 67, 26, 67, 58), Color("2f3a48"))
	_robe(Color("3f4a5a"), 14, 26, 60)
	_poly([22, 86, 30, 84, 18, 76], Color("d5dae0"))
	_rect(24, 84, 7, 4, Color("5a3a20"))
	_ell(74, 90, 8, 9, Color("9a6a40"))
	_circ(74, 81, 3.5, Color("f2c94c"))
	_head(51, 12)
	_rect(38, 46, 24, 6, Color("1a1a1e"))
	_circ(45, 49, 1.6, SKIN)
	_circ(55, 49, 1.6, SKIN)
	_stroke(_q(44, 56, 50, 60, 56, 55), INK, 1.3)


static func _court_mage(t: float) -> void:
	_retained_court_mage_0(t)
	_retained_court_mage_1(t)
	_retained_court_mage_2(t)


static func _king() -> void:
	_robe(Color("a82a2a"), 18, 32, 62)
	_rect(42, 66, 16, 44, GOLD)
	_ell(50, 65, 21, 6, Color("fbf8f0"))
	for x in [40, 50, 60]:
		_circ(x, 65 + (2 if x == 50 else 0), 1.2, INK)
	_seg(80, 108, 80, 46, GOLD, 3)
	_circ(80, 42, 5, Color("f2c94c"))
	_circ(80, 42, 2, Color("d03040"))
	_head()
	_poly(_q(37, 52, 50, 76, 63, 52) + _q(63, 52, 50, 60, 37, 52), Color("7a4a2a"))
	_eyes(49)
	_poly([36, 40, 64, 40, 64, 26, 58, 33, 50, 22, 42, 33, 36, 26], Color("f2c94c"))
	_circ(50, 35, 2.5, Color("d03040"))


# --- School --------------------------------------------------------------------------

static func _apprentice(t: float) -> void:
	_retained_apprentice_0(t)
	_retained_apprentice_1(t)
	_retained_apprentice_2(t)
	_retained_apprentice_3(t)


static func _caretaker() -> void:
	_seg(78, 30, 74, 98, Color("8b5a2b"), 3)
	_poly([66, 96, 82, 96, 86, 114, 62, 114], Color("d9b45a"))
	_robe(Color("5e7186"), 14, 24, 64)
	_rect(41, 64, 18, 16, Color("7d90a6"))
	_ring(34, 90, 5, GOLD, 1.5)
	_seg(31, 94, 29, 100, GOLD, 1.5)
	_seg(36, 95, 37, 101, GOLD, 1.5)
	_head(51)
	_circ(37, 52, 3.5, Color("c9c9c4"))
	_circ(63, 52, 3.5, Color("c9c9c4"))
	_eyes(50)
	_poly(_q(40, 57, 50, 52, 60, 57) + _q(60, 57, 50, 60, 40, 57), Color("c9c9c4"))
	_poly(_q(35, 45, 36, 34, 50, 34) + _q(50, 34, 64, 34, 65, 45), Color("4a4a4a"))
	_ell(60, 45, 10, 2.5, Color("3a3a3a"))


static func _adept(t: float) -> void:
	_retained_adept_0(t)
	_retained_adept_1(t)
	_retained_adept_2(t)
	_retained_adept_3(t)


static func _teacher(t: float) -> void:
	_retained_teacher_0(t)
	_retained_teacher_1(t)
	_retained_teacher_2(t)


static func _archmage(t: float) -> void:
	_retained_archmage_0(t)
	_retained_archmage_1(t)
	_retained_archmage_2(t)
	_retained_archmage_3(t)


## Retained map portraits keep static sections in their original depth order.
static func build_retained(parent: Node2D, id: String, clock: Callable) -> Array[Node2D]:
	var animated: Array[Node2D] = []
	_retained_section(parent, clock, func(_t: float): _ell(50, 112, 28, 5, Color(0, 0, 0, 0.2)))
	match id:
		"hunter":
			_retained_section(parent, clock, func(_t: float): _hunter())
		"lumberjack":
			_retained_section(parent, clock, func(_t: float): _lumberjack())
		"druid":
			_retained_section(parent, clock, func(_t: float): _druid())
		"swamp_witch":
			_retained_section(parent, clock, _retained_swamp_witch_0)
			animated.append(_retained_section(parent, clock, _retained_swamp_witch_1))
			_retained_section(parent, clock, _retained_swamp_witch_2)
		"archdruid":
			animated.append(_retained_section(parent, clock, _retained_archdruid_0))
			_retained_section(parent, clock, _retained_archdruid_1)
		"merchant":
			_retained_section(parent, clock, func(_t: float): _merchant())
		"innkeeper":
			_retained_section(parent, clock, func(_t: float): _innkeeper())
		"thief":
			_retained_section(parent, clock, func(_t: float): _thief())
		"court_mage":
			_retained_section(parent, clock, _retained_court_mage_0)
			animated.append(_retained_section(parent, clock, _retained_court_mage_1))
			_retained_section(parent, clock, _retained_court_mage_2)
		"king":
			_retained_section(parent, clock, func(_t: float): _king())
		"apprentice":
			_retained_section(parent, clock, _retained_apprentice_0)
			animated.append(_retained_section(parent, clock, _retained_apprentice_1))
			_retained_section(parent, clock, _retained_apprentice_2)
			animated.append(_retained_section(parent, clock, _retained_apprentice_3))
		"caretaker":
			_retained_section(parent, clock, func(_t: float): _caretaker())
		"adept":
			_retained_section(parent, clock, _retained_adept_0)
			animated.append(_retained_section(parent, clock, _retained_adept_1))
			_retained_section(parent, clock, _retained_adept_2)
			animated.append(_retained_section(parent, clock, _retained_adept_3))
		"transmutation_teacher":
			_retained_section(parent, clock, _retained_teacher_0)
			animated.append(_retained_section(parent, clock, _retained_teacher_1))
			_retained_section(parent, clock, _retained_teacher_2)
		"archmage":
			_retained_section(parent, clock, _retained_archmage_0)
			animated.append(_retained_section(parent, clock, _retained_archmage_1))
			_retained_section(parent, clock, _retained_archmage_2)
			animated.append(_retained_section(parent, clock, _retained_archmage_3))
	return animated


static func _retained_section(parent: Node2D, clock: Callable, painter: Callable) -> Node2D:
	return preload("res://scripts/ui/retained_drawing.gd").make(parent, func(canvas: Node2D):
		_ci = canvas
		_p = Vector2.ZERO
		_s = 27.0
		painter.call(clock.call())
		_ci = null
	)

static func _retained_swamp_witch_0(_t: float) -> void:
	_poly([24, 110, 30, 104, 36, 110, 42, 104, 48, 110, 54, 104, 60, 110, 66, 104, 72, 110, 76, 110, 64, 64, 36, 64], Color("2e4a45"))
	_rect(72, 80, 8, 12, Color("7cd04a"))
	_rect(74, 76, 4, 5, Color("7a5230"))

static func _retained_swamp_witch_1(t: float) -> void:
	_circ(76, 72, 4 + sin(t * 3.0) * 0.6, Color(0.78, 1.0, 0.54, 0.55))

static func _retained_swamp_witch_2(_t: float) -> void:
	_stroke(_q(36, 70, 43, 63, 50, 70) + _q(50, 70, 57, 77, 64, 70), Color("5fa03a"), 4)
	_circ(65, 69, 3, Color("5fa03a"))
	_seg(37, 50, 35, 70, Color("1f2420"), 2.5)
	_seg(63, 50, 66, 68, Color("1f2420"), 2.5)
	_head(51, 14, Color("c8d9a2"))
	_eyes(51)
	_poly([50, 52, 59, 57, 50, 58], Color("a9bf80"))
	_poly([38, 41, 62, 41, 57, 26, 68, 13, 52, 21, 44, 28], Color("25332f"))
	_ell(50, 41, 23, 4, Color("1f2e2a"))
	var cap := []
	for i in 9:
		var a := PI + PI * i / 8.0
		cap.append_array([63 + cos(a) * 5, 38 + sin(a) * 4])
	_poly(cap, Color("d04030"))
	_circ(61, 36.5, 0.9, Color.WHITE)
	_circ(65, 36, 0.9, Color.WHITE)

static func _retained_archdruid_0(t: float) -> void:
	var pulse := 1.0 + sin(t * 1.6) * 0.03
	_circ(50, 62, 46 * pulse, Color(0.85, 1.0, 0.69, 0.18))
	_circ(50, 62, 36 * pulse, Color(0.85, 1.0, 0.69, 0.18))

static func _retained_archdruid_1(_t: float) -> void:
	_robe(Color("5b4632"), 16, 30, 60)
	_ell(37, 64, 7, 4, Color("6fa046"))
	_ell(60, 90, 6, 3, Color("6fa046"))
	_ell(36, 100, 5, 3, Color("6fa046"))
	_head(50, 14, Color("e8c49a"))
	_poly(_q(37, 54, 50, 98, 63, 54), Color("b8c9a0"))
	_eyes(49, Color("c6ff8a"), 2.4)
	var antler := Color("eadbb8")
	for side in [-1, 1]:
		_seg(50 - 8 * side, 38, 50 - 16 * side, 18, antler, 3)
		_seg(50 - 12 * side, 28, 50 - 23 * side, 25, antler, 3)
		_seg(50 - 14 * side, 22, 50 - 11 * side, 12, antler, 3)
	_ell(73, 56, 6, 8, Color("8a6a4a"))
	_circ(71, 53, 2.3, Color.WHITE)
	_circ(75.5, 53, 2.3, Color.WHITE)
	_circ(71, 53, 1, INK)
	_circ(75.5, 53, 1, INK)

static func _retained_court_mage_0(_t: float) -> void:
	_robe(Color("8e1f3a"))
	_rect(27, 104, 46, 4, GOLD)
	_seg(48, 64, 48, 104, GOLD, 2)
	_seg(72, 90, 84, 66, Color("2a1e14"), 2.5)

static func _retained_court_mage_1(t: float) -> void:
	var flicker := 1.0 + sin(t * 9.0) * 0.12
	_circ(85, 62, 5 * flicker, Color("ff8a3a"))

static func _retained_court_mage_2(_t: float) -> void:
	_circ(85, 62, 2.4, Color("ffe08a"))
	_circ(78, 56, 2.6, Color("9fd8ff"))
	_circ(91, 54, 2, Color("9fd8ff"))
	_head(51)
	_eyes(50)
	_seg(43, 46, 48, 47.5, INK, 1.2)
	_seg(57, 46, 52, 47.5, INK, 1.2)
	_poly([46, 59, 54, 59, 50, 68], Color("2a1e14"))
	_ell(50, 41, 21, 4.5, Color("5e1226"))
	_poly([38, 41, 62, 41, 50, 8], Color("8e1f3a"))
	_poly([38, 41, 44, 41, 50, 8], Color("741830"))
	_poly([39.5, 35, 60.5, 35, 62, 40, 38, 40], GOLD)
	_poly([44, 32, 47, 26, 50, 30, 53, 26, 56, 32], Color("f2c94c"))

static func _retained_apprentice_0(_t: float) -> void:
	_robe(Color("6d6488"), 14, 26, 62)
	_ell(30, 92, 7, 5, Color("6d6488"))
	_seg(72, 92, 84, 74, Color("8b5a2b"), 2.5)

static func _retained_apprentice_1(t: float) -> void:
	# The wand sputters: a spark, then a puff of grey smoke.
	var sputter := fposmod(t * 0.8, 1.0)
	_circ(86, 71, 3, Color(1.0, 0.82, 0.3, 0.9 * (1.0 - sputter)))
	_circ(88 + sputter * 3, 66 - sputter * 6, 2 + sputter * 2, Color(0.53, 0.53, 0.53, 0.55 * sputter))

static func _retained_apprentice_2(_t: float) -> void:
	_head(51)
	_eyes(53)
	for f in [[42, 57], [44, 59], [58, 57]]:
		_circ(f[0], f[1], 0.9, Color("b5704a"))

static func _retained_apprentice_3(t: float) -> void:
	_difficulty_hat(Difficulty.APPRENTICE, t)

static func _retained_adept_0(_t: float) -> void:
	_robe(Color("2f5bc7"))
	_rect(27, 104, 46, 4, GOLD)

static func _retained_adept_1(t: float) -> void:
	_circ(28, 74, 5 + sin(t * 2.0) * 0.8, Color(0.62, 0.78, 1.0, 0.5))

static func _retained_adept_2(_t: float) -> void:
	_rect(20, 80, 16, 12, Color("7a4a2a"))
	_rect(22, 81, 12, 10, Color("f3eedc"))
	_head(51)
	_eyes(53)

static func _retained_adept_3(t: float) -> void:
	_difficulty_hat(Difficulty.ADEPT, t)

static func _retained_teacher_0(_t: float) -> void:
	_robe(Color("1f7a74"))
	_seg(70, 88, 82, 66, Color("2a1e14"), 2.5)

static func _retained_teacher_1(t: float) -> void:
	# A turning spiral at the wand's tip: the transformation she teaches.
	var spiral := []
	for i in 19:
		var k := float(i) / 18.0
		var a := t * 2.5 + k * TAU * 1.6
		spiral.append_array([84 + cos(a) * (1.0 + 5.0 * k), 61 + sin(a) * (1.0 + 5.0 * k)])
	_stroke(spiral, Color("c89bff"), 1.8)

static func _retained_teacher_2(_t: float) -> void:
	_circ(90, 52, 1.6, Color("f2c94c"))
	_circ(77, 55, 1.2, Color("f2c94c"))
	_circ(62, 58, 6, Color("a7a7a7"))
	_head(51)
	var frame := Color(INK)
	for x in [40, 52]:
		_stroke([x, 48, x + 8, 48, x + 8, 54, x, 54, x, 48], frame, 1.3)
	_seg(48, 51, 52, 51, frame, 1.3)
	_circ(44, 51, 1.5, INK)
	_circ(56, 51, 1.5, INK)
	_ell(50, 41, 21, 4.5, Color("123f3b"))
	_poly([39, 41, 61, 41, 56, 20, 62, 10, 50, 16], Color("195a55"))
	_rect(40, 34, 20, 5, Color("123f3b"))
	_stroke([47, 33.5, 53, 33.5, 53, 39.5, 47, 39.5, 47, 33.5], Color("c9ced6"), 1.4)

static func _retained_archmage_0(_t: float) -> void:
	_seg(20, 110, 22, 44, Color("5a3a20"), 3.5)

static func _retained_archmage_1(t: float) -> void:
	_circ(22, 40, 6 + sin(t * 2.2) * 0.8, Color("c89bff"))

static func _retained_archmage_2(_t: float) -> void:
	_circ(20, 38, 2, Color("f3e8ff"))
	_robe(Color("4a1e73"), 16, 28, 62)
	_circ(60, 88, 1.6, Color("f2c94c"))
	_circ(40, 100, 1.4, Color("f2c94c"))
	_circ(66, 102, 1.2, Color("f2c94c"))
	_head(51)
	_poly(_q(37, 55, 50, 100, 63, 55), Color("f2f2ea"))
	_eyes(51)

static func _retained_archmage_3(t: float) -> void:
	_difficulty_hat(Difficulty.ARCHMAGE, t)
