extends RefCounted

static func run(host: Node, game: String, check: Callable) -> void:
	for script in ["music_catalog.gd", "music_voice.gd"]:
		check.call(FileAccess.get_file_as_string("res://scripts/" + script) == FileAccess.get_file_as_string(game.path_join("addons/tuning_fork/" + script)), "music preview and runtime share identical " + script)
	var workspaces := SoundLibrary.workspace_folders(game, "music")
	check.call(workspaces.has("default/music") and workspaces.has("custom/music"), "both music workspaces are discovered from the game root")
	var workspace_panel := MusicPanel.new()
	host.add_child(workspace_panel)
	workspace_panel.open(game)
	check.call(workspace_panel.catalog.root == game.path_join("default/music"), "the music editor starts in the default workspace")
	workspace_panel._workspace.item_selected.emit(workspaces.find("custom/music"))
	check.call(not workspace_panel.catalog.find("loadout_loop.ogg").is_empty() and not workspace_panel.catalog.find("workspace.json").is_empty(), "switching to custom discovers its music and bindings")
	workspace_panel.free()
	var sfx := SoundLibrary.new()
	sfx.open(game)
	var default_path := sfx.sfx_dir()
	sfx.folder_name = "custom/sfx"
	check.call(sfx.open(game) == "" and sfx.find("combat/hit") != null and sfx.sfx_dir() != default_path, "custom SFX open independently of default SFX")
	var scratch := ProjectSettings.globalize_path("user://music_test_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(scratch.path_join("music/nested"))
	var source := game.path_join("custom/music/loadout_loop.ogg")
	var audio := scratch.path_join("music/nested/unexpected_name.ogg")
	check.call(DirAccess.copy_absolute(source, audio) == OK, "scratch music file copied")
	var catalog := MusicCatalog.new()
	catalog.open(scratch.path_join("music"))
	var entry := catalog.find("nested/unexpected_name.ogg")
	check.call(not entry.is_empty() and catalog.entries.size() == 1, "arbitrary nested music is discovered without a hardcoded list or JSON")
	entry.data = {"volume_db": -12.5, "extension_key": {"kept": true}}
	check.call(MusicCatalog.save_entry(entry) == OK, "adjacent music JSON is created on save")
	catalog.open(catalog.root)
	entry = catalog.find(entry.path)
	check.call(entry.data.volume_db == -12.5 and entry.data.extension_key.kept, "music values and unknown nested keys survive reload")
	check.call(catalog.resolve("../../outside.ogg") == "" and catalog.resolve("C:/outside.ogg") == "" and catalog.resolve("nested/unexpected_name.ogg") == audio, "bindings reject paths escaping the music folder")
	var voice := MusicVoice.new()
	host.add_child(voice)
	check.call(voice.configure(entry), "disk music can be configured for playback")
	voice.start()
	voice.seek(22.0)
	voice.start(true)
	check.call(voice.get_playback_position() >= 21.9, "continuous music preserves playback position on reentry")
	entry.data.playback_mode = "restart"
	check.call(voice.configure(entry), "restart playback mode loads")
	voice.seek(22.0)
	voice.start(true)
	check.call(voice.get_playback_position() < 0.1, "restart music begins at zero on reentry")
	entry.data.playback_mode = "segments"
	entry.data.segments = [{"start_seconds": 5.0, "end_seconds": 8.0}, {"start_seconds": 20.0, "end_seconds": 24.0}]
	check.call(voice.configure(entry), "valid music regions can be selected")
	voice.start(true)
	var previous := voice.last_segment
	voice.start(true)
	check.call(previous != voice.last_segment, "segment picking avoids immediate repeats")
	voice.target = 1.0
	voice.seek(voice.segment.y + 0.1)
	voice.advance(1.2)
	check.call(absf(voice.get_playback_position() - voice.segment.x) < 0.1, "looping a segment wraps at its end")
	var original_stream := voice.stream
	entry.data.segments = [{"start_seconds": 2.0, "end_seconds": 100000.0}]
	check.call(not voice.configure(entry) and voice.stream == original_stream, "out-of-track segments keep the last playable stream")
	check.call(MusicCatalog.problems({"fade_seconds": 0}) != "" and MusicCatalog.problems({"volume_db": "loud"}) != "" and MusicCatalog.problems({"playback_mode": "unknown"}) != "", "invalid track settings are rejected")
	voice.stop()
	voice.free()
	var panel := MusicPanel.new()
	host.add_child(panel)
	panel.open(scratch)
	panel.select("nested/unexpected_name.ogg")
	panel.current.data.volume_db = -9.0
	check.call(panel.unsaved_paths().size() == 1 and panel.save_all(), "music editor detects and saves edited parameters")
	check.call(panel.unsaved_paths().is_empty(), "music save clears dirty state")
	var other := scratch.path_join("music/new_file.ogg")
	check.call(MusicPanel.import_audio(source, other) == "", "another audio file can be imported")
	panel.check_disk()
	check.call(not panel.catalog.find("new_file.ogg").is_empty(), "music editor discovers files added while open")
	panel.select("nested/unexpected_name.ogg")
	panel.current.data.volume_db = -11.0
	var changed := FileAccess.open(panel.current.json, FileAccess.WRITE)
	changed.store_string('{"volume_db": -22.0}')
	changed.close()
	panel.check_disk()
	check.call(panel.current.data.volume_db == -11.0 and panel.unsaved_paths().size() == 1, "external changes preserve unsaved music edits")
	panel.revert_current()
	check.call(panel.current.data.volume_db == -22.0 and panel.unsaved_paths().is_empty(), "Revert reads the conflicting file from disk")
	panel.current.data.volume_db = -19.0
	var config := FileAccess.open(scratch.path_join("music/session.json"), FileAccess.WRITE)
	config.store_string('{"arbitrary_phase": "new_file.ogg"}')
	config.close()
	panel.check_disk()
	check.call(panel._list.item_count == panel.catalog.entries.size(), "an empty music filter displays every discovered entry")
	panel._filter.text = "UNEXPECTED"
	panel._rebuild_list()
	check.call(panel._list.item_count == 1, "music filtering is case-insensitive")
	panel._filter.text = ""
	panel._rebuild_list()
	panel.select("session.json")
	panel.current.data["extra"] = "unsaved configuration"
	panel.revert_current()
	check.call(panel.unsaved_paths().size() == 1, "reverting one entry preserves edits to other tracks")
	panel.play_context("arbitrary_phase")
	panel._process(2.0)
	check.call(panel._context_voices.has("arbitrary_phase") and panel._context_voices.arbitrary_phase.playing, "generic configuration bindings preview arbitrary phase names")
	panel.stop()
	panel.discard_all()
	check.call(panel.unsaved_paths().is_empty(), "discard clears every pending music edit")
	panel.free()
	# Clean only this test's explicitly named scratch subtree.
	_remove(scratch)

static func _remove(folder: String) -> void:
	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))
	for name in DirAccess.get_directories_at(folder):
		_remove(folder.path_join(name))
	DirAccess.remove_absolute(folder)
