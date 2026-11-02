class_name GroundSlamAbility
extends Ability


func execute(c: Character, _aim_dir: Vector2) -> void:
	var d: Dictionary = GameConfig.ability_def(id)
	var strength: float = float(c.stats.current["strength"])
	var dmg: float = strength * float(d["damage_mult"]) * GameConfig.damage_scale + float(d["flat"])
	var radius: float = float(d["radius"])
	var weight: float = float(c.stats.current["weight"])

	Fx.ring(c.global_position, color, c.radius * 0.9, radius, 0.5, 4.5)
	Fx.ring(c.global_position, color.lightened(0.35), 12.0, radius * 0.68, 0.34, 2.0)
	Fx.burst(c.global_position, color, 30, 230.0, 3.2)
	Fx.shake(15.0)

	for o in c.get_living_opponents():
		if c.global_position.distance_to(o.global_position) <= radius + o.radius:
			o.take_damage(dmg, c.global_position, float(d["knockback"]), weight, c)
			o.stun(float(d["stun"]))

	Fx.text_pop(c.global_position + Vector2(0, -c.radius - 36), "SLAM", color, 15)
