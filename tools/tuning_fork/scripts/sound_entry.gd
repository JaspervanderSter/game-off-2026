class_name SoundEntry
extends RefCounted
## One sound of the library: its JSON settings and, for an effect, its OGG file.
## The music entry holds music/music.json; the library holds its tracks.

var name := ""
var category := ""
var is_music := false
var json_path := ""
## Empty when the effect has no OGG file (or for the music entry).
var ogg_path := ""
## Settings as read from the JSON file, edited in place.
var data := {}
## Settings text at the last load or save: data is unsaved when it differs.
var saved_text := ""
var has_json := false
var json_time := -1
var ogg_time := -1
var stream: AudioStream
## Warnings about the settings file (unknown keys, unreadable file).
var problems: Array[String] = []
## The JSON file changed on disk while this entry had unsaved changes.
var changed_on_disk := false


func defaults() -> Dictionary:
	return SoundLibrary.MUSIC_DEFAULTS if is_music else SoundLibrary.SOUND_DEFAULTS


## The settings as they would be written.
func text() -> String:
	return SoundLibrary.settings_text(data, defaults())


func is_dirty() -> bool:
	return text() != saved_text


## The variants dictionary itself (edits apply to the entry), empty if none.
func variants() -> Dictionary:
	var values = data.get("variants", {})
	return values if values is Dictionary else {}


## A setting: from the variant, then the sound, then the defaults (as the game).
func setting(key: String, variant := "") -> Variant:
	if variant != "":
		var values = variants().get(variant, {})
		if values is Dictionary and values.has(key):
			return values[key]
	return data.get(key, defaults()[key])


## (Re)reads the JSON file. A missing file gives the defaults, written on save.
func load_settings() -> void:
	changed_on_disk = false
	problems.clear()
	has_json = FileAccess.file_exists(json_path)
	data = {"description": ""}
	data.merge(defaults().duplicate(true))
	if has_json:
		json_time = FileAccess.get_modified_time(json_path)
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(json_path))
		if parsed is Dictionary:
			data = parsed
			problems = SoundLibrary.settings_problems(data, defaults())
		else:
			problems.append("%s is not a valid JSON object: saving replaces it" % json_path.get_file())
	else:
		json_time = -1
	saved_text = text()


func save() -> Error:
	var error := DirAccess.make_dir_recursive_absolute(json_path.get_base_dir())
	if error != OK:
		return error
	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var written := text()
	file.store_string(written)
	file.close()
	saved_text = written
	has_json = true
	json_time = FileAccess.get_modified_time(json_path)
	changed_on_disk = false
	problems = SoundLibrary.settings_problems(data, defaults())
	return OK


func load_stream() -> void:
	stream = null
	if ogg_path == "" or not FileAccess.file_exists(ogg_path):
		return
	ogg_time = FileAccess.get_modified_time(ogg_path)
	stream = AudioStreamOggVorbis.load_from_file(ogg_path)
	if stream == null:
		problems.append("%s cannot be read as OGG Vorbis" % ogg_path.get_file())


func json_changed_on_disk() -> bool:
	if FileAccess.file_exists(json_path):
		return FileAccess.get_modified_time(json_path) != json_time
	return has_json


func ogg_changed_on_disk() -> bool:
	return ogg_path != "" and FileAccess.file_exists(ogg_path) and FileAccess.get_modified_time(ogg_path) != ogg_time
