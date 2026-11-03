extends Node
## Headless verification for the core SHIFT transaction rules.
## Run: Godot --headless --path . -- --selftest

var combat: CombatManager
var failures: int = 0
var checks: int = 0
var _made: Array = []


func run(combat_ref: CombatManager) -> int:
	combat = combat_ref
	print("=== SHIFT SELF TEST ===")
	_test_numeric()
	_test_conflicts()
	_test_health_proportional()
	_test_ability_exchange()
	_test_basic_exchange()
	_test_projectile_aim()
	_test_death_cleanup()
	await _test_expiry()
	_test_counter_choice()

	SwapManager.debug_restore_all()
	for c in _made:
		if is_instance_valid(c):
			c.queue_free()
	print("=== RESULT: %d/%d CHECKS PASSED ===" % [checks - failures, checks])
	if failures > 0:
		print("=== FAILURES: %d ===" % failures)
	return 0 if failures == 0 else 1


func _check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  PASS  " + label)
	else:
		failures += 1
		print("  FAIL  " + label)


func _wait_real(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _make(archetype: String, team: int, name: String) -> Character:
	var c := Character.new()
	c.setup(archetype, team, false, name)
	combat.world.add_child(c)
	c.global_position = Vector2(-500.0 - float(_made.size()) * 40.0, -500.0)
	c.set_physics_process(false)
	_made.append(c)
	return c


func _test_numeric() -> void:
	print("-- numeric swap + restore")
	var a := _make("Runner", 0, "T_A")
	var b := _make("Bruiser", 1, "T_B")
	var a_speed := float(a.get_stat("speed"))
	var b_speed := float(b.get_stat("speed"))
	var a_str := float(a.get_stat("strength"))
	var b_str := float(b.get_stat("strength"))

	_check(SwapManager.perform_swap(a, b, "speed", "test", false), "speed swap accepted")
	_check(is_equal_approx(float(a.get_stat("speed")), b_speed), "A received B speed")
	_check(is_equal_approx(float(b.get_stat("speed")), a_speed), "B received A speed")
	_check(not SwapManager.get_swap_for(a, "speed").is_empty(), "active swap recorded")
	_check(SwapManager.get_swap_for(a, "speed") == SwapManager.get_swap_for(b, "speed"), "both entities share one record")

	_check(SwapManager.perform_swap(a, b, "strength", "test", false), "second attribute swap accepted")
	_check(is_equal_approx(float(a.get_stat("strength")), b_str), "A received B strength")
	_check(is_equal_approx(float(b.get_stat("strength")), a_str), "B received A strength")
	_check(SwapManager.swaps.size() == 2, "two independent swaps tracked")

	SwapManager.debug_restore_all()
	_check(is_equal_approx(float(a.get_stat("speed")), a_speed), "A speed restored")
	_check(is_equal_approx(float(b.get_stat("speed")), b_speed), "B speed restored")
	_check(is_equal_approx(float(a.get_stat("strength")), a_str), "A strength restored")
	_check(is_equal_approx(float(b.get_stat("strength")), b_str), "B strength restored")
	_check(SwapManager.swaps.is_empty(), "ledger empty after restore")


func _test_conflicts() -> void:
	print("-- conflict prevention")
	var a := _make("Runner", 0, "T_C")
	var b := _make("Bruiser", 1, "T_D")
	var c := _make("Tank", 0, "T_E")
	var a_speed := float(a.get_stat("speed"))
	var b_speed := float(b.get_stat("speed"))
	var c_speed := float(c.get_stat("speed"))

	_check(SwapManager.perform_swap(a, b, "speed", "test", false), "A-B speed swap accepted")
	_check(not SwapManager.perform_swap(a, c, "speed", "test", false), "A-C speed swap rejected (conflict)")
	_check(is_equal_approx(float(a.get_stat("speed")), b_speed), "A value untouched by rejected swap")
	_check(is_equal_approx(float(c.get_stat("speed")), c_speed), "C value untouched by rejected swap")
	_check(SwapManager.get_attr_options().is_empty(), "no options without a selection")

	SwapManager.debug_restore_all()
	_check(is_equal_approx(float(a.get_stat("speed")), a_speed), "A restored after cleanup")


func _test_health_proportional() -> void:
	print("-- proportional health exchange")
	var a := _make("Ranger", 0, "T_F")
	var b := _make("Tank", 1, "T_G")
	a.apply_stat("health", 100.0, 1.0)
	a.health = 80.0
	b.apply_stat("health", 200.0, 1.0)
	b.health = 50.0

	_check(SwapManager.perform_swap(a, b, "health", "test", false), "health swap accepted")
	_check(is_equal_approx(a.max_health(), 200.0), "A max health became 200")
	_check(is_equal_approx(a.health, 160.0), "A kept 80% health (160/200)")
	_check(is_equal_approx(b.max_health(), 100.0), "B max health became 100")
	_check(is_equal_approx(b.health, 25.0), "B kept 25% health (25/100)")

	# Damage during the swap must survive restoration proportionally.
	a.health = 100.0
	b.health = 5.0
	SwapManager.debug_restore_all()
	_check(is_equal_approx(a.max_health(), 100.0), "A max health restored")
	_check(is_equal_approx(a.health, 50.0), "A restored preserving 50%")
	_check(is_equal_approx(b.max_health(), 200.0), "B max health restored")
	_check(is_equal_approx(b.health, 10.0), "B restored preserving 5%")


func _test_ability_exchange() -> void:
	print("-- modular ability exchange")
	var a := _make("Runner", 0, "T_H")
	var b := _make("Ranger", 1, "T_I")
	var a_ability := a.current_ability().id
	var b_ability := b.current_ability().id
	_check(a_ability != b_ability, "start with different abilities")

	_check(SwapManager.perform_swap(a, b, "special", "test", false), "special swap accepted")
	_check(a.current_ability().id == b_ability, "A now equips B ability")
	_check(b.current_ability().id == a_ability, "B now equips A ability")

	a.special_cd = 0.0
	var used := a.try_special()
	_check(used, "A can immediately use stolen ability")
	_check(a.special_cd > 0.0, "stolen ability consumed A's special cooldown")

	var a_cd := float(a.get_stat("special_cooldown"))
	var b_cd := float(b.get_stat("special_cooldown"))
	_check(SwapManager.perform_swap(a, b, "special_cooldown", "test", false), "special cooldown swap accepted")
	_check(is_equal_approx(float(a.get_stat("special_cooldown")), b_cd), "A received B special cooldown")
	_check(is_equal_approx(float(b.get_stat("special_cooldown")), a_cd), "B received A special cooldown")

	SwapManager.debug_restore_all()
	_check(a.current_ability().id == a_ability, "A base ability restored")
	_check(b.current_ability().id == b_ability, "B base ability restored")


func _test_basic_exchange() -> void:
	print("-- basic attack exchange")
	var a := _make("Runner", 0, "T_BASIC_A")
	var b := _make("Ranger", 1, "T_BASIC_B")
	var a_basic := a.current_basic().id
	var b_basic := b.current_basic().id
	_check(a_basic != b_basic, "start with different basic attacks")
	_check(a.is_melee(), "Runner starts melee")

	_check(SwapManager.perform_swap(a, b, "basic", "test", false), "basic attack swap accepted")
	_check(a.current_basic().id == b_basic, "A now has B basic attack")
	_check(b.current_basic().id == a_basic, "B now has A basic attack")
	_check(not a.is_melee(), "A's combat style follows stolen ranged basic")
	_check(b.is_melee(), "B's combat style follows stolen melee basic")

	a.attack_cd = 0.0
	a.stun_time = 0.0
	_check(a.try_basic_attack(), "A can attack with stolen basic")
	_check(a.attack_cd > 0.0, "stolen basic consumed attack cooldown")

	SwapManager.debug_restore_all()
	_check(a.current_basic().id == a_basic, "A base basic attack restored")
	_check(b.current_basic().id == b_basic, "B base basic attack restored")


func _test_projectile_aim() -> void:
	print("-- projectile aim direction")
	var r := _make("Ranger", 1, "T_PROJ")
	var dir := Vector2(0.22, 1.0).normalized()
	r.spawn_projectile(dir, 1.0, 0.0, Color.WHITE, 400.0, 5.0)
	var found := false
	var correct := false
	for n in combat.world.get_children():
		if n is Projectile and n.owner_char == r:
			found = true
			correct = n.direction.dot(dir) > 0.999
			n.queue_free()
	_check(found, "projectile spawned")
	_check(correct, "projectile direction matches aim")


func _test_death_cleanup() -> void:
	print("-- death cleanup")
	var a := _make("Runner", 0, "T_J")
	var b := _make("Bruiser", 1, "T_K")
	var a_speed := float(a.get_stat("speed"))
	var b_speed := float(b.get_stat("speed"))
	_check(SwapManager.perform_swap(a, b, "speed", "test", false), "swap before death accepted")
	_check(is_equal_approx(float(a.get_stat("speed")), b_speed), "A holds B speed")

	b.die()
	_check(is_equal_approx(float(a.get_stat("speed")), a_speed), "survivor restored when partner dies")
	_check(SwapManager.get_swaps_for(b).is_empty(), "dead entity has no active swaps")
	_check(SwapManager.get_swaps_for(a).is_empty(), "survivor's link cleaned")


func _test_expiry() -> void:
	print("-- timed expiry")
	var old_duration := GameConfig.swap_duration
	GameConfig.swap_duration = 0.25
	var a := _make("Trickster", 0, "T_L")
	var b := _make("Tank", 1, "T_M")
	var a_weight := float(a.get_stat("weight"))
	var b_weight := float(b.get_stat("weight"))
	_check(SwapManager.perform_swap(a, b, "weight", "test", false), "timed swap accepted")
	_check(is_equal_approx(float(a.get_stat("weight")), b_weight), "A holds B weight")
	await _wait_real(0.45)
	_check(is_equal_approx(float(a.get_stat("weight")), a_weight), "A weight auto-restored")
	_check(is_equal_approx(float(b.get_stat("weight")), b_weight), "B weight auto-restored")
	_check(SwapManager.swaps.is_empty(), "ledger cleared after expiry")
	GameConfig.swap_duration = old_duration


func _test_counter_choice() -> void:
	print("-- counter-swap utility choice")
	var excluded := "strength"
	var source: Character = null
	for e in combat.enemy_team:
		if e.alive:
			source = e
			break
	_check(source != null, "living targeted enemy available")
	if source == null:
		return
	var plan := combat.counter_ai.choose_counter(excluded, source)
	_check(not plan.is_empty(), "counter AI found a legal swap")
	if plan.is_empty():
		return
	var a: Character = plan["a"]
	var b: Character = plan["b"]
	var attr := str(plan["attr"])
	_check(a == source, "counter originates from the targeted enemy")
	_check(attr != excluded, "counter used a different attribute")
	_check(b.team == Character.TEAM_PLAYER, "counter steals from a player-team entity")
	_check(a != b and a.alive and b.alive, "counter plan targets two living entities")
	_check(not SwapManager.has_conflict(a, b, attr), "counter plan respects active-swap locks")
