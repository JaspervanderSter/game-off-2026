class_name MusicPreview
extends Node
## Plays the music tracks as the game's PhaseMusic does: smooth crossfades of
## `fade_seconds` up to `volume_db`, read live from the music settings, and the
## frenzy speed-up. The game speeds up only the battle track; here the speed-up
## applies to whichever track plays.

var settings: SoundEntry
## Track fading in, or "" when all fade out.
var current := ""
var frenzy_level := 0
var _players := {}
var _weights := {}


func set_tracks(tracks: Dictionary) -> void:
	for p in _players.values():
		p.queue_free()
	_players.clear()
	_weights.clear()
	current = ""
	for id: String in tracks:
		var player := AudioStreamPlayer.new()
		player.stream = tracks[id]
		player.volume_linear = 0.0
		add_child(player)
		_players[id] = player
		_weights[id] = 0.0


func transition_to(id: String) -> void:
	current = id if _players.has(id) else ""
	if current != "" and not _players[current].playing:
		_players[current].play()


func stop_now() -> void:
	current = ""
	for id: String in _players:
		_players[id].stop()
		_weights[id] = 0.0


## Fade amount of a track, 0 (silent) to 1 (full volume).
func weight(id: String) -> float:
	return float(_weights.get(id, 0.0))


func speed() -> float:
	return maxf(0.01, 1.0 + frenzy_level * float(_setting("frenzy_speed_per_level")))


func _setting(key: String) -> Variant:
	return settings.setting(key) if settings != null else SoundLibrary.MUSIC_DEFAULTS[key]


func _process(dt: float) -> void:
	var fade := maxf(0.01, float(_setting("fade_seconds")))
	var full := db_to_linear(float(_setting("volume_db")))
	for id: String in _players:
		var player: AudioStreamPlayer = _players[id]
		var w := move_toward(float(_weights[id]), 1.0 if id == current else 0.0, dt / fade)
		_weights[id] = w
		# Smoothstep in amplitude, as in the game.
		player.volume_linear = w * w * (3.0 - 2.0 * w) * full
		player.pitch_scale = speed()
		if w == 0.0 and id != current and player.playing:
			player.stop()
