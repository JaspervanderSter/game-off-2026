extends Node2D
## A vertically extensible journey through three floating territories.
const SkyCycle := preload("res://scripts/ui/day_night_sky.gd")
const Island := preload("res://scripts/ui/map_island.gd")
const GOLD := Color("ddba70")
const ISLAND_ORIGINS := [Vector2(100, 1180), Vector2(-140, 700), Vector2(100, 220)]
const ISLAND_SCALES := [1.0, 0.88, 0.78]
const STAGE_ISLAND := [0, 0, 0, 1, 1, 1, 2]
const STAGE_OFFSETS := [Vector2(-78, 28), Vector2(28, -22), Vector2(133, 28), Vector2(-100, 25), Vector2(25, 24), Vector2(135, -10), Vector2(122, 25)]
const OPPONENTS := ["rabbit", "deer", "wolf", "guardian", "archer", "spearman", "hat2"]
const WORLD_HEIGHT := 1510.0
var game
var sky: Node2D
var scroll: ScrollContainer
var content: Control
var world: Node2D
var roads: Node2D
var chrome: Node2D
var islands: Array[Node2D] = []
var buttons: Array[Button] = [] # menu first, then the seven stage buttons
var map_scale := 1.0
var focus_stage := 0
var age := 0.0
var ui_scale := 1.0
var _layout_size := Vector2.ZERO
var _touch_index := -1
var _touch_start := Vector2.ZERO
var _touch_scroll := 0
var _touch_dragged := false
var _touch_in_map := false
var _needs_center := true

func _ready() -> void:
	visibility_changed.connect(_clear_touch)
	sky = SkyCycle.new()
	add_child(sky)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.scroll_deadzone = 12
	scroll.scroll_vertical_custom_step = 90
	add_child(scroll)
	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(content)
	world = Node2D.new()
	content.add_child(world)
	for index in 3:
		var island := Island.new()
		island.biome = index
		island.position = ISLAND_ORIGINS[index]
		island.scale = Vector2.ONE * ISLAND_SCALES[index]
		world.add_child(island)
		islands.append(island)
	roads = Node2D.new()
	roads.z_index = 1
	world.add_child(roads)
	roads.draw.connect(_draw_roads)
	chrome = Node2D.new()
	chrome.draw.connect(_draw_chrome)
	add_child(chrome)
	var back := _button(self, Rect2(22, 12, 72, 64), "Menu · Esc")
	back.pressed.connect(_activate.bind(-1))
	buttons.append(back)
	for index in STAGE_OFFSETS.size():
		var island := islands[STAGE_ISLAND[index]]
		var button := _button(island, Rect2(STAGE_OFFSETS[index] - Vector2(52, 54), Vector2(104, 108)), Journey.NAMES[index])
		button.pressed.connect(_activate.bind(index))
		button.z_index = 2
		button.focus_entered.connect(_stage_focused.bind(index))
		button.draw.connect(_draw_stage.bind(index, button))
		buttons.append(button)
	_layout()

func _button(parent: Node, rect: Rect2, hint: String) -> Button:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.flat = true
	button.tooltip_text = hint
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	parent.add_child(button)
	return button

func _activate(index: int) -> void:
	if index < 0:
		game.show_menu()
	else:
		game.choose_stage(index)

func focus_first() -> void:
	var next := 0
	var found := false
	for index in STAGE_OFFSETS.size():
		buttons[index + 1].disabled = not game.journey.available(index)
		if not found and game.journey.available(index) and index not in game.journey.completed:
			next = index
			found = true
	focus_stage = next
	for index in islands.size():
		islands[index].hero_tier = index if index == STAGE_ISLAND[next] else -1
	_layout()
	buttons[next + 1].grab_focus()
	_reveal_stage.call_deferred(next)

func stage_position(index: int) -> Vector2:
	return islands[STAGE_ISLAND[index]].position + STAGE_OFFSETS[index] * ISLAND_SCALES[STAGE_ISLAND[index]]

func _stage_focused(index: int) -> void:
	focus_stage = index
	# Do not move an already-visible button between mouse press and release.
	var y := stage_position(index).y * map_scale - scroll.scroll_vertical
	var margin := 80.0 * map_scale
	if y < margin or y > scroll.size.y - margin:
		_reveal_stage.call_deferred(index)

func _reveal_stage(index: int) -> void:
	# Centre the destination after the ScrollContainer has measured its content.
	var target := stage_position(index).y * map_scale - scroll.size.y * 0.5
	scroll.scroll_vertical = roundi(target)

func _layout() -> void:
	var viewport_size := get_viewport_rect().size
	_layout_size = viewport_size
	_needs_center = true
	var portrait := viewport_size.y > viewport_size.x
	map_scale = viewport_size.x / (600.0 if portrait else 1120.0)
	ui_scale = 2.3 if portrait else 1.0
	if not portrait:
		map_scale = minf(map_scale, viewport_size.y / 760.0)
	scroll.position = Vector2(12, 88) * ui_scale
	scroll.size = viewport_size - Vector2(24, 104) * ui_scale
	content.custom_minimum_size = Vector2(scroll.size.x - 16, WORLD_HEIGHT * map_scale)
	world.position = Vector2((scroll.size.x - 16) * 0.5, 0)
	world.scale = Vector2.ONE * map_scale
	buttons[0].position = Vector2(22, 12) * ui_scale
	buttons[0].size = Vector2(72, 64) * ui_scale
	for index in islands.size():
		islands[index].position.x = ISLAND_ORIGINS[index].x * (0.35 if portrait else 1.0)
	chrome.queue_redraw()
	roads.queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	# Handle taps and swipes together, including drags that start on an encounter.
	# Godot's emulated mouse events use device -1; ignore those to avoid a second tap.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_touch_start = event.position
			_touch_scroll = scroll.scroll_vertical
			_touch_dragged = false
			_touch_in_map = scroll.get_global_rect().has_point(event.position)
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			if not _touch_dragged and not event.canceled:
				_tap_at(event.position)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		if event.index == _touch_index:
			var distance: Vector2 = event.position - _touch_start
			if distance.length() > 12.0 * ui_scale:
				_touch_dragged = true
			if _touch_dragged and _touch_in_map:
				scroll.scroll_vertical = _touch_scroll - roundi(distance.y)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_PAGEUP:
				scroll.scroll_vertical -= roundi(scroll.size.y * 0.8)
			KEY_PAGEDOWN:
				scroll.scroll_vertical += roundi(scroll.size.y * 0.8)
			KEY_HOME:
				scroll.scroll_vertical = 0
			KEY_END:
				scroll.scroll_vertical = roundi(content.custom_minimum_size.y)
			_:
				return
		get_viewport().set_input_as_handled()

func _clear_touch() -> void:
	_touch_index = -1
	_touch_dragged = false

func _tap_at(point: Vector2) -> void:
	for index in buttons.size():
		var button := buttons[index]
		if button.disabled:
			continue
		if index > 0 and not scroll.get_global_rect().has_point(point):
			continue
		var local := button.get_global_transform_with_canvas().affine_inverse() * point
		if Rect2(Vector2.ZERO, button.size).has_point(local):
			_activate(index - 1)
			return

func _process(dt: float) -> void:
	if not is_visible_in_tree():
		return
	age += dt
	if get_viewport_rect().size != _layout_size:
		_layout()
	# Container measurements complete after layout. Recentring before that would
	# clamp against the previous scrollbar range, especially on device rotation.
	if _needs_center and absf(scroll.get_v_scroll_bar().max_value - content.custom_minimum_size.y) < 1.0:
		_needs_center = false
		_reveal_stage(focus_stage)
	sky.scroll_offset = scroll.scroll_vertical
	var state: Dictionary = sky.colors()
	for island in islands:
		island.cloud_color = state.cloud
	for button in buttons:
		button.queue_redraw()
	roads.queue_redraw()
	chrome.queue_redraw()

func _draw_stage(index: int, button: Button) -> void:
	var p := button.size * 0.5
	var open: bool = game.journey.available(index)
	var won: bool = index in game.journey.completed
	var hot := open and (button.is_hovered() or button.has_focus())
	Shapes.ellipse(button, p + Vector2(0, 27), 32, 10, Color(0.12, 0.08, 0.06, 0.2))
	if hot or won:
		Shapes.ellipse(button, p + Vector2(0, 27), 33 + sin(age * 2) * 2, 12, Color(GOLD, 0.45))
	if OPPONENTS[index].begins_with("hat"):
		Icons.difficulty_hat(button, 2, p + Vector2(0, -4 + sin(age * 1.8) * 2), 31, age)
	else:
		Icons.creature(button, OPPONENTS[index], p + Vector2(0, -6), 28)
	if won:
		Icons.star(button, p + Vector2(0, 40), 9, GOLD)
	elif not open:
		var q := p + Vector2(0, 35)
		Shapes.arc(button, q, 5, PI, TAU, 16, Color("eee0bd"), 2)
		button.draw_rect(Rect2(q + Vector2(-7, 0), Vector2(14, 10)), Color("eee0bd"))
	if hot:
		var q := p + Vector2(0, -50 + sin(age * 3) * 3)
		button.draw_colored_polygon(PackedVector2Array([q + Vector2(-7, -7), q + Vector2(7, -7), q]), GOLD)

func _draw_roads() -> void:
	for road in Journey.ROADS:
		var a := stage_position(road.x)
		var b := stage_position(road.y)
		var different_islands: bool = STAGE_ISLAND[road.x] != STAGE_ISLAND[road.y]
		var open: bool = road.x in game.journey.completed
		var length := a.distance_to(b)
		var count := maxi(4, roundi(length / 17.0))
		for i in count:
			var p := a.lerp(b, (i + 0.5) / count)
			# Suppress dots directly beneath the opponent illustrations.
			if p.distance_to(a) < 38 or p.distance_to(b) < 38:
				continue
			var color := GOLD if open else Color("d7c5a1")
			if different_islands:
				color = Color("b8a0d4") if STAGE_ISLAND[road.y] == 2 else Color("b69d77")
				if i % 2 == 0:
					roads.draw_colored_polygon(PackedVector2Array([p + Vector2(-10, 0), p + Vector2(0, -4), p + Vector2(10, 0), p + Vector2(0, 7)]), Color(color, 0.95 if open else 0.4))
			else:
				Shapes.circle(roads, p, 2.5, Color(color, 1.0 if open else 0.5))

func _draw_chrome() -> void:
	var size := get_viewport_rect().size
	Shapes.set_transform(chrome, Vector2.ZERO, 0.0, Vector2.ONE * ui_scale)
	size /= ui_scale
	chrome.draw_rect(Rect2(0, 0, size.x, 84), Color("291f1b"))
	chrome.draw_rect(Rect2(0, 82, size.x, 2), Color("644a31"))
	Icons.arrow_right(chrome, Vector2(58, 45), -20, GOLD)
	Icons.world_map(chrome, Vector2(size.x * 0.5, 42), 23)
	if buttons[0].is_hovered() or buttons[0].has_focus():
		Shapes.arc(chrome, Vector2(58, 43), 30, 0, TAU, 48, GOLD, 2)
	var right := size.x - 32
	for index in STAGE_OFFSETS.size():
		var p := Vector2(right - (6 - index) * 22, 42)
		if index in game.journey.completed:
			Icons.star(chrome, p, 6.5, GOLD)
		else:
			Shapes.circle(chrome, p, 3.5, Color("6b5947"))
	Shapes.set_transform(chrome, Vector2.ZERO)
