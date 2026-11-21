extends Node
## Headless checks for Tuning Fork. Run from tools/tuning_fork:
##   godot --headless --path . res://tests/run_tests.tscn
## Reads the newest prototype's sounds; writes only to scratch folders in user://.

const GAME_RUNTIME := "addons/tuning_fork/sfx.gd"

var _checks := 0
var _failures := 0


func _ready() -> void:
	var game := _game_folder()
	_check(game != "", "a prototype with an sfx/ folder exists")
	if game != "":
		_test_round_trip(game)
		_test_rules_match_game(game)
		_test_borrowed_files(game)
		_test_waveform(game)
		_test_projects(game)
		preload("res://tests/music_tests.gd").run(self, game, _check)
	_test_number_text()
	_test_editing_and_saving()
	_test_sound_files()
	_test_events()
	_test_groups()
	print("%d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _game_folder() -> String:
	var prototypes := ProjectSettings.globalize_path("res://").path_join("../../prototypes").simplify_path()
	var found := ""
	var folders := Array(DirAccess.get_directories_at(prototypes))
	folders.sort()
	for folder: String in folders:
		if SoundLibrary.event_count(prototypes.path_join(folder)) >= 0:
			found = prototypes.path_join(folder)
	return found


## The project window: prototypes found beside the tool, newest first; the
## recent folders; event counts without loading.
func _test_projects(game: String) -> void:
	var found := ProjectPicker.detect()
	_check(not found.is_empty() and found[0] == game, "the newest prototype is found first beside the tool")
	_check(found.all(func(path: String) -> bool: return SoundLibrary.event_count(path) >= 0),
		"only folders holding sfx/ are found")
	var library := SoundLibrary.new()
	library.open(game)
	_check(SoundLibrary.event_count(game) == library.sounds.size(), "events are counted without loading them")
	_check(SoundLibrary.event_count(game.path_join("missing")) == -1, "a folder without sfx/ counts -1")
	var recent := ProjectPicker.remember(["C:/b", "C:/a"], "C:\\a\\")
	_check(recent == ["C:/a", "C:/b"], "an opened folder moves to the front of the recent ones, once")
	var many: Array = []
	for i in 20:
		many.append("C:/game_%d" % i)
	_check(ProjectPicker.remember(many, "C:/new").size() == ProjectPicker.MAX_RECENT, "the recent folders are capped")


## Every settings file of the game is written back byte for byte, unchanged.
func _test_round_trip(game: String) -> void:
	var library := SoundLibrary.new()
	_check(library.open(game) == "", "the game folder opens")
	_check(library.sounds.size() >= 29, "all events are listed (%d)" % library.sounds.size())
	for entry in library.sounds:
		_check(entry.has_json, "%s has a JSON file" % entry.path)
		_check(not library.streams_of(entry).is_empty() and not library.streams_of(entry).has(null),
			"%s has playable OGG files" % entry.path)
		_check(entry.problems.is_empty(), "%s has no settings problems" % entry.path)
		_check(library.groups.has(str(entry.setting("group"))), "%s plays in a known group" % entry.path)
		var on_disk := FileAccess.get_file_as_string(entry.json_path).replace("\r\n", "\n")
		_check(entry.text() == on_disk, "%s is written back unchanged" % entry.path)
		_check(not entry.is_dirty(), "%s starts saved" % entry.path)
	var groups_on_disk := FileAccess.get_file_as_string(library.groups_path()).replace("\r\n", "\n")
	_check(library.groups.has("ui") and library.groups_text() == groups_on_disk and not library.groups_dirty(),
		"groups.json is read and written back unchanged")
	var coin := library.find("coins/harvest/3")
	_check(coin != null and coin.folder == "coins/harvest" and coin.name == "3", "events are found by path in nested folders")


## The tool's defaults, file naming and file picking are the game runtime's.
func _test_rules_match_game(game: String) -> void:
	var path := game.path_join(GAME_RUNTIME)
	_check(FileAccess.file_exists(path), "the game's runtime addon exists")
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(path)
	_check(script.reload() == OK, "the game's runtime compiles")
	var constants := script.get_script_constant_map()
	_check(constants.get("SOUND_DEFAULTS") == SoundLibrary.SOUND_DEFAULTS, "SOUND_DEFAULTS match the game")
	_check(constants.get("GROUP_DEFAULTS") == SoundLibrary.GROUP_DEFAULTS, "GROUP_DEFAULTS match the game")
	_check(constants.get("GROUPS_FILE") == SoundLibrary.GROUPS_FILE, "the groups file matches the game")
	_check(constants.get("INFO_KEYS") == SoundLibrary.INFO_KEYS, "INFO_KEYS match the game")
	_check(constants.get("PICK_MODES") == SoundLibrary.PICK_MODES, "pick modes match the game")
	_check(constants.get("VOICES") == SoundPlayer.VOICES, "voice count matches the game")
	_check(is_equal_approx(constants.get("LOOP_FADE"), SoundPlayer.LOOP_FADE), "loop fade matches the game")
	var same_numbers := true
	for file in ["hit.ogg", "hit_2.ogg", "hit_10.ogg", "hit_1.ogg", "hit_02.ogg", "hitch.ogg", "hit.json", "hit_x.ogg"]:
		same_numbers = same_numbers and script.file_number(file, "hit") == SoundLibrary.file_number(file, "hit")
	_check(same_numbers, "file numbering matches the game")
	var same_picks := true
	for setup in [[4, "shuffle", 0], [5, "shuffle", 2], [3, "random", 0], [1, "shuffle", 0]]:
		var game_state := {}
		var tool_state := {}
		for i in 40:
			seed(1000 + i)
			var expected: int = script.next_pick(game_state, setup[0], setup[1], setup[2])
			seed(1000 + i)
			same_picks = same_picks and SoundPlayer.next_pick(tool_state, setup[0], setup[1], setup[2]) == expected
	randomize()
	_check(same_picks, "file picking matches the game")


func _test_borrowed_files(game: String) -> void:
	var library := SoundLibrary.new()
	library.open(game)
	var first := library.find("coins/harvest/1")
	var third := library.find("coins/harvest/3")
	_check(library.borrowed_from(third) == first and library.streams_of(third) == first.streams
		and third.files.is_empty(), "an event with files_from plays the other event's files")
	_check(library.borrowers_of(first).size() == 7 and not library.file_sources(first).has(third),
		"the harvest coins 2 to 8 borrow from the first; borrowers are not file sources")
	_check(third.add_file(first.files[0]) != "", "an event that borrows files cannot get files of its own")


func _test_waveform(game: String) -> void:
	var stream := AudioStreamOggVorbis.load_from_file(game.path_join("default/sfx/combat/hit.ogg"))
	var peaks := WaveCard.peaks_of(stream, 60)
	var loudest := 0.0
	var ordered := true
	for i in 60:
		loudest = maxf(loudest, peaks[i * 2 + 1])
		ordered = ordered and peaks[i * 2] <= peaks[i * 2 + 1]
	_check(peaks.size() == 120 and ordered and loudest > 0.1, "a waveform has a low and a high peak per column")
	_check(WaveCard.peaks_of(stream, 60) == peaks, "waveforms are measured once")


func _test_number_text() -> void:
	_check(SoundLibrary.number_text(-8.0, false) == "-8.0", "whole floats keep one decimal")
	_check(SoundLibrary.number_text(40.0, true) == "40", "whole-number keys have no decimal")
	_check(SoundLibrary.number_text(0.08000000001, false) == "0.08", "float noise is trimmed")
	_check(SoundLibrary.number_text(-0.0, false) == "0.0", "negative zero is written as zero")
	_check(SoundLibrary.number_text(0.075, false) == "0.075", "three decimals are kept")


## Edits and a save in a scratch copy, then a reload.
func _test_editing_and_saving() -> void:
	var dir := _scratch("test_library")
	DirAccess.make_dir_recursive_absolute(dir.path_join("sfx/combat"))
	_write(dir.path_join("sfx/combat/hit.json"), '{"pitch": 1.0, "description": "Hit.", "extra": true}')
	DirAccess.copy_absolute(_game_folder().path_join("default/sfx/combat/hit.ogg"), dir.path_join("sfx/combat/swing.ogg"))
	var library := SoundLibrary.new()
	_check(library.open(dir) == "", "a scratch folder opens")
	var hit := library.find("combat/hit")
	_check(Array(hit.problems) == ["unknown key \"extra\""], "unknown keys are reported")
	_check(not hit.is_dirty(), "a hand-written file is not unsaved")
	hit.data["volume_db"] = -3.5
	hit.data["pick"] = "random"
	hit.data["loop"] = true
	_check(hit.is_dirty(), "an edit is unsaved")
	_check(hit.save() == OK and not hit.is_dirty(), "saving clears unsaved")
	var expected := "{\n\t\"description\": \"Hit.\",\n\t\"loop\": true,\n\t\"volume_db\": -3.5,\n\t\"pitch\": 1.0,\n\t\"pick\": \"random\",\n\t\"extra\": true\n}\n"
	_check(FileAccess.get_file_as_string(hit.json_path) == expected, "saved file has the game's layout")
	var swing := library.find("combat/swing")
	_check(swing != null and not swing.has_json and not swing.is_dirty(), "an event without JSON is listed with defaults")
	_check(swing.save() == OK and FileAccess.file_exists(swing.json_path), "saving creates its JSON file")
	_check(not FileAccess.get_file_as_string(swing.json_path).contains("files_from"), "a new file plays its own files")
	_check(library.groups_dirty(), "a folder without groups.json offers the starting groups to save")
	var reloaded := SoundLibrary.new()
	reloaded.open(dir)
	_check(reloaded.find("combat/hit").setting("pick") == "random", "the saved values reload")
	_check(reloaded.find("combat/swing").setting("cooldown_ms") == 40.0, "the created file holds the defaults")
	_remove_tree(dir)


## Numbered files group under their event; files are added (OGG copied, WAV
## converted when oggenc is there) and removed with renumbering.
func _test_sound_files() -> void:
	var dir := _scratch("test_files")
	var combat := dir.path_join("sfx/combat")
	DirAccess.make_dir_recursive_absolute(combat)
	var game_combat := _game_folder().path_join("default/sfx/combat")
	DirAccess.copy_absolute(game_combat.path_join("hit.ogg"), combat.path_join("hit.ogg"))
	DirAccess.copy_absolute(game_combat.path_join("death.ogg"), combat.path_join("hit_2.ogg"))
	DirAccess.copy_absolute(game_combat.path_join("shoot.ogg"), combat.path_join("hit_3.ogg"))
	DirAccess.copy_absolute(game_combat.path_join("shoot.ogg"), combat.path_join("shoot.ogg"))
	var library := SoundLibrary.new()
	library.open(dir)
	var paths := library.sounds.map(func(e: SoundEntry) -> String: return e.path)
	_check(paths == ["combat/hit", "combat/shoot"], "numbered files belong to their event, not to new events %s" % [paths])
	var hit := library.find("combat/hit")
	_check(hit.files.size() == 3 and hit.files[1].get_file() == "hit_2.ogg", "an event lists its files in order")
	_check(hit.add_file(game_combat.path_join("hit.json")) != "", "only WAV and OGG files can be added")
	_check(hit.add_file(game_combat.path_join("death.ogg")) == "" and hit.files.size() == 4
		and hit.files[3].get_file() == "hit_4.ogg", "an OGG file is copied as the next numbered file")
	var wav := dir.path_join("beep.wav")
	_write_wav(wav)
	var encoder := Oggenc.program()
	if OS.has_feature("windows") and OS.has_feature("editor"):
		_check(encoder != "", "the Windows editor can find its WAV encoder")
	if encoder != "":
		_check(hit.add_file(wav) == "" and hit.files.size() == 5 and hit.streams[4] is AudioStreamOggVorbis,
			"a WAV file is converted to OGG with oggenc")
	else:
		print("oggenc not found: WAV conversion not checked")
	var before := hit.files.size()
	var second_length := hit.streams[2].get_length()
	_check(hit.remove_file(1, false) == "" and hit.files.size() == before - 1, "a file is removed")
	var renumbered := hit.list_files()
	var contiguous := true
	for i in renumbered.size():
		contiguous = contiguous and renumbered[i] == SoundLibrary.numbered_file("hit", i + 1)
	_check(contiguous and is_equal_approx(hit.streams[1].get_length(), second_length),
		"the files after it are renumbered in order %s" % [renumbered])
	_check(hit.remove_file(0, false) == "" and hit.list_files()[0] == "hit.ogg", "removing the first file renumbers the next to name.ogg")
	_check(not hit.files_changed_on_disk(), "the entry follows its own file changes")
	DirAccess.copy_absolute(game_combat.path_join("hit.ogg"), combat.path_join("hit_%d.ogg" % (hit.files.size() + 1)))
	_check(hit.files_changed_on_disk(), "a file added by another program is noticed")
	_remove_tree(dir)


## Events are created, renamed (files and files_from references follow) and
## deleted; paths are checked.
func _test_events() -> void:
	var dir := _scratch("test_events")
	DirAccess.make_dir_recursive_absolute(dir.path_join("sfx"))
	var library := SoundLibrary.new()
	library.open(dir)
	_check(library.path_problem("Combat/Hit") != "" and library.path_problem("combat/hit_2") != ""
		and library.path_problem("groups") != "" and library.path_problem("combat//hit") != ""
		and library.path_problem("enemies/boss/roar") == "", "event paths use lowercase folders and names, not ending in _N")
	_check(library.create_event("enemies/boss/roar", "The boss roars before it charges.") == "",
		"an event is created in new folders")
	var roar := library.find("enemies/boss/roar")
	_check(roar != null and FileAccess.file_exists(dir.path_join("sfx/enemies/boss/roar.json"))
		and roar.data.get("description") == "The boss roars before it charges." and not roar.is_dirty(),
		"a created event has its JSON file with its description")
	_check(library.create_event("enemies/boss/roar", "") != "", "an existing path cannot be created again")
	var source := _game_folder().path_join("default/sfx/combat/hit.ogg")
	roar.add_file(source)
	roar.add_file(source)
	library.create_event("enemies/boss/growl", "Quieter roar.")
	var growl := library.find("enemies/boss/growl")
	growl.data["files_from"] = "enemies/boss/roar"
	growl.save()
	roar.data["volume_db"] = -2.0
	_check(library.rename_event(roar, "bosses/dragon/roar") == "", "an event is renamed to another folder")
	_check(roar.path == "bosses/dragon/roar" and roar.list_files() == ["roar.ogg", "roar_2.ogg"]
		and FileAccess.file_exists(dir.path_join("sfx/bosses/dragon/roar.json"))
		and not FileAccess.file_exists(dir.path_join("sfx/enemies/boss/roar.json")),
		"its JSON and sound files move with it")
	_check(roar.is_dirty() and is_equal_approx(roar.setting("volume_db"), -2.0), "unsaved settings stay unsaved")
	_check(growl.setting("files_from") == "bosses/dragon/roar" and not growl.is_dirty()
		and FileAccess.get_file_as_string(growl.json_path).contains("bosses/dragon/roar"),
		"events taking its files follow the new path")
	_check(library.rename_event(growl, "growl") == "" and DirAccess.dir_exists_absolute(dir.path_join("sfx/bosses"))
		and not DirAccess.dir_exists_absolute(dir.path_join("sfx/enemies")), "folders left empty are removed")
	_check(library.delete_event(roar, false) != "", "an event whose files others play cannot be deleted")
	_check(library.delete_event(growl, false) == "" and library.delete_event(roar, false) == ""
		and library.sounds.is_empty() and not FileAccess.file_exists(dir.path_join("sfx/bosses/dragon/roar.ogg")),
		"deleting an event removes its JSON and sound files")
	_check(not library.structure_changed_on_disk(), "the library follows its own changes")
	_write(dir.path_join("sfx/new.json"), "{}")
	_check(library.structure_changed_on_disk(), "an event added by another program is noticed")
	_remove_tree(dir)


## Groups are added, renamed (their events follow), tuned and removed.
func _test_groups() -> void:
	var dir := _scratch("test_groups")
	DirAccess.make_dir_recursive_absolute(dir.path_join("sfx/ui"))
	_write(dir.path_join("sfx/groups.json"), '{\n\t"effects": {\n\t\t"volume_db": 0.0\n\t},\n\t"ui": {\n\t\t"volume_db": -3.0\n\t}\n}\n')
	_write(dir.path_join("sfx/ui/click.json"), '{\n\t"group": "ui"\n}\n')
	var library := SoundLibrary.new()
	library.open(dir)
	_check(not library.groups_dirty() and is_equal_approx(library.group_volume("ui"), -3.0), "groups.json is read")
	_check(library.add_group("Bad Name") != "" and library.add_group("ui") != "" and library.add_group("ambience") == "",
		"group names are checked")
	_check(library.rename_group("ui", "interface") == "" and library.find("ui/click").setting("group") == "interface"
		and not library.find("ui/click").is_dirty(), "renaming a group moves its events")
	_check(library.remove_group("interface") != "" and library.remove_group("ambience") == "",
		"only groups without events can be removed")
	library.groups["effects"]["volume_db"] = -1.5
	_check(library.groups_dirty() and library.save_groups() == OK and not library.groups_dirty(), "groups are saved")
	var reloaded := SoundLibrary.new()
	reloaded.open(dir)
	_check(reloaded.groups.keys() == ["effects", "interface"] and is_equal_approx(reloaded.group_volume("effects"), -1.5),
		"saved groups reload in order")
	_remove_tree(dir)


func _scratch(label: String) -> String:
	return ProjectSettings.globalize_path("user://%s_%d" % [label, OS.get_process_id()])


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## A short 16-bit mono beep.
func _write_wav(path: String) -> void:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(4410 * 2)
	for i in 4410:
		data.encode_s16(i * 2, int(sin(i * TAU * 440.0 / 22050.0) * 12000.0))
	wav.data = data
	wav.save_to_wav(path)


func _remove_tree(dir: String) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_remove_tree(dir.path_join(sub))
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + label)
