class_name ShiftSpell
extends RefCounted
## Charges of one wizard's shapeshift spell during a combat.
## One charge at start, three at most, one charge recharged every three
## seconds sequentially. Casting never resets a running recharge timer.

var charges := Rules.START_CHARGES
var recharge := 0.0 # seconds accumulated toward the next charge


func tick(dt: float) -> void:
	if charges >= Rules.MAX_CHARGES:
		recharge = 0.0
		return
	recharge += dt
	while recharge >= Rules.RECHARGE_TIME and charges < Rules.MAX_CHARGES:
		recharge -= Rules.RECHARGE_TIME
		charges += 1
	if charges >= Rules.MAX_CHARGES:
		recharge = 0.0


func can_cast() -> bool:
	return charges > 0


func consume() -> void:
	charges -= 1


func progress() -> float:
	return recharge / Rules.RECHARGE_TIME
