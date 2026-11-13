class_name Unit
extends Node2D
## A creature during one combat. It is created from an OwnedCreature at the
## start of combat and discarded afterwards, so forms, levels and statuses
## never persist between rounds.

const CELL := Rules.CELL

var battle: Battle
var source_uid := 0
var team := 0
var form_id := ""
var data: Dictionary
var level := 1
var stars := 0
var merge_copies := 1
var max_hp := 1.0
var hp := 1.0
var alive := true

var attack_timer := 0.0 # time until the basic attack is ready at full speed
var ability_timer := 0.0 # one cooldown, kept across form changes
var immune_t := 0.0 # shapeshift immunity
var target: Unit = null
## name -> {"t": remaining s, "v": magnitude, "positive": bool}
var statuses := {}

# Form-specific state, reset by a transformation.
var shell_t := 0.0
var charging := false
var dive_target: Unit = null
var parry_ready := false
var hunted := false
var hunt_retarget := 0.0
var last_burn_target_id := 0
var dash_vel := Vector2.ZERO
var dash_t := 0.0
var jump_t := 0.0
var jump_start := Vector2.ZERO
var jump_end := Vector2.ZERO
var jump_target: Unit = null
var last_hurt := -99.0

# Visual-only state.
var lunge_dir := Vector2.ZERO
var lunge_t := 0.0
var flash_t := 0.0
var pop_t := 0.0
var hovered := false
var anim_t := 0.0
var beat_t := 0.0 # hop on each song beat (bard and inspired allies)
var beat_len := 0.28
var song_step := 0 # bard melody position, one note per beat

const BEAT_TIME := 0.28


func setup(b: Battle, uid: int, team_id: int, form: String, pos: Vector2) -> void:
	battle = b
	source_uid = uid
	team = team_id
	position = pos
	_set_form(form)
	max_hp = data.hp * stat_mult()
	hp = max_hp
	ability_timer = data.get("cd_start", data.get("cd", 0.0) * 0.5)
	anim_t = randf() * 10.0


func _set_form(form: String) -> void:
	form_id = form
	data = CreatureDB.get_form(form)


# --- Shapeshifting --------------------------------------------------------

## Applies the shared transformation rules of Prototype 02.
func transform_to(new_form: String, gain_level: bool) -> void:
	var ratio := hp / max_hp
	_set_form(new_form)
	if gain_level:
		level += 1
	max_hp = data.hp * stat_mult()
	hp = minf(max_hp, ratio * max_hp + Rules.SHIFT_HEAL * max_hp)
	attack_timer = 0.0
	for key in statuses.keys():
		if not statuses[key].positive:
			statuses.erase(key)
	# The remaining cooldown carries over; entering a form never grants an
	# immediately ready ability.
	if ability_timer <= 0.0:
		ability_timer = data.get("cd", 0.0)
	# Rabbit's defining entry action is an immediate backline leap.
	if data.ability == "hop":
		ability_timer = 0.0
	shell_t = 0.0
	charging = false
	dive_target = null
	parry_ready = false
	hunted = false
	last_burn_target_id = 0
	jump_t = 0.0
	jump_target = null
	immune_t = Rules.TARGET_IMMUNITY
	pop_t = 0.45


# --- Derived statistics ---------------------------------------------------

func stat_mult() -> float:
	return Rules.level_mult(level) * Rules.star_mult(stars)


func visual_scale() -> float:
	return minf(1.0 + Rules.LEVEL_VISUAL_GROWTH * (level - 1), Rules.MAX_LEVEL_VISUAL_SCALE)


func attack_damage() -> float:
	return data.dmg * stat_mult()


func attack_interval() -> float:
	return _unchilled_attack_interval() / _chill_speed_multiplier()


func _unchilled_attack_interval() -> float:
	var interval: float = data.interval
	if data.ability == "berserk":
		interval *= 1.0 - data.power * (1.0 - hp / max_hp)
	var bonus := 0.0
	if statuses.has("inspired"):
		bonus += statuses.inspired.v
	if data.ability == "pack" and _ally_near(data.radius * CELL):
		bonus += data.power
	interval /= 1.0 + bonus
	if statuses.has("dazzled"):
		interval *= statuses.dazzled.v
	return interval


func armour() -> float:
	var a: float = data.armour
	if shell_t > 0.0:
		a += data.power
	if statuses.has("exposed"):
		a -= statuses.exposed.v
	return clampf(a, 0.0, 85.0)


func move_speed() -> float:
	return data.speed * CELL * _chill_speed_multiplier()


func _chill_speed_multiplier() -> float:
	if statuses.has("chilled"):
		return 1.0 - statuses.chilled.v
	return 1.0


func range_px() -> float:
	return data.range * CELL


func edge_dist(other: Unit) -> float:
	return position.distance_to(other.position) - 2.0 * Rules.BODY_RADIUS * CELL


func is_melee() -> bool:
	return data.attack == "melee"


func pack_active() -> bool:
	return data.ability == "pack" and _ally_near(data.radius * CELL)


func add_status(key: String, duration: float, value: float, positive: bool) -> void:
	if statuses.has(key):
		statuses[key].t = maxf(statuses[key].t, duration)
		statuses[key].v = maxf(statuses[key].v, value)
	else:
		statuses[key] = {"t": duration, "v": value, "positive": positive}


func heal(amount: float) -> void:
	var before := hp
	hp = minf(max_hp, hp + amount)
	if battle != null and hp > before:
		battle.healing_received[team] += hp - before


# --- Simulation -----------------------------------------------------------

func tick(dt: float) -> void:
	if not alive:
		return
	immune_t = maxf(0.0, immune_t - dt)
	var attack_progress := dt
	if statuses.has("chilled"):
		attack_progress -= minf(dt, statuses.chilled.t) * statuses.chilled.v
	_tick_statuses(dt)
	if not alive:
		return
	attack_timer = maxf(0.0, attack_timer - attack_progress)
	ability_timer = maxf(0.0, ability_timer - dt)
	_tick_visuals(dt)
	if jump_t > 0.0:
		_tick_jump(dt)
		return

	if dash_t > 0.0:
		dash_t -= dt
		position += dash_vel * dt
		battle.clamp_to_board(self)
		return
	if shell_t > 0.0:
		shell_t -= dt
		return
	if dive_target != null:
		_tick_dive(dt)
		return
	if charging:
		_tick_charge(dt)
		return

	_tick_ability()
	if shell_t > 0.0 or dive_target != null or charging or dash_t > 0.0 or jump_t > 0.0:
		return

	_choose_target(dt)
	if target == null:
		return
	if data.ability == "fireball" and attack_timer <= 0.0:
		_choose_burn_target()
	if data.ability == "kite" and _kite(dt):
		return
	if edge_dist(target) > range_px():
		_move_towards(target.position, move_speed(), dt)
	elif attack_timer <= 0.0:
		_attack(target)


func _tick_statuses(dt: float) -> void:
	for key in statuses.keys():
		var s: Dictionary = statuses[key]
		var step := minf(dt, s.t)
		if key == "poisoned" or key == "burning":
			battle.damage(null, self, s.v * step, "dot")
		elif key == "regen":
			heal(s.v * step)
		s.t -= dt
		if s.t <= 0.0:
			statuses.erase(key)


func _tick_visuals(dt: float) -> void:
	anim_t += dt
	lunge_t = maxf(0.0, lunge_t - dt)
	flash_t = maxf(0.0, flash_t - dt)
	pop_t = maxf(0.0, pop_t - dt)
	beat_t = maxf(0.0, beat_t - dt)


func _choose_target(dt: float) -> void:
	if target != null and not target.alive:
		target = null
	if data.ability == "hunt":
		hunt_retarget -= dt
		if target == null or hunt_retarget <= 0.0:
			hunt_retarget = 1.0
			var prey := battle.most_wounded_enemy(self, data.radius * CELL)
			target = prey if prey != null else battle.nearest_enemy(self)
		return
	if target == null:
		if data.ability == "backline" and not hunted:
			hunted = true
			target = battle.farthest_enemy(self)
		else:
			target = battle.nearest_enemy(self)
		return
	# Keep the target until it dies, unless it is out of reach while another
	# enemy is already within reach.
	if edge_dist(target) > range_px() + 4.0:
		var near := battle.nearest_enemy(self)
		if near != null and edge_dist(near) <= range_px():
			target = near


func _move_towards(point: Vector2, speed: float, dt: float) -> void:
	var to := point - position
	if to.length() < 0.5:
		return
	position += to.normalized() * minf(speed * dt, to.length())
	battle.clamp_to_board(self)


func _choose_burn_target() -> void:
	var best: Unit = null
	var shortest_burn := INF
	for enemy in battle.living(1 - team):
		if enemy.get_instance_id() == last_burn_target_id or edge_dist(enemy) > range_px():
			continue
		var remaining: float = enemy.statuses.get("burning", {}).get("t", 0.0)
		if remaining < shortest_burn:
			best = enemy
			shortest_burn = remaining
	if best != null:
		target = best


func _attack(t: Unit) -> void:
	attack_timer = _unchilled_attack_interval()
	if not is_melee():
		if data.ability == "fireball":
			last_burn_target_id = t.get_instance_id()
		battle.spawn_projectile(self, t)
		return
	lunge_dir = (t.position - position).normalized()
	lunge_t = 0.18
	Sfx.play("hit")
	if data.ability == "cleave":
		for e in battle.enemies_near(self, t.position, data.radius * CELL):
			battle.damage(self, e, attack_damage(), "melee")
	else:
		battle.damage(self, t, attack_damage(), "melee")
	if data.ability == "poison" and t.alive:
		t.add_status("poisoned", data.duration, data.power, false)


# --- Abilities --------------------------------------------------------------

func _tick_ability() -> void:
	match data.ability:
		"parry":
			if ability_timer <= 0.0 and not parry_ready:
				parry_ready = true
		"shell":
			if ability_timer <= 0.0 and battle.time - last_hurt < 1.0:
				shell_t = data.duration
				ability_timer = data.cd
				battle.emit_fx("shell", position)
		"charge":
			if ability_timer <= 0.0 and target != null and target.alive and edge_dist(target) > 1.5 * CELL:
				charging = true
				ability_timer = data.cd
				battle.emit_fx("charge", position)
		"hop":
			if ability_timer <= 0.0:
				var prey := battle.backline_enemy(self)
				if prey != null and edge_dist(prey) > range_px() + 0.2 * CELL:
					jump_target = prey
					jump_start = position
					var behind := Vector2.UP if team == 0 else Vector2.DOWN
					jump_end = prey.position + behind * (2.0 * Rules.BODY_RADIUS + 0.12) * CELL
					var r := Rules.BODY_RADIUS * CELL
					jump_end = jump_end.clamp(Vector2(r, r), Rules.BOARD_SIZE - Vector2(r, r))
					jump_t = 0.5
					ability_timer = data.cd
					battle.emit_fx("hop", position)
					Sfx.play("hop")
		"blizzard":
			if ability_timer <= 0.0:
				var centre := battle.best_blizzard_center(self)
				if centre.is_finite():
					battle.add_blizzard(self, centre)
					ability_timer = data.cd
					Sfx.play("blizzard")
		"fireball":
			if ability_timer <= 0.0:
				var prey := battle.nearest_enemy(self)
				if prey != null and edge_dist(prey) <= range_px():
					battle.spawn_projectile(self, prey, true)
					ability_timer = data.cd
		"spray":
			if ability_timer <= 0.0:
				var hit := battle.enemies_near(self, position, data.radius * CELL)
				if not hit.is_empty():
					for e in hit:
						e.add_status("exposed", data.duration, data.power, false)
					ability_timer = data.cd
					battle.emit_fx("spray", position, {"radius": data.radius * CELL})
		"display":
			if ability_timer <= 0.0:
				var hit := battle.enemies_near(self, position, data.radius * CELL)
				if not hit.is_empty():
					for e in hit:
						e.add_status("dazzled", data.duration, data.power, false)
					ability_timer = data.cd
					battle.emit_fx("display", position, {"radius": data.radius * CELL})
		"dive":
			if ability_timer <= 0.0:
				var prey := battle.farthest_enemy(self)
				if prey != null and edge_dist(prey) > 2.0 * CELL:
					dive_target = prey
					ability_timer = data.cd
					battle.emit_fx("dive", position)
		"heal":
			if ability_timer <= 0.0:
				var ally := battle.most_wounded_ally(self, data.radius * CELL)
				if ally != null:
					ally.heal(data.power)
					ability_timer = data.cd
					battle.emit_fx("heal", ally.position, {"from": position})
		"song":
			if ability_timer <= 0.0:
				ability_timer = data.cd
				var allies := battle.living(team)
				for a in allies:
					a.add_status("inspired", data.duration, data.power, true)
					a.beat_t = BEAT_TIME
					a.beat_len = BEAT_TIME
				beat_t = BEAT_TIME * 1.6
				beat_len = beat_t
				battle.emit_fx("song", position, {"targets": allies, "source": self, "step": song_step})
				Sfx.play_note(song_step)
				song_step += 1
		"graze":
			for a in battle.allies_near(self, position, data.radius * CELL):
				a.add_status("regen", 0.35, data.power, true)


func _tick_jump(dt: float) -> void:
	jump_t = maxf(0.0, jump_t - dt)
	position = jump_start.lerp(jump_end, 1.0 - jump_t / 0.5)
	if jump_t == 0.0:
		target = jump_target if is_instance_valid(jump_target) and jump_target.alive else null
		jump_target = null
		attack_timer = 0.0
		battle.emit_fx("impact", position)


func _tick_dive(dt: float) -> void:
	if not dive_target.alive:
		dive_target = null
		return
	_move_towards(dive_target.position, 9.0 * CELL, dt)
	if edge_dist(dive_target) <= 2.0:
		battle.damage(self, dive_target, data.power, "ability")
		battle.emit_fx("impact", dive_target.position)
		Sfx.play("hit")
		target = dive_target
		dive_target = null


func _tick_charge(dt: float) -> void:
	if target == null or not target.alive:
		charging = false
		return
	_move_towards(target.position, 5.0 * CELL, dt)
	if edge_dist(target) <= range_px():
		charging = false
		attack_timer = _unchilled_attack_interval()
		lunge_dir = (target.position - position).normalized()
		lunge_t = 0.25
		battle.damage(self, target, attack_damage() * data.power, "ability")
		if target.alive:
			target.dash_vel = lunge_dir * data.knock * CELL / 0.25
			target.dash_t = 0.25
		battle.emit_fx("impact", target.position)
		Sfx.play("hit")


## Archers step away from melee attackers while reloading.
func _kite(dt: float) -> bool:
	if attack_timer < 0.3 * _chill_speed_multiplier():
		return false
	for e in battle.enemies_near(self, position, (2.0 * Rules.BODY_RADIUS + 0.5) * CELL):
		if e.is_melee():
			var away := (position - e.position).normalized()
			_move_towards(position + away * CELL, move_speed(), dt)
			return true
	return false


func _ally_near(radius: float) -> bool:
	for a in battle.allies_near(self, position, radius):
		if a != self:
			return true
	return false


# --- Drawing ---------------------------------------------------------------

func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r := Rules.BODY_RADIUS * CELL
	var image_r := r * visual_scale()
	var offset := lunge_dir * sin(lunge_t / 0.18 * PI) * 10.0 if lunge_t > 0.0 else Vector2.ZERO
	var scale_k := 1.0 + 0.35 * sin(pop_t / 0.45 * PI)
	var bob := Vector2(0, sin(anim_t * 6.0) * 1.2)
	var p := offset + bob
	# Song beat: a quick hop (and a bigger squash-and-stretch on the bard).
	var beat_k := sin(beat_t / beat_len * PI) if beat_t > 0.0 else 0.0
	var is_singer: bool = data.ability == "song"
	p += Vector2(0, -beat_k * (9.0 if is_singer else 6.0))
	scale_k += beat_k * (0.16 if is_singer else 0.06)
	var inspired := statuses.has("inspired")

	# Ground shadow and team base.
	draw_circle(Vector2(0, r * 0.75), r * 0.95, Color(0, 0, 0, 0.25))
	Icons.team_base(self, p, r * scale_k, team, hovered)
	if inspired:
		# Golden ring around inspired creatures, flaring on each beat; it fades
		# during the last second of inspiration.
		var glow := Icons.GOLD
		glow.a = (0.55 + 0.45 * beat_k) * clampf(statuses.inspired.t, 0.25, 1.0)
		draw_arc(p, r * scale_k * (1.12 + 0.12 * beat_k), 0, TAU, 32, glow, 2.5 + 2.5 * beat_k, true)
	if hovered and battle != null and battle.casting_enabled and not battle.finished:
		# The local player is team 0: hovering previews its shapeshift on this unit.
		var ready := battle.spells[0].can_cast() and immune_t <= 0.0
		Icons.shift_reticle(self, p, r * scale_k, anim_t, team == 0, ready)
	if dive_target != null:
		p += Vector2(0, -8)
	if jump_t > 0.0:
		p += Vector2(0, -sin(jump_t / 0.5 * PI) * 30.0)
	Icons.creature(self, form_id, p, image_r * 0.92 * scale_k)
	if shell_t > 0.0:
		draw_arc(p, image_r * 1.15, 0, TAU, 32, Color(0.5, 1.0, 0.6, 0.9), 4.0, true)
	if parry_ready:
		Icons.parry_mark(self, p + Vector2(image_r * 0.95, -image_r * 0.6), 7.0)
	if flash_t > 0.0:
		draw_circle(p, image_r * 1.05, Color(1, 1, 1, flash_t / 0.12 * 0.6))
	if immune_t > 0.0:
		Icons.immunity_ring(self, p, image_r * 1.3, immune_t / Rules.TARGET_IMMUNITY, anim_t)

	# Fixed team base / health bar; image size shows temporary levels only.
	var bar_w := r * 2.2
	var bar_pos := Vector2(-bar_w * 0.5, r + 6.0)
	Icons.health_bar(self, bar_pos, bar_w, hp / max_hp, team)
	Icons.merge_stars(self, Vector2(0, -image_r - 10.0), stars)
	if hovered:
		Icons.merge_progress(self, Vector2(0, -image_r - 22.0), merge_copies, stars)
	var i := 0
	for key in statuses.keys():
		Icons.status(self, key, Vector2(-r - 4.0, -r + 2.0 + i * 13.0), 6.0)
		i += 1
	if pack_active():
		Icons.status(self, "pack", Vector2(r + 4.0, r - 2.0), 6.0)
	if inspired:
		# A note circles inspired creatures; fades out in the last second.
		var remaining: float = statuses.inspired.t
		var note_col := Icons.GOLD
		note_col.a = clampf(remaining, 0.0, 1.0)
		var orbit := Vector2.from_angle(anim_t * 3.2) * Vector2(image_r * 1.25, image_r * 0.6)
		Icons.note_shadowed(self, p + orbit + Vector2(0, -image_r * 0.35), 8.0 + 3.0 * beat_k, note_col)
