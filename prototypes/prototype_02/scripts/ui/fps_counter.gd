extends PanelContainer
## Hidden diagnostics: real frame intervals catch stalls hidden by smoothed FPS.

const UPDATE_SECONDS := 0.25

var _label := Label.new()
var _elapsed := 0.0
var _peak_ms := 0.0
var _previous_usec := 0


func _ready() -> void:
	position = Vector2(12, 12)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.04, 0.03, 0.06, 0.9)
	panel.content_margin_left = 10
	panel.content_margin_right = 10
	panel.content_margin_top = 6
	panel.content_margin_bottom = 6
	add_theme_stylebox_override("panel", panel)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(1.0, 0.87, 0.55))
	add_child(_label)
	visibility_changed.connect(_on_visibility_changed)
	hide()


func _on_visibility_changed() -> void:
	_elapsed = 0.0
	_peak_ms = 0.0
	_previous_usec = Time.get_ticks_usec()
	_label.text = "FPS —\nFrame — ms  |  Peak — ms"
	set_process(visible)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var frame_seconds := (now - _previous_usec) / 1000000.0
	_previous_usec = now
	var frame_ms := frame_seconds * 1000.0
	_peak_ms = maxf(_peak_ms, frame_ms)
	_elapsed += frame_seconds
	if _elapsed < UPDATE_SECONDS:
		return
	_elapsed = 0.0
	_label.text = "FPS %d\nFrame %.1f ms  |  Peak %.1f ms" % [
		Engine.get_frames_per_second(), frame_ms, _peak_ms]
