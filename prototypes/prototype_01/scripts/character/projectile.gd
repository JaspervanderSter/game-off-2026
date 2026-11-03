class_name Projectile
extends Node2D

var owner_char: Character
var team: int = 0
var damage: float = 0.0
var knockback: float = 0.0
var source_weight: float = 1.0
var color: Color = Color.WHITE
var speed: float = 600.0
var p_radius: float = 6.0
var direction: Vector2 = Vector2.RIGHT
var lifetime: float = 2.2
var trail: Array = []
var dead: bool = false


func setup(p_owner: Character, p_team: int, dmg: float, kb: float, weight: float, col: Color, spd: float, radius_p: float) -> void:
	owner_char = p_owner
	team = p_team
	damage = dmg
	knockback = kb
	source_weight = weight
	color = col
	speed = spd
	p_radius = radius_p


func _ready() -> void:
	z_index = 4
	queue_redraw()


func _physics_process(delta: float) -> void:
	if dead:
		return
	lifetime -= delta
	if lifetime <= 0.0:
		_expire()
		return
	global_position += direction * speed * delta
	trail.push_front(global_position)
	if trail.size() > 9:
		trail.pop_back()

	for o in _opponents():
		if global_position.distance_to(o.global_position) <= p_radius + o.radius:
			o.take_damage(damage, global_position - direction * 14.0, knockback, source_weight, owner_char)
			Fx.burst(global_position, color, 9, 130.0, 2.0)
			Fx.ring(global_position, color, p_radius, p_radius + 22.0, 0.22, 1.5)
			_expire()
			return

	if not GameConfig.arena_rect.grow(50.0).has_point(global_position):
		_expire()
		return
	queue_redraw()


func _opponents() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("characters"):
		if n is Character and n.alive and n.team != team and n != owner_char:
			out.append(n)
	return out


func _expire() -> void:
	dead = true
	queue_free()


func _draw() -> void:
	for i in range(trail.size()):
		var p: Vector2 = trail[i] - global_position
		var a := (1.0 - float(i) / float(maxi(1, trail.size()))) * 0.35
		draw_circle(p, p_radius * (1.0 - float(i) * 0.06), Color(color, a))
	draw_circle(Vector2.ZERO, p_radius * 2.3, Color(color, 0.16))
	draw_circle(Vector2.ZERO, p_radius * 1.25, Color(color, 0.8))
	draw_circle(Vector2.ZERO, p_radius * 0.55, Color(1, 1, 1, 0.95))
	draw_line(-direction * 22.0, Vector2.ZERO, Color(color, 0.35), 2.0, true)
