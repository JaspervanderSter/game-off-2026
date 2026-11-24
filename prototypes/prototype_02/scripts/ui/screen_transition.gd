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
const Retained := preload("res://scripts/ui/retained_drawing.gd")
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
var _cloud_mesh: ArrayMesh
var _curtain: Node2D
var _bank: ColorRect
var _halves: Array[Node2D] = []
var _clouds: Array[Dictionary] = []
var _layout_size := Vector2.ZERO
var _painted_cloud := Color(-1, -1, -1)
var _blocker: Control


func _ready() -> void:
	_blocker = Control.new()
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.visible = false
	add_child(_blocker)
	_build_curtain()


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
	_update_curtain()


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
	_update_curtain()


## 0 open to 1 fully covered, then back to 0.
func coverage() -> float:
	if t < 0.0:
		return 0.0
	if t < COVER:
		return smoothstep(0.0, COVER, t)
	if t < COVER + HOLD:
		return 1.0
	return 1.0 - smoothstep(COVER + HOLD, COVER + HOLD + REVEAL, t)


## The only triangulation happens at creation. Every cloud and tone shares it.
func _build_curtain() -> void:
	var outline := SkyCycle.cloud_outline()
	var vertices := PackedVector3Array()
	for point in outline:
		vertices.append(Vector3(point.x, point.y, 0.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = Geometry2D.triangulate_polygon(outline)
	_cloud_mesh = ArrayMesh.new()
	_cloud_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_curtain = Node2D.new()
	_curtain.visible = false
	add_child(_curtain)
	_bank = ColorRect.new()
	_bank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.add_child(_bank)
	for layer in LAYERS.size():
		var s: float = LAYERS[layer][0]
		var spacing := CLOUD_WIDTH * s * 0.62
		for side: float in [-1.0, 1.0]:
			var half := Node2D.new()
			_curtain.add_child(half)
			_halves.append(half)
			for row in ROWS:
				var stagger := (row % 2) * spacing * 0.5
				for depth in 3:
					var flip := -1.0 if (row + depth + layer) % 2 == 0 else 1.0
					var node := Retained.make(half, func(canvas: Node2D): _paint_cloud(canvas, layer, flip))
					node.scale = Vector2.ONE * s * (0.92 + 0.08 * ((row + depth) % 3))
					_clouds.append({"node": node, "layer": layer, "side": side, "row": row,
						"depth": depth, "offset": side * (depth * spacing + stagger)})

## Re-record tint only when a new transition's sky colour changes. Mesh vertices
## and indices stay shared; drifting and resizing never rebuild a silhouette.
func _paint_cloud(canvas: Node2D, layer: int, flip: float) -> void:
	var base := _tone(layer)
	canvas.draw_mesh(_cloud_mesh, null, Transform2D(0.0, Vector2(0, 9)), base.darkened(0.12))
	canvas.draw_mesh(_cloud_mesh, null, Transform2D.IDENTITY, base)
	canvas.draw_mesh(_cloud_mesh, null, Transform2D(0.0, Vector2.ONE * 0.55, 0.0, Vector2(-16 * flip, -9)), base.lightened(0.2))

func _update_curtain() -> void:
	_curtain.visible = active()
	if not active():
		return
	var k := coverage()
	var size := get_viewport_rect().size
	_blocker.size = size
	_bank.size = size
	_bank.color = Color(_tone(0), smoothstep(0.9, 1.0, k))
	_bank.visible = k > 0.9
	for layer in LAYERS.size():
		var width: float = CLOUD_WIDTH * LAYERS[layer][0]
		var reach := smoothstep(0.0, LAYERS[layer][1], k)
		_halves[layer * 2].position.x = lerpf(-width * 0.55, size.x * 0.5 + width * 0.3, reach)
		_halves[layer * 2 + 1].position.x = lerpf(size.x + width * 0.55, size.x * 0.5 - width * 0.3, reach)
	for entry in _clouds:
		var node: Node2D = entry.node
		var drift := sin(t * 0.9 + entry.row * 1.7 + entry.layer * 2.3 + entry.depth) * 8.0
		node.position.x = entry.offset + drift * entry.side
		if size != _layout_size:
			node.position.y = size.y * (entry.row + 0.2) / (ROWS - 0.8) + entry.layer * 10.0
		if cloud != _painted_cloud:
			node.queue_redraw()
	_layout_size = size
	_painted_cloud = cloud


func _tone(layer: int) -> Color:
	var shade: float = LAYERS[layer][2]
	return cloud.lightened(shade) if shade > 0.0 else cloud.darkened(-shade)
