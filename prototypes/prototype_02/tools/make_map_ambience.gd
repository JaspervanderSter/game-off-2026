extends SceneTree
## Synthesises the journey map's nature ambience (see MapAmbience) and encodes
## it to OGG Vorbis in music/ambience/: three seamless looping beds (day wind,
## night wind, crickets) and short one-shot variants (birds, wind chimes, owl).
## Every sound is seeded, so a new run rewrites identical files. Needs oggenc
## (OGGENC, %USERPROFILE%/Tools/oggenc/oggenc2.exe, Tuning Fork's vendored copy
## or the PATH). Run from prototypes/prototype_02, then import:
##   godot --path . --headless --script res://tools/make_map_ambience.gd
##   godot --path . --headless --import

const RATE := 22050
const LOOP_SECONDS := 32.0
const CROSSFADE := 2.0 # seconds of the tail blended into the start of a loop
const OUT_DIR := "res://music/ambience/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save("wind_day", _loop(_wind(520.0, 980.0, 0.55, 0.22, 11, 1300.0)))
	_save("wind_night", _loop(_wind(240.0, 470.0, 0.8, 0.34, 23, 650.0)))
	_save("crickets", _loop(_crickets(37)))
	for i in 6:
		_save("bird_%d" % (i + 1), _echo(_bird(i, 100 + i)))
	for i in 3:
		_save("chime_%d" % (i + 1), _chime(200 + i))
	for i in 2:
		_save("owl_%d" % (i + 1), _echo(_owl(i, 300 + i)))
	print("Map ambience written to ", ProjectSettings.globalize_path(OUT_DIR))
	quit()


# --- Beds --------------------------------------------------------------------------

## Airy wind: noise through a slowly swept band-pass, over a soft rumble, with
## gusts. Every modulation completes whole cycles over LOOP_SECONDS.
func _wind(low_hz: float, high_hz: float, resonance: float, rumble_level: float, seed_value: int, soft_hz: float) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedFloat32Array()
	out.resize(int((LOOP_SECONDS + CROSSFADE) * RATE))
	var low := 0.0
	var band := 0.0
	var rumble := 0.0
	var soft := [0.0, 0.0] # two gentle low-pass stages take the hiss off the top
	var a := 1.0 - exp(-TAU * soft_hz / RATE)
	for i in out.size():
		var t := float(i) / RATE
		var u := TAU * t / LOOP_SECONDS
		var sway := 0.5 + 0.24 * sin(u * 3.0) + 0.16 * sin(u * 7.0 + 1.3) + 0.1 * sin(u * 13.0 + 2.1)
		var f := 2.0 * sin(PI * lerpf(low_hz, high_hz, sway) / RATE)
		var x := rng.randf() * 2.0 - 1.0
		var high := x - low - resonance * band
		band += f * high
		low += f * band
		rumble += (x - rumble) * 0.02
		soft[0] += (band - soft[0]) * a
		soft[1] += (soft[0] - soft[1]) * a
		out[i] = (soft[1] * 0.8 + rumble * rumble_level * 6.0) * (0.3 + 0.7 * sway * sway)
	return out


## A field of crickets: each one repeats a short group of pulses at its own
## pitch and pace, nearer ones louder.
func _crickets(seed_value: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var crickets := []
	for c in 6:
		crickets.append({"hz": rng.randf_range(4200.0, 5300.0), "period": rng.randf_range(0.45, 0.9),
			"pulses": rng.randi_range(2, 4), "amp": rng.randf_range(0.15, 0.5), "offset": rng.randf() * 2.0})
	var out := PackedFloat32Array()
	out.resize(int((LOOP_SECONDS + CROSSFADE) * RATE))
	for c: Dictionary in crickets:
		var phase := 0.0
		for i in out.size():
			var t := float(i) / RATE
			phase += TAU * c.hz * (1.0 + 0.004 * sin(t * 3.1 + c.offset)) / RATE
			var local := fmod(t + c.offset, c.period)
			var pulse := int(local / 0.042)
			var within := local - pulse * 0.042
			if pulse < c.pulses and within < 0.022:
				var swell := 0.75 + 0.25 * sin(TAU * t * 2.0 / LOOP_SECONDS + c.offset * 3.0)
				out[i] += c.amp * swell * pow(sin(PI * within / 0.022), 2.0) * sin(phase)
	return out


## Blends the tail past LOOP_SECONDS into the start (equal power), so the loop
## joins without a click.
func _loop(samples: PackedFloat32Array) -> PackedFloat32Array:
	var fade := int(CROSSFADE * RATE)
	var length := samples.size() - fade
	var out := samples.slice(0, length)
	for i in fade:
		var k := float(i) / fade
		out[i] = samples[length + i] * cos(k * PI * 0.5) + samples[i] * sin(k * PI * 0.5)
	return out


# --- One-shots -------------------------------------------------------------------

## Six bird calls: tsip-tsip, falling tweets, a trill, a two-note whistle, a
## warble and a call answered by a farther bird.
func _bird(kind: int, seed_value: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := _silence(1.6)
	match kind:
		0:
			for n in 3:
				_chirp(out, 0.05 + n * 0.11, 0.07, 3800.0, 4600.0, 0.8)
		1:
			_chirp(out, 0.05, 0.12, 4800.0, 3200.0, 0.8)
			_chirp(out, 0.21, 0.12, 4700.0, 3100.0, 0.7)
			_chirp(out, 0.42, 0.08, 3000.0, 3600.0, 0.6)
		2:
			for n in 14:
				_chirp(out, 0.05 + n * 0.045, 0.03, 3400.0, 4000.0, 0.8 * (1.0 - n / 18.0))
		3:
			_chirp(out, 0.05, 0.18, 2300.0, 2600.0, 0.8, 0.05)
			_chirp(out, 0.27, 0.24, 2900.0, 2500.0, 0.8, 0.05)
		4:
			var at := 0.05
			for n in 8:
				var a := rng.randf_range(2800.0, 4200.0)
				var b := a + (500.0 if n % 2 == 0 else -500.0)
				var length := rng.randf_range(0.05, 0.09)
				_chirp(out, at, length, a, b, 0.7)
				at += length + rng.randf_range(0.02, 0.06)
		_:
			_chirp(out, 0.05, 0.1, 4200.0, 3600.0, 0.8)
			_chirp(out, 0.18, 0.1, 4200.0, 3600.0, 0.8)
			_chirp(out, 0.62, 0.1, 4000.0, 3400.0, 0.35)
			_chirp(out, 0.75, 0.1, 4000.0, 3400.0, 0.35)
	return out


## A pitch glide shaped by a smooth bell envelope, with a little second harmonic.
func _chirp(out: PackedFloat32Array, start: float, length: float, from_hz: float, to_hz: float, amp: float, harmonic := 0.22) -> void:
	var phase := 0.0
	var first := int(start * RATE)
	for i in int(length * RATE):
		if first + i >= out.size():
			return
		var k := float(i) / (length * RATE)
		phase += TAU * lerpf(from_hz, to_hz, k) / RATE
		out[first + i] += amp * pow(sin(PI * k), 1.5) * (sin(phase) + harmonic * sin(2.0 * phase))


## Wind chimes: a few bell strikes on a high pentatonic scale, each with
## inharmonic partials that ring and fade.
func _chime(seed_value: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var scale := [1046.5, 1174.7, 1318.5, 1568.0, 1760.0]
	var partials := [[1.0, 1.0, 1.8], [2.76, 0.45, 1.0], [5.4, 0.2, 0.55]]
	var out := _silence(3.8)
	var at := 0.05
	for n in rng.randi_range(4, 6):
		var hz: float = scale[rng.randi_range(0, scale.size() - 1)]
		var amp := rng.randf_range(0.35, 0.7)
		var first := int(at * RATE)
		for i in range(first, out.size()):
			var t := float(i - first) / RATE
			var value := 0.0
			for p: Array in partials:
				if hz * p[0] < RATE * 0.45:
					value += p[1] * exp(-t / p[2]) * sin(TAU * hz * p[0] * t)
			out[i] += amp * value * minf(1.0, t / 0.002)
		at += rng.randf_range(0.15, 0.4)
	return out


## An owl: soft, slightly falling hoots with a little vibrato and breath.
func _owl(kind: int, seed_value: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := _silence(2.4)
	var hoots: Array = [[0.05, 0.34, 392.0], [0.6, 0.52, 372.0], [1.4, 0.16, 384.0], [1.62, 0.16, 380.0]] if kind == 0 \
		else [[0.05, 0.5, 360.0], [0.85, 0.18, 380.0], [1.08, 0.18, 376.0], [1.32, 0.6, 352.0]]
	for h: Array in hoots:
		var first := int(h[0] * RATE)
		var length: float = h[1]
		var phase := 0.0
		var breath := 0.0
		for i in int(length * RATE):
			var t := float(i) / RATE
			var env := minf(1.0, t / 0.06) * minf(1.0, (length - t) / 0.12)
			phase += TAU * h[2] * (1.0 - 0.07 * t / length + 0.008 * sin(TAU * 5.0 * t)) / RATE
			breath += ((rng.randf() * 2.0 - 1.0) - breath) * 0.08
			out[first + i] += env * (0.8 * sin(phase) + 0.12 * sin(2.0 * phase) + 0.12 * breath)
	return out


## A faint early reflection gives a one-shot some space.
func _echo(samples: PackedFloat32Array) -> PackedFloat32Array:
	var delay := int(0.09 * RATE)
	for i in range(samples.size() - 1, delay - 1, -1):
		samples[i] += samples[i - delay] * 0.22
	return samples


func _silence(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	return out


# --- Files -------------------------------------------------------------------------

## Peak-normalises to 0.9, writes a 16-bit mono WAV, encodes it to OGG.
func _save(name: String, samples: PackedFloat32Array) -> void:
	var peak := 0.0001
	for v in samples:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, clampi(roundi(samples[i] / peak * 0.9 * 32767.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	var wav_path := OS.get_user_data_dir().path_join("ambience_%s.wav" % name)
	wav.save_to_wav(wav_path)
	var target := ProjectSettings.globalize_path(OUT_DIR + name + ".ogg")
	var output := []
	var code := OS.execute(_oggenc(), ["-Q", "-q", "3", "-o", target, wav_path], output, true)
	DirAccess.remove_absolute(wav_path)
	if code != 0:
		push_error("oggenc failed for %s: %s" % [name, "".join(output)])


func _oggenc() -> String:
	var candidates: Array[String] = []
	if OS.get_environment("OGGENC") != "":
		candidates.append(OS.get_environment("OGGENC"))
	if OS.get_environment("USERPROFILE") != "":
		candidates.append(OS.get_environment("USERPROFILE").path_join("Tools/oggenc/oggenc2.exe"))
	candidates.append(ProjectSettings.globalize_path("res://../../tools/tuning_fork/vendor/oggenc/oggenc.exe"))
	for candidate in candidates:
		if FileAccess.file_exists(candidate):
			return candidate
	return "oggenc2"
