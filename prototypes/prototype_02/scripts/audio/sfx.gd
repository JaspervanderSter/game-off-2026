extends Node
## Synthesised gameplay effects and supplied victory/defeat recordings.
## Autoloaded as Sfx; result audio has its own voice so effects cannot steal it.

const RATE := 22050
const VOICES := 10
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
	_streams.shift = _make(0.45, func(t, k): return _sweep(t, 300.0, 1400.0, k) * 0.5 + sin(t * TAU * 2400.0 * (1.0 + k)) * 0.15 * (1.0 - k))
	_streams.hit = _make(0.09, func(t, k): return (randf() * 2.0 - 1.0) * (1.0 - k) * 0.7 + sin(t * TAU * 120.0) * (1.0 - k) * 0.5)
	_streams.shoot = _make(0.08, func(t, k): return sin(t * TAU * lerpf(900.0, 500.0, k)) * (1.0 - k) * 0.35)
	_streams.death = _make(0.5, func(t, k): return _sweep(t, 700.0, 120.0, k) * (1.0 - k) * 0.5 + (randf() * 2.0 - 1.0) * 0.2 * (1.0 - k))
	_streams.buy = _make(0.25, func(t, k): return (sin(t * TAU * 1320.0) + sin(t * TAU * 1980.0) * 0.5) * exp(-k * 5.0) * 0.4)
	_streams.click = _make(0.05, func(t, k): return sin(t * TAU * 700.0) * (1.0 - k) * 0.4)
	_streams.fail = _make(0.15, func(t, k): return sign(sin(t * TAU * 140.0)) * (1.0 - k) * 0.2)
	_streams.win = preload("res://sfx/victory.wav")
	_streams.lose = preload("res://sfx/defeat.wav")
	_streams.damage = _make(0.3, func(t, k): return sin(t * TAU * lerpf(220.0, 90.0, k)) * (1.0 - k) * 0.6)
	_streams.heart_break = _make(0.20, func(t, k): return (sin(t * TAU * lerpf(180.0, 65.0, k)) * 0.65 + (randf() * 2.0 - 1.0) * exp(-k * 12.0) * 0.35) * (1.0 - k))
	_streams.coin_gain = _make(0.24, func(t, k): return (sin(t * TAU * 1568.0) + sin(t * TAU * 2352.0) * 0.35) * exp(-k * 7.0) * 0.45)
	_streams.combine = _make(0.16, func(t, k): return sin(t * TAU * lerpf(440.0, 740.0, k)) * sin(k * PI) * 0.35)
	_streams.merge = _make(0.55, func(t, k): return (sin(t * TAU * [523.0, 659.0, 784.0][mini(2, int(k * 3))]) + sin(t * TAU * 1047.0) * 0.3) * sin(k * PI) * 0.4)
	_streams.hop = _make(0.24, func(t, k): return sin(t * TAU * lerpf(250.0, 1100.0, k)) * sin(k * PI) * 0.3)
	_streams.blizzard = _make(0.55, func(t, k): return ((randf() * 2.0 - 1.0) * 0.2 + sin(t * TAU * 880.0) * 0.08) * sin(k * PI))


func play(name: String, pitch_jitter := 0.08) -> void:
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
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func _sweep(t: float, f0: float, f1: float, k: float) -> float:
	# Phase of a linear chirp from f0 to f1 over the sound's duration.
	var duration := t / maxf(k, 0.0001)
	return sin(TAU * (f0 * t + (f1 - f0) * t * t / (2.0 * duration)))


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
