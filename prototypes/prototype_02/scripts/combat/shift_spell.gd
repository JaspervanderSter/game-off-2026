class_name ShiftSpell
extends RefCounted
## Charges of one wizard's shapeshift spell during a combat.
## One charge at start (more with the charges upgrade), three at most. Default
## recharge is three seconds; the recharge upgrade reduces it to 2.4. Casting
## never resets the timer.

var charges := Rules.START_CHARGES
var recharge := 0.0 # seconds accumulated toward the next charge
var recharge_time := Rules.RECHARGE_TIME


func tick(dt: float) -> void:
	if charges >= Rules.MAX_CHARGES:
		recharge = 0.0
		return
	recharge += dt
	while recharge >= recharge_time and charges < Rules.MAX_CHARGES:
		recharge -= recharge_time
		charges += 1
	if charges >= Rules.MAX_CHARGES:
		recharge = 0.0


func can_cast() -> bool:
	return charges > 0


func consume() -> void:
	charges -= 1


func progress() -> float:
	return recharge / recharge_time
