extends Node
## Sound effects, played by name. A sound is one or more OGG files with a JSON
## file beside them in its category folder: `res://sfx/<category>/<name>.ogg`,
## optionally `<name>_2.ogg`, `<name>_3.ogg`..., and `<name>.json`. Each play
## picks one of the files (see next_pick) and the JSON sets how it plays
## (volume, pitch, random variation, pitch steps, repeat delay, file picking).
## A looping sound (the bard song) plays on its own voice from set_loop(): it
## starts from the beginning, repeats until switched off, then fades out.
## `music/music.json` sets the music volume, fades and frenzy speed-up.
## Autoloaded as Sfx; result audio has its own voice so effects cannot steal it.
##
## Exported desktop builds also read the same files beside the executable
## (`sfx/<category>/<name>[_N].ogg|json`, `music/music.json`): the sound files
## of a sound there replace all its packed files, and a JSON file there applies
## over the packed values key by key, so a sound designer can re-voice and tune
## the game without re-exporting. Changed files reload when the game window
## regains focus.
##
## Runs from the Godot editor read res:// straight from the project folder, so
## there a JSON file saved under `sfx/` or `music/` (by hand or with the
## Tuning Fork tool) also reloads when the game window regains focus.

const DIR := "res://sfx/"
const MUSIC_SETTINGS := "res://music/music.json"
## Every effect the game plays, with the category folder that holds it.
const SOUNDS := {
	"click": "interface", "fail": "interface", "buy": "interface",
	"combine": "interface", "merge": "interface", "difficulty_unlock": "interface",
	"coin_gain": "coins", "coin_harvest": "coins", "coin_compensation": "coins", "coin_pop": "coins",
	"hit": "combat", "shoot": "combat", "death": "combat",
	"hop": "abilities", "fear": "abilities", "blizzard": "abilities", "bard_song": "abilities",
	"shift_bless": "shapeshift", "shift_hex": "shapeshift",
	"heart_break": "duel", "victory": "duel", "defeat": "duel",
}
## Duel results play on a dedicated voice that effects cannot interrupt.
const RESULT_SOUNDS := ["victory", "defeat"]
const VOICES := 10
## Values used when a sound's JSON file leaves a key out.
const SOUND_DEFAULTS := {
	"volume_db": -8.0,
	"volume_jitter_db": 0.0,
	"pitch": 1.0,
	"pitch_jitter": 0.08,
	"pitch_step": 0.0,
	"cooldown_ms": 40,
	"pick": "shuffle",
	"shuffle_refill_after": 0,
}
## Values of "pick": how each play chooses among a sound's files (next_pick).
const PICK_MODES := ["shuffle", "random"]
## Seconds a looping sound takes to fade out once switched off.
const LOOP_FADE := 0.25
const MUSIC_DEFAULTS := {
	"volume_db": -16.0,
	"fade_seconds": 1.2,
	"frenzy_speed_per_level": 0.05,
}
## Keys a settings file may hold besides its values.
const INFO_KEYS := ["description"]
## Command-line user argument (after `--`) that silences all game audio.
const NO_SOUND_ARG := "--no-sound"

## False when launched with --no-sound: nothing is loaded or played and
## the master bus is muted (music included).
var enabled := true
## Files of each sound by name, an array of streams in file order.
var _streams := {}
## Picking state of each sound by name (see next_pick).
var _picks := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}
var _result_player: AudioStreamPlayer
## Voice of each looping sound that is on or fading out, by name.
var _loops := {}
## Folder of the executable, whose sfx/ and music/ files replace packed ones;
## empty when not exported.
var _override_root := ""
## Modification time of each replacement settings file already loaded, by path.
var _override_times := {}
## Replacement sound files of each sound already loaded, as names and times.
var _override_sounds := {}
## Settings of each sound by name, merged packed + replacement.
var _settings := {}
var _music := {}
## True in runs from the editor, whose res:// is the project folder on disk.
var _watch_project := false
## Modification time of each project settings file already loaded, by path.
var _project_times := {}


func _ready() -> void:
	_result_player = AudioStreamPlayer.new()
	add_child(_result_player)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	if NO_SOUND_ARG in OS.get_cmdline_user_args():
		enabled = false
		AudioServer.set_bus_mute(0, true)
		return
	for sound_name in SOUNDS:
		_streams[sound_name] = packed_streams(sound_name)
		_settings[sound_name] = read_settings(DIR + sound_file(sound_name, ".json"), SOUND_DEFAULTS)
	_music = read_settings(MUSIC_SETTINGS, MUSIC_DEFAULTS)
	if OS.has_feature("template") and not OS.has_feature("web"):
		_override_root = OS.get_executable_path().get_base_dir()
	_watch_project = OS.has_feature("editor")
	if _watch_project:
		for path: String in project_settings_files():
			_project_times[path] = FileAccess.get_modified_time(path)
	load_overrides()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and enabled:
		load_overrides()


## Path of a sound's file relative to the sfx folder, e.g. "combat/hit.ogg".
static func sound_file(sound_name: String, extension: String) -> String:
	return "%s/%s%s" % [SOUNDS[sound_name], sound_name, extension]


## Position of `file` among the sound files of `sound_name`: 1 for
## "<name>.ogg", N for "<name>_N.ogg" (N from 2), 0 when it is not one of them.
static func file_number(file: String, sound_name: String) -> int:
	if file == sound_name + ".ogg":
		return 1
	var digits := file.trim_prefix(sound_name + "_").trim_suffix(".ogg")
	if file.begins_with(sound_name + "_") and file.ends_with(".ogg") and digits.is_valid_int() \
			and str(int(digits)) == digits and int(digits) >= 2:
		return int(digits)
	return 0


## File names of the sound files of `sound_name` in `dir`, in number order.
## Exported builds list packed sounds with an ".import" suffix.
static func sound_files_in(dir: String, sound_name: String) -> Array[String]:
	var numbered := {}
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			var plain := file.trim_suffix(".remap").trim_suffix(".import")
			var number := file_number(plain, sound_name)
			if number > 0:
				numbered[number] = plain
	var numbers := numbered.keys()
	numbers.sort()
	var files: Array[String] = []
	for number in numbers:
		files.append(numbered[number])
	return files


## The packed files of a sound, loaded.
static func packed_streams(sound_name: String) -> Array[AudioStream]:
	var dir: String = DIR + SOUNDS[sound_name]
	var streams: Array[AudioStream] = []
	for file in sound_files_in(dir, sound_name):
		var stream: AudioStream = load(dir.path_join(file))
		if stream != null:
			streams.append(stream)
	return streams


## Project settings files (res://) and the sound each one tunes ("" for music).
static func project_settings_files() -> Dictionary:
	var files := {MUSIC_SETTINGS: ""}
	for sound_name in SOUNDS:
		files[DIR + sound_file(sound_name, ".json")] = sound_name
	return files


## Editor runs: reloads each project settings file saved since its last load.
## A file that cannot be read keeps the previous values and is retried later.
func reload_project_settings() -> void:
	var files := project_settings_files()
	for path: String in files:
		var time := FileAccess.get_modified_time(path)
		if time == _project_times.get(path, -1):
			continue
		var sound_name: String = files[path]
		var data := read_settings(path, SOUND_DEFAULTS if sound_name != "" else MUSIC_DEFAULTS)
		if data.is_empty():
			push_warning("Could not reload settings %s" % path)
			continue
		_project_times[path] = time
		if sound_name == "":
			_music = data
		else:
			_settings[sound_name] = data


## Loads each replacement file that is new or changed since its last load.
## A file that cannot be read keeps the previous values and is retried later.
func load_overrides() -> void:
	if _watch_project:
		reload_project_settings()
	if _override_root == "":
		return
	for sound_name in SOUNDS:
		_load_override_sounds(sound_name)
		var path := _override_root.path_join("sfx").path_join(sound_file(sound_name, ".json"))
		if _is_new_override(path):
			var packed := read_settings(DIR + sound_file(sound_name, ".json"), SOUND_DEFAULTS)
			var merged = _apply_override(packed, path, SOUND_DEFAULTS)
			if merged != null:
				_settings[sound_name] = merged
	var music_path := _override_root.path_join("music").path_join(MUSIC_SETTINGS.get_file())
	if _is_new_override(music_path):
		var merged = _apply_override(read_settings(MUSIC_SETTINGS, MUSIC_DEFAULTS), music_path, MUSIC_DEFAULTS)
		if merged != null:
			_music = merged


## The sound files of a sound beside the executable replace all its packed
## files; once they are all gone, the packed files play again.
func _load_override_sounds(sound_name: String) -> void:
	var dir := _override_root.path_join("sfx").path_join(SOUNDS[sound_name])
	var files := sound_files_in(dir, sound_name)
	var signature := ""
	for file in files:
		signature += "%s@%d;" % [file, FileAccess.get_modified_time(dir.path_join(file))]
	if signature == _override_sounds.get(sound_name, ""):
		return
	if files.is_empty():
		_override_sounds.erase(sound_name)
		_streams[sound_name] = packed_streams(sound_name)
		return
	var streams: Array[AudioStream] = []
	for file in files:
		var stream := AudioStreamOggVorbis.load_from_file(dir.path_join(file))
		if stream == null:
			push_warning("Could not load replacement sound %s" % dir.path_join(file))
			return
		streams.append(stream)
	_override_sounds[sound_name] = signature
	_streams[sound_name] = streams


func _is_new_override(path: String) -> bool:
	return FileAccess.file_exists(path) and _override_times.get(path, -1) != FileAccess.get_modified_time(path)


## Packed settings with a replacement file's values on top, key by key;
## null when the replacement cannot be read.
func _apply_override(packed: Dictionary, path: String, known: Dictionary) -> Variant:
	var replacement := read_settings(path, known)
	if replacement.is_empty():
		push_warning("Could not read replacement settings %s" % path)
		return null
	_override_times[path] = FileAccess.get_modified_time(path)
	return packed.merged(replacement, true)


## A JSON settings file as a dictionary; empty if missing or unreadable.
## Unknown keys are reported, since they would be silently ignored.
static func read_settings(path: String, known: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_warning("%s is not a valid JSON object" % path)
		return {}
	for problem in settings_problems(data, known):
		push_warning("%s: %s" % [path, problem])
	return data


## Keys of a settings dictionary that the game does not know, and values it
## cannot use.
static func settings_problems(data: Dictionary, known: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for key: String in data:
		if not known.has(key) and not key in INFO_KEYS:
			problems.append("unknown key \"%s\"" % key)
	if data.has("pick") and known.has("pick") and not data["pick"] in PICK_MODES:
		problems.append("\"pick\" must be one of %s" % ", ".join(PICK_MODES))
	return problems


## A sound setting: from the sound's JSON file, then SOUND_DEFAULTS.
func sound_setting(sound: String, key: String) -> Variant:
	return _settings.get(sound, {}).get(key, SOUND_DEFAULTS[key])


func music_setting(key: String) -> Variant:
	return _music.get(key, MUSIC_DEFAULTS[key])


## Index of the next file to play among `count`, given the picking `state` of
## the sound (a dictionary kept between calls). "random" draws any file each
## time. "shuffle" deals the files in a random order, each once, then deals
## again; with `refill_after` above 0 it deals again after that many plays,
## before every file has played. A new deal never starts with the file just
## played.
static func next_pick(state: Dictionary, count: int, mode: String, refill_after: int) -> int:
	var index := 0
	if count > 1 and mode == "random":
		index = randi() % count
	elif count > 1:
		var bag: Array = state.get("bag", [])
		var dealt: int = state.get("dealt", 0)
		var limit := count if refill_after <= 0 else mini(refill_after, count)
		if bag.is_empty() or dealt >= limit or bag.any(func(i: int) -> bool: return i >= count):
			bag = range(count)
			bag.shuffle()
			dealt = 0
			if bag.back() == state.get("last", -1):
				bag.reverse()
		index = bag.pop_back()
		state["bag"] = bag
		state["dealt"] = dealt + 1
	state["last"] = index
	return index


## Index of the file of `sound` to play next, as its settings pick it.
func pick_file(sound: String) -> int:
	return next_pick(_picks.get_or_add(sound, {}), _streams.get(sound, []).size(),
		str(sound_setting(sound, "pick")), int(sound_setting(sound, "shuffle_refill_after")))


## Pitch for one play of `sound`, before random variation. `step` is the
## position in a series: it adds `pitch_step` per step.
func base_pitch(sound: String, step := 0) -> float:
	return float(sound_setting(sound, "pitch")) + float(sound_setting(sound, "pitch_step")) * step


## Switches the looping sound `sound` on or off. Switched on, one of its files
## starts from its beginning on its own voice (unless already playing) and
## repeats; switched off, it fades out over LOOP_FADE seconds. Volume and pitch
## come from its settings; random variation and the repeat delay do not apply.
func set_loop(sound: String, on: bool) -> void:
	if not enabled or _streams.get(sound, []).is_empty():
		return
	var p: AudioStreamPlayer = _loops.get(sound)
	if on:
		if p == null:
			p = AudioStreamPlayer.new()
			add_child(p)
			_loops[sound] = p
		if p.has_meta("fade"):
			p.get_meta("fade").kill()
			p.remove_meta("fade")
		p.volume_db = float(sound_setting(sound, "volume_db"))
		p.pitch_scale = maxf(0.01, base_pitch(sound))
		if not p.playing:
			var stream: AudioStream = _streams[sound][pick_file(sound)].duplicate()
			if stream is AudioStreamOggVorbis:
				stream.loop = true
			p.stream = stream
			p.play()
	elif p != null and p.playing and not p.has_meta("fade"):
		var fade := create_tween()
		fade.tween_property(p, "volume_linear", 0.0, LOOP_FADE)
		fade.tween_callback(p.stop)
		fade.tween_callback(p.remove_meta.bind("fade"))
		p.set_meta("fade", fade)


## True while the looping sound `sound` is switched on.
func is_looping(sound: String) -> bool:
	var p: AudioStreamPlayer = _loops.get(sound)
	return p != null and p.playing and not p.has_meta("fade")


## Plays one file of the sound `sound` as its settings describe.
## `step` is the position in a series, e.g. the index of a landing coin.
func play(sound: String, step := 0) -> void:
	if not enabled or _streams.get(sound, []).is_empty():
		return
	# Avoid machine-gun stacking of identical sounds in the same instant.
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -100000)) < int(sound_setting(sound, "cooldown_ms")):
		return
	_last_played[sound] = now
	var p := _result_player
	if not sound in RESULT_SOUNDS:
		p = _players[_next]
		_next = (_next + 1) % VOICES
	var pitch_jitter := float(sound_setting(sound, "pitch_jitter"))
	var volume_jitter := float(sound_setting(sound, "volume_jitter_db"))
	p.stream = _streams[sound][pick_file(sound)]
	p.volume_db = float(sound_setting(sound, "volume_db")) + randf_range(-volume_jitter, volume_jitter)
	p.pitch_scale = maxf(0.01, base_pitch(sound, step) + randf_range(-pitch_jitter, pitch_jitter))
	p.play()
