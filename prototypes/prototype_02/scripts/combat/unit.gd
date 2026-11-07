class_name Unit
extends Node2D
## A creature during one combat. It is created from an OwnedCreature at the
## start of combat and discarded afterwards, so forms, momentum and statuses
## never persist between rounds.
##
## All combat behaviour is driven by CreatureDB form data. The unit does not
## branch on individual form ids; it reads statistics, attack style and ability
## parameters from the current form.

const CELL := Rules.CELL

var battle: Battle
var source_uid := 0
var team := 0
var form_id := ""
var data: Dictionary
var stars := 1
var max_hp := 1.0
var hp := 1.0
var alive := true

var attack_timer := 0.0 # time until the next basic attack can start
var ability_timer := 0.0 # one cooldown, kept across form changes
var immune_t := 0.0 # shapeshift immunity
var dodge_t := 0.0 # projectile-dodge window after a transformation
var target: Unit = null
## name -> {"t": remaining s, "v": magnitude, "positive": bool, ...extras}
var statuses := {}

# Attack windup. The attack is not committed until this reaches zero.
var pending_target: Unit = null
var pending_t := 0.0
var pending_windup := 0.0

# Momentum / combo.
var momentum_pending := false
var momentum_window_t := 0.0

# One-use animal special. Using it unlocks the next transformation stage.
var special_used := false
var special_lockout := 0.0
var special_check_t := 0.0
var special_flash_t := 0.0

# Form-specific state, reset by a transformation.
var shell_t := 0.0
var charging := false
var dive_target: Unit = null
var hunted := false
var hunt_retarget := 0.0
var dash_vel := Vector2.ZERO
var dash_t := 0.0
var last_hurt := -99.0

# Visual-only state.
var lunge_dir := Vector2.ZERO
var lunge_t := 0.0
var flash_t := 0.0
var pop_t := 0.0
var hovered := false
var anim_t := 0.0
var family_color := Color.WHITE


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
	family_color = CreatureDB.family_color(form)


# --- Shapeshifting --------------------------------------------------------

## True while the unit has an attack windup or special movement that a
## transformation can interrupt.
func has_pending_attack() -> bool:
	return pending_target != null or charging or dive_target != null


## Applies the shared transformation rules of Prototype 02.
## `combo` is true when the cast lands inside the momentum window.
func transform_to(new_form: String, combo := false) -> void:
	var ratio := hp / max_hp
	var interrupted := has_pending_attack()
	_set_form(new_form)
	max_hp = data.hp * stat_mult()
	hp = minf(max_hp, ratio * max_hp + Rules.SHIFT_HEAL * max_hp)
	pending_target = null
	pending_t = 0.0
	pending_windup = 0.0
	attack_timer = Rules.SHIFT_ATTACK_RECOVERY if interrupted else 0.0
	cleanse_negative()
	# The remaining cooldown carries over; entering a form never grants an
	# immediately ready ability.
	if ability_timer <= 0.0:
		ability_timer = data.get("cd", 0.0)
	shell_t = 0.0
	charging = false
	dive_target = null
	hunted = false
	hunt_retarget = 0.0
	dash_vel = Vector2.ZERO
	dash_t = 0.0
	immune_t = Rules.TARGET_IMMUNITY
	dodge_t = Rules.DODGE_WINDOW
	momentum_pending = true
	momentum_window_t = 0.0
	special_used = false
	special_lockout = 0.5
	special_check_t = 0.2
	special_flash_t = 0.0
	pop_t = 0.45
	if combo:
		_apply_combo()


func _apply_combo() -> void:
	var combo := CreatureDB.combo_for(form_id)
	var speed: float = combo.get("attack_speed", Rules.MOMENTUM_ATTACK_SPEED)
	var damage: float = combo.get("damage", Rules.MOMENTUM_DAMAGE)
	var duration: float = combo.get("duration", Rules.MOMENTUM_DURATION)
	add_status("momentum", duration, speed, true, {"dmg": damage})


func cleanse_negative() -> void:
	for key in statuses.keys():
		if not statuses[key].positive:
			statuses.erase(key)


# --- Animal progression and specials --------------------------------------

func stage() -> int:
	return CreatureDB.stage_of(form_id)


func is_final_stage() -> bool:
	return CreatureDB.is_final_stage(form_id)


## Animal stages I and II must use their special before they can upgrade.
func needs_special_for_upgrade() -> bool:
	return stage() > 0 and not is_final_stage() and not special_used


func can_use_special() -> bool:
	return stage() > 0 and data.has("special") and not special_used


func special_condition_met() -> bool:
	if not data.has("special"):
		return false
	var auto: Dictionary = data.special.get("auto", {})
	if auto.is_empty():
		return false
	match str(auto.get("type", "")):
		"nearby_enemies":
			return battle.enemies_near(self, position, float(auto.get("radius", 4.0)) * CELL).size() >= int(auto.get("count", 1))
		"nearby_allies":
			var count := 0
			for a in battle.allies_near(self, position, float(auto.get("radius", 4.0)) * CELL):
				if a != self:
					count += 1
			return count >= int(auto.get("count", 1))
		"ally_wounded":
			var count := 0
			for a in battle.allies_near(self, position, float(auto.get("radius", 4.0)) * CELL):
				if a != self and a.hp / a.max_hp <= float(auto.get("ratio", 0.6)):
					count += 1
			return count >= int(auto.get("count", 1))
		"enemy_cluster":
			var center := position
			if target != null and target.alive:
				center = target.position
			return battle.enemies_near(self, center, float(auto.get("radius", 1.8)) * CELL).size() >= int(auto.get("count", 2))
		"backline_in_range":
			for e in battle.enemies_near(self, position, float(auto.get("range", 5.0)) * CELL):
				if e.data.role == "back" or e.data.role == "support":
					return true
			return false
		"self_low":
			return hp / max_hp <= float(auto.get("ratio", 0.6))
	return false


func _tick_special(dt: float) -> void:
	if special_lockout > 0.0:
		special_lockout = maxf(0.0, special_lockout - dt)
		return
	if special_used or not can_use_special():
		return
	special_check_t -= dt
	if special_check_t > 0.0:
		return
	special_check_t = 0.2
	if special_condition_met():
		battle.trigger_special(team, self, false)


## Applies this form's one-use special. Returns false if there is nothing to use.
func _execute_special() -> bool:
	if special_used or not data.has("special"):
		return false
	var sp: Dictionary = data.special
	special_used = true
	special_flash_t = 0.7
	battle.emit_fx("special", position, {"color": family_color, "id": str(sp.get("id", ""))})
	var kind := str(sp.get("type", ""))
	match kind:
		"burst_damage":
			var center := position
			if sp.get("at_target", false) and target != null and target.alive:
				center = target.position
			for e in battle.enemies_near(self, center, float(sp.radius) * CELL):
				battle.damage(self, e, float(sp.power), "special")
				if sp.has("status"):
					e.add_status(str(sp.status), float(sp.status_duration), float(sp.status_power), false)
			battle.emit_fx("special_blast", center, {"radius": float(sp.radius) * CELL, "color": family_color})
		"burst_heal":
			for a in battle.allies_near(self, position, float(sp.radius) * CELL):
				a.heal(float(sp.power))
				if sp.get("cleanse", false):
					a.cleanse_negative()
			battle.emit_fx("special_heal", position, {"radius": float(sp.radius) * CELL, "color": family_color})
		"buff_allies":
			for a in battle.allies_near(self, position, float(sp.radius) * CELL):
				a.add_status(str(sp.status), float(sp.duration), float(sp.power), true)
			battle.emit_fx("special_heal", position, {"radius": float(sp.radius) * CELL, "color": family_color})
		"debuff_enemies":
			for e in battle.enemies_near(self, position, float(sp.radius) * CELL):
				e.add_status(str(sp.status), float(sp.duration), float(sp.power), false)
			battle.emit_fx("special_blast", position, {"radius": float(sp.radius) * CELL, "color": family_color})
		"knockback":
			for e in battle.enemies_near(self, position, float(sp.radius) * CELL):
				var away := (e.position - position).normalized()
				if away == Vector2.ZERO:
					away = Vector2.DOWN if team == 0 else Vector2.UP
				e.dash_vel = away * float(sp.knock) * CELL / 0.25
				e.dash_t = 0.25
				if sp.has("status"):
					e.add_status(str(sp.status), float(sp.status_duration), float(sp.status_power), false)
			battle.emit_fx("special_blast", position, {"radius": float(sp.radius) * CELL, "color": family_color})
		"leap":
			var t := _special_target(str(sp.get("target", "nearest")))
			if t != null:
				var dir := (t.position - position).normalized()
				position = t.position - dir * (0.8 * CELL)
				battle.clamp_to_board(self)
				lunge_dir = dir
				lunge_t = 0.25
				battle.damage(self, t, float(sp.power), "special")
				if float(sp.get("knock", 0.0)) > 0.0 and t.alive:
					t.dash_vel = dir * float(sp.knock) * CELL / 0.25
					t.dash_t = 0.25
				battle.emit_fx("impact", t.position)
			else:
				battle.emit_fx("special_blast", position, {"radius": CELL, "color": family_color})
		"volley":
			for t in battle.nearest_enemies(self, int(sp.get("count", 2))):
				battle.spawn_projectile(self, t, float(sp.get("power_mult", 1.0)))
			battle.emit_fx("special_blast", position, {"radius": 1.2 * CELL, "color": family_color})
		"self_buff":
			add_status(str(sp.status), float(sp.duration), float(sp.power), true)
			battle.emit_fx("special_heal", position, {"radius": 0.8 * CELL, "color": family_color})
		"evade":
			var away := Vector2.DOWN if team == 0 else Vector2.UP
			var near := battle.nearest_enemy(self)
			if near != null:
				away = (position - near.position).normalized()
			dash_vel = away * float(sp.get("distance", 1.0)) * CELL / 0.25
			dash_t = 0.25
			dodge_t = maxf(dodge_t, float(sp.get("dodge", 0.8)))
			battle.emit_fx("dodge", position)
	Sfx.play("special")
	return true


func _special_target(mode: String) -> Unit:
	match mode:
		"farthest":
			return battle.farthest_enemy(self)
		"wounded":
			return battle.most_wounded_enemy(self, 9999.0)
		_:
			return battle.nearest_enemy(self)


# --- Derived statistics ---------------------------------------------------

func stat_mult() -> float:
	return Rules.star_mult(stars)


func attack_damage() -> float:
	var mult := stat_mult()
	if statuses.has("momentum"):
		mult *= 1.0 + float(statuses["momentum"].get("dmg", 0.0))
	return data.dmg * mult


func attack_interval() -> float:
	var interval: float = data.interval
	if data.ability == "berserk":
		interval *= 1.0 - data.power * (1.0 - hp / max_hp)
	var bonus := 0.0
	if statuses.has("inspired"):
		bonus += statuses.inspired.v
	if statuses.has("momentum"):
		bonus += statuses.momentum.v
	interval /= 1.0 + bonus
	if statuses.has("dazzled"):
		interval *= statuses.dazzled.v
	return maxf(0.10, interval)


func armour() -> float:
	var a: float = data.armour
	if shell_t > 0.0:
		a += data.power
	if statuses.has("guarded"):
		a += statuses.guarded.v
	if statuses.has("exposed"):
		a -= statuses.exposed.v
	return clampf(a, 0.0, 85.0)


func move_speed() -> float:
	var s: float = data.speed * CELL
	if statuses.has("chilled"):
		s *= 1.0 - statuses.chilled.v
	return s


func range_px() -> float:
	return data.range * CELL


func edge_dist(other: Unit) -> float:
	return position.distance_to(other.position) - 2.0 * Rules.BODY_RADIUS * CELL


func is_melee() -> bool:
	return data.attack_kind == "melee"


func windup() -> float:
	return maxf(0.05, float(data.get("windup", 0.2)))


func add_status(key: String, duration: float, value: float, positive: bool, extra: Dictionary = {}) -> void:
	if statuses.has(key):
		statuses[key].t = maxf(statuses[key].t, duration)
		statuses[key].v = maxf(statuses[key].v, value)
		statuses[key].merge(extra, true)
	else:
		var s := {"t": duration, "v": value, "positive": positive}
		s.merge(extra, true)
		statuses[key] = s


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)


# --- Simulation -----------------------------------------------------------

func tick(dt: float) -> void:
	if not alive:
		return
	immune_t = maxf(0.0, immune_t - dt)
	dodge_t = maxf(0.0, dodge_t - dt)
	_tick_momentum(dt)
	_tick_statuses(dt)
	_tick_special(dt)
	if not alive:
		return
	attack_timer = maxf(0.0, attack_timer - dt)
	ability_timer = maxf(0.0, ability_timer - dt)
	_tick_visuals(dt)

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

	# A pending attack keeps the unit still and cannot be re-aimed.
	if pending_target != null:
		if not pending_target.alive:
			pending_target = null
			pending_t = 0.0
		else:
			pending_t -= dt
			if pending_t <= 0.0:
				_resolve_attack()
		return

	_tick_ability()
	if shell_t > 0.0 or dive_target != null or charging or dash_t > 0.0:
		return

	_choose_target(dt)
	if target == null:
		return
	if data.ability == "kite" and _kite(dt):
		return
	if edge_dist(target) > range_px():
		_move_towards(target.position, move_speed(), dt)
	elif attack_timer <= 0.0:
		_start_attack(target)


func _tick_momentum(dt: float) -> void:
	if not battle.momentum_enabled:
		momentum_pending = false
		momentum_window_t = 0.0
		return
	if momentum_window_t > 0.0:
		momentum_window_t = maxf(0.0, momentum_window_t - dt)
		return
	if momentum_pending and immune_t <= 0.0:
		momentum_window_t = Rules.MOMENTUM_WINDOW
		momentum_pending = false


func _tick_statuses(dt: float) -> void:
	for key in statuses.keys():
		var s: Dictionary = statuses[key]
		var step := minf(dt, s.t)
		if key == "poisoned":
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
	special_flash_t = maxf(0.0, special_flash_t - dt)


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


func _start_attack(t: Unit) -> void:
	if pending_target != null:
		return
	pending_target = t
	pending_windup = windup()
	pending_t = pending_windup
	attack_timer = attack_interval()
	lunge_dir = (t.position - position).normalized()
	Sfx.play("windup", 0.05)


func _resolve_attack() -> void:
	var t := pending_target
	pending_target = null
	pending_t = 0.0
	pending_windup = 0.0
	if t == null or not t.alive:
		return
	lunge_dir = (t.position - position).normalized()
	lunge_t = 0.18
	Sfx.play("hit")
	if not is_melee():
		battle.spawn_projectile(self, t)
		return
	if data.ability == "cleave":
		for e in battle.enemies_near(self, t.position, data.radius * CELL):
			battle.damage(self, e, attack_damage(), "melee")
	else:
		battle.damage(self, t, attack_damage(), "melee")


# --- Abilities --------------------------------------------------------------

func _tick_ability() -> void:
	match data.ability:
		"guard":
			for a in battle.allies_near(self, position, data.radius * CELL):
				if a != self:
					a.add_status("guarded", 0.25, data.power, true)
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
				for e in battle.enemies_near(self, position, (2.0 * Rules.BODY_RADIUS + 0.6) * CELL):
					if e.is_melee():
						var away := (position - e.position).normalized()
						if away == Vector2.ZERO:
							away = Vector2.DOWN if team == 0 else Vector2.UP
						dash_vel = away * data.power * CELL / 0.25
						dash_t = 0.25
						ability_timer = data.cd
						battle.emit_fx("hop", position)
						break
		"display", "spray":
			# Retained vocabulary for future data; not used by the current roster.
			pass
		"dazzle":
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
					if data.get("cleanse", false):
						ally.cleanse_negative()
					ability_timer = data.cd
					battle.emit_fx("heal", ally.position, {"from": position})
		"inspire":
			for a in battle.allies_near(self, position, data.radius * CELL):
				if a != self:
					a.add_status("inspired", 0.35, data.power, true)


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
		attack_timer = attack_interval()
		lunge_dir = (target.position - position).normalized()
		lunge_t = 0.25
		battle.damage(self, target, attack_damage() * data.power, "ability")
		if target.alive:
			target.dash_vel = lunge_dir * data.knock * CELL / 0.25
			target.dash_t = 0.25
		battle.emit_fx("impact", target.position)
		Sfx.play("hit")


## Ranged forms step away from melee attackers while reloading.
func _kite(dt: float) -> bool:
	if attack_timer < 0.3:
		return false
	for e in battle.enemies_near(self, position, (2.0 * Rules.BODY_RADIUS + 0.5) * CELL):
		if e.is_melee():
			var away := (position - e.position).normalized()
			_move_towards(position + away * CELL, move_speed(), dt)
			return true
	return false


# --- Drawing ---------------------------------------------------------------

func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r := Rules.BODY_RADIUS * CELL
	var offset := lunge_dir * sin(lunge_t / 0.18 * PI) * 10.0 if lunge_t > 0.0 else Vector2.ZERO
	var scale_k := 1.0 + 0.35 * sin(pop_t / 0.45 * PI)
	var bob := Vector2(0, sin(anim_t * 6.0) * 1.2)
	var p := offset + bob

	# Ground shadow, team base and family accent.
	draw_circle(Vector2(0, r * 0.75), r * 0.95, Color(0, 0, 0, 0.25))
	Icons.team_base(self, p, r * scale_k, team, hovered)
	Icons.family_ring(self, p, r * scale_k + 4.0, family_color, anim_t)
	if dive_target != null:
		p += Vector2(0, -8)
	Icons.creature(self, form_id, p, r * 0.92 * scale_k)
	if shell_t > 0.0:
		draw_arc(p, r * 1.15, 0, TAU, 32, Color(0.5, 1.0, 0.6, 0.9), 4.0, true)
	if flash_t > 0.0:
		draw_circle(p, r * 1.05, Color(1, 1, 1, flash_t / 0.12 * 0.6))
	if immune_t > 0.0:
		Icons.immunity_ring(self, p, r * 1.3, immune_t / Rules.TARGET_IMMUNITY, anim_t)
	if momentum_window_t > 0.0:
		Icons.momentum_ring(self, p, r * 1.22, momentum_window_t / Rules.MOMENTUM_WINDOW, anim_t)
	if dodge_t > 0.0:
		Icons.dodge_shimmer(self, p, r * 1.1, dodge_t / Rules.DODGE_WINDOW)
	if special_flash_t > 0.0:
		draw_circle(p, r * (1.0 + 0.5 * special_flash_t), Color(family_color.r, family_color.g, family_color.b, special_flash_t * 0.35))
	if stage() > 0:
		var rune_pos := p + Vector2(r * 1.1, -r * 1.1)
		Icons.special_rune(self, rune_pos, 7.0, family_color, special_used, not is_final_stage())
		if not special_used:
			var pulse := 0.5 + 0.5 * sin(anim_t * 6.0)
			draw_arc(rune_pos, 9.0 + pulse * 3.0, 0, TAU, 12, Color(1.0, 1.0, 1.0, 0.35 * pulse), 1.5, true)
	if pending_target != null:
		var progress := 1.0 - pending_t / maxf(pending_windup, 0.001)
		Icons.windup_telegraph(self, data.attack_style, p, r, lunge_dir, progress, family_color)
	elif lunge_t > 0.0:
		Icons.attack_strike(self, data.attack_style, p, r, lunge_dir, 1.0 - lunge_t / 0.18, family_color)

	# Health bar, permanent stars and status icons.
	var bar_w := r * 2.2
	var bar_pos := Vector2(-bar_w * 0.5, r + 6.0)
	Icons.health_bar(self, bar_pos, bar_w, hp / max_hp, team)
	Icons.level_stars(self, Vector2(0, -r - 10.0), stars)
	var i := 0
	for key in statuses.keys():
		Icons.status(self, key, Vector2(-r - 4.0, -r + 2.0 + i * 13.0), 6.0)
		i += 1
