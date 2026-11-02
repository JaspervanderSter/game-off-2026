class_name GameUI
extends CanvasLayer

var combat: CombatManager
var main: Node2D
var hud: GameHUD
var picker: SwapPicker
var root: Control


func setup(combat_ref: CombatManager, main_ref: Node2D) -> void:
	combat = combat_ref
	main = main_ref
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	root = Control.new()
	root.name = "UIRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	hud = GameHUD.new()
	hud.combat = combat
	root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	picker = SwapPicker.new()
	root.add_child(picker)
	picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picker.visible = false

	picker.confirmed.connect(_on_picker_confirmed)
	picker.cancelled.connect(_on_picker_cancelled)
	SwapManager.mode_changed.connect(_on_swap_mode_changed)
	SwapManager.selection_changed.connect(_on_selection_changed)
	SwapManager.swap_started.connect(_on_swap_started)
	SwapManager.swap_ended.connect(_on_swap_ended)
	SwapManager.notice.connect(_on_notice)


func set_hovered(c: Character) -> void:
	if hud != null:
		hud.hovered = c


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			SwapManager.cancel_selection()
		KEY_R:
			if combat != null:
				combat.restart()
		KEY_F11:
			var win := get_window()
			if win.mode == Window.MODE_FULLSCREEN:
				win.mode = Window.MODE_WINDOWED
			else:
				win.mode = Window.MODE_FULLSCREEN
		KEY_SHIFT:
			if SwapManager.mode == SwapManager.Mode.ATTRIBUTE:
				SwapManager.cancel_selection()


func is_ui_at_screen(pos: Vector2) -> bool:
	if picker != null and picker.visible:
		return true
	if SwapManager.is_selecting():
		return false
	if hud != null:
		return hud.contains_ui_point(pos)
	return false


func _on_swap_mode_changed(_mode: int) -> void:
	if SwapManager.mode == SwapManager.Mode.ATTRIBUTE:
		_open_picker()
	else:
		picker.close()
	if hud != null:
		hud.queue_redraw()


func _on_selection_changed() -> void:
	if SwapManager.mode == SwapManager.Mode.ATTRIBUTE:
		_refresh_picker()
	if hud != null:
		hud.queue_redraw()


func _open_picker() -> void:
	var a := SwapManager.selected_a
	var b := SwapManager.selected_b
	if a == null or b == null:
		picker.close()
		return
	picker.open(a, b, SwapManager.get_attr_options())


func _refresh_picker() -> void:
	var a := SwapManager.selected_a
	var b := SwapManager.selected_b
	if a == null or b == null:
		picker.close()
		return
	picker.refresh(a, b, SwapManager.get_attr_options())


func _on_picker_confirmed(attr: String) -> void:
	if not SwapManager.confirm_swap(attr):
		_refresh_picker()


func _on_picker_cancelled() -> void:
	SwapManager.cancel_selection()


func _on_swap_started(rec: Dictionary) -> void:
	var attr := str(rec["attr"])
	var label := str(GameConfig.ATTR_LABELS.get(attr, attr.to_upper()))
	var owner := str(rec.get("owner", ""))
	var a: Character = rec["a"]
	var b: Character = rec["b"]
	if hud == null:
		return
	if owner == "counter":
		var source_name := a.display_name if is_instance_valid(a) else "ENEMY"
		hud.show_banner("%s COUNTER-SHIFT · %s" % [source_name, label], Palette.ENEMY, 2.5)
		hud.flash(Palette.ENEMY, 0.35)
	else:
		var an := a.display_name if is_instance_valid(a) else "?"
		var bn := b.display_name if is_instance_valid(b) else "?"
		hud.show_banner("%s ⇄ %s · %s" % [an, bn, label], Palette.attr_color(attr), 2.2)
		hud.flash(Palette.attr_color(attr), 0.35)


func _on_swap_ended(rec: Dictionary) -> void:
	if hud == null:
		return
	if str(rec.get("owner", "")) != "player":
		return
	var a: Character = rec["a"]
	var b: Character = rec["b"]
	if is_instance_valid(a) and is_instance_valid(b) and a.alive and b.alive:
		var attr := str(rec["attr"])
		var label := str(GameConfig.ATTR_LABELS.get(attr, attr.to_upper()))
		hud.show_banner("SHIFT ENDED · %s RESTORED" % label, Palette.MUTED, 1.5)


func _on_notice(text: String, color: Color) -> void:
	if hud != null:
		hud.show_banner(text, color, 2.0)
