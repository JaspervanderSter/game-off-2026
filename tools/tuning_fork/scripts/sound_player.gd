class_name SoundPlayer
extends Node
## Plays effects the way the game's Sfx autoload does: a pool of voices, the
## repeat delay, random volume and pitch variation, and pitch steps.

## Emitted for each play that was not skipped by the repeat delay.
signal played(entry: SoundEntry, variant: String, step: int, pitch: float, volume_db: float)

const VOICES := 10

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


## Pitch of one play before random variation: `step` is the position in a
## series; it adds `pitch_step` per step (as Sfx.base_pitch).
static func base_pitch(entry: SoundEntry, variant: String, step: int) -> float:
	return float(entry.setting("pitch", variant)) + float(entry.setting("pitch_step", variant)) * step


## Plays `entry` with the values of `variant` ("" for the sound itself).
## Returns false when skipped: no stream, or repeated within cooldown_ms.
func play(entry: SoundEntry, variant := "", step := 0) -> bool:
	if entry.stream == null:
		return false
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(entry.name, -100000)) < int(entry.setting("cooldown_ms", variant)):
		return false
	_last_played[entry.name] = now
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	var pitch_jitter := float(entry.setting("pitch_jitter", variant))
	var volume_jitter := float(entry.setting("volume_jitter_db", variant))
	var volume := float(entry.setting("volume_db", variant)) + randf_range(-volume_jitter, volume_jitter)
	var pitch := maxf(0.01, base_pitch(entry, variant, step) + randf_range(-pitch_jitter, pitch_jitter))
	p.stream = entry.stream
	p.volume_db = volume
	p.pitch_scale = pitch
	p.play()
	played.emit(entry, variant, step, pitch, volume)
	return true


func stop_all() -> void:
	for p in _players:
		p.stop()
