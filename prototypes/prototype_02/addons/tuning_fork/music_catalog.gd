class_name MusicCatalog
extends RefCounted
## Generic, disk-backed music folder. Mirrored in Tuning Fork; parity is tested.
## Every OGG/WAV has its own adjacent JSON; other JSON files are configurations.
const DEFAULTS := {
	"description": "",
	"volume_db": -16.0,
	"fade_seconds": 1.2,
	"loop": true,
	"playback_mode": "continuous",
	"duck_db": -40.0,
	"frenzy_speed_per_level": 0.0,
	"segments": [],
}
const MODES := ["continuous", "restart", "segments"]
var root := ""
var entries: Array[Dictionary] = []

func open(folder: String) -> void:
	root = folder.replace("\\", "/").simplify_path()
	entries.clear()
	_scan(root)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.path < b.path)

func _scan(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	var names: PackedStringArray = []
	for file in DirAccess.get_files_at(folder):
		var plain := file.trim_suffix(".remap").trim_suffix(".import")
		if not plain in names:
			names.append(plain)
	var sidecars := []
	for file in names:
		if file.get_extension().to_lower() in ["ogg", "wav"]:
			var audio := folder.path_join(file)
			var json := audio.get_basename() + ".json"
			sidecars.append(json.get_file())
			entries.append(_entry(audio.trim_prefix(root + "/"), audio, json))
	for file in names:
		if file.get_extension() == "json" and not file in sidecars:
			var json := folder.path_join(file)
			entries.append(_entry(json.trim_prefix(root + "/"), "", json))
	for child in DirAccess.get_directories_at(folder):
		if not child.begins_with("."):
			_scan(folder.path_join(child))

func _entry(path: String, audio: String, json: String) -> Dictionary:
	var entry := {"path": path, "audio": audio, "json": json, "data": {}, "error": ""}
	if FileAccess.file_exists(json):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(json))
		if parsed is Dictionary:
			entry.data = parsed
		else:
			entry.error = "Invalid JSON: " + json
	if audio != "" and entry.error == "":
		entry.error = problems(entry.data)
	entry["saved"] = JSON.stringify(entry.data, "\t", false) + "\n"
	return entry

func find(path: String) -> Dictionary:
	for entry in entries:
		if entry.path == path:
			return entry
	return {}

func resolve(path: String) -> String:
	# All manifest paths stay inside the opened folder.
	if path == "" or path.is_absolute_path() or path.contains(":") or ".." in path.split("/"):
		return ""
	return root.path_join(path)

static func problems(data: Dictionary) -> String:
	for key in ["volume_db", "fade_seconds", "duck_db", "frenzy_speed_per_level"]:
		if data.has(key) and not (data[key] is float or data[key] is int):
			return key + " must be a number"
		if data.has(key) and not is_finite(float(data[key])):
			return key + " must be finite"
	if float(data.get("fade_seconds", 1.2)) <= 0.0:
		return "fade_seconds must be positive"
	if data.has("loop") and not data.loop is bool:
		return "loop must be true or false"
	if not data.get("playback_mode", "continuous") in MODES:
		return "Unknown playback_mode"
	if not data.get("segments", []) is Array:
		return "segments must be an array"
	for segment in data.get("segments", []):
		if not segment is Dictionary:
			return "Each segment needs start_seconds and end_seconds"
		for key in ["start_seconds", "end_seconds"]:
			if not segment.get(key) is float and not segment.get(key) is int:
				return "Each segment needs numeric " + key
		if not is_finite(float(segment.start_seconds)) or not is_finite(float(segment.end_seconds)) \
				or float(segment.start_seconds) < 0 or float(segment.end_seconds) <= float(segment.start_seconds):
			return "A segment must end after its non-negative start"
	if data.get("playback_mode") == "segments" and data.get("segments", []).is_empty():
		return "Add a segment before choosing segments mode"
	return ""

static func save_entry(entry: Dictionary) -> Error:
	if entry.audio != "" and problems(entry.data) != "":
		return ERR_INVALID_DATA
	var file := FileAccess.open(entry.json, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var written := JSON.stringify(entry.data, "\t", false) + "\n"
	file.store_string(written)
	file.close()
	entry.saved = written
	entry.error = ""
	return OK

static func stream_from(path: String) -> AudioStream:
	if path.begins_with("res://"):
		var packed := load(path) as AudioStream
		return packed.duplicate() if packed != null else null
	if path.get_extension().to_lower() == "wav":
		return AudioStreamWAV.load_from_file(path)
	return AudioStreamOggVorbis.load_from_file(path)

func signature() -> String:
	var parts := PackedStringArray()
	for entry in entries:
		for path: String in [entry.json, entry.audio]:
			if path != "" and FileAccess.file_exists(path):
				parts.append(path + ":" + FileAccess.get_sha256(path))
	return "|".join(parts)
