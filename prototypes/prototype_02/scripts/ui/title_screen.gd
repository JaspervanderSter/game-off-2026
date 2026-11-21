class_name TitleScreen
extends Node2D
## The menu: the game's title forms in the map's sky, above the islands
## (playtest decision, 21 November 2026). Seventeen creature tokens each run
## through their own transformation chain (the most likely outcome each time),
## then turn into a letter of SHAPESHIFTERS (blessed, blue) or DUEL (hexed, red)
## drawn in thick vector strokes, with the last creature perched on top. Then
## the island medallion, the only control, appears under the title: the world
## map scrolls the camera down to the islands (world_map.gd). A click or a key
## during the animation finishes it at once.
## Design: docs/design/Prototype 02.md, "Sky, sound and entry point".

const LINE1 := "SHAPESHIFTERS"
const LINE2 := "DUEL"
const CREATURES := ["skunk", "hedgehog", "archer", "peacock", "eagle", "snake", "guardian", "cleric", "frost_mage",
	"turtle", "rabbit", "rhino", "spearman", "duelist", "wolf", "berserker", "leopard"]
const BLUE := Color("8cb8ff")
const RED := Color("ff7a66")
const INK := Color("1a100a")
const START := 0.2 # tokens pop in
const STEP := 0.42 # seconds between two transformations of a token
const STAGGER := 0.07 # each token starts a little after the previous one
const MEDALLION_DELAY := 0.5 # after the last letter
const MEDALLION_RADIUS := 44.0
const LINE1_STEP := 64.0
const LINE2_STEP := 80.0
const LINE1_HEIGHT := 56.0
const LINE2_HEIGHT := 70.0
const DESIGN_WIDTH := 1100.0 # narrower screens shrink the title
## Letters on a 4 x 6 grid, as strokes of points.
const STROKES := {
	"S": [[Vector2(4, 0.6), Vector2(3, 0), Vector2(1, 0), Vector2(0, 1), Vector2(0, 2), Vector2(1, 3), Vector2(3, 3), Vector2(4, 4), Vector2(4, 5), Vector2(3, 6), Vector2(1, 6), Vector2(0, 5.4)]],
	"H": [[Vector2(0, 0), Vector2(0, 6)], [Vector2(4, 0), Vector2(4, 6)], [Vector2(0, 3), Vector2(4, 3)]],
	"A": [[Vector2(0, 6), Vector2(2, 0), Vector2(4, 6)], [Vector2(1, 4), Vector2(3, 4)]],
	"P": [[Vector2(0, 6), Vector2(0, 0), Vector2(3, 0), Vector2(4, 1), Vector2(4, 2), Vector2(3, 3), Vector2(0, 3)]],
	"E": [[Vector2(4, 0), Vector2(0, 0), Vector2(0, 6), Vector2(4, 6)], [Vector2(0, 3), Vector2(3, 3)]],
	"I": [[Vector2(2, 0), Vector2(2, 6)], [Vector2(1, 0), Vector2(3, 0)], [Vector2(1, 6), Vector2(3, 6)]],
	"F": [[Vector2(4, 0), Vector2(0, 0), Vector2(0, 6)], [Vector2(0, 3), Vector2(3, 3)]],
	"T": [[Vector2(0, 0), Vector2(4, 0)], [Vector2(2, 0), Vector2(2, 6)]],
	"R": [[Vector2(0, 6), Vector2(0, 0), Vector2(3, 0), Vector2(4, 1), Vector2(4, 2), Vector2(3, 3), Vector2(0, 3)], [Vector2(2, 3), Vector2(4, 6)]],
	"D": [[Vector2(0, 0), Vector2(0, 6), Vector2(2.4, 6), Vector2(4, 4.6), Vector2(4, 1.4), Vector2(2.4, 0), Vector2(0, 0)]],
	"U": [[Vector2(0, 0), Vector2(0, 5), Vector2(1, 6), Vector2(3, 6), Vector2(4, 5), Vector2(4, 0)]],
	"L": [[Vector2(0, 0), Vector2(0, 6), Vector2(4, 6)]],
}

var t := 0.0
var fx: FxLayer
var _fired := {}
var _silent := false


func _ready() -> void:
	fx = FxLayer.new()
	add_child(fx)


## Plays the title from its start.
func play() -> void:
	t = 0.0
	_fired.clear()
	fx.items.clear()
	_silent = false


## Finishes the animation at once, without its sounds and effects.
func finish() -> void:
	if t >= end_time():
		return
	_silent = true
	t = end_time() + 1.0
	fx.items.clear()
	for k in count():
		_fired[k] = true


func animating() -> bool:
	return t < medallion_time()


func count() -> int:
	return LINE1.length() + LINE2.length()


func letter_of(k: int) -> String:
	return LINE1[k] if k < LINE1.length() else LINE2[k - LINE1.length()]


func line_of(k: int) -> int:
	return 0 if k < LINE1.length() else 1


func steps(k: int) -> int:
	return 2 + k % 3


func step_time(k: int, j: int) -> float:
	return START + 0.3 + j * STEP + k * STAGGER


## When token k becomes its letter.
func turn_time(k: int) -> float:
	return step_time(k, steps(k))


func end_time() -> float:
	return turn_time(count() - 1)


func medallion_time() -> float:
	return end_time() + MEDALLION_DELAY


## Screen scale: the title shrinks on narrow (portrait) screens.
func view_scale() -> float:
	return minf(1.0, get_viewport_rect().size.x / DESIGN_WIDTH)


## Baseline centre of letter k, in this node's coordinates.
func slot(k: int) -> Vector2:
	var center := get_viewport_rect().size.x * 0.5
	var s := view_scale()
	if k < LINE1.length():
		return Vector2(center + (k - (LINE1.length() - 1) * 0.5) * LINE1_STEP * s, 250)
	return Vector2(center + (k - LINE1.length() - (LINE2.length() - 1) * 0.5) * LINE2_STEP * s, 430)


func medallion_center() -> Vector2:
	return Vector2(get_viewport_rect().size.x * 0.5, 570)


## The creature token k shows now: its chain of most likely outcomes.
func form_of(k: int) -> String:
	var id: String = CREATURES[k]
	for j in steps(k):
		if t >= step_time(k, j):
			id = CreatureDB.outcomes(id)[0].id
	return id


func advance(dt: float) -> void:
	t += dt
	for k in count():
		var at := slot(k) + Vector2(0, -34 * view_scale())
		for j in steps(k):
			var key := "%d-%d" % [k, j]
			if t >= step_time(k, j) and not _fired.has(key):
				_fired[key] = true
				if not _silent and j < steps(k) - 1:
					fx.add("merge", at)
					Sfx.play("ui/combine")
		if t >= turn_time(k) and not _fired.has(k):
			_fired[k] = true
			if not _silent:
				var bless := line_of(k) == 0
				fx.add("shift_bless" if bless else "shift_hex", at)
				Sfx.play("shapeshift/bless" if bless else "shapeshift/hex")
	if t >= medallion_time() and not _fired.has("medallion"):
		_fired["medallion"] = true
		if not _silent:
			Sfx.play("ui/difficulty_unlock")
	queue_redraw()


func _draw() -> void:
	var s := view_scale()
	for k in count():
		var team := line_of(k)
		if t < START + k * 0.03:
			continue
		var id := form_of(k)
		var base := slot(k)
		var height := (LINE1_HEIGHT if team == 0 else LINE2_HEIGHT) * s
		if t < turn_time(k):
			var pop := minf(1.0, (t - START - k * 0.03) / 0.2)
			Icons.token(self, id, base + Vector2(0, -height * 0.5), (26.0 if team == 0 else 32.0) * s * pop, team)
			continue
		var age := t - turn_time(k)
		var pop := 1.0 + 0.35 * sin(minf(age / 0.3, 1.0) * PI) * exp(-age * 3.0)
		Shapes.set_transform(self, base, 0.0, Vector2.ONE * pop)
		draw_vector_letter(self, letter_of(k), height, BLUE if team == 0 else RED)
		Shapes.set_transform(self, Vector2.ZERO)
		# The last creature perches on its letter, bobbing gently.
		var head := base + Vector2(0, -height * pop - 18 * s + sin(t * 2.0 + k) * 1.5)
		Icons.token(self, id, head, 14 * s, team)
	var show := smoothstep(medallion_time(), medallion_time() + 0.4, t)
	if show > 0.1:
		Icons.island_medallion(self, medallion_center(), MEDALLION_RADIUS * show, t, hot_medallion())


## True while the pointer is over the medallion.
func hot_medallion() -> bool:
	return not animating() and get_local_mouse_position().distance_to(medallion_center()) < MEDALLION_RADIUS


## A letter of thick rounded strokes standing on the origin: an ink outline,
## the colour, then a light core. Shared with tools/title_proposals.gd.
static func draw_vector_letter(ci: CanvasItem, c: String, height: float, fill: Color) -> void:
	var unit := height / 6.0
	var origin := Vector2(-2.0 * unit, -height)
	for layer in [[unit * 1.3, INK], [unit * 0.85, fill], [unit * 0.25, fill.lightened(0.45)]]:
		for stroke: Array in STROKES[c]:
			var points := PackedVector2Array()
			for p: Vector2 in stroke:
				points.append(origin + p * unit)
			ci.draw_polyline(points, layer[1], layer[0], true)
			for p in points:
				ci.draw_circle(p, layer[0] * 0.5, layer[1])
