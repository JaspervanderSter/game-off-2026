class_name WaveCard
extends PanelContainer
## One file of a sound: its waveform, name and length, with buttons to play
## that file and to remove it. Shows a playhead while it plays.

signal play_requested(index: int)
signal remove_requested(index: int)

const WAVE := Color(0.37, 0.70, 0.85)
const ACCENT := Color(0.98, 0.72, 0.30)
const BACKGROUND := Color("16181d")
## Peaks (min, max per column) of each stream already measured, by instance id.
static var _peaks_cache := {}

var index := 0
var stream: AudioStream
var _view: Control
var _voice: AudioStreamPlayer
var _voice_pitch := 1.0
var _style: StyleBoxFlat


func setup(file_index: int, path: String, file_stream: AudioStream) -> void:
	index = file_index
	stream = file_stream
	custom_minimum_size = Vector2(250, 0)
	_style = StyleBoxFlat.new()
	_style.bg_color = Color("23272f")
	_style.set_corner_radius_all(6)
	_style.set_border_width_all(2)
	_style.border_color = Color(1, 1, 1, 0.08)
	_style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", _style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	_view = Control.new()
	_view.custom_minimum_size = Vector2(234, 70)
	_view.draw.connect(_draw_wave)
	_view.mouse_filter = MOUSE_FILTER_STOP
	_view.tooltip_text = "Click to play this file"
	_view.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			play_requested.emit(index))
	column.add_child(_view)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	column.add_child(row)
	var play := Button.new()
	play.icon = Icons.get_icon("play", ACCENT, 16)
	play.flat = true
	play.focus_mode = FOCUS_NONE
	play.tooltip_text = "Play this file"
	play.pressed.connect(func() -> void: play_requested.emit(index))
	row.add_child(play)
	var label := Label.new()
	label.text = path.get_file()
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.tooltip_text = path
	label.mouse_filter = MOUSE_FILTER_PASS
	row.add_child(label)
	var length := Label.new()
	length.text = "%.2f s" % stream.get_length() if stream != null else "—"
	length.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	length.add_theme_font_size_override("font_size", 13)
	row.add_child(length)
	var remove := Button.new()
	remove.icon = Icons.get_icon("trash", Color(1, 1, 1, 0.7), 16)
	remove.flat = true
	remove.focus_mode = FOCUS_NONE
	remove.tooltip_text = "Move this file to the recycle bin"
	remove.pressed.connect(func() -> void: remove_requested.emit(index))
	row.add_child(remove)


## Marks this file as the one that played last, with a playhead on `voice`.
func show_play(voice: AudioStreamPlayer, pitch: float) -> void:
	_voice = voice
	_voice_pitch = pitch
	_style.border_color = ACCENT
	set_process(true)


func clear_play() -> void:
	_voice = null
	_style.border_color = Color(1, 1, 1, 0.08)
	_view.queue_redraw()


func _process(_dt: float) -> void:
	_view.queue_redraw()
	if _voice == null or not _voice.playing or _voice.stream != stream:
		_voice = null
		set_process(false)


func _draw_wave() -> void:
	var rect := Rect2(Vector2.ZERO, _view.size)
	_view.draw_rect(rect, BACKGROUND)
	var mid := rect.size.y * 0.5
	_view.draw_line(Vector2(0, mid), Vector2(rect.size.x, mid), Color(1, 1, 1, 0.12), 1.0)
	if stream == null:
		return
	var columns := int(rect.size.x)
	var peaks := peaks_of(stream, columns)
	for x in columns:
		var low := peaks[x * 2]
		var high := peaks[x * 2 + 1]
		_view.draw_line(Vector2(x + 0.5, mid - high * mid * 0.95), Vector2(x + 0.5, mid - low * mid * 0.95 + 1.0), WAVE, 1.0)
	if _voice != null and _voice.playing and _voice.stream == stream and stream.get_length() > 0.0:
		var x := clampf(_voice.get_playback_position() / stream.get_length(), 0.0, 1.0) * rect.size.x
		_view.draw_line(Vector2(x, 0), Vector2(x, rect.size.y), ACCENT, 2.0)


## The lowest and highest sample of each of `columns` slices of `audio`, as
## [min0, max0, min1, max1...] in -1..1, decoded once per stream.
static func peaks_of(audio: AudioStream, columns: int) -> PackedFloat32Array:
	var key := "%d/%d" % [audio.get_instance_id(), columns]
	if _peaks_cache.has(key):
		return _peaks_cache[key]
	var peaks := PackedFloat32Array()
	peaks.resize(columns * 2)
	var mix_rate := AudioServer.get_mix_rate()
	# Long files are decoded faster than real speed: enough samples for a picture.
	var speed := maxf(1.0, audio.get_length() * mix_rate / 120000.0)
	var total := maxf(1.0, audio.get_length() * mix_rate / speed)
	var playback := audio.instantiate_playback()
	playback.start(0.0)
	var frame := 0
	while playback.is_playing() and frame < total * 1.05:
		var chunk: PackedVector2Array = playback.mix_audio(speed, 4096)
		if chunk.is_empty():
			break
		for sample in chunk:
			var column := mini(int(frame / total * columns), columns - 1)
			var value := (sample.x + sample.y) * 0.5
			peaks[column * 2] = minf(peaks[column * 2], value)
			peaks[column * 2 + 1] = maxf(peaks[column * 2 + 1], value)
			frame += 1
	playback.stop()
	_peaks_cache[key] = peaks
	return peaks
