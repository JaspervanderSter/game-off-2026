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
	if not OS.has_feature("windows") or OS.has_feature("web"):
		check.call(game.alternate_audio == null, "non-Windows build has no alternate audio controller")
		game._input(event)
		game.free()
		return
	var alternate: Node = game.alternate_audio
	alternate.set_process(false)
	check.call(not alternate.active and alternate.catalog.entries.is_empty(), "Windows starts in default mode without loading alternate audio")
	game._input(event)
	check.call(alternate.dialog_visible(), "Ctrl+Shift+M opens the mode dialog")
	event.keycode = KEY_ESCAPE
	game._input(event)
	check.call(not alternate.dialog_visible(), "Escape closes the mode dialog")
	game.music.transition_to("prep")
	game.music.advance_fades(2.0)
	alternate.set_active(true)
	alternate.advance(2.0)
	game.music.advance_fades(2.0)
	var prep: MusicVoice = alternate.voices.prep
	var combat: MusicVoice = alternate.voices.battle
	check.call(alternate.active and prep.playing and not game.music.players.prep.playing, "alternate preparation replaces original music")
	check.call(prep.stream.get_length() > 100.0, "the manifest resolves the supplied loadout loop")
	check.call(game.map_screen.ambience.replaced and Sfx.overlay().ends_with("sfx_cobiora"), "alternate uses its baked map replacement and isolated SFX workspace")
	prep.seek(25.0)
	game.music.transition_to("battle")
	alternate.advance(2.0)
	check.call(prep.playing and prep.get_playback_position() >= 24.9 and combat.playing, "continuous preparation advances behind battle without restarting")
	check.call(is_equal_approx(prep.volume_linear, db_to_linear(float(prep.setting("volume_db")) + float(prep.setting("duck_db")))), "ducking is the exact configured reduction in dB")
	game.music.set_frenzy_level(5)
	check.call(is_equal_approx(combat.pitch_scale, 1.0), "Cobiora battle retains musical pitch unless configured otherwise")
	game.music.transition_to("prep")
	alternate.advance(2.0)
	check.call(prep.get_playback_position() >= 24.9 and not combat.playing, "return from battle restores preparation at its continuing position")
	game.show_map()
	game.map_screen.sky.elapsed = 123.0
	alternate.advance(2.0)
	var ambience: MusicVoice = alternate.voices.ambience
	check.call(is_equal_approx(ambience.stream.get_length(), 160.0), "baked ambience covers exactly one 160-second sky cycle")
	check.call(absf(ambience.get_playback_position() - 123.0) < 0.1, "baked ambience starts at the visible sky time")
	game.map_screen.hide()
	alternate.advance(2.0)
	check.call(not ambience.playing, "baked ambience stops while away from the map")
	game.map_screen.sky.elapsed = 63.0
	game.map_screen.show()
	alternate.advance(2.0)
	check.call(absf(ambience.get_playback_position() - 63.0) < 0.1, "return to the map resynchronizes the baked loop")
	alternate.set_active(false)
	alternate.advance(2.0)
	check.call(not game.map_screen.ambience.replaced and not ambience.playing and Sfx.overlay() == "", "return to default restores procedural ambience and default SFX")
	game.music.transition_to("battle")
	game.music.advance_fades(2.0)
	check.call(game.music.players.battle.playing and is_equal_approx(game.music.players.battle.pitch_scale, 1.25), "default battle music and frenzy behavior survive a mode switch")
	game.free()
	var fresh = load("res://main.tscn").instantiate()
	host.add_child(fresh)
	check.call(not fresh.alternate_audio.active, "the next launch starts in default mode again")
	fresh.free()
