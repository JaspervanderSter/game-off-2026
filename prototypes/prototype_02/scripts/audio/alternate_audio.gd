extends Node
## Designer workspace: editable on Windows, packed and always active on Web.
signal mode_changed
static var save_path := "user://audio_mode.cfg"
var active := false
var phase := ""
var music: PhaseMusic
var map: Node2D
var catalog := MusicCatalog.new()
var voices := {}
var manifest := {}
var root := ""
var _map_was_visible := false
var _frenzy := 0
var _dialog: Control
var _map_input_was_enabled := false

func _ready() -> void:
	root = ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	if OS.has_feature("web"):
		root = "res://"
	for role in ["prep", "battle", "ambience"]:
		var voice := MusicVoice.new()
		voice.volume_linear = 0.0
		add_child(voice)
		voices[role] = voice
	if OS.has_feature("web"):
		return
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_dialog = _build_dialog()
	layer.add_child(_dialog)
	_dialog.hide()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and active and not root.is_empty():
		reload_workspace()

func reload_workspace() -> void:
	catalog.open(root.path_join("custom/music"))
	var config := catalog.find("workspace.json")
	if not config.is_empty() and config.error == "":
		manifest = config.data.duplicate(true)
	for role: String in voices:
		var entry := catalog.find(str(manifest.get(role, "")))
		if entry.is_empty():
			# Removing a binding/file restores the original source. A malformed
			# replacement, in contrast, keeps the last valid version below.
			voices[role].stop()
			voices[role].stream = null
			voices[role].loaded_signature = ""
		elif not voices[role].configure(entry):
			push_warning("Alternate audio: could not reload %s; keeping its last playable version" % role)
	map.ambience.replaced = active and voices.ambience.stream != null
	apply_sfx()
	set_frenzy_level(_frenzy)

func apply_sfx() -> void:
	var folder := str(manifest.get("sfx_directory", ""))
	if active and folder != "" and not folder.is_absolute_path() and not folder.contains(":") and not ".." in folder.split("/"):
		Sfx.set_overlay(root.path_join(folder))
		Sfx.reload()

func restore_mode() -> void:
	if OS.has_feature("web"):
		set_active(true)
		return
	var config := ConfigFile.new()
	var mode := "custom" if not OS.has_feature("editor") else "default"
	if config.load(save_path) == OK:
		var saved = config.get_value("audio", "mode", mode)
		if saved in ["default", "custom"]:
			mode = saved
	set_active(mode == "custom")

func set_active(value: bool, persist := false) -> void:
	# Web always plays the packed designer workspace and has no mode selector.
	if OS.has_feature("web"):
		value = true
		persist = false
	elif not OS.has_feature("windows"):
		return
	if persist:
		var config := ConfigFile.new()
		config.set_value("audio", "mode", "custom" if value else "default")
		var error := config.save(save_path)
		if error != OK:
			push_warning("Could not save audio mode (error %d)." % error)
	if active == value:
		return
	active = value
	map.ambience.replaced = false
	if active:
		reload_workspace()
		transition_to(music.current)
	else:
		Sfx.set_overlay("")
		music.transition_to(music.current)
		for voice: MusicVoice in voices.values():
			voice.target = 0.0
			voice.keep_clock = false
	_map_was_visible = false
	mode_changed.emit()

func handles_phase(id: String) -> bool:
	return active and voices.has(id) and voices[id].stream != null

func transition_to(id: String) -> void:
	var changed := phase != id
	phase = id
	if not active:
		return
	if id in voices:
		voices[id].start(changed)
	if id == "battle" and str(voices.prep.setting("playback_mode")) == "continuous":
		voices.prep.start()

func set_frenzy_level(level: int) -> void:
	_frenzy = level
	var voice: MusicVoice = voices.get("battle")
	if voice != null:
		voice.pitch_scale = maxf(0.01, 1.0 + level * float(voice.setting("frenzy_speed_per_level")))

func _process(dt: float) -> void:
	advance(dt)

func advance(dt: float) -> void:
	if active:
		var shown := map.is_visible_in_tree()
		var prep: MusicVoice = voices.prep
		prep.target = 1.0 if phase == "prep" else (db_to_linear(float(prep.setting("duck_db"))) if phase == "battle" else 0.0)
		prep.keep_clock = not shown and str(prep.setting("playback_mode")) == "continuous"
		voices.battle.target = 1.0 if phase == "battle" else 0.0
		var ambience: MusicVoice = voices.ambience
		ambience.target = 1.0 if map.ambience_heard() else 0.0
		# Waits for the map's second frame: its first repaints the whole map,
		# and seeking the ambience in that frame too stalled the Web build.
		if shown and _map_was_visible and ambience.stream != null:
			var duration: float = map.sky.cycle_seconds
			ambience.pitch_scale = ambience.stream.get_length() / maxf(duration, 0.01)
			var position: float = map.sky.elapsed / maxf(duration, 0.01) * ambience.stream.get_length()
			var drift := absf(ambience.get_playback_position() - position)
			# A silent ambience (the title) stays stopped: MusicVoice stops a
			# voice with no weight, and restarting it every frame seeks the
			# stream each time (a measured Web stall).
			if not ambience.playing:
				if ambience.target > 0.0 or ambience.weight > 0.0:
					ambience.start(false, position)
			elif minf(drift, absf(ambience.stream.get_length() - drift)) > 0.12:
				ambience.seek(position)
		_map_was_visible = shown
	for voice: MusicVoice in voices.values():
		voice.advance(dt)

func toggle_dialog() -> void:
	if _dialog.visible:
		close_dialog()
		return
	# The map handles pointer events in _input, before GUI buttons receive them.
	# Suspend it while this modal owns input, including an unfinished map swipe.
	_map_input_was_enabled = map.is_processing_input()
	map.set_process_input(false)
	map._clear_touch()
	_dialog.show()
	_dialog.modulate.a = 0.0
	create_tween().tween_property(_dialog, "modulate:a", 1.0, 0.15)

func dialog_visible() -> bool:
	return _dialog != null and _dialog.visible

func close_dialog() -> void:
	if not _dialog.visible:
		return
	_dialog.hide()
	map.set_process_input(_map_input_was_enabled)

func _build_dialog() -> Control:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.02, 0.06, 0.7)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("30233e")
	style.border_color = Color("ddba70")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	for choice in [false, true]:
		var button := Button.new()
		button.text = "Custom" if choice else "Default"
		button.tooltip_text = "Windows audio workspace" if choice else "Original game audio"
		button.custom_minimum_size = Vector2(160, 96)
		button.icon = _music_icon(choice)
		button.toggle_mode = true
		button.button_pressed = active == choice
		mode_changed.connect(func() -> void: button.set_pressed_no_signal(active == choice))
		button.pressed.connect(func() -> void:
			set_active(choice, true)
			close_dialog())
		row.add_child(button)
	return shade

func _music_icon(alternative: bool) -> Texture2D:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for x in 32:
		for y in 32:
			var note := (Vector2(x, y) - Vector2(9, 24)).length() < 5 or (x >= 12 and x <= 15 and y >= 5 and y <= 24)
			if alternative:
				note = note or (Vector2(x, y) - Vector2(23, 21)).length() < 5 or (x >= 26 and x <= 29 and y >= 3 and y <= 21) or (y >= 3 and y <= 7 and x >= 12 and x <= 29)
			else:
				note = note or (x >= 15 and x <= 24 and y >= 5 and y <= 9)
			if note:
				image.set_pixel(x, y, Color("ddba70"))
	return ImageTexture.create_from_image(image)
