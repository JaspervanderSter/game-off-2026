extends SceneTree
## Synthesises the cloud transition's soft whoosh (sound event ui/clouds) as two
## takes, sfx/ui/clouds.ogg and clouds_2.ogg: airy noise through a band-pass
## that sweeps up then down, swelling in and fading out. Seeded, so a new run
## rewrites identical files. Needs oggenc (see tools/make_map_ambience.gd).
##   godot --path . --headless --script res://tools/make_cloud_whoosh.gd
##   godot --path . --headless --import

const RATE := 22050
const SECONDS := 1.1


func _init() -> void:
	_save("clouds", _whoosh(31, 380.0, 1500.0))
	_save("clouds_2", _whoosh(47, 320.0, 1250.0))
	print("Cloud whooshes written to ", ProjectSettings.globalize_path("res://sfx/ui/"))
	quit()


func _whoosh(seed_value: int, low_hz: float, high_hz: float) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedFloat32Array()
	out.resize(int(SECONDS * RATE))
	var low := 0.0
	var band := 0.0
	var soft := [0.0, 0.0]
	var a := 1.0 - exp(-TAU * 2400.0 / RATE)
	for i in out.size():
		var k := float(i) / out.size()
		var sweep := sin(k * PI) # up, then down
		var f := 2.0 * sin(PI * lerpf(low_hz, high_hz, sweep) / RATE)
		var x := rng.randf() * 2.0 - 1.0
		var high := x - low - 0.6 * band
		band += f * high
		low += f * band
		soft[0] += (band - soft[0]) * a
		soft[1] += (soft[0] - soft[1]) * a
		# Swells in over a third, fades over the rest.
		var envelope := smoothstep(0.0, 0.35, k) * (1.0 - smoothstep(0.35, 1.0, k))
		out[i] = soft[1] * envelope
	return out


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
	var wav_path := OS.get_user_data_dir().path_join("whoosh_%s.wav" % name)
	wav.save_to_wav(wav_path)
	var target := ProjectSettings.globalize_path("res://sfx/ui/%s.ogg" % name)
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
