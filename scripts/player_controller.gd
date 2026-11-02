class_name PlayerController
extends Node

var character: Character
var combat: CombatManager
var ui: Node


func setup(c: Character, combat_ref: CombatManager, ui_ref: Node) -> void:
	character = c
	combat = combat_ref
	ui = ui_ref


func _physics_process(_delta: float) -> void:
	if character == null or not is_instance_valid(character) or not character.alive:
		return
	if combat == null or not combat.is_playing():
		character.move_dir = Vector2.ZERO
		return

	var dir := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	character.move_dir = dir.normalized() if dir.length_squared() > 0.01 else Vector2.ZERO

	character.set_aim(character.get_global_mouse_position())

	if SwapManager.mode != SwapManager.Mode.IDLE:
		return
	var screen_mouse := get_viewport().get_mouse_position()
	if ui != null and ui.is_ui_at_screen(screen_mouse):
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		character.try_basic_attack()


func _unhandled_input(event: InputEvent) -> void:
	if character == null or not is_instance_valid(character) or not character.alive:
		return
	if combat == null or not combat.is_playing():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SHIFT:
			SwapManager.enter_targeting()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if SwapManager.mode != SwapManager.Mode.IDLE:
			return
		if ui != null and ui.is_ui_at_screen(event.position):
			return
		character.try_special()
