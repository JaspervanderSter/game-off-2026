class_name EnemyAI
extends BaseAI


func setup_enemy(c: Character, combat_ref: CombatManager) -> void:
	setup(c, combat_ref, false, null)
