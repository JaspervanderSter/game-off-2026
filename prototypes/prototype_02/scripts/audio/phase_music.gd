class_name PhaseMusic
extends Node
## Two independent voices allow reversible crossfades without restarting a
## playing loop. Only stop a voice once its fade has reached complete silence.

const FADE_SECONDS := 1.2
const MUSIC_DB := -16.0 # leave room for combat and reward sound effects
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


## Empty id fades all music out. Re-selecting a track preserves its position.
func transition_to(id: String) -> void:
	assert(id == "" or TRACKS.has(id))
	current = id
	if id != "" and not players[id].playing:
		players[id].play()


func _process(dt: float) -> void:
	advance_fades(dt)


func advance_fades(dt: float) -> void:
	for id in players:
		var player: AudioStreamPlayer = players[id]
		var target := 1.0 if id == current else 0.0
		var weight := move_toward(float(weights[id]), target, dt / FADE_SECONDS)
		weights[id] = weight
		# Smoothstep in amplitude: quiet starts and ends with no volume jumps.
		player.volume_linear = weight * weight * (3.0 - 2.0 * weight) * db_to_linear(MUSIC_DB)
		if weight == 0.0 and id != current and player.playing:
			player.stop()
