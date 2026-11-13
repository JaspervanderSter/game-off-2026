class_name Battle
extends Node2D
## Real-time automatic combat between two teams, with both wizards casting
## shapeshift. Drive it with step(dt): the game calls it every physics frame,
## tests call it directly.

signal unit_died(unit: Unit)
signal unit_transformed(unit: Unit, caster_team: int, from_form: String)
signal fx_requested(kind: String, pos: Vector2, extra: Dictionary)
signal ended(result: Dictionary)

const CELL := Rules.CELL
const PROJECTILE_SPEED := 9.0 * Rules.CELL

var units: Array[Unit] = []
var projectiles: Array[Dictionary] = []
var blizzards: Array[Dictionary] = []
var spells: Array[ShiftSpell] = [ShiftSpell.new(), ShiftSpell.new()]
var ai_casting: Array[bool] = [false, true]
# Casting difficulty per team, copied from WizardState.ai_level in setup().
var ai_levels: Array[int] = [Difficulty.ARCHMAGE, Difficulty.ARCHMAGE]
var casting_enabled := true
var time := 0.0
var finished := false
var result := {}
var rng := RandomNumberGenerator.new()
var casts := [0, 0] # successful casts per team, for tests and tuning
# Per-team combat statistics (indexed by the team that received the effect),
# read by the balance suite. Damage counts HP actually lost (after armour,
# capped by remaining HP); healing counts HP actually restored.
var damage_taken := [0.0, 0.0]
var healing_received := [0.0, 0.0]
var parries := [0, 0]

var _ai_delay := [0.0, 0.0]
var _projectile_layer: Node2D


func _ready() -> void:
	_projectile_layer = Node2D.new()
	_projectile_layer.z_index = 2
	_projectile_layer.draw.connect(_draw_projectiles)
	add_child(_projectile_layer)


func setup(teams: Array[WizardState], seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for state in teams:
		ai_levels[state.team] = state.ai_level
		spells[state.team].recharge_time = state.shift_recharge_time()
		for c in state.fielded():
			spawn(state.team, c.form_id, Rules.cell_center(c.cell), c.uid, c.stars, c.merge_copies)
	for t in 2:
		var first: Vector2 = Difficulty.profile(ai_levels[t]).first_delay
		_ai_delay[t] = rng.randf_range(first.x, first.y)


func spawn(team: int, form: String, pos: Vector2, uid: int = 0, stars: int = 0, copies: int = 1) -> Unit:
	var u := Unit.new()
	u.stars = stars
	u.merge_copies = copies
	u.setup(self, uid, team, form, pos)
	units.append(u)
	add_child(u)
	return u


# --- Main loop ----------------------------------------------------------------

func step(dt: float) -> void:
	if finished:
		return
	time += dt
	for t in 2:
		spells[t].tick(dt)
		if casting_enabled and ai_casting[t]:
			_ai_cast(t, dt)
	for u in units.duplicate():
		u.tick(dt)
	_update_projectiles(dt)
	_tick_blizzards(dt)
	_separate()
	_reap()
	_check_end()
	if _projectile_layer:
		_projectile_layer.queue_redraw()


## Casts the shapeshift spell for a team. Invalid casts consume nothing.
func cast(team: int, u: Unit) -> bool:
	if finished or not casting_enabled or u == null or not u.alive:
		return false
	if u.immune_t > 0.0 or not spells[team].can_cast():
		return false
	var from := u.form_id
	spells[team].consume()
	u.transform_to(CreatureDB.roll_outcome(from, rng), u.team == team)
	casts[team] += 1
	unit_transformed.emit(u, team, from)
	return true


func _ai_cast(team: int, dt: float) -> void:
	if not spells[team].can_cast():
		return
	_ai_delay[team] -= dt
	if _ai_delay[team] > 0.0:
		return
	var profile := Difficulty.profile(ai_levels[team])
	var choice := EnemyAI.choose_cast(self, team, profile.threshold)
	# Easier wizards sometimes spend a well-timed charge on the wrong creature.
	if choice != null and profile.blunder > 0.0 and rng.randf() < profile.blunder:
		choice = EnemyAI.random_cast_target(self)
	if choice != null and cast(team, choice):
		var delay: Vector2 = profile.cast_delay
		_ai_delay[team] = rng.randf_range(delay.x, delay.y)
	else:
		_ai_delay[team] = profile.retry_delay


func _check_end() -> void:
	var alive := [0, 0]
	for u in units:
		if u.alive:
			alive[u.team] += 1
	if alive[0] > 0 and alive[1] > 0 and time < Rules.COMBAT_TIMEOUT:
		return
	finished = true
	if alive[0] == 0 and alive[1] > 0:
		result = {"winner": 1, "survivors": alive[1]}
	elif alive[1] == 0 and alive[0] > 0:
		result = {"winner": 0, "survivors": alive[0]}
	else:
		result = {"winner": -1, "survivors": 0} # mutual elimination or timeout
	result["time"] = time
	ended.emit(result)


func _reap() -> void:
	for u in units.duplicate():
		if not u.alive:
			units.erase(u)
			for other in units:
				if other.target == u:
					other.target = null
				if other.dive_target == u:
					other.dive_target = null
			unit_died.emit(u)
			u.queue_free()


# --- Damage -----------------------------------------------------------------

## kind: "melee" / "ranged" (basic attacks), "ability", "splash", "dot", "thorns".
func damage(src: Unit, dst: Unit, amount: float, kind: String, pierce := false) -> bool:
	if dst == null or not dst.alive:
		return false
	if (kind == "melee" or kind == "ranged") and dst.parry_ready:
		dst.parry_ready = false
		dst.ability_timer = dst.data.cd
		parries[dst.team] += 1
		emit_fx("parry", dst.position)
		return false
	var reduction := 0.0 if pierce else dst.armour() / 100.0
	var dealt := amount * (1.0 - reduction)
	damage_taken[dst.team] += clampf(dealt, 0.0, dst.hp)
	dst.hp -= dealt
	dst.last_hurt = time
	if kind != "dot":
		dst.flash_t = 0.12
	if kind == "melee" and dst.data.ability == "thorns" and src != null and src.alive:
		damage(dst, src, dst.data.power, "thorns")
	if dst.hp <= 0.0:
		dst.hp = 0.0
		dst.alive = false
	return true


# --- Projectiles --------------------------------------------------------------

func spawn_projectile(src: Unit, t: Unit, fireball := false) -> void:
	projectiles.append({
		"pos": src.position,
		"target": t,
		"aim": t.position,
		"team": src.team,
		"kind": "fireball" if fireball else src.data.attack,
		# Fire damage scales with stars and levels like basic damage, so the
		# pyromancer's ability-based damage keeps pace with merged enemies.
		"dmg": src.data.power * src.stat_mult() if fireball else src.attack_damage(),
		"src": src,
		"speed": src.data.fireball_speed * CELL if fireball else PROJECTILE_SPEED,
		"pierce": fireball or src.data.ability == "pierce",
		"splash": 0.0 if fireball else src.data.get("splash_radius", 0.0) * CELL,
		"chill_slow": src.data.get("chill_slow", 0.0),
		"chill_duration": src.data.get("chill_duration", 0.0),
		"burn_dps": src.data.get("burn_dps", 0.0) * src.stat_mult(),
		"burn_duration": src.data.get("burn_duration", 0.0),
	})
	Sfx.play("shoot")


func _update_projectiles(dt: float) -> void:
	for p in projectiles.duplicate():
		var t: Unit = p.target if is_instance_valid(p.target) else null
		if p.kind == "fireball" and (t == null or not t.alive):
			t = _nearest_enemy_from(p.team, p.pos)
			p.target = t
		if t != null and t.alive:
			p.aim = t.position
		var to: Vector2 = p.aim - p.pos
		var travel: float = p.speed * dt
		if to.length() > travel:
			p.pos += to.normalized() * travel
			continue
		projectiles.erase(p)
		var src: Unit = p.src if is_instance_valid(p.src) else null
		if p.splash > 0.0:
			for e in enemies_of_team_near(p.team, p.aim, p.splash):
				_projectile_hit(p, src, e, "ranged" if e == t else "splash")
			emit_fx("blast", p.aim, {"radius": p.splash})
		elif t != null and t.alive:
			_projectile_hit(p, src, t, "ability" if p.kind == "fireball" else "ranged")
			if p.kind == "fireball":
				emit_fx("blast", p.aim, {"radius": CELL * 0.8})
				Sfx.play("hit")


func _projectile_hit(p: Dictionary, src: Unit, dst: Unit, kind: String) -> void:
	if not damage(src, dst, p.dmg, kind, p.pierce) or not dst.alive:
		return
	if p.chill_duration > 0.0:
		dst.add_status("chilled", p.chill_duration, p.chill_slow, false)
	if p.burn_duration > 0.0:
		dst.add_status("burning", p.burn_duration, p.burn_dps, false)


func _draw_projectiles() -> void:
	for storm in blizzards:
		var rect: Rect2 = storm.rect
		draw_blizzard(rect, storm.t)
	for p in projectiles:
		var dir: Vector2 = (p.aim - p.pos).normalized()
		Icons.projectile(_projectile_layer, p.kind, p.pos, dir)


func best_blizzard_center(src: Unit) -> Vector2:
	var best := Vector2(INF, INF)
	var score := -1.0
	for candidate in living(1 - src.team):
		if src.edge_dist(candidate) > src.range_px():
			continue
		var centre := (candidate.position / CELL).floor() * CELL + Vector2.ONE * CELL * 0.5
		centre = centre.clamp(Vector2.ONE * CELL * 1.5, Rules.BOARD_SIZE - Vector2.ONE * CELL * 1.5)
		var rect := Rect2(centre - Vector2.ONE * CELL * 1.5, Vector2.ONE * CELL * 3.0)
		var value := 0.0
		for enemy in living(1 - src.team):
			if rect.has_point(enemy.position):
				value += 1.0 + (1.0 - enemy.hp / enemy.max_hp) * 0.2
		if value > score:
			score = value
			best = centre
	return best


func add_blizzard(src: Unit, centre: Vector2) -> void:
	blizzards.append({"rect": Rect2(centre - Vector2.ONE * CELL * 1.5, Vector2.ONE * CELL * 3.0),
		"team": src.team, "src": src, "t": 0.0, "remaining": src.data.duration,
		"dps": src.data.storm_dps, "slow": src.data.chill_slow})


## Overlapping blizzards do not stack: a creature inside several storms only
## suffers the strongest one (damage and chill) each step.
func _tick_blizzards(dt: float) -> void:
	var strongest := {} # Unit -> {"storm": Dictionary, "step": float}
	for storm in blizzards:
		var step := minf(dt, storm.remaining)
		for enemy in living(1 - int(storm.team)):
			if not storm.rect.has_point(enemy.position):
				continue
			var best: Dictionary = strongest.get(enemy, {})
			if best.is_empty() or storm.dps * step > best.storm.dps * best.step \
					or (is_equal_approx(storm.dps * step, best.storm.dps * best.step) and storm.slow > best.storm.slow):
				strongest[enemy] = {"storm": storm, "step": step}
	for enemy in strongest:
		var hit: Dictionary = strongest[enemy]
		var storm: Dictionary = hit.storm
		var src: Unit = storm.src if is_instance_valid(storm.src) else null
		damage(src, enemy, storm.dps * hit.step, "dot")
		if enemy.alive:
			enemy.add_status("chilled", 0.35, storm.slow, false)
	for storm in blizzards.duplicate():
		var step := minf(dt, storm.remaining)
		storm.t += step
		storm.remaining -= step
		if storm.remaining <= 0.0:
			blizzards.erase(storm)


func draw_blizzard(rect: Rect2, elapsed: float) -> void:
	var ci := _projectile_layer
	ci.draw_rect(rect, Color(0.45, 0.78, 1.0, 0.20))
	ci.draw_rect(rect, Color(0.6, 0.9, 1.0, 0.8), false, 2.0)
	for i in range(1, 3):
		ci.draw_line(rect.position + Vector2(i * CELL, 0), rect.position + Vector2(i * CELL, rect.size.y), Color(0.7, 0.9, 1.0, 0.12), 1.0)
		ci.draw_line(rect.position + Vector2(0, i * CELL), rect.position + Vector2(rect.size.x, i * CELL), Color(0.7, 0.9, 1.0, 0.12), 1.0)
	for i in 28:
		var p := rect.position + Vector2(fposmod(i * 43.0 + elapsed * 60.0, rect.size.x), fposmod(i * 71.0 + elapsed * 85.0, rect.size.y))
		ci.draw_line(p + Vector2(-3, -4), p + Vector2(3, 4), Color(0.9, 0.97, 1.0, 0.85), 2.0, true)


# --- Spatial helpers -------------------------------------------------------------

func clamp_to_board(u: Unit) -> void:
	var r := Rules.BODY_RADIUS * CELL
	u.position = u.position.clamp(Vector2(r, r), Rules.BOARD_SIZE - Vector2(r, r))


func _separate() -> void:
	var min_d := 2.0 * Rules.BODY_RADIUS * CELL
	for i in units.size():
		var a := units[i]
		if a.dive_target != null or a.jump_t > 0.0:
			continue
		for j in range(i + 1, units.size()):
			var b := units[j]
			if b.dive_target != null or b.jump_t > 0.0:
				continue
			var d := a.position - b.position
			var dist := d.length()
			if dist >= min_d:
				continue
			if dist < 0.01:
				d = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
				dist = d.length()
			var push := d / dist * (min_d - dist) * 0.5
			a.position += push
			b.position -= push
	for u in units:
		clamp_to_board(u)


func enemies_of_team_near(team: int, pos: Vector2, radius: float) -> Array[Unit]:
	var result: Array[Unit] = []
	for u in units:
		if u.alive and u.team != team and u.position.distance_to(pos) <= radius + Rules.BODY_RADIUS * CELL:
			result.append(u)
	return result


func enemies_near(of: Unit, pos: Vector2, radius: float) -> Array[Unit]:
	return enemies_of_team_near(of.team, pos, radius)


func allies_near(of: Unit, pos: Vector2, radius: float) -> Array[Unit]:
	var result: Array[Unit] = []
	for u in units:
		if u.alive and u.team == of.team and u.position.distance_to(pos) <= radius + Rules.BODY_RADIUS * CELL:
			result.append(u)
	return result


func nearest_enemy(of: Unit) -> Unit:
	return _nearest_enemy_from(of.team, of.position)


func _nearest_enemy_from(team: int, pos: Vector2) -> Unit:
	var best: Unit = null
	var best_d := INF
	for u in units:
		if u.alive and u.team != team:
			var d := pos.distance_squared_to(u.position)
			if d < best_d:
				best_d = d
				best = u
	return best


## Deepest row relative to the opposing team's side, rather than diagonal distance.
func backline_enemy(of: Unit) -> Unit:
	var best: Unit = null
	var depth := -INF
	for u in living(1 - of.team):
		var value := -u.position.y if of.team == 0 else u.position.y
		if value > depth or (is_equal_approx(value, depth) and best != null and of.position.distance_squared_to(u.position) < of.position.distance_squared_to(best.position)):
			depth = value
			best = u
	return best


func farthest_enemy(of: Unit) -> Unit:
	var best: Unit = null
	var best_d := -1.0
	for u in units:
		if u.alive and u.team != of.team:
			var d := of.position.distance_squared_to(u.position)
			if d > best_d:
				best_d = d
				best = u
	return best


func most_wounded_enemy(of: Unit, radius: float) -> Unit:
	var best: Unit = null
	var best_ratio := 0.999
	for u in enemies_near(of, of.position, radius):
		var ratio := u.hp / u.max_hp
		if ratio < best_ratio:
			best_ratio = ratio
			best = u
	return best


func most_wounded_ally(of: Unit, radius: float) -> Unit:
	var best: Unit = null
	var best_ratio := 0.95
	for u in allies_near(of, of.position, radius):
		var ratio := u.hp / u.max_hp
		if ratio < best_ratio:
			best_ratio = ratio
			best = u
	return best


func living(team: int) -> Array[Unit]:
	var result: Array[Unit] = []
	for u in units:
		if u.alive and u.team == team:
			result.append(u)
	return result


func unit_at(pos: Vector2, slack: float = 6.0) -> Unit:
	var best: Unit = null
	var best_d := Rules.BODY_RADIUS * CELL + slack
	for u in units:
		if u.alive:
			var d := u.position.distance_to(pos)
			if d < best_d:
				best_d = d
				best = u
	return best


func emit_fx(kind: String, pos: Vector2, extra: Dictionary = {}) -> void:
	fx_requested.emit(kind, pos, extra)
