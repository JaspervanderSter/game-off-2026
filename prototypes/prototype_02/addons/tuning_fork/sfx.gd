extends Node
## Tuning Fork runtime: plays sound events by path. Autoloaded as `Sfx` by the
## Tuning Fork addon. The game only calls:
##
##   Sfx.play("combat/hit")            plays an event; a looping one keeps going
##   Sfx.stop("abilities/bard_song")   fades a looping event out
##   Sfx.set_group_volume("ui", -6.0)  the game's own volume change of a group
##
## An event is `res://sfx/<folders>/<name>.json` with its sound files beside it,
## `<name>.ogg` then `<name>_2.ogg`, `<name>_3.ogg`... Its path is
## "<folders>/<name>". The JSON settings say how it plays (SOUND_DEFAULTS);
## `res://sfx/groups.json` lists the mixing groups, each an audio bus.
## A missing event or file is silence and one warning, never an error.
##
## Exported desktop builds also read `sfx/` beside the executable: a sound file
## there replaces all the packed files of its event, a JSON file there applies
## over the packed values key by key, and an event that exists only there plays
## too. Runs from the Godot editor read the project's `sfx/` folder straight
## from disk. Either way, changed files reload when the game window regains
## focus. Definition: tools/tuning_fork/docs/ in the repository.

const DIR := "res://sfx/"
const GROUPS_FILE := "groups.json"
## Voices shared by the events that are neither looping nor protected; when
## all are busy, the oldest sound stops.
const VOICES := 10
## Values used when an event's JSON file leaves a key out.
const SOUND_DEFAULTS := {
	"group": "effects",
	"loop": false,
	"protected": false,
	"files_from": "",
	"volume_db": -8.0,
	"volume_jitter_db": 0.0,
	"pitch": 1.0,
	"pitch_jitter": 0.08,
	"cooldown_ms": 40,
	"pick": "shuffle",
	"shuffle_refill_after": 0,
}
## Values of a group in groups.json.
const GROUP_DEFAULTS := {
	"volume_db": 0.0,
}
## Values of "pick": how each play chooses among an event's files (next_pick).
const PICK_MODES := ["shuffle", "random"]
## Seconds a looping event takes to fade out once stopped.
const LOOP_FADE := 0.25
## Keys a settings file may hold besides its values.
const INFO_KEYS := ["description"]
## Command-line user argument (after `--`) that silences all game audio.
const NO_SOUND_ARG := "--no-sound"

## False when launched with --no-sound: nothing is loaded or played and the
## master bus is muted (music included).
var enabled := true
## Settings of each event by path, packed values with replacement values on top.
var _settings := {}
## Own sound files of each event by path, loaded, in file order.
var _streams := {}
## Groups by name: their settings from groups.json.
var _groups := {}
## The game's own volume change of each group, in decibels.
var _group_offsets := {}
## Picking state of each event by path (see next_pick).
var _picks := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}
## Own voice of each protected or looping event that has played, by path.
var _own_voices := {}
## Paths already warned about, so each warning shows once.
var _warned := {}
## Folders read, in order: the packed or project sfx/ folder, then the one
## beside the executable in exported builds.
var _roots: Array[String] = []
## Whether files of each root are read from disk (load_from_file) rather than
## loaded as imported resources.
var _from_disk: Array[bool] = []
## Folder laid over all the roots (set_overlay), as given and as read; "" when
## none.
var _overlay := ""
var _overlay_root := ""
var _overlay_from_disk := false
## Loaded sound files by absolute path: [modified time, stream].
var _file_cache := {}
## Paths and modification times of the watched folders at the last load.
var _signature := ""


func _ready() -> void:
	for i in VOICES:
		_players.append(_new_voice())
	if NO_SOUND_ARG in OS.get_cmdline_user_args():
		enabled = false
		AudioServer.set_bus_mute(0, true)
		return
	if OS.has_feature("editor"):
		_add_root(ProjectSettings.globalize_path(DIR), true)
	else:
		_add_root(DIR, false)
	if OS.has_feature("template") and not OS.has_feature("web"):
		_add_root(OS.get_executable_path().get_base_dir().path_join("sfx"), true)
	reload()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and enabled:
		reload()


## Plays the event at `path`. A looping event starts from the beginning of one
## of its files, unless already playing, and keeps going until stop().
func play(path: String) -> void:
	if not enabled or not _exists(path):
		return
	var streams := files_of(path)
	if streams.is_empty():
		_warn_once(path, "Sound event %s has no sound file" % path)
		return
	if bool(setting(path, "loop")):
		_start_loop(path, streams)
		return
	# Avoid machine-gun stacking of identical sounds in the same instant.
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(path, -100000)) < int(setting(path, "cooldown_ms")):
		return
	_last_played[path] = now
	var p: AudioStreamPlayer
	if bool(setting(path, "protected")):
		p = _own_voice(path)
	else:
		p = _players[_next]
		_next = (_next + 1) % VOICES
	var pitch_jitter := float(setting(path, "pitch_jitter"))
	var volume_jitter := float(setting(path, "volume_jitter_db"))
	p.stream = streams[pick_file(path)]
	p.bus = _bus_of(path)
	p.volume_db = float(setting(path, "volume_db")) + randf_range(-volume_jitter, volume_jitter)
	p.pitch_scale = maxf(0.01, float(setting(path, "pitch")) + randf_range(-pitch_jitter, pitch_jitter))
	p.play()


## Fades the looping event at `path` out over LOOP_FADE seconds.
func stop(path: String) -> void:
	var p: AudioStreamPlayer = _own_voices.get(path)
	if p == null or not p.playing or p.has_meta("fade"):
		return
	var fade := create_tween()
	fade.tween_property(p, "volume_linear", 0.0, LOOP_FADE)
	fade.tween_callback(p.stop)
	fade.tween_callback(p.remove_meta.bind("fade"))
	p.set_meta("fade", fade)


## The game's own volume change of `group`, in decibels, added to the volume
## the sound designer set in groups.json (an options menu, for example).
func set_group_volume(group: String, volume_db: float) -> void:
	_group_offsets[group] = volume_db
	_apply_groups()


## Lays the folder `root` (a res:// folder laid out like sfx/) over every other
## folder read, or removes it with "". Like the folder beside the executable,
## its sound files replace all the files of their event and its JSON files
## apply key by key. For hearing another set of sounds, such as an earlier
## one, against the current set in the running game. Applies at once.
func set_overlay(root: String) -> void:
	if root == _overlay:
		return
	_overlay = root
	_overlay_from_disk = root != "" and OS.has_feature("editor")
	_overlay_root = ProjectSettings.globalize_path(root) if _overlay_from_disk else root
	if enabled:
		reload(true)


## The folder set_overlay laid over the others, or "".
func overlay() -> String:
	return _overlay


## True while the looping event at `path` plays and is not fading out.
func is_looping(path: String) -> bool:
	var p: AudioStreamPlayer = _own_voices.get(path)
	return p != null and p.playing and not p.has_meta("fade")


## Every known event path, sorted.
func event_paths() -> Array:
	var paths := _settings.keys()
	paths.sort()
	return paths


## A setting of the event at `path`: its JSON files, then SOUND_DEFAULTS.
func setting(path: String, key: String) -> Variant:
	return _settings.get(path, {}).get(key, SOUND_DEFAULTS[key])


## The sound files an event plays: its own, or those of the event named by
## its `files_from` setting.
func files_of(path: String) -> Array:
	var source := str(setting(path, "files_from"))
	if source == "":
		return _streams.get(path, [])
	if not _settings.has(source):
		_warn_once(path, "Sound event %s takes its files from %s, which does not exist" % [path, source])
		return []
	return _streams.get(source, [])


## Index of the file of the event at `path` to play next, as its settings pick it.
func pick_file(path: String) -> int:
	return next_pick(_picks.get_or_add(path, {}), files_of(path).size(),
		str(setting(path, "pick")), int(setting(path, "shuffle_refill_after")))


## Index of the next file to play among `count`, given the picking `state` of
## the event (a dictionary kept between calls). "random" draws any file each
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


## Position of `file` among the sound files of the event named `event_name`:
## 1 for "<name>.ogg", N for "<name>_N.ogg" (N from 2), 0 otherwise.
static func file_number(file: String, event_name: String) -> int:
	if file == event_name + ".ogg":
		return 1
	var digits := file.trim_prefix(event_name + "_").trim_suffix(".ogg")
	if file.begins_with(event_name + "_") and file.ends_with(".ogg") and digits.is_valid_int() \
			and str(int(digits)) == digits and int(digits) >= 2:
		return int(digits)
	return 0


## File names of the sound files of `event_name` among `files`, in number
## order. Exported builds list packed sounds with an ".import" suffix.
static func numbered_files(files: PackedStringArray, event_name: String) -> Array[String]:
	var numbered := {}
	for file in files:
		var plain := file.trim_suffix(".remap").trim_suffix(".import")
		var number := file_number(plain, event_name)
		if number > 0:
			numbered[number] = plain
	var numbers := numbered.keys()
	numbers.sort()
	var result: Array[String] = []
	for number in numbers:
		result.append(numbered[number])
	return result


## A JSON settings file as a dictionary; empty if missing or unreadable.
## Unknown keys and unusable values are reported.
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


## Keys of a settings dictionary that are not known, and values that cannot be
## used.
static func settings_problems(data: Dictionary, known: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for key: String in data:
		if not known.has(key) and not key in INFO_KEYS:
			problems.append("unknown key \"%s\"" % key)
	if data.has("pick") and known.has("pick") and not data["pick"] in PICK_MODES:
		problems.append("\"pick\" must be one of %s" % ", ".join(PICK_MODES))
	return problems


## Reads every root again if any file in a watched root changed since the last
## load: settings, groups and the sound files that changed. A file that cannot
## be read keeps the previous values. `force` reads them even when unchanged.
func reload(force := false) -> void:
	var signature := _watched_signature()
	if signature == _signature and not _settings.is_empty() and not force:
		return
	_signature = signature
	var settings := {}
	var own_files := {}
	var groups := {}
	var roots := _roots.duplicate()
	var from_disk := _from_disk.duplicate()
	if _overlay != "":
		roots.append(_overlay_root)
		from_disk.append(_overlay_from_disk)
	for r in roots.size():
		var root: String = roots[r]
		var root_groups := _read_groups(root.path_join(GROUPS_FILE))
		for group_name: String in root_groups:
			groups[group_name] = groups.get(group_name, {}).merged(root_groups[group_name], true)
		var found := {}
		_scan(root, "", found)
		for path: String in found:
			var entry: Dictionary = found[path]
			if entry.has("json"):
				var data = _read_json(entry.json)
				if data == null:
					push_warning("Could not read %s; keeping its previous settings" % entry.json)
					settings[path] = _settings.get(path, {})
				else:
					for problem in settings_problems(data, SOUND_DEFAULTS):
						push_warning("%s: %s" % [entry.json, problem])
					settings[path] = settings.get(path, {}).merged(data, true)
			if not entry.files.is_empty():
				var streams := []
				for file: String in entry.files:
					var stream := _load_file(file, from_disk[r])
					if stream != null:
						streams.append(stream)
				own_files[path] = streams
	# An event exists when its JSON file exists in one of the roots.
	for path: String in own_files.keys():
		if not settings.has(path):
			own_files.erase(path)
	_settings = settings
	_streams = own_files
	_groups = groups
	_apply_groups()
	for path: String in _settings:
		var source := str(setting(path, "files_from"))
		if source != "" and _streams.has(path):
			push_warning("Sound event %s has its own files and files_from; files_from wins" % path)
		if source != "" and _settings.has(source) and str(setting(source, "files_from")) != "":
			push_warning("Sound event %s takes its files from %s, which takes its own from another event" % [path, source])


func _add_root(root: String, from_disk: bool) -> void:
	_roots.append(root)
	_from_disk.append(from_disk)


## A JSON object file as a dictionary, or null when it cannot be read.
static func _read_json(path: String) -> Variant:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else null


## Events under `dir` (relative folder `rel`) into `found`: path -> {"json":
## absolute JSON path (when there is one), "files": absolute sound file paths}.
## Sound files are listed even without a JSON beside them, so a replacement
## folder can hold only the sound files of an event packed in the game.
func _scan(dir: String, rel: String, found: Dictionary) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	var files := DirAccess.get_files_at(dir)
	var names := {}
	for file in files:
		var plain := file.trim_suffix(".remap").trim_suffix(".import")
		if plain.get_extension() == "json" and not (rel == "" and plain == GROUPS_FILE):
			names[plain.get_basename()] = true
		elif plain.get_extension() == "ogg":
			names[plain.get_basename()] = true
	for event_name: String in names:
		var path := event_name if rel == "" else rel.path_join(event_name)
		var entry := {"files": []}
		if FileAccess.file_exists(dir.path_join(event_name + ".json")):
			entry["json"] = dir.path_join(event_name + ".json")
		for file in numbered_files(files, event_name):
			entry.files.append(dir.path_join(file))
		found[path] = entry
	for sub in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(sub), sub if rel == "" else rel.path_join(sub), found)


func _read_groups(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data = _read_json(path)
	if data == null:
		push_warning("%s is not a valid JSON object" % path)
		return {}
	var groups := {}
	for group_name in data:
		if data[group_name] is Dictionary:
			for problem in settings_problems(data[group_name], GROUP_DEFAULTS):
				push_warning("%s, group %s: %s" % [path, group_name, problem])
			groups[group_name] = data[group_name]
	return groups


## One audio bus per group, named after it and sent to Master, at the group's
## volume plus the game's change.
func _apply_groups() -> void:
	for group_name: String in _groups:
		var bus := AudioServer.get_bus_index(group_name)
		if bus < 0:
			AudioServer.add_bus()
			bus = AudioServer.bus_count - 1
			AudioServer.set_bus_name(bus, group_name)
			AudioServer.set_bus_send(bus, "Master")
		AudioServer.set_bus_volume_db(bus, float(_groups[group_name].get("volume_db", GROUP_DEFAULTS.volume_db))
			+ float(_group_offsets.get(group_name, 0.0)))


func _bus_of(path: String) -> String:
	var group := str(setting(path, "group"))
	if _groups.has(group):
		return group
	_warn_once("group:" + group, "Sound group %s is not in %s" % [group, GROUPS_FILE])
	return "Master"


## Paths and modification times of every file in the folders read from disk.
func _watched_signature() -> String:
	var parts := PackedStringArray()
	for r in _roots.size():
		if _from_disk[r]:
			_list_times(_roots[r], parts)
	if _overlay_from_disk:
		_list_times(_overlay_root, parts)
	return ";".join(parts)


func _list_times(dir: String, parts: PackedStringArray) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() in ["json", "ogg"]:
			parts.append("%s@%d" % [dir.path_join(file), FileAccess.get_modified_time(dir.path_join(file))])
	for sub in DirAccess.get_directories_at(dir):
		_list_times(dir.path_join(sub), parts)


## A sound file, loaded once per modification; the file name is kept as the
## stream's "sfx_file" meta.
func _load_file(path: String, from_disk: bool) -> AudioStream:
	if not from_disk:
		var packed: AudioStream = load(path)
		if packed != null:
			packed.set_meta("sfx_file", path.trim_prefix(DIR))
		return packed
	var time := FileAccess.get_modified_time(path)
	var cached: Array = _file_cache.get(path, [])
	if not cached.is_empty() and cached[0] == time:
		return cached[1]
	var stream := AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		push_warning("Could not load sound file %s" % path)
		return null if cached.is_empty() else cached[1]
	stream.set_meta("sfx_file", path.get_file())
	_file_cache[path] = [time, stream]
	return stream


func _exists(path: String) -> bool:
	if _settings.has(path):
		return true
	_warn_once(path, "No sound event %s under %s" % [path, DIR])
	return false


func _warn_once(key: String, message: String) -> void:
	if not _warned.has(key):
		_warned[key] = true
		push_warning(message)


func _new_voice() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	add_child(p)
	return p


func _own_voice(path: String) -> AudioStreamPlayer:
	if not _own_voices.has(path):
		_own_voices[path] = _new_voice()
	return _own_voices[path]


## Starts a looping event on its own voice, or keeps it going and cancels a
## fade-out. Volume and pitch come from its settings; random variation and the
## repeat delay do not apply.
func _start_loop(path: String, streams: Array) -> void:
	var p := _own_voice(path)
	if p.has_meta("fade"):
		p.get_meta("fade").kill()
		p.remove_meta("fade")
	p.bus = _bus_of(path)
	p.volume_db = float(setting(path, "volume_db"))
	p.pitch_scale = maxf(0.01, float(setting(path, "pitch")))
	if not p.playing:
		var stream: AudioStream = streams[pick_file(path)].duplicate()
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		p.stream = stream
		p.play()
