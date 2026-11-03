class_name OwnedCreature
extends RefCounted
## A purchased creature. It always keeps its purchased form: combat
## transformations live on the temporary combat Unit and reset each round.

static var _next_uid := 1

var uid: int
var form_id: String
var stars := 0 # permanent rank, independent of temporary combat levels
var merge_copies := 1 # 1/3 or 2/3 of this rank; no power bonus until 3/3
var cell := Vector2i(-1, -1) # board cell when fielded
var slot := -1 # reserve slot when benched


func _init(id: String) -> void:
	form_id = id
	uid = _next_uid
	_next_uid += 1


func is_fielded() -> bool:
	return cell.x >= 0


func price() -> int:
	return CreatureDB.get_form(form_id).price * int(pow(3, stars)) * merge_copies
