class_name SoundSet
extends RefCounted
## Chooses which sound effects the game plays, to compare them before and after
## a change: the current ones in res://sfx/ (the default), or the earlier ones
## in LEGACY_DIR laid over them (Sfx.set_overlay). The choice is toggled in
## game (see main.gd) and survives restarts through `save_path`.
##
## LEGACY_DIR holds the sounds as they were before the duel sound effects of
## 14 November 2026 (commit b770cb4): the six files that commit replaced, and,
## for the four events it added, the file of the event they played until then.

enum Set { CURRENT, LEGACY }

const LEGACY_DIR := "res://sfx_legacy/"

static var save_path := "user://sound_set.cfg"
static var _set := -1 # -1 until loaded from save_path


static func current() -> Set:
	if _set < 0:
		var config := ConfigFile.new()
		_set = Set.CURRENT
		if config.load(save_path) == OK and config.get_value("sound", "set", "current") == "legacy":
			_set = Set.LEGACY
	return _set as Set


static func is_legacy() -> bool:
	return current() == Set.LEGACY


static func set_set(value: Set) -> void:
	_set = value
	var config := ConfigFile.new()
	config.set_value("sound", "set", "legacy" if value == Set.LEGACY else "current")
	var error := config.save(save_path)
	if error != OK:
		push_warning("Could not save the sound set to %s (error %d)." % [save_path, error])
	apply()


static func toggle() -> Set:
	set_set(Set.CURRENT if is_legacy() else Set.LEGACY)
	return current()


## Makes Sfx play the chosen set.
static func apply() -> void:
	Sfx.set_overlay(LEGACY_DIR if is_legacy() else "")


## Forgets the loaded choice so the next call reads save_path again.
static func reload() -> void:
	_set = -1
