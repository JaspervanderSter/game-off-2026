class_name SwapPicker
extends Control
## Full-screen attribute exchange interface shown after two targets are picked.

signal confirmed(attr: String)
signal cancelled

const CARD_SIZE := Vector2(800, 544)
const ROW_W := 768.0
const ROW_H := 30.0
const ROW_STEP := 32.0

var char_a: Character = null
var char_b: Character = null
var options: Array = []
var rows: Array = []
var selected_attr: String = ""

var confirm_btn: Button
var cancel_btn: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_buttons()
	resized.connect(_on_resized)
	_layout_controls()


func _card_rect() -> Rect2:
	return Rect2((size.x - CARD_SIZE.x) * 0.5, (size.y - CARD_SIZE.y) * 0.5, CARD_SIZE.x, CARD_SIZE.y)


func _row_x() -> float:
	return _card_rect().position.x + 16.0


func _row_start_y() -> float:
	return _card_rect().position.y + 154.0


func _layout_controls() -> void:
	var card := _card_rect()
	if is_instance_valid(cancel_btn):
		cancel_btn.position = Vector2(card.position.x + 16.0, card.position.y + 422.0)
	if is_instance_valid(confirm_btn):
		confirm_btn.position = Vector2(card.end.x - 236.0, card.position.y + 422.0)
	for i in range(rows.size()):
		if is_instance_valid(rows[i]):
			rows[i].position = Vector2(_row_x(), _row_start_y() + float(i) * ROW_STEP)
			rows[i].size = Vector2(ROW_W, ROW_H)


func _on_resized() -> void:
	_layout_controls()
	queue_redraw()


func _build_buttons() -> void:
	cancel_btn = Button.new()
	cancel_btn.text = "CANCEL  (ESC)"
	cancel_btn.size = Vector2(160, 36)
	cancel_btn.focus_mode = Control.FOCUS_NONE
	_apply_button_style(cancel_btn, Palette.MUTED)
	cancel_btn.pressed.connect(_on_cancel)
	add_child(cancel_btn)

	confirm_btn = Button.new()
	confirm_btn.text = "CONFIRM SHIFT"
	confirm_btn.size = Vector2(220, 36)
	confirm_btn.focus_mode = Control.FOCUS_NONE
	_apply_button_style(confirm_btn, Palette.SWAP)
	confirm_btn.disabled = true
	confirm_btn.pressed.connect(_on_confirm)
	add_child(confirm_btn)


func _apply_button_style(b: Button, accent: Color) -> void:
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", Palette.TEXT)
	b.add_theme_color_override("font_hover_color", Palette.WHITE)
	b.add_theme_color_override("font_pressed_color", Palette.WHITE)
	b.add_theme_color_override("font_disabled_color", Palette.DIM)
	b.add_theme_stylebox_override("normal", UIKit.stylebox(Color(0.05, 0.09, 0.14, 0.96), Color(accent, 0.5), 5))
	b.add_theme_stylebox_override("hover", UIKit.stylebox(Color(0.08, 0.14, 0.21, 0.98), Color(accent, 0.9), 5))
	b.add_theme_stylebox_override("pressed", UIKit.stylebox(Color(accent, 0.28), Color(accent, 1.0), 5))
	b.add_theme_stylebox_override("disabled", UIKit.stylebox(Color(0.03, 0.045, 0.065, 0.9), Color(0.25, 0.3, 0.36, 0.25), 5))


func open(a: Character, b: Character, opts: Array) -> void:
	char_a = a
	char_b = b
	options = opts
	selected_attr = ""
	visible = true
	_rebuild_rows()
	_layout_controls()
	_update_confirm()
	queue_redraw()


func refresh(a: Character, b: Character, opts: Array) -> void:
	if not visible:
		return
	char_a = a
	char_b = b
	options = opts
	if selected_attr != "":
		var still := false
		for o in options:
			if str(o["attr"]) == selected_attr and bool(o["ok"]):
				still = true
				break
		if not still:
			selected_attr = ""
	_rebuild_rows()
	_layout_controls()
	_update_confirm()
	queue_redraw()


func close() -> void:
	visible = false
	selected_attr = ""
	confirm_btn.disabled = true


func _rebuild_rows() -> void:
	for r in rows:
		if is_instance_valid(r):
			r.queue_free()
	rows.clear()
	for i in range(options.size()):
		var opt: Dictionary = options[i]
		var row := SwapRow.new()
		row.setup(opt)
		row.position = Vector2(_row_x(), _row_start_y() + float(i) * ROW_STEP)
		row.size = Vector2(ROW_W, ROW_H)
		row.set_selected(str(opt["attr"]) == selected_attr)
		row.picked.connect(_on_row_picked)
		add_child(row)
		rows.append(row)
	_layout_controls()


func _update_confirm() -> void:
	if confirm_btn == null:
		return
	confirm_btn.disabled = selected_attr == ""
	if selected_attr == "":
		confirm_btn.text = "CONFIRM SHIFT"
	else:
		confirm_btn.text = "CONFIRM — " + str(GameConfig.ATTR_LABELS.get(selected_attr, selected_attr.to_upper()))


func _on_row_picked(attr: String) -> void:
	selected_attr = attr
	for r in rows:
		if is_instance_valid(r):
			r.set_selected(r.attr == attr)
	_update_confirm()
	queue_redraw()


func _on_confirm() -> void:
	if selected_attr == "":
		return
	confirmed.emit(selected_attr)


func _on_cancel() -> void:
	cancelled.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		cancelled.emit()


func _draw() -> void:
	var card := _card_rect()
	var row_x := _row_x()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.035, 0.58))
	UIKit.panel(self, card, Color(0.022, 0.038, 0.06, 0.98), Color(Palette.SWAP, 0.55), 10, 2)
	draw_rect(Rect2(card.position.x, card.position.y + 8, 3, card.size.y - 16), Color(Palette.SWAP, 0.85))

	UIKit.text(self, Vector2(card.position.x + 24, card.position.y + 36), "SHIFT PROTOCOL", 18, Palette.SWAP)
	UIKit.text_right(self, card.end.x - 24, card.position.y + 34, "COMBAT PAUSED · EXCHANGE ONE ATTRIBUTE", 8, Palette.MUTED)
	draw_line(Vector2(card.position.x + 24, card.position.y + 44), Vector2(card.end.x - 24, card.position.y + 44), Color(Palette.PANEL_EDGE, 0.7), 1.0)

	_draw_side(Rect2(card.position.x + 16, card.position.y + 52, 378, 84), char_a, "TARGET A")
	_draw_side(Rect2(card.position.x + 406, card.position.y + 52, 378, 84), char_b, "TARGET B")

	UIKit.text(self, Vector2(row_x + 14, card.position.y + 148), "ATTRIBUTE", 8, Palette.DIM)
	UIKit.text_center(self, row_x + 362, card.position.y + 148, "A · NOW → NEW", 8, Palette.DIM)
	UIKit.text_center(self, row_x + 642, card.position.y + 148, "B · NOW → NEW", 8, Palette.DIM)
	UIKit.text_right(self, row_x + ROW_W - 12, card.position.y + 148, "STATUS", 8, Palette.DIM)

	var sel_text := "SELECT AN ATTRIBUTE"
	var sel_col := Palette.DIM
	if selected_attr != "":
		sel_text = "SELECTED: " + str(GameConfig.ATTR_LABELS.get(selected_attr, selected_attr.to_upper()))
		sel_col = Palette.SWAP
	UIKit.text_center(self, card.get_center().x, card.position.y + 446, sel_text, 10, sel_col)

	UIKit.text_center(self, card.get_center().x, card.position.y + 486, "SWAPS LAST %.0f SECONDS AND RESTORE AUTOMATICALLY." % GameConfig.swap_duration, 8, Palette.MUTED)
	UIKit.text_center(self, card.get_center().x, card.position.y + 501, "COMBAT PAUSED · CONFLICTING ATTRIBUTES ARE LOCKED.", 8, Palette.DIM)


func _draw_side(rect: Rect2, c: Character, tag: String) -> void:
	if c == null or not is_instance_valid(c):
		return
	var team_col := Palette.team_color(c.team)
	UIKit.panel(self, rect, Color(0.032, 0.055, 0.085, 0.96), Color(team_col, 0.5), 6)
	UIKit.text(self, Vector2(rect.position.x + 12, rect.position.y + 16), "%s · %s TEAM" % [tag, "BLUE" if c.team == Character.TEAM_PLAYER else "RED"], 8, team_col)
	UIKit.text(self, Vector2(rect.position.x + 12, rect.position.y + 35), c.display_name, 14, Palette.TEXT)
	UIKit.text(self, Vector2(rect.position.x + 12, rect.position.y + 50), c.archetype.to_upper(), 8, Palette.MUTED)

	var ability := c.current_ability()
	if ability != null:
		UIKit.text_right(self, rect.end.x - 12, rect.position.y + 16, "SPEC " + ability.short_name, 8, ability.color)

	var hp_bar := Rect2(rect.position.x + 12, rect.position.y + 58, rect.size.x - 24, 6)
	UIKit.bar(self, hp_bar, c.health_pct(), team_col)
	UIKit.text(self, Vector2(rect.position.x + 12, rect.position.y + 78), "HP %d / %d" % [int(ceil(c.health)), int(c.max_health())], 8, Palette.MUTED)
	UIKit.text_right(self, rect.end.x - 12, rect.position.y + 78, "SPD %.1f   STR %.1f   WGT %.1f" % [
		float(c.stats.current["speed"]), float(c.stats.current["strength"]), float(c.stats.current["weight"])
	], 8, Palette.DIM)
