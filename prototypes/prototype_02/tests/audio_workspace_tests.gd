extends RefCounted
## Integration checks run by the ordinary suite, never the balance suite.
static func run(host: Node, check: Callable) -> void:
	var game = load("res://main.tscn").instantiate()
	host.add_child(game)
	game.set_process(false)
	game.music.set_process(false)
	check.call(game.music.current == "" and not game.music.players.prep.playing, "default startup still has no phase music")
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_M
	event.ctrl_pressed = true
	event.shift_pressed = true
	if OS.has_feature("web"):
		check.call(game.alternate_audio != null and game.alternate_audio.active, "Web always starts in designer audio")
		check.call(Sfx.overlay() == "res://custom/sfx", "Web uses packed designer SFX")
		check.call(Sfx.files_of("combat/hit").size() == 3, "Web includes all designer hit variants")
		check.call(not game.alternate_audio.dialog_visible(), "Web has no audio mode selector")
		game.free()
		return
	if not OS.has_feature("windows"):
		check.call(game.alternate_audio == null, "non-Windows build has no alternate audio controller")
		game._input(event)
		game.free()
		return
	var alternate: Node = game.alternate_audio
	# Web reads the same tracks through imported resource paths, not disk files.
	var packed_catalog := MusicCatalog.new()
	packed_catalog.open("res://custom/music")
	var packed_voice := MusicVoice.new()
	host.add_child(packed_voice)
	for role in ["loadout_loop.ogg", "battle_loop.ogg", "world_map_cycle.ogg"]:
		check.call(packed_voice.configure(packed_catalog.find(role)), "designer track loads through its packed resource path: " + role)
	packed_voice.free()
	alternate.set_process(false)
	check.call(alternate.active == not OS.has_feature("editor"), "only exported Windows starts in Custom without a saved preference")
	game._input(event)
	check.call(alternate.dialog_visible(), "Ctrl+Shift+M opens the mode dialog")
	check.call(not game.map_screen.is_processing_input(), "audio dialog suspends map pointer interception")
	# Send real pointer events through the viewport, rather than calling pressed.
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var buttons: Array[Node] = alternate._dialog.find_children("*", "Button", true, false)
	for index in [1, 0]:
		var button: Button = buttons[index]
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = button.get_global_rect().get_center()
		click.pressed = true
		host.get_viewport().push_input(click, true)
		click = click.duplicate()
		click.pressed = false
		host.get_viewport().push_input(click, true)
		check.call(alternate.active == (index == 1) and not alternate.dialog_visible(), "pointer selects %s and closes the dialog" % button.text)
		check.call(game.map_screen.is_processing_input(), "closing audio dialog restores map input")
		game._input(event)
		check.call(button.button_pressed, "reopening audio dialog shows selected %s mode" % button.text)
		var restarted = load("res://main.tscn").instantiate()
		host.add_child(restarted)
		check.call(restarted.alternate_audio.active == (index == 1), "restarting restores the selected %s mode" % button.text)
		restarted.free()
		# Each controller shares Sfx; reapply the live game's overlay after freeing it.
		if alternate.active:
			alternate.apply_sfx()
	event.keycode = KEY_ESCAPE
	game._input(event)
	check.call(not alternate.dialog_visible(), "Escape closes the mode dialog")
	check.call(game.map_screen.is_processing_input(), "Escape restores map input")
	game.music.transition_to("prep")
	game.music.advance_fades(2.0)
	alternate.set_active(true)
	alternate.advance(2.0)
	game.music.advance_fades(2.0)
	var prep: MusicVoice = alternate.voices.prep
	var combat: MusicVoice = alternate.voices.battle
	check.call(alternate.active and prep.playing and not game.music.players.prep.playing, "alternate preparation replaces original music")
	check.call(prep.stream.get_length() > 100.0, "the manifest resolves the supplied loadout loop")
	check.call(game.map_screen.ambience.replaced and Sfx.overlay().ends_with("custom/sfx"), "alternate uses its baked map replacement and isolated SFX workspace")
	prep.seek(25.0)
	game.music.transition_to("battle")
	alternate.advance(2.0)
	check.call(prep.playing and prep.get_playback_position() >= 24.9 and combat.playing, "continuous preparation advances behind battle without restarting")
	check.call(is_equal_approx(prep.volume_linear, db_to_linear(float(prep.setting("volume_db")) + float(prep.setting("duck_db")))), "ducking is the exact configured reduction in dB")
	game.music.set_frenzy_level(5)
	check.call(is_equal_approx(combat.pitch_scale, 1.0), "Custom battle retains musical pitch unless configured otherwise")
	game.music.transition_to("prep")
	alternate.advance(2.0)
	check.call(prep.get_playback_position() >= 24.9 and not combat.playing, "return from battle restores preparation at its continuing position")
	game.show_map()
	game.map_screen.sky.elapsed = 123.0
	alternate.advance(2.0)
	var ambience: MusicVoice = alternate.voices.ambience
	var cycle: float = game.map_screen.sky.cycle_seconds
	var recording: float = ambience.stream.get_length()
	check.call(is_equal_approx(ambience.pitch_scale, recording / cycle), "baked ambience of any length is fitted to one sky cycle")
	check.call(absf(ambience.get_playback_position() - 123.0 / cycle * recording) < 0.1, "baked ambience starts at the visible sky time")
	game.map_screen.hide()
	alternate.advance(2.0)
	check.call(not ambience.playing, "baked ambience stops while away from the map")
	game.map_screen.sky.elapsed = 63.0
	game.map_screen.show()
	alternate.advance(2.0)
	check.call(not ambience.playing, "baked ambience waits for the map's second frame (the first repaints the map)")
	alternate.advance(2.0)
	check.call(absf(ambience.get_playback_position() - 63.0 / cycle * recording) < 0.1, "return to the map resynchronizes the baked loop")
	alternate.set_active(false)
	alternate.advance(2.0)
	check.call(not game.map_screen.ambience.replaced and not ambience.playing and Sfx.overlay() == "", "return to default restores procedural ambience and default SFX")
	game.music.transition_to("battle")
	game.music.advance_fades(2.0)
	check.call(game.music.players.battle.playing and is_equal_approx(game.music.players.battle.pitch_scale, 1.25), "default battle music and frenzy behavior survive a mode switch")
	game.free()
	var fresh = load("res://main.tscn").instantiate()
	host.add_child(fresh)
	check.call(not fresh.alternate_audio.active, "saved Default overrides the Windows startup default")
	fresh.free()
	DirAccess.remove_absolute(preload("res://scripts/audio/alternate_audio.gd").save_path)
