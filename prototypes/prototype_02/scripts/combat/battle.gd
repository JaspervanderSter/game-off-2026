class_name Battle
extends Node2D
## Real-time automatic combat between two teams, with both wizards casting
## shapeshift. Drive it with step(dt): the game calls it every physics frame,
## tests call it directly.

signal unit_died(unit: Unit)
signal unit_transformed(unit: Unit, caster_team: int, from_form: String, combo: bool)
signal special_triggered(unit: Unit, caster_team: int, manual: bool, special_id: String)
signal fx_requested(kind: String, pos: Vector2, extra: Dictionary)
signal ended(result: Dictionary)

const CELL := Rules.CELL
const PROJECTILE_SPEED := 9.0 * Rules.CELL

var units: Array[Unit] = []
var projectiles: Array[Dictionary] = []
var spells: Array[ShiftSpell] = [ShiftSpell.new(), ShiftSpell.new()]
var ai_casting: Array[bool] = [false, true]
var casting_enabled := true
var momentum_enabled := Rules.MOMENTUM_ENABLED
var time := 0.0
var finished := false
var result := {}
var rng := RandomNumberGenerator.new()
var casts := [0, 0] # successful transformations per team, for tests and tuning
var specials_cast := [0, 0] # successful special triggers per team

var _ai_delay := [0.0, 0.0]
var _ai_special_delay := [0.0, 0.0]
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
		for c in state.fielded():
			spawn(state.team, c.form_id, Rules.cell_center(c.cell), c.uid, c.stars)
	for t in 2:
		_ai_delay[t] = rng.randf_range(1.0, 2.0)


func spawn(team: int, form: String, pos: Vector2, uid: int = 0, stars: int = 1) -> Unit:
	var u := Unit.new()
	u.stars = stars
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
			_ai_special(t, dt)
			_ai_cast(t, dt)
	for u in units.duplicate():
		u.tick(dt)
	_update_projectiles(dt)
	_separate()
	_reap()
	_check_end()
	if _projectile_layer:
		_projectile_layer.queue_redraw()


## Casts the shapeshift spell for a team. Invalid casts consume nothing.
## Base forms always advance. Animal stages I and II require their one-use
## special to have been triggered. Stage III refreshes instead of upgrading.
func cast(team: int, u: Unit) -> bool:
	if finished or not casting_enabled or u == null or not u.alive:
		return false
	if u.immune_t > 0.0 or not spells[team].can_cast():
		return false
	if u.needs_special_for_upgrade():
		return false
	var from := u.form_id
	var interrupted := u.has_pending_attack()
	var combo := momentum_enabled and u.momentum_window_t > 0.0
	var next := CreatureDB.next_form(from)
	spells[team].consume()
	u.transform_to(next, combo)
	casts[team] += 1
	if interrupted:
		emit_fx("interrupt", u.position)
		Sfx.play("interrupt")
	if combo:
		emit_fx("combo", u.position)
		Sfx.play("combo")
	unit_transformed.emit(u, team, from, combo)
	return true


## Triggers a friendly unit's one-use special. Manual triggers spend a charge;
## automatic triggers are free but require the unit's data condition.
func trigger_special(team: int, u: Unit, manual := true) -> bool:
	if finished or not casting_enabled or u == null or not u.alive or u.team != team:
		return false
	if not u.can_use_special():
		return false
	if manual and not spells[team].can_cast():
		return false
	if manual:
		spells[team].consume()
	var special_id := str(u.data.special.get("id", ""))
	if not u._execute_special():
		return false
	specials_cast[team] += 1
	special_triggered.emit(u, team, manual, special_id)
	return true


func _ai_special(team: int, dt: float) -> void:
	_ai_special_delay[team] -= dt
	if _ai_special_delay[team] > 0.0:
		return
	if spells[team].charges < 2:
		_ai_special_delay[team] = 0.5
		return
	var candidates: Array[Unit] = []
	for u in living(team):
		if u.can_use_special() and (u.special_condition_met() or spells[team].charges >= 3):
			candidates.append(u)
	if candidates.is_empty():
		_ai_special_delay[team] = 0.5
		return
	var choice: Unit = candidates[rng.randi_range(0, candidates.size() - 1)]
	if trigger_special(team, choice, true):
		_ai_special_delay[team] = rng.randf_range(1.2, 2.2)
	else:
		_ai_special_delay[team] = 0.3


func _ai_cast(team: int, dt: float) -> void:
	if not spells[team].can_cast():
		return
	_ai_delay[team] -= dt
	if _ai_delay[team] > 0.0:
		return
	var choice := EnemyAI.choose_cast(self, team)
	if choice != null and cast(team, choice):
		_ai_delay[team] = rng.randf_range(0.6, 1.6)
	else:
		_ai_delay[team] = 0.3


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
func damage(src: Unit, dst: Unit, amount: float, kind: String, pierce := false) -> void:
	if dst == null or not dst.alive:
		return
	var reduction := 0.0 if pierce else dst.armour() / 100.0
	dst.hp -= amount * (1.0 - reduction)
	dst.last_hurt = time
	if kind != "dot":
		dst.flash_t = 0.12
	if kind == "melee" and dst.data.ability == "thorns" and src != null and src.alive:
		damage(dst, src, dst.data.power, "thorns")
	if kind == "melee" and dst.statuses.has("retaliate") and src != null and src.alive:
		damage(dst, src, dst.statuses["retaliate"].v, "thorns")
	if dst.hp <= 0.0:
		dst.hp = 0.0
		dst.alive = false


# --- Projectiles --------------------------------------------------------------

func spawn_projectile(src: Unit, t: Unit, damage_mult := 1.0) -> void:
	projectiles.append({
		"pos": src.position,
		"target": t,
		"aim": t.position,
		"team": src.team,
		"kind": src.data.get("projectile", "arrow"),
		"dmg": src.attack_damage() * damage_mult,
		"src": src,
		"pierce": src.data.get("pierce", false),
		"splash": src.data.get("splash_radius", 0.0) * CELL,
		"chill": [src.data.duration, src.data.power] if src.data.ability == "chill" else [],
	})
	Sfx.play("shoot")


func _update_projectiles(dt: float) -> void:
	for p in projectiles.duplicate():
		var t: Unit = p.target if is_instance_valid(p.target) else null
		if t != null and t.alive:
			p.aim = t.position
		var to: Vector2 = p.aim - p.pos
		var travel := PROJECTILE_SPEED * dt
		if to.length() > travel:
			p.pos += to.normalized() * travel
			continue
		projectiles.erase(p)
		# A transformation grants a short projectile-dodge window. The
		# projectile is committed only when it arrives, so timing matters.
		if t != null and t.alive and t.dodge_t > 0.0:
			emit_fx("dodge", t.position)
			Sfx.play("dodge")
			continue
		var src: Unit = p.src if is_instance_valid(p.src) else null
		if p.splash > 0.0:
			for e in enemies_of_team_near(p.team, p.aim, p.splash):
				damage(src, e, p.dmg, "ranged" if e == t else "splash")
			emit_fx("blast", p.aim, {"radius": p.splash})
		elif t != null and t.alive:
			damage(src, t, p.dmg, "ranged", p.pierce)
			if not p.chill.is_empty() and t.alive:
				t.add_status("chilled", p.chill[0], p.chill[1], false)


func _draw_projectiles() -> void:
	for p in projectiles:
		var dir: Vector2 = (p.aim - p.pos).normalized()
		Icons.projectile(_projectile_layer, p.kind, p.pos, dir)


func incoming_projectile_to(u: Unit) -> bool:
	for p in projectiles:
		if p.target == u:
			return true
	return false


# --- Spatial helpers -------------------------------------------------------------

func clamp_to_board(u: Unit) -> void:
	var r := Rules.BODY_RADIUS * CELL
	u.position = u.position.clamp(Vector2(r, r), Rules.BOARD_SIZE - Vector2(r, r))


func _separate() -> void:
	var min_d := 2.0 * Rules.BODY_RADIUS * CELL
	for i in units.size():
		var a := units[i]
		if a.dive_target != null:
			continue
		for j in range(i + 1, units.size()):
			var b := units[j]
			if b.dive_target != null:
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
	var best: Unit = null
	var best_d := INF
	for u in units:
		if u.alive and u.team != of.team:
			var d := of.position.distance_squared_to(u.position)
			if d < best_d:
				best_d = d
				best = u
	return best


func nearest_enemies(of: Unit, count: int) -> Array[Unit]:
	var candidates: Array[Unit] = []
	for u in units:
		if u.alive and u.team != of.team:
			candidates.append(u)
	candidates.sort_custom(func(a, b):
		return of.position.distance_squared_to(a.position) < of.position.distance_squared_to(b.position))
	var result: Array[Unit] = []
	for i in mini(count, candidates.size()):
		result.append(candidates[i])
	return result


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
