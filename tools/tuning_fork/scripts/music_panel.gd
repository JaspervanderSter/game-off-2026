class_name MusicPanel
extends HSplitContainer
## Generic music browser/editor. No game names, phases or track paths here.
var game_root := ""
var _workspace: OptionButton
var catalog := MusicCatalog.new()
var current := {}
var voice: MusicVoice
var _list: ItemList
var _form: VBoxContainer
var _status: Label
var _filter: LineEdit
var _shown: Array[Dictionary] = []
var _signature := ""
var _dialog: FileDialog
var _replace := false
var _card: WaveCard
var _auto := false
var _timer: Timer
var _context_voices := {}

func _ready() -> void:
	voice = MusicVoice.new()
	voice.volume_linear = 0.0
	add_child(voice)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 290
	add_child(left)
	_workspace = OptionButton.new()
	_workspace.tooltip_text = "Independent music workspace"
	_workspace.item_selected.connect(func(index: int) -> void:
		if not unsaved_paths().is_empty():
			_status.text = "Save or revert music changes before switching workspace."
			_workspace.select(_music_folders().find(catalog.root.trim_prefix(game_root + "/")))
			return
		_open_folder(game_root.path_join(_workspace.get_item_text(index))))
	left.add_child(_workspace)
	_filter = LineEdit.new()
	_filter.placeholder_text = "Filter music and configurations"
	_filter.text_changed.connect(func(_text: String) -> void: _rebuild_list())
	left.add_child(_filter)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(index: int) -> void: select(_shown[index].path))
	left.add_child(_list)
	var add := Button.new()
	add.text = "Import music (WAV / OGG)"
	add.icon = Icons.get_icon("plus")
	add.pressed.connect(func() -> void:
		_replace = false
		_dialog.popup_centered_ratio(0.65))
	left.add_child(add)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_theme_constant_override("separation", 10)
	scroll.add_child(_form)
	_dialog = FileDialog.new()
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	_dialog.filters = PackedStringArray(["*.ogg,*.wav ; Audio files"])
	_dialog.files_selected.connect(add_files)
	add_child(_dialog)
	_timer = Timer.new()
	_timer.wait_time = 0.3
	_timer.one_shot = true
	_timer.timeout.connect(play_current)
	add_child(_timer)
	_show_current()

func _music_folders() -> Array[String]:
	return SoundLibrary.workspace_folders(game_root, "music")

func open(folder: String) -> void:
	game_root = folder
	_workspace.clear()
	var folders := _music_folders()
	for workspace in folders:
		_workspace.add_item(workspace)
	_open_folder(game_root.path_join(folders[0] if not folders.is_empty() else "music"))

func _open_folder(folder: String) -> void:
	stop()
	current = {}
	catalog.open(folder)
	_signature = catalog.signature()
	_rebuild_list()
	if not catalog.entries.is_empty():
		select(catalog.entries[0].path)
	else:
		_show_current()

func _rebuild_list() -> void:
	_list.clear()
	_shown.clear()
	for entry in catalog.entries:
		if _filter.text != "" and _filter.text.to_lower() not in str(entry.path).to_lower():
			continue
		_shown.append(entry)
		_list.add_item(entry.path + (" *" if dirty(entry) else ""), Icons.get_icon("wave" if entry.audio != "" else "mixer"))
		var index := _list.item_count - 1
		_list.set_item_tooltip(index, entry.json)
		if entry.error != "":
			_list.set_item_custom_fg_color(index, Color("ff9e65"))
		if entry == current:
			_list.select(index)

func select(path: String) -> void:
	stop()
	current = catalog.find(path)
	_show_current()
	_rebuild_list()

static func dirty(entry: Dictionary) -> bool:
	return JSON.stringify(entry.data, "\t", false) + "\n" != entry.saved

func unsaved_paths() -> Array[String]:
	var result: Array[String] = []
	for entry in catalog.entries:
		if dirty(entry):
			result.append("music/" + entry.path)
	return result

func save_all() -> bool:
	for entry in catalog.entries:
		if dirty(entry) and not save(entry):
			return false
	return true

func save(entry: Dictionary) -> bool:
	if entry.audio != "":
		var problem := MusicCatalog.problems(entry.data)
		if problem != "":
			_status.text = problem
			return false
		var check_voice := MusicVoice.new()
		var candidate := entry.duplicate(true)
		candidate.error = MusicCatalog.problems(candidate.data)
		var valid := check_voice.configure(candidate)
		check_voice.free()
		if not valid:
			_status.text = "Cannot save: unreadable audio or segment outside the track"
			return false
	var error := MusicCatalog.save_entry(entry)
	_status.text = "Saved " + entry.json if error == OK else "Save failed: " + error_string(error)
	_signature = catalog.signature()
	_rebuild_list()
	return error == OK

func check_disk() -> void:
	if catalog.root == "":
		return
	var fresh := MusicCatalog.new()
	fresh.open(catalog.root)
	var fingerprint := fresh.signature()
	if fingerprint == _signature:
		return
	_signature = fingerprint
	var selected := str(current.get("path", ""))
	var conflicts := []
	for entry in catalog.entries:
		if dirty(entry):
			var next := fresh.find(entry.path)
			if next.is_empty() or next.saved != entry.saved:
				conflicts.append(entry.path)
			if not next.is_empty():
				fresh.entries.erase(next)
			fresh.entries.append(entry)
	catalog = fresh
	current = catalog.find(selected)
	_show_current()
	_rebuild_list()
	_status.text = "Reloaded changed files" if conflicts.is_empty() else "External changes conflict with your edits. Save to overwrite or Revert: " + ", ".join(conflicts)

func _show_current() -> void:
	for child in _form.get_children():
		_form.remove_child(child)
		child.queue_free()
	_card = null
	if current.is_empty():
		_label("No music yet. Import a WAV/OGG or add files under music/.")
		_status = _label("")
		return
	_label(current.path, 22)
	var location := _label(current.json)
	location.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := HBoxContainer.new()
	_form.add_child(actions)
	_button(actions, "Save", func() -> void: save(current), "save")
	_button(actions, "Revert", func() -> void:
		revert_current(), "reload")
	if current.audio != "":
		_button(actions, "Play", play_current, "play")
		_button(actions, "Stop", stop, "stop")
		_button(actions, "Replace audio", func() -> void:
			_replace = true
			_dialog.popup_centered_ratio(0.65), "folder")
		var auto := CheckButton.new()
		auto.text = "Auto-preview"
		auto.button_pressed = _auto
		auto.toggled.connect(func(value: bool) -> void: _auto = value)
		actions.add_child(auto)
		var audio := MusicCatalog.stream_from(current.audio)
		_card = WaveCard.new()
		_card.setup(0, current.audio, audio, false)
		_card.play_requested.connect(func(_index: int) -> void: play_current())
		_form.add_child(_card)
		if audio != null:
			var seek := HSlider.new()
			seek.max_value = audio.get_length()
			seek.step = 0.01
			seek.tooltip_text = "Seek in seconds; useful for auditioning a full day/night cycle"
			seek.value_changed.connect(func(seconds: float) -> void:
				if not voice.playing:
					play_current()
				voice.seek(seconds))
			_form.add_child(seek)
	else:
		var contexts := HBoxContainer.new()
		_form.add_child(contexts)
		for role: String in current.data:
			if current.data[role] is String and not catalog.find(current.data[role]).is_empty() and catalog.find(current.data[role]).audio != "":
				_button(contexts, role.capitalize(), play_context.bind(role), "play")
		if contexts.get_child_count() > 0:
			_button(contexts, "Stop", stop, "stop")
	var keys: Array = current.data.keys()
	if current.audio != "":
		keys = MusicCatalog.DEFAULTS.keys()
		for key: String in current.data:
			if not key in keys:
				keys.append(key)
	for key: String in keys:
		_add_field(key, current.data.get(key, MusicCatalog.DEFAULTS.get(key)))
	_status = _label(current.error)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _add_field(key: String, value: Variant) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_form.add_child(row)
	var label := Label.new()
	label.text = key.replace("_", " ").capitalize()
	label.custom_minimum_size.x = 210
	label.tooltip_text = _hint(key)
	row.add_child(label)
	if key == "segments" and value is Array:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(box)
		for i in value.size():
			if not value[i] is Dictionary:
				continue
			var part := HBoxContainer.new()
			box.add_child(part)
			for bound in ["start_seconds", "end_seconds"]:
				var number := _number(float(value[i].get(bound, 0.0)), 0.0, 36000.0)
				number.tooltip_text = bound
				number.value_changed.connect(func(amount: float) -> void:
					var segments: Array = current.data.get("segments", []).duplicate(true)
					segments[i][bound] = amount
					_edit(key, segments))
				part.add_child(number)
			_button(part, "Remove", func() -> void:
				var segments: Array = current.data.get("segments", []).duplicate(true)
				segments.remove_at(i)
				_edit(key, segments)
				_show_current(), "trash")
		_button(box, "Add segment (start / end seconds)", func() -> void:
			var segments: Array = current.data.get("segments", []).duplicate(true)
			segments.append({"start_seconds": 0.0, "end_seconds": 10.0})
			_edit(key, segments)
			_show_current(), "plus")
	elif value is bool:
		var toggle := CheckButton.new()
		toggle.button_pressed = value
		toggle.toggled.connect(func(on: bool) -> void: _edit(key, on))
		row.add_child(toggle)
	elif value is int or value is float:
		var number := _number(float(value), -10000.0, 36000.0)
		number.value_changed.connect(func(amount: float) -> void: _edit(key, amount))
		row.add_child(number)
	elif key == "playback_mode":
		var choice := OptionButton.new()
		for mode in MusicCatalog.MODES:
			choice.add_item(mode)
		choice.select(MusicCatalog.MODES.find(value))
		choice.item_selected.connect(func(index: int) -> void: _edit(key, MusicCatalog.MODES[index]))
		row.add_child(choice)
	elif value is Dictionary or value is Array:
		var text := TextEdit.new()
		text.text = JSON.stringify(value, "\t", false)
		text.custom_minimum_size = Vector2(200, 110)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.text_changed.connect(func() -> void:
			var parsed = JSON.parse_string(text.text)
			if parsed is Dictionary or parsed is Array:
				_edit(key, parsed))
		row.add_child(text)
	else:
		var text := LineEdit.new()
		text.text = str(value)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.text_changed.connect(func(content: String) -> void: _edit(key, content))
		row.add_child(text)
	var reset := Button.new()
	reset.icon = Icons.get_icon("revert")
	reset.tooltip_text = "Reset this setting to its default (remove the JSON key)"
	reset.pressed.connect(func() -> void:
		current.data.erase(key)
		_rebuild_list()
		_show_current())
	row.add_child(reset)

func _edit(key: String, value: Variant) -> void:
	current.data[key] = value
	_rebuild_list()
	if _auto and current.audio != "":
		_timer.start()

func revert_current() -> void:
	if current.is_empty():
		return
	stop()
	var fresh := MusicCatalog.new()
	fresh.open(catalog.root)
	var replacement := fresh.find(current.path)
	catalog.entries.erase(current)
	if not replacement.is_empty():
		catalog.entries.append(replacement)
	current = replacement
	catalog.entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.path < b.path)
	_signature = fresh.signature()
	_show_current()
	_rebuild_list()

func discard_all() -> void:
	if catalog.root == "":
		return
	var selected := str(current.get("path", ""))
	stop()
	catalog.open(catalog.root)
	_signature = catalog.signature()
	current = catalog.find(selected)
	_show_current()
	_rebuild_list()

func play_current() -> void:
	if current.is_empty() or current.audio == "":
		return
	_timer.stop()
	var preview: Dictionary = current.duplicate(true)
	preview.error = MusicCatalog.problems(preview.data)
	if not voice.configure(preview):
		_status.text = "Cannot preview: invalid settings, unreadable audio or segment outside the track"
		return
	voice.start(true)
	voice.target = 1.0
	if _card != null:
		_card.stream = voice.stream
		_card.show_play(voice, voice.pitch_scale)
	_status.text = "Previewing saved or unsaved settings"

func stop() -> void:
	if _timer != null:
		_timer.stop()
	if voice != null:
		voice.stop()
		voice.target = 0.0
		voice.weight = 0.0
	for context: MusicVoice in _context_voices.values():
		context.stop()
		context.queue_free()
	_context_voices.clear()

## Any configuration mapping names to track paths gets transition buttons.
## The editor knows neither the game's phases nor an artist's file names.
func play_context(role: String) -> void:
	var entry := catalog.find(str(current.data.get(role, "")))
	if entry.is_empty():
		return
	if not _context_voices.has(role):
		var context := MusicVoice.new()
		context.volume_linear = 0.0
		add_child(context)
		_context_voices[role] = context
	var selected: MusicVoice = _context_voices[role]
	if not selected.configure(entry):
		_status.text = "Cannot preview this binding: check the track settings and audio file"
		return
	for key: String in _context_voices:
		var context: MusicVoice = _context_voices[key]
		context.keep_clock = str(context.setting("playback_mode")) == "continuous"
		context.target = 1.0 if key == role else (db_to_linear(float(context.setting("duck_db"))) if context.keep_clock else 0.0)
	selected.start(true)
	_status.text = "Previewing transition to " + role

func _process(dt: float) -> void:
	if voice != null:
		voice.advance(dt)
	for context: MusicVoice in _context_voices.values():
		context.advance(dt)

func add_files(paths: PackedStringArray) -> void:
	if catalog.root == "":
		return
	DirAccess.make_dir_recursive_absolute(catalog.root)
	for source in paths:
		if not source.get_extension().to_lower() in ["ogg", "wav"]:
			continue
		var target := catalog.root.path_join(source.get_file().get_basename() + ".ogg")
		if _replace and not current.is_empty() and current.audio != "":
			target = current.audio
		elif FileAccess.file_exists(target):
			_status.text = "Already exists: select the track and use Replace audio"
			continue
		var problem := import_audio(source, target)
		if problem != "":
			_status.text = problem
			continue
		stop()
		check_disk()
		select(target.trim_prefix(catalog.root + "/"))
	_replace = false

static func import_audio(source: String, target: String) -> String:
	if source.replace("\\", "/") == target.replace("\\", "/"):
		return "This is already the selected file"
	if target.get_extension().to_lower() != "ogg":
		return "Replace WAV tracks with another WAV in your audio editor, or import a new OGG track"
	var temporary := target + ".pending.ogg"
	var problem := ""
	if source.get_extension().to_lower() == "wav":
		problem = Oggenc.to_ogg(source, temporary)
	else:
		var error := DirAccess.copy_absolute(source, temporary)
		if error != OK:
			problem = error_string(error)
	if problem == "" and MusicCatalog.stream_from(temporary) == null:
		problem = "Unreadable audio file"
	if problem == "":
		var error := DirAccess.copy_absolute(temporary, target)
		if error != OK:
			problem = error_string(error)
	if FileAccess.file_exists(temporary):
		DirAccess.remove_absolute(temporary)
	return problem

func _number(value: float, low: float, high: float) -> SpinBox:
	var field := SpinBox.new()
	field.min_value = low
	field.max_value = high
	field.step = 0.01
	field.value = value
	field.custom_minimum_size.x = 150
	return field

func _label(text: String, font_size := 15) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	_form.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable, icon: String) -> void:
	var button := Button.new()
	button.text = text
	button.icon = Icons.get_icon(icon)
	button.pressed.connect(action)
	parent.add_child(button)

func _hint(key: String) -> String:
	return {
		"volume_db": "Track level in decibels (0 = as recorded)",
		"fade_seconds": "Full fade in/out duration in seconds",
		"loop": "Repeat the full track or the chosen segment",
		"playback_mode": "continuous: keep position; restart: start over on entry; segments: pick a segment on entry",
		"duck_db": "Reduction in dB while another phase is active (0 = no reduction)",
		"frenzy_speed_per_level": "Playback speed increase per game frenzy level (0 preserves musical pitch)",
		"segments": "Regions in seconds; one is chosen on each entry, without immediate repeats",
	}.get(key, "Project setting stored as plain JSON; unknown keys are preserved")
