extends Node
## Optional 20-duel comparison against the frozen old policy, with board sides
## mirrored. Both policies share current creature data, gold and spell rules.

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var legacy = load("res://tests/fixtures/legacy_enemy_ai.gd")
	var new_wins := 0
	var old_wins := 0
	var draws := 0
	var round_total := 0
	for seed_id in 10:
		for new_team in 2:
			var states: Array[WizardState] = [WizardState.new(0), WizardState.new(1)]
			var generators: Array[RandomNumberGenerator] = [RandomNumberGenerator.new(), RandomNumberGenerator.new()]
			for team in 2:
				generators[team].seed = 8100 + seed_id * 2 + (0 if team == new_team else 1)
				var pack: Dictionary = CreatureDB.PACKS[(seed_id + (0 if team == new_team else 1)) % CreatureDB.PACKS.size()]
				states[team].take_starting_pack(pack)
			var rounds := 0
			while states[0].hp > 0 and states[1].hp > 0 and rounds < 35:
				rounds += 1
				for team in 2:
					states[team].gold += Rules.income(rounds)
					states[team].refresh_offers(generators[team])
					if team == new_team:
						EnemyAI.shop(states[team], generators[team])
					else:
						legacy.shop(states[team], generators[team])
				var b := Battle.new()
				add_child(b)
				b.setup(states, 19000 + seed_id * 100 + rounds)
				b.ai_casting = [false, false]
				var timers := [0.7, 0.7]
				while not b.finished:
					b.step(1.0 / 30.0)
					for team in 2:
						timers[team] -= 1.0 / 30.0
						if timers[team] <= 0 and b.spells[team].can_cast():
							var choice: Unit = EnemyAI.choose_cast(b, team) if team == new_team else legacy.choose_cast(b, team)
							if choice != null:
								b.cast(team, choice)
							timers[team] = 0.7
				if b.result.winner >= 0:
					states[1 - b.result.winner].take_round_damage(b.result.survivors)
				b.free()
			round_total += rounds
			if states[new_team].hp <= 0:
				old_wins += 1
			elif states[1 - new_team].hp <= 0:
				new_wins += 1
			else:
				draws += 1
			print("benchmark seed=%d new_team=%d score=%d/%d/%d rounds=%d" % [seed_id, new_team, new_wins, old_wins, draws, rounds])
	print("BENCHMARK new=%d legacy=%d draws=%d average_rounds=%.2f" % [new_wins, old_wins, draws, round_total / 20.0])
	get_tree().quit()
