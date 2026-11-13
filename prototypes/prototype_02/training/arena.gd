extends Node
## Strategy arena: full AI-vs-AI duels between two configurable wizards, with the
## live rules (packs, income, shop, peasant harvest at combat start, real-time
## combat with each wizard's casting loop). Each seed is played twice with the
## sides swapped and the shop generators exchanged, so both strategies see the
## same offers and the same starting packs.
##   godot --headless --path . res://training/arena.tscn -- --no-sound --duels=20 --seed=1
##     --a='{"level":2}' --b='{"level":2,"profile":{"harvest_value":6}}'
## A side is {"level": int, "profile": {EnemyAI profile overrides},
## "cast": {Difficulty casting overrides, delays as [min, max]}}.
## Prints one RESULT line: a_wins b_wins draws rounds a_hp_left b_hp_left, plus
## per-side averages (peasants fielded, stars, upgrades, gold left unspent).

const STEP := 1.0 / 30.0
const MAX_ROUNDS := 40


func _ready() -> void:
	call_deferred("run")


func _side(text: String) -> Dictionary:
	var side = JSON.parse_string(text) if text != "" else {}
	if not side is Dictionary:
		push_error("Invalid side: " + text)
		side = {}
	var level := int(side.get("level", Difficulty.ARCHMAGE))
	var profile: Dictionary = EnemyAI.profile_for(level).merged(side.get("profile", {}), true)
	var cast := {}
	for key in side.get("cast", {}):
		var value = side.cast[key]
		cast[key] = Vector2(value[0], value[1]) if value is Array else value
	return {"level": level, "profile": profile, "cast": cast}


func run() -> void:
	var duels := 20
	var seed_base := 1
	var sides := [_side(""), _side("")]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--duels="):
			duels = int(arg.trim_prefix("--duels="))
		elif arg.begins_with("--seed="):
			seed_base = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--a="):
			sides[0] = _side(arg.trim_prefix("--a="))
		elif arg.begins_with("--b="):
			sides[1] = _side(arg.trim_prefix("--b="))
	var wins := [0, 0]
	var draws := 0
	var rounds_total := 0
	var hp_left := [0.0, 0.0]
	var stats := [{}, {}]
	for duel in duels:
		var seed_id := seed_base * 100003 + duel / 2
		var a_team := duel % 2
		var result := _duel(sides, seed_id, a_team, stats)
		rounds_total += result.rounds
		if result.winner >= 0:
			wins[result.winner] += 1
		else:
			draws += 1
		for s in 2:
			hp_left[s] += result.hp[s]
	var parts := []
	for s in 2:
		for key in stats[s]:
			parts.append("%s_%s=%.3f" % ["ab"[s], key, stats[s][key] / float(duels)])
	print("RESULT a=%d b=%d draws=%d rounds=%.3f a_hp=%.3f b_hp=%.3f %s" % [
		wins[0], wins[1], draws, float(rounds_total) / duels, hp_left[0] / duels, hp_left[1] / duels, " ".join(parts)])
	get_tree().quit()


## Side index s plays team (a_team ^ s). Shop generator g follows the seed, not
## the side, so swapping a_team swaps which strategy sees which offers.
func _duel(sides: Array, seed_id: int, a_team: int, stats: Array) -> Dictionary:
	var states: Array[WizardState] = [WizardState.new(0), WizardState.new(1)]
	var shops: Array[RandomNumberGenerator] = [RandomNumberGenerator.new(), RandomNumberGenerator.new()]
	var combat_rng := RandomNumberGenerator.new()
	combat_rng.seed = seed_id * 7 + 3
	var side_of := [a_team, 1 - a_team] # side_of[team]
	for team in 2:
		shops[team].seed = seed_id * 7 + team
		states[team].ai_level = sides[side_of[team]].level
		states[team].take_starting_pack(EnemyAI.choose_pack(shops[team], sides[side_of[team]].profile))
	var rounds := 0
	while states[0].hp > 0 and states[1].hp > 0 and rounds < MAX_ROUNDS:
		rounds += 1
		for team in 2:
			var s := states[team]
			s.gold += Rules.income(rounds)
			s.refresh_offers(shops[team])
			EnemyAI.shop(s, shops[team], sides[side_of[team]].profile)
		var b := Battle.new()
		add_child(b)
		b.ai_casting = [true, true]
		for team in 2:
			b.cast_overrides[team] = sides[side_of[team]].cast
		b.setup(states, combat_rng.randi())
		for team in 2:
			b.ai_profiles[team] = sides[side_of[team]].profile
		for team in 2:
			var st: Dictionary = stats[side_of[team]]
			var yields := states[team].harvest()
			var gold := 0
			for y in yields:
				gold += y.gold
			st.harvest = st.get("harvest", 0.0) + gold
		while not b.finished:
			b.step(STEP)
		if b.result.winner >= 0:
			states[1 - b.result.winner].take_round_damage(b.result.survivors)
		b.free()
	if OS.get_cmdline_user_args().has("--comp"):
		for team in 2:
			var forms := []
			for c in states[team].fielded():
				forms.append("%s%d" % [c.form_id, c.stars])
			forms.sort()
			var bench := []
			for c in states[team].benched():
				bench.append("%s%d.%d" % [c.form_id, c.stars, c.merge_copies])
			forms.append("| " + " ".join(bench))
			print("COMP side=%s won=%s rounds=%d forms=%s" % ["AB"[side_of[team]], states[team].hp > 0, rounds, ",".join(forms)])
	for team in 2:
		var st: Dictionary = stats[side_of[team]]
		var stars := 0
		for c in states[team].fielded():
			stars += c.stars
		st.final_stars = st.get("final_stars", 0.0) + stars
		st.upgraded = st.get("upgraded", 0.0) + (1.0 if states[team].shift_recharge_upgraded else 0.0)
		st.gold_left = st.get("gold_left", 0.0) + states[team].gold
	var winner := -1
	if states[0].hp <= 0 and states[1].hp > 0:
		winner = side_of[1]
	elif states[1].hp <= 0 and states[0].hp > 0:
		winner = side_of[0]
	var hp := [0.0, 0.0]
	for team in 2:
		hp[side_of[team]] = maxf(0.0, states[team].hp)
	return {"winner": winner, "rounds": rounds, "hp": hp}
