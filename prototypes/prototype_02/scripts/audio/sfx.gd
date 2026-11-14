extends Node
## Sound effects, played by name. Each one is an OGG file with a JSON file of
## the same name beside it, `res://sfx/<category>/<name>.ogg` and `.json`; the
## JSON sets how it plays (volume, pitch, random variation, melody, repeat delay).
## `music/music.json` sets the music volume, fades and frenzy speed-up.
## Autoloaded as Sfx; result audio has its own voice so effects cannot steal it.
##
## Exported desktop builds also read the same files beside the executable
## (`sfx/<category>/<name>.ogg|json`, `music/music.json`): a sound file there
## replaces the packed one, and a JSON file there applies over the packed values
## key by key, so a sound designer can tune the game without re-exporting.
## Changed files reload when the game window regains focus.
##
## A JSON file may hold variants: `play("coin_gain:harvest")` plays coin_gain.ogg
## with the values of its "harvest" variant, then of the sound, then defaults.

const DIR := "res://sfx/"
const MUSIC_SETTINGS := "res://music/music.json"
## Every effect the game plays, with the category folder that holds it.
const SOUNDS := {
	"click": "interface", "fail": "interface", "buy": "interface",
	"combine": "interface", "merge": "interface", "difficulty_unlock": "interface",
	"coin_gain": "coins", "coin_pop": "coins",
	"hit": "combat", "shoot": "combat", "death": "combat",
	"hop": "abilities", "fear": "abilities", "blizzard": "abilities", "note": "abilities",
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
## Command-line user argument (after `--`) that silences all game audio.
const NO_SOUND_ARG := "--no-sound"

## False when launched with --no-sound: nothing is loaded or played and
## the master bus is muted (music included).
var enabled := true
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}
var _result_player: AudioStreamPlayer
## Folder of the executable, whose sfx/ and music/ files replace packed ones;
## empty when not exported.
var _override_root := ""
## Modification time of each replacement file already loaded, by path.
var _override_times := {}
## Settings of each sound by name, merged packed + replacement.
var _settings := {}
var _music := {}


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
		_streams[sound_name] = load(DIR + sound_file(sound_name, ".ogg"))
		_settings[sound_name] = read_settings(DIR + sound_file(sound_name, ".json"), SOUND_DEFAULTS)
	_music = read_settings(MUSIC_SETTINGS, MUSIC_DEFAULTS)
	if OS.has_feature("template") and not OS.has_feature("web"):
		_override_root = OS.get_executable_path().get_base_dir()
	load_overrides()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and enabled:
		load_overrides()


## Path of a sound's file relative to the sfx folder, e.g. "combat/hit.ogg".
static func sound_file(sound_name: String, extension: String) -> String:
	return "%s/%s%s" % [SOUNDS[sound_name], sound_name, extension]


## Loads each replacement file that is new or changed since its last load.
## A file that cannot be read keeps the previous values and is retried later.
func load_overrides() -> void:
	if _override_root == "":
		return
	for sound_name in SOUNDS:
		var path := _override_root.path_join("sfx").path_join(sound_file(sound_name, ".ogg"))
		if _is_new_override(path):
			var stream := AudioStreamOggVorbis.load_from_file(path)
			if stream == null:
				push_warning("Could not load replacement sound %s" % path)
			else:
				_override_times[path] = FileAccess.get_modified_time(path)
				_streams[sound_name] = stream
		path = _override_root.path_join("sfx").path_join(sound_file(sound_name, ".json"))
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


func _is_new_override(path: String) -> bool:
	return FileAccess.file_exists(path) and _override_times.get(path, -1) != FileAccess.get_modified_time(path)


## Packed settings with a replacement file's values on top, key by key (and
## variant by variant); null when the replacement cannot be read.
func _apply_override(packed: Dictionary, path: String, known: Dictionary) -> Variant:
	var replacement := read_settings(path, known)
	if replacement.is_empty():
		push_warning("Could not read replacement settings %s" % path)
		return null
	_override_times[path] = FileAccess.get_modified_time(path)
	var variants: Dictionary = _variants(packed).duplicate(true)
	var new_variants := _variants(replacement)
	for variant in new_variants:
		if new_variants[variant] is Dictionary:
			variants[variant] = variants.get(variant, {}).merged(new_variants[variant], true)
	var merged := packed.merged(replacement, true)
	if not variants.is_empty():
		merged["variants"] = variants
	return merged


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


## Keys of a settings dictionary (or of its variants) that the game does not know.
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


## A sound setting: from the variant, then the sound, then SOUND_DEFAULTS.
func sound_setting(sound: String, key: String) -> Variant:
	var data: Dictionary = _settings.get(sound.get_slice(":", 0), {})
	if sound.contains(":"):
		var variant = _variants(data).get(sound.get_slice(":", 1), {})
		if variant is Dictionary and variant.has(key):
			return variant[key]
	return data.get(key, SOUND_DEFAULTS[key])


## The variants of a settings dictionary, empty when absent or malformed.
static func _variants(data: Dictionary) -> Dictionary:
	var variants = data.get("variants", {})
	return variants if variants is Dictionary else {}


func music_setting(key: String) -> Variant:
	return _music.get(key, MUSIC_DEFAULTS[key])


## Pitch for one play of `sound`, before random variation. `step` is the
## position in a series: it adds `pitch_step` per step and walks the melody.
func base_pitch(sound: String, step := 0) -> float:
	var pitch := float(sound_setting(sound, "pitch")) + float(sound_setting(sound, "pitch_step")) * step
	var melody: Array = sound_setting(sound, "melody")
	if not melody.is_empty():
		pitch *= pow(2.0, float(melody[posmod(step, melody.size())]) / 12.0)
	return pitch


## Plays the sound `sound` (or `sound:variant`) as its settings describe.
## `step` is the position in a series, e.g. the index of a landing coin.
func play(sound: String, step := 0) -> void:
	var sound_name := sound.get_slice(":", 0)
	if not enabled or not _streams.has(sound_name):
		return
	# Avoid machine-gun stacking of identical sounds in the same instant.
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound_name, -100000)) < int(sound_setting(sound, "cooldown_ms")):
		return
	_last_played[sound_name] = now
	var p := _result_player
	if not sound_name in RESULT_SOUNDS:
		p = _players[_next]
		_next = (_next + 1) % VOICES
	var pitch_jitter := float(sound_setting(sound, "pitch_jitter"))
	var volume_jitter := float(sound_setting(sound, "volume_jitter_db"))
	p.stream = _streams[sound_name]
	p.volume_db = float(sound_setting(sound, "volume_db")) + randf_range(-volume_jitter, volume_jitter)
	p.pitch_scale = maxf(0.01, base_pitch(sound, step) + randf_range(-pitch_jitter, pitch_jitter))
	p.play()
