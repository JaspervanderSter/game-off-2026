class_name SoundLibrary
extends RefCounted
## The sounds of a game folder: every `sfx/<category>/<name>.ogg` with its JSON
## settings file beside it, plus `music/music.json` and the music tracks
## (`music/*.ogg`). Reads and writes the JSON files in the game's format.
##
## Mirrors prototypes/prototype_02/scripts/audio/sfx.gd. Keep SOUND_DEFAULTS,
## MUSIC_DEFAULTS and the playback rules (SoundPlayer, MusicPreview) in sync
## with it; tests/run_tests.gd compares the defaults with the game's.

const SOUND_DEFAULTS := {
	"volume_db": -8.0,
	"volume_jitter_db": 0.0,
	"pitch": 1.0,
	"pitch_jitter": 0.08,
	"pitch_step": 0.0,
	"melody": [],
	"cooldown_ms": 40,
}
const MUSIC_DEFAULTS := {
	"volume_db": -16.0,
	"fade_seconds": 1.2,
	"frenzy_speed_per_level": 0.05,
}
## Keys a settings file may hold besides its values.
const INFO_KEYS := ["description", "variants"]
## Keys written as whole numbers.
const INT_KEYS := ["cooldown_ms", "melody"]
## Written key order: description, values (defaults order), other keys, variants.
const VALUE_ORDER := ["volume_db", "volume_jitter_db", "pitch", "pitch_jitter", "pitch_step", "cooldown_ms", "melody"]

## The game folder (holding sfx/ and music/), as an absolute path.
var root := ""
## Effects, sorted by category then name.
var sounds: Array[SoundEntry] = []
## music/music.json, or null when the folder has no music/.
var music: SoundEntry
## Music tracks by file name without extension, looping.
var music_tracks := {}
var _track_times := {}


## Scans `path`. Returns an error message, or "" on success.
func open(path: String) -> String:
	root = path.simplify_path()
	sounds.clear()
	music = null
	music_tracks.clear()
	_track_times.clear()
	var sfx_dir := root.path_join("sfx")
	var music_dir := root.path_join("music")
	if not DirAccess.dir_exists_absolute(sfx_dir) and not DirAccess.dir_exists_absolute(music_dir):
		return "No sfx/ or music/ folder in %s" % root
	if DirAccess.dir_exists_absolute(sfx_dir):
		_scan_sounds(sfx_dir, "")
		var categories := Array(DirAccess.get_directories_at(sfx_dir))
		categories.sort()
		for category: String in categories:
			_scan_sounds(sfx_dir.path_join(category), category)
	if DirAccess.dir_exists_absolute(music_dir):
		music = SoundEntry.new()
		music.name = "music"
		music.category = "music"
		music.is_music = true
		music.json_path = music_dir.path_join("music.json")
		music.load_settings()
		var files := Array(DirAccess.get_files_at(music_dir))
		files.sort()
		for file: String in files:
			if file.get_extension().to_lower() == "ogg":
				_load_track(music_dir.path_join(file))
	return ""


## Effects, then the music settings.
func all_entries() -> Array[SoundEntry]:
	var entries: Array[SoundEntry] = sounds.duplicate()
	if music != null:
		entries.append(music)
	return entries


func find(sound_name: String) -> SoundEntry:
	for entry in all_entries():
		if entry.name == sound_name:
			return entry
	return null


## Path relative to the game folder, for display.
func relative(path: String) -> String:
	return path.trim_prefix(root + "/")


## Reloads music tracks changed on disk; returns the names of those reloaded.
func reload_changed_tracks() -> Array[String]:
	var reloaded: Array[String] = []
	for path: String in _track_times:
		if FileAccess.file_exists(path) and FileAccess.get_modified_time(path) != _track_times[path]:
			_load_track(path)
			reloaded.append(path.get_file().get_basename())
	return reloaded


func _scan_sounds(dir: String, category: String) -> void:
	var names := {}
	for file in DirAccess.get_files_at(dir):
		var extension := file.get_extension().to_lower()
		if extension == "json" or extension == "ogg":
			names[file.get_basename()] = true
	var sorted := names.keys()
	sorted.sort()
	for sound_name: String in sorted:
		var entry := SoundEntry.new()
		entry.name = sound_name
		entry.category = category
		entry.json_path = dir.path_join(sound_name + ".json")
		var ogg := dir.path_join(sound_name + ".ogg")
		entry.ogg_path = ogg if FileAccess.file_exists(ogg) else ""
		entry.load_settings()
		entry.load_stream()
		sounds.append(entry)


func _load_track(path: String) -> void:
	_track_times[path] = FileAccess.get_modified_time(path)
	var stream := AudioStreamOggVorbis.load_from_file(path)
	if stream != null:
		stream.loop = true
		music_tracks[path.get_file().get_basename()] = stream


## Keys of a settings dictionary (or of its variants) that the game does not
## know. Same rules as Sfx.settings_problems in the game.
static func settings_problems(data: Dictionary, known: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for key: String in data:
		if not known.has(key) and not key in INFO_KEYS:
			problems.append("unknown key \"%s\"" % key)
	var variants = data.get("variants", {})
	if not variants is Dictionary:
		problems.append("\"variants\" must be an object")
		return problems
	for variant: String in variants:
		if not variants[variant] is Dictionary:
			problems.append("variant \"%s\" must be an object" % variant)
			continue
		for key: String in variants[variant]:
			if not known.has(key):
				problems.append("unknown key \"%s\" in variant \"%s\"" % [key, variant])
	return problems


## The JSON text of a settings dictionary, as the game's files are written:
## tab indentation, keys in a fixed order, number arrays on one line.
static func settings_text(data: Dictionary, defaults: Dictionary) -> String:
	return _value_text(ordered(data, defaults), "", "") + "\n"


## A copy of `data` with its keys in the written order.
static func ordered(data: Dictionary, defaults: Dictionary) -> Dictionary:
	var out := {}
	if data.has("description"):
		out["description"] = data["description"]
	for key: String in VALUE_ORDER + defaults.keys():
		if data.has(key) and not out.has(key):
			out[key] = data[key]
	for key in data:
		if not out.has(key) and key != "variants":
			out[key] = data[key]
	if data.has("variants"):
		var variants = data["variants"]
		if variants is Dictionary:
			var ordered_variants := {}
			for variant in variants:
				var values = variants[variant]
				ordered_variants[variant] = ordered(values, defaults) if values is Dictionary else values
			out["variants"] = ordered_variants
		else:
			out["variants"] = variants
	return out


## A number as written: whole numbers for INT_KEYS, otherwise at least one decimal.
static func number_text(value: float, whole: bool) -> String:
	if is_zero_approx(value):
		value = 0.0
	if value == roundf(value) and absf(value) < 1e15:
		return str(int(value)) if whole else "%.1f" % value
	return String.num(value, 6)


static func _value_text(value: Variant, key: String, indent: String) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			if value.is_empty():
				return "{}"
			var lines := PackedStringArray()
			for k in value:
				lines.append("%s\t%s: %s" % [indent, JSON.stringify(str(k)), _value_text(value[k], str(k), indent + "\t")])
			return "{\n%s\n%s}" % [",\n".join(lines), indent]
		TYPE_ARRAY:
			var items := PackedStringArray()
			var flat := true
			for item in value:
				if item is Dictionary or item is Array:
					flat = false
				items.append(_value_text(item, key, indent + "\t"))
			if flat:
				return "[%s]" % ", ".join(items)
			var lines := PackedStringArray()
			for item in items:
				lines.append(indent + "\t" + item)
			return "[\n%s\n%s]" % [",\n".join(lines), indent]
		TYPE_INT, TYPE_FLOAT:
			return number_text(float(value), key in INT_KEYS)
		_:
			return JSON.stringify(value)
