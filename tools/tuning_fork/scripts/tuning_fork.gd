extends Control
## Tuning Fork: lists a game's sound events by folder, creates, renames and
## deletes them, shows each event's files as waveforms, plays them as the game
## does, edits their JSON settings and the mixing groups, and saves them back.
## WAV and OGG files dropped on the window are added to the selected event
## (WAV converted to OGG with oggenc). It starts on the project window
## (ProjectPicker), where the user picks the game folder. Definition:
## docs/Home.md.
##
## Command-line user arguments (after `--`):
##   --root=<folder>     game folder holding sfx/, opened without the project window
##   --select=<path>     event selected at start ("groups" for the groups)
##   --screenshot=<png>  plays the event a few times muted, saves the window, quits

const CONFIG_PATH := "user://tuning_fork.cfg"
const GROUPS_ITEM := "groups"
## Slider range of each number setting: [min, max, step]. The number boxes
## accept values beyond the slider.
const RANGES := {
	"volume_db": [-40.0, 12.0, 0.1],
	"volume_jitter_db": [0.0, 12.0, 0.1],
	"pitch": [0.25, 4.0, 0.01],
	"pitch_jitter": [0.0, 0.5, 0.005],
	"cooldown_ms": [0.0, 1000.0, 1.0],
	"shuffle_refill_after": [0.0, 16.0, 1.0],
}
const HINTS := {
	"group": "Mixing group: the event's volume adds to its group's volume (groups at the bottom of the list)",
	"loop": "Plays until the game stops it, from the start of one file, over and over",
	"protected": "Plays on a voice of its own: no other sound can cut it",
	"files_from": "Plays the files of another event, with this event's own settings",
	"volume_db": "Loudness in dB (0 = as recorded)",
	"volume_jitter_db": "Random loudness change per play, up to ± this many dB",
	"pitch": "Playback pitch (1 = as recorded); pitch also changes speed",
	"pitch_jitter": "Random pitch change per play, up to ± this amount",
	"cooldown_ms": "A repeat of the same event sooner than this is skipped",
	"pick": "How each play chooses a file: shuffle plays every file once in a random order before any repeats; random draws any file each time",
	"shuffle_refill_after": "Shuffle only: deal the files again after this many plays, before all have played (0 = after all of them)",
}
const OWN_FILES := "own files"
const ACCENT := Color(0.98, 0.72, 0.30)
const DIM := Color(1, 1, 1, 0.45)
const WARNING := Color(1.0, 0.62, 0.35)
const PANEL := Color("16181d")
const CARD := Color("23272f")

var library := SoundLibrary.new()
var sound_player: SoundPlayer
var current: SoundEntry
var showing_groups := false

var _items := {}
var _rows := {}
var _cards: Array[WaveCard] = []
var _updating := false
var _after_confirm := Callable()
var _pending_removal := -1

var _background: Control
var _picker: ProjectPicker
var _root_label: Label
var _auto_play: CheckButton
var _filter: LineEdit
var _tree: Tree
var _editor: Control
var _empty_hint: Label
var _name_label: Label
var _path_label: Label
var _rename_button: Button
var _delete_button: Button
var _save_button: Button
var _revert_button: Button
var _event_box: VBoxContainer
var _description: LineEdit
var _problems_label: Label
var _files_caption: HBoxContainer
var _files_caption_label: Label
var _file_strip: HFlowContainer
var _grid: GridContainer
var _scatter: PlayScatter
var _last_label: Label
var _groups_box: VBoxContainer
var _groups_grid: GridContainer
var _new_group: LineEdit
var _status: Label
var _unsaved_label: Label
var _save_all_button: Button
var _auto_timer: Timer
var _add_dialog: FileDialog
var _confirm: ConfirmationDialog
var _remove_dialog: ConfirmationDialog
var _new_dialog: ConfirmationDialog
var _new_folder: LineEdit
var _new_name: LineEdit
var _new_description: LineEdit
var _new_error: Label
var _rename_dialog: ConfirmationDialog
var _rename_path: LineEdit
var _rename_error: Label
var _delete_dialog: ConfirmationDialog
var _tabs: TabContainer
var _music_panel: MusicPanel
var _sfx_workspace: OptionButton


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	sound_player = SoundPlayer.new()
	add_child(sound_player)
	sound_player.played.connect(_on_played)
	_build_ui()
	get_window().files_dropped.connect(func(paths: PackedStringArray) -> void:
		if _picker.visible:
			_picker.open_dropped(paths)
		else:
			if _tabs.current_tab == 1:
				_music_panel.add_files(paths)
			else:
				_add_files(paths))
	var disk_timer := Timer.new()
	disk_timer.wait_time = 1.0
	disk_timer.autostart = true
	disk_timer.timeout.connect(_check_disk)
	add_child(disk_timer)
	_auto_timer = Timer.new()
	_auto_timer.one_shot = true
	_auto_timer.wait_time = 0.25
	_auto_timer.timeout.connect(_play_once)
	add_child(_auto_timer)

	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	_auto_play.set_pressed_no_signal(bool(config.get_value("tool", "auto_play", true)))
	var args := _user_args()
	if args.has("root"):
		var game := ProjectPicker.normalized(args["root"])
		_open_root(game, args.get("select", _remembered_selection(game)))
		if args.get("tab", "") == "music":
			_tabs.current_tab = 1
			if args.has("select"):
				_music_panel.select(args["select"])
	else:
		_show_picker()
	if args.has("screenshot"):
		_take_screenshot(args["screenshot"])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_confirm_unsaved(func() -> void: get_tree().quit())
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and library.root != "":
		_check_disk()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if _picker.visible:
		if key.keycode == KEY_ESCAPE and _picker.can_go_back:
			_hide_picker()
			get_viewport().set_input_as_handled()
		return
	var typing := get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is TextEdit
	if _tabs.current_tab == 1:
		if key.keycode == KEY_S and key.is_command_or_control_pressed():
			if key.shift_pressed:
				_save_all()
			elif not _music_panel.current.is_empty():
				_music_panel.save(_music_panel.current)
		elif key.keycode == KEY_SPACE and not typing:
			_music_panel.play_current()
		elif key.keycode == KEY_ESCAPE:
			_music_panel.stop()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_S and key.is_command_or_control_pressed():
		if key.shift_pressed:
			_save_all()
		else:
			_save_current()
	elif key.keycode == KEY_SPACE and not typing:
		_play_once()
	elif key.keycode == KEY_ESCAPE:
		_stop_all()
		if typing:
			get_viewport().gui_release_focus()
	else:
		return
	get_viewport().set_input_as_handled()


# --- Folder and selection -------------------------------------------------

## Shows the project window over the editor, with `message` as a warning.
func _show_picker(message := "", animate := true) -> void:
	_stop_all()
	var open := library.root != ""
	_picker.show_projects(_recent(), ProjectPicker.detect(), open, message, animate)
	_background.hide()


func _hide_picker() -> void:
	_picker.hide()
	_background.show()


func _on_project_chosen(game: String) -> void:
	game = ProjectPicker.normalized(game)
	if SoundLibrary.event_count(game) < 0 and not DirAccess.dir_exists_absolute(game.path_join("music")):
		_picker.show_message("No sfx/ folder in %s" % game)
		return
	_open_root(game, _remembered_selection(game))


func _on_project_forgotten(game: String) -> void:
	var recent := _recent()
	recent.erase(game)
	_save_config("recent", recent)
	_show_picker("", false)


## Game folders opened before, most recent first.
func _recent() -> Array[String]:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	var recent: Array[String] = []
	for game in config.get_value("tool", "recent", []):
		recent.append(str(game))
	# Before the project window, only the last folder was kept.
	var last := str(config.get_value("tool", "root", ""))
	if not config.has_section_key("tool", "recent") and last != "":
		recent.append(last)
	return recent


## The event or page last selected in `game`.
func _remembered_selection(game: String) -> String:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	var selections: Dictionary = config.get_value("tool", "selections", {})
	if selections.has(game):
		return str(selections[game])
	if game == str(config.get_value("tool", "root", "")):
		return str(config.get_value("tool", "selected", ""))
	return ""


func _remember_selection(select: String) -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	var selections: Dictionary = config.get_value("tool", "selections", {})
	selections[library.root] = select
	config.set_value("tool", "selections", selections)
	config.save(CONFIG_PATH)


func _open_root(root: String, select := "") -> void:
	_stop_all()
	current = null
	showing_groups = false
	if library.root != root:
		library.folder_name = "sfx"
	var error := library.open(root)
	_sfx_workspace.clear()
	var folders: Array[String] = []
	if DirAccess.dir_exists_absolute(root):
		for folder in DirAccess.get_directories_at(root):
			if folder == "sfx" or folder.begins_with("sfx_"):
				folders.append(folder)
	folders.sort()
	for folder in folders:
		_sfx_workspace.add_item(folder)
	_sfx_workspace.select(folders.find(library.folder_name))
	if _music_panel.catalog.root != root.path_join("music"):
		_music_panel.open(root)
	else:
		_music_panel.check_disk()
	_root_label.text = library.root if error == "" else "—"
	_root_label.tooltip_text = _root_label.text
	sound_player.apply_groups(library.groups)
	_rebuild_tree()
	if error != "":
		_set_status(error, true)
		_show_page()
		_show_picker(error)
		return
	_hide_picker()
	_save_config("recent", ProjectPicker.remember(_recent(), library.root))
	get_window().title = "Tuning Fork · %s" % library.root.get_file()
	_set_status("%d events in %s" % [library.sounds.size(), library.root])
	if select == GROUPS_ITEM:
		_select_groups()
		return
	var entry := library.find(select)
	if entry == null and not library.sounds.is_empty():
		entry = library.sounds[0]
	_select(entry)


func _select(entry: SoundEntry) -> void:
	if entry != current or showing_groups:
		current = entry
		showing_groups = false
		_scatter.clear_points()
		_last_label.text = ""
		if entry != null:
			_remember_selection(entry.path)
	if entry != null and _items.has(entry) and _tree.get_selected() != _items[entry]:
		_updating = true
		_items[entry].select(0)
		_tree.scroll_to_item(_items[entry])
		_updating = false
	_show_page()


func _select_groups() -> void:
	current = null
	showing_groups = true
	_remember_selection(GROUPS_ITEM)
	if _items.has(GROUPS_ITEM) and _tree.get_selected() != _items[GROUPS_ITEM]:
		_updating = true
		_items[GROUPS_ITEM].select(0)
		_updating = false
	_show_page()


## Events in their folders (nested), then the groups.
func _rebuild_tree() -> void:
	_updating = true
	_tree.clear()
	_items.clear()
	var tree_root := _tree.create_item()
	var filter := _filter.text.strip_edges().to_lower()
	var folders := {"": tree_root}
	for entry in library.sounds:
		if filter != "" and not entry.path.contains(filter):
			continue
		var item := _tree.create_item(_folder_item(entry.folder, folders))
		item.set_metadata(0, entry)
		item.set_icon(0, Icons.get_icon("wave", Color(1, 1, 1, 0.7), 16))
		_items[entry] = item
		_update_item(entry)
	if library.root != "":
		var groups := _tree.create_item(tree_root)
		groups.set_text(0, "Groups")
		groups.set_icon(0, Icons.get_icon("mixer", Color(1, 1, 1, 0.7), 16))
		groups.set_metadata(0, GROUPS_ITEM)
		_items[GROUPS_ITEM] = groups
		_update_groups_item()
	if showing_groups and _items.has(GROUPS_ITEM):
		_items[GROUPS_ITEM].select(0)
	elif current != null and _items.has(current):
		_items[current].select(0)
	_updating = false


func _folder_item(folder: String, folders: Dictionary) -> TreeItem:
	if folders.has(folder):
		return folders[folder]
	var parent := _folder_item(folder.get_base_dir(), folders)
	var item := _tree.create_item(parent)
	item.set_text(0, folder.get_file())
	item.set_icon(0, Icons.get_icon("folder", DIM, 16))
	item.set_selectable(0, false)
	item.set_custom_color(0, DIM)
	folders[folder] = item
	return item


func _update_item(entry: SoundEntry) -> void:
	if _items.has(entry):
		var item: TreeItem = _items[entry]
		var dirty := entry.is_dirty()
		var text := entry.name
		var source := library.borrowed_from(entry)
		if str(entry.setting("files_from")) != "":
			text += "  ↪"
		elif entry.files.size() > 1:
			text += "  ×%d" % entry.files.size()
		item.set_text(0, text + ("  ●" if dirty else ""))
		item.set_tooltip_text(0, entry.path)
		var broken := str(entry.setting("files_from")) != "" and (source == null or source.files.is_empty())
		if dirty:
			item.set_custom_color(0, ACCENT)
		elif not entry.problems.is_empty() or not entry.file_problems.is_empty() or broken \
				or (source == null and entry.files.is_empty()):
			item.set_custom_color(0, WARNING)
		else:
			item.clear_custom_color(0)
	_update_unsaved()


func _update_groups_item() -> void:
	if _items.has(GROUPS_ITEM):
		var item: TreeItem = _items[GROUPS_ITEM]
		var dirty := library.groups_dirty()
		item.set_text(0, "Groups" + ("  ●" if dirty else ""))
		if dirty:
			item.set_custom_color(0, ACCENT)
		elif not library.groups_problems.is_empty():
			item.set_custom_color(0, WARNING)
		else:
			item.clear_custom_color(0)
	_update_unsaved()


func _update_unsaved() -> void:
	var unsaved := _unsaved().size() + (1 if library.groups_dirty() else 0)
	_unsaved_label.text = "● %d" % unsaved if unsaved > 0 else ""
	_save_all_button.disabled = unsaved == 0


func _unsaved() -> Array[SoundEntry]:
	var list: Array[SoundEntry] = []
	for entry in library.sounds:
		if entry.is_dirty():
			list.append(entry)
	return list


# --- Showing the selected event or the groups -----------------------------------

func _show_page() -> void:
	_editor.visible = current != null or showing_groups
	_empty_hint.visible = not _editor.visible
	_event_box.visible = current != null
	_groups_box.visible = showing_groups
	_rename_button.visible = current != null
	_delete_button.visible = current != null
	if showing_groups:
		_name_label.text = "Groups"
		_path_label.text = library.relative(library.groups_path())
		_build_group_rows()
		_refresh_groups()
		return
	if current == null:
		return
	_updating = true
	_name_label.text = current.path
	var path_text := library.relative(current.json_path)
	var source := library.borrowed_from(current)
	if source != null:
		path_text += "   ·   files of %s" % source.path
	else:
		path_text += "   ·   %d file%s" % [current.files.size(), "" if current.files.size() == 1 else "s"]
	_path_label.text = path_text
	_description.text = str(current.data.get("description", ""))
	_build_cards()
	_build_rows()
	_updating = false
	_refresh()


## Updates everything that follows the values: rows, notes, scatter range.
func _refresh() -> void:
	if current == null:
		return
	_updating = true
	for key: String in _rows:
		_refresh_row(key)
	_updating = false
	var notes: Array[String] = current.problems.duplicate()
	notes.append_array(current.file_problems)
	var files_from := str(current.setting("files_from"))
	var source := library.borrowed_from(current)
	if not current.has_json:
		notes.append("No JSON file yet: saving creates %s" % library.relative(current.json_path))
	if files_from != "" and source == null:
		notes.append("files_from names %s, which does not exist: the game plays nothing" % files_from)
	elif source != null and str(source.setting("files_from")) != "":
		notes.append("%s takes its files from another event: take them from that one instead" % source.path)
	elif files_from == "" and current.files.is_empty():
		notes.append("No sound file yet: drop a WAV or OGG file on the window")
	if not library.groups.has(str(current.setting("group"))):
		notes.append("Group %s is not in %s: the game plays it at the master volume" % [current.setting("group"), SoundLibrary.GROUPS_FILE])
	if current.changed_on_disk:
		notes.append("The JSON file changed on disk: revert to load it, or save to replace it")
	_problems_label.text = "\n".join(notes)
	_problems_label.visible = not notes.is_empty()
	var dirty := current.is_dirty()
	_save_button.disabled = not dirty and current.has_json
	_revert_button.disabled = not dirty and not current.changed_on_disk
	_update_item(current)
	_scatter.set_range(float(current.setting("pitch")), float(current.setting("pitch_jitter")),
		float(current.setting("volume_db")), float(current.setting("volume_jitter_db")))


## One waveform card per file the event plays, then the add card for its own
## files; borrowed files show the event they come from.
func _build_cards() -> void:
	for child in _file_strip.get_children():
		_file_strip.remove_child(child)
		child.queue_free()
	_cards.clear()
	var source := library.borrowed_from(current)
	var owner_entry := source if source != null else current
	_files_caption.visible = source != null
	if source != null:
		_files_caption_label.text = "Files of %s" % source.path
	for i in owner_entry.files.size():
		var card := WaveCard.new()
		card.setup(i, owner_entry.files[i], owner_entry.streams[i], source == null)
		card.play_requested.connect(func(index: int) -> void: _play_once(index))
		card.remove_requested.connect(_ask_remove_file)
		_file_strip.add_child(card)
		_cards.append(card)
	if source != null or str(current.setting("files_from")) != "":
		return
	var add := Button.new()
	add.icon = Icons.get_icon("plus", Color(1, 1, 1, 0.6), 28)
	add.text = "WAV · OGG"
	add.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	add.custom_minimum_size = Vector2(150, 112)
	add.focus_mode = FOCUS_NONE
	add.tooltip_text = "Add sound files: drop WAV or OGG files on the window, or click to choose them"
	add.add_theme_color_override("font_color", DIM)
	add.add_theme_font_size_override("font_size", 13)
	var dashed := StyleBoxFlat.new()
	dashed.bg_color = Color(1, 1, 1, 0.02)
	dashed.set_border_width_all(2)
	dashed.border_color = Color(1, 1, 1, 0.15)
	dashed.set_corner_radius_all(6)
	add.add_theme_stylebox_override("normal", dashed)
	var hover := dashed.duplicate()
	hover.border_color = ACCENT
	add.add_theme_stylebox_override("hover", hover)
	add.add_theme_stylebox_override("pressed", hover)
	add.pressed.connect(func() -> void: _add_dialog.popup_centered_ratio(0.6))
	_file_strip.add_child(add)


func _build_rows() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_rows.clear()
	for key: String in current.defaults():
		match key:
			"group", "files_from", "pick":
				_add_choice_row(key)
			"loop", "protected":
				_add_switch_row(key)
			_:
				_add_number_row(key)


func _add_number_row(key: String) -> void:
	var row := _row_start(key)
	var limits: Array = RANGES.get(key, [-100.0, 100.0, 0.01])
	var slider := HSlider.new()
	slider.min_value = limits[0]
	slider.max_value = limits[1]
	slider.step = limits[2]
	slider.size_flags_horizontal = SIZE_EXPAND_FILL
	slider.size_flags_vertical = SIZE_SHRINK_CENTER
	slider.custom_minimum_size.x = 220
	slider.tooltip_text = HINTS.get(key, "")
	var spin := SpinBox.new()
	spin.min_value = limits[0]
	spin.max_value = limits[1]
	spin.step = limits[2]
	spin.allow_greater = true
	spin.allow_lesser = limits[0] < 0.0
	spin.select_all_on_focus = true
	spin.custom_minimum_size.x = 120
	slider.value_changed.connect(func(value: float) -> void:
		spin.set_value_no_signal(value)
		_set_value(key, value))
	spin.value_changed.connect(func(value: float) -> void:
		slider.set_value_no_signal(value)
		_set_value(key, value))
	_grid.add_child(slider)
	_grid.add_child(spin)
	row["slider"] = slider
	row["spin"] = spin
	_row_end(key, row)


## A drop-down: the pick modes, the groups, or the events to take files from.
func _add_choice_row(key: String) -> void:
	var row := _row_start(key)
	var options := OptionButton.new()
	options.tooltip_text = HINTS[key]
	options.size_flags_horizontal = SIZE_SHRINK_BEGIN
	options.custom_minimum_size.x = 220
	options.item_selected.connect(func(i: int) -> void:
		if not _updating and current != null:
			_set_choice(key, options.get_item_metadata(i)))
	_grid.add_child(options)
	if key == "files_from":
		var go := _icon_button("link", "Select the event these files come from", func() -> void:
			var source := library.borrowed_from(current)
			if source != null:
				_select(source))
		go.size_flags_horizontal = SIZE_SHRINK_BEGIN
		row["go"] = go
		_grid.add_child(go)
	else:
		_grid.add_child(Control.new())
	row["options"] = options
	_row_end(key, row)


func _add_switch_row(key: String) -> void:
	var row := _row_start(key)
	var check := CheckButton.new()
	check.tooltip_text = HINTS[key]
	check.size_flags_horizontal = SIZE_SHRINK_BEGIN
	check.toggled.connect(func(on: bool) -> void:
		if not _updating and current != null:
			_set_choice(key, on))
	_grid.add_child(check)
	_grid.add_child(Control.new())
	row["check"] = check
	_row_end(key, row)


func _row_start(key: String) -> Dictionary:
	var label := Label.new()
	label.text = key
	label.tooltip_text = HINTS.get(key, "")
	label.mouse_filter = MOUSE_FILTER_PASS
	label.custom_minimum_size.x = 190
	_grid.add_child(label)
	return {"label": label}


func _row_end(key: String, row: Dictionary) -> void:
	var reset := Button.new()
	reset.icon = Icons.get_icon("revert", Color.WHITE, 16)
	reset.flat = true
	reset.tooltip_text = "Back to the default value"
	reset.pressed.connect(func() -> void: _reset_value(key))
	_grid.add_child(reset)
	row["reset"] = reset
	_rows[key] = row


## The choices of a drop-down row, as [label, value] pairs.
func _choices(key: String) -> Array:
	var choices := []
	match key:
		"pick":
			for mode: String in SoundLibrary.PICK_MODES:
				choices.append([mode, mode])
		"group":
			for group_name: String in library.groups:
				choices.append([group_name, group_name])
		"files_from":
			choices.append([OWN_FILES, ""])
			for source in library.file_sources(current):
				choices.append([source.path, source.path])
	var value := str(current.setting(key))
	if not choices.any(func(c: Array) -> bool: return c[1] == value):
		choices.append([value + "  (missing)", value])
	return choices


func _refresh_row(key: String) -> void:
	var row: Dictionary = _rows[key]
	var value = current.setting(key)
	var default = current.defaults()[key]
	row["reset"].disabled = str(value) == str(default) if (default is String or default is bool) \
		else is_equal_approx(float(value), float(default))
	if row.has("options"):
		var options: OptionButton = row["options"]
		options.clear()
		var choices := _choices(key)
		for i in choices.size():
			options.add_item(choices[i][0])
			options.set_item_metadata(i, choices[i][1])
			if choices[i][1] == str(value):
				options.select(i)
		if row.has("go"):
			row["go"].disabled = str(value) == ""
		return
	if row.has("check"):
		row["check"].set_pressed_no_signal(bool(value))
		return
	var number := float(value)
	row["slider"].set_value_no_signal(number)
	row["spin"].set_value_no_signal(number)
	# The refill count only applies to shuffle; a loop has no random variation
	# and no repeat delay.
	var looping := bool(current.setting("loop"))
	var active: bool = (key != "shuffle_refill_after" or str(current.setting("pick")) == "shuffle") \
		and not (looping and key in ["volume_jitter_db", "pitch_jitter", "cooldown_ms"])
	row["slider"].editable = active
	row["spin"].editable = active
	row["label"].add_theme_color_override("font_color", Color.WHITE if active else DIM)


# --- Editing ---------------------------------------------------------------

func _set_value(key: String, value: float) -> void:
	if _updating or current == null:
		return
	current.data[key] = int(roundf(value)) if key in SoundLibrary.INT_KEYS else snappedf(value, 0.0001)
	if key == "shuffle_refill_after":
		sound_player.reset_pick(current)
	_after_edit()


func _set_choice(key: String, value: Variant) -> void:
	if key == "files_from" and str(value) == "":
		current.data.erase("files_from")
	else:
		current.data[key] = value
	sound_player.reset_pick(current)
	if key == "files_from":
		_show_page()
	_after_edit(key != "files_from")


func _reset_value(key: String) -> void:
	if current == null:
		return
	if key == "files_from":
		current.data.erase(key)
	else:
		current.data[key] = current.defaults()[key]
	sound_player.reset_pick(current)
	if key == "files_from":
		_show_page()
	_after_edit()


func _set_description(text: String) -> void:
	if _updating or current == null:
		return
	current.data["description"] = text
	_after_edit(false)


func _after_edit(replay := true) -> void:
	_refresh()
	if replay and _auto_play.button_pressed:
		_auto_timer.start()


# --- Creating, renaming and deleting events -------------------------------------

func _ask_new_event() -> void:
	_new_folder.text = current.folder if current != null else ""
	_new_name.text = ""
	_new_description.text = ""
	_new_error.text = ""
	_new_dialog.popup_centered(Vector2i(460, 0))
	_new_name.grab_focus()


func _create_event() -> void:
	var folder := _new_folder.text.strip_edges().trim_prefix("/").trim_suffix("/")
	var event_name := _new_name.text.strip_edges()
	var event_path := event_name if folder == "" else folder.path_join(event_name)
	var problem := library.create_event(event_path, _new_description.text.strip_edges())
	if problem != "":
		_new_error.text = problem
		return
	_new_dialog.hide()
	_filter.text = ""
	_rebuild_tree()
	_select(library.find(event_path))
	_set_status("Created %s: the game plays it with Sfx.play(\"%s\")" % [event_path, event_path])


func _ask_rename() -> void:
	if current == null:
		return
	_rename_path.text = current.path
	_rename_error.text = ""
	_rename_dialog.popup_centered(Vector2i(460, 0))
	_rename_path.grab_focus()
	_rename_path.select_all()


func _rename_event() -> void:
	var old_path := current.path
	var event_path := _rename_path.text.strip_edges().trim_prefix("/").trim_suffix("/")
	_stop_all()
	var problem := library.rename_event(current, event_path)
	if problem != "":
		_rename_error.text = problem
		return
	_rename_dialog.hide()
	_rebuild_tree()
	_select(current)
	_set_status("Renamed %s to %s: change Sfx.play(\"%s\") in the game's code" % [old_path, event_path, old_path])


func _ask_delete() -> void:
	if current == null:
		return
	var borrowers := library.borrowers_of(current)
	if not borrowers.is_empty():
		_set_status("%s plays the files of %s: change its files_from first" % [borrowers[0].path, current.path], true)
		return
	var count := current.files.size()
	_delete_dialog.dialog_text = "Move %s and its %d file%s to the recycle bin?\nThe game's code may still play it: it then plays nothing." % [
		current.path, count, "" if count == 1 else "s"]
	_delete_dialog.popup_centered(Vector2i(460, 0))


func _delete_event() -> void:
	var event_path := current.path
	_stop_all()
	var problem := library.delete_event(current)
	if problem != "":
		_set_status(problem, true)
		return
	current = null
	_rebuild_tree()
	_select(library.sounds[0] if not library.sounds.is_empty() else null)
	_set_status("Moved %s to the recycle bin" % event_path)


# --- Groups ------------------------------------------------------------------

func _build_group_rows() -> void:
	for child in _groups_grid.get_children():
		_groups_grid.remove_child(child)
		child.queue_free()
	for group_name: String in library.groups:
		var name_edit := LineEdit.new()
		name_edit.text = group_name
		name_edit.custom_minimum_size.x = 180
		name_edit.tooltip_text = "Rename the group: its events follow"
		var rename := func(_t := "") -> void:
			var new_name := name_edit.text.strip_edges()
			if new_name == group_name or not library.groups.has(group_name):
				return
			var problem := library.rename_group(group_name, new_name)
			if problem != "":
				_set_status(problem, true)
				name_edit.text = group_name
				return
			_after_groups_edit(true)
		name_edit.text_submitted.connect(rename)
		name_edit.focus_exited.connect(rename)
		_groups_grid.add_child(name_edit)
		var slider := HSlider.new()
		slider.min_value = -40.0
		slider.max_value = 12.0
		slider.step = 0.1
		slider.size_flags_horizontal = SIZE_EXPAND_FILL
		slider.size_flags_vertical = SIZE_SHRINK_CENTER
		slider.custom_minimum_size.x = 220
		slider.tooltip_text = "Group volume in dB, added to each event's volume"
		slider.value = library.group_volume(group_name)
		var spin := SpinBox.new()
		spin.min_value = -40.0
		spin.max_value = 12.0
		spin.step = 0.1
		spin.allow_greater = true
		spin.allow_lesser = true
		spin.select_all_on_focus = true
		spin.custom_minimum_size.x = 120
		spin.suffix = "dB"
		spin.value = library.group_volume(group_name)
		var set_volume := func(value: float) -> void:
			slider.set_value_no_signal(value)
			spin.set_value_no_signal(value)
			library.groups[group_name]["volume_db"] = snappedf(value, 0.0001)
			_after_groups_edit(false)
		slider.value_changed.connect(set_volume)
		spin.value_changed.connect(set_volume)
		_groups_grid.add_child(slider)
		_groups_grid.add_child(spin)
		var members := library.group_members(group_name).size()
		var count := Label.new()
		count.text = "%d event%s" % [members, "" if members == 1 else "s"]
		count.add_theme_color_override("font_color", DIM)
		count.custom_minimum_size.x = 80
		_groups_grid.add_child(count)
		var remove := _icon_button("trash", "Remove this group" if members == 0 else "Used by %d events: move them to another group first" % members,
			func() -> void:
				var problem := library.remove_group(group_name)
				if problem != "":
					_set_status(problem, true)
				else:
					_after_groups_edit(true), 16)
		remove.disabled = members > 0
		_groups_grid.add_child(remove)


func _add_group() -> void:
	var problem := library.add_group(_new_group.text.strip_edges())
	if problem != "":
		_set_status(problem, true)
		return
	_new_group.text = ""
	_after_groups_edit(true)


func _after_groups_edit(rebuild: bool) -> void:
	sound_player.apply_groups(library.groups)
	if rebuild:
		_build_group_rows()
		for entry in library.sounds:
			_update_item(entry)
	_refresh_groups()


func _refresh_groups() -> void:
	var notes := library.groups_problems.duplicate()
	if library.groups_time == -1:
		notes.append("No %s yet: saving creates it" % SoundLibrary.GROUPS_FILE)
	var dirty := library.groups_dirty()
	_save_button.disabled = not dirty
	_revert_button.disabled = not dirty
	_update_groups_item()
	_set_groups_notes(notes)


func _set_groups_notes(notes: Array) -> void:
	var label: Label = _groups_box.get_node("Notes")
	label.text = "\n".join(notes)
	label.visible = not notes.is_empty()


# --- Sound files -------------------------------------------------------------

## Adds dropped or chosen WAV/OGG files to the current event.
func _add_files(paths: PackedStringArray) -> void:
	if current == null:
		_set_status("Select an event to add files to it", true)
		return
	var added: Array[String] = []
	var problems: Array[String] = []
	for path in paths:
		var problem := current.add_file(path)
		if problem == "":
			added.append(current.files.back().get_file())
		else:
			problems.append(problem)
	sound_player.reset_pick(current)
	library.note_structure()
	_show_page()
	if not problems.is_empty():
		_set_status("  ·  ".join(problems), true)
	else:
		_set_status("Added " + ", ".join(added))


func _ask_remove_file(index: int) -> void:
	if current == null or index >= current.files.size():
		return
	_pending_removal = index
	var later := current.files.size() - index - 1
	_remove_dialog.dialog_text = "Move %s to the recycle bin?%s" % [current.files[index].get_file(),
		"\nThe files after it are renumbered." if later > 0 else ""]
	_remove_dialog.popup_centered(Vector2i(420, 0))


func _remove_file() -> void:
	if current == null or _pending_removal < 0:
		return
	_stop_all()
	var file_name := current.files[_pending_removal].get_file()
	var problem := current.remove_file(_pending_removal)
	_pending_removal = -1
	sound_player.reset_pick(current)
	library.note_structure()
	_show_page()
	if problem != "":
		_set_status(problem, true)
	else:
		_set_status("Moved %s to the recycle bin" % file_name)


# --- Saving ----------------------------------------------------------------

func _save_current() -> void:
	if _tabs.current_tab == 1:
		if not _music_panel.current.is_empty():
			_music_panel.save(_music_panel.current)
		return
	if showing_groups:
		_save_groups()
	elif current != null:
		_save_entries([current])


func _save_all() -> bool:
	if not _music_panel.save_all():
		return false
	if library.groups_dirty() and not _save_groups():
		return false
	return _save_entries(_unsaved())


func _save_groups() -> bool:
	var error := library.save_groups()
	if error != OK:
		_set_status("Could not save %s (%s)" % [library.groups_path(), error_string(error)], true)
		return false
	_set_status("Saved %s" % SoundLibrary.GROUPS_FILE)
	if showing_groups:
		_refresh_groups()
	_update_groups_item()
	return true


func _save_entries(entries: Array[SoundEntry]) -> bool:
	var saved: Array[String] = []
	for entry in entries:
		var error := entry.save()
		if error != OK:
			_set_status("Could not save %s (%s)" % [entry.json_path, error_string(error)], true)
			return false
		saved.append(entry.path)
		_update_item(entry)
	library.note_structure()
	if not saved.is_empty():
		_set_status("Saved " + ", ".join(saved))
	_refresh()
	return true


func _revert_current() -> void:
	if showing_groups:
		library.load_groups()
		_after_groups_edit(true)
		_set_status("Reloaded %s" % SoundLibrary.GROUPS_FILE)
		return
	if current == null:
		return
	current.load_settings()
	sound_player.reset_pick(current)
	_set_status("Reloaded %s" % library.relative(current.json_path))
	_show_page()


## Runs `then` now, or once the user saved or discarded unsaved changes.
func _confirm_unsaved(then: Callable) -> void:
	var unsaved: Array = _unsaved().map(func(e: SoundEntry) -> String: return e.path)
	unsaved.append_array(_music_panel.unsaved_paths())
	if library.groups_dirty():
		unsaved.append(SoundLibrary.GROUPS_FILE)
	if unsaved.is_empty():
		then.call()
		return
	_after_confirm = then
	_confirm.dialog_text = "Unsaved changes: %s" % ", ".join(unsaved)
	_confirm.popup_centered(Vector2i(440, 0))


## Reloads what changed on disk (another editor, new files): events added or
## removed, sound files, settings and groups.
func _check_disk() -> void:
	_music_panel.check_disk()
	if library.root == "":
		return
	if library.structure_changed_on_disk():
		if _unsaved().is_empty() and not library.groups_dirty():
			_open_root(library.root, GROUPS_ITEM if showing_groups else (current.path if current != null else ""))
			_set_status("Events changed on disk: reloaded")
		else:
			library.note_structure()
			_set_status("Events were added or removed on disk: save, then reload (top bar)", true)
		return
	var reloaded: Array[String] = []
	var current_changed := false
	for entry in library.sounds:
		if entry.files_changed_on_disk():
			entry.load_files()
			sound_player.reset_pick(entry)
			reloaded.append(entry.path + " files")
			current_changed = true
		if entry.json_changed_on_disk():
			if entry.is_dirty():
				entry.changed_on_disk = true
				entry.json_time = FileAccess.get_modified_time(entry.json_path)
			else:
				entry.load_settings()
				reloaded.append(entry.path + ".json")
			current_changed = true
		_update_item(entry)
	if library.groups_changed_on_disk():
		if library.groups_dirty():
			library.groups_time = FileAccess.get_modified_time(library.groups_path())
			_set_status("%s changed on disk: revert to load it, or save to replace it" % SoundLibrary.GROUPS_FILE, true)
		else:
			library.load_groups()
			sound_player.apply_groups(library.groups)
			reloaded.append(SoundLibrary.GROUPS_FILE)
			current_changed = true
	if not reloaded.is_empty():
		_set_status("Reloaded from disk: " + ", ".join(reloaded))
	if current_changed:
		_show_page()


# --- Playing ---------------------------------------------------------------

## Plays the current event once: file `file_index`, or the one it picks.
func _play_once(file_index := -1) -> void:
	if _tabs.current_tab == 1:
		_music_panel.play_current()
		return
	if current == null:
		return
	var streams := library.streams_of(current)
	if streams.is_empty():
		_set_status("%s has no sound file: drop a WAV or OGG file on the window" % current.path, true)
	elif not sound_player.play(current, streams, file_index):
		_last_label.text = "skipped: repeated within cooldown_ms"


func _on_played(entry: SoundEntry, file_index: int, pitch: float, volume_db: float, voice: AudioStreamPlayer) -> void:
	if entry != current:
		return
	var source := library.borrowed_from(entry)
	var owner_entry := source if source != null else entry
	_scatter.add_point(pitch, volume_db)
	_last_label.text = "%s   ·   pitch %.3f   ·   %.1f dB%s" % [
		owner_entry.files[file_index].get_file(), pitch, volume_db, "   ·   looping until Stop" if entry.setting("loop") else ""]
	for card in _cards:
		if card.index == file_index:
			card.show_play(voice, pitch)
		else:
			card.clear_play()


func _stop_all() -> void:
	sound_player.stop_all()
	if _music_panel != null:
		_music_panel.stop()


# --- Interface construction ---------------------------------------------------

func _build_ui() -> void:
	var theme_root := Theme.new()
	theme_root.default_font_size = 15
	theme = theme_root
	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel", _flat(Color("1d2026")))
	add_child(background)
	_background = background
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 0)
	background.add_child(page)
	page.add_child(_build_top_bar())
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = SIZE_EXPAND_FILL
	page.add_child(_tabs)
	var sfx_page := VBoxContainer.new()
	sfx_page.name = "SFX"
	_tabs.add_child(sfx_page)
	_sfx_workspace = OptionButton.new()
	_sfx_workspace.tooltip_text = "Independent sound workspace. Default audio uses sfx; alternate modes can use their own folder."
	_sfx_workspace.item_selected.connect(func(index: int) -> void:
		var folder := _sfx_workspace.get_item_text(index)
		_confirm_unsaved(func() -> void:
			library.folder_name = folder
			_open_root(library.root)))
	sfx_page.add_child(_sfx_workspace)
	var split := HSplitContainer.new()
	split.size_flags_vertical = SIZE_EXPAND_FILL
	sfx_page.add_child(split)
	split.add_child(_build_list())
	split.add_child(_build_editor())
	sfx_page.add_child(_build_status_bar())
	_music_panel = MusicPanel.new()
	_music_panel.name = "Music"
	_tabs.add_child(_music_panel)
	_tabs.tab_changed.connect(func(_index: int) -> void: _stop_all())
	_build_dialogs()
	_picker = ProjectPicker.new()
	_picker.hide()
	_picker.chosen.connect(_on_project_chosen)
	_picker.forgotten.connect(_on_project_forgotten)
	_picker.closed.connect(_hide_picker)
	add_child(_picker)


func _build_top_bar() -> Control:
	var bar := _panel(PANEL, 8)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.get_child(0).add_child(row)
	var logo := TextureRect.new()
	logo.texture = Icons.get_icon("fork", ACCENT, 26)
	logo.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(logo)
	var title := Label.new()
	title.text = "Tuning Fork"
	title.add_theme_font_size_override("font_size", 19)
	row.add_child(title)
	row.add_child(VSeparator.new())
	_root_label = Label.new()
	_root_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_root_label.clip_text = true
	_root_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_root_label.add_theme_color_override("font_color", DIM)
	_root_label.mouse_filter = MOUSE_FILTER_PASS
	row.add_child(_root_label)
	row.add_child(_icon_button("folder", "Projects: open another game folder",
		func() -> void: _confirm_unsaved(func() -> void: _show_picker())))
	row.add_child(_icon_button("reload", "Reload every event and the groups from disk",
		func() -> void: _confirm_unsaved(func() -> void:
			_open_root(library.root, GROUPS_ITEM if showing_groups else (current.path if current else "")))))
	_auto_play = CheckButton.new()
	_auto_play.icon = Icons.get_icon("speaker")
	_auto_play.tooltip_text = "Auto-play: replay the event after each change"
	_auto_play.toggled.connect(func(on: bool) -> void: _save_config("auto_play", on))
	row.add_child(_auto_play)
	return bar


func _build_list() -> Control:
	var margin := _margin(10)
	margin.custom_minimum_size.x = 260
	var column := VBoxContainer.new()
	margin.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	_filter = LineEdit.new()
	_filter.placeholder_text = "Filter"
	_filter.clear_button_enabled = true
	_filter.size_flags_horizontal = SIZE_EXPAND_FILL
	_filter.text_changed.connect(func(_t: String) -> void: _rebuild_tree())
	top.add_child(_filter)
	var add := _icon_button("plus", "New event", _ask_new_event)
	add.icon = Icons.get_icon("plus", ACCENT)
	add.flat = false
	top.add_child(add)
	_tree = Tree.new()
	_tree.hide_root = true
	_tree.size_flags_vertical = SIZE_EXPAND_FILL
	_tree.add_theme_constant_override("v_separation", 6)
	_tree.item_selected.connect(func() -> void:
		if _updating or _tree.get_selected() == null:
			return
		var picked = _tree.get_selected().get_metadata(0)
		if picked is SoundEntry:
			_select(picked)
		elif picked == GROUPS_ITEM:
			_select_groups())
	_tree.item_activated.connect(func() -> void: _play_once())
	column.add_child(_tree)
	return margin


func _build_editor() -> Control:
	var holder := Control.new()
	holder.size_flags_horizontal = SIZE_EXPAND_FILL
	_empty_hint = Label.new()
	_empty_hint.text = "Open a game folder"
	_empty_hint.add_theme_color_override("font_color", DIM)
	_empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_hint.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	holder.add_child(_empty_hint)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	holder.add_child(scroll)
	_editor = scroll
	var margin := _margin(18)
	margin.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(titles)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 26)
	titles.add_child(_name_label)
	_path_label = Label.new()
	_path_label.add_theme_color_override("font_color", DIM)
	_path_label.add_theme_font_size_override("font_size", 13)
	titles.add_child(_path_label)
	_rename_button = _icon_button("edit", "Rename or move this event (the game's code must follow)", _ask_rename)
	header.add_child(_rename_button)
	_delete_button = _icon_button("trash", "Move this event and its files to the recycle bin", _ask_delete)
	header.add_child(_delete_button)
	_revert_button = _icon_button("revert", "Revert to the file on disk", _revert_current)
	header.add_child(_revert_button)
	_save_button = _icon_button("save", "Save (Ctrl+S)", _save_current)
	_save_button.icon = Icons.get_icon("save", ACCENT)
	header.add_child(_save_button)

	column.add_child(_build_event_box())
	column.add_child(_build_groups_box())
	return holder


func _build_event_box() -> Control:
	_event_box = VBoxContainer.new()
	_event_box.add_theme_constant_override("separation", 12)
	_files_caption = HBoxContainer.new()
	_event_box.add_child(_files_caption)
	var link := TextureRect.new()
	link.texture = Icons.get_icon("link", DIM, 16)
	link.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_files_caption.add_child(link)
	_files_caption_label = Label.new()
	_files_caption_label.add_theme_color_override("font_color", DIM)
	_files_caption.add_child(_files_caption_label)
	_file_strip = HFlowContainer.new()
	_file_strip.add_theme_constant_override("h_separation", 10)
	_file_strip.add_theme_constant_override("v_separation", 10)
	_event_box.add_child(_file_strip)

	_description = LineEdit.new()
	_description.placeholder_text = "When the game plays this event"
	_description.text_changed.connect(_set_description)
	_event_box.add_child(_description)
	_problems_label = Label.new()
	_problems_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problems_label.add_theme_color_override("font_color", WARNING)
	_event_box.add_child(_problems_label)

	var card := _panel(CARD, 14)
	_event_box.add_child(card)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 10)
	card.get_child(0).add_child(_grid)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_event_box.add_child(row)
	var play := _icon_button("play", "Play: one file, as the game picks it (Space)", func() -> void: _play_once(), 30)
	play.icon = Icons.get_icon("play", ACCENT, 30)
	play.flat = false
	row.add_child(play)
	var stop := _icon_button("stop", "Stop (Esc)", _stop_all, 30)
	stop.flat = false
	row.add_child(stop)
	_scatter = PlayScatter.new()
	_scatter.tooltip_text = "Last plays: pitch across, volume (dB) up. The box is the random range."
	_event_box.add_child(_scatter)
	_last_label = Label.new()
	_last_label.add_theme_color_override("font_color", DIM)
	_event_box.add_child(_last_label)
	return _event_box


func _build_groups_box() -> Control:
	_groups_box = VBoxContainer.new()
	_groups_box.add_theme_constant_override("separation", 12)
	var intro := Label.new()
	intro.text = "Each event plays in one group; a group's volume adds to its events' volumes."
	intro.add_theme_color_override("font_color", DIM)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_groups_box.add_child(intro)
	var notes := Label.new()
	notes.name = "Notes"
	notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notes.add_theme_color_override("font_color", WARNING)
	_groups_box.add_child(notes)
	var card := _panel(CARD, 14)
	_groups_box.add_child(card)
	_groups_grid = GridContainer.new()
	_groups_grid.columns = 5
	_groups_grid.add_theme_constant_override("h_separation", 12)
	_groups_grid.add_theme_constant_override("v_separation", 10)
	card.get_child(0).add_child(_groups_grid)
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 8)
	_groups_box.add_child(add_row)
	_new_group = LineEdit.new()
	_new_group.placeholder_text = "new group"
	_new_group.custom_minimum_size.x = 180
	_new_group.text_submitted.connect(func(_t: String) -> void: _add_group())
	add_row.add_child(_new_group)
	var add := _icon_button("plus", "Add a group", _add_group)
	add.flat = false
	add_row.add_child(add)
	return _groups_box


func _build_status_bar() -> Control:
	var bar := _panel(PANEL, 6)
	var row := HBoxContainer.new()
	bar.get_child(0).add_child(row)
	_status = Label.new()
	_status.size_flags_horizontal = SIZE_EXPAND_FILL
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_status)
	_unsaved_label = Label.new()
	_unsaved_label.add_theme_color_override("font_color", ACCENT)
	_unsaved_label.tooltip_text = "Events and groups with unsaved changes"
	row.add_child(_unsaved_label)
	_save_all_button = _icon_button("save", "Save all (Ctrl+Shift+S)", func() -> void: _save_all(), 18)
	row.add_child(_save_all_button)
	return bar


func _build_dialogs() -> void:
	_add_dialog = FileDialog.new()
	_add_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	_add_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_add_dialog.use_native_dialog = true
	_add_dialog.title = "Sound files to add"
	_add_dialog.filters = PackedStringArray(["*.wav, *.ogg ; WAV and OGG sounds"])
	_add_dialog.files_selected.connect(_add_files)
	add_child(_add_dialog)

	_confirm = ConfirmationDialog.new()
	_confirm.title = "Unsaved changes"
	_confirm.ok_button_text = "Save all"
	_confirm.add_button("Discard", true, "discard")
	_confirm.confirmed.connect(func() -> void:
		if _save_all():
			_after_confirm.call())
	_confirm.custom_action.connect(func(action: StringName) -> void:
		if action == &"discard":
			_confirm.hide()
			_music_panel.discard_all()
			_after_confirm.call())
	add_child(_confirm)

	_remove_dialog = ConfirmationDialog.new()
	_remove_dialog.title = "Remove file"
	_remove_dialog.ok_button_text = "Move to recycle bin"
	_remove_dialog.confirmed.connect(_remove_file)
	add_child(_remove_dialog)

	_new_dialog = _form_dialog("New event", "Create", _create_event)
	var form: VBoxContainer = _new_dialog.get_child(0)
	_new_folder = _form_field(form, "Folder", "combat, or enemies/boss")
	_new_name = _form_field(form, "Name", "hit")
	_new_description = _form_field(form, "When the game plays it", "A melee hit lands.")
	_new_error = _form_error(form)

	_rename_dialog = _form_dialog("Rename or move event", "Rename", _rename_event)
	form = _rename_dialog.get_child(0)
	_rename_path = _form_field(form, "Path (folders/name)", "combat/hit")
	var note := Label.new()
	note.text = "The game's code must play the new path. Events taking this event's files follow."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", DIM)
	form.add_child(note)
	_rename_error = _form_error(form)

	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "Delete event"
	_delete_dialog.ok_button_text = "Move to recycle bin"
	_delete_dialog.confirmed.connect(_delete_event)
	add_child(_delete_dialog)


## A dialog with a form (its first child) that stays open until `action`
## hides it.
func _form_dialog(title: String, ok_text: String, action: Callable) -> ConfirmationDialog:
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.ok_button_text = ok_text
	dialog.dialog_hide_on_ok = false
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 6)
	dialog.add_child(form)
	dialog.confirmed.connect(action)
	add_child(dialog)
	return dialog


func _form_field(form: VBoxContainer, caption: String, placeholder: String) -> LineEdit:
	form.add_child(_caption(caption))
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.custom_minimum_size.x = 420
	edit.text_submitted.connect(func(_t: String) -> void: form.get_parent().confirmed.emit())
	form.add_child(edit)
	return edit


func _form_error(form: VBoxContainer) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", WARNING)
	form.add_child(label)
	return label


# --- Small helpers ---------------------------------------------------------

func _icon_button(shape: String, tooltip: String, action: Callable, size := 20) -> Button:
	var button := Button.new()
	button.icon = Icons.get_icon(shape, Color.WHITE, size)
	button.tooltip_text = tooltip
	button.flat = true
	button.focus_mode = FOCUS_NONE
	if action.is_valid():
		button.pressed.connect(action)
	return button


func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", DIM)
	return label


func _flat(color: Color, radius := 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	return box


## A panel with a margin container inside (its first child).
func _panel(color: Color, margin: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(color, 6 if color == CARD else 0))
	panel.add_child(_margin(margin))
	return panel


func _margin(amount: int) -> MarginContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, amount)
	return margin


func _set_status(text: String, warning := false) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", WARNING if warning else Color(1, 1, 1, 0.75))


func _save_config(key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value("tool", key, value)
	config.save(CONFIG_PATH)


func _user_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			args[arg.substr(2).get_slice("=", 0)] = arg.get_slice("=", 1)
	return args


## Plays the selected event a few times muted (to show the plays), saves the
## window and quits.
func _take_screenshot(path: String) -> void:
	AudioServer.set_bus_mute(0, true)
	for i in 6:
		_play_once()
		await get_tree().create_timer(0.2).timeout
	# Low-processor mode draws only on change: ask for one more frame.
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
