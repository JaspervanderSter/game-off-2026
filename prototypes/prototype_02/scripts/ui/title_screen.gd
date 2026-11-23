class_name TitleScreen
extends Node2D
## The title island (playtest decision, 22 November 2026): the game opens on a
## floating island left of the forest, in the world map's own space. DUEL
## stands on it in earth letters with grass on every ledge, SHAPESHIFTERS is
## carved in gold in its cliff. It bursts out of the clouds in about half a
## second on the title jingle (ui/title), lands with a jolt, then keeps
## living: it floats, rocks drift under it, birds circle, smoke rises from the
## cottage, and a creature on the D changes shape every few seconds through
## its chain of most likely outcomes. Once it has landed, the rope bridge
## unrolls from its shore towards the forest and the island medallion appears
## on it: world_map.gd draws both, and pans the camera along the bridge.
## On Web the title first waits in the clouds behind a pulsing start medallion:
## the page loads faster than anyone looks, and the browser only lets sound
## play after a first click or key, so that input starts it with its jingle.
## The island is drawn in its own 1280 x 720 frame, its grass top centred on
## FRAME_ANCHOR; world_map.gd places this node in the map's coordinates.
## Design: docs/design/Prototype 02.md, "Sky, sound and entry point".

const LINE1 := "SHAPESHIFTERS"
const LINE2 := "DUEL"
const FRAME_ANCHOR := Vector2(640, 400)
## The cottage door, where the journey's footsteps start, and the island's
## right shore, where the bridge leaves, in this node's frame.
const DOOR := Vector2(927, 404)
const SHORE := Vector2(966, 400)
## The medallion's place on the bridge, near the screen's right edge.
const MEDALLION := Vector2(1190, 384)
const MEDALLION_RADIUS := 44.0
const LAND_AT := 0.45 # the island lands
const BRIDGE_AT := 0.95 # then its bridge unrolls...
const BRIDGE_TIME := 0.55
const MEDALLION_AT := 1.45 # ...and the way to the map appears on it
const READY_AT := 1.55
const IDLE_SHIFT := 3.2 # seconds between two changes of the creature
const GOLD := Color("e7cd94")
const EARTH := Color("8a6a4a")
const EARTH_DARK := Color("5e4430")
const GRASS := Color("7fa956")
const CLOUD := Color("e3eadf")
const ISLAND_HALF := 330.0
const ISLAND_DEPTH := 168.0
const ISLAND_PROFILE := [Vector2(1.0, 0.0), Vector2(0.95, 0.32), Vector2(0.8, 0.42), Vector2(0.62, 0.6),
	Vector2(0.4, 0.66), Vector2(0.2, 1.0), Vector2(0.02, 0.78), Vector2(-0.2, 0.86), Vector2(-0.42, 0.62),
	Vector2(-0.64, 0.55), Vector2(-0.82, 0.4), Vector2(-0.96, 0.3), Vector2(-1.0, 0.0)]
const DUEL_UNIT := 26.0
const LINE1_UNIT := 8.5

var t := 0.0
## Waiting for the first input before playing (Web launch).
var waiting := false
var _idle := 0.0 # seconds spent waiting, for the clouds and the start prompt
var _prompt_leaving := false
var _fired := {}
var _silent := false
var _parts: Array[Dictionary] = []
var _glyphs := {}


func _ready() -> void:
	_glyphs = glyph_pieces()


## Holds the title in the clouds, at its start, until play() is called.
func wait_for_start() -> void:
	t = 0.0
	_idle = 0.0
	_fired.clear()
	_parts.clear()
	waiting = true
	_prompt_leaving = false
	queue_redraw()


## Plays the title from its start, with its jingle.
func play() -> void:
	_prompt_leaving = waiting
	waiting = false
	t = 0.0
	_fired.clear()
	_parts.clear()
	_silent = false
	Sfx.play("ui/title")


## Finishes the animation at once, without its effects.
func finish() -> void:
	waiting = false
	_prompt_leaving = false
	if t >= READY_AT:
		return
	_silent = true
	t = READY_AT + 1.0
	_events()
	_parts.clear()
	_silent = false
	queue_redraw()


func animating() -> bool:
	return t < READY_AT


func medallion_center() -> Vector2:
	return MEDALLION


## Share of the bridge unrolled from the shore, 0 to 1.
func bridge_reach() -> float:
	return 1.0 - pow(1.0 - clampf((t - BRIDGE_AT) / BRIDGE_TIME, 0.0, 1.0), 3)


## Seconds since the medallion appeared (negative before).
func medallion_age() -> float:
	return t - MEDALLION_AT


## How far below its place the island floats now, in frame units: it rises
## out of the clouds with a little overshoot, then bobs.
func lift() -> float:
	var k := clampf(t / LAND_AT, 0.0, 1.0)
	var c1 := 1.3
	var eased := 1.0 + (c1 + 1.0) * pow(k - 1.0, 3) + c1 * pow(k - 1.0, 2)
	return (1.0 - eased) * 620.0 + sin(t * 1.3) * 4.0 * smoothstep(0.6, 1.4, t)


func advance(dt: float) -> void:
	if waiting:
		_idle += dt
		queue_redraw()
		return
	t += dt
	_events()
	for p in _parts:
		p.age += dt
		p.vel += Vector2(0, p.get("grav", 0.0)) * dt
		p.vel *= 1.0 - minf(1.0, p.get("drag", 0.0) * dt)
		p.pos += p.vel * dt
	_parts = _parts.filter(func(p): return p.age < p.life)
	queue_redraw()


func _once(key: Variant, at: float) -> bool:
	if t >= at and not _fired.has(key):
		_fired[key] = true
		return true
	return false


func _events() -> void:
	if _once("burst", 0.16) and not _silent:
		# The island breaks through the clouds.
		for i in 16:
			var dir := Vector2(cos(TAU * i / 16.0) * 1.8, sin(TAU * i / 16.0) * 0.5)
			_parts.append({"pos": Vector2(640, 660) + dir * 30.0, "vel": dir * randf_range(160, 260), "age": 0.0,
				"life": 0.8, "size": randf_range(14.0, 24.0), "col": CLOUD, "drag": 3.5})
	if _once("land", LAND_AT) and not _silent:
		for i in 4:
			_parts.append({"pos": Vector2(640 + (i - 1.5) * 120.0 + randf_range(-30, 30), 560), "rock": true,
				"vel": Vector2(randf_range(-30, 30), 40), "grav": 800.0, "age": 0.0, "life": 1.2, "size": randf_range(4.0, 7.0)})
	var steps := _shift_steps()
	if steps > 0 and _once("shift%d" % steps, 0.0) and not _silent:
		var at := _perch() + Vector2(0, -20)
		for i in 9:
			_parts.append({"pos": at, "vel": Vector2.from_angle(TAU * i / 9.0 + randf() * 0.4) * randf_range(90, 150),
				"age": 0.0, "life": 0.55, "size": randf_range(4.0, 7.0), "col": GOLD, "drag": 4.0, "star": true})
		for i in 8:
			var dir := Vector2.from_angle(TAU * i / 8.0)
			_parts.append({"pos": at + dir * 6.0, "vel": dir * 90.0, "age": 0.0, "life": 0.45, "size": 9.0,
				"col": Color(1, 1, 1, 0.85), "drag": 5.0})


## A short jolt as the island lands.
func _shake() -> Vector2:
	var a := t - LAND_AT
	if a <= 0.0 or a >= 0.35:
		return Vector2.ZERO
	return Vector2(sin(a * 90.0), cos(a * 70.0)) * 7.0 * (1.0 - a / 0.35)


func _draw() -> void:
	var base := _shake()
	var top := FRAME_ANCHOR.y + lift()
	var clock := t + _idle # keeps the sky moving while the title waits
	draw_set_transform(base)
	# Birds circle far behind.
	for i in 2:
		var a := clock * 0.45 + i * 2.6
		_bird(Vector2(640 + cos(a) * 470.0, 170 + sin(a) * 40.0 + i * 30.0), 1.0 - i * 0.25)
	# Rocks drift under the island.
	for r in [[Vector2(470, 585), 7.0, 0.0], [Vector2(812, 572), 9.0, 1.7], [Vector2(560, 640), 5.0, 3.1]]:
		_floating_rock(r[0] + Vector2(0, lift() + sin(t * 1.1 + r[2]) * 6.0), r[1])
	# The rock, its dark right facet, its grass top.
	var body := PackedVector2Array()
	var facet := PackedVector2Array([Vector2(640 + ISLAND_HALF * 0.35, top)])
	for q: Vector2 in ISLAND_PROFILE:
		var p := Vector2(640 + q.x * ISLAND_HALF, top + q.y * ISLAND_DEPTH)
		body.append(p)
		if q.x >= 0.2:
			facet.append(p)
	draw_colored_polygon(body, EARTH)
	draw_colored_polygon(facet, EARTH_DARK)
	var l := 640 - ISLAND_HALF
	var r := 640 + ISLAND_HALF
	draw_colored_polygon(PackedVector2Array([Vector2(l - 6, top + 2), Vector2(l + 6, top - 8), Vector2(r - 6, top - 8),
		Vector2(r + 6, top + 2), Vector2(r - 4, top + 9), Vector2(l + 4, top + 9)]), GRASS.darkened(0.14))
	draw_colored_polygon(PackedVector2Array([Vector2(l + 4, top - 3), Vector2(l + 10, top - 8), Vector2(r - 10, top - 8),
		Vector2(r - 4, top - 3)]), GRASS)
	# SHAPESHIFTERS carved in gold in the cliff.
	var xs1 := letter_centers(LINE1, 640, LINE1_UNIT, 1.0)
	for k in LINE1.length():
		var at := Vector2(xs1[k], top + 58.0)
		_glyph(LINE1[k], at + Vector2(0, LINE1_UNIT * 0.22), LINE1_UNIT, Color(0.07, 0.03, 0.1, 0.9))
		_glyph(LINE1[k], at, LINE1_UNIT, GOLD)
	# Firs, the cottage, and DUEL in earth and grass, squashing as it lands.
	_fir(Vector2(l + 26, top), 0.8)
	_fir(Vector2(l + 54, top), 1.15)
	_cottage(Vector2(r - 40, top))
	var xs2 := letter_centers(LINE2, 640, DUEL_UNIT, 0.9)
	var land := _squash(t - LAND_AT, 0.18)
	var d := DUEL_UNIT * 0.3
	for k in LINE2.length():
		draw_set_transform(base + Vector2(xs2[k], top), 0.0, land)
		_glyph(LINE2[k], Vector2(d * 0.8, d * 0.45), DUEL_UNIT, EARTH_DARK)
		_glyph(LINE2[k], Vector2(0, -d * 0.6), DUEL_UNIT, GRASS)
		_glyph(LINE2[k], Vector2.ZERO, DUEL_UNIT, EARTH)
	draw_set_transform(base)
	if t > 0.9:
		_creature()
	# Particles, then clouds drifting in front of the island's foot.
	for p in _parts:
		var k: float = 1.0 - p.age / p.life
		if p.get("rock", false):
			_floating_rock(p.pos, p.size)
		elif p.get("star", false):
			Icons.star(self, p.pos, p.size * k, Color(p.col, k))
		else:
			Shapes.circle(self, p.pos, p.size * (0.4 + 0.6 * k), Color(p.col, p.col.a * k))
	draw_set_transform(Vector2.ZERO)
	var sky := preload("res://scripts/ui/day_night_sky.gd")
	sky.cloud(self, Vector2(400 + sin(clock * 0.3) * 30.0, 640), 0.9, CLOUD)
	sky.cloud(self, Vector2(920 + sin(clock * 0.25 + 2.0) * 34.0, 690), 1.1, CLOUD)
	if waiting:
		_start_prompt(clampf(_idle / 0.4, 0.0, 1.0), 1.0 + 0.05 * sin(_idle * 4.0))
	elif _prompt_leaving and t < 0.25:
		# Pressed: the medallion swells and fades as the island breaks through.
		_start_prompt(1.0 - t / 0.25, 1.0 + t * 1.6)


## The start medallion while the title waits: a gold play mark in a dark disc,
## with a ripple inviting the first tap.
func _start_prompt(alpha: float, scale: float) -> void:
	var c := Vector2(640, 360)
	var r := 40.0 * scale
	if waiting:
		var k := fmod(_idle * 0.7, 1.0)
		Shapes.ring(self, c, r + 6.0 + k * 46.0, 3.0, Color(GOLD, 0.6 * (1.0 - k) * alpha))
	Shapes.circle(self, c, r, Color(Color("30233e"), 0.88 * alpha))
	Shapes.ring(self, c, r, 3.0, Color(GOLD, alpha))
	var s := r * 0.42
	draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.7, -s), c + Vector2(s * 1.1, 0), c + Vector2(-s * 0.7, s)]),
		Color(GOLD, alpha))


# --- The perched creature -----------------------------------------------------------

func _shift_steps() -> int:
	return int(maxf(0.0, t - 0.9) / IDLE_SHIFT)


## Where the creature stands: on the D.
func _perch() -> Vector2:
	var xs := letter_centers(LINE2, 640, DUEL_UNIT, 0.9)
	return Vector2(xs[0] - 10.0, FRAME_ANCHOR.y + lift() - DUEL_UNIT * 5.0 - 8.0)


## A rabbit, then its chain of most likely outcomes, hopping as it changes.
func _creature() -> void:
	var steps := _shift_steps()
	var id := "rabbit"
	for i in steps:
		id = CreatureDB.outcomes(id)[0].id
	var age := t - 0.9 - steps * IDLE_SHIFT
	var scale := Vector2.ONE
	var hop := 0.0
	if age < 0.4:
		scale = _squash(age, 0.35)
		hop = sin(minf(age / 0.3, 1.0) * PI) * 10.0
	Shapes.set_transform(self, _shake() + _perch() + Vector2(0, -19.0 - hop), 0.0, scale)
	Icons.creature(self, id, Vector2.ZERO, 20.0)
	Shapes.set_transform(self, _shake())


# --- Props --------------------------------------------------------------------------

func _floating_rock(p: Vector2, r: float) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(-r, -r * 0.3), p + Vector2(r, -r * 0.3), p + Vector2(r * 0.3, r * 1.2)]), EARTH)
	draw_colored_polygon(PackedVector2Array([p + Vector2(r * 0.2, -r * 0.3), p + Vector2(r, -r * 0.3), p + Vector2(r * 0.3, r * 1.2)]), EARTH_DARK)
	draw_rect(Rect2(p + Vector2(-r, -r * 0.3 - 3), Vector2(r * 2.0, 3)), GRASS)


func _bird(p: Vector2, s: float) -> void:
	var flap := sin(t * 9.0 + p.x * 0.01) * 5.0 * s
	draw_polyline(PackedVector2Array([p + Vector2(-9, -flap) * s, p + Vector2(0, 2) * s, p + Vector2(9, -flap) * s]), Color("3c3046"), 2.5 * s, true)


func _fir(base: Vector2, s: float) -> void:
	draw_rect(Rect2(base + Vector2(-3, -12) * s, Vector2(6, 12) * s), EARTH_DARK)
	for i in 3:
		var y := -10.0 - i * 16.0
		var w := 22.0 - i * 5.0
		draw_colored_polygon(PackedVector2Array([base + Vector2(-w, y) * s, base + Vector2(w, y) * s, base + Vector2(0, y - 26) * s]),
			Color("3f6b3a") if i % 2 == 0 else Color("4c7a43"))


func _cottage(base: Vector2) -> void:
	draw_rect(Rect2(base + Vector2(-20, -30), Vector2(40, 30)), Color("c9b58b"))
	draw_rect(Rect2(base + Vector2(6, -30), Vector2(14, 30)), Color("b09a70"))
	draw_colored_polygon(PackedVector2Array([base + Vector2(-26, -28), base + Vector2(0, -52), base + Vector2(26, -28)]), Color("805544"))
	draw_rect(Rect2(base + Vector2(-6, -16), Vector2(10, 16)), EARTH_DARK)
	draw_rect(Rect2(base + Vector2(10, -50), Vector2(6, 12)), Color("805544").darkened(0.2))
	# A thread of smoke from the chimney.
	for i in 3:
		var k := fmod(t * 0.5 + i / 3.0, 1.0)
		Shapes.circle(self, base + Vector2(13 + sin(k * 6.0 + i) * 6.0 + k * 14.0, -56 - k * 50.0), 4.0 + k * 6.0, Color(1, 1, 1, 0.55 * (1.0 - k)))


## Squash and stretch `age` seconds after a landing, as an (x, y) scale.
static func _squash(age: float, amount: float) -> Vector2:
	if age < 0.0:
		return Vector2.ONE
	var s := amount * exp(-age * 8.0) * cos(age * 22.0)
	return Vector2(1.0 + s, 1.0 - s)


# --- Lettering ----------------------------------------------------------------------
# Every letter is a set of flat pieces on a grid 4 units wide (I: 1) and 5
# high, with chamfered corners like the islands' cut rock.

static func _r(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


static func _tri(a: Vector2, b: Vector2, c: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, b, c])


static func glyph_pieces() -> Dictionary:
	var bowl := [_r(0, 0, 1, 5), _r(1, 0, 3, 1), _tri(Vector2(3, 0), Vector2(4, 1), Vector2(3, 1)), _r(3, 1, 4, 2),
		_tri(Vector2(3, 2), Vector2(4, 2), Vector2(3, 3)), _r(1, 2, 3, 3)]
	return {
		"S": [_r(1, 0, 4, 1), _tri(Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)), _r(0, 1, 1, 2),
			_tri(Vector2(0, 2), Vector2(1, 2), Vector2(1, 3)), _r(1, 2, 3, 3), _tri(Vector2(3, 2), Vector2(4, 3), Vector2(3, 3)),
			_r(3, 3, 4, 4), _tri(Vector2(3, 4), Vector2(4, 4), Vector2(3, 5)), _r(0, 4, 3, 5)],
		"H": [_r(0, 0, 1, 5), _r(3, 0, 4, 5), _r(1, 2, 3, 3)],
		"A": [_r(1, 0, 3, 1), _tri(Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)), _tri(Vector2(3, 0), Vector2(4, 1), Vector2(3, 1)),
			_r(0, 1, 1, 5), _r(3, 1, 4, 5), _r(1, 2.3, 3, 3.3)],
		"P": bowl,
		"E": [_r(0, 0, 1, 5), _r(1, 0, 4, 1), _r(1, 2, 3.4, 3), _r(1, 4, 4, 5)],
		"I": [_r(0, 0, 1, 5)],
		"F": [_r(0, 0, 1, 5), _r(1, 0, 4, 1), _r(1, 2, 3.4, 3)],
		"T": [_r(0, 0, 4, 1), _r(1.5, 1, 2.5, 5)],
		"R": bowl + [PackedVector2Array([Vector2(1.9, 3), Vector2(3.1, 3), Vector2(4, 5), Vector2(2.8, 5)])],
		"D": [_r(0, 0, 1, 5), _r(1, 0, 3, 1), _tri(Vector2(3, 0), Vector2(4, 1), Vector2(3, 1)), _r(3, 1, 4, 4),
			_tri(Vector2(3, 4), Vector2(4, 4), Vector2(3, 5)), _r(1, 4, 3, 5)],
		"U": [_r(0, 0, 1, 4), _r(3, 0, 4, 4), _tri(Vector2(0, 4), Vector2(1, 4), Vector2(1, 5)),
			_tri(Vector2(3, 4), Vector2(4, 4), Vector2(3, 5)), _r(1, 4, 3, 5)],
		"L": [_r(0, 0, 1, 5), _r(1, 4, 4, 5)],
	}


static func _width(c: String) -> float:
	return 1.0 if c == "I" else 4.0


## Centre of each letter's baseline for `text` centred on center_x.
static func letter_centers(text: String, center_x: float, unit: float, gap: float) -> Array:
	var total := 0.0
	for i in text.length():
		total += _width(text[i]) + (gap if i > 0 else 0.0)
	var x := center_x - total * unit * 0.5
	var result := []
	for i in text.length():
		result.append(x + _width(text[i]) * unit * 0.5)
		x += (_width(text[i]) + gap) * unit
	return result


## Letter c with the middle of its baseline at `at`.
func _glyph(c: String, at: Vector2, unit: float, col: Color) -> void:
	var origin := at + Vector2(-_width(c) * unit * 0.5, -5.0 * unit)
	for piece: PackedVector2Array in _glyphs[c]:
		var pts := PackedVector2Array()
		for p in piece:
			pts.append(origin + p * unit)
		draw_colored_polygon(pts, col)
