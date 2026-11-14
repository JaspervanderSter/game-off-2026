class_name PhaseMusic
extends Node
## Two independent voices allow reversible crossfades without restarting a
## playing loop. Only stop a voice once its fade has reached complete silence.
## Volume, fade time and frenzy speed-up come from music/music.json. The music
## is the game's own system, apart from the Tuning Fork sound events (Sfx).
## Exported desktop builds apply a music/music.json beside the executable over
## the packed values; the settings reload when the game window regains focus.

const SETTINGS := "res://music/music.json"
const DEFAULTS := {
	"volume_db": -16.0,
	"fade_seconds": 1.2,
	"frenzy_speed_per_level": 0.05,
}
const INFO_KEYS := ["description"]

const TRACKS := {
	"prep": preload("res://music/cartoon_magic.ogg"),
	"battle": preload("res://music/marching_beat.ogg"),
}

var players: Dictionary = {}
var weights: Dictionary = {}
var current := ""
var _settings := {}


## Music settings: the project's music.json, then the one beside an exported
## executable on top, key by key. Unknown keys are reported.
static func load_settings() -> Dictionary:
	var paths := [SETTINGS]
	if OS.has_feature("template") and not OS.has_feature("web"):
		paths.append(OS.get_executable_path().get_base_dir().path_join("music/music.json"))
	var merged := {}
	for path: String in paths:
		if not FileAccess.file_exists(path):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary:
			push_warning("%s is not a valid JSON object" % path)
			continue
		for problem in settings_problems(data):
			push_warning("%s: %s" % [path, problem])
		merged.merge(data, true)
	return merged


static func settings_problems(data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for key: String in data:
		if not DEFAULTS.has(key) and not key in INFO_KEYS:
			problems.append("unknown key \"%s\"" % key)
	return problems


func setting(key: String) -> Variant:
	return _settings.get(key, DEFAULTS[key])


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_settings = load_settings()


func _ready() -> void:
	_settings = load_settings()
	for id in TRACKS:
		var player := AudioStreamPlayer.new()
		var stream: AudioStreamOggVorbis = TRACKS[id].duplicate()
		stream.loop = true
		player.stream = stream
		player.volume_linear = 0.0
		add_child(player)
		players[id] = player
		weights[id] = 0.0


## Seconds of a full fade in or out.
func fade_seconds() -> float:
	return maxf(0.01, float(setting("fade_seconds")))


## Music loudness once fully faded in, in decibels.
func volume_db() -> float:
	return float(setting("volume_db"))


## Empty id fades all music out. Re-selecting a track preserves its position.
func transition_to(id: String) -> void:
	assert(id == "" or TRACKS.has(id))
	current = id
	if id != "" and not players[id].playing:
		players[id].play()


func set_frenzy_level(level: int) -> void:
	var player: AudioStreamPlayer = players["battle"]
	player.pitch_scale = maxf(0.01, 1.0 + level * float(setting("frenzy_speed_per_level")))


func _process(dt: float) -> void:
	advance_fades(dt)


func advance_fades(dt: float) -> void:
	var full := db_to_linear(volume_db())
	for id in players:
		var player: AudioStreamPlayer = players[id]
		var target := 1.0 if id == current else 0.0
		var weight := move_toward(float(weights[id]), target, dt / fade_seconds())
		weights[id] = weight
		# Smoothstep in amplitude: quiet starts and ends with no volume jumps.
		player.volume_linear = weight * weight * (3.0 - 2.0 * weight) * full
		if weight == 0.0 and id != current and player.playing:
			player.stop()
