class_name SoundEntry
extends RefCounted
## One sound of the library: its JSON settings and, for an effect, its OGG
## files (`<name>.ogg`, `<name>_2.ogg`...). The music entry holds
## music/music.json; the library holds its tracks.
##
## Settings change in memory and are written by save(). File operations
## (add_file, remove_file) change the folder at once.

## Extensions add_file accepts; other than OGG, they are converted with oggenc.
const ADDABLE := ["ogg", "wav"]

var name := ""
var category := ""
var is_music := false
## Folder holding the sound's files.
var dir := ""
var json_path := ""
## Absolute paths of the sound's OGG files, in number order.
var files: Array[String] = []
## One stream per file (null where a file cannot be read).
var streams: Array[AudioStream] = []
## Settings as read from the JSON file, edited in place.
var data := {}
## Settings text at the last load or save: data is unsaved when it differs.
var saved_text := ""
var has_json := false
var json_time := -1
## Warnings about the settings file (unknown keys, unreadable file).
var problems: Array[String] = []
## Files that cannot be read as OGG Vorbis.
var file_problems: Array[String] = []
## The JSON file changed on disk while this entry had unsaved changes.
var changed_on_disk := false
var _files_signature := ""


func defaults() -> Dictionary:
	return SoundLibrary.MUSIC_DEFAULTS if is_music else SoundLibrary.SOUND_DEFAULTS


## The settings as they would be written.
func text() -> String:
	return SoundLibrary.settings_text(data, defaults())


func is_dirty() -> bool:
	return text() != saved_text


## A setting: from the sound's JSON, then the defaults (as the game).
func setting(key: String) -> Variant:
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


## File names of the sound's OGG files in its folder, in number order.
func list_files() -> Array[String]:
	var numbered := {}
	if not is_music and DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			var number := SoundLibrary.file_number(file, name)
			if number > 0:
				numbered[number] = file
	var numbers := numbered.keys()
	numbers.sort()
	var names: Array[String] = []
	for number in numbers:
		names.append(numbered[number])
	return names


## (Re)loads every OGG file of the sound.
func load_files() -> void:
	files.clear()
	streams.clear()
	file_problems.clear()
	for file in list_files():
		var path := dir.path_join(file)
		var stream := AudioStreamOggVorbis.load_from_file(path)
		if stream == null:
			file_problems.append("%s cannot be read as OGG Vorbis" % file)
		files.append(path)
		streams.append(stream)
	_files_signature = _signature()


## True when the sound's files were added, removed or changed on disk.
func files_changed_on_disk() -> bool:
	return _signature() != _files_signature


func json_changed_on_disk() -> bool:
	if FileAccess.file_exists(json_path):
		return FileAccess.get_modified_time(json_path) != json_time
	return has_json


## Copies (OGG) or converts (WAV, with oggenc) `source` into the sound's next
## numbered file. Returns an error message, or "" on success.
func add_file(source: String) -> String:
	var extension := source.get_extension().to_lower()
	if not extension in ADDABLE:
		return "%s: only %s files can be added" % [source.get_file(), " and ".join(ADDABLE).to_upper()]
	var numbers := list_files().map(func(f: String) -> int: return SoundLibrary.file_number(f, name))
	var next: int = 1 if numbers.is_empty() else numbers.max() + 1
	var target := dir.path_join(SoundLibrary.numbered_file(name, next))
	if extension == "ogg":
		if AudioStreamOggVorbis.load_from_file(source) == null:
			return "%s cannot be read as OGG Vorbis" % source.get_file()
		var error := DirAccess.copy_absolute(source, target)
		if error != OK:
			return "Could not copy %s (%s)" % [source.get_file(), error_string(error)]
	else:
		var problem := Oggenc.to_ogg(source, target)
		if problem != "":
			return problem
	load_files()
	return ""


## Removes the `index`-th file (to the recycle bin, or for good when `trash`
## is false) and renumbers the files after it, so they stay name.ogg, name_2.ogg...
## Godot import files of the moved files are removed too; the editor makes
## new ones. Returns an error message, or "" on success.
func remove_file(index: int, trash := true) -> String:
	var names := list_files()
	if index < 0 or index >= names.size():
		return "No such file"
	var error := _discard(dir.path_join(names[index]), trash)
	if error == OK:
		_discard(dir.path_join(names[index] + ".import"), trash)
	if error != OK:
		return "Could not remove %s (%s)" % [names[index], error_string(error)]
	names.remove_at(index)
	# Two passes through temporary names, so no rename lands on a file to move.
	var moves := {}
	for i in names.size():
		var target := SoundLibrary.numbered_file(name, i + 1)
		if names[i] != target:
			var temporary := dir.path_join(names[i] + ".renaming")
			error = DirAccess.rename_absolute(dir.path_join(names[i]), temporary)
			if error != OK:
				load_files()
				return "Could not rename %s (%s)" % [names[i], error_string(error)]
			_discard(dir.path_join(names[i] + ".import"), trash)
			moves[temporary] = dir.path_join(target)
	for temporary: String in moves:
		error = DirAccess.rename_absolute(temporary, moves[temporary])
		if error != OK:
			load_files()
			return "Could not rename %s (%s)" % [temporary.get_file(), error_string(error)]
	load_files()
	return ""


func _discard(path: String, trash: bool) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	return OS.move_to_trash(path) if trash else DirAccess.remove_absolute(path)


func _signature() -> String:
	var parts := PackedStringArray()
	for file in list_files():
		parts.append("%s@%d" % [file, FileAccess.get_modified_time(dir.path_join(file))])
	return ";".join(parts)
