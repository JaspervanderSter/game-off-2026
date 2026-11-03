extends Node
## Owns the SHIFT targeting flow and every active swap transaction.
##
## Conflict rule: an entity + attribute pair can only participate in one active
## swap at a time. This makes restoration deterministic and safe.

signal mode_changed(mode: int)
signal selection_changed
signal swap_started(record: Dictionary)
signal swap_ended(record: Dictionary)
signal swaps_changed
signal notice(text: String, color: Color)

enum Mode { IDLE, SELECT_A, SELECT_B, ATTRIBUTE }

var mode: int = Mode.IDLE
var selected_a: Character = null
var selected_b: Character = null
var hovered: Character = null
var player: Character = null
var swaps: Array = []
var next_id: int = 1
var shift_ready_at_ms: int = 0
var match_active: bool = true
var _picker_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


func _enter_picker_pause() -> void:
	_picker_paused = not get_tree().paused
	get_tree().paused = true


func _leave_picker_pause() -> void:
	if _picker_paused:
		_picker_paused = false
		get_tree().paused = false
	else:
		_picker_paused = false


func reset_all() -> void:
	_leave_picker_pause()
	mode = Mode.IDLE
	selected_a = null
	selected_b = null
	hovered = null
	player = null
	swaps.clear()
	next_id = 1
	shift_ready_at_ms = 0
	match_active = true


func set_player(c: Character) -> void:
	player = c


# ---------------------------------------------------------------------------
# SHIFT selection
# ---------------------------------------------------------------------------
func is_shift_ready() -> bool:
	return Time.get_ticks_msec() >= shift_ready_at_ms


func shift_remaining() -> float:
	var now := Time.get_ticks_msec()
	return maxf(0.0, float(shift_ready_at_ms - now) / 1000.0)


func shift_progress() -> float:
	if GameConfig.shift_cooldown <= 0.0:
		return 1.0
	return clampf(1.0 - shift_remaining() / GameConfig.shift_cooldown, 0.0, 1.0)


func enter_targeting() -> void:
	if not match_active:
		return
	if player == null or not is_instance_valid(player) or not player.alive:
		return
	if mode != Mode.IDLE:
		cancel_selection()
		return
	if not is_shift_ready():
		notice.emit("SHIFT RECHARGING — %.1fs" % shift_remaining(), Palette.WARN)
		return
	selected_a = null
	selected_b = null
	mode = Mode.SELECT_A
	TimeManager.set_hold(GameConfig.targeting_scale)
	mode_changed.emit(mode)
	selection_changed.emit()


func is_selecting() -> bool:
	return mode == Mode.SELECT_A or mode == Mode.SELECT_B


func is_targeting() -> bool:
	return mode != Mode.IDLE


func is_valid_target(c: Character) -> bool:
	return match_active and is_instance_valid(c) and c.alive


func select_char(c: Character) -> void:
	if not is_selecting() or not is_valid_target(c):
		return
	if mode == Mode.SELECT_A:
		selected_a = c
		mode = Mode.SELECT_B
		mode_changed.emit(mode)
		selection_changed.emit()
		return
	if mode == Mode.SELECT_B:
		if c == selected_a:
			notice.emit("PICK TWO DIFFERENT ENTITIES", Palette.WARN)
			return
		selected_b = c
		mode = Mode.ATTRIBUTE
		_enter_picker_pause()
		mode_changed.emit(mode)
		selection_changed.emit()


func cancel_selection() -> void:
	if mode == Mode.IDLE:
		return
	mode = Mode.IDLE
	selected_a = null
	selected_b = null
	_leave_picker_pause()
	TimeManager.clear_hold()
	mode_changed.emit(mode)
	selection_changed.emit()


func get_selected_index(c: Character) -> int:
	if c == null:
		return 0
	if c == selected_a:
		return 1
	if c == selected_b:
		return 2
	return 0


# ---------------------------------------------------------------------------
# Options
# ---------------------------------------------------------------------------
func get_attr_options() -> Array:
	var out: Array = []
	if selected_a == null or selected_b == null:
		return out
	for attr in GameConfig.ATTRS:
		var rec_a := get_swap_for(selected_a, attr)
		var rec_b := get_swap_for(selected_b, attr)
		var ok := rec_a.is_empty() and rec_b.is_empty()
		var reason := ""
		if not rec_a.is_empty() or not rec_b.is_empty():
			reason = "ACTIVE SWAP"
		out.append({
			"attr": attr,
			"ok": ok,
			"reason": reason,
			"a": selected_a.get_stat(attr),
			"b": selected_b.get_stat(attr),
		})
	return out


func confirm_swap(attr: String) -> bool:
	if mode != Mode.ATTRIBUTE or selected_a == null or selected_b == null:
		return false
	var option_ok := false
	for o in get_attr_options():
		if str(o["attr"]) == attr and bool(o["ok"]):
			option_ok = true
			break
	if not option_ok:
		notice.emit("THAT ATTRIBUTE IS LOCKED", Palette.WARN)
		return false
	var a := selected_a
	var b := selected_b
	_leave_picker_pause()
	if not perform_swap(a, b, attr, "player", true):
		if mode == Mode.ATTRIBUTE:
			_enter_picker_pause()
		return false
	TimeManager.clear_hold()
	shift_ready_at_ms = Time.get_ticks_msec() + int(GameConfig.shift_cooldown * 1000.0)
	mode = Mode.IDLE
	selected_a = null
	selected_b = null
	mode_changed.emit(mode)
	selection_changed.emit()
	return true


# ---------------------------------------------------------------------------
# Transactions
# ---------------------------------------------------------------------------
func get_swap_for(c: Character, attr: String) -> Dictionary:
	if c == null:
		return {}
	for rec in swaps:
		if rec["attr"] == attr and (rec["a"] == c or rec["b"] == c):
			return rec
	return {}


func get_swaps_for(c: Character) -> Array:
	var out: Array = []
	if c == null:
		return out
	for rec in swaps:
		if rec["a"] == c or rec["b"] == c:
			out.append(rec)
	return out


func has_swaps(c: Character) -> bool:
	return get_swaps_for(c).size() > 0


func has_conflict(a: Character, b: Character, attr: String) -> bool:
	return not get_swap_for(a, attr).is_empty() or not get_swap_for(b, attr).is_empty()


func perform_swap(a: Character, b: Character, attr: String, owner: String = "player", animate: bool = true) -> bool:
	if not match_active:
		return false
	if a == null or b == null or a == b:
		return false
	if not is_instance_valid(a) or not is_instance_valid(b):
		return false
	if not a.alive or not b.alive:
		return false
	if not GameConfig.ATTRS.has(attr):
		return false
	if has_conflict(a, b, attr):
		return false

	var value_a: Variant = a.get_stat(attr)
	var value_b: Variant = b.get_stat(attr)
	var pct_a: float = a.health_pct()
	var pct_b: float = b.health_pct()

	var rec := {
		"id": next_id,
		"a": a,
		"b": b,
		"attr": attr,
		"orig_a": value_a,
		"orig_b": value_b,
		"start_ms": Time.get_ticks_msec(),
		"expires_ms": 0,
		"owner": owner,
	}
	next_id += 1

	if not animate:
		if not a.alive or not b.alive:
			return false
		_exchange(rec, pct_a, pct_b)
		_activate(rec)
		return true

	var duration := GameConfig.slowmo_duration
	var scale := GameConfig.slowmo_scale
	var apply_at := GameConfig.slowmo_apply_at
	if owner == "counter":
		duration = GameConfig.counter_slowmo_duration
		scale = GameConfig.counter_slowmo_scale
		apply_at = GameConfig.counter_slowmo_apply_at

	Fx.play_swap(a, b, attr, duration)
	var apply_cb := func() -> void:
		if not is_instance_valid(a) or not is_instance_valid(b):
			return
		if not a.alive or not b.alive:
			notice.emit("SHIFT LINK LOST — TARGET DOWN", Palette.WARN)
			return
		_exchange(rec, pct_a, pct_b)
		_activate(rec)
	TimeManager.run_focus(scale, duration, apply_at, apply_cb)
	return true


func _exchange(rec: Dictionary, pct_a: float, pct_b: float) -> void:
	var a: Character = rec["a"]
	var b: Character = rec["b"]
	var attr: String = rec["attr"]
	a.apply_stat(attr, rec["orig_b"], pct_a)
	b.apply_stat(attr, rec["orig_a"], pct_b)


func _activate(rec: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	rec["start_ms"] = now
	rec["expires_ms"] = now + int(GameConfig.swap_duration * 1000.0)
	swaps.append(rec)
	Fx.shake(8.0 if str(rec.get("owner", "")) != "counter" else 11.0)
	swap_started.emit(rec)
	swaps_changed.emit()


func _restore(rec: Dictionary) -> void:
	if not swaps.has(rec):
		return
	swaps.erase(rec)
	var a: Character = rec["a"]
	var b: Character = rec["b"]
	var attr: String = rec["attr"]
	if is_instance_valid(a) and a.alive:
		a.apply_stat(attr, rec["orig_a"], a.health_pct())
	if is_instance_valid(b) and b.alive:
		b.apply_stat(attr, rec["orig_b"], b.health_pct())
	swap_ended.emit(rec)
	swaps_changed.emit()


func remaining_seconds(rec: Dictionary) -> float:
	var now := Time.get_ticks_msec()
	return maxf(0.0, float(int(rec["expires_ms"]) - now) / 1000.0)


func remaining_fraction(rec: Dictionary) -> float:
	if GameConfig.swap_duration <= 0.0:
		return 0.0
	return clampf(remaining_seconds(rec) / GameConfig.swap_duration, 0.0, 1.0)


func on_character_died(c: Character) -> void:
	if mode != Mode.IDLE and (selected_a == c or selected_b == c):
		cancel_selection()
	var affected := get_swaps_for(c)
	if affected.is_empty():
		return
	for rec in affected.duplicate():
		_restore(rec)
	notice.emit("%s DOWN — SHIFT LINK SEVERED" % c.display_name, Palette.WARN)


func debug_restore_all() -> void:
	for rec in swaps.duplicate():
		_restore(rec)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()

	var expired: Array = []
	for rec in swaps:
		if now >= int(rec["expires_ms"]):
			expired.append(rec)
	for rec in expired:
		_restore(rec)

	if not match_active:
		return
	if mode != Mode.IDLE:
		if player != null and (not is_instance_valid(player) or not player.alive):
			cancel_selection()
		elif selected_a != null and (not is_instance_valid(selected_a) or not selected_a.alive):
			cancel_selection()
		elif selected_b != null and (not is_instance_valid(selected_b) or not selected_b.alive):
			cancel_selection()
