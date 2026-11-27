extends PanelContainer
## Hidden developer panel tuning the map's camera (MapCameraTuning): opened
## with Ctrl+Shift+C, or a three-finger tap on the map or the title. Like the
## FPS counter it is a tool, not part of the game's interface, so it may use
## words. Every change applies at once and is saved on the device.

const FONT_SIZE := 26
const GOLD := Color(1.0, 0.87, 0.55)

var _rows := {}
var _building := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.06, 0.04, 0.09, 0.93)
	panel.border_color = Color(GOLD, 0.6)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(10)
	panel.set_content_margin_all(16)
	add_theme_stylebox_override("panel", panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var title := _label("Map camera")
	column.add_child(title)
	_choice(column, "scope", "Zoom on", ["Mobile only", "Always", "Off"])
	_slider(column, "map_zoom", "Map zoom", 1.0, 3.5, 0.1, "x%.1f")
	_choice(column, "follow", "Follow", ["Smooth damp", "Lerp"])
	_slider(column, "follow_time", "Follow time", 0.2, 3.0, 0.1, "%.1f s")
	_toggle(column, "pan", "Pan by dragging")
	_toggle(column, "gestures", "Pinch / wheel zoom")
	_slider(column, "max_zoom", "Max zoom", 1.5, 6.0, 0.1, "x%.1f")
	_slider(column, "idle_return", "Return after", 1.0, 15.0, 0.5, "%.1f s")
	_slider(column, "title_fill", "Title fill", 0.0, 1.0, 0.05, "%.2f")
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	var reset := _button("Defaults")
	reset.pressed.connect(_on_reset)
	buttons.add_child(reset)
	var close := _button("Close")
	close.pressed.connect(hide)
	buttons.add_child(close)
	_refresh()
	hide()


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh()
		reset_size()
		# Fill most of the screen, whatever its shape, to stay readable.
		var screen := get_viewport_rect().size
		scale = Vector2.ONE * clampf(minf(screen.x * 0.94 / size.x, screen.y * 0.94 / size.y), 0.5, 3.0)
		position = Vector2((screen.x - size.x * scale.x) * 0.5, 16)


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", GOLD)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.custom_minimum_size = Vector2(0, 56)
	return button


func _row(column: Container, caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := _label(caption)
	label.custom_minimum_size = Vector2(210, 0)
	row.add_child(label)
	column.add_child(row)
	return row


func _choice(column: Container, key: String, caption: String, options: Array) -> void:
	var row := _row(column, caption)
	var group := ButtonGroup.new()
	var buttons: Array[Button] = []
	for index in options.size():
		var button := _button(options[index])
		button.toggle_mode = true
		button.button_group = group
		button.toggled.connect(func(on: bool):
			if on and not _building:
				MapCameraTuning.set_value(key, index))
		row.add_child(button)
		buttons.append(button)
	_rows[key] = buttons


func _slider(column: Container, key: String, caption: String, low: float, high: float, step: float, shown: String) -> void:
	var row := _row(column, caption)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size = Vector2(360, 56)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(GOLD, 0.35)
	grabber.content_margin_top = 8
	grabber.content_margin_bottom = 8
	slider.add_theme_stylebox_override("slider", grabber)
	row.add_child(slider)
	var readout := _label("")
	readout.custom_minimum_size = Vector2(100, 0)
	row.add_child(readout)
	slider.value_changed.connect(func(v: float):
		readout.text = shown % v
		if not _building:
			MapCameraTuning.set_value(key, v))
	_rows[key] = slider


func _toggle(column: Container, key: String, caption: String) -> void:
	var row := _row(column, caption)
	var box := CheckButton.new()
	box.focus_mode = Control.FOCUS_NONE
	box.custom_minimum_size = Vector2(0, 56)
	box.toggled.connect(func(on: bool):
		if not _building:
			MapCameraTuning.set_value(key, on))
	row.add_child(box)
	_rows[key] = box


func _refresh() -> void:
	_building = true
	for key in _rows:
		var control = _rows[key]
		var v = MapCameraTuning.value(key)
		if control is Array:
			control[clampi(int(v), 0, control.size() - 1)].button_pressed = true
		elif control is HSlider:
			control.value = float(v)
			control.value_changed.emit(control.value)
		elif control is CheckButton:
			control.button_pressed = bool(v)
	_building = false


func _on_reset() -> void:
	MapCameraTuning.reset()
	_refresh()
