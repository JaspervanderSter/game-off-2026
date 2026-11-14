class_name SoundPlayer
extends Node
## Plays effects the way the game's Sfx autoload does: a pool of voices, the
## repeat delay, the choice of one file per play ("pick"), random volume and
## pitch variation, and pitch steps.

## Emitted for each play that was not skipped by the repeat delay.
signal played(entry: SoundEntry, file_index: int, step: int, pitch: float, volume_db: float, voice: AudioStreamPlayer)

const VOICES := 10

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}
var _picks := {}


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


## Pitch of one play before random variation: `step` is the position in a
## series; it adds `pitch_step` per step (as Sfx.base_pitch).
static func base_pitch(entry: SoundEntry, step: int) -> float:
	return float(entry.setting("pitch")) + float(entry.setting("pitch_step")) * step


## Index of the next file among `count` (as Sfx.next_pick): "random" draws any
## file; "shuffle" deals every file once in a random order, dealing again after
## `refill_after` plays when above 0; a new deal never starts with the last file.
static func next_pick(state: Dictionary, count: int, mode: String, refill_after: int) -> int:
	var index := 0
	if count > 1 and mode == "random":
		index = randi() % count
	elif count > 1:
		var bag: Array = state.get("bag", [])
		var dealt: int = state.get("dealt", 0)
		var limit := count if refill_after <= 0 else mini(refill_after, count)
		if bag.is_empty() or dealt >= limit or bag.any(func(i: int) -> bool: return i >= count):
			bag = range(count)
			bag.shuffle()
			dealt = 0
			if bag.back() == state.get("last", -1):
				bag.reverse()
		index = bag.pop_back()
		state["bag"] = bag
		state["dealt"] = dealt + 1
	state["last"] = index
	return index


## Starts the deal of a sound's files over (after its pick settings change).
func reset_pick(entry: SoundEntry) -> void:
	_picks.erase(entry.name)


## Plays one file of `entry`: `file_index`, or the next one its settings pick
## when -1. Returns false when skipped: no readable file, or repeated within
## cooldown_ms.
func play(entry: SoundEntry, step := 0, file_index := -1) -> bool:
	if entry.streams.is_empty():
		return false
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(entry.name, -100000)) < int(entry.setting("cooldown_ms")):
		return false
	if file_index < 0:
		file_index = next_pick(_picks.get_or_add(entry.name, {}), entry.streams.size(),
			str(entry.setting("pick")), int(entry.setting("shuffle_refill_after")))
	var stream := entry.streams[file_index]
	if stream == null:
		return false
	_last_played[entry.name] = now
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	var pitch_jitter := float(entry.setting("pitch_jitter"))
	var volume_jitter := float(entry.setting("volume_jitter_db"))
	var volume := float(entry.setting("volume_db")) + randf_range(-volume_jitter, volume_jitter)
	var pitch := maxf(0.01, base_pitch(entry, step) + randf_range(-pitch_jitter, pitch_jitter))
	p.stream = stream
	p.volume_db = volume
	p.pitch_scale = pitch
	p.play()
	played.emit(entry, file_index, step, pitch, volume, p)
	return true


func stop_all() -> void:
	for p in _players:
		p.stop()
