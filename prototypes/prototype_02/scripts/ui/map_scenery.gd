class_name MapScenery
extends RefCounted
## Scenery of the journey map's islands, drawn by each island (map_island.gd)
## in island coordinates, back to front. Every opponent has a home (where it
## lives), a prop (an object of its trade) or both, placed around its spot, as
## picked by the user on 21 November 2026; the forest's waterfall pours out of
## a jagged opening behind roots in its cliff and vanishes into mist. The
## opponents themselves are the map's buttons, drawn above.
## Design: docs/design/prototype_02/Journey and Opponents.md, "Map".

const GREEN := Color("536b4b")
const INK := Color("49372e")
const GOLD := Color("ddba70")
const PURPLE := Color("543865")
const WOOD := Color("8a5a34")
const WATER := Color("5f8f95")
const STREAM := Color("7fb6c6")
const SkyCycle := preload("res://scripts/ui/day_night_sky.gd")
const CLIFF := Color("857570") # the lit cliff face around the waterfall's opening
const DARK := Color("1e1612")
const DEEP := Color("120c09")
## The forest's firs, clear of the homes, as [position, scale].
const FOREST_TREES := [[Vector2(-150, -40), 0.7], [Vector2(-128, -60), 0.6], [Vector2(-185, -32), 0.65],
	[Vector2(120, 30), 0.6], [Vector2(140, 48), 0.55], [Vector2(10, -66), 0.6], [Vector2(-10, 62), 0.55]]
## The waterfall's opening on the forest's cliff, and the fall's length.
const HOLE := Vector2(-108, 116)
const FALL_LENGTH := 112.0
const FALL_WIDTH := Vector2(13, 26)

var ci: CanvasItem
var t := 0.0
var _items: Array = []


## Draws an island's scenery around its five opponents' `spots` (island
## coordinates, journey order) at time `time`.
func draw(canvas: CanvasItem, zone: int, spots: Array, time: float) -> void:
	ci = canvas
	t = time
	_items.clear()
	if zone == 0:
		_waterfall()
		for tree: Array in FOREST_TREES:
			var p: Vector2 = tree[0]
			var s: float = tree[1]
			_add(p, func(): _fir(p, s))
	elif zone == 2:
		_add(Vector2(0, -15), func(): _tower(Vector2(0, -15), 1.05))
	for i in mini(spots.size(), OpponentDB.ZONE_SIZE):
		_opponent_scenery(OpponentDB.get_opponent(zone * OpponentDB.ZONE_SIZE + i).id, spots[i])
	_items.sort_custom(func(a, b): return a[0] < b[0])
	for item in _items:
		item[1].call()


func _add(ground: Vector2, draw_call: Callable) -> void:
	_items.append([ground.y, draw_call])


## Each opponent's home and/or prop around its spot `p`.
func _opponent_scenery(id: String, p: Vector2) -> void:
	match id:
		"hunter":
			_add(p + Vector2(-4, -30), func(): _hunt_stand(p + Vector2(-4, -30), 0.85))
		"druid":
			_add(p + Vector2(0, -1), func(): _menhirs(p, false))
			_add(p + Vector2(0, 1), func(): _menhirs(p, true))
		"lumberjack":
			# His axe is in his hands: the stump has none.
			_add(p + Vector2(50, -18), func(): _cabin(p + Vector2(50, -18), 0.8))
			_add(p + Vector2(-26, -2), func(): _stump(p + Vector2(-26, -2), 0.9))
			_add(p + Vector2(-12, 6), func(): _log_pile(p + Vector2(-12, 6), 0.6))
		"swamp_witch":
			_add(p + Vector2(34, -26), func(): _pond(p + Vector2(34, -14), 36, 11))
			_add(p + Vector2(36, -24), func(): _witch_hut(p + Vector2(36, -24), 0.75))
			_add(p + Vector2(-26, -2), func(): _cauldron(p + Vector2(-26, -2), 0.8, Color("7ad04a")))
		"archdruid":
			_add(p + Vector2(-14, -24), func(): _great_tree(p + Vector2(-14, -24), 0.8))
		"merchant":
			_add(p + Vector2(0, -26), func(): _market_stall(p + Vector2(0, -26), 0.85))
		"innkeeper":
			_add(p + Vector2(10, -28), func(): _tavern(p + Vector2(10, -28), 0.8))
			_add(p + Vector2(-26, -2), func(): _barrels(p + Vector2(-26, -2), 0.85))
		"thief":
			_add(p + Vector2(26, -2), func(): _loot(p + Vector2(26, -2), 0.85))
		"court_mage":
			_add(p + Vector2(-22, 0), func(): _brazier(p + Vector2(-22, 0), 0.8, Color("ff8a3a")))
			_add(p + Vector2(22, 0), func(): _brazier(p + Vector2(22, 0), 0.8, Color("8fd8ff")))
		"apprentice":
			_add(p + Vector2(26, -2), func(): _dummy(p + Vector2(26, -2), 0.8))
		"caretaker":
			# His broom is in his hands: a bucket by the shed's door.
			_add(p + Vector2(-14, -22), func(): _shed(p + Vector2(-14, -22), 0.8))
		"adept":
			_add(p + Vector2(26, -2), func(): _lectern(p + Vector2(26, -2), 0.9))
		"transmutation_teacher":
			_add(p + Vector2(20, -20), func(): _greenhouse(p + Vector2(20, -20), 0.8))
		"archmage":
			# The tower is his home; a rune circle glows where he stands.
			_add(p + Vector2(0, -1), func(): _rune_circle(p, 30, 9))


# --- Shapes ----------------------------------------------------------------------------

func _poly(points: Array, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(points), col)


func _shadow(p: Vector2, rx: float) -> void:
	Shapes.ellipse(ci, p, rx, rx * 0.3, Color(0.12, 0.08, 0.06, 0.22))


func _building(p: Vector2, s: float, w: float, h: float, wall: Color, roof: Color, windows: int) -> void:
	_shadow(p, w * 0.6 * s)
	_poly([p + Vector2(-w * 0.5, 0) * s, p + Vector2(-w * 0.5, -h) * s, p + Vector2(w * 0.5, -h) * s, p + Vector2(w * 0.5, 0) * s], wall)
	_poly([p + Vector2(w * 0.2, 0) * s, p + Vector2(w * 0.2, -h) * s, p + Vector2(w * 0.5, -h) * s, p + Vector2(w * 0.5, 0) * s], wall.darkened(0.15))
	_poly([p + Vector2(-w * 0.5 - 6, -h + 2) * s, p + Vector2(0, -h - 26) * s, p + Vector2(w * 0.5 + 6, -h + 2) * s], roof)
	for i in windows:
		var x := -w * 0.5 + (i + 0.5) * w / windows
		ci.draw_rect(Rect2(p + Vector2(x - 3, -h * 0.65) * s, Vector2(6, 8) * s), GOLD)


# --- Forest ----------------------------------------------------------------------------

func _fir(p: Vector2, s: float) -> void:
	Shapes.line(ci, p + Vector2(0, -12) * s, p + Vector2(0, 13) * s, INK, 6 * s)
	_poly([p + Vector2(-22, 0) * s, p + Vector2(0, -58) * s, p + Vector2(22, 0) * s], GREEN.darkened(0.12))
	_poly([p + Vector2(-17, -19) * s, p + Vector2(0, -67) * s, p + Vector2(17, -19) * s], GREEN)


func _hunt_stand(p: Vector2, s: float) -> void:
	_shadow(p, 26 * s)
	for x in [-16, 16]:
		Shapes.line(ci, p + Vector2(x, 0) * s, p + Vector2(x * 0.8, -44) * s, WOOD.darkened(0.2), 4 * s)
	_poly([p + Vector2(-22, -44) * s, p + Vector2(22, -44) * s, p + Vector2(20, -38) * s, p + Vector2(-20, -38) * s], WOOD)
	_poly([p + Vector2(-24, -60) * s, p + Vector2(0, -76) * s, p + Vector2(24, -60) * s], Color("6b4a2e"))
	for y in [-8, -18, -28]:
		Shapes.line(ci, p + Vector2(-4, y) * s, p + Vector2(8, y) * s, WOOD.lightened(0.2), 2 * s)
	# Antlers over the hide.
	Shapes.line(ci, p + Vector2(-6, -64) * s, p + Vector2(-12, -72) * s, Color("efe6d2"), 2 * s)
	Shapes.line(ci, p + Vector2(6, -64) * s, p + Vector2(12, -72) * s, Color("efe6d2"), 2 * s)


## The druid's ring of standing stones: the back half, or the front half.
func _menhirs(p: Vector2, front: bool) -> void:
	if not front:
		Shapes.ellipse(ci, p, 30, 9, Color(0.6, 0.95, 0.6, 0.18 + 0.08 * sin(t * 2.0)))
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var q := p + Vector2(cos(a) * 34, sin(a) * 12)
		if (sin(a) > 0.0) != front:
			continue
		_poly([q + Vector2(-5, 0), q + Vector2(-4, -20), q + Vector2(0, -24), q + Vector2(5, -19), q + Vector2(5, 0)], Color("9a9890"))
		_poly([q + Vector2(1, -23), q + Vector2(5, -19), q + Vector2(5, 0), q + Vector2(1, 0)], Color("7a7870"))


func _cabin(p: Vector2, s: float) -> void:
	_shadow(p, 36 * s)
	_poly([p + Vector2(-28, 0) * s, p + Vector2(-28, -28) * s, p + Vector2(28, -28) * s, p + Vector2(28, 0) * s], Color("9a6a3e"))
	for y in [-6, -12, -18, -24]:
		Shapes.line(ci, p + Vector2(-28, y) * s, p + Vector2(28, y) * s, Color("6e4626"), 1.5 * s)
	_poly([p + Vector2(-34, -26) * s, p + Vector2(0, -52) * s, p + Vector2(34, -26) * s], Color("8a3e2e"))
	_poly([p + Vector2(-6, 0) * s, p + Vector2(-6, -16) * s, p + Vector2(6, -16) * s, p + Vector2(6, 0) * s], INK)
	_poly([p + Vector2(14, -14) * s, p + Vector2(22, -14) * s, p + Vector2(22, -21) * s, p + Vector2(14, -21) * s], GOLD)
	ci.draw_rect(Rect2(p + Vector2(14, -50) * s, Vector2(7, 14) * s), Color("6a6660"))
	for i in 3:
		var k := fmod(t * 0.5 + i / 3.0, 1.0)
		Shapes.circle(ci, p + Vector2(18 + k * 8, -54 - k * 26) * s, (3 + k * 4) * s, Color(0.85, 0.85, 0.82, 0.5 * (1 - k)))


func _log_pile(p: Vector2, s: float) -> void:
	_shadow(p, 20 * s)
	for c in [Vector2(-12, -5), Vector2(0, -5), Vector2(12, -5), Vector2(-6, -15), Vector2(6, -15), Vector2(0, -25)]:
		Shapes.circle(ci, p + c * s, 6 * s, Color("c9a06a"))
		Shapes.circle(ci, p + c * s, 3 * s, Color("a67c4a"))


func _stump(p: Vector2, s: float) -> void:
	_poly([p + Vector2(-10, 0) * s, p + Vector2(-9, -10) * s, p + Vector2(9, -10) * s, p + Vector2(10, 0) * s], WOOD)
	Shapes.ellipse(ci, p + Vector2(0, -10) * s, 9 * s, 3.5 * s, Color("c9a06a"))


func _pond(p: Vector2, rx: float, ry: float) -> void:
	Shapes.ellipse(ci, p, rx + 4, ry + 3, Color("5a6a45"))
	Shapes.ellipse(ci, p, rx, ry, WATER)
	Shapes.ellipse(ci, p + Vector2(-rx * 0.3, -ry * 0.3), rx * 0.4, ry * 0.25, Color(1, 1, 1, 0.18))
	for q in [Vector2(rx * 0.35, 2), Vector2(-rx * 0.5, 4)]:
		Shapes.ellipse(ci, p + q, 6, 2.5, Color("6f9a4f"))


func _witch_hut(p: Vector2, s: float) -> void:
	for x in [-14, -4, 8, 16]:
		Shapes.line(ci, p + Vector2(x, 10) * s, p + Vector2(x, -10) * s, WOOD.darkened(0.3), 3 * s)
	_poly([p + Vector2(-20, -10) * s, p + Vector2(-18, -36) * s, p + Vector2(20, -38) * s, p + Vector2(22, -10) * s], Color("4e5a46"))
	_poly([p + Vector2(-26, -34) * s, p + Vector2(4, -66) * s, p + Vector2(14, -58) * s, p + Vector2(26, -36) * s], Color("2e3a34"))
	_poly([p + Vector2(4, -26) * s, p + Vector2(12, -26) * s, p + Vector2(12, -18) * s, p + Vector2(4, -18) * s], Color(0.6, 1, 0.5, 0.7 + 0.3 * sin(t * 4)))


func _cauldron(p: Vector2, s: float, brew: Color) -> void:
	for i in 3:
		var k := fmod(t * 1.5 + i / 3.0, 1.0)
		Shapes.circle(ci, p + Vector2(-6 + i * 6, -22 - k * 18) * s, (3 + k * 3) * s, Color(brew, 0.6 * (1 - k)))
	Shapes.ellipse(ci, p + Vector2(0, 2) * s, 12 * s, 4 * s, Color(1, 0.55, 0.2, 0.8))
	Shapes.ellipse(ci, p + Vector2(0, -8) * s, 14 * s, 11 * s, Color("2a2a2e"))
	Shapes.ellipse(ci, p + Vector2(0, -16) * s, 12 * s, 3.5 * s, brew)


func _great_tree(p: Vector2, s: float) -> void:
	_shadow(p, 40 * s)
	_poly([p + Vector2(-14, 0) * s, p + Vector2(-9, -50) * s, p + Vector2(9, -50) * s, p + Vector2(14, 0) * s], Color("5e4430"))
	for r in [[Vector2(-20, 2), Vector2(-8, -6)], [Vector2(20, 2), Vector2(8, -6)]]:
		Shapes.line(ci, p + r[0] * s, p + r[1] * s, Color("5e4430"), 5 * s)
	for c in [[Vector2(-26, -62), 24], [Vector2(24, -64), 25], [Vector2(0, -84), 28], [Vector2(-8, -60), 22]]:
		Shapes.circle(ci, p + c[0] * s, c[1] * s, Color("3f5e3a"))
	for c in [[Vector2(-14, -80), 9], [Vector2(16, -78), 8]]:
		Shapes.circle(ci, p + c[0] * s, c[1] * s, Color("5d7a44"))
	Shapes.circle(ci, p + Vector2(0, -32) * s, 5 * s, Color("1e140e"))
	Shapes.circle(ci, p + Vector2(0, -32) * s, 2 * s, Color(1, 0.9, 0.4, 0.6 + 0.4 * sin(t * 2)))


# --- The forest's waterfall -----------------------------------------------------------

func _waterfall() -> void:
	var roots := [
		[Vector2(-22, -44), Vector2(-20, -30), Vector2(-23, -16), Vector2(-19, -4)],
		[Vector2(-10, -46), Vector2(-12, -32), Vector2(-8, -18), Vector2(-11, -6), Vector2(-8, 4)],
		[Vector2(2, -46), Vector2(4, -34), Vector2(1, -22), Vector2(5, -12)],
		[Vector2(12, -45), Vector2(10, -30), Vector2(14, -18), Vector2(11, -4), Vector2(14, 6)],
		[Vector2(22, -42), Vector2(24, -30), Vector2(21, -18), Vector2(24, -8)],
	]
	# A jagged opening in the lit cliff face, dark inside.
	_hole_shape([Vector2(-18, -7), Vector2(-11, -13), Vector2(-2, -11), Vector2(6, -15), Vector2(15, -9), Vector2(19, -1),
		Vector2(13, 7), Vector2(2, 9), Vector2(-9, 8), Vector2(-16, 3)], CLIFF.darkened(0.28))
	_hole_shape([Vector2(-13, -4), Vector2(-8, -9), Vector2(0, -7), Vector2(6, -10), Vector2(13, -5), Vector2(14, 1),
		Vector2(9, 5), Vector2(-2, 6), Vector2(-11, 3)], DARK)
	_hole_shape([Vector2(-5, -3), Vector2(4, -5), Vector2(8, 1), Vector2(-2, 3)], DEEP)
	for edge in [[Vector2(-18, -7), Vector2(-11, -13)], [Vector2(-11, -13), Vector2(-2, -11)], [Vector2(-2, -11), Vector2(6, -15)]]:
		Shapes.line(ci, HOLE + edge[0], HOLE + edge[1], CLIFF.lightened(0.3), 1.6, true)
	Shapes.line(ci, HOLE + Vector2(-9, 8), HOLE + Vector2(2, 9), CLIFF.lightened(0.15), 1.6, true)
	# Loose stones on a little ledge under it.
	for r in [[Vector2(-15, 12), 3.5], [Vector2(15, 11), 3.0]]:
		var c: Vector2 = r[0]
		var s: float = r[1]
		_hole_shape([c + Vector2(-s, 0), c + Vector2(0, -s), c + Vector2(s, -s * 0.3), c + Vector2(s * 0.6, s * 0.5)], CLIFF.darkened(0.1))
	# Roots from the forest above hang around it, two of them over the water.
	_roots([roots[0], roots[2], roots[4]], false)
	var top := HOLE + Vector2(1, 8)
	_curtain(top)
	_roots([roots[1], roots[3]], true)
	_lip_foam(top + Vector2(0, 1))
	_mist(HOLE + Vector2(0, FALL_LENGTH + 4))


func _hole_shape(points: Array, col: Color) -> void:
	var poly := PackedVector2Array()
	for v: Vector2 in points:
		poly.append(HOLE + v)
	ci.draw_colored_polygon(poly, col)


## Roots swaying a little; drops fall from the tips of the dripping ones.
func _roots(roots: Array, drip: bool) -> void:
	for i in roots.size():
		var line := PackedVector2Array()
		var points: Array = roots[i]
		for j in points.size():
			line.append(HOLE + points[j] + Vector2(sin(t * 0.8 + i) * 0.6 * j, 0))
		Shapes.polyline(ci, line, Color("5e4430"), 2.6 - (i % 3) * 0.6)
		if drip:
			var tip: Vector2 = line[line.size() - 1]
			var k := fmod(t * 0.7 + i * 0.31, 1.0)
			Shapes.circle(ci, tip + Vector2(0, k * 26), 1.3, Color(0.85, 0.95, 1.0, 0.8 * (1.0 - k)))


## The falling water: widening, with a light core and streaks running down,
## fading at its foot into the mist.
func _curtain(top: Vector2) -> void:
	var steps := 20
	for i in steps:
		var a := float(i) / steps
		var b := float(i + 1) / steps
		var fade_a := 1.0 - smoothstep(0.6, 1.0, a)
		var fade_b := 1.0 - smoothstep(0.6, 1.0, b)
		var wa := lerpf(FALL_WIDTH.x, FALL_WIDTH.y, sqrt(a)) + sin(minf(a * 3.0, 1.0) * PI * 0.5) * 2.0
		var wb := lerpf(FALL_WIDTH.x, FALL_WIDTH.y, sqrt(b)) + sin(minf(b * 3.0, 1.0) * PI * 0.5) * 2.0
		var ya := top.y + a * FALL_LENGTH
		var yb := top.y + b * FALL_LENGTH
		for layer in [[0.5, 0.5, STREAM.darkened(0.08), 0.95], [0.2, 0.15, STREAM.lightened(0.35), 0.8]]:
			var col: Color = layer[2]
			var ca := Color(col, layer[3] * fade_a)
			var cb := Color(col, layer[3] * fade_b)
			ci.draw_polygon(PackedVector2Array([Vector2(top.x - wa * layer[0], ya), Vector2(top.x + wa * layer[1], ya),
				Vector2(top.x + wb * layer[1], yb), Vector2(top.x - wb * layer[0], yb)]), PackedColorArray([ca, ca, cb, cb]))
	for i in 6:
		var k := fmod(t * 0.8 + i / 6.0, 1.0)
		var w := lerpf(FALL_WIDTH.x, FALL_WIDTH.y, sqrt(k))
		var x := top.x + (fmod(i * 0.37, 1.0) - 0.5) * w * 0.8
		var y := top.y + k * FALL_LENGTH * 0.85
		Shapes.line(ci, Vector2(x, y), Vector2(x, y + 10 + k * 8), Color(1, 1, 1, 0.6 * (1.0 - k)), 1.6, true)


## White churn and a few droplets where the water leaves the opening.
func _lip_foam(p: Vector2) -> void:
	for i in 5:
		var k := fmod(t * 1.4 + i * 0.2, 1.0)
		Shapes.circle(ci, p + Vector2((i - 2) * 3.0, -sin(k * PI) * 3.0), 3.2 * (1.0 - k * 0.4), Color(1, 1, 1, 0.7 * (1.0 - k)))
	for i in 4:
		var k := fmod(t * 0.9 + i * 0.25, 1.0)
		var side := -1.0 if i % 2 else 1.0
		Shapes.circle(ci, p + Vector2(side * (6 + k * 14), k * 22 + k * k * 18), 1.4, Color(0.9, 0.97, 1.0, 0.8 * (1.0 - k)))


## Small clouds of mist where the water vanishes, drifting and breathing.
func _mist(p: Vector2) -> void:
	var tint := Color("e6eef0").lerp(STREAM.lightened(0.5), 0.25)
	for i in 9:
		var k := fmod(t * 0.12 + i / 9.0, 1.0)
		var q := p + Vector2(sin(i * 2.4 + t * 0.25) * 22.0, -6 + k * 34)
		Shapes.circle(ci, q, 9.0 + k * 13.0, Color(tint, 0.42 * sin(k * PI)))
	SkyCycle.cloud(ci, p + Vector2(sin(t * 0.3) * 4.0, 26), 0.3, Color(tint, 0.85))
	SkyCycle.cloud(ci, p + Vector2(-18 + sin(t * 0.25 + 1.0) * 4.0, 34), 0.22, Color(tint, 0.7))


# --- Town ------------------------------------------------------------------------------

func _market_stall(p: Vector2, s: float) -> void:
	_shadow(p, 30 * s)
	ci.draw_rect(Rect2(p + Vector2(-26, -14) * s, Vector2(52, 14) * s), Color("6e4626"))
	for x in [-24, 22]:
		Shapes.line(ci, p + Vector2(x, 0) * s, p + Vector2(x, -36) * s, WOOD, 3 * s)
	for i in 6:
		var x := -28.0 + i * 9.5
		_poly([p + Vector2(x, -36) * s, p + Vector2(x + 9.5, -36) * s, p + Vector2(x + 9.5, -28) * s,
			p + Vector2(x + 4.75, -24) * s, p + Vector2(x, -28) * s], Color("c8962f") if i % 2 else Color("7a4a28"))
	for c in [[Vector2(-14, -16), Color("e86a3a")], [Vector2(-2, -16), Color("f2d36a")], [Vector2(10, -16), Color("7ad04a")]]:
		Shapes.circle(ci, p + c[0] * s, 4 * s, c[1])


func _tavern(p: Vector2, s: float) -> void:
	_building(p, s, 48, 34, Color("c9b58b"), Color("805544"), 3)
	Shapes.line(ci, p + Vector2(-28, -26) * s, p + Vector2(-40, -26) * s, WOOD, 2 * s)
	_poly([p + Vector2(-44, -25) * s, p + Vector2(-36, -25) * s, p + Vector2(-36, -15) * s, p + Vector2(-44, -15) * s], Color("6e4626"))
	Shapes.ellipse(ci, p + Vector2(-40, -20) * s, 2.5 * s, 3 * s, GOLD)
	_poly([p + Vector2(-5, 0) * s, p + Vector2(-5, -14) * s, p + Vector2(5, -14) * s, p + Vector2(5, 0) * s], INK)


func _barrels(p: Vector2, s: float) -> void:
	for x in [-8, 8]:
		Shapes.ellipse(ci, p + Vector2(x, -8) * s, 7 * s, 9 * s, Color("8a5a34"))
		Shapes.line(ci, p + Vector2(x - 7, -6) * s, p + Vector2(x + 7, -6) * s, Color("4e3a2a"), 1.5 * s)
		Shapes.line(ci, p + Vector2(x - 7, -11) * s, p + Vector2(x + 7, -11) * s, Color("4e3a2a"), 1.5 * s)
	_poly([p + Vector2(-4, -18) * s, p + Vector2(4, -18) * s, p + Vector2(3, -26) * s, p + Vector2(-3, -26) * s], Color("c8a050"))
	Shapes.ellipse(ci, p + Vector2(0, -26) * s, 4 * s, 2 * s, Color("f4ecd8"))


func _loot(p: Vector2, s: float) -> void:
	Shapes.ellipse(ci, p + Vector2(0, -7) * s, 9 * s, 8 * s, Color("8a7a5a"))
	_poly([p + Vector2(-3, -14) * s, p + Vector2(3, -14) * s, p + Vector2(5, -19) * s, p + Vector2(-5, -19) * s], Color("6e5e42"))
	for i in 3:
		Icons.coin(ci, p + Vector2(10 + i * 4, -2 - i * 2) * s, 3 * s)


func _brazier(p: Vector2, s: float, flame: Color) -> void:
	Shapes.line(ci, p, p + Vector2(0, -14) * s, Color("4a4448"), 3 * s)
	Shapes.ellipse(ci, p + Vector2(0, -15) * s, 7 * s, 3 * s, Color("5a5458"))
	var flick := 1.0 + 0.15 * sin(t * 9.0 + p.x)
	_poly([p + Vector2(-5, -16) * s, p + Vector2(0, -16 - 14 * flick) * s, p + Vector2(5, -16) * s], flame)


# --- School ----------------------------------------------------------------------------

func _tower(p: Vector2, s: float) -> void:
	Shapes.ellipse(ci, p + Vector2(0, 8) * s, 56 * s, 15 * s, Color(0.12, 0.07, 0.17, 0.3))
	_poly([p + Vector2(-28, 0) * s, p + Vector2(-22, -105) * s, p + Vector2(22, -105) * s, p + Vector2(28, 0) * s], Color("78617d"))
	_poly([p + Vector2(8, 0) * s, p + Vector2(8, -105) * s, p + Vector2(22, -105) * s, p + Vector2(28, 0) * s], PURPLE)
	_poly([p + Vector2(-38, -100) * s, p + Vector2(0, -154) * s, p + Vector2(38, -100) * s], Color("513060"))
	Shapes.line(ci, p + Vector2(-38, -100) * s, p + Vector2(38, -100) * s, GOLD, 3 * s)
	for y in [-82, -48]:
		ci.draw_rect(Rect2(p + Vector2(-5, y) * s, Vector2(10, 17) * s), GOLD)
	Icons.star(ci, p + Vector2(0, -129) * s, 9 * s, GOLD)
	ci.draw_rect(Rect2(p + Vector2(-9, -24) * s, Vector2(18, 24) * s), Color("342339"))


func _shed(p: Vector2, s: float) -> void:
	_building(p, s, 30, 22, Color("8a6a4a"), Color("5e4430"), 0)
	_poly([p + Vector2(18, 2) * s, p + Vector2(17, -8) * s, p + Vector2(29, -8) * s, p + Vector2(28, 2) * s], Color("8a8e96"))


func _greenhouse(p: Vector2, s: float) -> void:
	_shadow(p, 34 * s)
	Shapes.ellipse(ci, p + Vector2(0, -16) * s, 30 * s, 22 * s, Color(0.75, 0.9, 0.95, 0.55))
	for c in [Vector2(-12, -10), Vector2(6, -14), Vector2(14, -6)]:
		Shapes.circle(ci, p + c * s, 7 * s, Color("6f9a4f"))
	Shapes.arc(ci, p + Vector2(0, -16) * s, 30 * s, PI, TAU, 24, Color("ddd6e8"), 2 * s, true)
	ci.draw_rect(Rect2(p + Vector2(18, -46) * s, Vector2(6, 18) * s), Color("6a6660"))
	for i in 3:
		var k := fmod(t * 0.6 + i / 3.0, 1.0)
		var smoke: Color = [Color("b48be6"), Color("7ad04a"), Color("f2a94a")][i]
		Shapes.circle(ci, p + Vector2(21 + k * 6, -48 - k * 26) * s, (3 + k * 4) * s, Color(smoke, 0.55 * (1 - k)))


func _dummy(p: Vector2, s: float) -> void:
	Shapes.line(ci, p, p + Vector2(0, -34) * s, WOOD, 3 * s)
	Shapes.line(ci, p + Vector2(-12, -24) * s, p + Vector2(12, -24) * s, WOOD, 3 * s)
	Shapes.ellipse(ci, p + Vector2(0, -22) * s, 8 * s, 12 * s, Color("d8c27a"))
	Shapes.circle(ci, p + Vector2(0, -38) * s, 6 * s, Color("d8c27a"))
	Shapes.circle(ci, p + Vector2(3, -20) * s, 3 * s, Color(0.2, 0.15, 0.1, 0.6))


func _lectern(p: Vector2, s: float) -> void:
	Shapes.line(ci, p, p + Vector2(0, -20) * s, WOOD, 4 * s)
	_poly([p + Vector2(-12, -18) * s, p + Vector2(12, -22) * s, p + Vector2(12, -26) * s, p + Vector2(-12, -22) * s], WOOD.lightened(0.1))
	_poly([p + Vector2(-11, -23) * s, p + Vector2(0, -27) * s, p + Vector2(11, -27) * s, p + Vector2(0, -23) * s], Color("efe6d2"))
	# Books float above the open one.
	for i in 3:
		var q := p + Vector2((i - 1) * 16, -42 - sin(t * 2.0 + i * 2.0) * 5) * s * 0.7
		_poly([q + Vector2(-7, 0) * s * 0.7, q + Vector2(0, -3) * s * 0.7, q + Vector2(7, 0) * s * 0.7, q + Vector2(0, 3) * s * 0.7],
			[Color("c8453a"), Color("3a6ad0"), Color("2f9a7a")][i])


func _rune_circle(p: Vector2, rx: float, ry: float) -> void:
	var glow := 0.45 + 0.25 * sin(t * 2.5)
	Shapes.ellipse(ci, p, rx, ry, Color(0.7, 0.5, 1.0, 0.15))
	var ring := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		ring.append(p + Vector2(cos(a) * rx, sin(a) * ry))
	Shapes.polyline(ci, ring, Color(0.8, 0.6, 1.0, glow), 2.0)
	for i in 6:
		var a := TAU * i / 6.0 + t * 0.4
		Shapes.circle(ci, p + Vector2(cos(a) * rx * 0.7, sin(a) * ry * 0.7), 2, Color(0.9, 0.8, 1.0, glow))
