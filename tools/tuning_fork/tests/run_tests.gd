extends Node
## Headless checks for Tuning Fork. Run from tools/tuning_fork:
##   godot --headless --path . res://tests/run_tests.tscn
## Reads the newest prototype's sounds; writes only to a scratch folder in user://.

const GAME_SFX_SCRIPT := "scripts/audio/sfx.gd"

var _checks := 0
var _failures := 0


func _ready() -> void:
	var game := _game_folder()
	_check(game != "", "a prototype with an sfx/ folder exists")
	if game != "":
		_test_round_trip(game)
		_test_defaults_match_game(game)
		_test_playback_rules(game)
	_test_number_text()
	_test_editing_and_saving()
	print("%d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _game_folder() -> String:
	var prototypes := ProjectSettings.globalize_path("res://").path_join("../../prototypes").simplify_path()
	var found := ""
	var folders := Array(DirAccess.get_directories_at(prototypes))
	folders.sort()
	for folder: String in folders:
		if DirAccess.dir_exists_absolute(prototypes.path_join(folder).path_join("sfx")):
			found = prototypes.path_join(folder)
	return found


## Every settings file of the game is written back byte for byte, unchanged.
func _test_round_trip(game: String) -> void:
	var library := SoundLibrary.new()
	_check(library.open(game) == "", "the game folder opens")
	_check(library.sounds.size() >= 20, "all effects are listed (%d)" % library.sounds.size())
	_check(library.music != null and library.music_tracks.size() >= 2, "music settings and tracks are listed")
	for entry in library.all_entries():
		_check(entry.has_json, "%s has a JSON file" % entry.name)
		_check(entry.is_music or entry.stream != null, "%s has a playable OGG" % entry.name)
		_check(entry.problems.is_empty(), "%s has no settings problems" % entry.name)
		var on_disk := FileAccess.get_file_as_string(entry.json_path).replace("\r\n", "\n")
		_check(entry.text() == on_disk, "%s is written back unchanged" % entry.name)
		_check(not entry.is_dirty(), "%s starts saved" % entry.name)
	var coin := library.find("coin_gain")
	_check(coin != null and coin.category == "coins", "coin_gain is in coins/")
	_check(coin != null and coin.variants().has("harvest"), "coin_gain has its harvest variant")


## The tool's defaults are the game's (Sfx.SOUND_DEFAULTS and MUSIC_DEFAULTS).
func _test_defaults_match_game(game: String) -> void:
	var path := game.path_join(GAME_SFX_SCRIPT)
	_check(FileAccess.file_exists(path), "the game's sfx.gd exists")
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(path)
	_check(script.reload() == OK, "the game's sfx.gd compiles")
	var constants := script.get_script_constant_map()
	_check(constants.get("SOUND_DEFAULTS") == SoundLibrary.SOUND_DEFAULTS, "SOUND_DEFAULTS match the game")
	_check(constants.get("MUSIC_DEFAULTS") == SoundLibrary.MUSIC_DEFAULTS, "MUSIC_DEFAULTS match the game")
	_check(constants.get("INFO_KEYS") == SoundLibrary.INFO_KEYS, "INFO_KEYS match the game")
	_check(constants.get("VOICES") == SoundPlayer.VOICES, "voice count matches the game")


func _test_playback_rules(game: String) -> void:
	var library := SoundLibrary.new()
	library.open(game)
	var song := library.find("bard_song")
	_check(song != null and is_equal_approx(SoundPlayer.base_pitch(song, "", 5), 1.0), "the bard song plays at one pitch")
	var coin := library.find("coin_gain")
	var step := float(coin.setting("pitch_step", "harvest"))
	_check(step > 0.0 and is_equal_approx(SoundPlayer.base_pitch(coin, "harvest", 2), 1.0 + 2.0 * step), "pitch_step rises per step in a variant")
	_check(is_equal_approx(SoundPlayer.base_pitch(coin, "", 2), 1.0), "the sound itself has no pitch step")
	_check(coin.setting("volume_db", "harvest") == coin.setting("volume_db"), "a variant falls back to the sound's values")


func _test_number_text() -> void:
	_check(SoundLibrary.number_text(-8.0, false) == "-8.0", "whole floats keep one decimal")
	_check(SoundLibrary.number_text(40.0, true) == "40", "whole-number keys have no decimal")
	_check(SoundLibrary.number_text(0.08000000001, false) == "0.08", "float noise is trimmed")
	_check(SoundLibrary.number_text(-0.0, false) == "0.0", "negative zero is written as zero")
	_check(SoundLibrary.number_text(0.075, false) == "0.075", "three decimals are kept")


## Edits, a new variant and a save in a scratch copy, then a reload.
func _test_editing_and_saving() -> void:
	var dir := ProjectSettings.globalize_path("user://test_library_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(dir.path_join("sfx/combat"))
	var json := FileAccess.open(dir.path_join("sfx/combat/hit.json"), FileAccess.WRITE)
	json.store_string('{"pitch": 1.0, "description": "Hit.", "extra": true}')
	json.close()
	DirAccess.copy_absolute(_game_folder().path_join("sfx/combat/hit.ogg"), dir.path_join("sfx/combat/swing.ogg"))
	var library := SoundLibrary.new()
	_check(library.open(dir) == "", "a scratch folder opens")
	var hit := library.find("hit")
	_check(Array(hit.problems) == ["unknown key \"extra\""], "unknown keys are reported")
	_check(not hit.is_dirty(), "a hand-written file is not unsaved")
	hit.data["volume_db"] = -3.5
	hit.data["variants"] = {"heavy": {"pitch": 0.8}}
	_check(hit.is_dirty(), "an edit is unsaved")
	_check(hit.save() == OK and not hit.is_dirty(), "saving clears unsaved")
	var expected := "{\n\t\"description\": \"Hit.\",\n\t\"volume_db\": -3.5,\n\t\"pitch\": 1.0,\n\t\"extra\": true,\n\t\"variants\": {\n\t\t\"heavy\": {\n\t\t\t\"pitch\": 0.8\n\t\t}\n\t}\n}\n"
	_check(FileAccess.get_file_as_string(hit.json_path) == expected, "saved file has the game's layout")
	var swing := library.find("swing")
	_check(swing != null and not swing.has_json and not swing.is_dirty(), "a sound without JSON is listed with defaults")
	_check(swing.save() == OK and FileAccess.file_exists(swing.json_path), "saving creates its JSON file")
	var reloaded := SoundLibrary.new()
	reloaded.open(dir)
	_check(is_equal_approx(float(reloaded.find("hit").setting("pitch", "heavy")), 0.8), "the saved variant reloads")
	_check(reloaded.find("swing").setting("cooldown_ms") == 40.0, "the created file holds the defaults")
	for path in [hit.json_path, swing.json_path, dir.path_join("sfx/combat/swing.ogg")]:
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir.path_join("sfx/combat"))
	DirAccess.remove_absolute(dir.path_join("sfx"))
	DirAccess.remove_absolute(dir)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + label)
