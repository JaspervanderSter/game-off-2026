class_name Journey
extends RefCounted
## A won duel opens every outgoing road. Branches remain replayable.

const LEVELS := [0, 0, 0, 1, 1, 1, 2]
const ROADS := [Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 4), Vector2i(3, 5), Vector2i(4, 6), Vector2i(5, 6)]
const NAMES := ["The clearing", "The old grove", "The wolf trail", "The village gate", "The village watch", "The crossroads", "The archmage"]

var completed: Array[int] = []
var selected := -1

func available(index: int) -> bool:
	if index < 0 or index >= LEVELS.size():
		return false
	if index == 0 or index in completed:
		return true
	for road in ROADS:
		if road.y == index and road.x in completed:
			return true
	return false

func restore(config: ConfigFile, legacy_difficulty: int) -> void:
	completed.clear()
	if config.has_section_key("journey", "completed"):
		var saved = config.get_value("journey", "completed", [])
		if saved is Array:
			for index in saved:
				if index is int and index >= 0 and index < LEVELS.size() and index not in completed:
					completed.append(index)
	else:
		# Preserve access earned before the map existed.
		for index in LEVELS.size():
			if LEVELS[index] < legacy_difficulty:
				completed.append(index)

func record_win() -> void:
	if available(selected) and selected not in completed:
		completed.append(selected)
