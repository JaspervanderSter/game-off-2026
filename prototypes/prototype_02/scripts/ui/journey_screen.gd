extends Node2D
## Procedural main-menu diorama; the map has its own scene and renderer.
var game
var age := 0.0
var buttons: Array[Button] = []
const GOLD := Color(0.9, 0.72, 0.38)
const INK := Color(0.27, 0.18, 0.15)
const PAPER := Color(0.73, 0.65, 0.47)

func _ready() -> void:
	_button(Rect2(546, 443, 188, 100), 0)
	if not OS.has_feature("web"):
		_button(Rect2(1190, 628, 58, 58), -2)

func _button(rect: Rect2, index: int) -> void:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.flat = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	button.pressed.connect(_activate.bind(index))
	add_child(button)
	buttons.append(button)

func _activate(index: int) -> void:
	if index == -2:
		get_tree().quit()
	else:
		game.show_map()

func focus_first() -> void:
	buttons[0].grab_focus()

func _process(dt: float) -> void:
	if not visible:
		return
	age += dt
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.16, 0.12, 0.1))
	# Wooden frame and inset parchment, using the board's existing palette.
	for inset in [20, 28]:
		draw_rect(Rect2(inset, inset, 1280 - inset * 2, 720 - inset * 2), Color(0.4, 0.28, 0.18), false, 3)
	draw_rect(Rect2(54, 118, 1172, 492), PAPER)
	draw_rect(Rect2(62, 126, 1156, 476), Color(0.8, 0.73, 0.57), false, 2)
	for i in 70:
		var p := Vector2(80 + fmod(i * 179.7, 1120), 142 + fmod(i * 89.3, 438))
		Shapes.circle(self, p, 1 + i % 3, Color(0.35, 0.27, 0.17, 0.08))
	_draw_menu()

func _draw_menu() -> void:
	# A small duel diorama, entirely drawn with the game's vector vocabulary.
	for y in 4:
		for x in 8:
			var p := Vector2(384 + x * 64, 205 + y * 48)
			draw_rect(Rect2(p, Vector2(64, 48)), Color(0.83, 0.76, 0.6) if (x + y) % 2 == 0 else Color(0.67, 0.58, 0.42))
	Shapes.circle(self, Vector2(486, 314), 66, Color(0.25, 0.55, 1, 0.15))
	Shapes.circle(self, Vector2(794, 314), 66, Color(1, 0.3, 0.3, 0.15))
	Icons.wizard_hat(self, Vector2(486, 305 + sin(age * 2) * 5), 55, 0)
	Icons.difficulty_hat(self, 2, Vector2(794, 305 + sin(age * 2 + 1) * 5), 55, age)
	Icons.swords(self, Vector2(640, 314), 38, INK)
	for i in 12:
		var p := Vector2(640, 314) + Vector2.from_angle(age * 0.2 + i * TAU / 12) * Vector2(470, 174)
		Icons.star(self, p, 3 + sin(age * 2 + i), Color(0.95, 0.8, 0.4, 0.7))
	var glow := _hot(0)
	_panel(Rect2(546, 443, 188, 100), glow)
	Icons.island_medallion(self, Vector2(610, 493), 32, age, glow)
	Icons.arrow_right(self, Vector2(681 + sin(age * 3) * 3, 493), 22, GOLD)
	if buttons.size() > 1:
		_ring(Vector2(1219, 657), 25, GOLD if _hot(1) else Color(0.55, 0.43, 0.3))
		Shapes.arc(self, Vector2(1219, 657), 12, -1.1, PI + 1.1, 24, GOLD, 3, true)
		Shapes.line(self, Vector2(1219, 639), Vector2(1219, 655), GOLD, 3)

func _hot(index: int) -> bool:
	return buttons[index].is_hovered() or buttons[index].has_focus()

func _ring(p: Vector2, radius: float, color: Color) -> void:
	Shapes.arc(self, p, radius, 0, TAU, 48, color, 2, true)

func _panel(rect: Rect2, hot: bool) -> void:
	draw_rect(rect, Color(0.28, 0.17, 0.33) if hot else Color(0.2, 0.14, 0.24))
	draw_rect(rect.grow(-4), GOLD if hot else Color(0.57, 0.43, 0.27), false, 2)

