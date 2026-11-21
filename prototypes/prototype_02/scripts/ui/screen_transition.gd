class_name ScreenTransition
extends Node2D
## The cloud curtains between the journey map and a duel (playtest decision,
## 21 November 2026, chosen over an iris, a zoom, a vortex and three other
## cloud variations): three layers of clouds roll in from both sides, the ones
## at the back smaller, slower and a shade darker, meet in the middle and cover
## the screen; the screens are swapped while covered, then the curtains part. A
## soft whoosh (ui/clouds) plays each way and input waits until it is done.
## The clouds keep the game's flat look: the map's own cloud silhouette
## (day_night_sky.gd) in solid tones, a darker underside, the body and a light
## crest, tinted with the map's cloud colour of the moment.
## Lives on its own CanvasLayer above the map and the HUD (main.gd).

const COVER := 0.65
const HOLD := 0.1
const REVEAL := 0.65
const SkyCycle := preload("res://scripts/ui/day_night_sky.gd")
## Per layer, back to front: cloud scale (map cloud = 1), speed, shade.
const LAYERS := [[2.3, 0.86, -0.08], [2.8, 0.94, -0.03], [3.3, 1.0, 0.04]]
const ROWS := 8
const CLOUD_WIDTH := 182.0 # the map cloud's width at scale 1

var t := -1.0 # seconds since the transition began; negative when idle
var from := Vector2.ZERO
var to := Vector2.ZERO
var cloud := Color("d1dccf") # the sky's cloud colour when the transition began
var _swap := Callable()
var _swapped := false
var _blocker: Control


func _ready() -> void:
	_blocker = Control.new()
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.visible = false
	add_child(_blocker)


## Covers the screen with clouds, calls `swap` once covered, then parts them.
## `cover_at` and `reveal_at` (the opponent, the board) record where the
## transition starts and ends.
func play(cover_at: Vector2, reveal_at: Vector2, swap: Callable, cloud_colour := Color("d1dccf")) -> void:
	from = cover_at
	to = reveal_at
	cloud = cloud_colour.lerp(Color(0.96, 0.97, 0.97), 0.45)
	_swap = swap
	_swapped = false
	t = 0.0
	_blocker.size = get_viewport_rect().size
	_blocker.visible = true
	Sfx.play("ui/clouds")


func active() -> bool:
	return t >= 0.0


func _process(dt: float) -> void:
	if t < 0.0:
		return
	t += dt
	if t >= COVER and not _swapped:
		_swapped = true
		_swap.call()
		Sfx.play("ui/clouds")
	if t >= COVER + HOLD + REVEAL:
		t = -1.0
		_blocker.visible = false
	queue_redraw()


## 0 open to 1 fully covered, then back to 0.
func coverage() -> float:
	if t < 0.0:
		return 0.0
	if t < COVER:
		return smoothstep(0.0, COVER, t)
	if t < COVER + HOLD:
		return 1.0
	return 1.0 - smoothstep(COVER + HOLD, COVER + HOLD + REVEAL, t)


func _draw() -> void:
	if t < 0.0:
		return
	var k := coverage()
	var size := get_viewport_rect().size
	# Once the curtains overlap, a flat bank of the back clouds' tone closes
	# any gap between them.
	if k > 0.9:
		draw_rect(Rect2(Vector2.ZERO, size), Color(_tone(0), smoothstep(0.9, 1.0, k)))
	for layer in LAYERS.size():
		_layer(layer, k, size)


func _tone(layer: int) -> Color:
	var shade: float = LAYERS[layer][2]
	return cloud.lightened(shade) if shade > 0.0 else cloud.darkened(-shade)


## One map cloud in three flat tones: a darker underside, the body, a light crest.
func _cloud(p: Vector2, s: float, base: Color, flip: float) -> void:
	SkyCycle.cloud(self, p + Vector2(0, 9 * s), s, base.darkened(0.12))
	SkyCycle.cloud(self, p, s, base)
	SkyCycle.cloud(self, p + Vector2(-16 * s * flip, -9 * s), s * 0.55, base.lightened(0.2))


## One layer of both curtains: rows of clouds, each row three clouds deep, the
## front cloud leading and the others trailing outward.
func _layer(layer: int, k: float, size: Vector2) -> void:
	var s: float = LAYERS[layer][0]
	var speed: float = LAYERS[layer][1]
	var tone := _tone(layer)
	var width := CLOUD_WIDTH * s
	var spacing := width * 0.62
	# The curtains start fully off screen and ease in until they overlap.
	var reach := smoothstep(0.0, speed, k)
	for side: float in [-1.0, 1.0]:
		var lead: float = lerpf(-width * 0.55, size.x * 0.5 + width * 0.3, reach) if side < 0.0 \
			else lerpf(size.x + width * 0.55, size.x * 0.5 - width * 0.3, reach)
		for row in ROWS:
			var y := size.y * (row + 0.2) / (ROWS - 0.8) + layer * 10.0
			var stagger := (row % 2) * spacing * 0.5
			for depth in 3:
				var x: float = lead + side * (depth * spacing + stagger)
				var drift := sin(t * 0.9 + row * 1.7 + layer * 2.3 + depth) * 8.0
				var flip := -1.0 if (row + depth + layer) % 2 == 0 else 1.0
				_cloud(Vector2(x + drift * side, y), s * (0.92 + 0.08 * ((row + depth) % 3)), tone, flip)
