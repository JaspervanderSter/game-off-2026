class_name MultishotAbility
extends Ability


func execute(c: Character, aim_dir: Vector2) -> void:
	var d: Dictionary = GameConfig.ability_def(id)
	var count: int = int(d["count"])
	var spread: float = deg_to_rad(float(d["spread"]))
	var strength: float = float(c.stats.current["strength"])
	var dmg: float = strength * float(d["damage_mult"]) * GameConfig.damage_scale + float(d["flat"])
	var base_angle: float = aim_dir.angle()
	var kb: float = float(d["knockback"])
	var speed: float = float(d["projectile_speed"])

	for i in range(count):
		var t: float = 0.0 if count <= 1 else (float(i) / float(count - 1) - 0.5)
		var angle: float = base_angle + t * spread
		c.spawn_projectile(Vector2.from_angle(angle), dmg, kb, color, speed, c.radius * 0.7 + 2.0)

	Fx.burst(c.global_position + aim_dir * c.radius, color, 14, 150.0, 2.0)
	Fx.shake(2.0)
	Fx.text_pop(c.global_position + Vector2(0, -c.radius - 30), "VOLLEY", color, 13)
