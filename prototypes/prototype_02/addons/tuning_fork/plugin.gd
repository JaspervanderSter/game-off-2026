@tool
extends EditorPlugin
## Registers the Tuning Fork runtime as the `Sfx` autoload while the addon is on,
## and the switch of its play log in Project Settings (Audio > Tuning Fork).

const AUTOLOAD := "Sfx"
const LOG_SETTING := "audio/tuning_fork/log_plays"


func _enter_tree() -> void:
	if not ProjectSettings.has_setting(LOG_SETTING):
		ProjectSettings.set_setting(LOG_SETTING, false)
	ProjectSettings.set_initial_value(LOG_SETTING, false)
	ProjectSettings.add_property_info({"name": LOG_SETTING, "type": TYPE_BOOL})
	ProjectSettings.set_as_basic(LOG_SETTING, true)


func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD, "res://addons/tuning_fork/sfx.gd")


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD)
