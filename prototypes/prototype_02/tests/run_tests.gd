extends Node
## Headless rule tests and combat simulations for Prototype 02.
## Run from prototypes/prototype_02:
##   godot --headless --path . res://tests/run_tests.tscn

var _failures := 0
var _checks := 0


func _ready() -> void:
	_test_network()
	_test_charges()
	_test_transformation_rules()
	_test_immunity_and_invalid_casts()
	_test_economy()
	_test_shop_and_merges()
	_test_preparation_input()
	_test_round_reset_and_damage()
	_test_abilities()
	_test_animal_roles()
	_simulate_duels()
	print("\n%d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: " + label)


func _new_battle() -> Battle:
	var b := Battle.new()
	add_child(b)
	b.ai_casting = [false, false]
	b.rng.seed = 7
	return b


# --- Network ----------------------------------------------------------------------

func _test_network() -> void:
	var ids := CreatureDB.all_ids()
	check(ids.size() == 24, "24 forms")
	var fantasy := 0
	for id in ids:
		check(CreatureDB.FORMS.has(id), "form data for " + id)
		if CreatureDB.FORMS[id].family == "fantasy":
			fantasy += 1
		var outs := CreatureDB.outcomes(id)
		check(outs.size() == 3, "3 outcomes for " + id)
		var total := 0.0
		for o in outs:
			total += o.chance
			check(CreatureDB.FORMS[o.id].family != CreatureDB.FORMS[id].family, "cross-roster link " + id + ">" + o.id)
			for back in CreatureDB.outcomes(o.id):
				check(back.id != id, "no direct reverse " + id + "<>" + o.id)
		check(absf(total - 1.0) < 0.0001, "chances sum to 1 for " + id)
	check(fantasy == 12, "12 fantasy forms")
	# Every form reaches every other; shortest return is 8 casts.
	for id in ids:
		var dist := {id: 0}
		var frontier: Array = [id]
		var return_len := -1
		while not frontier.is_empty() and return_len < 0:
			var next: Array = []
			for f in frontier:
				for o in CreatureDB.outcomes(f):
					if o.id == id and return_len < 0:
						return_len = dist[f] + 1
					if not dist.has(o.id):
						dist[o.id] = dist[f] + 1
						next.append(o.id)
			frontier = next
		check(dist.size() == 24, "all forms reachable from " + id)
		check(return_len == 8, "shortest return of 8 for " + id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var counts := {}
	for i in 3000:
		var r := CreatureDB.roll_outcome("peasant", rng)
		counts[r] = counts.get(r, 0) + 1
	for o in CreatureDB.outcomes("peasant"):
		check(absf(counts.get(o.id, 0) / 3000.0 - 1.0 / 3.0) < 0.04, "roll distribution " + o.id)


# --- Spell ----------------------------------------------------------------------------

func _test_charges() -> void:
	var s := ShiftSpell.new()
	check(s.charges == 1, "start with one charge")
	_tick(s, 2.99)
	check(s.charges == 1, "no charge before 3 s")
	_tick(s, 0.02)
	check(s.charges == 2, "two charges at 3 s")
	_tick(s, 3.0)
	check(s.charges == 3, "three charges at 6 s")
	_tick(s, 10.0)
	check(s.charges == 3 and s.recharge == 0.0, "capped at three, timer stopped")
	s.consume()
	s.consume()
	s.consume()
	_tick(s, 1.5)
	check(absf(s.recharge - 1.5) < 0.05, "recharge running")
	_tick(s, 7.45)
	check(s.charges == 2, "two charges just before nine seconds")
	_tick(s, 0.1)
	check(s.charges == 3, "zero to three in nine seconds")
	# A cast during a running recharge keeps the timer.
	s = ShiftSpell.new()
	s.charges = 2
	_tick(s, 1.5)
	s.consume()
	check(absf(s.recharge - 1.5) < 0.05, "cast does not reset recharge timer")


func _tick(s: ShiftSpell, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.00001:
		var dt := minf(0.01, seconds - t)
		s.tick(dt)
		t += dt


func _test_transformation_rules() -> void:
	var b := _new_battle()
	var ally := b.spawn(0, "guardian", Vector2(100, 300))
	var foe := b.spawn(1, "peasant", Vector2(400, 50))
	b.spells[0].charges = 3
	ally.hp = ally.max_hp * 0.5
	ally.attack_timer = 1.0
	ally.add_status("poisoned", 3.0, 5.0, false)
	ally.add_status("inspired", 2.0, 0.35, true)
	ally.ability_timer = 2.5
	check(b.cast(0, ally), "cast on ally succeeds")
	check(ally.form_id in ["rabbit", "turtle", "deer"], "guardian becomes a stage-2 animal")
	check(ally.level == 2, "ally cast grants +1 level")
	check(absf(ally.max_hp - ally.data.hp * 1.2) < 0.01, "level 2 max HP is x1.2 base")
	check(absf(ally.hp / ally.max_hp - 0.6) < 0.001, "50% health becomes 60%")
	check(ally.attack_timer == 0.0, "attack readied")
	check(not ally.statuses.has("poisoned"), "negative status cleansed")
	check(ally.statuses.has("inspired"), "positive status kept")
	check(absf(ally.ability_timer - 2.5) < 0.001, "ability cooldown carried over")
	check(absf(ally.attack_damage() - ally.data.dmg * 1.2) < 0.01, "level scales basic damage")
	# Enemy cast preserves the enemy's level, still heals and readies it.
	foe.level = 3
	foe.max_hp = foe.data.hp * Rules.level_mult(3)
	foe.hp = foe.max_hp * 0.95
	check(b.cast(0, foe), "cast on enemy succeeds")
	check(foe.level == 3, "enemy cast preserves level")
	check(absf(foe.hp - foe.max_hp) < 0.01, "heal capped at full health")
	# Entering a form with a ready-on-entry cooldown does not get an instant ability.
	var fresh := b.spawn(0, "peasant", Vector2(200, 300))
	fresh.ability_timer = 0.0
	b.spells[0].charges = 3
	b.cast(0, fresh)
	check(fresh.ability_timer == float(fresh.data.get("cd", 0.0)), "no instant ability on entry")
	b.queue_free()


func _test_immunity_and_invalid_casts() -> void:
	var b := _new_battle()
	var u := b.spawn(0, "archer", Vector2(100, 300))
	b.spawn(1, "archer", Vector2(400, 50))
	b.spells[0].charges = 3
	b.spells[1].charges = 3
	check(b.cast(0, u), "first cast")
	check(not b.cast(0, u), "immune target rejected")
	check(not b.cast(1, u), "immunity applies to both wizards")
	check(b.spells[0].charges == 2, "invalid cast consumed no charge")
	for i in 290:
		b.step(0.01)
	check(u.immune_t > 0.0, "still immune before 3 s")
	for i in 20:
		b.step(0.01)
	check(u.immune_t == 0.0, "immunity ends after 3 s")
	b.spells[0].charges = 0
	check(not b.cast(0, u), "no charge, no cast")
	b.casting_enabled = false
	b.spells[0].charges = 3
	check(not b.cast(0, u), "no-spell mode blocks casts")
	b.queue_free()


# --- Economy and rounds ---------------------------------------------------------------

func _test_economy() -> void:
	check(Rules.income(1) == 3 and Rules.income(2) == 4 and Rules.income(5) == 7, "income 3, 4, 5...")
	var s := WizardState.new(0)
	var rng := RandomNumberGenerator.new()
	s.refresh_offers(rng)
	check(s.offers.size() == 3, "three offers")
	for id in s.offers:
		check(CreatureDB.FORMS[id].family == "fantasy", "shop sells fantasy forms only")
	s.offers = ["peasant", "crossbowman", "guardian"]
	s.gold = 3
	check(s.buy(1) != null and s.gold == 0, "buy a 3-gold creature")
	check(s.buy(1) == null, "each offer bought once")
	check(s.buy(0) == null, "cannot buy without gold")
	var c: OwnedCreature = s.creatures[0]
	s.sell(c)
	check(s.gold == 3 and s.creatures.is_empty(), "sell for purchase price")
	s.gold = 100
	for i in 12:
		s.add_creature("peasant")
	check(s.field_count() == 6 and s.benched().size() == 6, "6 fielded + 6 reserve")
	check(s.add_creature("peasant") == null and not s.has_space(), "capacity reached")
	var benched: OwnedCreature = s.benched()[0]
	var empty_cell := Vector2i(-1, -1)
	for y in Rules.team_rows(0):
		for x in Rules.COLS:
			if s.at_cell(Vector2i(x, y)) == null:
				empty_cell = Vector2i(x, y)
	check(not s.move_to_cell(benched, empty_cell), "field cap blocks a 7th creature")
	var fielded: OwnedCreature = s.fielded()[0]
	var cell := fielded.cell
	check(s.move_to_cell(benched, cell) and benched.cell == cell and not fielded.is_fielded(), "swap bench and field")
	check(not s.move_to_cell(fielded, Vector2i(0, 0)), "cannot place in the enemy half")


func _test_shop_and_merges() -> void:
	var s := WizardState.new(0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	s.gold = 100
	s.offers = ["peasant", "archer", "cleric"]
	var bought := s.buy(0)
	check(bought != null and not bought.is_fielded() and bought.slot == 0,
		"purchase goes to bench even with an empty board")
	check(s.field_count() == 0, "purchase never auto-fields")
	check(s.toggle_lock(1), "right-click can lock an offer")
	var gold := s.gold
	check(s.reroll(rng) and s.gold == gold - Rules.REROLL_COST, "reroll charges exactly once")
	check(s.offers[0] != "" and s.offers[1] == "archer" and s.offers[2] != "cleric",
		"reroll fills sold slots, changes unlocked offers and keeps locks")
	s.refresh_offers(rng)
	check(s.offers[1] == "archer" and s.locked[1], "locks persist into next round")
	s.toggle_lock(0)
	s.toggle_lock(2)
	gold = s.gold
	check(not s.reroll(rng) and s.gold == gold, "all locked prevents paid no-op reroll")
	s.buy(1)
	check(not s.locked[1] and s.offers[1] == "", "buying clears the offer lock")
	s.gold = 0
	var offers := s.offers.duplicate()
	check(not s.reroll(rng) and s.offers == offers, "no gold means no reroll")
	check(not s.toggle_lock(1), "empty offer cannot be locked")

	# Nine purchased copies chain into one three-star unit, keeping its board cell.
	var m := WizardState.new(0)
	m.gold = 100
	m.offers = ["peasant", "", ""]
	var first := m.buy(0)
	m.move_to_cell(first, Vector2i(3, 3))
	for i in 8:
		m.offers[0] = "peasant"
		var result := m.buy(0)
		check(result != null and result in m.creatures, "purchase returns surviving merge result")
		if i == 1:
			check(first.stars == 2 and m.creatures.size() == 1, "three one-star copies merge")
	check(m.creatures.size() == 1 and first.stars == 3, "nine copies merge to three stars")
	check(first.cell == Vector2i(3, 3), "merge preserves fielded survivor and position")
	check(first.price() == 9, "merged sale preserves invested gold")
	for i in 2:
		var capped := m.add_creature("peasant")
		capped.stars = 3
	m._merge(first)
	check(m.creatures.size() == 3 and first.stars == 3, "three-star rank never merges further")

	# Full-bench third-copy exception, and rejection without an available merge.
	var full := WizardState.new(0)
	full.gold = 100
	for i in Rules.RESERVE_CAP:
		var c := OwnedCreature.new("peasant" if i < 2 else "archer")
		c.slot = i
		full.creatures.append(c)
	full.offers = ["guardian", "peasant", ""]
	gold = full.gold
	check(full.buy(0) == null and full.gold == gold and full.offers[0] == "guardian",
		"full bench rejects purchase even when the board has room")
	var merged := full.buy(1)
	check(merged != null and merged.stars == 2 and merged.slot >= 0 and full.benched().size() == 5,
		"full bench accepts a third copy and frees a slot by merging")
	var mixed := WizardState.new(0)
	var rank_two := mixed.add_creature("archer")
	rank_two.stars = 2
	mixed.add_creature("archer")
	mixed.offers = ["archer", "", ""]
	mixed.gold = 10
	mixed.buy(0)
	check(mixed.creatures.size() == 3 and rank_two.stars == 2, "different ranks do not merge")

	var foe := WizardState.new(1)
	foe.add_creature("guardian")
	var b := _new_battle()
	var teams: Array[WizardState] = [m, foe]
	b.setup(teams, 12)
	var u: Unit = b.living(0)[0]
	check(u.stars == 3 and u.level == 1, "combat copies permanent stars separately from levels")
	check(u.max_hp > CreatureDB.get_form("peasant").hp * 3, "stars improve combat health")
	u.transform_to("rabbit", true)
	check(u.stars == 3 and u.level == 2 and first.stars == 3, "transformation keeps stars and grants temporary level")
	check(absf(u.attack_damage() - u.data.dmg * Rules.star_mult(3) * Rules.level_mult(2)) < 0.001,
		"star and temporary level bonuses combine")
	b.free()
	b = _new_battle()
	b.setup(teams, 12)
	u = b.living(0)[0]
	check(u.stars == 3 and u.level == 1 and u.form_id == "peasant", "next combat resets form and level but keeps stars")
	b.free()


func _test_preparation_input() -> void:
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	game.choose_pack(0)
	game.player.gold = 20
	var state: WizardState = game.player
	state.offers = ["peasant", "archer", "cleric"]
	var offer_pos := Hud.offer_rect(1).get_center()
	game._right_press(offer_pos)
	check(game.player.locked[1], "shop right-click locks offer through game input")
	game._left_press(Hud.REROLL_RECT.get_center())
	check(game.player.gold == 19 and game.player.offers[1] == "archer", "reroll button refreshes through game input")
	var field_count: int = game.player.field_count()
	game._left_press(offer_pos)
	check(game.player.field_count() == field_count and game.player.benched().size() == 1,
		"shop click purchases onto bench")
	var bought: OwnedCreature = game.player.benched()[0]
	game._left_press(Rules.reserve_slot_rect(bought.slot).get_center())
	var cell: Vector2i = game.player.preferred_free_cell("back")
	game._left_release(Rules.BOARD_POS + Rules.cell_center(cell))
	check(bought.cell == cell and game.player.field_count() == field_count + 1,
		"player can drag purchased bench unit onto board")
	game._right_press(Hud.offer_rect(0).get_center())
	game._right_press(Hud.offer_rect(0).get_center())
	check(not game.player.locked[0], "second right-click unlocks an offer")
	game.free()


func _test_round_reset_and_damage() -> void:
	var p := WizardState.new(0)
	var e := WizardState.new(1)
	p.add_creature("guardian")
	e.add_creature("peasant")
	var b := _new_battle()
	var teams: Array[WizardState] = [p, e]
	b.setup(teams, 11)
	b.spells[0].charges = 3
	b.cast(0, b.living(0)[0])
	check(p.creatures[0].form_id == "guardian", "owned creature keeps its purchased form")
	var result := {}
	b.ended.connect(func(r): result.merge(r)) # lambdas capture locals by value
	for i in 6000:
		b.step(1.0 / 60.0)
		if b.finished:
			break
	check(b.finished and result.has("winner"), "combat ends")
	b.queue_free()
	# Draw on mutual elimination / timeout.
	var d := _new_battle()
	d.spawn(0, "turtle", Vector2(30, 400))
	d.spawn(1, "turtle", Vector2(540, 30))
	d.casting_enabled = false
	for i in 4000:
		d.step(1.0 / 60.0)
		if d.finished:
			break
	check(d.finished, "timeout ends combat")
	d.queue_free()


func _test_abilities() -> void:
	# Duelist parry negates the first basic hit.
	var b := _new_battle()
	var duelist := b.spawn(0, "duelist", Vector2(200, 200))
	var archer := b.spawn(1, "archer", Vector2(200, 100))
	duelist.tick(0.01)
	check(duelist.parry_ready, "duelist starts with parry")
	b.damage(archer, duelist, 10.0, "ranged")
	check(duelist.hp == duelist.max_hp and not duelist.parry_ready, "parry negates a hit")
	# Armour reduction and piercing.
	var guard := b.spawn(0, "guardian", Vector2(300, 300))
	b.damage(null, guard, 100.0, "ability")
	check(absf(guard.max_hp - guard.hp - 60.0) < 0.01, "40% armour")
	guard.hp = guard.max_hp
	b.damage(null, guard, 100.0, "ranged", true)
	check(absf(guard.max_hp - guard.hp - 100.0) < 0.01, "piercing ignores armour")
	# Hedgehog thorns.
	var hog := b.spawn(1, "hedgehog", Vector2(400, 100))
	var peasant := b.spawn(0, "peasant", Vector2(420, 120))
	b.damage(peasant, hog, 5.0, "melee")
	check(absf(peasant.max_hp - peasant.hp - 5.0) < 0.01, "thorns reflect melee damage")
	# Poison ticks (measured on an isolated unit so it does not fight).
	var lone := _new_battle()
	var victim := lone.spawn(0, "peasant", Vector2(100, 100))
	victim.add_status("poisoned", 2.0, 5.0, false)
	for i in 100:
		victim.tick(0.01)
	check(absf(victim.max_hp - victim.hp - 5.0) < 0.2, "poison 5 HP/s")
	lone.queue_free()
	# Berserker attacks faster when hurt.
	var berserker := b.spawn(0, "berserker", Vector2(100, 400))
	var full := berserker.attack_interval()
	berserker.hp = berserker.max_hp * 0.2
	check(berserker.attack_interval() < full * 0.6, "berserker speeds up")
	b.queue_free()


## Animal transformations must offer useful combat niches, including the
## previously weak stage-2 outcomes. These checks exercise their actual effects.
func _test_animal_roles() -> void:
	var b := _new_battle()
	var rabbit := b.spawn(0, "rabbit", Vector2(200, 200))
	var guardian := b.spawn(1, "guardian", Vector2(240, 200))
	check(rabbit.attack_damage() / rabbit.attack_interval() > guardian.attack_damage() / guardian.attack_interval() * 2.0,
		"rabbit trades guardian durability for substantially higher basic DPS")
	rabbit.tick(0.01)
	check(rabbit.dash_t > 0.0, "rabbit hops away from melee pressure")
	check(rabbit.dash_vel.length() * 0.25 <= Rules.CELL,
		"rabbit hop stays short enough to re-engage quickly")
	var deer := b.spawn(0, "deer", Vector2(200, 230))
	guardian.hp = guardian.max_hp * 0.5
	rabbit.hp = rabbit.max_hp * 0.5
	deer.hp = deer.max_hp * 0.5
	deer.tick(0.01)
	var rabbit_hp := rabbit.hp
	var deer_hp := deer.hp
	rabbit._tick_statuses(0.3)
	deer._tick_statuses(0.3)
	check(rabbit.hp > rabbit_hp and deer.hp > deer_hp, "deer sustains nearby allies and itself")
	check(not guardian.statuses.has("regen"), "deer does not heal enemies")
	var skunk := b.spawn(0, "skunk", Vector2(220, 240))
	skunk.ability_timer = 0.0
	skunk.tick(0.01)
	check(guardian.armour() < guardian.data.armour, "skunk weakens an armoured frontline")
	var peacock := b.spawn(0, "peacock", Vector2(220, 260))
	peacock.ability_timer = 0.0
	var interval := guardian.attack_interval()
	peacock.tick(0.01)
	check(guardian.attack_interval() > interval, "peacock slows enemy attacks")
	b.free()


# --- Simulations ------------------------------------------------------------------------

## Plays AI-vs-AI duels to check the loop terminates and to report pacing.
func _simulate_duels() -> void:
	for casting in [true, false]:
		var durations := []
		var rounds := []
		var draws := 0
		var combats := 0
		for duel in 20:
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 + duel
			var states: Array[WizardState] = [WizardState.new(0), WizardState.new(1)]
			for s in states:
				for id in EnemyAI.choose_pack(rng, CreatureDB.PACKS):
					s.add_creature(id)
			var round_num := 0
			while states[0].hp > 0 and states[1].hp > 0 and round_num < 40:
				round_num += 1
				for s in states:
					s.gold += Rules.income(round_num)
					s.refresh_offers(rng)
					EnemyAI.shop(s, rng)
				var b := _new_battle()
				b.rng.seed = rng.randi()
				b.ai_casting = [casting, casting]
				b.casting_enabled = casting
				b.setup(states, rng.randi())
				while not b.finished:
					b.step(1.0 / 60.0)
				combats += 1
				durations.append(b.result.time)
				if b.result.winner >= 0:
					states[1 - b.result.winner].hp -= b.result.survivors
				else:
					draws += 1
				b.free()
			rounds.append(round_num)
			check(round_num < 40, "duel ends (casting=%s, duel %d)" % [casting, duel])
		var avg_t := 0.0
		for t in durations:
			avg_t += t
		avg_t /= durations.size()
		var avg_r := 0.0
		for r in rounds:
			avg_r += r
		avg_r /= rounds.size()
		print("casting=%s: %d combats, avg combat %.1f s, avg duel %.1f rounds, draws %d" % [casting, combats, avg_t, avg_r, draws])
