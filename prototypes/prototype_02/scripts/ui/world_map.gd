extends Node2D
## The entire floating-island journey fits the viewport, without UI chrome or scrolling.
const SkyCycle := preload("res://scripts/ui/day_night_sky.gd")
const Island := preload("res://scripts/ui/map_island.gd")
const Bridge := preload("res://scripts/ui/map_bridge.gd")
signal path_point_appeared(stage: int, point_index: int)
const TRACE_DURATION := 3.6
## After the trace, the new opponent springs out of the ground: a gold ring
## opens at the end of the path, the opponent jumps out of it (hidden below the
## ground line while it rises) with a squash and stretch, and bits themed on its
## island fly out. It becomes playable once it stands.
const APPEAR_DURATION := 0.8
const REVEAL_DURATION := TRACE_DURATION + APPEAR_DURATION
const RISE_START := 0.12 # the ground opens first
const RISE_TIME := 0.42
const BURST_DURATION := 1.4 # the island bits settle after the opponent is playable
const RISE_TOP := 96.0 # room above the button for the clipped figure
const GOLD := Color("ddba70")
const LANDSCAPE_SIZE := Vector2(1280, 720)
const PORTRAIT_SIZE := Vector2(680, 1180)
const LANDSCAPE_ORIGINS := [Vector2(280, 425), Vector2(1000, 425), Vector2(640, 155)]
const PORTRAIT_ORIGINS := [Vector2(165, 860), Vector2(515, 860), Vector2(340, 240)]
const LANDSCAPE_SCALES := [0.72, 0.72, 0.62]
const PORTRAIT_SCALES := [0.55, 0.55, 0.72]
## Where each opponent stands on its island, in island coordinates and play
## order: forest clearings between the groves, the town's streets up to the
## keep, and the school courtyard up to the tower door.
const ZONE_SPOTS := [
	[Vector2(-200, 34), Vector2(-62, -50), Vector2(-48, 46), Vector2(52, -14), Vector2(92, -62)],
	[Vector2(-150, 30), Vector2(-66, 4), Vector2(58, 40), Vector2(108, -8), Vector2(-14, -30)],
	[Vector2(-88, 52), Vector2(-170, 6), Vector2(-100, -56), Vector2(130, -44), Vector2(46, 10)],
]
## Extra waypoints (island coordinates) for a road that must go around a
## landmark: the school road passes in front of the tower, never behind it.
const ROAD_VIAS := {13: [Vector2(-40, 26), Vector2(70, 22)]}
## The forest's last opponent guards the rope bridge, standing this far inland
## from its landing, towards this point (island coordinates).
const GUARD_INLAND := 36.0
const GUARD_INLAND_TOWARD := Vector2(0, 10)
## The king stands on top of his keep, and the crystal steps to the school leave
## from the keep's roof beside him (island coordinates).
const KING_SPOT := Vector2(-1, -118)
const STEPS_START := Vector2(-30, -128)
var _guard_spots := {} # zone -> island-coordinate spot, set by _layout
## Opponents further back on an island are drawn slightly smaller.
const DEPTH_SCALE := Vector2(0.86, 1.0)
const OPPONENT_SIZE := 27.0
var game
var sky: Node2D
var world: Node2D
var roads: Node2D
var ambience: MapAmbience
## The menu: the title forms in the sky above the islands. The camera pans
## between them (menu_blend 1 on the title, 0 on the islands) instead of
## changing scene.
var title: TitleScreen
var menu_blend := 0.0
var menu_target := 0.0
const PAN_TIME := 1.4
const SKY_PARALLAX := 4.0 # stars and clouds drift less than the islands
var _world_origin := Vector2.ZERO
var islands: Array[Node2D] = []
var bridges: Array[Node2D] = []
var buttons: Array[Button] = [] # one icon-only opponent per stage
var figures: Array[Control] = [] # each opponent's drawing, clipped at the ground while it rises
var map_scale := 1.0
var focus_stage := 0
var age := 0.0
var discovered: Array[int] = []
var revealing := -1
var reveal_elapsed := 0.0
## Stage springing out of the ground, kept after its reveal until its bits settle.
var appearing := -1
var appear_elapsed := 0.0
var _appear_sound_played := false
var _discovery_initialized := false
var _pending: Array[int] = []
var _paths := {} # destination stage -> evenly spaced points, in world coordinates
var _emitted_points := 0
var _layout_size := Vector2.ZERO
var _touch_index := -1
var _touch_start := Vector2.ZERO
var _touch_dragged := false
var _mouse_active := false
var _mouse_start := Vector2.ZERO
var _mouse_dragged := false

func _ready() -> void:
	visibility_changed.connect(_clear_touch)
	sky = SkyCycle.new()
	add_child(sky)
	world = Node2D.new()
	add_child(world)
	for index in 3:
		var island := Island.new()
		island.biome = index
		world.add_child(island)
		islands.append(island)
	for index in 2:
		var bridge := Bridge.new()
		bridge.z_index = 1
		world.add_child(bridge)
		bridges.append(bridge)
	roads = Node2D.new()
	roads.z_index = 1
	world.add_child(roads)
	roads.draw.connect(_draw_roads)
	for index in Journey.stage_count():
		var island := islands[stage_island(index)]
		var button := _button(island, Rect2(stage_offset(index) - Vector2(52, 54), Vector2(104, 108)))
		button.pressed.connect(_activate.bind(index))
		button.z_index = 2
		button.focus_entered.connect(_stage_focused.bind(index))
		button.draw.connect(_draw_stage.bind(index, button))
		buttons.append(button)
		var figure := Control.new()
		figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
		figure.draw.connect(_draw_figure.bind(index, figure))
		button.add_child(figure)
		figures.append(figure)
	_layout()
	ambience = MapAmbience.new()
	ambience.map = self
	add_child(ambience)
	title = TitleScreen.new()
	title.z_index = 3
	add_child(title)
	_apply_pan()

func _button(parent: Node, rect: Rect2) -> Button:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.flat = true
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	parent.add_child(button)
	return button

func _activate(index: int) -> void:
	if on_title():
		return
	if index < 0:
		game.show_menu()
	elif index < buttons.size() and buttons[index].visible and not buttons[index].disabled:
		game.choose_stage(index)

func focus_first() -> void:
	_sync_discovery()
	_layout()
	_focus_latest()

func _focus_latest() -> void:
	var target := 0
	for index in discovered:
		if not buttons[index].disabled:
			target = index
	focus_stage = target
	buttons[target].grab_focus()

func _sync_discovery() -> void:
	if not _discovery_initialized:
		# Reloaded progress is already known: do not replay old discovery sequences.
		for index in buttons.size():
			if game.journey.available(index):
				discovered.append(index)
		_discovery_initialized = true
	else:
		for index in discovered.duplicate():
			if not game.journey.available(index):
				discovered.erase(index)
		if revealing >= 0 and not game.journey.available(revealing):
			revealing = -1
		if appearing >= 0 and not game.journey.available(appearing):
			appearing = -1
		_pending = _pending.filter(func(index): return game.journey.available(index))
		for index in buttons.size():
			if game.journey.available(index) and index not in discovered and index != revealing and index not in _pending:
				_pending.append(index)
		_begin_next_reveal()
	_refresh_discovery()

func _begin_next_reveal() -> void:
	if revealing >= 0 or _pending.is_empty():
		return
	revealing = _pending.pop_front()
	reveal_elapsed = 0.0
	_emitted_points = 0

func visible_path_points(stage: int) -> int:
	if not _paths.has(stage):
		return 0
	if stage == revealing:
		if reveal_elapsed <= 0.0:
			return 0
		var progress := smoothstep(0.0, TRACE_DURATION, reveal_elapsed)
		return 1 + floori((_paths[stage].size() - 1) * progress)
	return _paths[stage].size() if stage in discovered else 0

func advance_discovery(dt: float) -> void:
	if appearing >= 0 and appearing != revealing:
		appear_elapsed += maxf(0.0, dt)
		if appear_elapsed >= BURST_DURATION:
			appearing = -1
	if revealing < 0:
		return
	var stage := revealing
	reveal_elapsed += maxf(0.0, dt)
	if reveal_elapsed >= TRACE_DURATION:
		if appearing != stage:
			appearing = stage
			_appear_sound_played = false
		appear_elapsed = reveal_elapsed - TRACE_DURATION
		if not _appear_sound_played and appear_elapsed >= RISE_START:
			_appear_sound_played = true
			Sfx.play("ui/map_opponent_appear")
	var count := visible_path_points(stage)
	if count > _emitted_points:
		for index in range(_emitted_points, count):
			path_point_appeared.emit(stage, index)
		_emitted_points = count
		# Catch up visually after a slow frame, but never stack a burst of taps.
		Sfx.play("ui/map_step")
	if reveal_elapsed >= TRACE_DURATION and stage not in discovered:
		discovered.append(stage)
	if reveal_elapsed >= REVEAL_DURATION:
		revealing = -1
		_begin_next_reveal()
		_refresh_discovery()
		_focus_latest()
	else:
		_refresh_discovery()
	roads.queue_redraw()

func _refresh_discovery() -> void:
	for index in buttons.size():
		var button := buttons[index]
		button.visible = index in discovered
		button.disabled = not button.visible or not game.journey.available(index) or index == revealing
		# Only a rising figure is cut at the ground line; a standing one never is.
		figures[index].clip_contents = _rise(_appear_age(index)) < 1.0

static func stage_island(index: int) -> int:
	return OpponentDB.zone(index)

## Spot of an opponent on its island, in island coordinates. The last opponent
## of the forest and of the town guards the bridge to the next island.
func stage_offset(index: int) -> Vector2:
	var zone := stage_island(index)
	if OpponentDB.is_boss(index) and _guard_spots.has(zone):
		return _guard_spots[zone]
	return ZONE_SPOTS[zone][index % OpponentDB.ZONE_SIZE]

## Size factor of an opponent from its depth on the island: 1 at the front.
func depth_scale(index: int) -> float:
	return lerpf(DEPTH_SCALE.x, DEPTH_SCALE.y, inverse_lerp(-62.0, 52.0, clampf(stage_offset(index).y, -62.0, 52.0)))

func stage_position(index: int) -> Vector2:
	return islands[stage_island(index)].position + stage_offset(index) * islands[stage_island(index)].scale

func _stage_focused(index: int) -> void:
	focus_stage = index

func _layout() -> void:
	var viewport_size := get_viewport_rect().size
	_layout_size = viewport_size
	var portrait := viewport_size.y > viewport_size.x
	var design_size := PORTRAIT_SIZE if portrait else LANDSCAPE_SIZE
	var origins: Array = PORTRAIT_ORIGINS if portrait else LANDSCAPE_ORIGINS
	var scales: Array = PORTRAIT_SCALES if portrait else LANDSCAPE_SCALES
	map_scale = minf(viewport_size.x / design_size.x, viewport_size.y / design_size.y)
	_world_origin = (viewport_size - design_size * map_scale) * 0.5
	world.position = _world_origin
	world.scale = Vector2.ONE * map_scale
	for index in islands.size():
		islands[index].position = origins[index]
		islands[index].scale = Vector2.ONE * scales[index]
	# The rope bridge lands on the shores, clear of the opponents; the crystal
	# steps rise from the keep's roof to the school courtyard.
	bridges[0].set_span(_bridge_bank(0, islands[1].position), _bridge_bank(1, islands[0].position), false)
	bridges[1].set_span(islands[1].position + STEPS_START * islands[1].scale, islands[2].position + Vector2(0, 74) * islands[2].scale, true)
	# The archdruid guards the rope bridge just inland of its landing, which
	# moves with the screen orientation; the king stands on his keep.
	var bank: Vector2 = (bridges[0].from_point - islands[0].position) / islands[0].scale
	_guard_spots[0] = bank + (GUARD_INLAND_TOWARD - bank).normalized() * GUARD_INLAND
	_guard_spots[1] = KING_SPOT
	for zone in islands.size():
		var spots: Array = []
		for i in OpponentDB.ZONE_SIZE:
			spots.append(stage_offset(zone * OpponentDB.ZONE_SIZE + i))
		islands[zone].spots = spots
	for index in buttons.size():
		var target_size := Vector2(140, 144) if portrait else Vector2(104, 108)
		buttons[index].size = target_size
		buttons[index].position = stage_offset(index) - target_size * 0.5
		buttons[index].pivot_offset = target_size * 0.5
		# The figure's box ends at the ground line (the button's centre).
		figures[index].position = Vector2(0, -RISE_TOP)
		figures[index].size = Vector2(target_size.x, target_size.y * 0.5 + RISE_TOP)
	_rebuild_paths()
	if revealing >= 0:
		_emitted_points = visible_path_points(revealing)
	_refresh_discovery()
	roads.queue_redraw()

func _bridge_bank(index: int, toward: Vector2) -> Vector2:
	var island := islands[index]
	var origin: Vector2 = island.position + Vector2(0, -12) * island.scale
	var direction := toward - origin
	var radii: Vector2 = Vector2(222, 66) * island.scale
	var factor := 1.0 / sqrt(pow(direction.x / radii.x, 2) + pow(direction.y / radii.y, 2))
	return origin + direction * factor

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	# Swipes cancel selection without moving the map, including over encounters.
	# Godot's emulated mouse events use device -1; ignore those to avoid a second tap.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1:
		get_viewport().set_input_as_handled()
		return
	# Use the same hit testing for mouse and touch, including after switching
	# input devices. Buttons still provide keyboard focus and hover feedback.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_active = true
			_mouse_start = event.position
			_mouse_dragged = false
		elif _mouse_active:
			_mouse_active = false
			if not _mouse_dragged:
				_tap_at(event.position)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and _mouse_active:
		if event.position.distance_to(_mouse_start) > 12.0 * map_scale:
			_mouse_dragged = true
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_touch_start = event.position
			_touch_dragged = false
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			if not _touch_dragged and not event.canceled:
				_tap_at(event.position)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		if event.index == _touch_index:
			var distance: Vector2 = event.position - _touch_start
			if distance.length() > 12.0 * map_scale:
				_touch_dragged = true
		get_viewport().set_input_as_handled()
		return

func _clear_touch() -> void:
	_touch_index = -1
	_touch_dragged = false
	_mouse_active = false
	_mouse_dragged = false

func _tap_at(point: Vector2) -> void:
	if on_title():
		# The title: a tap finishes its animation, then the medallion goes down to the islands.
		if title.animating():
			title.finish()
		elif point.distance_to(title.get_global_transform_with_canvas() * title.medallion_center()) < TitleScreen.MEDALLION_RADIUS:
			game.show_map()
		return
	var nearest := -1
	var nearest_distance := INF
	for index in buttons.size():
		var button := buttons[index]
		if button.disabled or not button.visible:
			continue
		var local := button.get_global_transform_with_canvas().affine_inverse() * point
		if Rect2(Vector2.ZERO, button.size).has_point(local):
			var center := button.get_global_transform_with_canvas() * (button.size * 0.5)
			var distance := point.distance_squared_to(center)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = index
	if nearest >= 0:
		_activate(nearest)

func _process(dt: float) -> void:
	if not is_visible_in_tree():
		return
	age += dt
	menu_blend = move_toward(menu_blend, menu_target, dt / PAN_TIME)
	if menu_blend > 0.0:
		title.advance(dt)
	else:
		# Discovery waits until the camera has reached the islands.
		advance_discovery(dt)
	if get_viewport_rect().size != _layout_size:
		_layout()
	_apply_pan()
	var state: Dictionary = sky.colors()
	for island in islands:
		island.cloud_color = state.cloud
	for index in buttons.size():
		buttons[index].queue_redraw()
		figures[index].queue_redraw()
	roads.queue_redraw()

## True while the camera looks, or is going, at the title above the islands.
func on_title() -> bool:
	return menu_target > 0.5


## Points the camera at the title; `restart` replays its animation.
func show_title(restart := false, instant := false) -> void:
	menu_target = 1.0
	if instant:
		menu_blend = 1.0
	if restart:
		title.play()
	get_viewport().gui_release_focus()
	_apply_pan()


## Points the camera at the islands: a pan from the title, or a cut.
func show_islands(instant := false) -> void:
	menu_target = 0.0
	if instant:
		menu_blend = 0.0
	title.finish()
	_apply_pan()


## The islands sit one screen below the title; the sky follows with parallax.
func _apply_pan() -> void:
	if title == null:
		return
	var height := get_viewport_rect().size.y
	var eased := smoothstep(0.0, 1.0, menu_blend)
	world.position = _world_origin + Vector2(0, eased * height)
	title.position = Vector2(0, (eased - 1.0) * height)
	title.visible = menu_blend > 0.0
	sky.scroll_offset = eased * height * SKY_PARALLAX


## Seconds since the ground began to open under a stage's opponent; INF once
## it has long stood there.
func _appear_age(index: int) -> float:
	return appear_elapsed if index == appearing else INF

## How far a rising opponent is out of the ground, 0 to 1 (overshooting into a
## small hop near the end).
func _rise(u: float) -> float:
	var v := clampf((u - RISE_START) / RISE_TIME, 0.0, 1.0)
	if v >= 1.0:
		return 1.0
	var c := 1.9 # ease-out-back overshoot
	return 1.0 + (c + 1.0) * pow(v - 1.0, 3) + c * pow(v - 1.0, 2)

func _draw_stage(index: int, button: Button) -> void:
	var p := button.size * 0.5
	var open: bool = game.journey.available(index)
	var won: bool = index in game.journey.completed
	var hot := open and (button.is_hovered() or button.has_focus())
	var k := depth_scale(index)
	var u := _appear_age(index)
	Shapes.ellipse(button, p, 32 * k * clampf(_rise(u), 0.0, 1.0), 10 * k, Color(0.12, 0.08, 0.06, 0.2))
	if u < BURST_DURATION:
		_draw_opening(button, p, k, u)
	if hot or won:
		Shapes.ellipse(button, p, (33 + sin(age * 2) * 2) * k, 12 * k, Color(GOLD, 0.45))
	if u < BURST_DURATION:
		_draw_burst(button, p, k, u, stage_island(index))
	if hot:
		var q := p + Vector2(0, -63 * k + sin(age * 3) * 3)
		button.draw_colored_polygon(PackedVector2Array([q + Vector2(-7, -7), q + Vector2(7, -7), q]), GOLD)

## Full-length opponents stand on the path spot; creatures remain on the board.
## A rising opponent starts below the ground line (its box ends there),
## stretches as it shoots up, hops slightly and lands with a short squash.
func _draw_figure(index: int, figure: Control) -> void:
	var u := _appear_age(index)
	var rise := _rise(u)
	if rise <= 0.0:
		return
	var k := depth_scale(index)
	var size := OPPONENT_SIZE * k
	var feet := buttons[index].size * 0.5 + Vector2(0, RISE_TOP)
	var v := clampf((u - RISE_START) / RISE_TIME, 0.0, 1.0)
	var stretch := 0.0
	if v < 1.0:
		stretch = 0.18 * sin(v * PI)
	elif u < BURST_DURATION:
		var w := u - RISE_START - RISE_TIME
		stretch = -0.14 * exp(-6.0 * w) * sin(w * 18.0)
	var squash := Vector2(1.0 / sqrt(1.0 + stretch), 1.0 + stretch)
	Shapes.set_transform(figure, feet + Vector2(0, (1.0 - rise) * size * 2.4), 0.0, squash)
	Icons.opponent(figure, OpponentDB.get_opponent(index).id,
		Vector2(0, -size * 0.94 + sin(age * 1.8 + index) * 1.2), size, age)
	Shapes.set_transform(figure, Vector2.ZERO)

## The ground opens under a rising opponent: a dark hole inside a widening gold
## ring; the hole closes once the opponent stands and the ring fades.
func _draw_opening(ci: CanvasItem, p: Vector2, k: float, u: float) -> void:
	var hole := smoothstep(0.0, RISE_START + 0.08, u) * (1.0 - smoothstep(RISE_START + RISE_TIME, APPEAR_DURATION + 0.2, u))
	if hole > 0.0:
		Shapes.ellipse(ci, p, 22 * k * hole, 7 * k * hole, Color(0.1, 0.06, 0.04, 0.55 * hole))
	var ring := smoothstep(0.0, 0.2, u)
	var fade := 1.0 - smoothstep(0.6, BURST_DURATION, u)
	if fade > 0.0:
		_ellipse_ring(ci, p, (14 + 16 * ring) * k, (4.5 + 5 * ring) * k, Color(GOLD, 0.95 * fade), 2.5 * k)
	# A shock wave leaves the ground as the opponent jumps out.
	var shock := (u - RISE_START) / 0.35
	if shock > 0.0 and shock < 1.0:
		_ellipse_ring(ci, p, (24 + 34 * shock) * k, (8 + 11 * shock) * k,
			Color(1.0, 0.95, 0.75, 0.9 * (1.0 - shock)), 3.0 * k * (1.0 - shock) + 1.0)

## Bits of the island fly out as the opponent springs up: leaves in the forest,
## stone chips and rolling dust in the town, violet and gold sparks at the school.
func _draw_burst(ci: CanvasItem, p: Vector2, k: float, u: float, zone: int) -> void:
	var w := u - RISE_START
	if w <= 0.0:
		return
	var life := BURST_DURATION - RISE_START
	var fade := 1.0 - smoothstep(life * 0.45, life, w)
	if zone == 1:
		var spread := 1.0 - exp(-4.0 * w)
		for i in 4:
			var side := -1.0 if i % 2 == 0 else 1.0
			var at := p + Vector2(side * (10 + spread * (18 + i * 6)), -3 - spread * (4 + i * 2)) * k
			Shapes.ellipse(ci, at, (5 + spread * 7) * k, (3.5 + spread * 4) * k, Color(0.85, 0.8, 0.7, 0.45 * fade))
	for i in 14:
		var a := lerpf(-PI * 0.92, -PI * 0.08, i / 13.0) + sin(i * 12.9898) * 0.12
		var speed := (95.0 + (i % 3) * 32.0) * k
		var gravity := 300.0 * k
		if zone == 2:
			speed *= 0.6
			gravity = -40.0 * k # sparks drift up
		var q := p + Vector2(0, -4 * k) + Vector2(cos(a), sin(a)) * speed * w + Vector2(0, 0.5 * gravity * w * w)
		var spin := w * 9.0 + i
		match zone:
			0:
				var leaf: Color = [Color("b5dc7a"), Color("f0d860"), Color("e8a24a")][i % 3]
				Shapes.ellipse(ci, q, 6.0 * k, 2.8 * k, Color(leaf, fade), spin)
			1:
				var stone: Color = [Color("eee8da"), Color("6f685d"), Color("d2c6ab")][i % 3]
				var r := (3.0 + (i % 2) * 1.4) * k
				var chip := PackedVector2Array()
				for corner in 4:
					var c := spin + corner * TAU / 4.0
					chip.append(q + Vector2(cos(c), sin(c)) * r * (1.0 if corner % 2 == 0 else 0.7))
				ci.draw_colored_polygon(chip, Color(stone, fade))
			_:
				var spark: Color = [GOLD, Color("fff3c4"), Color("d2b0ff")][i % 3]
				Icons.star(ci, q, (4.5 + 2.0 * sin(age * 12.0 + i)) * k, Color(spark, fade))

func _ellipse_ring(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in 41:
		var a := TAU * i / 40.0
		points.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	Shapes.polyline(ci, points, col, width)

func _append_curve(points: PackedVector2Array, a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> PackedVector2Array:
	for index in 33:
		points.append(a.bezier_interpolate(b, c, d, index / 32.0))
	return points

## A gently winding footpath through `stops`: each leg leaves and arrives
## level, so a change of depth reads as a bend rather than a straight cut.
func _winding(stops: Array[Vector2]) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(1, stops.size()):
		var a := stops[index - 1]
		var b := stops[index]
		var reach := Vector2((b.x - a.x) * 0.45, 0)
		points = _append_curve(points, a, a + reach, b - reach, b)
	return points

func _length(points: PackedVector2Array) -> float:
	var total := 0.0
	for index in range(1, points.size()):
		total += points[index - 1].distance_to(points[index])
	return total

func _sample(points: PackedVector2Array, distance: float) -> Vector2:
	for index in range(1, points.size()):
		var length := points[index - 1].distance_to(points[index])
		if distance <= length:
			return points[index - 1].lerp(points[index], distance / maxf(length, 0.001))
		distance -= length
	return points[-1]

func _rebuild_paths() -> void:
	_paths.clear()
	for stage in range(1, buttons.size()):
		var a := stage_position(stage - 1)
		var b := stage_position(stage)
		var points := PackedVector2Array()
		if stage_island(stage) != stage_island(stage - 1):
			var bridge: Node2D = bridges[stage_island(stage) - 1]
			var start: Vector2 = bridge.from_point
			var finish: Vector2 = bridge.to_point
			# The guard stands just before the bridge: a short, straight step on.
			points = _append_curve(points, a, a.lerp(start, 0.33), a.lerp(start, 0.66), start)
			for index in 65:
				points.append(bridge.point_at(index / 64.0))
			points.append_array(_winding([finish, b]))
		else:
			var island: Node2D = islands[stage_island(stage)]
			var stops: Array[Vector2] = [a]
			for via in ROAD_VIAS.get(stage, []):
				stops.append(island.position + via * island.scale)
			stops.append(b)
			points = _winding(stops)
		var trim_start: float = 26 * islands[stage_island(stage - 1)].scale.x
		var trim_end: float = 30 * islands[stage_island(stage)].scale.x
		var length := maxf(1.0, _length(points) - trim_start - trim_end)
		var count := clampi(roundi(length / 8.0), 6, 40)
		var dots := PackedVector2Array()
		for index in count:
			dots.append(_sample(points, trim_start + length * index / float(count - 1)))
		_paths[stage] = dots

func _draw_roads() -> void:
	for stage in range(1, buttons.size()):
		var count := visible_path_points(stage)
		if count == 0:
			continue
		var points: PackedVector2Array = _paths[stage]
		for index in count:
			var tip := stage == revealing and index == count - 1 and reveal_elapsed < TRACE_DURATION
			var color := GOLD if tip else Color("e4cb94")
			if tip:
				Shapes.circle(roads, points[index], 6.0, Color(GOLD, 0.16))
			# A quiet dark rim keeps the dots legible on pale wood and paving.
			Shapes.circle(roads, points[index], 3.5, Color(0.18, 0.13, 0.10, 0.55))
			Shapes.circle(roads, points[index], 2.3, color)
