class_name MapAmbience
extends Node
## Nature ambience of the journey map, following its sky cycle. Three looping
## beds (day wind, night wind, crickets) take their loudness from the four sky
## states; short calls (birds, wind chimes, an owl) come at random, more or less
## often by time of day, from the island they belong to. The ambience fades in
## while the map is shown and out while it is hidden; the menu and the duels
## have none. Like the music, it is the game's own system, apart from the
## Tuning Fork sound events: its volume and fade time are ambience_volume_db and
## ambience_fade_seconds in default/music/music.json. tools/make_map_ambience.gd
## synthesises the sounds in default/music/ambience/.
## Design: docs/design/Prototype 02.md, "Sky, sound and entry point".

const SkyCycle := preload("res://scripts/ui/day_night_sky.gd")

const BEDS := {
	"wind_day": preload("res://default/music/ambience/wind_day.ogg"),
	"wind_night": preload("res://default/music/ambience/wind_night.ogg"),
	"crickets": preload("res://default/music/ambience/crickets.ogg"),
}
## Loudness of each bed (linear, 0 to 1) in each sky state: day, golden mist,
## dusk, night. The cycle blends between neighbouring states.
const BED_LEVELS := {
	"wind_day": [1.0, 0.75, 0.35, 0.0],
	"wind_night": [0.0, 0.25, 0.6, 1.0],
	"crickets": [0.0, 0.0, 0.45, 0.8],
}
const CALLS := {
	"bird": [
		preload("res://default/music/ambience/bird_1.ogg"), preload("res://default/music/ambience/bird_2.ogg"),
		preload("res://default/music/ambience/bird_3.ogg"), preload("res://default/music/ambience/bird_4.ogg"),
		preload("res://default/music/ambience/bird_5.ogg"), preload("res://default/music/ambience/bird_6.ogg"),
	],
	"chime": [
		preload("res://default/music/ambience/chime_1.ogg"), preload("res://default/music/ambience/chime_2.ogg"),
		preload("res://default/music/ambience/chime_3.ogg"),
	],
	"owl": [preload("res://default/music/ambience/owl_1.ogg"), preload("res://default/music/ambience/owl_2.ogg")],
}
## Calls per minute in each sky state (day, golden mist, dusk, night).
const CALL_RATES := {
	"bird": [14.0, 8.0, 3.0, 0.0],
	"chime": [0.0, 3.0, 1.0, 0.0],
	"owl": [0.0, 0.0, 1.0, 3.0],
}
## Shortest gap between two calls of a kind, in seconds.
const CALL_GAPS := {"bird": 1.2, "chime": 6.0, "owl": 9.0}
## Loudness of a call relative to the ambience volume, in dB (± 2 dB per call).
const CALL_LEVELS := {"bird": -3.0, "chime": -9.0, "owl": -5.0}
## Islands (0 forest, 1 town, 2 school) a call can come from.
const CALL_ISLANDS := {"bird": [0, 1], "chime": [2], "owl": [0]}
const CALL_VOICES := 4

var map: Node2D # world_map.gd
var presence := 0.0 # 0 while hidden, 1 once faded in on the map
var beds := {} # id -> AudioStreamPlayer
var voices: Array[AudioStreamPlayer2D] = []
var rng := RandomNumberGenerator.new()
var _wait := {} # kind -> seconds before another call of that kind may come
var _last := {} # kind -> index of the call last played, never repeated at once
var _settings := {}
## Only the Windows alternative replaces the complete procedural mix.
var replaced := false
var _original_gain := 1.0


func _ready() -> void:
	rng.randomize()
	_settings = PhaseMusic.load_settings()
	for id in BEDS:
		var player := AudioStreamPlayer.new()
		var stream: AudioStreamOggVorbis = BEDS[id].duplicate()
		stream.loop = true
		player.stream = stream
		player.volume_linear = 0.0
		add_child(player)
		beds[id] = player
	for i in CALL_VOICES:
		var voice := AudioStreamPlayer2D.new()
		voice.max_distance = 4000.0
		voice.attenuation = 0.0
		add_child(voice)
		voices.append(voice)
	for kind in CALLS:
		_wait[kind] = rng.randf_range(0.5, 3.0)
		_last[kind] = -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_settings = PhaseMusic.load_settings()


func _process(dt: float) -> void:
	advance(dt)


func setting(key: String) -> float:
	return float(_settings.get(key, PhaseMusic.DEFAULTS[key]))


## The sky cycle's position, 0 to 1 (0 is full day).
func sky_phase() -> float:
	return map.sky.elapsed / maxf(map.sky.cycle_seconds, 0.01)


## Loudness of a bed (linear, 0 to 1) at the current time of day.
func bed_level(id: String) -> float:
	return _by_time(BED_LEVELS[id])


## Calls of a kind per second at the current time of day.
func call_rate(kind: String) -> float:
	return _by_time(CALL_RATES[kind]) / 60.0


func _by_time(values: Array) -> float:
	var weights := SkyCycle.weights(sky_phase())
	var total := 0.0
	for i in 4:
		total += weights[i] * float(values[i])
	return total


func advance(dt: float) -> void:
	var shown := map.is_visible_in_tree()
	presence = move_toward(presence, 1.0 if shown else 0.0, dt / maxf(0.01, setting("ambience_fade_seconds")))
	# Smoothstep in amplitude: quiet starts and ends with no volume jumps.
	var fade := presence * presence * (3.0 - 2.0 * presence)
	if replaced or _original_gain < 1.0:
		_original_gain = move_toward(_original_gain, 0.0 if replaced else 1.0, dt / maxf(0.01, setting("ambience_fade_seconds")))
		fade *= _original_gain
	var full := db_to_linear(setting("ambience_volume_db"))
	for id in beds:
		var player: AudioStreamPlayer = beds[id]
		player.volume_linear = bed_level(id) * fade * full
		if fade > 0.0 and not player.playing:
			# Each visit picks up the loop somewhere else.
			player.play(rng.randf() * player.stream.get_length())
		elif fade == 0.0 and player.playing:
			player.stop()
	if not shown or presence < 0.5 or replaced:
		return
	for kind: String in CALLS:
		_wait[kind] -= dt
		if _wait[kind] <= 0.0 and rng.randf() < call_rate(kind) * dt:
			_call(kind, fade * full)
			_wait[kind] = CALL_GAPS[kind]


## Plays one call of `kind` from a free voice, on one of its islands.
func _call(kind: String, loudness: float) -> void:
	var voice: AudioStreamPlayer2D = null
	for candidate in voices:
		if not candidate.playing:
			voice = candidate
			break
	if voice == null:
		return
	var choices: Array = CALLS[kind]
	var index := rng.randi_range(0, choices.size() - 1)
	if index == _last[kind] and choices.size() > 1:
		index = (index + 1) % choices.size()
	_last[kind] = index
	var islands: Array = CALL_ISLANDS[kind]
	var island: Node2D = map.islands[islands[rng.randi_range(0, islands.size() - 1)]]
	voice.global_position = island.global_position + Vector2(rng.randf_range(-60.0, 60.0), rng.randf_range(-30.0, 10.0))
	voice.stream = choices[index]
	voice.volume_linear = loudness * db_to_linear(CALL_LEVELS[kind] + rng.randf_range(-2.0, 2.0))
	voice.pitch_scale = rng.randf_range(0.95, 1.05)
	voice.play()
