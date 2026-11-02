class_name Character
extends CharacterBody2D
## A living arena entity. All gameplay-relevant attributes are read from
## `stats.current` every time they are needed, so swapping an attribute takes
## effect immediately without touching character logic.

signal health_changed(current: float, maximum: float)
signal stat_changed(attr: String)
signal died(character: Character)
signal attacked(character: Character)

const TEAM_PLAYER := 0
const TEAM_ENEMY := 1

var team: int = 0
var archetype: String = ""
var display_name: String = ""
var stats: CharacterStats
var alive: bool = true
var is_player: bool = false
var radius: float = 16.0

var health: float = 0.0
var aim_dir: Vector2 = Vector2.RIGHT
var aim_point: Vector2 = Vector2.ZERO
var move_dir: Vector2 = Vector2.ZERO
var knockback_velocity: Vector2 = Vector2.ZERO

var attack_cd: float = 0.0
var special_cd: float = 0.0
var stun_time: float = 0.0

var hit_flash: float = 0.0
var swing_time: float = 0.0
var swing_duration: float = 0.15
var swing_angle: float = 0.0
var swing_range: float = 70.0
var swing_arc: float = 90.0
var swing_color: Color = Color.WHITE

var shield_hp: float = 0.0
var shield_max: float = 0.0
var shield_time: float = 0.0

var dash_time: float = 0.0
var dash_speed: float = 0.0
var dash_dir: Vector2 = Vector2.ZERO
var dash_damage: float = 0.0
var dash_knockback: float = 0.0
var dash_hit_radius: float = 30.0
var dash_color: Color = Color.WHITE
var dash_hits: Dictionary = {}
var dash_trail_timer: float = 0.0

var controller: Node = null
var collision_shape: CollisionShape2D

var _time: float = 0.0
var _death_time: float = 0.0
var _last_usec: int = 0
var _desired_ghost_timer: float = 0.0


func setup(p_archetype: String, p_team: int, p_is_player: bool, p_display_name: String) -> void:
	archetype = p_archetype
	team = p_team
	is_player = p_is_player
	display_name = p_display_name

	var def: Dictionary = GameConfig.archetype(p_archetype)
	radius = float(def.get("radius", 16.0))
	stats = CharacterStats.new()
	stats.setup(def, GameConfig.make_ability(str(def.get("ability", ""))), GameConfig.make_basic(p_archetype))
	health = float(stats.current["health"])

	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 1
	collision_mask = 1 | 2

	collision_shape = CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius * 0.92
	collision_shape.shape = shape
	add_child(collision_shape)

	aim_point = Vector2(200, 0)


func _ready() -> void:
	add_to_group("characters")
	_last_usec = Time.get_ticks_usec()
	queue_redraw()


func _take_unscaled_delta() -> float:
	var now := Time.get_ticks_usec()
	var d := 0.0
	if _last_usec > 0:
		d = float(now - _last_usec) / 1_000_000.0
	_last_usec = now
	return clampf(d, 0.0, 0.1)


func _physics_process(delta: float) -> void:
	var rdt := _take_unscaled_delta()
	_time += rdt
	hit_flash = maxf(0.0, hit_flash - rdt)
	swing_time = maxf(0.0, swing_time - rdt)

	if not alive:
		_death_time += rdt
		queue_redraw()
		return

	attack_cd = maxf(0.0, attack_cd - delta)
	special_cd = maxf(0.0, special_cd - delta)
	stun_time = maxf(0.0, stun_time - delta)

	if shield_time > 0.0:
		shield_time -= delta
		if shield_time <= 0.0:
			shield_time = 0.0
			shield_hp = 0.0

	if aim_point != Vector2.ZERO:
		var aim_vec := aim_point - global_position
		if aim_vec.length_squared() > 1.0:
			aim_dir = aim_vec.normalized()

	var speed := float(stats.current["speed"]) * GameConfig.move_speed_scale
	var vel := Vector2.ZERO

	if dash_time > 0.0:
		dash_time -= delta
		vel = dash_dir * dash_speed + knockback_velocity * 0.2
		_check_dash_contacts()
		dash_trail_timer -= rdt
		if dash_trail_timer <= 0.0:
			dash_trail_timer = 0.03
			Fx.trail_dot(global_position + _rand_offset(radius * 0.55), Color(dash_color, 0.5), 4.0)
	elif stun_time > 0.0:
		vel = knockback_velocity
	else:
		vel = move_dir * speed + knockback_velocity

	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, GameConfig.knockback_decay * delta)
	velocity = vel
	move_and_slide()
	_clamp_to_arena()
	queue_redraw()


func _rand_offset(r: float) -> Vector2:
	return Vector2(randf_range(-r, r), randf_range(-r, r))


func _clamp_to_arena() -> void:
	var r: Rect2 = GameConfig.arena_rect
	var inset: float = GameConfig.arena_inset + radius * 0.35
	global_position.x = clampf(global_position.x, r.position.x + inset, r.end.x - inset)
	global_position.y = clampf(global_position.y, r.position.y + inset, r.end.y - inset)


func _check_dash_contacts() -> void:
	for o in get_living_opponents():
		if dash_hits.has(o):
			continue
		if global_position.distance_to(o.global_position) <= dash_hit_radius + o.radius:
			dash_hits[o] = true
			o.take_damage(dash_damage, global_position, dash_knockback, float(stats.current["weight"]), self)
			Fx.burst(o.global_position, dash_color, 10, 140.0, 2.0)


# ---------------------------------------------------------------------------
# Combat
# ---------------------------------------------------------------------------
func try_basic_attack() -> bool:
	if not alive or stun_time > 0.0 or dash_time > 0.0:
		return false
	if attack_cd > 0.0:
		return false

	var b: BasicAttack = stats.current["basic"]
	if b == null:
		return false
	attack_cd = float(stats.current["attack_cooldown"])

	var strength := float(stats.current["strength"])
	var dmg := strength * b.damage_mult * GameConfig.damage_scale
	var kb := b.knockback
	var col := b.color
	var weight := float(stats.current["weight"])

	swing_duration = b.swing
	swing_time = swing_duration
	swing_angle = aim_dir.angle()
	swing_range = b.range
	swing_arc = b.arc
	swing_color = col

	if b.kind == "ranged":
		spawn_projectile(aim_dir, dmg, kb, col, b.projectile_speed, b.projectile_radius)
		Fx.burst(global_position + aim_dir * (radius + 6.0), col, 6, 90.0, 1.8)
		attacked.emit(self)
		return true

	var hit_any := false
	for o in get_living_opponents():
		var to: Vector2 = o.global_position - global_position
		var dist := to.length()
		if dist > swing_range + o.radius:
			continue
		var dir := to.normalized() if dist > 0.001 else aim_dir
		var ang := rad_to_deg(abs(aim_dir.angle_to(dir)))
		if ang <= swing_arc * 0.5 or dist < radius * 0.6:
			o.take_damage(dmg, global_position, kb, weight, self)
			hit_any = true

	if hit_any:
		Fx.burst(global_position + aim_dir * swing_range * 0.65, col, 8, 110.0, 2.0)
		Fx.shake(2.5)
	attacked.emit(self)
	return true


func try_special() -> bool:
	if not alive or stun_time > 0.0 or dash_time > 0.0:
		return false
	if special_cd > 0.0:
		return false
	var ability: Ability = stats.current["special"]
	if ability == null:
		return false
	special_cd = float(stats.current["special_cooldown"])
	ability.execute(self, aim_dir)
	attacked.emit(self)
	return true


func spawn_projectile(dir: Vector2, dmg: float, kb: float, col: Color, speed: float, p_radius: float) -> void:
	var d := dir.normalized()
	if d == Vector2.ZERO:
		d = aim_dir
	var p := Projectile.new()
	p.setup(self, team, dmg, kb, float(stats.current["weight"]), col, speed, p_radius)
	p.direction = d
	var parent := get_parent()
	if parent == null:
		return
	parent.add_child(p)
	p.global_position = global_position + d * (radius + 10.0)


func start_dash(dir: Vector2, distance: float, speed: float, dmg: float, kb: float, hit_radius: float, col: Color) -> void:
	if not alive:
		return
	var d := dir.normalized()
	if d == Vector2.ZERO:
		d = aim_dir
	dash_dir = d
	dash_speed = speed
	dash_time = maxf(0.05, distance / maxf(1.0, speed))
	dash_damage = dmg
	dash_knockback = kb
	dash_hit_radius = hit_radius
	dash_color = col
	dash_hits.clear()
	dash_trail_timer = 0.0


func blink(dir: Vector2, distance: float) -> void:
	var d := dir.normalized()
	if d == Vector2.ZERO:
		d = aim_dir
	var target := global_position + d * distance
	var r: Rect2 = GameConfig.arena_rect
	var inset: float = GameConfig.arena_inset + radius + 6.0
	target.x = clampf(target.x, r.position.x + inset, r.end.x - inset)
	target.y = clampf(target.y, r.position.y + inset, r.end.y - inset)
	global_position = target


func add_shield(amount: float, duration: float) -> void:
	shield_max = amount
	shield_hp = amount
	shield_time = duration


func stun(duration: float) -> void:
	stun_time = maxf(stun_time, duration)
	swing_time = 0.0


func take_damage(amount: float, source_pos: Vector2, knockback_force: float, source_weight: float, attacker: Character) -> void:
	if not alive or amount <= 0.0:
		return
	if attacker != null and attacker != self and attacker.team == team:
		return

	var remaining := amount
	var absorbed := 0.0
	if shield_time > 0.0 and shield_hp > 0.0:
		absorbed = minf(shield_hp, remaining)
		shield_hp -= absorbed
		remaining -= absorbed
		if absorbed > 0.0:
			Fx.text_pop(global_position + Vector2(0, -radius - 4.0), "ABSORB", Palette.ABILITY_SHIELD, 11)
			Fx.ring(global_position, Palette.ABILITY_SHIELD, radius + 2.0, radius + 16.0, 0.18, 1.5)
		if shield_hp <= 0.0:
			shield_hp = 0.0
			shield_time = 0.0
			Fx.ring(global_position, Palette.ABILITY_SHIELD, radius + 4.0, radius + 26.0, 0.3, 2.0)

	if remaining > 0.0:
		health -= remaining
		hit_flash = 0.14
		Fx.damage_number(global_position + Vector2(randf_range(-8.0, 8.0), -radius - 16.0), remaining, Color("#ffd8a8"))
		Fx.burst(global_position, Palette.team_color(team).lightened(0.25), int(clampf(remaining * 0.5, 3.0, 14.0)), 120.0, 1.8)

	if knockback_force > 0.0:
		apply_knockback(source_pos, knockback_force, source_weight)

	health_changed.emit(maxf(health, 0.0), max_health())
	if health <= 0.0:
		die()


func apply_knockback(source_pos: Vector2, force: float, source_weight: float) -> void:
	if not alive:
		return
	if shield_time > 0.0:
		force *= GameConfig.shield_knockback_resist
	var dir := global_position - source_pos
	if dir.length_squared() < 0.001:
		dir = -aim_dir if aim_dir != Vector2.ZERO else Vector2.RIGHT
	dir = dir.normalized()
	var resist := maxf(1.0, float(stats.current["weight"]) * 0.55)
	var impulse := force * (0.55 + source_weight * 0.09) / resist
	knockback_velocity += dir * impulse


func die() -> void:
	if not alive:
		return
	alive = false
	health = 0.0
	move_dir = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	dash_time = 0.0
	shield_time = 0.0
	shield_hp = 0.0
	stun_time = 0.0
	_col_death()

	health_changed.emit(0.0, max_health())
	SwapManager.on_character_died(self)
	Fx.burst(global_position, Palette.team_color(team), 30, 220.0, 3.0)
	Fx.ring(global_position, Palette.team_color(team), radius, radius + 70.0, 0.6, 3.0)
	Fx.text_pop(global_position + Vector2(0, -radius - 20.0), "DOWN", Palette.team_color(team), 14)
	died.emit(self)
	queue_redraw()


func _col_death() -> void:
	collision_layer = 0
	collision_mask = 0
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)


# ---------------------------------------------------------------------------
# Attribute access
# ---------------------------------------------------------------------------
func get_stat(attr: String) -> Variant:
	return stats.current.get(attr)


func max_health() -> float:
	return float(stats.current["health"])


func health_pct() -> float:
	var m := max_health()
	if m <= 0.0:
		return 0.0
	return clampf(health / m, 0.0, 1.0)


func apply_stat(attr: String, value: Variant, hp_pct: float) -> void:
	if attr == "health":
		var new_max := maxf(1.0, float(value))
		stats.current["health"] = new_max
		health = clampf(hp_pct * new_max, 0.0, new_max)
		if alive and health < 1.0:
			health = minf(1.0, new_max)
		health_changed.emit(health, new_max)
	elif attr == "attack_cooldown":
		stats.current[attr] = float(value)
		attack_cd = minf(attack_cd, float(value))
	elif attr == "special_cooldown":
		stats.current[attr] = float(value)
		special_cd = minf(special_cd, float(value))
	else:
		stats.current[attr] = value
	stat_changed.emit(attr)
	queue_redraw()


func set_aim(world_pos: Vector2) -> void:
	aim_point = world_pos
	var d := world_pos - global_position
	if d.length_squared() > 1.0:
		aim_dir = d.normalized()


func is_melee() -> bool:
	var b := current_basic()
	return b == null or b.kind == "melee"


func current_basic() -> BasicAttack:
	return stats.current.get("basic")


func base_basic() -> BasicAttack:
	return stats.base.get("basic")


func current_ability() -> Ability:
	return stats.current.get("special")


func base_ability() -> Ability:
	return stats.base.get("special")


func get_team_color() -> Color:
	return Palette.team_color(team)


func get_living_opponents() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("characters"):
		if n is Character and n != self and n.alive and n.team != team:
			out.append(n)
	return out


func get_living_allies() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("characters"):
		if n is Character and n != self and n.alive and n.team == team:
			out.append(n)
	return out


func nearest_opponent() -> Character:
	var best: Character = null
	var best_d := INF
	for o in get_living_opponents():
		var d: float = global_position.distance_squared_to(o.global_position)
		if d < best_d:
			best_d = d
			best = o
	return best


func count_opponents_within(r: float) -> int:
	var count := 0
	for o in get_living_opponents():
		if global_position.distance_to(o.global_position) <= r:
			count += 1
	return count


func is_swap_marked() -> bool:
	return SwapManager.has_swaps(self)


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------
func _draw() -> void:
	var team_col := Palette.team_color(team)
	var team_dark := Palette.team_dark(team)
	var font := ThemeDB.fallback_font

	if not alive:
		var fade := clampf(1.0 - _death_time / 1.4, 0.0, 1.0)
		if fade <= 0.0:
			return
		_draw_ellipse(Vector2(0, radius * 0.75), radius * 0.95, radius * 0.36, Color(0, 0, 0, 0.25 * fade))
		draw_circle(Vector2.ZERO, radius, Color(team_dark, 0.5 * fade))
		draw_arc(Vector2.ZERO, radius + 1.0, 0, TAU, 32, Color(team_col, 0.5 * fade), 2.0, true)
		return

	var body_fill := team_dark.lerp(team_col, 0.24)
	if hit_flash > 0.0:
		body_fill = body_fill.lerp(Color.WHITE, 0.8)

	# Ground shadow
	_draw_ellipse(Vector2(0, radius * 0.78), radius * 0.98, radius * 0.38, Color(0, 0, 0, 0.35))

	# Soft aura
	draw_circle(Vector2.ZERO, radius * 1.55, Color(team_col, 0.065))

	# Active-swap aura (purple rotating arcs)
	if is_swap_marked():
		for i in range(2):
			var a0 := _time * 1.6 + float(i) * PI
			draw_arc(Vector2.ZERO, radius + 7.0, a0, a0 + 1.5, 18, Color(Palette.SWAP, 0.85), 2.0, true)

	# Selection / hover rings
	if SwapManager.is_targeting() and SwapManager.is_valid_target(self):
		var selected_index := SwapManager.get_selected_index(self)
		if selected_index > 0:
			var glow := 0.55 + 0.35 * sin(_time * 6.0)
			draw_arc(Vector2.ZERO, radius + 16.0, 0, TAU, 40, Color(Palette.WARN, glow), 3.0, true)
			draw_arc(Vector2.ZERO, radius + 20.0, 0, TAU, 40, Color(Palette.WARN, glow * 0.4), 6.0, true)
			draw_circle(Vector2(0, -radius - 33.0), 8.0, Palette.WARN)
			draw_string(font, Vector2(-8, -radius - 29.0), str(selected_index), HORIZONTAL_ALIGNMENT_CENTER, 16, 11, Palette.BG)
		else:
			var pulse := 0.35 + 0.3 * sin(_time * 4.0)
			draw_arc(Vector2.ZERO, radius + 12.0, 0, TAU, 32, Color(Palette.WHITE, pulse), 1.6, true)

	# Body silhouette
	_draw_body(body_fill, team_col, team_dark)

	# Status rings
	if shield_time > 0.0 and shield_hp > 0.0:
		var shield_pct := clampf(shield_hp / maxf(1.0, shield_max), 0.0, 1.0)
		_draw_hex(Vector2.ZERO, radius + 9.0, Color(Palette.ABILITY_SHIELD, 0.35 + shield_pct * 0.4), 2.0)
		draw_arc(Vector2.ZERO, radius + 9.0, -PI * 0.5, -PI * 0.5 + TAU * shield_pct, 40, Palette.ABILITY_SHIELD, 3.0, true)

	if dash_time > 0.0:
		draw_line(-dash_dir * (radius + 26.0), -dash_dir * (radius + 4.0), Color(dash_color, 0.8), 3.0, true)

	# Equipped ability orb
	var ability := current_ability()
	if ability != null:
		var orbit := Vector2(cos(_time * 1.7), sin(_time * 1.7)) * (radius + 11.0)
		draw_circle(orbit, 6.0, Color(ability.color, 0.16))
		draw_circle(orbit, 3.4, ability.color)
		_draw_ability_icon(orbit, ability.id, ability.color, 4.2)

	# Swing arc
	if swing_time > 0.0:
		var t := 1.0 - swing_time / maxf(0.01, swing_duration)
		var alpha := (1.0 - t) * 0.85
		var a_from := swing_angle - deg_to_rad(swing_arc) * 0.5
		var a_to := swing_angle + deg_to_rad(swing_arc) * 0.5
		draw_arc(Vector2.ZERO, swing_range * (0.55 + 0.45 * t), a_from, a_to, 24, Color(swing_color, alpha), 5.0, true)
		draw_arc(Vector2.ZERO, swing_range * (0.48 + 0.45 * t), a_from, a_to, 24, Color(swing_color, alpha * 0.4), 9.0, true)

	# Stun
	if stun_time > 0.0:
		for i in range(3):
			var a := _time * 6.0 + float(i) * TAU / 3.0
			var p := Vector2(cos(a), sin(a)) * (radius + 4.0) + Vector2(0, -radius - 6.0)
			draw_circle(p, 2.0, Palette.WARN)

	var bar_w := 50.0
	var bar_h := 6.0
	var top := -radius - 24.0

	# Name
	var tag := display_name
	if is_player:
		tag = "YOU · " + display_name
	var name_col := team_col.lerp(Palette.TEXT, 0.45)
	draw_string(font, Vector2(-58, top - 11.0), tag, HORIZONTAL_ALIGNMENT_CENTER, 116, 10, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(-58, top - 12.0), tag, HORIZONTAL_ALIGNMENT_CENTER, 116, 10, name_col)

	# Health bar
	draw_rect(Rect2(-bar_w * 0.5 - 1.0, top - 1.0, bar_w + 2.0, bar_h + 2.0), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-bar_w * 0.5, top, bar_w, bar_h), Color(0.07, 0.11, 0.16))
	var pct := health_pct()
	draw_rect(Rect2(-bar_w * 0.5, top, bar_w * pct, bar_h), team_col)
	draw_rect(Rect2(-bar_w * 0.5, top, bar_w, 1.0), Color(1, 1, 1, 0.15))
	if shield_time > 0.0 and shield_hp > 0.0:
		var sp := clampf(shield_hp / maxf(1.0, shield_max), 0.0, 1.0)
		draw_rect(Rect2(-bar_w * 0.5, top - 4.0, bar_w * sp, 2.0), Palette.ABILITY_SHIELD)

	# Player chevron
	if is_player:
		var bob := sin(_time * 4.0) * 1.5
		var cy := top - 28.0 + bob
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, cy + 5), Vector2(-5, cy - 2), Vector2(5, cy - 2)
		]), Color(team_col, 0.9))


func _draw_ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(24):
		var a := TAU * float(i) / 24.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _draw_hex(center: Vector2, r: float, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in range(7):
		var a := TAU * float(i) / 6.0 - PI * 0.5
		pts.append(center + Vector2(cos(a) * r, sin(a) * r))
	draw_polyline(pts, col, width, true)


func _draw_body(fill: Color, team_col: Color, team_dark: Color) -> void:
	var edge := team_col
	match str(GameConfig.archetype(archetype).get("shape", "circle")):
		"bruiser":
			# Bulky slabs + fists
			draw_circle(Vector2.ZERO, radius, fill)
			draw_circle(Vector2(-radius * 0.82, -radius * 0.28), radius * 0.42, team_dark.lightened(0.08))
			draw_circle(Vector2(radius * 0.82, -radius * 0.28), radius * 0.42, team_dark.lightened(0.08))
			var fist_dir := aim_dir.rotated(0.0)
			draw_circle(fist_dir.rotated(0.62) * (radius * 1.15), radius * 0.32, fill.lightened(0.15))
			draw_circle(fist_dir.rotated(-0.62) * (radius * 1.15), radius * 0.32, fill.lightened(0.15))
		"runner":
			var back := -aim_dir
			draw_colored_polygon(PackedVector2Array([
				back.rotated(0.5) * radius, back * (radius * 1.75), back.rotated(-0.5) * radius
			]), Color(team_dark, 0.95))
			draw_circle(Vector2.ZERO, radius, fill)
			draw_line(Vector2(0, -radius * 0.25), aim_dir * radius * 1.1, edge, 2.0, true)
			draw_line(Vector2(0, radius * 0.35), -aim_dir * radius * 0.9, Color(team_col, 0.5), 1.5, true)
		"tank":
			var pts := PackedVector2Array()
			for i in range(6):
				var a := TAU * float(i) / 6.0 + PI / 6.0
				pts.append(Vector2(cos(a) * radius, sin(a) * radius))
			draw_colored_polygon(pts, fill)
			draw_rect(Rect2(-radius * 0.45, -radius * 0.45, radius * 0.9, radius * 0.9), Color(team_dark, 0.55), false, 2.0)
			draw_line(Vector2(-radius * 0.7, 0), Vector2(radius * 0.7, 0), Color(team_col, 0.25), 1.0)
		"ranger":
			draw_circle(Vector2.ZERO, radius, fill)
			var ba := current_basic()
			if ba != null and ba.kind == "ranged":
				var tip := aim_dir * (radius + 20.0)
				var side := aim_dir.rotated(PI * 0.5) * radius * 0.4
				draw_line(aim_dir * radius * 0.2 + side, tip + side, team_dark.lightened(0.25), 3.0, true)
				draw_line(aim_dir * radius * 0.2 - side, tip - side, team_dark.lightened(0.25), 3.0, true)
				draw_circle(tip, 3.0, edge)
			else:
				var blade_col := edge if ba == null else ba.color
				draw_line(aim_dir * radius * 0.2, aim_dir * (radius + 15.0), blade_col, 3.0, true)
				draw_arc(Vector2.ZERO, radius + 9.0, aim_dir.angle() - 0.5, aim_dir.angle() + 0.5, 12, Color(blade_col, 0.5), 2.0, true)
		"trickster":
			var diamond := PackedVector2Array([
				Vector2(0, -radius * 1.05), Vector2(radius * 0.92, 0),
				Vector2(0, radius * 1.05), Vector2(-radius * 0.92, 0)
			])
			draw_colored_polygon(diamond, fill)
			for i in range(3):
				var a := _time * 2.1 + float(i) * TAU / 3.0
				draw_circle(Vector2(cos(a), sin(a)) * (radius + 8.0), 1.7, Color(edge, 0.75))
		_:
			draw_circle(Vector2.ZERO, radius, fill)

	# Visor / facing marker
	var visor_a := aim_dir
	var visor_pos := visor_a * (radius * 0.45)
	draw_circle(visor_pos, maxf(2.0, radius * 0.16), edge.lightened(0.35))

	# Small weapon-type marker when the stolen basic attack changes combat style.
	var basic_now := current_basic()
	var basic_base := base_basic()
	if basic_now != null and basic_base != null and basic_now.kind != basic_base.kind:
		var marker := Vector2(-radius * 0.9, radius * 0.7)
		if basic_now.kind == "ranged":
			draw_line(marker, marker + Vector2(10, 0), Color(basic_now.color, 0.95), 1.6, true)
			draw_colored_polygon(PackedVector2Array([
				marker + Vector2(10, 0), marker + Vector2(6, -2.5), marker + Vector2(6, 2.5)
			]), Color(basic_now.color, 0.95))
		else:
			draw_arc(marker + Vector2(3, 0), 5.0, -0.9, 0.9, 10, Color(basic_now.color, 0.8), 1.4, true)

	# Outline
	draw_arc(Vector2.ZERO, radius + 1.0, 0, TAU, 36, edge, 2.2, true)
	if is_player:
		var glow := 0.35 + 0.25 * sin(_time * 4.0)
		draw_arc(Vector2.ZERO, radius + 4.0, 0, TAU, 36, Color(Palette.WHITE, glow), 1.2, true)


func _draw_ability_icon(pos: Vector2, id: String, col: Color, s: float) -> void:
	var dark := Color(0.02, 0.03, 0.05, 0.9)
	match id:
		"ground_slam":
			draw_arc(pos, s, 0, TAU, 12, dark, 1.2, true)
			draw_circle(pos, s * 0.4, dark)
		"dash":
			draw_line(pos + Vector2(-s, -s * 0.7), pos + Vector2(s * 0.4, 0), dark, 1.4, true)
			draw_line(pos + Vector2(-s, s * 0.7), pos + Vector2(s * 0.4, 0), dark, 1.4, true)
		"shield":
			var pts := PackedVector2Array()
			for i in range(7):
				var a := TAU * float(i) / 6.0 - PI * 0.5
				pts.append(pos + Vector2(cos(a) * s, sin(a) * s))
			draw_polyline(pts, dark, 1.2, true)
		"multishot":
			for i in range(3):
				var a := -0.5 + float(i) * 0.5
				draw_circle(pos + Vector2(cos(a), sin(a)) * s, 1.1, dark)
		"blink":
			draw_line(pos + Vector2(-s, 0), pos + Vector2(s, 0), dark, 1.2, true)
			draw_line(pos + Vector2(0, -s), pos + Vector2(0, s), dark, 1.2, true)
		_:
			draw_circle(pos, s * 0.4, dark)
