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
	_test_starting_packs()
	_test_preparation_input()
	_test_loss_gold()
	_test_shop_drag_and_enemy_preparation()
	_test_phase_music()
	_test_result_recordings()
	_test_round_reset_and_damage()
	_test_frenzy()
	_test_abilities()
	_test_animal_roles()
	_test_mage_attacks()
	_test_mage_interruptions()
	_test_bard_song()
	_test_overlapping_blizzards()
	_test_combat_click_casts()
	_test_blizzard_and_recharge_upgrade()
	_test_ai_strategy()
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
		check(absf(counts.get(o.id, 0) / 3000.0 - o.chance) < 0.04, "roll distribution " + o.id)


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
	var foe := b.spawn(1, "archer", Vector2(400, 50), 0, 1)
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
	foe.level = 3
	foe.max_hp = foe.data.hp * foe.stat_mult()
	foe.hp = foe.max_hp * 0.5
	foe.attack_timer = 1.5
	foe.add_status("poisoned", 3.0, 5.0, false)
	check(b.cast(0, foe), "cast on enemy succeeds")
	check(foe.level == 1 and foe.stars == 1, "enemy cast resets temporary levels and preserves stars")
	check(is_equal_approx(foe.max_hp, foe.data.hp * 1.8) and is_equal_approx(foe.attack_damage(), foe.data.dmg * 1.8),
		"enemy cast recalculates max health and damage at level 1 with stars")
	check(is_equal_approx(foe.hp / foe.max_hp, 0.5), "enemy cast preserves health percentage without healing")
	check(foe.attack_timer == 1.5 and foe.statuses.has("poisoned"), "enemy cast preserves attack cooldown and debuffs")
	check(foe.stun_t == 3.0, "enemy cast stuns for three seconds")
	var start_pos := foe.position
	var start_hp := foe.hp
	foe.tick(0.75)
	check(foe.position == start_pos and foe.target == null, "stunned enemy cannot move or act")
	check(foe.attack_timer == 0.75 and foe.hp < start_hp, "attack recharge and poison continue during the stun")
	foe.tick(2.0)
	check(foe.stun_t == 0.25 and foe.position == start_pos, "enemy remains still just before three seconds")
	foe.tick(0.5)
	check(foe.stun_t == 0.0 and foe.position != start_pos, "enemy resumes movement when the stun expires")
	# Entering a form with a ready-on-entry cooldown does not get an instant ability.
	var fresh := b.spawn(0, "peasant", Vector2(200, 300))
	fresh.ability_timer = 0.0
	b.spells[0].charges = 3
	b.cast(0, fresh)
	check(fresh.ability_timer == (0.0 if fresh.data.ability == "hop" else float(fresh.data.get("cd", 0.0))), "rabbit leap is immediate; other ability cooldowns carry over")
	b.queue_free()
	_test_ally_shift_effects()


## Positive post-transformation effects trigger only on a shapeshift by the
## creature's own wizard.
func _test_ally_shift_effects() -> void:
	var b := _new_battle()
	var blessed := b.spawn(0, "peasant", Vector2(100, 400))
	blessed.ability_timer = 0.0
	blessed.transform_to("rabbit", true)
	check(blessed.ability_timer == 0.0, "ally shift into rabbit readies its leap at once")
	var hexed := b.spawn(1, "peasant", Vector2(500, 40))
	hexed.ability_timer = 0.0
	hexed.transform_to("rabbit", false)
	check(is_equal_approx(hexed.ability_timer, CreatureDB.get_form("rabbit").cd), "enemy shift into rabbit gives no immediate leap")
	b.free()

	# Skunk: nearby enemies stop attacking and flee in a zigzag for 2 s.
	b = _new_battle()
	var skunk := b.spawn(0, "spearman", Vector2(300, 300))
	var near := b.spawn(1, "guardian", Vector2(300, 250))
	var mage := b.spawn(1, "pyromancer", Vector2(260, 250))
	var far := b.spawn(1, "archer", Vector2(300, 30))
	var friend := b.spawn(0, "peasant", Vector2(340, 300))
	mage.ability_timer = 0.0
	mage._tick_ability()
	check(mage.channel_t > 0.0, "pyromancer starts channeling before the skunk shift")
	skunk.transform_to("skunk", true)
	check(near.statuses.has("feared") and is_equal_approx(near.statuses.feared.t, 2.0), "ally shift into skunk fears a nearby enemy for 2 s")
	check(not far.statuses.has("feared") and not friend.statuses.has("feared"), "skunk fear spares distant enemies and allies")
	check(mage.statuses.has("feared") and mage.channel_t == 0.0 and mage.ability_timer == mage.data.cd,
		"skunk fear interrupts Fireball and starts its cooldown")
	near.attack_timer = 0.0
	var start_d := near.position.distance_to(skunk.position)
	var hp_before := skunk.hp
	var xs: Array[float] = []
	for i in 30:
		near.tick(1.0 / 60.0)
		xs.append(near.position.x)
	check(near.position.distance_to(skunk.position) > start_d and skunk.hp == hp_before and near.attack_timer == 0.0,
		"feared enemy runs away without attacking")
	var turns := 0
	for i in range(2, xs.size()):
		if signf(xs[i] - xs[i - 1]) != signf(xs[i - 1] - xs[i - 2]):
			turns += 1
	check(turns >= 1, "feared enemy flees in a zigzag")
	near._tick_statuses(1.6)
	check(not near.statuses.has("feared"), "fear expires after 2 s")
	b.free()

	b = _new_battle()
	var cursed := b.spawn(1, "spearman", Vector2(300, 300))
	var bystander := b.spawn(0, "guardian", Vector2(300, 350))
	cursed.transform_to("skunk", false)
	check(not bystander.statuses.has("feared"), "enemy shift into skunk causes no fear")
	b.free()


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
	fielded.form_id = "guardian" # unlike forms still swap instead of combining
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

	# Buying never combines copies, even if a matching pair is already owned.
	var m := WizardState.new(0)
	m.gold = 100
	m.offers = ["cleric", "cleric", "cleric"]
	var first := m.buy(0)
	var second := m.buy(1)
	var third := m.buy(2)
	check(m.creatures.size() == 3 and first.stars == 0, "three purchases stay separate until manual merge")
	m.move_to_cell(first, Vector2i(3, 3))
	check(m.move_to_cell(second, first.cell), "drop on matching board creature combines copies")
	check(first.merge_copies == 2 and first.stars == 0 and second not in m.creatures,
		"two copies fill two circles without earning a star")
	check(first.price() == CreatureDB.get_form("cleric").price * 2, "partial group preserves resale value")
	var partial := _new_battle()
	var normal_unit := partial.spawn(0, "cleric", Vector2(50, 300))
	var teams_partial: Array[WizardState] = [m, WizardState.new(1)]
	partial.setup(teams_partial, 1)
	var grouped: Unit = partial.living(0)[1]
	check(grouped.merge_copies == 2 and grouped.max_hp == normal_unit.max_hp and grouped.attack_damage() == normal_unit.attack_damage(),
		"partial grouping persists into combat but gives no health or damage bonus")
	partial.free()
	check(m.move_to_cell(third, first.cell) and first.stars == 1 and first.merge_copies == 1,
		"third manually dropped copy earns one star and resets circles")
	check(first.cell == Vector2i(3, 3) and m.creatures.size() == 1, "manual merge preserves chosen recipient cell")
	var next := m.add_creature("cleric")
	next.stars = 1
	var last := m.add_creature("cleric")
	last.stars = 1
	m.merge(next, first)
	check(first.stars == 1 and first.merge_copies == 2, "two one-star copies stay at one star")
	m.merge(last, first)
	check(first.stars == 2 and first.merge_copies == 1 and first.price() == 18, "three one-star copies earn second star with conserved value")
	for i in 2:
		var copy := m.add_creature("cleric")
		copy.stars = 2
		m.merge(copy, first)
	check(first.stars == 3 and first.price() == 54, "27 base copies earn third star")
	var capped := m.add_creature("cleric")
	capped.stars = 3
	check(not m.merge(capped, first) and first.stars == 3, "three-star creatures cannot combine")
	check(not m.merge(first, first), "self-drop cannot duplicate merge material")

	var overflow := WizardState.new(0)
	var recipient := overflow.add_creature("guardian")
	var source := overflow.add_creature("guardian")
	recipient.merge_copies = 2
	source.merge_copies = 2
	var source_cell := source.cell
	var target_cell := recipient.cell
	var invested := source.price() + recipient.price()
	check(overflow.move_to_cell(source, target_cell), "two partial groups can combine")
	check(recipient.stars == 1 and recipient.merge_copies == 1 and source.stars == 0 and source.merge_copies == 1,
		"overflow leaves unconsumed material at its original rank")
	check(source.cell == source_cell and recipient.cell == target_cell and source.price() + recipient.price() == invested,
		"overflow keeps source location and all invested value")
	var other_form := overflow.add_creature("cleric")
	check(not overflow.merge(other_form, recipient) and not overflow.merge(source, recipient), "different forms and different ranks cannot combine")
	var outsider := OwnedCreature.new("guardian")
	check(not overflow.merge(outsider, source), "unowned copies cannot be merged")

	var bench := WizardState.new(0)
	bench.gold = 20
	bench.offers = ["cleric", "cleric", "cleric"]
	var bench_target := bench.buy(0)
	var bench_source := bench.buy(1)
	check(bench.move_to_slot(bench_source, bench_target.slot) and bench_target.merge_copies == 2,
		"manual merge works from bench to bench")
	var field_source := bench.add_creature("cleric")
	check(bench.move_to_slot(field_source, bench_target.slot) and bench_target.stars == 1 and not bench_target.is_fielded(),
		"board to bench merge preserves bench recipient")
	var full := WizardState.new(0)
	full.gold = 100
	for i in Rules.RESERVE_CAP:
		var c := OwnedCreature.new("peasant")
		c.slot = i
		full.creatures.append(c)
	full.offers = ["peasant", "", ""]
	check(not full.can_buy(0) and full.buy(0) == null and full.gold == 100,
		"full bench requires manual space before buying even with matching copies")
	full.move_to_slot(full.at_slot(1), 0)
	check(full.buy(0) != null, "manual grouping frees a slot for purchases")

	var foe := WizardState.new(1)
	foe.add_creature("guardian")
	var b := _new_battle()
	var teams: Array[WizardState] = [m, foe]
	b.setup(teams, 12)
	var u: Unit = b.living(0)[0]
	check(u.stars == 3 and u.level == 1, "combat copies permanent stars separately from levels")
	check(is_equal_approx(u.visual_scale(), 1.0), "merge stars do not enlarge the base combat image")
	check(u.max_hp > CreatureDB.get_form("cleric").hp * 3, "stars improve combat health")
	u.transform_to("rabbit", true)
	check(is_equal_approx(u.visual_scale(), 1.15), "temporary level enlarges image by 15 percent")
	check(u.stars == 3 and u.level == 2 and first.stars == 3, "transformation keeps stars and grants temporary level")
	check(absf(u.attack_damage() - u.data.dmg * Rules.star_mult(3) * Rules.level_mult(2)) < 0.001,
		"star and temporary level bonuses combine")
	u.level = 100
	check(is_equal_approx(u.visual_scale(), Rules.MAX_LEVEL_VISUAL_SCALE), "visual growth is capped without capping combat levels")
	b.free()
	b = _new_battle()
	b.setup(teams, 12)
	u = b.living(0)[0]
	check(u.stars == 3 and u.level == 1 and u.form_id == "cleric", "next combat resets form and level but keeps stars")
	check(is_equal_approx(u.visual_scale(), 1.0), "next combat restores normal image size")
	b.free()


func _test_starting_packs() -> void:
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	for i in CreatureDB.PACKS.size():
		game.new_duel()
		var pack: Dictionary = CreatureDB.PACKS[i]
		game._left_press(Hud.pack_rect(i).get_center())
		var forms: Array = game.player.fielded().map(func(c: OwnedCreature) -> String: return c.form_id)
		var gold := Rules.income(1) + int(pack.bonus_gold)
		check(forms == pack.forms, "%s fields the selected trio" % pack.name)
		check(game.round_num == 1 and game.player.gold == gold, "%s grants its first shop budget" % pack.name)
		var enemy_forms: Array = game.enemy.fielded().map(func(c: OwnedCreature) -> String: return c.form_id)
		var enemy_pack := CreatureDB.PACKS.filter(func(choice: Dictionary) -> bool: return choice.forms == enemy_forms)
		check(enemy_pack.size() == 1 and game.enemy.gold == Rules.income(1) + enemy_pack[0].bonus_gold,
			"opponent receives the bonus for its own trio")
		game.choose_pack(i)
		check(game.round_num == 1 and game.player.gold == gold, "pack cannot be claimed twice")
		game.start_round()
		check(game.player.gold == gold + Rules.income(2), "pack bonus is not granted again in round two")
	game.free()


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
	game._left_release(offer_pos)
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
	state.gold = 20
	state.offers = ["guardian", "guardian", "guardian"]
	for i in 3:
		game._left_press(Hud.offer_rect(i).get_center())
		game._left_release(Hud.offer_rect(i).get_center())
	check(state.benched().size() == 3, "three UI purchases do not auto-merge")
	var recipient: OwnedCreature = state.benched()[0]
	var source: OwnedCreature = state.benched()[1]
	game._left_press(Rules.reserve_slot_rect(source.slot).get_center())
	game._left_release(Rules.reserve_slot_rect(recipient.slot).get_center())
	check(recipient.stars == 0 and recipient.merge_copies == 2 and game.drag == null,
		"drag-and-drop UI creates a two-circle group without a star")
	source = state.benched()[1]
	game._left_press(Rules.reserve_slot_rect(source.slot).get_center())
	game._left_release(Rules.reserve_slot_rect(recipient.slot).get_center())
	check(recipient.stars == 1 and recipient.merge_copies == 1 and state.benched().size() == 1,
		"third UI drop promotes the chosen recipient")
	game.free()


func _finish_enemy_preparation(game) -> void:
	for i in 64:
		if not game.enemy_preparing:
			break
		game._advance_enemy_preparation(1.0)
	check(not game.enemy_preparing, "enemy preparation finishes within a bounded number of actions")


func _test_shop_drag_and_enemy_preparation() -> void:
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	game.choose_pack(0)
	var state: WizardState = game.player
	var foe: WizardState = game.enemy
	# A deterministic affordable purchase, with no same-form merge on this team.
	foe.creatures.clear()
	foe.add_creature("guardian")
	foe.gold = 3
	foe.offers = ["archer", "", ""]
	check(game.enemy_preparing and foe.gold == 3 and foe.creatures.size() == 1,
		"round starts without instantly completing enemy purchases")
	game.start_combat()
	check(game.phase == game.Phase.PREP, "combat waits for visible enemy preparation")
	game._advance_enemy_preparation(0.1)
	check(foe.gold == 3, "enemy purchase has an initial readable delay")
	game._advance_enemy_preparation(0.25)
	check(foe.gold == 2 and foe.creatures.size() == 2 and game.enemy_action.kind == "buy",
		"enemy spends on one visible purchase at a time")
	var traveller: OwnedCreature = foe.creatures[-1]
	var origin: Vector2 = game.enemy_display_position(traveller)
	check(game.enemy_is_moving(traveller) and origin.distance_to(Rules.cell_center(traveller.cell)) > 20,
		"purchased enemy starts a movement rather than teleporting")
	game._advance_enemy_preparation(0.2)
	var middle: Vector2 = game.enemy_display_position(traveller)
	check(middle != origin and game.enemy_is_moving(traveller), "enemy placement has an intermediate position")
	_finish_enemy_preparation(game)
	check(not game.enemy_is_moving(traveller) and game.enemy_display_position(traveller).is_equal_approx(Rules.cell_center(traveller.cell)),
		"enemy arrives before combat becomes available")

	state.creatures.clear()
	state.gold = 20
	state.offers = ["guardian", "cleric", "archer"]
	var pos := Hud.offer_rect(0).get_center()
	game._left_press(pos)
	check(state.creatures.is_empty() and state.gold == 20 and state.offers[0] == "guardian",
		"shop mouse-down reserves a gesture without purchasing")
	game._left_release(Rules.BOARD_POS + Rules.cell_center(Vector2i(3, 3)))
	var target := state.at_cell(Vector2i(3, 3))
	check(target != null and state.gold == 18 and state.benched().is_empty(),
		"shop drag buys directly onto board without a bench detour")
	check(not game.show_merge_progress(target), "merge circles hidden when idle")
	game.hover_info = {"owned": target}
	check(game.show_merge_progress(target), "merge circles visible on hover")
	game.hover_info = {}
	state.offers[0] = "guardian"
	game._left_press(pos)
	var motion := InputEventMouseMotion.new()
	motion.position = pos + Vector2(-20, 0)
	game._unhandled_input(motion)
	check(game.show_merge_progress(target), "shop drag reveals compatible target progress")
	game._left_release(Rules.BOARD_POS + Rules.cell_center(target.cell))
	check(target.merge_copies == 2 and state.creatures.size() == 1 and state.gold == 16,
		"shop drag can buy and manually combine with a matching target")
	game._left_press(Hud.offer_rect(1).get_center())
	game._left_release(Vector2(10, 10))
	check(state.offers[1] == "cleric" and state.gold == 16 and game.drag == null,
		"invalid shop drop cancels without spending or consuming offer")
	game._left_press(Hud.offer_rect(1).get_center())
	game._left_release(Rules.BOARD_POS + Rules.cell_center(target.cell))
	check(state.offers[1] == "cleric" and state.gold == 16, "incompatible occupied drop does not charge")
	game._left_press(Hud.offer_rect(1).get_center())
	game._left_release(Hud.offer_rect(1).get_center())
	check(state.benched().size() == 1 and state.gold == 14, "ordinary shop click buys onto bench on release")
	var unrelated: OwnedCreature = state.benched()[0]
	game.drag = unrelated
	check(not game.show_merge_progress(target), "unrelated creatures hide progress during drag")
	game.drag = null
	# Fill the bench, then explicitly buy onto an empty board cell.
	for i in Rules.RESERVE_CAP:
		if state.at_slot(i) == null:
			var c := OwnedCreature.new("peasant")
			c.slot = i
			state.creatures.append(c)
	check(state.free_slot() == -1, "direct-purchase test has a full bench")
	game._left_press(Hud.offer_rect(2).get_center())
	game._left_release(Rules.BOARD_POS + Rules.cell_center(Vector2i(4, 4)))
	check(state.at_cell(Vector2i(4, 4)) != null and state.gold == 13, "direct placement works with a full bench")
	state.offers[0] = "guardian"
	game._left_press(pos)
	game._left_release(Rules.BOARD_POS + Rules.cell_center(target.cell))
	check(target.stars == 1 and state.gold == 11 and state.free_slot() == -1,
		"explicit shop merge works with a full bench and conserves its slots")
	state.offers[0] = "peasant"
	for i in 4:
		state.add_creature("peasant")
	var gold := state.gold
	game._left_press(pos)
	game._left_release(Rules.BOARD_POS + Rules.cell_center(Vector2i(7, 5)))
	check(state.gold == gold and state.offers[0] == "peasant", "field cap blocks direct purchase without charging")
	game.new_duel()
	check(not game.enemy_preparing and game.enemy_moves.is_empty() and game.shop_drag_index == -1,
		"restart clears enemy animations and pending shop gestures")
	game.free()


func _test_loss_gold() -> void:
	var state := WizardState.new(0)
	state.hp = 2
	state.gold = 7
	check(state.take_round_damage(6) == 2 and state.hp == 0 and state.gold == 7,
		"lethal overkill grants no compensation")
	check(state.take_round_damage(1) == 0 and state.gold == 7, "no reward after zero hearts")
	var carry := WizardState.new(0)
	check(carry.take_round_damage(1) == 0.5 and carry.hp == 9.5 and carry.gold == 0,
		"one survivor deals half a heart with no fractional gold")
	carry.take_round_damage(1)
	check(carry.hp == 9 and carry.gold == 1 and carry.loss_gold_progress == 0,
		"half-heart compensation carries across rounds to one whole gold")
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	game.player.gold = 8
	game.enemy.gold = 11
	game._on_battle_ended({"winner": 1, "survivors": 3})
	check(game.player.hp == 8.5 and game.player.gold == 9, "three survivors cost 1.5 hearts and grant one gold")
	check(game.enemy.hp == 10 and game.enemy.gold == 11, "winner gains no loss reward")
	var hud: Hud = game.hud
	check(hud.loss_rewards.size() == 3 and hud.displayed_hp(game.player) == 10 and hud.displayed_gold(game.player) == 8,
		"presentation begins before three half-heart hits")
	hud.advance_loss_rewards(0.23)
	check(hud.displayed_hp(game.player) == 9.5 and hud.displayed_gold(game.player) == 8,
		"first half-heart breaks without granting gold")
	hud.advance_loss_rewards(0.26)
	check(hud.displayed_hp(game.player) == 9, "second half-heart completes a whole heart")
	hud.advance_loss_rewards(0.83)
	check(hud.displayed_gold(game.player) == 9, "whole-heart coin arrives at counter")
	hud.advance_loss_rewards(hud.loss_reward_duration())
	check(hud.displayed_gold(game.player) == 9 and hud.displayed_hp(game.player) == 8.5,
		"HUD finishes at exact fractional health and integer gold")
	game.enemy.hp = 0.5
	game._on_battle_ended({"winner": 0, "survivors": 6})
	check(game.enemy.hp == 0 and game.enemy.gold == 11 and hud.loss_rewards.size() == 1,
		"last half-heart breaks with no overkill reward")
	check(not hud.loss_rewards[0].coin, "lethal half-heart has no coin effect")
	game._on_battle_ended({"winner": -1, "survivors": 0})
	check(hud.loss_rewards.is_empty() and game.player.gold == 9, "draw clears presentation and grants no gold")
	game.player.hp = 10
	game._on_battle_ended({"winner": 1, "survivors": 20})
	check(game.player.gold == 9 and hud.loss_rewards.all(func(reward): return not reward.coin),
		"lethal combat grants no compensation for any lost heart")
	check(game._resolve_t >= hud.loss_reward_duration(), "resolution waits for all half-heart effects")
	game.new_duel()
	check(hud.loss_rewards.is_empty() and game.player.gold == 0, "new duel clears rewards")
	game.free()


func _test_phase_music() -> void:
	var music := PhaseMusic.new()
	add_child(music)
	music.set_process(false)
	var prep: AudioStreamPlayer = music.players.prep
	var combat: AudioStreamPlayer = music.players.battle
	check(prep.stream.loop and combat.stream.loop and prep.stream.get_length() > 5 and combat.stream.get_length() > 5,
		"both supplied OGG tracks load as loops")
	music.transition_to("prep")
	check(prep.playing and is_zero_approx(prep.volume_linear), "preparation playback begins in complete silence")
	music.advance_fades(PhaseMusic.FADE_SECONDS * 0.5)
	var halfway := prep.volume_linear
	check(halfway > 0.0 and halfway < db_to_linear(PhaseMusic.MUSIC_DB), "preparation fades in gradually")
	prep.seek(10.0)
	music.transition_to("prep")
	check(is_equal_approx(prep.volume_linear, halfway) and prep.get_playback_position() >= 9.9,
		"same track keeps playback position and current volume")
	music.advance_fades(PhaseMusic.FADE_SECONDS * 0.5)
	check(is_equal_approx(prep.volume_linear, db_to_linear(PhaseMusic.MUSIC_DB)), "fade reaches configured music volume")
	music.transition_to("battle")
	check(prep.playing and combat.playing and is_zero_approx(combat.volume_linear), "crossfade starts battle silently without cutting preparation")
	music.advance_fades(PhaseMusic.FADE_SECONDS * 0.5)
	check(prep.volume_linear > 0.0 and combat.volume_linear > 0.0 and combat.volume_linear < db_to_linear(PhaseMusic.MUSIC_DB),
		"both music voices overlap during crossfade")
	var prep_before := prep.volume_linear
	var battle_before := combat.volume_linear
	music.transition_to("prep")
	check(is_equal_approx(prep.volume_linear, prep_before) and is_equal_approx(combat.volume_linear, battle_before),
		"rapid phase reversal preserves current gains without jumps")
	music.advance_fades(PhaseMusic.FADE_SECONDS)
	check(prep.playing and not combat.playing and is_zero_approx(combat.volume_linear), "outgoing voice stops only at silence")
	music.transition_to("")
	check(prep.playing and prep.volume_linear > 0.0, "music stop request starts a fade instead of cutting playback")
	music.advance_fades(PhaseMusic.FADE_SECONDS * 0.5)
	check(prep.playing and prep.volume_linear > 0.0 and prep.volume_linear < prep_before * 2,
		"stop fade has an audible intermediate level")
	music.advance_fades(PhaseMusic.FADE_SECONDS)
	check(not prep.playing and not combat.playing and is_zero_approx(prep.volume_linear), "stop fade ends in silence")
	music.free()

	var game = load("res://main.tscn").instantiate()
	add_child(game)
	check(game.music.current == "prep", "pack choice uses preparation music")
	game.choose_pack(0)
	check(game.music.current == "prep", "preparation keeps its music")
	_finish_enemy_preparation(game)
	game.start_combat()
	check(game.music.current == "battle", "combat selects battle music")
	game.battle.time = 56.75
	game.battle.step(0.25)
	check(is_equal_approx(game.music.players.battle.pitch_scale, 1.25)
		and is_equal_approx(game.music.players.prep.pitch_scale, 1.0),
		"frenzy speeds up only the battle music")
	game._on_battle_ended({"winner": 1, "survivors": 1})
	check(game.music.current == "", "resolution fades out battle music for heart and gold effects")
	game._finish_round()
	check(game.music.current == "prep", "next round fades preparation music back in")
	_finish_enemy_preparation(game)
	game.start_combat()
	check(is_equal_approx(game.music.players.battle.pitch_scale, 1.0), "next combat starts at normal music speed")
	game.player.hp = 0.5
	game._on_battle_ended({"winner": 1, "survivors": 1})
	game._finish_round()
	check(game.phase == game.Phase.OVER and game.music.current == "", "game over keeps music faded out")
	game.new_duel()
	check(game.music.current == "prep", "restart fades preparation music in")
	game.free()


func _test_result_recordings() -> void:
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	var voice: AudioStreamPlayer = Sfx._result_player
	voice.stop()
	Sfx._last_played.erase("win")
	Sfx._last_played.erase("lose")
	game._on_battle_ended({"winner": 0, "survivors": 1})
	check(not voice.playing and not Sfx._last_played.has("win"), "intermediate victory has no result recording")
	game._on_battle_ended({"winner": 1, "survivors": 1})
	check(not voice.playing and not Sfx._last_played.has("lose"), "intermediate defeat has no result recording")
	game._on_battle_ended({"winner": -1, "survivors": 0})
	check(not voice.playing, "draw has no result recording")
	game.enemy.hp = 0.5
	game._on_battle_ended({"winner": 0, "survivors": 1})
	check(not voice.playing, "final victory waits for the heart sequence")
	game.battle = Battle.new()
	game.add_child(game.battle)
	game._finish_round()
	check(game.phase == game.Phase.OVER and voice.stream.resource_path == "res://sfx/victory.wav" and voice.playing,
		"final duel victory plays supplied victory recording on game over")
	check(voice.pitch_scale == 1.0 and voice.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED,
		"result recording plays once at its original pitch")
	game.new_duel()
	voice.stop()
	Sfx._last_played.erase("lose")
	game.music.transition_to("battle")
	game.music.advance_fades(PhaseMusic.FADE_SECONDS)
	game.player.hp = 0.5
	game._on_battle_ended({"winner": 1, "survivors": 1})
	check(not voice.playing and game.music.current == "", "final defeat fades music and waits for the heart sequence")
	game.music.advance_fades(PhaseMusic.FADE_SECONDS)
	check(not game.music.players.battle.playing and not game.music.players.prep.playing,
		"music is stopped after defeat fade")
	game.battle = Battle.new()
	game.add_child(game.battle)
	game._finish_round()
	check(game.phase == game.Phase.OVER and voice.stream.resource_path == "res://sfx/defeat.wav" and voice.playing,
		"final duel defeat plays supplied defeat recording on game over")
	for i in Sfx.VOICES + 2:
		Sfx._last_played.erase("heart_break")
		Sfx.play("heart_break")
	check(voice.stream.resource_path == "res://sfx/defeat.wav" and voice.playing,
		"heart effects cannot steal or interrupt the result voice")
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


func _test_frenzy() -> void:
	var b := _new_battle()
	var ally := b.spawn(0, "peasant", Vector2(200, 300))
	var foe := b.spawn(1, "peasant", Vector2(200, 80))
	var speed := ally.move_speed()
	var interval := ally.attack_interval()
	ally.stun_t = 60.0
	foe.stun_t = 60.0
	b.time = 44.5
	b.step(0.25)
	check(b.frenzy_level == 0, "combat has no frenzy before 45 seconds")

	ally.attack_timer = interval
	b.spells[0].charges = 0
	b.spells[1].charges = 0
	b.spells[0].recharge = 0.0
	b.spells[1].recharge = 0.0
	b.spells[1].recharge_time = Rules.UPGRADED_RECHARGE_TIME
	b.step(0.25)
	check(b.frenzy_level == 1 and is_equal_approx(ally.move_speed(), speed * 1.2),
		"frenzy starts at 45 seconds and boosts movement by 20%")
	check(is_equal_approx(ally.attack_interval(), interval / 1.2)
		and is_equal_approx(ally.attack_timer, interval - 0.25 * 1.2),
		"frenzy speeds up basic attacks already on cooldown")
	check(is_equal_approx(b.spells[0].recharge, 0.25) and is_equal_approx(b.spells[1].recharge, 0.25)
		and b.spells[0].recharge_time == Rules.RECHARGE_TIME
		and b.spells[1].recharge_time == Rules.UPGRADED_RECHARGE_TIME,
		"frenzy leaves normal and upgraded shapeshift recharge rates intact")
	b.damage(ally, foe, 10.0, "melee")
	check(is_equal_approx(foe.hp, foe.max_hp - 12.0), "frenzy boosts damage dealt by 20%")

	for level in range(2, 6):
		b.step(3.0)
		check(b.frenzy_level == level, "frenzy gains a level every three seconds")
	check(is_equal_approx(b.frenzy_multiplier(), 2.0), "frenzy doubles damage and speed at 57 seconds")
	b.step(3.0)
	check(b.finished and b.result.winner == -1, "surviving teams still draw at 60 seconds")
	b.free()


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
	var rear := b.spawn(1, "archer", Vector2(240, 50))
	rabbit.tick(0.01)
	check(rabbit.jump_t > 0.0 and rabbit.jump_target == rear, "rabbit leaps to deepest enemy rather than nearby frontline")
	rabbit._tick_jump(0.5)
	check(rabbit.target == rear and rabbit.position.y < rear.position.y, "rabbit lands behind and engages its backline target")
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


func _test_bard_song() -> void:
	var b := _new_battle()
	var bard := b.spawn(0, "bard", Vector2(40, 400))
	var far := b.spawn(0, "duelist", Vector2(540, 40)) # opposite corner of the board
	var foe := b.spawn(1, "guardian", Vector2(300, 60))
	var interval := far.attack_interval()
	bard._tick_ability()
	check(bard.ability_timer > 0.0 and not far.statuses.has("inspired"), "song waits for its first beat")
	bard.ability_timer = 0.0
	bard._tick_ability()
	check(far.statuses.has("inspired") and bard.statuses.has("inspired") and not foe.statuses.has("inspired"),
		"one beat inspires every ally on the battlefield, the bard included, and no enemy")
	check(is_equal_approx(far.statuses.inspired.t, 3.0) and is_equal_approx(bard.ability_timer, 1.0),
		"song beats every second and inspires for three seconds")
	check(is_equal_approx(far.attack_interval(), interval / 1.35), "inspired allies attack 35% faster")
	b.damage(null, bard, bard.max_hp, "ability")
	b._reap()
	far._tick_statuses(2.9)
	check(far.statuses.has("inspired"), "inspiration outlasts the bard's death until it expires")
	far._tick_statuses(0.2)
	check(not far.statuses.has("inspired"), "inspiration expires three seconds after the last beat")
	b.free()


func _test_mage_attacks() -> void:
	var b := _new_battle()
	var frost := b.spawn(0, "frost_mage", Vector2(200, 300))
	var guard := b.spawn(1, "guardian", Vector2(200, 170))
	var speed := guard.move_speed()
	var interval := guard.attack_interval()
	guard.attack_timer = interval
	frost._attack(guard)
	b._update_projectiles(1.0)
	check(is_equal_approx(guard.move_speed(), speed * 0.5) and is_equal_approx(guard.attack_interval(), interval * 2.0),
		"frost shot halves movement and basic attack rates")
	guard.tick(0.4)
	check(is_equal_approx(guard.attack_timer, interval - 0.2), "chill slows a basic attack already recharging")
	guard.tick(0.8)
	check(is_equal_approx(guard.attack_timer, interval - 0.7) and is_equal_approx(guard.move_speed(), speed),
		"attack recharge returns to full speed when chill expires mid-tick")
	b.free()

	b = _new_battle()
	var fire := b.spawn(0, "pyromancer", Vector2(240, 300))
	guard = b.spawn(1, "guardian", Vector2(240, 140))
	var neighbour := b.spawn(1, "turtle", Vector2(280, 140))
	var unburned := b.spawn(1, "guardian", Vector2(410, 300))
	fire._tick_ability()
	check(b.projectiles.is_empty(), "fireball has an initial cooldown")
	fire._attack(guard)
	b._update_projectiles(1.0)
	check(guard.statuses.has("burning") and neighbour.statuses.has("burning") and not unburned.statuses.has("burning"),
		"basic fire shot burns its target and enemies in splash range")
	var hp := guard.hp
	guard._tick_statuses(0.5)
	check(is_equal_approx(hp - guard.hp, 1.5), "burn ticks for damage reduced by armour")
	fire.target = guard
	fire.attack_timer = 0.0
	fire.tick(0.0)
	check(fire.target == unburned, "pyromancer switches to an unburned enemy when the next shot is ready")
	b._update_projectiles(1.0)

	fire.ability_timer = 0.0
	fire._tick_ability()
	fire.tick(0.75)
	check(b.projectiles.is_empty() and fire.channel_t > 0.0, "pyromancer does not attack during its fireball channel")
	fire.tick(0.25)
	check(b.projectiles.size() == 1 and fire.ability_timer == 15.0,
		"fireball starts its own long cooldown at launch")
	var projectile := b.projectiles[0]
	check(b.cast(1, fire), "enemy can transform pyromancer after launch")
	guard.position += Vector2(12, -20)
	b._update_projectiles(0.1)
	check(projectile.aim == guard.position and is_equal_approx(fire.position.distance_to(projectile.pos), 0.35 * Rules.CELL),
		"launched fireball still follows a moving enemy after caster transforms")
	b.damage(null, guard, guard.max_hp, "ability", true)
	b._reap()
	hp = neighbour.hp
	b._update_projectiles(2.0)
	check(is_equal_approx(hp - neighbour.hp, 120.0), "fireball retargets after a kill and ignores armour")
	b.free()


func _test_mage_interruptions() -> void:
	for form in ["pyromancer", "frost_mage"]:
		var b := _new_battle()
		var mage := b.spawn(1, form, Vector2(240, 150))
		b.spawn(0, "guardian", Vector2(240, 300))
		mage.ability_timer = 0.0
		mage.tick(0.0)
		check(mage.channel_t == 1.0 and b.projectiles.is_empty() and b.blizzards.is_empty(),
			"%s channels before releasing its ability" % form)
		var cooldown: float = mage.data.cd
		check(b.cast(0, mage), "channeling mage can be transformed")
		check(mage.channel_t == 0.0 and mage.ability_timer == cooldown,
			"%s loses the cast and starts its cooldown on interruption" % form)
		mage.tick(1.0)
		check(b.projectiles.is_empty() and b.blizzards.is_empty(), "interrupted ability never fires")
		b.free()


# --- Simulations ------------------------------------------------------------------------

## Plays AI-vs-AI duels to check the loop terminates and to report pacing.
func _test_overlapping_blizzards() -> void:
	var b := _new_battle()
	var mage := b.spawn(0, "frost_mage", Vector2(200, 300))
	var other_mage := b.spawn(0, "frost_mage", Vector2(260, 300))
	var victim := b.spawn(1, "peasant", Vector2(200, 170))
	var lone := b.spawn(1, "peasant", Vector2(380, 170))
	b.add_blizzard(mage, Vector2(200, 170))
	b.add_blizzard(other_mage, Vector2(236, 170)) # overlaps the first storm
	b.add_blizzard(other_mage, Vector2(380, 170))
	b._tick_blizzards(1.0)
	var single_storm_damage: float = mage.data.storm_dps
	check(absf(victim.max_hp - victim.hp - single_storm_damage) < 0.01
		and absf(lone.max_hp - lone.hp - single_storm_damage) < 0.01,
		"overlapping blizzards deal the damage of one storm, not their sum")
	check(victim.statuses.has("chilled") and is_equal_approx(victim.statuses.chilled.v, 0.5),
		"overlapping blizzards still chill once at full strength")
	b.free()


func _test_combat_click_casts() -> void:
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	game.choose_pack(0)
	game.enemy_preparing = false
	game.enemy_moves.clear()
	game.enemy_action.clear()
	if game.enemy.field_count() == 0:
		game.enemy.add_creature("peasant")
	game.start_combat()
	var b: Battle = game.battle
	b.spells[0].charges = 2
	var ally: Unit = b.living(0)[0]
	var foe: Unit = b.living(1)[0]
	game._right_press(Rules.BOARD_POS + foe.position)
	check(b.casts[0] == 0, "right-click no longer casts during combat")
	game._left_press(Rules.BOARD_POS + ally.position)
	check(b.casts[0] == 1 and game.fx.items.any(func(i): return i.kind == "shift_bless"),
		"left click shapeshifts an own creature with the blessing effect")
	game._left_press(Rules.BOARD_POS + foe.position)
	check(b.casts[0] == 2 and game.fx.items.any(func(i): return i.kind == "shift_hex"),
		"left click shapeshifts an enemy creature with the hex effect")
	var effects: int = game.fx.items.size()
	game._left_press(Vector2(20, 20))
	check(game.fx.items.size() == effects, "clicks outside the board neither cast nor fizzle")
	game.queue_free()


func _test_blizzard_and_recharge_upgrade() -> void:
	var b := _new_battle()
	var mage := b.spawn(0, "frost_mage", Vector2(200, 300))
	var victim := b.spawn(1, "archer", Vector2(200, 170))
	var neighbour := b.spawn(1, "cleric", Vector2(270, 160))
	var outside := b.spawn(1, "archer", Vector2(500, 150))
	var friend := b.spawn(0, "archer", Vector2(200, 170))
	mage.ability_timer = 0
	mage._tick_ability()
	mage.tick(1.0)
	check(b.blizzards.size() == 1 and b.blizzards[0].rect.size == Vector2.ONE * Rules.CELL * 3,
		"frost mage casts an exact 3x3 square blizzard")
	check(mage.ability_timer >= 8, "blizzard has a long cooldown")
	var speed := victim.move_speed()
	var interval := victim.attack_interval()
	b._tick_blizzards(1.0)
	check(victim.hp < victim.max_hp and neighbour.hp < neighbour.max_hp,
		"blizzard damages multiple enemies inside square")
	check(outside.hp == outside.max_hp and friend.hp == friend.max_hp,
		"blizzard spares allies and enemies outside square")
	check(is_equal_approx(victim.move_speed(), speed * 0.5) and is_equal_approx(victim.attack_interval(), interval * 2.0),
		"blizzard halves movement and basic attack rates")
	mage.transform_to("peacock", false)
	b._tick_blizzards(10.0)
	check(b.blizzards.is_empty() and absf(victim.max_hp - victim.hp - 21.6) < 0.01,
		"cast blizzard persists after form change and damage stops at duration")
	b.free()

	var p := WizardState.new(0)
	var e := WizardState.new(1)
	p.gold = Rules.SHIFT_RECHARGE_COST - 1
	check(not p.upgrade_shift_recharge(), "recharge upgrade requires its gold cost")
	p.gold = Rules.SHIFT_RECHARGE_COST
	check(p.upgrade_shift_recharge() and p.gold == 0, "recharge upgrade consumes exactly its cost")
	p.gold = 100
	check(not p.upgrade_shift_recharge() and p.gold == 100, "single recharge upgrade cannot be bought twice")
	p.add_creature("guardian")
	e.add_creature("guardian")
	b = _new_battle()
	var teams: Array[WizardState] = [p, e]
	b.setup(teams, 3)
	check(b.spells[0].recharge_time == 2.4 and b.spells[1].recharge_time == 3.0,
		"recharge upgrade applies only to owning wizard")
	b.spells[0].tick(2.39)
	check(b.spells[0].charges == 1, "upgraded charge is not granted early")
	b.spells[0].tick(0.02)
	check(b.spells[0].charges == 2 and b.spells[1].charges == 1,
		"upgraded charge recharges at 2.4 seconds")
	b.free()
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	game.choose_pack(0)
	game.player.gold = Rules.SHIFT_RECHARGE_COST
	game._left_press(Hud.SHIFT_UPGRADE_RECT.get_center())
	check(game.player.shift_recharge_upgraded and game.player.gold == 0, "recharge upgrade shop button works")
	game.new_duel()
	check(not game.player.shift_recharge_upgraded, "new duel resets permanent duel upgrade")
	game.free()
	check(CreatureDB.get_form("assassin").price == 2, "assassin costs two gold")
	var guardian_outcomes := CreatureDB.outcomes("guardian")
	check(guardian_outcomes[0].id == "turtle" and guardian_outcomes[0].chance == 0.55,
		"dominant transformation follows guardian defensive identity")
	for id in CreatureDB.all_ids():
		var outcomes := CreatureDB.outcomes(id)
		check(outcomes[0].chance == 0.55 and outcomes[1].chance == 0.30 and outcomes[2].chance == 0.15,
			"ordered decreasing probabilities for " + id)


func _test_ai_strategy() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	var state := WizardState.new(1)
	state.add_creature("guardian")
	state.add_creature("guardian")
	state.offers = ["", "", ""]
	EnemyAI.shop_step(state, rng)
	check(state.field_count() == 2 and state.creatures[0].merge_copies == 1,
		"AI keeps two fielded bodies instead of merging for no star")
	state = WizardState.new(1)
	for id in ["guardian", "berserker", "spearman", "archer", "cleric", "frost_mage"]:
		state.add_creature(id)
	var guard: OwnedCreature = state.creatures[0]
	guard.merge_copies = 2
	state.gold = 2
	state.offers = ["guardian", "", ""]
	var action := EnemyAI.shop_step(state, rng)
	check(action.get("kind") == "buy" and state.gold == 0 and state.creatures.size() == 7,
		"AI buys a completing duplicate with a full field instead of stopping")
	action = EnemyAI.shop_step(state, rng)
	check(action.get("kind") == "merge" and guard.stars == 1 and state.field_count() == 6,
		"AI upgrades a full team without removing a fielded body")
	state.shift_recharge_upgraded = true
	state.gold = 4
	state.offers = ["peasant", "", ""]
	action = EnemyAI.shop_step(state, rng)
	check(action.get("kind") == "reroll" and state.gold == 3, "AI spends gold rerolling unhelpful offers")
	state.shift_recharge_upgraded = false
	state.gold = 4
	state.offers = ["", "", ""]
	action = EnemyAI.shop_step(state, rng)
	check(action.get("kind") == "upgrade" and state.shift_recharge_upgraded and state.gold == 0,
		"AI buys recharge upgrade from its own gold")
	state.gold = 10
	state.ai_rerolls = 2
	state.offers = ["peasant", "", ""]
	action = EnemyAI.shop_step(state, rng)
	check(action.get("kind") == "reroll" and state.gold == 9, "AI keeps looking for improvements after two rerolls")
	state.gold = Rules.REROLL_COST
	state.offers = ["peasant", "", ""]
	check(EnemyAI.shop_step(state, rng).is_empty() and state.gold == Rules.REROLL_COST,
		"AI keeps its last coin when a reroll would leave nothing for a purchase")
	state.gold = 2
	state.offers = ["guardian", "", ""]
	action = EnemyAI.shop_step(state, rng)
	check(action.get("kind") == "buy" and state.gold == 0,
		"AI starts collecting copies towards the next star of a fielded unit")

	state = WizardState.new(1)
	for id in ["guardian", "berserker", "spearman", "archer", "cleric", "frost_mage"]:
		state.add_creature(id)
	for id in ["peasant", "duelist", "assassin", "crossbowman", "pyromancer", "bard"]:
		state.add_creature(id)
	guard = state.creatures[0]
	guard.merge_copies = 2
	state.gold = 2
	state.offers = ["guardian", "", ""]
	action = EnemyAI.shop_step(state, rng)
	check(action.get("kind") == "merge" and action.get("cost") == 2 and state.gold == 0
		and guard.stars == 1 and state.free_slot() == -1 and state.field_count() == Rules.FIELD_CAP,
		"AI pays for a direct promotion even when the field and bench are full")
	state = WizardState.new(1)
	for id in ["guardian", "berserker", "spearman", "archer", "cleric", "frost_mage"]:
		state.add_creature(id).stars = Rules.MAX_STARS
	state.shift_recharge_upgraded = true
	state.gold = 10
	state.offers = ["guardian", "pyromancer", ""]
	check(EnemyAI.shop_step(state, rng).is_empty() and state.gold == 10,
		"AI skips rerolls when the shop has no way to improve a max-rank team")
	var b := _new_battle()
	var weak_enemy := b.spawn(0, "peasant", Vector2(100, 350))
	b.spawn(1, "guardian", Vector2(100, 100))
	b.spells[1].charges = 3
	check(EnemyAI.choose_cast(b, 1) != weak_enemy, "AI avoids transforming a weak enemy into stronger expected forms")
	b.free()


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
				s.take_starting_pack(EnemyAI.choose_pack(rng))
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
					states[1 - b.result.winner].take_round_damage(b.result.survivors)
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
