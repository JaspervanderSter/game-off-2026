class_name Journey
extends RefCounted
## Each won duel discovers the next encounter. Completed stages remain replayable.

const LEVELS := [0, 0, 0, 1, 1, 1, 2]
const ISLANDS := [0, 0, 0, 1, 1, 1, 2]
const ENVIRONMENTS := ["forest", "town", "school"]
const HEARTS := [3, 6, 10]
const ROADS := [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(4, 5), Vector2i(5, 6)]
const NAMES := ["The clearing", "The old grove", "The wolf trail", "The village gate", "The village watch", "The crossroads", "The archmage"]

var completed: Array[int] = []
var selected := -1

static func environment_for_stage(index: int) -> String:
	if index < 0 or index >= ISLANDS.size():
		return ENVIRONMENTS[0]
	return ENVIRONMENTS[ISLANDS[index]]

static func hearts_for_stage(index: int) -> int:
	if index < 0 or index >= ISLANDS.size():
		return Rules.WIZARD_HP
	return HEARTS[ISLANDS[index]]

func available(index: int) -> bool:
	if index < 0 or index >= LEVELS.size():
		return false
	if index == 0 or index in completed:
		return true
	return index - 1 in completed

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
	# Older branching saves can have gaps. Preserve the furthest earned stage
	# by crediting the encounters that now precede it in the linear journey.
	if not completed.is_empty():
		var furthest: int = completed.max()
		completed.clear()
		for index in furthest + 1:
			completed.append(index)

func record_win() -> void:
	if available(selected) and selected not in completed:
		completed.append(selected)
