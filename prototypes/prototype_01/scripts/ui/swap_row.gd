class_name SwapRow
extends Control
## A clickable attribute row inside the SHIFT picker.

signal picked(attr: String)

var attr: String = ""
var label_text: String = ""
var a_now: String = ""
var a_new: String = ""
var b_now: String = ""
var b_new: String = ""
var enabled: bool = true
var reason: String = ""
var selected: bool = false
var accent: Color = Color.WHITE
var _hover: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))


func _on_hover(h: bool) -> void:
	_hover = h
	queue_redraw()


func setup(data: Dictionary) -> void:
	attr = str(data.get("attr", ""))
	label_text = str(GameConfig.ATTR_LABELS.get(attr, attr.to_upper()))
	a_now = GameConfig.attr_text(attr, data.get("a"))
	b_now = GameConfig.attr_text(attr, data.get("b"))
	a_new = b_now
	b_new = a_now
	enabled = bool(data.get("ok", true))
	reason = str(data.get("reason", ""))
	accent = Palette.attr_color(attr)
	queue_redraw()


func set_selected(v: bool) -> void:
	selected = v
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and enabled:
		picked.emit(attr)
		accept_event()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var bg := Color(0.035, 0.06, 0.09, 0.35)
	if selected:
		bg = Color(Palette.SWAP, 0.17)
	elif _hover and enabled:
		bg = Color(0.08, 0.14, 0.21, 0.62)
	elif not enabled:
		bg = Color(0.02, 0.03, 0.05, 0.25)
	draw_rect(rect, bg)
	if selected:
		draw_rect(rect, Color(Palette.SWAP, 0.95), false, 1.5)
	elif _hover and enabled:
		draw_rect(rect, Color(Palette.EDGE_BRIGHT, 0.45), false, 1.0)
	else:
		draw_rect(rect, Color(Palette.PANEL_EDGE, 0.32), false, 1.0)
	draw_rect(Rect2(0, 3, 2.5, size.y - 6), Color(accent, 0.9 if enabled else 0.25))

	var mid := size.y * 0.5 + 4.0
	UIKit.text(self, Vector2(14, mid), label_text, 11, Color(accent, 1.0 if enabled else 0.35))

	UIKit.text(self, Vector2(236, mid), "A", 8, Palette.DIM)
	UIKit.text_right(self, 350, mid, a_now, 10, Color(Palette.MUTED, 1.0 if enabled else 0.35))
	UIKit.text(self, Vector2(358, mid), "→", 10, Color(Palette.DIM, 1.0 if enabled else 0.25))
	UIKit.text(self, Vector2(374, mid), a_new, 10, Color(accent, 1.0 if enabled else 0.35))

	UIKit.text(self, Vector2(524, mid), "B", 8, Palette.DIM)
	UIKit.text_right(self, 638, mid, b_now, 10, Color(Palette.MUTED, 1.0 if enabled else 0.35))
	UIKit.text(self, Vector2(646, mid), "→", 10, Color(Palette.DIM, 1.0 if enabled else 0.25))
	UIKit.text(self, Vector2(662, mid), b_new, 10, Color(accent, 1.0 if enabled else 0.35))

	if not enabled and reason != "":
		UIKit.text_right(self, size.x - 12, mid, reason, 8, Palette.BAD)
	elif selected:
		UIKit.text_right(self, size.x - 12, mid, "SELECTED", 8, Palette.SWAP)
