class_name AllyAI
extends BaseAI


func setup_ally(c: Character, combat_ref: CombatManager, p_ref: Character) -> void:
	setup(c, combat_ref, true, p_ref)
