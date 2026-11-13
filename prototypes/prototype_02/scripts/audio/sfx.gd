extends Node
## Synthesised gameplay effects and supplied victory/defeat recordings.
## Autoloaded as Sfx; result audio has its own voice so effects cannot steal it.

const RATE := 22050
const VOICES := 10
const VOICE_DB := -8.0
const NOTE_DB := -13.0 # the song plays every second: keep it under the effects
## Bard melody in semitones above C5 (pentatonic: do re mi sol la sol mi re).
const SONG_MELODY := [0, 2, 4, 7, 9, 7, 4, 2]
## Command-line user argument (after `--`) that silences all game audio.
const NO_SOUND_ARG := "--no-sound"

## False when launched with --no-sound: nothing is synthesised or played and
## the master bus is muted (music included).
var enabled := true
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}
var _result_player: AudioStreamPlayer


func _ready() -> void:
	_result_player = AudioStreamPlayer.new()
	_result_player.volume_db = -8.0
	add_child(_result_player)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_players.append(p)
	if NO_SOUND_ARG in OS.get_cmdline_user_args():
		enabled = false
		AudioServer.set_bus_mute(0, true)
		return
	_streams.hit = _make(0.09, func(t, k): return (randf() * 2.0 - 1.0) * (1.0 - k) * 0.7 + sin(t * TAU * 120.0) * (1.0 - k) * 0.5)
	_streams.shoot = _make(0.08, func(t, k): return sin(t * TAU * lerpf(900.0, 500.0, k)) * (1.0 - k) * 0.35)
	_streams.death = _make(0.5, func(t, k): return _sweep(t, 700.0, 120.0, k) * (1.0 - k) * 0.5 + (randf() * 2.0 - 1.0) * 0.2 * (1.0 - k))
	_streams.buy = _make(0.25, func(t, k): return (sin(t * TAU * 1320.0) + sin(t * TAU * 1980.0) * 0.5) * exp(-k * 5.0) * 0.4)
	_streams.click = _make(0.05, func(t, k): return sin(t * TAU * 700.0) * (1.0 - k) * 0.4)
	_streams.difficulty_unlock = _make(0.25, _unlock_sample)
	_streams.fail = _make(0.15, func(t, k): return sign(sin(t * TAU * 140.0)) * (1.0 - k) * 0.2)
	_streams.win = preload("res://sfx/victory.wav")
	_streams.lose = preload("res://sfx/defeat.wav")
	_streams.damage = _make(0.3, func(t, k): return sin(t * TAU * lerpf(220.0, 90.0, k)) * (1.0 - k) * 0.6)
	_streams.heart_break = _make(0.20, func(t, k): return (sin(t * TAU * lerpf(180.0, 65.0, k)) * 0.65 + (randf() * 2.0 - 1.0) * exp(-k * 12.0) * 0.35) * (1.0 - k))
	_streams.coin_gain = _make(0.24, func(t, k): return (sin(t * TAU * 1568.0) + sin(t * TAU * 2352.0) * 0.35) * exp(-k * 7.0) * 0.45)
	# Peasant harvest: a springy upward blip with a bright bell on top.
	_streams.coin_pop = _make(0.16, func(t, k): return sin(t * TAU * lerpf(520.0, 1400.0, k)) * (1.0 - k) * 0.35 + sin(t * TAU * 2637.0) * exp(-k * 9.0) * 0.18)
	_streams.combine =_make(0.16, func(t, k): return sin(t * TAU * lerpf(440.0, 740.0, k)) * sin(k * PI) * 0.35)
	_streams.merge = _make(0.55, func(t, k): return (sin(t * TAU * [523.0, 659.0, 784.0][mini(2, int(k * 3))]) + sin(t * TAU * 1047.0) * 0.3) * sin(k * PI) * 0.4)
	# Shapeshift of an own creature: bright rising arpeggio (C E G C) over a shimmer.
	_streams.shift_bless = _make(0.55, func(t, k): return (sin(t * TAU * [523.25, 659.25, 783.99, 1046.5][mini(3, int(k * 5.0))]) * 0.5 + sin(t * TAU * 2093.0) * 0.12 * sin(k * PI)) * (1.0 - k) * 0.55)
	# Shapeshift of an enemy creature: a wobbling descending growl with grit.
	_streams.shift_hex = _make(0.5, func(t, k): return (_sweep(t, 420.0, 90.0, k) * (0.7 + 0.3 * sin(t * TAU * 18.0)) * 0.5 + (randf() * 2.0 - 1.0) * 0.18 * exp(-k * 3.0)) * (1.0 - k))
	_streams.note =_make(0.45, func(t, k): return (sin(t * TAU * 523.25) + sin(t * TAU * 1046.5) * 0.35 + sin(t * TAU * 1569.75) * 0.12) * exp(-k * 6.0) * 0.45)
	_streams.hop =_make(0.24, func(t, k): return sin(t * TAU * lerpf(250.0, 1100.0, k)) * sin(k * PI) * 0.3)
	# Skunk fear burst: a hissing gas puff under a wobbling, rising squeal.
	_streams.fear = _make(0.5, func(t, k): return ((randf() * 2.0 - 1.0) * 0.3 * exp(-k * 4.0) + sin(t * TAU * lerpf(500.0, 1300.0, k) + sin(t * TAU * 22.0) * 3.0) * 0.22 * sin(k * PI)) * (1.0 - k * 0.5))
	_streams.blizzard =_make(0.55, func(t, k): return ((randf() * 2.0 - 1.0) * 0.2 + sin(t * TAU * 880.0) * 0.08) * sin(k * PI))


func play(name: String, pitch_jitter := 0.08, pitch := 1.0) -> void:
	if not enabled or not _streams.has(name):
		return
	# Avoid machine-gun stacking of identical sounds in the same instant.
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(name, -1000)) < 40:
		return
	_last_played[name] = now
	if name == "win" or name == "lose":
		_result_player.stream = _streams[name]
		_result_player.pitch_scale = 1.0
		_result_player.play()
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[name]
	p.volume_db = VOICE_DB
	p.pitch_scale = pitch + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## One note of the bard's song: a plucked bell walking a pentatonic melody,
## one step per beat, so a singing bard is heard as a little tune.
func play_note(step: int) -> void:
	if not enabled or not _streams.has("note"):
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams.note
	p.volume_db = NOTE_DB
	p.pitch_scale = pow(2.0, SONG_MELODY[posmod(step, SONG_MELODY.size())] / 12.0)
	p.play()


func _sweep(t: float, f0: float, f1: float, k: float) -> float:
	# Phase of a linear chirp from f0 to f1 over the sound's duration.
	var duration := t / maxf(k, 0.0001)
	return sin(TAU * (f0 * t + (f1 - f0) * t * t / (2.0 * duration)))


func _unlock_sample(t: float, _k: float) -> float:
	var latch := (sin(TAU * 520.0 * t) * 0.48 + sin(TAU * 1630.0 * t) * 0.28
		+ randf_range(-0.24, 0.24)) * exp(-95.0 * t)
	var ring_time := maxf(t - 0.045, 0.0)
	var ring := (sin(TAU * 1318.5 * ring_time) * 0.33 + sin(TAU * 2768.9 * ring_time) * 0.15)
	return latch + ring * exp(-22.0 * ring_time) * minf(ring_time / 0.006, 1.0)


func _make(duration: float, gen: Callable) -> AudioStreamWAV:
	var n := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var k := float(i) / n
		var v: float = clampf(gen.call(t, k), -1.0, 1.0)
		# Short fade-in avoids clicks.
		v *= minf(1.0, i / 60.0)
		data.encode_s16(i * 2, int(v * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
