class_name FxNode
extends Node2D
## Effect base that always runs on real time, even during 0.05x slow motion.

var _last_usec: int = 0


func _ready() -> void:
	_last_usec = Time.get_ticks_usec()


func udelta() -> float:
	var now := Time.get_ticks_usec()
	var d := float(now - _last_usec) / 1_000_000.0
	_last_usec = now
	return clampf(d, 0.0, 0.1)
