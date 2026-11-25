class_name MusicVoice
extends AudioStreamPlayer
## A tunable track, shared verbatim with the tool's preview.
var settings := {}
var weight := 0.0
var target := 0.0
var keep_clock := false
var segment := Vector2.ZERO
var last_segment := -1
var loaded_signature := ""

func setting(key: String) -> Variant:
	return settings.get(key, MusicCatalog.DEFAULTS[key])

func configure(entry: Dictionary) -> bool:
	if entry.is_empty() or entry.get("error", "") != "" or not (FileAccess.file_exists(entry.audio) or ResourceLoader.exists(entry.audio)):
		return false
	var fingerprint: String = entry.audio if entry.audio.begins_with("res://") else FileAccess.get_sha256(entry.audio)
	var changed := fingerprint != loaded_signature
	var next: AudioStream = stream
	if changed:
		next = MusicCatalog.stream_from(entry.audio)
		if next == null:
			return false
	var data: Dictionary = entry.data
	for part in data.get("segments", []):
		if float(part.end_seconds) > next.get_length() + 0.02:
			return false
	var position := get_playback_position()
	var was_playing := playing
	var old_mode := str(setting("playback_mode"))
	settings = data.duplicate(true)
	if changed:
		stream = next
		loaded_signature = fingerprint
	if stream is AudioStreamOggVorbis:
		stream.loop = bool(setting("loop")) and str(setting("playback_mode")) != "segments"
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if bool(setting("loop")) and str(setting("playback_mode")) != "segments" else AudioStreamWAV.LOOP_DISABLED
	if was_playing and changed:
		play(fposmod(position, maxf(stream.get_length(), 0.01)))
	if was_playing and (old_mode != str(setting("playback_mode")) or str(setting("playback_mode")) == "segments"):
		start(true)
	return true

func start(reenter := false, offset := -1.0) -> void:
	if stream == null:
		return
	var mode := str(setting("playback_mode"))
	if mode == "segments" and (reenter or not playing):
		var choices: Array = setting("segments")
		if choices.is_empty():
			return
		var index := randi_range(0, choices.size() - 1)
		if choices.size() > 1 and index == last_segment:
			index = (index + 1) % choices.size()
		last_segment = index
		segment = Vector2(float(choices[index].start_seconds), float(choices[index].end_seconds))
		play(segment.x)
	elif offset >= 0.0:
		play(fposmod(offset, maxf(stream.get_length(), 0.01)))
	elif not playing or (reenter and mode == "restart"):
		play()

func advance(dt: float) -> void:
	weight = move_toward(weight, target, dt / maxf(0.01, float(setting("fade_seconds"))))
	volume_linear = weight * db_to_linear(float(setting("volume_db")))
	if playing and str(setting("playback_mode")) == "segments" and get_playback_position() >= segment.y:
		if bool(setting("loop")):
			seek(segment.x)
		else:
			stop()
	if weight == 0.0 and target == 0.0 and not keep_clock:
		stop()
