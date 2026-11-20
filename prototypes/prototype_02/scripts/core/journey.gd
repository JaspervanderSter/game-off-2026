class_name Journey
extends RefCounted
## Fifteen opponents in three linear zones (OpponentDB). Beating an opponent
## opens the next one; the fifth of a zone opens the next zone. Beaten
## opponents remain replayable.

var completed: Array[int] = []
var selected := -1


static func stage_count() -> int:
	return OpponentDB.count()


func available(index: int) -> bool:
	if index < 0 or index >= stage_count():
		return false
	return index == 0 or index in completed or index - 1 in completed


## Loads the beaten opponents. Saves from before the fifteen-opponent journey
## keep their access through the difficulty they had unlocked: Adept finishes
## the forest, Archmage the forest and the town.
func restore(config: ConfigFile, legacy_difficulty: int) -> void:
	completed.clear()
	if config.has_section_key("journey", "opponents"):
		var saved = config.get_value("journey", "opponents", [])
		if saved is Array:
			for index in saved:
				if index is int and index >= 0 and index < stage_count() and index not in completed:
					completed.append(index)
	else:
		for index in stage_count():
			if OpponentDB.zone(index) < legacy_difficulty:
				completed.append(index)


func save(config: ConfigFile) -> void:
	config.set_value("journey", "opponents", completed)


func record_win() -> void:
	if available(selected) and selected not in completed:
		completed.append(selected)
