class_name PhaseMusic
extends Node
## Two independent voices allow reversible crossfades without restarting a
## playing loop. Only stop a voice once its fade has reached complete silence.
## Volume, fade time and frenzy speed-up come from music/music.json (see Sfx).

const TRACKS := {
	"prep": preload("res://music/cartoon_magic.ogg"),
	"battle": preload("res://music/marching_beat.ogg"),
}

var players: Dictionary = {}
var weights: Dictionary = {}
var current := ""


func _ready() -> void:
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
	return maxf(0.01, float(Sfx.music_setting("fade_seconds")))


## Music loudness once fully faded in, in decibels.
func volume_db() -> float:
	return float(Sfx.music_setting("volume_db"))


## Empty id fades all music out. Re-selecting a track preserves its position.
func transition_to(id: String) -> void:
	assert(id == "" or TRACKS.has(id))
	current = id
	if id != "" and not players[id].playing:
		players[id].play()


func set_frenzy_level(level: int) -> void:
	var player: AudioStreamPlayer = players["battle"]
	player.pitch_scale = maxf(0.01, 1.0 + level * float(Sfx.music_setting("frenzy_speed_per_level")))


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
