class_name PackDeck
extends RefCounted
## Hidden deck of starting compositions (indices into CreatureDB.PACKS).
## Draws come from a shuffled order without repeats; once RESHUFFLE_AFTER cards
## have been dealt, or the next draw would pass that mark, the whole deck is
## shuffled again. The player is dealt three cards per duel (every composition
## of the first nine is seen before a repeat), the opponent one card per duel
## from its own deck. Nothing on screen shows the deck: the cards simply look
## random. The order survives restarts through `save_path`.

const RESHUFFLE_AFTER := 9

## Tests point this at a scratch file so they never disturb a player's decks.
static var save_path := "user://pack_decks.cfg"

var key: String
var order: Array[int] = []
var dealt := 0


func _init(deck_key: String) -> void:
	key = deck_key


func deal(count: int, rng: RandomNumberGenerator) -> Array[int]:
	if not _valid() or dealt + count > RESHUFFLE_AFTER:
		shuffle(rng)
	var cards: Array[int] = []
	for i in count:
		cards.append(order[dealt + i])
	dealt += count
	return cards


func shuffle(rng: RandomNumberGenerator) -> void:
	order.clear()
	for i in CreatureDB.PACKS.size():
		order.append(i)
	# Fisher-Yates with the game's generator, so seeded runs are reproducible.
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := order[i]
		order[i] = order[j]
		order[j] = swap
	dealt = 0


## A saved order is only reused if it is still a permutation of the packs.
func _valid() -> bool:
	if order.size() != CreatureDB.PACKS.size() or dealt < 0 or dealt > RESHUFFLE_AFTER:
		return false
	var sorted := order.duplicate()
	sorted.sort()
	for i in sorted.size():
		if sorted[i] != i:
			return false
	return true


func load_state() -> void:
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return
	var saved_order = config.get_value(key, "order", [])
	var saved_dealt = config.get_value(key, "dealt", 0)
	if saved_order is Array and saved_dealt is int:
		order.clear()
		for value in saved_order:
			if not value is int:
				order.clear()
				return
			order.append(value)
		dealt = saved_dealt


func save_state() -> void:
	var config := ConfigFile.new()
	config.load(save_path) # keep the other deck's section
	config.set_value(key, "order", Array(order))
	config.set_value(key, "dealt", dealt)
	var error := config.save(save_path)
	if error != OK:
		push_warning("Could not save the %s deck: %s" % [key, error_string(error)])
