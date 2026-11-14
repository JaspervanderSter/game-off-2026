class_name SoundPlayer
extends Node
## Plays events the way the game's Sfx autoload does: a pool of shared voices,
## own voices for looping and protected events, the repeat delay, the choice of
## one file per play ("pick"), random volume and pitch variation, and one audio
## bus per group at the group's volume.

## Emitted for each play that was not skipped by the repeat delay.
signal played(entry: SoundEntry, file_index: int, pitch: float, volume_db: float, voice: AudioStreamPlayer)

const VOICES := 10
const LOOP_FADE := 0.25

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}
var _picks := {}
## Own voice of each looping or protected event, by path.
var _own_voices := {}


func _ready() -> void:
	for i in VOICES:
		_players.append(_new_voice())


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


## One audio bus per group, sent to Master, at the group's volume (as Sfx).
func apply_groups(groups: Dictionary) -> void:
	for group_name: String in groups:
		var bus := AudioServer.get_bus_index(group_name)
		if bus < 0:
			AudioServer.add_bus()
			bus = AudioServer.bus_count - 1
			AudioServer.set_bus_name(bus, group_name)
			AudioServer.set_bus_send(bus, "Master")
		AudioServer.set_bus_volume_db(bus, float(groups[group_name].get("volume_db", 0.0)))


## Starts the deal of an event's files over (after its pick settings change).
func reset_pick(entry: SoundEntry) -> void:
	_picks.erase(entry.path)


## Plays one of `streams` (the files `entry` plays): `file_index`, or the next
## one its settings pick when -1. A looping event loops until stop_all().
## Returns false when skipped: no readable file, or repeated within cooldown_ms.
func play(entry: SoundEntry, streams: Array[AudioStream], file_index := -1) -> bool:
	if streams.is_empty():
		return false
	var looping := bool(entry.setting("loop"))
	var now := Time.get_ticks_msec()
	if not looping and now - int(_last_played.get(entry.path, -100000)) < int(entry.setting("cooldown_ms")):
		return false
	if file_index < 0:
		file_index = next_pick(_picks.get_or_add(entry.path, {}), streams.size(),
			str(entry.setting("pick")), int(entry.setting("shuffle_refill_after")))
	var stream := streams[file_index]
	if stream == null:
		return false
	_last_played[entry.path] = now
	var p: AudioStreamPlayer
	if looping or bool(entry.setting("protected")):
		p = _own_voice(entry.path)
	else:
		p = _players[_next]
		_next = (_next + 1) % VOICES
	var pitch_jitter := 0.0 if looping else float(entry.setting("pitch_jitter"))
	var volume_jitter := 0.0 if looping else float(entry.setting("volume_jitter_db"))
	var volume := float(entry.setting("volume_db")) + randf_range(-volume_jitter, volume_jitter)
	var pitch := maxf(0.01, float(entry.setting("pitch")) + randf_range(-pitch_jitter, pitch_jitter))
	if p.has_meta("fade"):
		p.get_meta("fade").kill()
		p.remove_meta("fade")
	if looping:
		stream = stream.duplicate()
		if stream is AudioStreamOggVorbis:
			stream.loop = true
	var group := str(entry.setting("group"))
	p.bus = group if AudioServer.get_bus_index(group) >= 0 else "Master"
	p.stream = stream
	p.volume_db = volume
	p.pitch_scale = pitch
	p.play()
	played.emit(entry, file_index, pitch, volume, p)
	return true


## Stops every shared voice; looping voices fade out as in the game.
func stop_all() -> void:
	for p in _players:
		p.stop()
	for path: String in _own_voices:
		var p: AudioStreamPlayer = _own_voices[path]
		if p.playing and not p.has_meta("fade"):
			var fade := create_tween()
			fade.tween_property(p, "volume_linear", 0.0, LOOP_FADE)
			fade.tween_callback(p.stop)
			fade.tween_callback(p.remove_meta.bind("fade"))
			p.set_meta("fade", fade)


func _new_voice() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	add_child(p)
	return p


func _own_voice(path: String) -> AudioStreamPlayer:
	if not _own_voices.has(path):
		_own_voices[path] = _new_voice()
	return _own_voices[path]
