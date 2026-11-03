extends CanvasLayer
## World-space FX layer that renders above the arena but below the UI.

signal shake_requested(amount: float)

const FloatingTextScript = preload("res://scripts/fx/floating_text.gd")
const ParticleBurstScript = preload("res://scripts/fx/particle_burst.gd")
const ShockwaveScript = preload("res://scripts/fx/shockwave.gd")
const TrailDotScript = preload("res://scripts/fx/trail_dot.gd")
const SwapEffectScript = preload("res://scripts/fx/swap_effect.gd")


func _ready() -> void:
	layer = 5
	follow_viewport_enabled = true
	follow_viewport_scale = 1.0
	process_mode = Node.PROCESS_MODE_ALWAYS


func reset() -> void:
	for c in get_children():
		c.queue_free()
	shake_requested.emit(0.0)


func shake(amount: float) -> void:
	shake_requested.emit(amount)


func text_pop(pos: Vector2, text: String, color: Color, size: int = 14, life: float = 0.9, rise: float = 46.0) -> void:
	var n := FloatingTextScript.new()
	add_child(n)
	n.global_position = pos
	n.setup(text, color, size, life, rise)


func damage_number(pos: Vector2, amount: float, color: Color) -> void:
	text_pop(pos, str(int(round(amount))), color, 16, 0.8, 54.0)


func burst(pos: Vector2, color: Color, count: int = 14, speed: float = 160.0, size: float = 2.5) -> void:
	var n := ParticleBurstScript.new()
	add_child(n)
	n.global_position = pos
	n.setup(color, count, speed, size)


func ring(pos: Vector2, color: Color, start_radius: float, end_radius: float, duration: float, width: float = 3.0) -> void:
	var n := ShockwaveScript.new()
	add_child(n)
	n.global_position = pos
	n.setup(color, start_radius, end_radius, duration, width)


func trail_dot(pos: Vector2, color: Color, size: float = 3.0) -> void:
	var n := TrailDotScript.new()
	add_child(n)
	n.global_position = pos
	n.setup(color, size)


func play_swap(a: Character, b: Character, attr: String, duration: float) -> void:
	var n := SwapEffectScript.new()
	add_child(n)
	n.global_position = Vector2.ZERO
	n.setup(a, b, attr, duration)
