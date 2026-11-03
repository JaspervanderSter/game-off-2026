extends Node
## Synthesised sound effects (no audio files). Autoloaded as Sfx.

const RATE := 22050
const VOICES := 10

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_players.append(p)
	_streams.shift = _make(0.45, func(t, k): return _sweep(t, 300.0, 1400.0, k) * 0.5 + sin(t * TAU * 2400.0 * (1.0 + k)) * 0.15 * (1.0 - k))
	_streams.hit = _make(0.09, func(t, k): return (randf() * 2.0 - 1.0) * (1.0 - k) * 0.7 + sin(t * TAU * 120.0) * (1.0 - k) * 0.5)
	_streams.shoot = _make(0.08, func(t, k): return sin(t * TAU * lerpf(900.0, 500.0, k)) * (1.0 - k) * 0.35)
	_streams.death = _make(0.5, func(t, k): return _sweep(t, 700.0, 120.0, k) * (1.0 - k) * 0.5 + (randf() * 2.0 - 1.0) * 0.2 * (1.0 - k))
	_streams.buy = _make(0.25, func(t, k): return (sin(t * TAU * 1320.0) + sin(t * TAU * 1980.0) * 0.5) * exp(-k * 5.0) * 0.4)
	_streams.click = _make(0.05, func(t, k): return sin(t * TAU * 700.0) * (1.0 - k) * 0.4)
	_streams.fail = _make(0.15, func(t, k): return sign(sin(t * TAU * 140.0)) * (1.0 - k) * 0.2)
	_streams.win = _make(0.7, func(t, k): return sin(t * TAU * [523.0, 659.0, 784.0, 1047.0][mini(3, int(k * 4.0))]) * 0.35 * (1.0 - k * 0.5))
	_streams.lose = _make(0.7, func(t, k): return sin(t * TAU * [392.0, 330.0, 262.0, 196.0][mini(3, int(k * 4.0))]) * 0.35 * (1.0 - k * 0.5))
	_streams.damage = _make(0.3, func(t, k): return sin(t * TAU * lerpf(220.0, 90.0, k)) * (1.0 - k) * 0.6)


func play(name: String, pitch_jitter := 0.08) -> void:
	if not _streams.has(name):
		return
	# Avoid machine-gun stacking of identical sounds in the same instant.
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(name, -1000)) < 40:
		return
	_last_played[name] = now
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
