@tool
extends EditorPlugin
## Registers the Tuning Fork runtime as the `Sfx` autoload while the addon is on.

const AUTOLOAD := "Sfx"


func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD, "res://addons/tuning_fork/sfx.gd")


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD)
