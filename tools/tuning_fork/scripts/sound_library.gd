class_name SoundLibrary
extends RefCounted
## The sound events of a game folder: every event under `sfx/` (a JSON file
## `<folders>/<name>.json` with OGG files `<name>.ogg`, `<name>_2.ogg`...
## beside it, path "<folders>/<name>") and the mixing groups of
## `sfx/groups.json`. Creates, renames and deletes events and groups, and reads
## and writes the JSON files in the game's format. Definition:
## tools/tuning_fork/docs/.
##
## Mirrors the runtime addon, addons/tuning_fork/sfx.gd in the game. Keep
## SOUND_DEFAULTS, GROUP_DEFAULTS, the file naming and the playback rules
## (SoundPlayer) in sync with it; tests/run_tests.gd compares them.

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
const GROUP_DEFAULTS := {
	"volume_db": 0.0,
}
const PICK_MODES := ["shuffle", "random"]
const GROUPS_FILE := "groups.json"
## Groups of a new groups.json.
const STARTING_GROUPS := ["effects", "ui", "ambience"]
## Keys a settings file may hold besides its values.
const INFO_KEYS := ["description"]
## Keys written as whole numbers.
const INT_KEYS := ["cooldown_ms", "shuffle_refill_after"]
## Written key order: description, values (defaults order), other keys.
const VALUE_ORDER := ["group", "loop", "protected", "files_from", "volume_db", "volume_jitter_db", "pitch",
	"pitch_jitter", "cooldown_ms", "pick", "shuffle_refill_after"]

## The game folder (holding sfx/), as an absolute path.
var root := ""
## SFX folder relative to the selected project, resolved from its configuration.
var folder_name := "sfx"
## Events, sorted by path.
var sounds: Array[SoundEntry] = []
## Groups by name: their settings, as edited.
var groups := {}
## groups.json text at the last load or save.
var groups_saved_text := ""
var groups_time := -1
## Warnings about groups.json.
var groups_problems: Array[String] = []
var _structure := ""


## Scans `path`. Returns an error message, or "" on success.
func open(path: String) -> String:
	root = path.simplify_path()
	sounds.clear()
	folder_name = audio_root(root).path_join("sfx")
	if not DirAccess.dir_exists_absolute(sfx_dir()) and workspace_folders(root, "music").is_empty():
		return "No audio folders at the configured audio root in %s" % root
	_scan(sfx_dir(), "")
	_sort()
	load_groups()
	_structure = structure_signature()
	return ""


## The project chooses one editable audio root; the tool knows no game modes.
static func audio_root(game: String) -> String:
	var config_path := game.path_join("tuning_fork.json")
	if not FileAccess.file_exists(config_path):
		return ""
	var config = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	if not config is Dictionary or not config.get("audio_root") is String:
		return "__invalid_audio_root__"
	var folder: String = config.audio_root.replace("\\", "/")
	if folder.is_empty() or folder.is_absolute_path() or folder.contains(":") or ".." in folder.split("/"):
		return "__invalid_audio_root__"
	return folder.simplify_path()


## Only direct audio folders of the configured root are exposed.
static func workspace_folders(game: String, kind: String) -> Array[String]:
	var folder := audio_root(game).path_join(kind)
	var result: Array[String] = []
	if DirAccess.dir_exists_absolute(game.path_join(folder)):
		result.append(folder)
	return result


func sfx_dir() -> String:
	return root.path_join(folder_name)


func groups_path() -> String:
	return sfx_dir().path_join(GROUPS_FILE)


func find(event_path: String) -> SoundEntry:
	for entry in sounds:
		if entry.path == event_path:
			return entry
	return null


## Path relative to the game folder, for display.
func relative(path: String) -> String:
	return path.trim_prefix(root + "/")


## The sound files an event plays: its own, or those of the event its
## `files_from` names (as Sfx.files_of).
func streams_of(entry: SoundEntry) -> Array[AudioStream]:
	var source := borrowed_from(entry)
	return source.streams if source != null else entry.streams


## The event whose files `entry` plays, or null when it plays its own.
func borrowed_from(entry: SoundEntry) -> SoundEntry:
	var source_path := str(entry.setting("files_from"))
	return null if source_path == "" else find(source_path)


## Events whose files_from names `entry`.
func borrowers_of(entry: SoundEntry) -> Array[SoundEntry]:
	var list: Array[SoundEntry] = []
	for other in sounds:
		if other != entry and str(other.setting("files_from")) == entry.path:
			list.append(other)
	return list


## Events that other events can take their files from: those with no files_from.
func file_sources(except: SoundEntry) -> Array[SoundEntry]:
	var list: Array[SoundEntry] = []
	for other in sounds:
		if other != except and str(other.setting("files_from")) == "":
			list.append(other)
	return list


## Files and folders under sfx/ by name, to notice events added or removed by
## another program.
func structure_signature() -> String:
	var parts := PackedStringArray()
	_list_structure(sfx_dir(), parts)
	return ";".join(parts)


func structure_changed_on_disk() -> bool:
	return structure_signature() != _structure


## Why `event_path` cannot name a new event, or "" when it can: folders and
## a name of lowercase letters, digits and "_", the name not ending in "_N".
func path_problem(event_path: String, except: SoundEntry = null) -> String:
	if event_path == "":
		return "Give the event a name"
	var parts := event_path.split("/")
	var segment := RegEx.create_from_string("^[a-z0-9_]+$")
	for part in parts:
		if segment.search(part) == null:
			return "Use lowercase letters, digits and _ in \"%s\", folders separated by /" % part
	var event_name := parts[parts.size() - 1]
	if RegEx.create_from_string("_[0-9]+$").search(event_name) != null:
		return "A name cannot end in _ and a number: that marks extra sound files"
	if parts.size() == 1 and event_name + ".json" == GROUPS_FILE:
		return "%s is the groups file" % GROUPS_FILE
	var existing := find(event_path)
	if existing != null and existing != except:
		return "%s already exists" % event_path
	return ""


## Creates the event `event_path` with a JSON file holding its description.
## Returns an error message, or "" on success.
func create_event(event_path: String, description: String) -> String:
	var problem := path_problem(event_path)
	if problem != "":
		return problem
	var entry := _entry_at(event_path)
	entry.load_settings()
	entry.data["description"] = description
	var error := entry.save()
	if error != OK:
		return "Could not create %s (%s)" % [relative(entry.json_path), error_string(error)]
	entry.load_files()
	sounds.append(entry)
	_sort()
	_structure = structure_signature()
	return ""


## Moves `entry` (its JSON and sound files) to `event_path`, and points the
## files_from of other events at its new path. Unsaved settings stay unsaved.
## Returns an error message, or "" on success.
func rename_event(entry: SoundEntry, event_path: String) -> String:
	var problem := path_problem(event_path, entry)
	if problem != "":
		return problem
	if event_path == entry.path:
		return ""
	var target := _entry_at(event_path)
	var error := DirAccess.make_dir_recursive_absolute(target.dir)
	if error != OK:
		return "Could not create %s (%s)" % [relative(target.dir), error_string(error)]
	var moves := {}
	if FileAccess.file_exists(entry.json_path):
		moves[entry.json_path] = target.json_path
	var names := entry.list_files()
	for i in names.size():
		moves[entry.dir.path_join(names[i])] = target.dir.path_join(numbered_file(target.name, i + 1))
	for from: String in moves:
		if FileAccess.file_exists(moves[from]):
			return "%s already exists" % relative(moves[from])
	for from: String in moves:
		error = DirAccess.rename_absolute(from, moves[from])
		if error != OK:
			return "Could not move %s (%s)" % [relative(from), error_string(error)]
		_remove_if_present(from + ".import")
	var old_path := entry.path
	var old_dir := entry.dir
	entry.path = target.path
	entry.name = target.name
	entry.folder = target.folder
	entry.dir = target.dir
	entry.json_path = target.json_path
	if entry.has_json:
		entry.json_time = FileAccess.get_modified_time(entry.json_path)
	entry.load_files()
	for other in sounds:
		if str(other.data.get("files_from", "")) == old_path:
			_update_saved(other, "files_from", event_path)
	_remove_empty_folders(old_dir)
	_sort()
	_structure = structure_signature()
	return ""


## Moves `entry`'s JSON and sound files to the recycle bin (or deletes them
## when `trash` is false). Refused while other events take its files.
## Returns an error message, or "" on success.
func delete_event(entry: SoundEntry, trash := true) -> String:
	var borrowers := borrowers_of(entry)
	if not borrowers.is_empty():
		return "%s plays the files of %s: change its files_from first" % [borrowers[0].path, entry.path]
	var paths: Array[String] = [entry.json_path]
	for file in entry.list_files():
		paths.append(entry.dir.path_join(file))
	for path in paths:
		if FileAccess.file_exists(path):
			var error := OS.move_to_trash(path) if trash else DirAccess.remove_absolute(path)
			if error != OK:
				return "Could not remove %s (%s)" % [relative(path), error_string(error)]
			_remove_if_present(path + ".import")
	sounds.erase(entry)
	_remove_empty_folders(entry.dir)
	_structure = structure_signature()
	return ""


# --- Groups ------------------------------------------------------------------

## (Re)reads groups.json. Without one, the starting groups (written on save).
func load_groups() -> void:
	groups.clear()
	groups_problems.clear()
	groups_time = -1
	if FileAccess.file_exists(groups_path()):
		groups_time = FileAccess.get_modified_time(groups_path())
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(groups_path()))
		if parsed is Dictionary:
			for group_name: String in parsed:
				if parsed[group_name] is Dictionary:
					groups[group_name] = parsed[group_name]
					for problem in settings_problems(parsed[group_name], GROUP_DEFAULTS):
						groups_problems.append("%s: %s" % [group_name, problem])
				else:
					groups_problems.append("%s is not an object" % group_name)
		else:
			groups_problems.append("%s is not a valid JSON object: saving replaces it" % GROUPS_FILE)
		groups_saved_text = groups_text()
	else:
		for group_name in STARTING_GROUPS:
			groups[group_name] = GROUP_DEFAULTS.duplicate()
		groups_saved_text = ""


func groups_text() -> String:
	var ordered_groups := {}
	for group_name: String in groups:
		ordered_groups[group_name] = ordered(groups[group_name], GROUP_DEFAULTS)
	return _value_text(ordered_groups, "", "") + "\n"


func groups_dirty() -> bool:
	return groups_text() != groups_saved_text


func groups_changed_on_disk() -> bool:
	if FileAccess.file_exists(groups_path()):
		return FileAccess.get_modified_time(groups_path()) != groups_time
	return groups_time != -1


func save_groups() -> Error:
	var file := FileAccess.open(groups_path(), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var written := groups_text()
	file.store_string(written)
	file.close()
	groups_saved_text = written
	groups_time = FileAccess.get_modified_time(groups_path())
	return OK


func group_volume(group_name: String) -> float:
	return float(groups.get(group_name, {}).get("volume_db", GROUP_DEFAULTS.volume_db))


## Events whose group is `group_name`.
func group_members(group_name: String) -> Array[SoundEntry]:
	var list: Array[SoundEntry] = []
	for entry in sounds:
		if str(entry.setting("group")) == group_name:
			list.append(entry)
	return list


## Why `group_name` cannot name a new group, or "" when it can.
func group_problem(group_name: String) -> String:
	if RegEx.create_from_string("^[a-z0-9_]+$").search(group_name) == null:
		return "Use lowercase letters, digits and _ for a group name"
	if groups.has(group_name):
		return "%s already exists" % group_name
	return ""


func add_group(group_name: String) -> String:
	var problem := group_problem(group_name)
	if problem == "":
		groups[group_name] = GROUP_DEFAULTS.duplicate()
	return problem


## Renames a group in groups.json (saved with the groups) and in its events'
## settings (saved at once for events without other unsaved changes).
func rename_group(old_name: String, new_name: String) -> String:
	if old_name == new_name:
		return ""
	var problem := group_problem(new_name)
	if problem != "":
		return problem
	var renamed := {}
	for group_name: String in groups:
		renamed[new_name if group_name == old_name else group_name] = groups[group_name]
	groups = renamed
	for entry in group_members(old_name):
		_update_saved(entry, "group", new_name)
	return ""


## Removes a group no event uses.
func remove_group(group_name: String) -> String:
	var members := group_members(group_name)
	if not members.is_empty():
		return "%d event%s use %s" % [members.size(), "" if members.size() == 1 else "s", group_name]
	groups.erase(group_name)
	return ""


# --- Files and formats ----------------------------------------------------------

## Position of `file` among the sound files of `event_name`: 1 for
## "<name>.ogg", N for "<name>_N.ogg" (N from 2), 0 otherwise (as Sfx.file_number).
static func file_number(file: String, event_name: String) -> int:
	if file == event_name + ".ogg":
		return 1
	var digits := file.trim_prefix(event_name + "_").trim_suffix(".ogg")
	if file.begins_with(event_name + "_") and file.ends_with(".ogg") and digits.is_valid_int() \
			and str(int(digits)) == digits and int(digits) >= 2:
		return int(digits)
	return 0


## File name of the `number`-th sound file of `event_name`.
static func numbered_file(event_name: String, number: int) -> String:
	return event_name + ".ogg" if number <= 1 else "%s_%d.ogg" % [event_name, number]


## Keys of a settings dictionary that the game does not know, and values it
## cannot use. Same rules as Sfx.settings_problems in the game.
static func settings_problems(data: Dictionary, known: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for key: String in data:
		if not known.has(key) and not key in INFO_KEYS:
			problems.append("unknown key \"%s\"" % key)
	if data.has("pick") and known.has("pick") and not data["pick"] in PICK_MODES:
		problems.append("\"pick\" must be one of %s" % ", ".join(PICK_MODES))
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
		if not out.has(key):
			out[key] = data[key]
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


# --- Internals ---------------------------------------------------------------

## A folder's events: every JSON file, and every OGG file that is not a
## numbered file (`_N`) of another event there; then its sub-folders.
func _scan(dir: String, folder: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for event_name in event_names_at(dir, folder == ""):
		var entry := _entry_at(event_name if folder == "" else folder.path_join(event_name))
		entry.load_settings()
		entry.load_files()
		sounds.append(entry)
	for sub in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(sub), sub if folder == "" else folder.path_join(sub))


## Names of the events in the folder `dir` (not its sub-folders): every JSON
## file, and every OGG file that is not a numbered file (`_N`) of another event
## there. `top` skips groups.json, for sfx/ itself.
static func event_names_at(dir: String, top: bool) -> Array[String]:
	var jsons := {}
	var names := {}
	for file in DirAccess.get_files_at(dir):
		var extension := file.get_extension().to_lower()
		if top and file == GROUPS_FILE:
			continue
		if extension == "json":
			jsons[file.get_basename()] = true
		if extension == "json" or extension == "ogg":
			names[file.get_basename()] = true
	var sorted := names.keys()
	var found: Array[String] = []
	for event_name: String in sorted:
		# A numbered OGG without its own JSON belongs to the event it numbers.
		if not jsons.has(event_name) and sorted.any(func(other: String) -> bool: return file_number(event_name + ".ogg", other) > 1):
			continue
		found.append(event_name)
	return found


## Number of events in the game folder `game` (holding sfx/), counted without
## loading them; -1 when it has no sfx/ folder.
static func event_count(game: String) -> int:
	var folders := workspace_folders(game, "sfx")
	if folders.is_empty():
		return -1
	var sfx := game.path_join(folders[0])
	return _count_events(sfx, true)


static func _count_events(dir: String, top: bool) -> int:
	var count := event_names_at(dir, top).size()
	for sub in DirAccess.get_directories_at(dir):
		count += _count_events(dir.path_join(sub), false)
	return count


func _entry_at(event_path: String) -> SoundEntry:
	var entry := SoundEntry.new()
	entry.path = event_path
	entry.name = event_path.get_file()
	entry.folder = event_path.get_base_dir()
	entry.dir = sfx_dir() if entry.folder == "" else sfx_dir().path_join(entry.folder)
	entry.json_path = entry.dir.path_join(entry.name + ".json")
	return entry


func _sort() -> void:
	sounds.sort_custom(func(a: SoundEntry, b: SoundEntry) -> bool: return a.path < b.path)


## Sets `key` on `entry`; saves it at once unless it had other unsaved changes.
func _update_saved(entry: SoundEntry, key: String, value: Variant) -> void:
	var was_dirty := entry.is_dirty()
	entry.data[key] = value
	if not was_dirty and entry.has_json:
		entry.save()


func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Removes `dir` and the folders above it that became empty, up to sfx/.
func _remove_empty_folders(dir: String) -> void:
	while dir.length() > sfx_dir().length() and dir.begins_with(sfx_dir()) \
			and DirAccess.get_files_at(dir).is_empty() and DirAccess.get_directories_at(dir).is_empty():
		DirAccess.remove_absolute(dir)
		dir = dir.get_base_dir()


func _list_structure(dir: String, parts: PackedStringArray) -> void:
	for file in DirAccess.get_files_at(dir):
		if file.get_extension().to_lower() in ["json", "ogg"]:
			parts.append(relative(dir.path_join(file)))
	for sub in DirAccess.get_directories_at(dir):
		_list_structure(dir.path_join(sub), parts)


## Remembers the files under sfx/ as they are now (after a change made here).
func note_structure() -> void:
	_structure = structure_signature()
