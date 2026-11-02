class_name ShieldAbility
extends Ability


func execute(c: Character, _aim_dir: Vector2) -> void:
	var d: Dictionary = GameConfig.ability_def(id)
	var amount: float = float(d["amount_base"]) + float(c.stats.current["weight"]) * float(d["amount_weight"])
	c.add_shield(amount, float(d["duration"]))
	Fx.ring(c.global_position, color, c.radius + 2.0, c.radius + 30.0, 0.4, 3.0)
	Fx.ring(c.global_position, color.lightened(0.4), 6.0, c.radius + 12.0, 0.28, 2.0)
	Fx.burst(c.global_position, color, 16, 120.0, 2.0)
	Fx.text_pop(c.global_position + Vector2(0, -c.radius - 30), "SHIELD", color, 13)
