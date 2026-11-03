class_name OwnedCreature
extends RefCounted
## A purchased creature. It always keeps its purchased form: combat
## transformations live on the temporary combat Unit and reset each round.

static var _next_uid := 1

var uid: int
var form_id: String
var cell := Vector2i(-1, -1) # board cell when fielded
var slot := -1 # reserve slot when benched


func _init(id: String) -> void:
	form_id = id
	uid = _next_uid
	_next_uid += 1


func is_fielded() -> bool:
	return cell.x >= 0


func price() -> int:
	return CreatureDB.get_form(form_id).price
