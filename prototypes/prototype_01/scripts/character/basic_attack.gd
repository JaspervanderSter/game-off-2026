class_name BasicAttack
extends RefCounted
## Swappable normal-attack profile. Damage is still driven by the character's
## current strength and attack-cooldown attributes; this object defines the
## weapon shape, range, multiplier and knockback.

var id: String = ""
var display_name: String = "BASIC ATTACK"
var short_name: String = "BASIC"
var description: String = ""
var kind: String = "melee" # "melee" or "ranged"
var range: float = 70.0
var arc: float = 90.0
var damage_mult: float = 1.0
var knockback: float = 100.0
var swing: float = 0.15
var projectile_speed: float = 600.0
var projectile_radius: float = 6.0
var color: Color = Color.WHITE
var origin_archetype: String = ""
var fit: Dictionary = {}
