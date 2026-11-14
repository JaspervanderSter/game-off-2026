extends Control
## Tuning Fork: lists a game's sounds, shows each sound's files as waveforms,
## plays them as the game does, edits their JSON settings live and saves them
## back beside the sounds. WAV and OGG files dropped on the window are added to
## the selected sound (WAV converted to OGG with oggenc).
##
## Command-line user arguments (after `--`):
##   --root=<folder>     game folder holding sfx/ and music/
##   --select=<sound>    sound selected at start
##   --screenshot=<png>  plays a muted series, saves the window to this file, quits

const CONFIG_PATH := "user://tuning_fork.cfg"
## Slider range of each number setting: [min, max, step]. The number boxes
## accept values beyond the slider.
const RANGES := {
	"volume_db": [-40.0, 12.0, 0.1],
	"volume_jitter_db": [0.0, 12.0, 0.1],
	"pitch": [0.25, 4.0, 0.01],
	"pitch_jitter": [0.0, 0.5, 0.005],
	"pitch_step": [-0.5, 0.5, 0.005],
	"cooldown_ms": [0.0, 1000.0, 1.0],
	"shuffle_refill_after": [0.0, 16.0, 1.0],
	"fade_seconds": [0.0, 10.0, 0.05],
	"frenzy_speed_per_level": [0.0, 0.5, 0.005],
}
const HINTS := {
	"volume_db": "Loudness in dB (0 = as recorded)",
	"volume_jitter_db": "Random loudness change per play, up to ± this many dB",
	"pitch": "Playback pitch (1 = as recorded); pitch also changes speed",
	"pitch_jitter": "Random pitch change per play, up to ± this amount",
	"pitch_step": "Pitch added per step of a series (each harvest coin)",
	"cooldown_ms": "A repeat of the same sound sooner than this is skipped",
	"pick": "How each play chooses a file: shuffle plays every file once in a random order before any repeats; random draws any file each time",
	"shuffle_refill_after": "Shuffle only: deal the files again after this many plays, before all have played (0 = after all of them)",
	"fade_seconds": "Seconds of a full music fade in or out",
	"frenzy_speed_per_level": "Battle music speed-up per frenzy level",
}
const FRENZY_LEVELS := 5
const ACCENT := Color(0.98, 0.72, 0.30)
const DIM := Color(1, 1, 1, 0.45)
const WARNING := Color(1.0, 0.62, 0.35)
const PANEL := Color("16181d")
const CARD := Color("23272f")

var library := SoundLibrary.new()
var sound_player: SoundPlayer
var music: MusicPreview
var current: SoundEntry

var _items := {}
var _rows := {}
var _cards: Array[WaveCard] = []
var _updating := false
var _series_token := 0
var _series_running := false
var _after_confirm := Callable()
var _last_track := ""
var _pending_removal := -1

var _root_label: Label
var _auto_play: CheckButton
var _filter: LineEdit
var _tree: Tree
var _editor: Control
var _empty_hint: Label
var _name_label: Label
var _path_label: Label
var _save_button: Button
var _revert_button: Button
var _description: LineEdit
var _problems_label: Label
var _files_box: VBoxContainer
var _file_strip: HFlowContainer
var _grid: GridContainer
var _effect_box: VBoxContainer
var _step_spin: SpinBox
var _count_spin: SpinBox
var _interval_spin: SpinBox
var _loop_toggle: Button
var _scatter: PlayScatter
var _last_label: Label
var _music_box: VBoxContainer
var _track_list: VBoxContainer
var _track_buttons := {}
var _track_bars := {}
var _frenzy_slider: HSlider
var _frenzy_label: Label
var _status: Label
var _unsaved_label: Label
var _save_all_button: Button
var _auto_timer: Timer
var _folder_dialog: FileDialog
var _add_dialog: FileDialog
var _confirm: ConfirmationDialog
var _remove_dialog: ConfirmationDialog


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	sound_player = SoundPlayer.new()
	add_child(sound_player)
	sound_player.played.connect(_on_played)
	music = MusicPreview.new()
	add_child(music)
	_build_ui()
	get_window().files_dropped.connect(_add_files)
	var disk_timer := Timer.new()
	disk_timer.wait_time = 1.0
	disk_timer.autostart = true
	disk_timer.timeout.connect(_check_disk)
	add_child(disk_timer)
	_auto_timer = Timer.new()
	_auto_timer.one_shot = true
	_auto_timer.wait_time = 0.25
	_auto_timer.timeout.connect(func() -> void: if not _series_running: _play_step(int(_step_spin.value)))
	add_child(_auto_timer)

	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	_auto_play.set_pressed_no_signal(bool(config.get_value("tool", "auto_play", true)))
	var args := _user_args()
	var root: String = args.get("root", config.get_value("tool", "root", ""))
	if root == "" or not DirAccess.dir_exists_absolute(root):
		root = _find_game_folder()
	_open_root(root, args.get("select", config.get_value("tool", "selected", "")))
	if args.has("screenshot"):
		_take_screenshot(args["screenshot"])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_confirm_unsaved(func() -> void: get_tree().quit())
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and library.root != "":
		_check_disk()


func _process(_dt: float) -> void:
	for id: String in _track_bars:
		_track_bars[id].value = music.weight(id)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	var typing := get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is TextEdit
	if key.keycode == KEY_S and key.is_command_or_control_pressed():
		if key.shift_pressed:
			_save_all()
		else:
			_save_current()
	elif key.keycode == KEY_SPACE and not typing:
		_play_pressed()
	elif key.keycode == KEY_ESCAPE:
		_stop_all()
		if typing:
			get_viewport().gui_release_focus()
	else:
		return
	get_viewport().set_input_as_handled()


# --- Folder and selection -------------------------------------------------

## Newest prototype of this repository that has an sfx/ folder. The repository
## is the nearest folder above the project (or, exported, above the executable)
## that holds prototypes/.
func _find_game_folder() -> String:
	var start := ProjectSettings.globalize_path("res://")
	if OS.has_feature("template"):
		start = OS.get_executable_path().get_base_dir()
	var prototypes := ""
	var dir := start.simplify_path()
	for i in 6:
		if DirAccess.dir_exists_absolute(dir.path_join("prototypes")):
			prototypes = dir.path_join("prototypes")
			break
		dir = dir.get_base_dir()
	var found := ""
	if prototypes != "":
		var folders := Array(DirAccess.get_directories_at(prototypes))
		folders.sort()
		for folder: String in folders:
			if DirAccess.dir_exists_absolute(prototypes.path_join(folder).path_join("sfx")):
				found = prototypes.path_join(folder)
	return found


func _open_root(root: String, select := "") -> void:
	_stop_all()
	music.stop_now()
	current = null
	var error := library.open(root) if root != "" else "Open a game folder: the one holding sfx/ and music/"
	_root_label.text = library.root if error == "" else "—"
	_root_label.tooltip_text = _root_label.text
	music.settings = library.music
	music.set_tracks(library.music_tracks)
	_build_track_list()
	_rebuild_tree()
	if error != "":
		_set_status(error, true)
		_show_entry()
		return
	_save_config("root", library.root)
	_set_status("%d sounds in %s" % [library.sounds.size(), library.root])
	var entry := library.find(select)
	if entry == null and not library.sounds.is_empty():
		entry = library.sounds[0]
	_select(entry)


func _select(entry: SoundEntry) -> void:
	if entry != current:
		_stop_series()
		current = entry
		_scatter.clear_points()
		_last_label.text = ""
		if entry != null:
			_save_config("selected", entry.name)
	if entry != null and _items.has(entry) and _tree.get_selected() != _items[entry]:
		_updating = true
		_items[entry].select(0)
		_tree.scroll_to_item(_items[entry])
		_updating = false
	_show_entry()


func _rebuild_tree() -> void:
	_updating = true
	_tree.clear()
	_items.clear()
	var tree_root := _tree.create_item()
	var filter := _filter.text.strip_edges().to_lower()
	var groups := {}
	for entry in library.all_entries():
		if filter != "" and not entry.name.to_lower().contains(filter) and not entry.category.to_lower().contains(filter):
			continue
		var category := entry.category if entry.category != "" else "sfx"
		if not groups.has(category):
			var group := _tree.create_item(tree_root)
			group.set_text(0, category)
			group.set_selectable(0, false)
			group.set_custom_color(0, DIM)
			groups[category] = group
		var item := _tree.create_item(groups[category])
		item.set_metadata(0, entry)
		item.set_icon(0, Icons.get_icon("note" if entry.is_music else "wave", Color(1, 1, 1, 0.7), 16))
		_items[entry] = item
		_update_item(entry)
	if current != null and _items.has(current):
		_items[current].select(0)
	_updating = false


func _update_item(entry: SoundEntry) -> void:
	if _items.has(entry):
		var item: TreeItem = _items[entry]
		var dirty := entry.is_dirty()
		var text := entry.name
		if entry.files.size() > 1:
			text += "  ×%d" % entry.files.size()
		item.set_text(0, text + ("  ●" if dirty else ""))
		if dirty:
			item.set_custom_color(0, ACCENT)
		elif not entry.problems.is_empty() or not entry.file_problems.is_empty() or (not entry.is_music and entry.files.is_empty()):
			item.set_custom_color(0, WARNING)
		else:
			item.clear_custom_color(0)
	var unsaved := _unsaved().size()
	_unsaved_label.text = "● %d" % unsaved if unsaved > 0 else ""
	_save_all_button.disabled = unsaved == 0


func _unsaved() -> Array[SoundEntry]:
	var list: Array[SoundEntry] = []
	for entry in library.all_entries():
		if entry.is_dirty():
			list.append(entry)
	return list


# --- Showing the selected sound -----------------------------------------------

func _show_entry() -> void:
	_editor.visible = current != null
	_empty_hint.visible = current == null
	if current == null:
		return
	_updating = true
	_name_label.text = current.name
	var path_text := library.relative(current.json_path)
	if not current.is_music:
		path_text += "   ·   %d file%s" % [current.files.size(), "" if current.files.size() == 1 else "s"]
	_path_label.text = path_text
	_description.text = str(current.data.get("description", ""))
	_effect_box.visible = not current.is_music
	_music_box.visible = current.is_music
	_files_box.visible = not current.is_music
	_build_cards()
	_build_rows()
	_updating = false
	_refresh()


## Updates everything that follows the values: rows, markers, scatter range.
func _refresh() -> void:
	if current == null:
		return
	_updating = true
	for key: String in _rows:
		_refresh_row(key)
	_updating = false
	var notes: Array[String] = current.problems.duplicate()
	notes.append_array(current.file_problems)
	if not current.has_json:
		notes.append("No JSON file yet: saving creates %s" % library.relative(current.json_path))
	if not current.is_music and current.files.is_empty():
		notes.append("No sound file yet: drop a WAV or OGG file on the window")
	if current.changed_on_disk:
		notes.append("The JSON file changed on disk: revert to load it, or save to replace it")
	_problems_label.text = "\n".join(notes)
	_problems_label.visible = not notes.is_empty()
	var dirty := current.is_dirty()
	_save_button.disabled = not dirty and current.has_json
	_revert_button.disabled = not dirty and not current.changed_on_disk
	_update_item(current)
	if not current.is_music:
		_update_scatter_range(int(_step_spin.value))
	_frenzy_label.text = "×%.2f" % music.speed()


func _update_scatter_range(step: int) -> void:
	_scatter.set_range(
		SoundPlayer.base_pitch(current, step), float(current.setting("pitch_jitter")),
		float(current.setting("volume_db")), float(current.setting("volume_jitter_db")))


## One waveform card per file of the current sound, then the add card.
func _build_cards() -> void:
	for child in _file_strip.get_children():
		_file_strip.remove_child(child)
		child.queue_free()
	_cards.clear()
	if current == null or current.is_music:
		return
	for i in current.files.size():
		var card := WaveCard.new()
		card.setup(i, current.files[i], current.streams[i])
		card.play_requested.connect(func(index: int) -> void:
			_stop_series()
			_play_step(int(_step_spin.value), index))
		card.remove_requested.connect(_ask_remove_file)
		_file_strip.add_child(card)
		_cards.append(card)
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
		if key == "pick":
			_add_pick_row()
		else:
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


func _add_pick_row() -> void:
	var row := _row_start("pick")
	var options := OptionButton.new()
	for mode: String in SoundLibrary.PICK_MODES:
		options.add_item(mode)
	options.tooltip_text = HINTS["pick"]
	options.size_flags_horizontal = SIZE_SHRINK_BEGIN
	options.custom_minimum_size.x = 160
	options.item_selected.connect(func(i: int) -> void:
		if not _updating and current != null:
			current.data["pick"] = SoundLibrary.PICK_MODES[i]
			sound_player.reset_pick(current)
			_after_edit(false))
	_grid.add_child(options)
	_grid.add_child(Control.new())
	row["options"] = options
	_row_end("pick", row)


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


func _refresh_row(key: String) -> void:
	var row: Dictionary = _rows[key]
	var value = current.setting(key)
	var default = current.defaults()[key]
	row["reset"].disabled = str(value) == str(default) if default is String \
		else is_equal_approx(float(value), float(default))
	if key == "pick":
		row["options"].select(maxi(0, SoundLibrary.PICK_MODES.find(str(value))))
		return
	var number := float(value)
	row["slider"].set_value_no_signal(number)
	row["spin"].set_value_no_signal(number)
	# The refill count only applies to shuffle.
	var active: bool = key != "shuffle_refill_after" or str(current.setting("pick")) == "shuffle"
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


func _reset_value(key: String) -> void:
	if current == null:
		return
	current.data[key] = current.defaults()[key]
	sound_player.reset_pick(current)
	_after_edit()


func _set_description(text: String) -> void:
	if _updating or current == null:
		return
	current.data["description"] = text
	_after_edit(false)


func _after_edit(replay := true) -> void:
	_refresh()
	if replay and _auto_play.button_pressed and not current.is_music:
		_auto_timer.start()


# --- Sound files -------------------------------------------------------------

## Adds dropped or chosen WAV/OGG files to the current sound.
func _add_files(paths: PackedStringArray) -> void:
	if current == null or current.is_music:
		_set_status("Select a sound to add files to it", true)
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
	_show_entry()
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
	_show_entry()
	if problem != "":
		_set_status(problem, true)
	else:
		_set_status("Moved %s to the recycle bin" % file_name)


# --- Saving ----------------------------------------------------------------

func _save_current() -> void:
	if current != null:
		_save_entries([current])


func _save_all() -> bool:
	return _save_entries(_unsaved())


func _save_entries(entries: Array[SoundEntry]) -> bool:
	var saved: Array[String] = []
	for entry in entries:
		var error := entry.save()
		if error != OK:
			_set_status("Could not save %s (%s)" % [entry.json_path, error_string(error)], true)
			return false
		saved.append(entry.name)
		_update_item(entry)
	if not saved.is_empty():
		_set_status("Saved " + ", ".join(saved))
	_refresh()
	return true


func _revert_current() -> void:
	if current == null:
		return
	current.load_settings()
	sound_player.reset_pick(current)
	_set_status("Reloaded %s" % library.relative(current.json_path))
	_show_entry()


## Runs `then` now, or once the user saved or discarded unsaved changes.
func _confirm_unsaved(then: Callable) -> void:
	var unsaved := _unsaved()
	if unsaved.is_empty():
		then.call()
		return
	_after_confirm = then
	_confirm.dialog_text = "Unsaved changes: %s" % ", ".join(unsaved.map(func(e: SoundEntry) -> String: return e.name))
	_confirm.popup_centered(Vector2i(440, 0))


## Reloads sounds and settings that changed on disk (another editor, new files).
func _check_disk() -> void:
	var reloaded: Array[String] = []
	var current_changed := false
	for entry in library.all_entries():
		if entry.files_changed_on_disk():
			entry.load_files()
			sound_player.reset_pick(entry)
			reloaded.append(entry.name + " files")
			current_changed = current_changed or entry == current
		if entry.json_changed_on_disk():
			if entry.is_dirty():
				entry.changed_on_disk = true
				entry.json_time = FileAccess.get_modified_time(entry.json_path)
			else:
				entry.load_settings()
				reloaded.append(entry.name + ".json")
			current_changed = current_changed or entry == current
		_update_item(entry)
	var tracks := library.reload_changed_tracks()
	if not tracks.is_empty():
		music.set_tracks(library.music_tracks)
		_build_track_list()
		reloaded.append_array(tracks)
	if not reloaded.is_empty():
		_set_status("Reloaded from disk: " + ", ".join(reloaded))
	if current_changed:
		_show_entry()


# --- Playing ---------------------------------------------------------------

func _play_pressed() -> void:
	if current == null:
		return
	if current.is_music:
		var track := _last_track if _last_track != "" else str(library.music_tracks.keys().front() if not library.music_tracks.is_empty() else "")
		_play_track(track, music.current != track)
	else:
		_stop_series()
		_play_step(int(_step_spin.value))


## Plays the current sound at `step`: file `file_index`, or the one it picks.
func _play_step(step: int, file_index := -1) -> void:
	if current == null or current.is_music:
		return
	if current.files.is_empty():
		_set_status("%s has no sound file: drop a WAV or OGG file on the window" % current.name, true)
	elif not sound_player.play(current, step, file_index):
		_last_label.text = "step %d skipped: repeated within cooldown_ms" % step


func _on_played(entry: SoundEntry, file_index: int, step: int, pitch: float, volume_db: float, voice: AudioStreamPlayer) -> void:
	if entry != current:
		return
	_update_scatter_range(step)
	_scatter.add_point(pitch, volume_db)
	_last_label.text = "%s   ·   step %d   ·   pitch %.3f   ·   %.1f dB" % [
		entry.files[file_index].get_file(), step, pitch, volume_db]
	for card in _cards:
		if card.index == file_index:
			card.show_play(voice, pitch)
		else:
			card.clear_play()


## Plays `count` steps from the step box, `interval` ms apart, looping if set.
func _play_series() -> void:
	_stop_series()
	if current == null or current.is_music:
		return
	var token := _series_token
	var first := int(_step_spin.value)
	var i := 0
	_series_running = true
	while token == _series_token and current != null:
		_play_step(first + i)
		i += 1
		if i >= int(_count_spin.value):
			if not _loop_toggle.button_pressed:
				break
			i = 0
		await get_tree().create_timer(_interval_spin.value / 1000.0).timeout
	if token == _series_token:
		_series_running = false


func _stop_series() -> void:
	_series_token += 1
	_series_running = false


func _stop_all() -> void:
	_stop_series()
	sound_player.stop_all()
	music.transition_to("")
	_refresh_track_buttons()


func _play_track(id: String, on: bool) -> void:
	if id == "":
		return
	_last_track = id
	music.transition_to(id if on else "")
	_refresh_track_buttons()


func _refresh_track_buttons() -> void:
	for id: String in _track_buttons:
		_track_buttons[id].set_pressed_no_signal(music.current == id)


# --- Interface construction ---------------------------------------------------

func _build_ui() -> void:
	var theme_root := Theme.new()
	theme_root.default_font_size = 15
	theme = theme_root
	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel", _flat(Color("1d2026")))
	add_child(background)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 0)
	background.add_child(page)
	page.add_child(_build_top_bar())
	var split := HSplitContainer.new()
	split.size_flags_vertical = SIZE_EXPAND_FILL
	page.add_child(split)
	split.add_child(_build_list())
	split.add_child(_build_editor())
	page.add_child(_build_status_bar())
	_build_dialogs()


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
	row.add_child(_icon_button("folder", "Open a game folder (the one holding sfx/ and music/)",
		func() -> void: _confirm_unsaved(func() -> void: _folder_dialog.popup_centered_ratio(0.6))))
	row.add_child(_icon_button("reload", "Reload every sound and settings file from disk",
		func() -> void: _confirm_unsaved(func() -> void: _open_root(library.root, current.name if current else ""))))
	_auto_play = CheckButton.new()
	_auto_play.icon = Icons.get_icon("speaker")
	_auto_play.tooltip_text = "Auto-play: replay the sound after each change"
	_auto_play.toggled.connect(func(on: bool) -> void: _save_config("auto_play", on))
	row.add_child(_auto_play)
	return bar


func _build_list() -> Control:
	var margin := _margin(10)
	margin.custom_minimum_size.x = 250
	var column := VBoxContainer.new()
	margin.add_child(column)
	_filter = LineEdit.new()
	_filter.placeholder_text = "Filter"
	_filter.clear_button_enabled = true
	_filter.text_changed.connect(func(_t: String) -> void: _rebuild_tree())
	column.add_child(_filter)
	_tree = Tree.new()
	_tree.hide_root = true
	_tree.size_flags_vertical = SIZE_EXPAND_FILL
	_tree.add_theme_constant_override("v_separation", 6)
	_tree.item_selected.connect(func() -> void:
		if not _updating and _tree.get_selected() != null:
			_select(_tree.get_selected().get_metadata(0)))
	_tree.item_activated.connect(_play_pressed)
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
	_revert_button = _icon_button("revert", "Revert the settings to the file on disk", _revert_current)
	header.add_child(_revert_button)
	_save_button = _icon_button("save", "Save the settings (Ctrl+S)", _save_current)
	_save_button.icon = Icons.get_icon("save", ACCENT)
	header.add_child(_save_button)

	_files_box = VBoxContainer.new()
	column.add_child(_files_box)
	_file_strip = HFlowContainer.new()
	_file_strip.add_theme_constant_override("h_separation", 10)
	_file_strip.add_theme_constant_override("v_separation", 10)
	_files_box.add_child(_file_strip)

	_description = LineEdit.new()
	_description.placeholder_text = "When the game plays this sound"
	_description.text_changed.connect(_set_description)
	column.add_child(_description)
	_problems_label = Label.new()
	_problems_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problems_label.add_theme_color_override("font_color", WARNING)
	column.add_child(_problems_label)

	var card := _panel(CARD, 14)
	column.add_child(card)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 10)
	card.get_child(0).add_child(_grid)

	column.add_child(_build_effect_box())
	column.add_child(_build_music_box())
	return holder


func _build_effect_box() -> Control:
	_effect_box = VBoxContainer.new()
	_effect_box.add_theme_constant_override("separation", 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_effect_box.add_child(row)
	var play := _icon_button("play", "Play: one file, as the game picks it (Space)", _play_pressed, 30)
	play.icon = Icons.get_icon("play", ACCENT, 30)
	play.flat = false
	row.add_child(play)
	row.add_child(_caption("step"))
	_step_spin = _spin(0, 999, 1, 0, "Position in a series: adds pitch_step per step")
	_step_spin.value_changed.connect(func(_v: float) -> void: _refresh())
	row.add_child(_step_spin)
	row.add_child(VSeparator.new())
	var series := _icon_button("series", "Play a series of steps from the step above", _play_series, 24)
	series.flat = false
	row.add_child(series)
	_count_spin = _spin(1, 64, 1, 8, "Steps in the series")
	row.add_child(_count_spin)
	row.add_child(_caption("×"))
	_interval_spin = _spin(10, 2000, 10, 180, "Milliseconds between steps")
	_interval_spin.suffix = "ms"
	row.add_child(_interval_spin)
	_loop_toggle = _icon_button("loop", "Loop the series until stopped", Callable(), 24)
	_loop_toggle.toggle_mode = true
	_loop_toggle.flat = false
	row.add_child(_loop_toggle)
	var stop := _icon_button("stop", "Stop (Esc)", _stop_all, 24)
	stop.flat = false
	row.add_child(stop)
	_scatter = PlayScatter.new()
	_scatter.tooltip_text = "Last plays: pitch across, volume (dB) up. The box is the random range."
	_effect_box.add_child(_scatter)
	_last_label = Label.new()
	_last_label.add_theme_color_override("font_color", DIM)
	_effect_box.add_child(_last_label)
	return _effect_box


func _build_music_box() -> Control:
	_music_box = VBoxContainer.new()
	_music_box.add_theme_constant_override("separation", 10)
	_track_list = VBoxContainer.new()
	_track_list.add_theme_constant_override("separation", 6)
	_music_box.add_child(_track_list)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_music_box.add_child(row)
	row.add_child(_caption("frenzy"))
	_frenzy_slider = HSlider.new()
	_frenzy_slider.min_value = 0
	_frenzy_slider.max_value = FRENZY_LEVELS
	_frenzy_slider.step = 1
	_frenzy_slider.tick_count = FRENZY_LEVELS + 1
	_frenzy_slider.ticks_on_borders = true
	_frenzy_slider.custom_minimum_size.x = 220
	_frenzy_slider.size_flags_vertical = SIZE_SHRINK_CENTER
	_frenzy_slider.tooltip_text = "Frenzy level of the battle: speeds up the music"
	_frenzy_slider.value_changed.connect(func(v: float) -> void:
		music.frenzy_level = int(v)
		_frenzy_label.text = "×%.2f" % music.speed())
	row.add_child(_frenzy_slider)
	_frenzy_label = Label.new()
	row.add_child(_frenzy_label)
	row.add_child(VSeparator.new())
	var stop := _icon_button("stop", "Fade out (Esc)", _stop_all, 24)
	stop.flat = false
	row.add_child(stop)
	return _music_box


func _build_track_list() -> void:
	for child in _track_list.get_children():
		child.queue_free()
	_track_buttons.clear()
	_track_bars.clear()
	for id: String in library.music_tracks:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_track_list.add_child(row)
		var button := Button.new()
		button.toggle_mode = true
		button.text = id
		button.icon = Icons.get_icon("play", ACCENT, 20)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.x = 220
		button.tooltip_text = "Fade this track in (Space replays the last one)"
		button.toggled.connect(func(on: bool) -> void: _play_track(id, on))
		row.add_child(button)
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(200, 8)
		bar.size_flags_vertical = SIZE_SHRINK_CENTER
		bar.size_flags_horizontal = SIZE_EXPAND_FILL
		bar.tooltip_text = "Fade amount"
		row.add_child(bar)
		_track_buttons[id] = button
		_track_bars[id] = bar


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
	_unsaved_label.tooltip_text = "Sounds with unsaved changes"
	row.add_child(_unsaved_label)
	_save_all_button = _icon_button("save", "Save all (Ctrl+Shift+S)", func() -> void: _save_all(), 18)
	row.add_child(_save_all_button)
	return bar


func _build_dialogs() -> void:
	_folder_dialog = FileDialog.new()
	_folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_folder_dialog.use_native_dialog = true
	_folder_dialog.title = "Game folder (holding sfx/ and music/)"
	_folder_dialog.dir_selected.connect(func(dir: String) -> void: _open_root(dir))
	add_child(_folder_dialog)

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
			_after_confirm.call())
	add_child(_confirm)

	_remove_dialog = ConfirmationDialog.new()
	_remove_dialog.title = "Remove file"
	_remove_dialog.ok_button_text = "Move to recycle bin"
	_remove_dialog.confirmed.connect(_remove_file)
	add_child(_remove_dialog)


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


func _spin(low: float, high: float, step: float, value: float, tooltip: String) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.value = value
	spin.select_all_on_focus = true
	spin.tooltip_text = tooltip
	return spin


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


## Plays a muted series (to show the plays), saves the window and quits.
func _take_screenshot(path: String) -> void:
	AudioServer.set_bus_mute(0, true)
	_play_series()
	await get_tree().create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
