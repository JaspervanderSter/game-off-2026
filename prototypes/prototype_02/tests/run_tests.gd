extends Node
## Headless rule tests and combat simulations for Prototype 02.
## Run from prototypes/prototype_02:
##   godot --headless --path . res://tests/run_tests.tscn

var _failures := 0
var _checks := 0


func _ready() -> void:
	_test_network()
	_test_families()
	_test_charges()
	_test_transformation_rules()
	_test_immunity_and_invalid_casts()
	_test_attack_timing()
	_test_momentum()
	_test_economy()
	_test_shop_and_merges()
	_test_preparation_input()
	_test_round_reset_and_damage()
	_test_abilities()
	_test_specials()
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
	check(ids.size() == 24, "24 forms across six families")
	check(CreatureDB.BASE_FORMS.size() == 6, "six purchasable archetypes")
	var base_count := 0
	for id in ids:
		check(CreatureDB.FORMS.has(id), "form data for " + id)
		if CreatureDB.FORMS[id].base:
			base_count += 1
	check(base_count == 6, "six base forms")
	for family in CreatureDB.FAMILIES:
		var forms: Array = CreatureDB.FAMILIES[family]
		check(forms.size() == 4, "four forms in " + family)
		check(CreatureDB.get_form(forms[0]).base, "first form is the base for " + family)
		for i in forms.size():
			var id: String = forms[i]
			check(CreatureDB.family_of(id) == family, id + " belongs to " + family)
			check(CreatureDB.stage_of(id) == i, "%s is stage %d" % [id, i])
			if i < forms.size() - 1:
				check(CreatureDB.next_form(id) == forms[i + 1], "%s upgrades to %s" % [id, forms[i + 1]])
			else:
				check(CreatureDB.is_final_stage(id), id + " is the final stage")
				check(CreatureDB.next_form(id) == id, "final stage refreshes in place")


func _test_families() -> void:
	check(CreatureDB.FAMILIES.size() == 6, "six families")
	check(CreatureDB.shop_ids().size() == 6, "shop sells six base forms")
	for id in CreatureDB.shop_ids():
		check(CreatureDB.get_form(id).base, "shop form is a base form: " + id)
	check(CreatureDB.get_form("vanguard").ability == "guard", "vanguard guards")
	check(CreatureDB.get_form("striker").ability == "backline", "striker reaches backline")
	check(CreatureDB.get_form("ranger").attack_kind == "projectile", "ranger is ranged")
	check(CreatureDB.get_form("mystic").ability == "chill", "mystic controls movement")
	check(CreatureDB.get_form("support").ability == "heal", "support heals")
	check(CreatureDB.get_form("berserker").ability == "berserk", "berserker rages")
	check(CreatureDB.get_form("bear").attack_style == "smash", "bear smashes")
	check(CreatureDB.get_form("fox").attack_style == "slash", "fox slashes")
	check(CreatureDB.get_form("hawk").attack_kind == "projectile", "hawk is ranged")
	check(CreatureDB.get_form("raven").ability == "chill", "raven controls")
	check(CreatureDB.get_form("unicorn")["special"]["power"] > 0, "unicorn has a special")
	check(CreatureDB.get_form("badger")["ability"] == "thorns", "badger retaliates")
	check(CreatureDB.get_form("rhino")["special"]["id"] == "stampede", "rhino stamps")
	# Every animal has a special; base forms do not.
	for family in CreatureDB.FAMILIES:
		var forms: Array = CreatureDB.FAMILIES[family]
		check(not forms[0].is_empty() and not CreatureDB.get_form(forms[0]).has("special"), "base has no special: " + forms[0])
		for i in range(1, forms.size()):
			var form: Dictionary = CreatureDB.get_form(forms[i])
			check(form.has("special"), "animal has a special: " + forms[i])
			check(form["special"].has("id") and form["special"].has("type"), "special is data-driven: " + forms[i])
			check(form["special"].has("auto"), "special has an auto condition: " + forms[i])
	check(CreatureDB.FAMILIES["support"] == ["support", "doe", "songbird", "unicorn"], "support ladder escalates")


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
	var ally := b.spawn(0, "vanguard", Vector2(100, 300))
	var foe := b.spawn(1, "striker", Vector2(400, 50))
	b.spells[0].charges = 3
	ally.hp = ally.max_hp * 0.5
	ally.attack_timer = 1.0
	ally.add_status("poisoned", 3.0, 5.0, false)
	ally.add_status("inspired", 2.0, 0.35, true)
	ally.ability_timer = 2.5
	check(b.cast(0, ally), "cast on ally succeeds")
	check(ally.form_id == "bear", "vanguard upgrades to its first animal")
	ally.immune_t = 0.0
	check(absf(ally.max_hp - ally.data.hp) < 0.01, "no temporary level bonus")
	check(absf(ally.hp / ally.max_hp - 0.6) < 0.001, "50% health becomes 60%")
	check(ally.attack_timer == 0.0, "attack readied")
	check(not ally.statuses.has("poisoned"), "negative status cleansed")
	check(ally.statuses.has("inspired"), "positive status kept")
	check(absf(ally.ability_timer - 2.5) < 0.001, "ability cooldown carried over")
	check(absf(ally.attack_damage() - ally.data.dmg) < 0.01, "basic damage is the form value")
	# Enemy cast preserves health percentage and heals, but grants no level.
	foe.hp = foe.max_hp * 0.95
	check(b.cast(0, foe), "cast on enemy succeeds")
	check(foe.form_id == "fox", "enemy striker upgrades to fox")
	check(absf(foe.hp - foe.max_hp) < 0.01, "heal capped at full health")
	# Entering a form with a cooldown does not get an instant ability.
	var fresh := b.spawn(0, "support", Vector2(200, 300))
	fresh.ability_timer = 0.0
	b.spells[0].charges = 3
	b.cast(0, fresh)
	check(fresh.form_id == "doe", "support upgrades to doe")
	check(fresh.ability_timer == float(fresh.data.get("cd", 0.0)), "no instant ability on entry")
	# Animal stages require their special before the next upgrade.
	var gated := b.spawn(0, "vanguard", Vector2(250, 300))
	b.spells[0].charges = 3
	check(b.cast(0, gated), "base form upgrades without a special")
	check(gated.form_id == "bear", "gated animal is bear")
	gated.immune_t = 0.0
	var charges_before := b.spells[0].charges
	check(not b.cast(0, gated), "upgrade blocked until special is used")
	check(b.spells[0].charges == charges_before, "blocked upgrade consumes no charge")
	check(b.trigger_special(0, gated, true), "manual special succeeds")
	check(gated.special_used, "special is marked used")
	check(b.cast(0, gated), "special unlocks the next upgrade")
	check(gated.form_id == "turtle", "bear upgrades to turtle")
	# Final stage refreshes instead of changing form.
	var maxed := b.spawn(0, "rhino", Vector2(350, 300))
	maxed.hp = maxed.max_hp * 0.5
	b.spells[0].charges = 3
	check(b.cast(0, maxed), "final stage cast refreshes")
	check(maxed.form_id == "rhino", "final stage keeps its form")
	check(maxed.hp / maxed.max_hp >= 0.6, "final stage refresh heals")
	check(not maxed.special_used, "final stage refresh resets the special")
	# Permanent stars persist and scale the new form.
	var starred := b.spawn(0, "vanguard", Vector2(400, 300))
	starred.stars = 2
	starred.max_hp = starred.data.hp * Rules.star_mult(2)
	starred.hp = starred.max_hp
	b.spells[0].charges = 3
	b.cast(0, starred)
	check(starred.stars == 2, "stars survive transformation")
	check(absf(starred.max_hp - starred.data.hp * Rules.star_mult(2)) < 0.01,
		"star multiplier applies to the new form")
	b.free()


func _test_immunity_and_invalid_casts() -> void:
	var b := _new_battle()
	var u := b.spawn(0, "ranger", Vector2(100, 300))
	b.spawn(1, "ranger", Vector2(400, 50))
	b.spells[0].charges = 3
	b.spells[1].charges = 3
	check(b.cast(0, u), "first cast")
	check(u.dodge_t > 0.0, "transformation opens a dodge window")
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
	b.free()


# --- Attack timing ------------------------------------------------------------------

func _test_attack_timing() -> void:
	# Interrupt an attacker during its windup.
	var b := _new_battle()
	var striker := b.spawn(0, "striker", Vector2(200, 200))
	var victim := b.spawn(1, "ranger", Vector2(240, 200))
	striker.attack_timer = 0.0
	striker.tick(0.01)
	check(striker.pending_target != null, "attack starts with a windup")
	var hp_before := victim.hp
	b.spells[0].charges = 3
	check(b.cast(0, striker), "interrupting cast succeeds")
	check(not striker.has_pending_attack(), "windup cancelled")
	check(absf(striker.attack_timer - Rules.SHIFT_ATTACK_RECOVERY) < 0.001,
		"interrupted attacker gets recovery")
	check(absf(victim.hp - hp_before) < 0.001, "interrupted attack deals no damage")
	b.free()

	# A committed attack still lands.
	b = _new_battle()
	striker = b.spawn(0, "striker", Vector2(200, 200))
	victim = b.spawn(1, "ranger", Vector2(240, 200))
	striker.attack_timer = 0.0
	striker.tick(0.01)
	striker.tick(0.2)
	check(victim.hp < victim.max_hp, "committed attack lands")

	# Projectile dodge during the short window.
	var d := _new_battle()
	var ranger := d.spawn(0, "ranger", Vector2(100, 300))
	var target := d.spawn(1, "vanguard", Vector2(300, 300))
	d.spawn_projectile(ranger, target)
	d.spells[0].charges = 3
	check(d.cast(0, target), "target transformation succeeds")
	var hp_after_cast := target.hp
	check(target.dodge_t > 0.0, "dodge window is active")
	d._update_projectiles(1.0)
	check(d.projectiles.is_empty(), "projectile is deflected")
	check(absf(target.hp - hp_after_cast) < 0.001, "dodge prevents projectile damage")
	d.free()

	# Without the dodge window the projectile hits.
	var e := _new_battle()
	ranger = e.spawn(0, "ranger", Vector2(100, 300))
	target = e.spawn(1, "vanguard", Vector2(300, 300))
	e.spawn_projectile(ranger, target)
	var hp_before_hit := target.hp
	e._update_projectiles(1.0)
	check(target.hp < hp_before_hit, "committed projectile damages the target")
	e.free()


func _test_momentum() -> void:
	var b := _new_battle()
	var u := b.spawn(0, "vanguard", Vector2(100, 300))
	b.spells[0].charges = 3
	check(b.cast(0, u), "first cast")
	check(u.momentum_pending and u.momentum_window_t == 0.0, "momentum waits for immunity")
	u.tick(3.05)
	check(u.immune_t == 0.0, "immunity expired")
	check(u.momentum_window_t > 0.0, "momentum window opens")
	b.spells[0].charges = 3
	u.special_used = true # unlock the staged upgrade for this momentum test
	check(b.cast(0, u), "second cast during window")
	check(u.statuses.has("momentum"), "combo grants momentum")
	check(u.momentum_window_t == 0.0, "combo resets the window")
	var base_interval: float = u.data.interval
	var base_damage: float = u.data.dmg
	check(u.attack_interval() < base_interval, "momentum speeds up attacks")
	check(u.attack_damage() > base_damage, "momentum increases damage")
	b.free()

	# Window expiry means no combo.
	b = _new_battle()
	u = b.spawn(0, "vanguard", Vector2(100, 300))
	b.spells[0].charges = 3
	b.cast(0, u)
	u.tick(3.05)
	check(u.momentum_window_t > 0.0, "window opens after immunity")
	u.tick(2.6)
	check(u.momentum_window_t == 0.0, "window expires")
	b.spells[0].charges = 3
	u.special_used = true
	b.cast(0, u)
	check(not u.statuses.has("momentum"), "late cast does not combo")
	b.free()

	# Disabled momentum never opens a window.
	b = _new_battle()
	b.momentum_enabled = false
	u = b.spawn(0, "vanguard", Vector2(100, 300))
	b.spells[0].charges = 3
	b.cast(0, u)
	u.tick(3.1)
	check(u.momentum_window_t == 0.0, "disabled momentum has no window")
	b.free()


# --- Economy and rounds ---------------------------------------------------------------

func _test_economy() -> void:
	check(Rules.income(1) == 3 and Rules.income(2) == 4 and Rules.income(5) == 7, "income 3, 4, 5...")
	var s := WizardState.new(0)
	var rng := RandomNumberGenerator.new()
	s.refresh_offers(rng)
	check(s.offers.size() == 3, "three offers")
	for id in s.offers:
		check(CreatureDB.get_form(id).base, "shop sells base archetypes only")
	s.offers = ["vanguard", "berserker", "ranger"]
	s.gold = 3
	check(s.buy(1) != null and s.gold == 0, "buy a 3-gold creature")
	check(s.buy(1) == null, "each offer bought once")
	check(s.buy(0) == null, "cannot buy without gold")
	var c: OwnedCreature = s.creatures[0]
	s.sell(c)
	check(s.gold == 3 and s.creatures.is_empty(), "sell for purchase price")
	s.gold = 100
	for i in 12:
		s.add_creature("vanguard")
	check(s.field_count() == 6 and s.benched().size() == 6, "6 fielded + 6 reserve")
	check(s.add_creature("vanguard") == null and not s.has_space(), "capacity reached")
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
	s.offers = ["vanguard", "ranger", "support"]
	var bought := s.buy(0)
	check(bought != null and not bought.is_fielded() and bought.slot == 0,
		"purchase goes to bench even with an empty board")
	check(s.field_count() == 0, "purchase never auto-fields")
	check(s.toggle_lock(1), "right-click can lock an offer")
	var gold := s.gold
	check(s.reroll(rng) and s.gold == gold - Rules.REROLL_COST, "reroll charges exactly once")
	check(s.offers[0] != "" and s.offers[1] == "ranger" and s.offers[2] != "support",
		"reroll fills sold slots, changes unlocked offers and keeps locks")
	s.refresh_offers(rng)
	check(s.offers[1] == "ranger" and s.locked[1], "locks persist into next round")
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
	m.offers = ["vanguard", "", ""]
	var first := m.buy(0)
	m.move_to_cell(first, Vector2i(3, 3))
	for i in 8:
		m.offers[0] = "vanguard"
		var result := m.buy(0)
		check(result != null and result in m.creatures, "purchase returns surviving merge result")
		if i == 1:
			check(first.stars == 2 and m.creatures.size() == 1, "three one-star copies merge")
	check(m.creatures.size() == 1 and first.stars == 3, "nine copies merge to three stars")
	check(first.cell == Vector2i(3, 3), "merge preserves fielded survivor and position")
	check(first.price() == 18, "merged sale preserves invested gold")
	for i in 2:
		var capped := m.add_creature("vanguard")
		capped.stars = 3
	m._merge(first)
	check(m.creatures.size() == 3 and first.stars == 3, "three-star rank never merges further")

	# Full-bench third-copy exception, and rejection without an available merge.
	var full := WizardState.new(0)
	full.gold = 100
	for i in Rules.RESERVE_CAP:
		var c := OwnedCreature.new("vanguard" if i < 2 else "ranger")
		c.slot = i
		full.creatures.append(c)
	full.offers = ["support", "vanguard", ""]
	gold = full.gold
	check(full.buy(0) == null and full.gold == gold and full.offers[0] == "support",
		"full bench rejects purchase even when the board has room")
	var merged := full.buy(1)
	check(merged != null and merged.stars == 2 and merged.slot >= 0 and full.benched().size() == 5,
		"full bench accepts a third copy and frees a slot by merging")
	var mixed := WizardState.new(0)
	var rank_two := mixed.add_creature("vanguard")
	rank_two.stars = 2
	mixed.add_creature("vanguard")
	mixed.offers = ["vanguard", "", ""]
	mixed.gold = 10
	mixed.buy(0)
	check(mixed.creatures.size() == 3 and rank_two.stars == 2, "different ranks do not merge")

	var foe := WizardState.new(1)
	foe.add_creature("vanguard")
	var b := _new_battle()
	var teams: Array[WizardState] = [m, foe]
	b.setup(teams, 12)
	var u: Unit = b.living(0)[0]
	check(u.stars == 3, "combat copies permanent stars")
	check(u.max_hp > CreatureDB.get_form("vanguard").hp * 3, "stars improve combat health")
	u.transform_to("bear", false)
	check(u.stars == 3 and first.stars == 3, "transformation keeps stars")
	check(absf(u.max_hp - u.data.hp * Rules.star_mult(3)) < 0.001,
		"star multiplier applies to the new form")
	b.free()
	b = _new_battle()
	b.setup(teams, 12)
	u = b.living(0)[0]
	check(u.stars == 3 and u.form_id == "vanguard", "next combat resets form but keeps stars")
	b.free()


func _test_preparation_input() -> void:
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	game.choose_pack(0)
	game.player.gold = 20
	var state: WizardState = game.player
	state.offers = ["vanguard", "ranger", "support"]
	var offer_pos := Hud.offer_rect(1).get_center()
	game._right_press(offer_pos)
	check(game.player.locked[1], "shop right-click locks offer through game input")
	game._left_press(Hud.REROLL_RECT.get_center())
	check(game.player.gold == 19 and game.player.offers[1] == "ranger", "reroll button refreshes through game input")
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
	p.add_creature("vanguard")
	e.add_creature("striker")
	var b := _new_battle()
	var teams: Array[WizardState] = [p, e]
	b.setup(teams, 11)
	b.spells[0].charges = 3
	b.cast(0, b.living(0)[0])
	check(p.creatures[0].form_id == "vanguard", "owned creature keeps its purchased form")
	var result := {}
	b.ended.connect(func(r): result.merge(r)) # lambdas capture locals by value
	for i in 6000:
		b.step(1.0 / 60.0)
		if b.finished:
			break
	check(b.finished and result.has("winner"), "combat ends")
	b.free()
	# Draw on timeout.
	var d := _new_battle()
	d.spawn(0, "turtle", Vector2(30, 400))
	d.spawn(1, "turtle", Vector2(540, 30))
	d.casting_enabled = false
	for i in 4000:
		d.step(1.0 / 60.0)
		if d.finished:
			break
	check(d.finished, "timeout ends combat")
	d.free()


func _test_abilities() -> void:
	# Vanguard guard aura.
	var b := _new_battle()
	var vanguard := b.spawn(0, "vanguard", Vector2(200, 200))
	var ally := b.spawn(0, "ranger", Vector2(240, 200))
	vanguard.tick(0.01)
	check(ally.statuses.has("guarded"), "vanguard guards nearby allies")
	check(ally.armour() > CreatureDB.get_form("ranger").armour, "guard adds armour")
	# Armour reduction.
	b.damage(null, vanguard, 100.0, "ability")
	check(absf(vanguard.max_hp - vanguard.hp - 60.0) < 0.01, "40% armour")
	# Thorns.
	var badger := b.spawn(1, "badger", Vector2(400, 100))
	var fox := b.spawn(0, "fox", Vector2(420, 120))
	b.damage(fox, badger, 10.0, "melee")
	check(absf(fox.max_hp - fox.hp - 7.0) < 0.01, "thorns reflect melee damage")
	# Chill slows movement.
	var mystic := b.spawn(0, "mystic", Vector2(100, 100))
	var target := b.spawn(1, "vanguard", Vector2(300, 100))
	var base_speed := target.move_speed()
	target.add_status("chilled", 2.0, 0.35, false)
	check(target.move_speed() < base_speed, "chill slows movement")
	# Berserker speeds up when hurt.
	var berserker := b.spawn(0, "berserker", Vector2(100, 400))
	var full := berserker.attack_interval()
	berserker.hp = berserker.max_hp * 0.2
	check(berserker.attack_interval() < full * 0.6, "berserker speeds up")
	b.free()

	# Heal, cleanse and support.
	b = _new_battle()
	var support := b.spawn(0, "support", Vector2(200, 200))
	ally = b.spawn(0, "vanguard", Vector2(240, 200))
	ally.hp = ally.max_hp * 0.4
	ally.add_status("poisoned", 3.0, 5.0, false)
	support.ability_timer = 0.0
	var ally_hp := ally.hp
	support.tick(0.01)
	check(ally.hp > ally_hp, "support heals a wounded ally")
	var unicorn := b.spawn(0, "unicorn", Vector2(260, 200))
	unicorn.ability_timer = 0.0
	ally.hp = ally.max_hp * 0.4
	ally.add_status("poisoned", 3.0, 5.0, false)
	unicorn.tick(0.01)
	check(not ally.statuses.has("poisoned"), "unicorn cleanse removes negative effects")
	# Cleave.
	var bear := b.spawn(0, "bear", Vector2(200, 300))
	var fox_a := b.spawn(1, "fox", Vector2(240, 300))
	var fox_b := b.spawn(1, "fox", Vector2(260, 300))
	bear.attack_timer = 0.0
	bear.tick(0.01)
	bear.tick(0.5)
	check(fox_a.hp < fox_a.max_hp and fox_b.hp < fox_b.max_hp, "bear cleave hits nearby enemies")
	# Shell.
	var turtle := b.spawn(0, "turtle", Vector2(100, 500))
	turtle.ability_timer = 0.0
	turtle.last_hurt = b.time
	turtle.tick(0.01)
	check(turtle.shell_t > 0.0, "turtle enters its shell")
	check(turtle.armour() > CreatureDB.get_form("turtle").armour, "shell adds armour")
	# Charge, dive, hop and dazzle.
	var rhino := b.spawn(0, "rhino", Vector2(100, 200))
	var prey := b.spawn(1, "fox", Vector2(500, 200))
	rhino.target = prey
	rhino.ability_timer = 0.0
	rhino.tick(0.01)
	check(rhino.charging, "rhino charges a distant target")
	var eagle := b.spawn(0, "eagle", Vector2(100, 300))
	eagle.ability_timer = 0.0
	eagle.tick(0.01)
	check(eagle.dive_target != null, "eagle dives at a distant enemy")
	var rabbit := b.spawn(0, "rabbit", Vector2(200, 400))
	b.spawn(1, "striker", Vector2(230, 400))
	rabbit.ability_timer = 0.0
	rabbit.tick(0.01)
	check(rabbit.dash_t > 0.0, "rabbit hops away from melee pressure")
	var owl := b.spawn(0, "owl", Vector2(300, 400))
	var dazzled := b.spawn(1, "vanguard", Vector2(330, 400))
	owl.ability_timer = 0.0
	var before_dazzle := dazzled.attack_interval()
	owl.tick(0.01)
	check(dazzled.statuses.has("dazzled"), "owl dazzles nearby enemies")
	check(dazzled.attack_interval() > before_dazzle, "dazzle slows enemy attacks")
	# Inspire.
	var songbird := b.spawn(0, "songbird", Vector2(400, 400))
	var inspired := b.spawn(0, "vanguard", Vector2(430, 400))
	var before_inspire := inspired.attack_interval()
	songbird.tick(0.01)
	check(inspired.statuses.has("inspired"), "songbird inspires nearby allies")
	check(inspired.attack_interval() < before_inspire, "inspire speeds up attacks")
	# Backline targeting.
	b.free()
	b = _new_battle()
	var striker := b.spawn(0, "striker", Vector2(100, 500))
	var near_foe := b.spawn(1, "vanguard", Vector2(150, 500))
	var far_foe := b.spawn(1, "ranger", Vector2(500, 500))
	striker.target = null
	striker.hunted = false
	striker._choose_target(0.01)
	check(striker.target == far_foe, "striker seeks the farthest enemy")
	# Kite.
	b.free()
	b = _new_battle()
	var ranger := b.spawn(0, "ranger", Vector2(200, 550))
	b.spawn(1, "striker", Vector2(230, 550))
	ranger.attack_timer = 1.0
	var x_before := ranger.position.x
	ranger.tick(0.01)
	check(ranger.position.x < x_before, "ranger kites away from melee")
	# Splash projectile.
	b.free()
	b = _new_battle()
	var phoenix := b.spawn(0, "phoenix", Vector2(100, 100))
	var splash_a := b.spawn(1, "fox", Vector2(400, 100))
	var splash_b := b.spawn(1, "fox", Vector2(420, 100))
	phoenix.attack_timer = 0.0
	phoenix.tick(0.01)
	phoenix.tick(0.5)
	b._update_projectiles(1.0)
	check(splash_a.hp < splash_a.max_hp and splash_b.hp < splash_b.max_hp,
		"phoenix splash damages a cluster")
	b.free()


# --- Specials ---------------------------------------------------------------------------

func _test_specials() -> void:
	# Manual trigger spends a charge and applies the special once.
	var b := _new_battle()
	var rhino := b.spawn(0, "rhino", Vector2(100, 300))
	var enemy_a := b.spawn(1, "fox", Vector2(150, 300))
	var enemy_b := b.spawn(1, "fox", Vector2(170, 300))
	b.spells[0].charges = 3
	var enemy_hp := enemy_a.hp
	check(b.trigger_special(0, rhino, true), "manual special succeeds")
	check(b.spells[0].charges == 2, "manual special spends one charge")
	check(rhino.special_used, "special is marked used")
	check(not b.trigger_special(0, rhino, true), "special cannot be used twice")
	check(enemy_a.dash_t > 0.0 and enemy_b.dash_t > 0.0, "stampede knocks enemies away")
	check(enemy_a.statuses.has("dazzled") and enemy_b.statuses.has("dazzled"), "stampede staggers enemies")
	b.free()

	# Automatic trigger is free and only fires once.
	b = _new_battle()
	var bear := b.spawn(0, "bear", Vector2(100, 300))
	var auto_a := b.spawn(1, "fox", Vector2(140, 300))
	var auto_b := b.spawn(1, "fox", Vector2(160, 300))
	b.spells[0].charges = 3
	bear.special_lockout = 0.0
	var charges_before := b.spells[0].charges
	var auto_hp := auto_a.hp
	bear._tick_special(0.25)
	check(bear.special_used, "auto special triggers")
	check(b.spells[0].charges == charges_before, "auto special is free")
	check(auto_a.hp < auto_hp, "auto roar damages nearby enemies")
	b.free()

	# Leap special.
	b = _new_battle()
	var fox := b.spawn(0, "fox", Vector2(100, 300))
	var far_fox := b.spawn(1, "ranger", Vector2(400, 300))
	b.spells[0].charges = 3
	var far_hp := far_fox.hp
	check(b.trigger_special(0, fox, true), "pounce succeeds")
	check(fox.position.distance_to(far_fox.position) < 100.0, "fox lands near its target")
	check(far_hp - far_fox.hp > 20.0, "pounce damages the target")
	b.free()

	# Area heal and cleanse.
	b = _new_battle()
	var unicorn := b.spawn(0, "unicorn", Vector2(200, 200))
	var wounded := b.spawn(0, "vanguard", Vector2(240, 200))
	wounded.hp = wounded.max_hp * 0.4
	wounded.add_status("poisoned", 3.0, 5.0, false)
	b.spells[0].charges = 3
	var hp_before := wounded.hp
	check(b.trigger_special(0, unicorn, true), "purify succeeds")
	check(wounded.hp > hp_before, "purify heals allies")
	check(not wounded.statuses.has("poisoned"), "purify cleanses allies")
	b.free()

	# Volley fires at several enemies.
	b = _new_battle()
	var hawk := b.spawn(0, "hawk", Vector2(100, 300))
	b.spawn(1, "fox", Vector2(400, 300))
	b.spawn(1, "fox", Vector2(420, 300))
	b.spawn(1, "fox", Vector2(440, 300))
	b.spells[0].charges = 3
	check(b.trigger_special(0, hawk, true), "volley succeeds")
	check(b.projectiles.size() == 3, "volley fires at three enemies")
	b.free()

	# Evade and self-buff specials.
	b = _new_battle()
	var rabbit := b.spawn(0, "rabbit", Vector2(200, 300))
	b.spawn(1, "striker", Vector2(230, 300))
	b.spells[0].charges = 3
	check(b.trigger_special(0, rabbit, true), "evade succeeds")
	check(rabbit.dash_t > 0.0 and rabbit.dodge_t >= 1.0, "evade dashes and dodges")
	b.free()

	b = _new_battle()
	var wolverine := b.spawn(0, "wolverine", Vector2(200, 300))
	b.spells[0].charges = 3
	check(b.trigger_special(0, wolverine, true), "frenzy succeeds")
	check(wolverine.statuses.has("inspired"), "frenzy grants attack speed")
	b.free()

	# Retaliation special.
	b = _new_battle()
	var badger := b.spawn(0, "badger", Vector2(200, 300))
	var attacker := b.spawn(1, "fox", Vector2(230, 300))
	b.spells[0].charges = 3
	check(b.trigger_special(0, badger, true), "quills succeeds")
	check(badger.statuses.has("retaliate"), "quills grants retaliation")
	var attacker_hp := attacker.hp
	b.damage(attacker, badger, 10.0, "melee")
	check(attacker_hp - attacker.hp >= 15.0, "retaliation reflects damage")
	b.free()

	# Main input path: left-click triggers a friendly animal special.
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	game.choose_pack(0)
	game.start_combat()
	var unit: Unit = game.battle.living(0)[0]
	game.battle.spells[0].charges = 3
	check(game.battle.cast(0, unit), "input test transforms a base unit")
	unit.immune_t = 0.0
	game._left_press(Rules.BOARD_POS + unit.position)
	check(unit.special_used, "left-click triggers the animal special")
	game.free()


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
