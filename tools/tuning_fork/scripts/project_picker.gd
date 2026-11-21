class_name ProjectPicker
extends PanelContainer
## The project window, shown at start and by the folder button: the game
## folders opened before (most recent first), then those found beside the
## tool (the prototypes of this repository that hold sfx/). Clicking one opens
## it; a folder can also be chosen with the system dialog or dropped on the
## window. Definition: docs/Tool.md.

## The user picked `game` (not yet checked for sfx/).
signal chosen(game: String)
## The user removed `game` from the recent folders.
signal forgotten(game: String)
## The user went back to the project already open.
signal closed

const MAX_RECENT := 12
const ACCENT := Color(0.98, 0.72, 0.30)
const DIM := Color(1, 1, 1, 0.45)
const WARNING := Color(1.0, 0.62, 0.35)
const CARD := Color("23272f")
const CARD_HOVER := Color("2d323c")

var can_go_back := false

var _logo: TextureRect
var _back: Button
var _list: VBoxContainer
var _message: Label
var _dialog: FileDialog


func _init() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", _flat(Color("1d2026")))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 44)
	margin.add_theme_constant_override("margin_bottom", 28)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	add_child(margin)
	var row := HBoxContainer.new()
	margin.add_child(row)
	row.add_child(_spacer())
	var column := VBoxContainer.new()
	column.size_flags_horizontal = SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 2.4
	column.custom_minimum_size.x = 560
	column.add_theme_constant_override("separation", 16)
	row.add_child(column)
	row.add_child(_spacer())

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	_logo = TextureRect.new()
	_logo.texture = Icons.get_icon("fork", ACCENT, 48)
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_logo.custom_minimum_size = Vector2(48, 48)
	_logo.pivot_offset = Vector2(24, 44)
	header.add_child(_logo)
	var title := Label.new()
	title.text = "Tuning Fork"
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	_back = Button.new()
	_back.icon = Icons.get_icon("back", Color.WHITE, 22)
	_back.tooltip_text = "Back to the open project (Esc)"
	_back.flat = true
	_back.focus_mode = FOCUS_NONE
	_back.pressed.connect(func() -> void: closed.emit())
	header.add_child(_back)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)

	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_color_override("font_color", WARNING)
	column.add_child(_message)

	var open := Button.new()
	open.icon = Icons.get_icon("folder", ACCENT, 22)
	open.text = "Open a game folder"
	open.tooltip_text = "Any folder holding sfx/ or music/; or drop it on the window"
	open.custom_minimum_size.y = 52
	open.focus_mode = FOCUS_NONE
	open.alignment = HORIZONTAL_ALIGNMENT_LEFT
	open.add_theme_constant_override("h_separation", 14)
	for state in ["normal", "hover", "pressed"]:
		var box := _flat(CARD if state == "normal" else CARD_HOVER, 8)
		box.set_border_width_all(1)
		box.border_color = Color(ACCENT, 0.35 if state == "normal" else 0.7)
		box.content_margin_left = 14
		open.add_theme_stylebox_override(state, box)
	open.pressed.connect(func() -> void: _dialog.popup_centered_ratio(0.6))
	column.add_child(open)

	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.title = "Game folder (holding sfx/ or music/)"
	_dialog.dir_selected.connect(func(dir: String) -> void: chosen.emit(dir))
	add_child(_dialog)


## Lists `recent` then the `detected` folders not among them, and shows the
## window. `message` is a warning under the list.
func show_projects(recent: Array, detected: Array, back_allowed: bool, message := "", animate := true) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var cards: Array[Control] = []
	if not recent.is_empty():
		_list.add_child(_section("clock", "Recent"))
		for game: String in recent:
			cards.append(_card(game, true))
	var others := detected.filter(func(game: String) -> bool: return not recent.has(game))
	if not others.is_empty():
		_list.add_child(_section("search", "Found beside Tuning Fork"))
		for game: String in others:
			cards.append(_card(game, false))
	if cards.is_empty():
		var hint := Label.new()
		hint.text = "Open the game folder that holds sfx/ or music/"
		hint.add_theme_color_override("font_color", DIM)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.custom_minimum_size.y = 120
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_list.add_child(hint)
	if not recent.is_empty():
		_dialog.current_dir = str(recent[0]).get_base_dir()
	can_go_back = back_allowed
	_back.visible = back_allowed
	_message.text = message
	show()
	if animate:
		_ring()
		for i in cards.size():
			var alpha := cards[i].modulate.a
			cards[i].modulate.a = 0.0
			create_tween().tween_property(cards[i], "modulate:a", alpha, 0.18).set_delay(0.03 * i)


## Shows a warning under the list, with a short shake of the logo.
func show_message(text: String) -> void:
	_message.text = text
	_message.modulate.a = 0.0
	create_tween().tween_property(_message, "modulate:a", 1.0, 0.15)
	_ring()


## Opens the first folder among dropped paths.
func open_dropped(paths: PackedStringArray) -> void:
	for path in paths:
		if DirAccess.dir_exists_absolute(path):
			chosen.emit(path)
			return
	show_message("Drop a game folder (the one holding sfx/)")


## Game folders beside the tool: the prototypes, holding sfx/, of the nearest
## folder above `start` that holds prototypes/; newest (last by name) first.
## `start` defaults to the project folder, or the executable's when exported.
static func detect(start := "") -> Array[String]:
	if start == "":
		start = ProjectSettings.globalize_path("res://")
		if OS.has_feature("template"):
			start = OS.get_executable_path().get_base_dir()
	var found: Array[String] = []
	var dir := normalized(start)
	for i in 6:
		var prototypes := dir.path_join("prototypes")
		if DirAccess.dir_exists_absolute(prototypes):
			var folders := Array(DirAccess.get_directories_at(prototypes))
			folders.sort()
			folders.reverse()
			for folder: String in folders:
				if SoundLibrary.event_count(prototypes.path_join(folder)) >= 0 or not SoundLibrary.workspace_folders(prototypes.path_join(folder), "music").is_empty():
					found.append(prototypes.path_join(folder))
			break
		dir = dir.get_base_dir()
	return found


## `recent` with `game` first, without repeats, at most MAX_RECENT folders.
static func remember(recent: Array, game: String) -> Array[String]:
	var list: Array[String] = [normalized(game)]
	for other in recent:
		var path := normalized(str(other))
		if not list.has(path) and list.size() < MAX_RECENT:
			list.append(path)
	return list


static func normalized(path: String) -> String:
	return path.replace("\\", "/").simplify_path()


## The logo rings like a struck tuning fork.
func _ring() -> void:
	var tween := create_tween()
	for amount in [0.12, -0.09, 0.06, -0.035, 0.015, 0.0]:
		tween.tween_property(_logo, "rotation", amount, 0.07)


func _section(shape: String, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.texture = Icons.get_icon(shape, DIM, 16)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(icon)
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", DIM)
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)
	return row


## One folder: icon, name, path, number of events; recent ones can be removed.
func _card(game: String, recent: bool) -> Control:
	var count := SoundLibrary.event_count(game)
	var present := count >= 0 or not SoundLibrary.workspace_folders(game, "music").is_empty()
	if present and count < 0:
		count = 0
	var style := _flat(CARD, 8)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", style)
	card.tooltip_text = game if present else "Not found, or no sfx/ folder: %s" % game
	if present:
		card.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	_list.add_child(card)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	var icon := TextureRect.new()
	icon.texture = Icons.get_icon("folder", (ACCENT if recent else Color(1, 1, 1, 0.75)) if present else DIM, 28)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(icon)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 0)
	row.add_child(names)
	var title := Label.new()
	title.text = game.get_file()
	title.add_theme_font_size_override("font_size", 18)
	if not present:
		title.add_theme_color_override("font_color", DIM)
	names.add_child(title)
	var path := Label.new()
	path.text = game
	path.clip_text = true
	path.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	path.add_theme_color_override("font_color", DIM)
	path.add_theme_font_size_override("font_size", 13)
	names.add_child(path)

	var wave := TextureRect.new()
	wave.texture = Icons.get_icon("wave", DIM, 18)
	wave.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(wave)
	var number := Label.new()
	number.text = str(count) if present else "—"
	number.custom_minimum_size.x = 32
	number.add_theme_font_size_override("font_size", 18)
	number.add_theme_color_override("font_color", Color.WHITE if present else DIM)
	row.add_child(number)
	if recent:
		var remove := Button.new()
		remove.icon = Icons.get_icon("close", DIM, 16)
		remove.tooltip_text = "Remove from this list (the folder stays on disk)"
		remove.flat = true
		remove.focus_mode = FOCUS_NONE
		remove.pressed.connect(func() -> void: forgotten.emit(game))
		row.add_child(remove)
	_pass_mouse(margin)

	if present:
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				chosen.emit(game))
		card.mouse_entered.connect(func() -> void:
			create_tween().tween_property(style, "bg_color", CARD_HOVER, 0.12))
		card.mouse_exited.connect(func() -> void:
			create_tween().tween_property(style, "bg_color", CARD, 0.2))
	else:
		card.modulate.a = 0.7
	return card


## Lets clicks reach the card through everything but its buttons.
func _pass_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control and not child is Button:
			child.mouse_filter = MOUSE_FILTER_PASS if child is Container else MOUSE_FILTER_IGNORE
		_pass_mouse(child)


func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	return spacer


func _flat(color: Color, radius := 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	return box
