extends Node
## Central authority for `Engine.time_scale`. Handles both the tactical hold used
## while SHIFT targeting is open and the dramatic confirmation sequence.
## A watchdog always restores normal speed.

signal time_scale_changed(scale: float)

var _generation: int = 0
var _sequence_until_ms: int = 0
var _sequence_active: bool = false
var _hold_active: bool = false
var _hold_scale: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


func set_hold(scale: float) -> void:
	_hold_active = true
	_hold_scale = clampf(scale, 0.01, 1.0)
	if not _sequence_active:
		Engine.time_scale = _hold_scale
		time_scale_changed.emit(Engine.time_scale)


func clear_hold() -> void:
	_hold_active = false
	_hold_scale = 1.0
	if not _sequence_active:
		Engine.time_scale = 1.0
		time_scale_changed.emit(1.0)


func run_focus(scale: float, duration: float, apply_at: float, callback: Callable) -> void:
	_generation += 1
	var gen := _generation
	_sequence_active = true
	Engine.time_scale = maxf(0.01, scale)
	_sequence_until_ms = Time.get_ticks_msec() + int(duration * 1000.0) + 400
	time_scale_changed.emit(Engine.time_scale)

	var apply_delay := clampf(apply_at, 0.0, duration)
	if apply_delay > 0.0:
		await get_tree().create_timer(apply_delay, true, false, true).timeout
	if gen != _generation:
		return
	if callback.is_valid():
		callback.call()
	var remaining := duration - apply_delay
	if remaining > 0.0:
		await get_tree().create_timer(remaining, true, false, true).timeout
	if gen == _generation:
		_end()


func _end() -> void:
	_sequence_active = false
	_sequence_until_ms = 0
	Engine.time_scale = _hold_scale if _hold_active else 1.0
	time_scale_changed.emit(Engine.time_scale)


func reset() -> void:
	_generation += 1
	_hold_active = false
	_hold_scale = 1.0
	_sequence_active = false
	_end()


func is_slowed() -> bool:
	return Engine.time_scale < 0.999


func _process(_delta: float) -> void:
	if not _sequence_active:
		return
	if _sequence_until_ms > 0 and Time.get_ticks_msec() > _sequence_until_ms:
		_end()
