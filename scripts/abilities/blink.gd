class_name BlinkAbility
extends Ability


func execute(c: Character, aim_dir: Vector2) -> void:
	var d: Dictionary = GameConfig.ability_def(id)
	var start: Vector2 = c.global_position
	var radius: float = float(d["radius"])
	var strength: float = float(c.stats.current["strength"])
	var dmg: float = strength * float(d["damage_mult"]) * GameConfig.damage_scale + float(d["flat"])
	var weight: float = float(c.stats.current["weight"])

	Fx.ring(start, color, 10.0, radius, 0.42, 3.5)
	Fx.ring(start, color.lightened(0.4), 6.0, radius * 0.6, 0.3, 2.0)
	Fx.burst(start, color, 26, 210.0, 3.0)
	Fx.shake(7.0)

	c.blink(aim_dir, float(d["distance"]))

	for o in c.get_living_opponents():
		if start.distance_to(o.global_position) <= radius + o.radius:
			o.take_damage(dmg, start, float(d["knockback"]), weight, c)

	Fx.ring(c.global_position, color, 8.0, 40.0, 0.3, 2.0)
	Fx.burst(c.global_position, color.lightened(0.3), 10, 100.0, 2.0)
	Fx.text_pop(start + Vector2(0, -c.radius - 30), "BLINK", color, 13)
