extends Node
## Plays a batch of seeded matches using the live shop and combat AI.

const STEP := 1.0 / 60.0
const ROUND_CAP := 35


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3 or args[0] != "--no-sound":
		push_error("Expected --no-sound, a jobs file and a results file.")
		get_tree().quit(1)
		return
	var jobs = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var output := FileAccess.open(args[2], FileAccess.WRITE)
	if not jobs is Array or output == null:
		push_error("Could not open self-play jobs or results.")
		get_tree().quit(1)
		return
	for job in jobs:
		var profiles: Array[Dictionary] = [
			EnemyAI.BASE_PROFILE.merged(job.a, true),
			EnemyAI.BASE_PROFILE.merged(job.b, true),
		]
		for side in 2:
			var result := _duel(profiles, int(job.seed), side)
			result.id = job.id
			result.side = side
			output.store_line(JSON.stringify(result))
			output.flush()
			await get_tree().process_frame
	output.close()
	get_tree().quit()


func _duel(profiles: Array[Dictionary], seed_id: int, first_side: int) -> Dictionary:
	var states: Array[WizardState] = [WizardState.new(0), WizardState.new(1)]
	var shops: Array[RandomNumberGenerator] = [RandomNumberGenerator.new(), RandomNumberGenerator.new()]
	var combat_rng := RandomNumberGenerator.new()
	combat_rng.seed = seed_id * 3 + 2
	for team in 2:
		var policy := team ^ first_side
		shops[team].seed = seed_id * 3 + policy
		states[team].take_starting_pack(EnemyAI.choose_pack(shops[team]))
	for round_index in ROUND_CAP:
		for team in 2:
			var state := states[team]
			state.gold += Rules.income(round_index + 1)
			state.refresh_offers(shops[team])
			EnemyAI.shop(state, shops[team], profiles[team ^ first_side])
		var battle := Battle.new()
		add_child(battle)
		battle.ai_profiles = [profiles[first_side], profiles[1 ^ first_side]]
		battle.ai_casting = [true, true]
		battle.setup(states, combat_rng.randi())
		while not battle.finished:
			battle.step(STEP)
		var winner: int = battle.result.winner
		if winner >= 0:
			states[1 - winner].take_round_damage(battle.result.survivors)
		battle.free()
		if winner >= 0 and states[1 - winner].hp <= 0:
			return {"winner": winner ^ first_side, "rounds": round_index + 1}
	return {"winner": -1, "rounds": ROUND_CAP}
