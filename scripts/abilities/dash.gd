class_name DashAbility
extends Ability


func execute(c: Character, aim_dir: Vector2) -> void:
	var d: Dictionary = GameConfig.ability_def(id)
	var strength: float = float(c.stats.current["strength"])
	var dmg: float = strength * float(d["damage_mult"]) * GameConfig.damage_scale + float(d["flat"])

	c.start_dash(
		aim_dir,
		float(d["distance"]),
		float(d["speed"]),
		dmg,
		float(d["knockback"]),
		float(d["hit_radius"]),
		color
	)
	Fx.burst(c.global_position, color, 12, 150.0, 2.4)
	Fx.text_pop(c.global_position + Vector2(0, -c.radius - 30), "DASH", color, 13)
