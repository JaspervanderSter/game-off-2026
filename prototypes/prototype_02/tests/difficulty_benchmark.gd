extends Node
## Optional difficulty calibration: AI duels of one easier level against the
## Archmage, alternating board sides. Both wizards use the real live casting loop
## (Battle._ai_cast with each level's delays, thresholds and blunders).
##   godot --headless --path . res://tests/difficulty_benchmark.tscn -- --level=0 --duels=40 --seed=1
## Calibration: add --set=key=value to override a profile key of the tested level.
## Prints one RESULT line: level, challenger wins, archmage wins, unfinished duels,
## average rounds, and the Archmage's average remaining hearts in the duels it wins.

const STEP := 1.0 / 30.0
const MAX_ROUNDS := 40


func _ready() -> void:
	call_deferred("run")


func run() -> void:
	var level := Difficulty.APPRENTICE
	var duels := 20
	var seed_base := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			level = int(arg.trim_prefix("--level="))
		elif arg.begins_with("--duels="):
			duels = int(arg.trim_prefix("--duels="))
		elif arg.begins_with("--seed="):
			seed_base = int(arg.trim_prefix("--seed="))
	# --set=key=value overrides one profile key of the tested level (str_to_var syntax,
	# e.g. --set=blunder=0.2 or --set=cast_delay=Vector2(2,3)).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--set="):
			var pair := arg.trim_prefix("--set=").split("=", true, 1)
			Difficulty.overrides[level][pair[0]] = str_to_var(pair[1])
	var wins := 0
	var losses := 0
	var unfinished := 0
	var round_total := 0
	var archmage_hp_left := 0.0
	for duel in duels:
		var challenger := duel % 2
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_base * 100003 + duel
		var states: Array[WizardState] = [WizardState.new(0), WizardState.new(1)]
		states[challenger].ai_level = level
		for s in states:
			for id in EnemyAI.choose_pack(rng, CreatureDB.PACKS):
				s.add_creature(id)
		var rounds := 0
		while states[0].hp > 0 and states[1].hp > 0 and rounds < MAX_ROUNDS:
			rounds += 1
			for s in states:
				s.gold += Rules.income(rounds)
				s.refresh_offers(rng)
				EnemyAI.shop(s, rng)
			var b := Battle.new()
			add_child(b)
			b.ai_casting = [true, true]
			b.setup(states, rng.randi())
			while not b.finished:
				b.step(STEP)
			if b.result.winner >= 0:
				states[1 - b.result.winner].take_round_damage(b.result.survivors)
			b.free()
		round_total += rounds
		if states[1 - challenger].hp <= 0:
			wins += 1
		elif states[challenger].hp <= 0:
			losses += 1
			archmage_hp_left += states[1 - challenger].hp
		else:
			unfinished += 1
	print("RESULT level=%d wins=%d losses=%d unfinished=%d rounds=%.2f archmage_hp_when_winning=%.2f" % [
		level, wins, losses, unfinished, float(round_total) / duels, archmage_hp_left / maxf(1.0, losses)])
	get_tree().quit()
