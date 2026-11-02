class_name Ability
extends RefCounted
## Modular special-attack data object. Abilities are stateless: they read the
## casting character at execution time, so they can be swapped between any two
## characters safely.

var id: String = ""
var display_name: String = "ABILITY"
var short_name: String = "ABILITY"
var description: String = ""
var color: Color = Color.WHITE
var glyph: String = "◆"
var origin_archetype: String = ""


func execute(_character: Character, _aim_dir: Vector2) -> void:
	pass
