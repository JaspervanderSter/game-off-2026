extends Node
## Windows-only experiment. Default playback never reads this workspace.
signal mode_changed
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

func _ready() -> void:
	root = ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	for role in ["prep", "battle", "ambience"]:
		var voice := MusicVoice.new()
		voice.volume_linear = 0.0
		add_child(voice)
		voices[role] = voice
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
	catalog.open(root.path_join("music"))
	var config := catalog.find("alternate.json")
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

func set_active(value: bool) -> void:
	# This guard also prevents a saved setting or caller enabling it in Web.
	if not OS.has_feature("windows") or OS.has_feature("web"):
		return
	if active == value:
		return
	active = value
	map.ambience.replaced = false
	if active:
		reload_workspace()
		transition_to(music.current)
	else:
		SoundSet.apply()
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
		ambience.target = 1.0 if shown else 0.0
		if shown and ambience.stream != null:
			var duration: float = map.sky.cycle_seconds
			ambience.pitch_scale = ambience.stream.get_length() / maxf(duration, 0.01)
			var position: float = map.sky.elapsed / maxf(duration, 0.01) * ambience.stream.get_length()
			var drift := absf(ambience.get_playback_position() - position)
			if not _map_was_visible or not ambience.playing:
				ambience.start(false, position)
			elif minf(drift, absf(ambience.stream.get_length() - drift)) > 0.12:
				ambience.seek(position)
		_map_was_visible = shown
	for voice: MusicVoice in voices.values():
		voice.advance(dt)

func toggle_dialog() -> void:
	_dialog.visible = not _dialog.visible
	if _dialog.visible:
		_dialog.modulate.a = 0.0
		create_tween().tween_property(_dialog, "modulate:a", 1.0, 0.15)

func dialog_visible() -> bool:
	return _dialog.visible

func close_dialog() -> void:
	_dialog.hide()

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
		button.text = "Cobiora" if choice else "Default"
		button.tooltip_text = "Windows audio workspace" if choice else "Original game audio"
		button.custom_minimum_size = Vector2(160, 96)
		button.icon = _music_icon(choice)
		button.toggle_mode = true
		button.button_pressed = active == choice
		mode_changed.connect(func() -> void: button.set_pressed_no_signal(active == choice))
		button.pressed.connect(func() -> void:
			set_active(choice)
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
