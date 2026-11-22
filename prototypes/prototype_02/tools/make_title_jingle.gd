extends SceneTree
## Synthesises the title's jingle (sound event ui/title), played as the title
## island bursts out of the clouds: a rising whoosh, a marimba chord with a
## low thump on the landing (0.45 s in), a three-note tag and a bell, a few
## sparkles, a little reverb. Seeded, so a new run rewrites identical files.
## Writes default/sfx/ui/title.ogg and its custom/ copy. Needs oggenc (see
## tools/make_map_ambience.gd).
##   godot --path . --headless --script res://tools/make_title_jingle.gd
##   godot --path . --headless --import

const RATE := 32000
const SECONDS := 3.0
const D3 := 146.83
const A3 := 220.0
const D4 := 293.66
const FS4 := 369.99
const A4 := 440.0
const D5 := 587.33
const FS5 := 739.99
const A5 := 880.0
const D6 := 1174.66


func _init() -> void:
	var out := PackedFloat32Array()
	out.resize(int(SECONDS * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_whoosh(out, rng, 0.0, 0.5, 0.35)
	_thump(out, 0.45, 0.9)
	for f in [D3, A3, D4, FS4]:
		_marimba(out, 0.45, f, 0.32)
	_bell(out, 0.45, A5, 0.14, 1.8)
	for i in 3:
		_marimba(out, 0.74 + i * 0.12, [FS4, A4, D5][i], 0.34)
	_bell(out, 0.98, D6, 0.12, 1.4)
	_bell(out, 0.98, FS5, 0.1, 1.6)
	for i in 10:
		var notes := [D6, A5 * 2.0, FS5 * 2.0, D6 * 2.0]
		_bell(out, 1.0 + i * 0.1 + rng.randf_range(0.0, 0.06), notes[rng.randi() % notes.size()], 0.035 * (1.0 - i * 0.06), 3.0)
	_reverb(out, 0.22)
	for folder in ["default", "custom"]:
		_save(out, ProjectSettings.globalize_path("res://%s/sfx/ui/title.ogg" % folder))
	print("Title jingle written to default/ and custom/sfx/ui/title.ogg")
	quit()


static func _tone(out: PackedFloat32Array, at: float, f: float, amp: float, decay: float, partials: Array, attack := 0.003) -> void:
	var start := int(at * RATE)
	var length := mini(int(6.0 / decay * RATE), out.size() - start)
	for i in length:
		var tt := float(i) / RATE
		var s := 0.0
		for p: Array in partials:
			s += p[1] * sin(TAU * f * p[0] * tt) * exp(-tt * decay * (0.6 + 0.4 * p[0]))
		out[start + i] += s * amp * minf(1.0, tt / attack)


static func _bell(out: PackedFloat32Array, at: float, f: float, amp: float, decay: float) -> void:
	_tone(out, at, f, amp, decay, [[1.0, 1.0], [2.0, 0.3], [2.76, 0.25], [5.4, 0.1]])


static func _marimba(out: PackedFloat32Array, at: float, f: float, amp: float) -> void:
	_tone(out, at, f, amp, 4.5, [[1.0, 1.0], [3.93, 0.28], [9.2, 0.06]], 0.002)


## A low sine dropping in pitch: the weight of the landing.
static func _thump(out: PackedFloat32Array, at: float, amp: float) -> void:
	var start := int(at * RATE)
	var phase := 0.0
	for i in mini(int(0.5 * RATE), out.size() - start):
		var tt := float(i) / RATE
		phase += TAU * (42.0 + 120.0 * exp(-tt * 28.0)) / RATE
		out[start + i] += sin(phase) * exp(-tt * 9.0) * amp * minf(1.0, tt / 0.002)


## Noise through a low-pass opening from 300 to 3200 Hz, swelling up to the
## landing and cut short after it.
static func _whoosh(out: PackedFloat32Array, rng: RandomNumberGenerator, at: float, length_s: float, amp: float) -> void:
	var start := int(at * RATE)
	var length := mini(int((length_s + 0.06) * RATE), out.size() - start)
	var low := 0.0
	for i in length:
		var k := float(i) / (length_s * RATE)
		var cutoff := lerpf(300.0, 3200.0, minf(k, 1.0))
		low += (rng.randf_range(-1.0, 1.0) - low) * (1.0 - exp(-TAU * cutoff / RATE))
		var env := pow(minf(k / 0.92, 1.0), 2.0)
		if k > 1.0:
			env *= exp(-(k - 1.0) * length_s / 0.06 * 4.0)
		out[start + i] += low * env * amp * 2.0


## A small Schroeder reverb: four damped combs in parallel, two all-passes.
static func _reverb(out: PackedFloat32Array, wet: float) -> void:
	var sum := PackedFloat32Array()
	sum.resize(out.size())
	for delay: int in [810, 862, 927, 984]:
		var buf := PackedFloat32Array()
		buf.resize(delay)
		var index := 0
		var damp := 0.0
		for i in out.size():
			var y := buf[index]
			damp = y * 0.7 + damp * 0.3
			buf[index] = out[i] + damp * 0.8
			index = (index + 1) % delay
			sum[i] += y * 0.25
	for delay: int in [403, 320]:
		var buf := PackedFloat32Array()
		buf.resize(delay)
		var index := 0
		for i in sum.size():
			var y := buf[index]
			var x := sum[i]
			buf[index] = x + y * 0.5
			sum[i] = y - x * 0.5
			index = (index + 1) % delay
	for i in out.size():
		out[i] += sum[i] * wet


func _save(samples: PackedFloat32Array, target: String) -> void:
	var peak := 0.0001
	for v in samples:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	var fade := int(0.2 * RATE)
	for i in samples.size():
		var s := samples[i] / peak * 0.9 * minf(1.0, float(samples.size() - i) / fade)
		data.encode_s16(i * 2, clampi(roundi(s * 32767.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	var wav_path := OS.get_user_data_dir().path_join("title_jingle.wav")
	wav.save_to_wav(wav_path)
	var output := []
	var code := OS.execute(_oggenc(), ["-Q", "-q", "4", "-o", target, wav_path], output, true)
	DirAccess.remove_absolute(wav_path)
	if code != 0:
		push_error("oggenc failed for %s: %s" % [target, "".join(output)])


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
	return "oggenc"
