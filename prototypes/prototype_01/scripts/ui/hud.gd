class_name GameHUD
extends Control
## Immediate-mode HUD: player status, character inspector, team status, active
## swap ledger, ability footer and the SHIFT prompt.

const PLAYER_SIZE := Vector2(340, 329)
const TEAM_SIZE := Vector2(440, 56)
const HOVER_SIZE := Vector2(440, 244)
const FOOTER_SIZE := Vector2(320, 104)
const SHIFT_SIZE := Vector2(220, 34)

var combat: CombatManager
var hovered: Character = null
var banner_text: String = ""
var banner_color: Color = Color.WHITE
var banner_time: float = 0.0
var banner_total: float = 1.0

var flash_time: float = 0.0
var flash_total: float = 1.0
var flash_color: Color = Color.WHITE

var _time: float = 0.0
var _last_usec: int = 0
var _char_screens: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_last_usec = Time.get_ticks_usec()


func show_banner(text: String, color: Color, duration: float = 2.2) -> void:
	banner_text = text
	banner_color = color
	banner_time = duration
	banner_total = duration


func flash(color: Color, duration: float = 0.35) -> void:
	flash_color = color
	flash_time = duration
	flash_total = duration


func contains_ui_point(pos: Vector2) -> bool:
	if combat != null and combat.state != CombatManager.State.PLAYING:
		return true
	for r in _panel_rects():
		if r.has_point(pos):
			return true
	return false


func _player_rect() -> Rect2:
	return Rect2(16, 16, PLAYER_SIZE.x, PLAYER_SIZE.y)


func _team_rect() -> Rect2:
	return Rect2(size.x * 0.5 - TEAM_SIZE.x * 0.5, 16, TEAM_SIZE.x, TEAM_SIZE.y)


func _hover_rect() -> Rect2:
	return Rect2(16, size.y - 16.0 - HOVER_SIZE.y, HOVER_SIZE.x, HOVER_SIZE.y)


func _footer_rect() -> Rect2:
	return Rect2(size.x - 16.0 - FOOTER_SIZE.x, size.y - 16.0 - FOOTER_SIZE.y, FOOTER_SIZE.x, FOOTER_SIZE.y)


func _shift_rect() -> Rect2:
	return Rect2(size.x * 0.5 - SHIFT_SIZE.x * 0.5, size.y - 16.0 - SHIFT_SIZE.y, SHIFT_SIZE.x, SHIFT_SIZE.y)


func _panel_rects() -> Array:
	var rects: Array = [_player_rect(), _team_rect(), _swaps_rect(), _footer_rect(), _shift_rect()]
	if _inspect_target() != null:
		rects.append(_hover_rect())
	return rects


func _inspect_target() -> Character:
	if SwapManager.mode == SwapManager.Mode.ATTRIBUTE:
		return null
	if hovered != null and is_instance_valid(hovered) and hovered.alive:
		return hovered
	if SwapManager.selected_b != null and is_instance_valid(SwapManager.selected_b) and SwapManager.selected_b.alive:
		return SwapManager.selected_b
	if SwapManager.selected_a != null and is_instance_valid(SwapManager.selected_a) and SwapManager.selected_a.alive:
		return SwapManager.selected_a
	return null


func _swaps_rect() -> Rect2:
	var count := SwapManager.swaps.size()
	var x := size.x - 16.0 - 340.0
	if count == 0:
		return Rect2(x, 16, 340, 58)
	var shown := mini(count, 6)
	var extra := 12.0 if count > 6 else 0.0
	var h := 34.0 + float(shown) * 30.0 + extra + 6.0
	return Rect2(x, 16, 340, h)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var rdt := clampf(float(now - _last_usec) / 1_000_000.0, 0.0, 0.1)
	_last_usec = now
	_time += rdt
	if banner_time > 0.0:
		banner_time = maxf(0.0, banner_time - rdt)
	if flash_time > 0.0:
		flash_time = maxf(0.0, flash_time - rdt)
	queue_redraw()


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------
func _draw() -> void:
	if combat == null or combat.player == null:
		return
	_refresh_char_screens()
	_draw_player_panel()
	_draw_hover_panel()
	_draw_team_panel()
	_draw_swaps_panel()
	_draw_footer()
	_draw_shift_pill()
	_draw_swap_mode()
	_draw_time_dilation()
	_draw_banner()
	_draw_flash()
	if combat.state != CombatManager.State.PLAYING:
		_draw_match_overlay()


func _draw_flash() -> void:
	if flash_time <= 0.0:
		return
	var a := flash_time / maxf(0.01, flash_total)
	draw_rect(Rect2(Vector2.ZERO, size), Color(flash_color, 0.055 * a))
	draw_rect(Rect2(5, 5, size.x - 10, size.y - 10), Color(flash_color, 0.16 * a), false, 2.0)


func _refresh_char_screens() -> void:
	_char_screens.clear()
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var center := size * 0.5
	var cam_pos := cam.global_position + cam.offset
	for n in get_tree().get_nodes_in_group("characters"):
		if n is Character and n.alive:
			_char_screens.append(center + (n.global_position - cam_pos) * cam.zoom)


func _char_under_rect(rect: Rect2) -> bool:
	var padded := rect.grow(12.0)
	for p in _char_screens:
		if padded.has_point(p):
			return true
	return false


func _panel_bg(rect: Rect2, alpha_normal: float = 0.93) -> Color:
	if _char_under_rect(rect):
		return Color(Palette.PANEL, 0.34)
	return Color(Palette.PANEL, alpha_normal)


func _draw_player_panel() -> void:
	var p: Character = combat.player
	var r := _player_rect()
	var team_col := Palette.team_color(p.team)
	UIKit.panel(self, r, _panel_bg(r), Color(team_col, 0.35 if p.alive else 0.15), 7)
	draw_rect(Rect2(r.position.x, r.position.y + 8, 3, r.size.y - 16), Color(team_col, 0.8 if p.alive else 0.25))

	UIKit.text(self, Vector2(r.position.x + 12, r.position.y + 28), p.display_name, 15, Color(team_col, 1.0 if p.alive else 0.5))
	var name_w := UIKit.text_width(p.display_name, 15)
	UIKit.text(self, Vector2(r.position.x + 18 + name_w, r.position.y + 28), "· " + p.archetype.to_upper(), 10, Palette.MUTED)
	var sub := "BLUE TEAM · YOU" if p.alive else "SPECTATING — TEAM STILL FIGHTING"
	UIKit.text(self, Vector2(r.position.x + 12, r.position.y + 45), sub, 8, Palette.WARN if not p.alive else Palette.MUTED)

	var hp_bar := Rect2(r.position.x + 12, r.position.y + 54, r.size.x - 24, 16)
	UIKit.bar(self, hp_bar, p.health_pct(), Color(team_col, 0.9))
	UIKit.text_center(self, hp_bar.get_center().x, hp_bar.position.y + 12.0, "%d / %d" % [int(ceil(p.health)), int(p.max_health())], 9, Palette.WHITE)

	# Column headers
	var hx := r.position.x
	UIKit.text(self, Vector2(hx + 12, r.position.y + 94), "ATTR", 8, Palette.DIM)
	UIKit.text_right(self, hx + 228, r.position.y + 94, "NOW", 8, Palette.DIM)
	UIKit.text_right(self, hx + 284, r.position.y + 94, "BASE", 8, Palette.DIM)
	UIKit.text(self, Vector2(hx + 294, r.position.y + 94), "SHIFT", 8, Palette.DIM)

	var row_y := r.position.y + 102.0
	for attr_v in GameConfig.ATTRS:
		var attr := str(attr_v)
		var rec := SwapManager.get_swap_for(p, attr)
		var now_val: Variant = p.get_stat(attr)
		var base_val: Variant = p.stats.base_value(attr)
		var quality := GameConfig.attr_quality(attr, now_val, base_val)
		var now_text := GameConfig.attr_text(attr, now_val)
		var base_text := GameConfig.attr_text(attr, base_val)
		var now_col := Palette.TEXT
		if not rec.is_empty():
			now_col = Palette.SWAP
		elif quality > 0:
			now_col = Palette.BUFF
		elif quality < 0:
			now_col = Palette.DEBUFF

		UIKit.text(self, Vector2(hx + 12, row_y + 12), str(GameConfig.ATTR_LABELS[attr]), 9, Color(Palette.attr_color(attr), 0.9))
		UIKit.text_right(self, hx + 228, row_y + 12, now_text, 9, now_col)
		UIKit.text_right(self, hx + 284, row_y + 12, base_text, 8, Palette.MUTED)
		if not rec.is_empty():
			UIKit.text(self, Vector2(hx + 294, row_y + 12), "%.1fs" % SwapManager.remaining_seconds(rec), 8, Palette.SWAP)
		elif quality > 0:
			UIKit.text(self, Vector2(hx + 294, row_y + 12), "▲", 8, Palette.BUFF)
		elif quality < 0:
			UIKit.text(self, Vector2(hx + 294, row_y + 12), "▼", 8, Palette.DEBUFF)
		row_y += 17.0

	draw_line(Vector2(hx + 12, r.position.y + 241), Vector2(r.end.x - 12, r.position.y + 241), Color(Palette.PANEL_EDGE, 0.7), 1.0)

	var ability := p.current_ability()
	var cd_rows := [
		{"label": "ATK", "cd": p.attack_cd, "max": float(p.stats.current["attack_cooldown"]), "col": Palette.ATTR_ACD, "ready": p.attack_cd <= 0.001},
		{"label": "SPEC", "cd": p.special_cd, "max": float(p.stats.current["special_cooldown"]), "col": ability.color if ability != null else Palette.SWAP, "ready": p.special_cd <= 0.001},
		{"label": "SHIFT", "cd": SwapManager.shift_remaining(), "max": GameConfig.shift_cooldown, "col": Palette.SWAP, "ready": SwapManager.is_shift_ready()},
	]
	var cy := r.position.y + 253.0
	for row_v in cd_rows:
		var row: Dictionary = row_v
		var maximum: float = maxf(0.01, float(row["max"]))
		var cd: float = float(row["cd"])
		var pct := 1.0 - clampf(cd / maximum, 0.0, 1.0)
		UIKit.text(self, Vector2(hx + 12, cy + 10), str(row["label"]), 8, Palette.MUTED)
		UIKit.bar(self, Rect2(hx + 64, cy + 2, 174, 7), pct, row["col"])
		var ready: bool = bool(row["ready"])
		var state_text := "READY" if ready else ("%.1fs" % cd)
		UIKit.text_right(self, r.end.x - 12, cy + 10, state_text, 8, Palette.BUFF if ready else Palette.MUTED)
		cy += 18.0

	var own_swaps := SwapManager.get_swaps_for(p).size()
	var foot_text := "NO ACTIVE SHIFTS"
	var foot_col := Palette.DIM
	if not p.alive:
		foot_text = "SPECTATING"
		foot_col = Palette.WARN
	elif own_swaps > 0:
		foot_text = "%d ACTIVE SHIFT%s" % [own_swaps, "" if own_swaps == 1 else "S"]
		foot_col = Palette.SWAP
	UIKit.text(self, Vector2(hx + 12, r.position.y + 321), foot_text, 8, foot_col)
	UIKit.text_right(self, r.end.x - 12, r.position.y + 321, "SHIFT READY" if SwapManager.is_shift_ready() else "SHIFT %.1fs" % SwapManager.shift_remaining(), 8, Palette.MUTED)


func _draw_hover_panel() -> void:
	var c := _inspect_target()
	if c == null:
		return
	var r := _hover_rect()
	var team_col := Palette.team_color(c.team)
	UIKit.panel(self, r, _panel_bg(r), Color(team_col, 0.45), 7)
	draw_rect(Rect2(r.position.x, r.position.y + 8, 3, r.size.y - 16), Color(team_col, 0.85))

	UIKit.text(self, Vector2(r.position.x + 12, r.position.y + 24), c.display_name, 15, team_col)
	var name_w := UIKit.text_width(c.display_name, 15)
	UIKit.text(self, Vector2(r.position.x + 18 + name_w, r.position.y + 24), "· " + c.archetype.to_upper(), 10, Palette.MUTED)
	var role := "YOU" if c.is_player else ("ALLY" if c.team == Character.TEAM_PLAYER else "ENEMY")
	UIKit.text_right(self, r.end.x - 12, r.position.y + 24, role, 9, Color(team_col, 0.9))

	var hp_bar := Rect2(r.position.x + 12, r.position.y + 32, r.size.x - 24, 12)
	UIKit.bar(self, hp_bar, c.health_pct(), Color(team_col, 0.9))
	UIKit.text_center(self, hp_bar.get_center().x, hp_bar.position.y + 9.5, "%d / %d HP" % [int(ceil(c.health)), int(c.max_health())], 8, Palette.WHITE)

	var hx := r.position.x
	UIKit.text(self, Vector2(hx + 12, r.position.y + 66), "ATTRIBUTE", 8, Palette.DIM)
	UIKit.text_right(self, hx + 248, r.position.y + 66, "NOW", 8, Palette.DIM)
	UIKit.text_right(self, hx + 304, r.position.y + 66, "BASE", 8, Palette.DIM)
	UIKit.text(self, Vector2(hx + 318, r.position.y + 66), "SOURCE / STATUS", 8, Palette.DIM)

	var row_y := r.position.y + 74.0
	for attr_v in GameConfig.ATTRS:
		var attr := str(attr_v)
		var rec := SwapManager.get_swap_for(c, attr)
		var now_val: Variant = c.get_stat(attr)
		var base_val: Variant = c.stats.base_value(attr)
		var quality := GameConfig.attr_quality(attr, now_val, base_val)
		var now_text := GameConfig.attr_text(attr, now_val)
		var base_text := GameConfig.attr_text(attr, base_val)
		var now_col := Palette.TEXT
		if not rec.is_empty():
			now_col = Palette.SWAP
		elif quality > 0:
			now_col = Palette.BUFF
		elif quality < 0:
			now_col = Palette.DEBUFF

		UIKit.text(self, Vector2(hx + 12, row_y + 13), str(GameConfig.ATTR_LABELS[attr]), 9, Color(Palette.attr_color(attr), 0.95))
		UIKit.text_right(self, hx + 248, row_y + 13, now_text, 9, now_col)
		UIKit.text_right(self, hx + 304, row_y + 13, base_text, 8, Palette.MUTED)

		if not rec.is_empty():
			var other: Character = rec["b"] if rec["a"] == c else rec["a"]
			var src := "← %s %.1fs" % [_short_name(other), SwapManager.remaining_seconds(rec)]
			UIKit.text(self, Vector2(hx + 318, row_y + 13), src, 8, Palette.SWAP)
			UIKit.bar(self, Rect2(hx + 318, row_y + 16, 110, 2), SwapManager.remaining_fraction(rec), Palette.SWAP, Color(0.1, 0.06, 0.16, 0.8))
		elif attr == "special" or attr == "basic":
			var origin := ""
			if attr == "special" and now_val is Ability:
				origin = (now_val as Ability).origin_archetype.to_upper()
			elif attr == "basic" and now_val is BasicAttack:
				origin = (now_val as BasicAttack).origin_archetype.to_upper()
			UIKit.text(self, Vector2(hx + 318, row_y + 13), "FROM " + origin, 8, Palette.MUTED)
		elif quality > 0:
			UIKit.text(self, Vector2(hx + 318, row_y + 13), "IMPROVED", 8, Palette.BUFF)
		elif quality < 0:
			UIKit.text(self, Vector2(hx + 318, row_y + 13), "REDUCED", 8, Palette.DEBUFF)
		else:
			UIKit.text(self, Vector2(hx + 318, row_y + 13), "—", 8, Palette.DIM)

		row_y += 18.0

	var active := SwapManager.get_swaps_for(c).size()
	if active > 0:
		UIKit.text(self, Vector2(hx + 12, r.end.y - 10), "%d ACTIVE SHIFT%s ON THIS UNIT" % [active, "" if active == 1 else "S"], 8, Palette.SWAP)


func _short_name(c: Character) -> String:
	if c == null:
		return "—"
	var n := c.display_name
	if n.length() > 10:
		n = n.substr(0, 10)
	return n


func _draw_team_panel() -> void:
	var r := _team_rect()
	UIKit.panel(self, r, _panel_bg(r), Palette.PANEL_EDGE, 7)
	draw_line(Vector2(r.position.x + r.size.x * 0.5, r.position.y + 10), Vector2(r.position.x + r.size.x * 0.5, r.end.y - 10), Color(Palette.PANEL_EDGE, 0.8), 1.0)

	var blue_alive := combat.alive_on_team(Character.TEAM_PLAYER)
	var red_alive := combat.alive_on_team(Character.TEAM_ENEMY)
	UIKit.text(self, Vector2(r.position.x + 12, r.position.y + 19), "BLUE TEAM · %d ALIVE" % blue_alive, 8, Palette.PLAYER)
	UIKit.text(self, Vector2(r.position.x + 228, r.position.y + 19), "RED TEAM · %d ALIVE" % red_alive, 8, Palette.ENEMY)

	_draw_team_chips(combat.team_array(Character.TEAM_PLAYER), r.position.x + 12, r.position.y + 28)
	_draw_team_chips(combat.team_array(Character.TEAM_ENEMY), r.position.x + 228, r.position.y + 28)


func _draw_team_chips(team: Array, x: float, y: float) -> void:
	for i in range(team.size()):
		var c: Character = team[i]
		var chip := Rect2(x + float(i) * 34.0, y, 29, 20)
		var col := Palette.team_color(c.team)
		var alive := is_instance_valid(c) and c.alive
		UIKit.panel(self, chip, Color(Palette.team_dark(c.team), 0.9 if alive else 0.4), Color(col, 0.7 if alive else 0.2), 3)
		var abbr := c.archetype.substr(0, 3).to_upper()
		UIKit.text_center(self, chip.get_center().x, chip.position.y + 13.5, abbr, 7, Color(col, 0.95 if alive else 0.3))
		if not alive:
			draw_line(chip.position + Vector2(4, 4), chip.end - Vector2(4, 4), Color(Palette.BAD, 0.7), 1.0)
			draw_line(Vector2(chip.position.x + 4, chip.end.y - 4), Vector2(chip.end.x - 4, chip.position.y + 4), Color(Palette.BAD, 0.7), 1.0)
		if c.is_player:
			draw_circle(chip.position + Vector2(chip.size.x - 3, 3), 1.6, Palette.WHITE)


func _draw_swaps_panel() -> void:
	var r := _swaps_rect()
	UIKit.panel(self, r, _panel_bg(r), Color(Palette.SWAP, 0.25), 7)
	UIKit.text(self, Vector2(r.position.x + 12, r.position.y + 18), "ACTIVE SHIFTS", 9, Palette.SWAP)
	UIKit.text_right(self, r.end.x - 12, r.position.y + 18, "%d LIVE" % SwapManager.swaps.size(), 8, Palette.MUTED)

	if SwapManager.swaps.is_empty():
		UIKit.text_center(self, r.get_center().x, r.position.y + 43, "NO ACTIVE SHIFTS", 8, Palette.DIM)
		return

	var list := SwapManager.swaps.duplicate()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["expires_ms"]) < int(b["expires_ms"])
	)

	var row_y := r.position.y + 28.0
	var shown := mini(list.size(), 6)
	for i in range(shown):
		var rec: Dictionary = list[i]
		var attr := str(rec["attr"])
		var col := Palette.attr_color(attr)
		var a: Character = rec["a"]
		var b: Character = rec["b"]
		UIKit.text(self, Vector2(r.position.x + 12, row_y + 12), str(GameConfig.ATTR_LABELS[attr]), 8, col)
		UIKit.text_right(self, r.end.x - 12, row_y + 12, "%.1fs" % SwapManager.remaining_seconds(rec), 8, col)

		var a_name := _short_name(a)
		var b_name := _short_name(b)
		UIKit.text(self, Vector2(r.position.x + 12, row_y + 23), "%s ⇄ %s" % [a_name, b_name], 8, Palette.TEXT)
		var owner := str(rec["owner"])
		if owner == "counter":
			UIKit.text_right(self, r.end.x - 12, row_y + 23, "COUNTER", 7, Palette.ENEMY)
		elif owner == "player":
			UIKit.text_right(self, r.end.x - 12, row_y + 23, "YOU", 7, Palette.PLAYER)
		UIKit.bar(self, Rect2(r.position.x + 12, row_y + 26, r.size.x - 24, 2), SwapManager.remaining_fraction(rec), col, Color(0.1, 0.07, 0.15, 0.8))
		row_y += 30.0

	if list.size() > 6:
		UIKit.text_center(self, r.get_center().x, row_y + 10, "+%d MORE" % (list.size() - 6), 8, Palette.MUTED)


func _draw_footer() -> void:
	var r := _footer_rect()
	var p: Character = combat.player
	var ability := p.current_ability()
	var col := ability.color if ability != null else Palette.SWAP
	UIKit.panel(self, r, _panel_bg(r), Color(Palette.PANEL_EDGE, 0.8), 7)
	UIKit.text(self, Vector2(r.position.x + 12, r.position.y + 16), "EQUIPPED SPECIAL", 8, Palette.DIM)
	UIKit.text(self, Vector2(r.position.x + 12, r.position.y + 32), ability.display_name if ability != null else "—", 11, col)
	var origin_text := ""
	if ability != null and ability.origin_archetype != p.archetype:
		origin_text = "FROM " + ability.origin_archetype.to_upper()
	UIKit.text_right(self, r.end.x - 12, r.position.y + 16, origin_text, 8, Palette.SWAP if origin_text != "" else Palette.DIM)
	var cd_pct := 1.0
	var cd_text := "READY"
	if p.special_cd > 0.001:
		cd_pct = 1.0 - clampf(p.special_cd / maxf(0.01, float(p.stats.current["special_cooldown"])), 0.0, 1.0)
		cd_text = "%.1fs" % p.special_cd
	UIKit.bar(self, Rect2(r.position.x + 12, r.position.y + 38, r.size.x - 24, 5), cd_pct, col)
	UIKit.text_right(self, r.end.x - 12, r.position.y + 54, cd_text, 8, Palette.BUFF if cd_text == "READY" else Palette.MUTED)

	var desc := ""
	if ability != null:
		desc = ability.description
		if desc.length() > 48:
			desc = desc.substr(0, 47) + "…"
	UIKit.text(self, Vector2(r.position.x + 12, r.position.y + 68), desc, 8, Palette.MUTED)
	UIKit.text(self, Vector2(r.position.x + 12, r.position.y + 85), "WASD MOVE · LMB ATTACK · RMB SPECIAL", 8, Palette.TEXT)
	UIKit.text(self, Vector2(r.position.x + 12, r.position.y + 97), "SHIFT SWAP · ESC CANCEL · R RESTART · F11 FULLSCREEN", 8, Palette.MUTED)


func _draw_shift_pill() -> void:
	var r := _shift_rect()
	var text := ""
	var col := Palette.SWAP
	var border := Color(Palette.SWAP, 0.35)
	var pulse := 0.6 + 0.4 * sin(_time * 4.0)

	if combat.state != CombatManager.State.PLAYING:
		return
	if SwapManager.is_selecting():
		text = "SELECT TARGETS · ESC CANCEL"
		col = Palette.WARN
		border = Color(Palette.WARN, 0.6)
	elif SwapManager.mode == SwapManager.Mode.ATTRIBUTE:
		text = "CHOOSE ATTRIBUTE · ESC CANCEL"
		col = Palette.SWAP
		border = Color(Palette.SWAP, 0.7)
	elif not combat.player.alive:
		text = "SPECTATING"
		col = Palette.MUTED
		border = Palette.PANEL_EDGE
	elif SwapManager.is_shift_ready():
		text = "SHIFT READY — PRESS SHIFT"
		col = Color(Palette.PLAYER, pulse)
		border = Color(Palette.PLAYER, 0.35 + 0.35 * pulse)
	else:
		text = "SHIFT RECHARGING  %.1fs" % SwapManager.shift_remaining()
		col = Palette.MUTED

	UIKit.panel(self, r, _panel_bg(r), border, 17)
	UIKit.text_center(self, r.get_center().x, r.position.y + 22, text, 9, col)
	if SwapManager.mode == SwapManager.Mode.IDLE and not SwapManager.is_shift_ready() and combat.player.alive:
		UIKit.bar(self, Rect2(r.position.x + 12, r.end.y - 6, r.size.x - 24, 3), SwapManager.shift_progress(), Palette.SWAP, Color(0.08, 0.06, 0.12, 0.7))


func _draw_time_dilation() -> void:
	if not TimeManager.is_slowed():
		return
	if SwapManager.is_targeting():
		return
	var cx := size.x * 0.5
	var t := Engine.time_scale
	var pulse := 0.6 + 0.4 * sin(_time * 9.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.SWAP, 0.022))
	draw_rect(Rect2(4, 4, size.x - 8, size.y - 8), Color(Palette.SWAP, 0.22 * pulse), false, 2.0)
	var text := "TIME DILATION  ×%.2f" % t
	var w := UIKit.text_width(text, 10) + 34.0
	UIKit.panel(self, Rect2(cx - w * 0.5, 80, w, 24), Color(0.02, 0.025, 0.05, 0.85), Color(Palette.SWAP, 0.75), 12)
	UIKit.text_center(self, cx, 96, text, 10, Color(Palette.SWAP, 0.95))
	UIKit.text_center(self, cx, 116, "WORLD SPEED REDUCED", 7, Color(Palette.MUTED, 0.9))


func _draw_swap_mode() -> void:
	if not SwapManager.is_selecting():
		if SwapManager.mode == SwapManager.Mode.ATTRIBUTE:
			_draw_border_glow(Color(Palette.SWAP, 0.25))
		return
	var a := 0.2 + 0.12 * sin(_time * 5.0)
	_draw_border_glow(Color(Palette.SWAP, a + 0.18))
	var msg := ""
	if SwapManager.mode == SwapManager.Mode.SELECT_A:
		msg = "SHIFT PROTOCOL — CLICK FIRST TARGET"
	elif SwapManager.mode == SwapManager.Mode.SELECT_B:
		msg = "TARGET LOCKED: %s — CLICK SECOND TARGET" % _short_name(SwapManager.selected_a)
	UIKit.text_center(self, size.x * 0.5, 100, msg, 10, Color(Palette.SWAP, 0.95))
	UIKit.text_center(self, size.x * 0.5, 116, "TIME DILATION ×%.2f · CLICK ANY TWO LIVING UNITS · ESC CANCEL" % Engine.time_scale, 8, Palette.MUTED)


func _draw_border_glow(col: Color) -> void:
	draw_rect(Rect2(5, 5, size.x - 10, size.y - 10), col, false, 2.0)
	draw_rect(Rect2(9, 9, size.x - 18, size.y - 18), Color(col, col.a * 0.35), false, 1.0)


func _draw_banner() -> void:
	if banner_time <= 0.0 or banner_text == "":
		return
	var age := banner_total - banner_time
	var alpha := minf(1.0, age * 7.0) * minf(1.0, banner_time * 2.5)
	var y := 146.0 - minf(age, 0.25) * 16.0
	var w := UIKit.text_width(banner_text, 17) + 44.0
	var cx := size.x * 0.5
	var rect := Rect2(cx - w * 0.5, y - 22.0, w, 32.0)
	UIKit.panel(self, rect, Color(0.02, 0.03, 0.05, 0.82 * alpha), Color(banner_color, 0.7 * alpha), 5)
	UIKit.text_center(self, cx, y, banner_text, 17, Color(banner_color, alpha))


func _draw_match_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.03, 0.72))
	var cx := size.x * 0.5
	var panel_rect := Rect2(cx - 250.0, size.y * 0.5 - 134.0, 500, 268)
	var victory := combat.state == CombatManager.State.VICTORY
	var col := Palette.GOOD if victory else Palette.BAD
	UIKit.panel(self, panel_rect, Color(0.02, 0.035, 0.055, 0.97), Color(col, 0.6), 10, 2)
	draw_line(Vector2(panel_rect.position.x + 30, panel_rect.position.y + 8), Vector2(panel_rect.end.x - 30, panel_rect.position.y + 8), Color(col, 0.8), 2.0)

	var top := panel_rect.position.y
	UIKit.text_center(self, cx, top + 76.0, "VICTORY" if victory else "DEFEAT", 52, col)
	UIKit.text_center(self, cx, top + 104.0, "ALL HOSTILES DOWN" if victory else "BLUE TEAM WIPED", 11, Palette.MUTED)

	UIKit.text_center(self, cx, top + 146.0, "SHIFTS  %d      COUNTER-SHIFTS  %d      TAKEDOWNS  %d" % [combat.player_shift_count, combat.enemy_shift_count, combat.kill_count], 10, Palette.TEXT)
	UIKit.text_center(self, cx, top + 168.0, "SHIFT WAR COMPLETE", 8, Palette.DIM)

	var pulse := 0.55 + 0.45 * sin(_time * 4.0)
	UIKit.text_center(self, cx, top + 232.0, "PRESS R TO RESTART", 13, Color(Palette.PLAYER, pulse))
	UIKit.text_center(self, cx, top + 250.0, "OR CLOSE THE WINDOW — THANKS FOR TESTING SHIFT", 8, Palette.DIM)
