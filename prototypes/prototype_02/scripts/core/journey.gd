class_name Journey
extends RefCounted
## Fifteen opponents, five per island; victories discover the next encounter.
const ENVIRONMENTS := ["forest", "town", "school"]
const HEARTS := [3, 6, 10]
var completed: Array[int] = []
var selected := -1
## Rules whose spotlight has already played (RuleSpotlight): once per rule.
var introduced: Array[String] = []

## The rule opponent `index` still has to introduce: "" once it was shown, once
## the opponent was beaten, or when it introduces none.
func rule_to_introduce(index: int) -> String:
	if index < 0 or index >= stage_count() or index in completed:
		return ""
	var rule: String = OpponentDB.get_opponent(index).rule
	return "" if rule in introduced else rule

static func stage_count() -> int:
	return OpponentDB.count()

static func environment_for_stage(index: int) -> String:
	return ENVIRONMENTS[OpponentDB.zone(index)] if index >= 0 and index < stage_count() else ENVIRONMENTS[0]

static func hearts_for_stage(index: int) -> int:
	return HEARTS[OpponentDB.zone(index)] if index >= 0 and index < stage_count() else Rules.WIZARD_HP

func available(index: int) -> bool:
	return index >= 0 and index < stage_count() and (index == 0 or index in completed or index - 1 in completed)

func restore(config: ConfigFile, legacy_difficulty: int) -> void:
	completed.clear()
	introduced.clear()
	var shown = config.get_value("journey", "introduced", [])
	if shown is Array:
		for rule in shown:
			if rule is String and rule not in introduced:
				introduced.append(rule)
	if config.has_section_key("journey", "opponents"):
		var saved = config.get_value("journey", "opponents", [])
		if saved is Array:
			for index in saved:
				if index is int and index >= 0 and index < stage_count() and index not in completed:
					completed.append(index)
	elif config.has_section_key("journey", "completed"):
		# Preserve advancement from the previous seven-stage map within each zone.
		var saved = config.get_value("journey", "completed", [])
		var furthest := -1
		if saved is Array:
			for index in saved:
				if index is int and index >= 0 and index <= 6:
					furthest = maxi(furthest, index)
		var count := 0
		if furthest == 6:
			count = stage_count()
		elif furthest >= 0:
			var zone := 0 if furthest < 3 else 1
			var beaten := furthest + 1 if zone == 0 else furthest - 2
			count = zone * OpponentDB.ZONE_SIZE + floori(beaten * OpponentDB.ZONE_SIZE / 3.0)
		for index in count:
			completed.append(index)
	else:
		for index in stage_count():
			if OpponentDB.zone(index) < legacy_difficulty:
				completed.append(index)
	# Branching saves become a continuous prefix, keeping their furthest access.
	if not completed.is_empty():
		var furthest: int = completed.max()
		completed.clear()
		for index in furthest + 1:
			completed.append(index)

func save(config: ConfigFile) -> void:
	config.set_value("journey", "opponents", completed)
	config.set_value("journey", "introduced", introduced)

func record_win() -> void:
	if available(selected) and selected not in completed:
		completed.append(selected)
