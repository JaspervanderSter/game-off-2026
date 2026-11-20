class_name RuleSpotlight
extends RefCounted
## Draws the player's eye to the rule a journey opponent introduces, without
## text: the screen dims around an elliptical opening on the new element, a
## gold ring pulses there with orbiting sparkles, then the dimming lifts. It
## plays once per rule, the first time the rule actually shows up in a duel
## (main.gd decides when), and never blocks input. During combat the duel
## slows down while the spotlight is fully on.
## Design: docs/design/prototype_02/Journey and Opponents.md, "Introducing a rule".

const FADE_IN := 0.35
const HOLD := 1.9
const FADE_OUT := 0.5
const DURATION := FADE_IN + HOLD + FADE_OUT
const DIM := Color(0.04, 0.03, 0.06, 0.62)
const GOLD := Color("ddba70")
const SLOW_MOTION := 0.25
const SEGMENTS := 48
const FEATHER := 14.0 # soft inner edge of the dimming, in pixels
const FAR := 2400.0 # outer edge of the dimming: beyond the screen from anywhere

## Rule waiting for its first appearance in this duel; "" when none is left.
var rule := ""
var time := -1.0 # seconds since the spotlight began; negative before it does
var center := Vector2.ZERO
var radii := Vector2.ZERO
var unit: Unit = null # followed while alive, for rules shown on a creature


## Prepares a duel: `introduced_rule` waits for its moment ("" for none).
func reset(introduced_rule: String) -> void:
	rule = introduced_rule
	time = -1.0
	unit = null


## True while the rule still waits for its moment.
func pending() -> bool:
	return rule != "" and time < 0.0


func active() -> bool:
	return time >= 0.0 and time < DURATION


## Starts the spotlight on an ellipse (screen coordinates), or on `follow`.
func begin(at: Vector2, ellipse: Vector2, follow: Unit = null) -> void:
	center = at
	radii = ellipse
	unit = follow
	time = 0.0
	Sfx.play("ui/difficulty_unlock")


func advance(dt: float) -> void:
	if time < 0.0:
		return
	time += dt
	if unit != null and is_instance_valid(unit) and unit.alive:
		center = Rules.BOARD_POS + unit.position
	if time >= DURATION:
		rule = ""
		unit = null


## Combat speed while the spotlight is on: slow while fully dimmed.
func time_scale() -> float:
	return lerpf(1.0, SLOW_MOTION, _strength()) if active() else 1.0


func _strength() -> float:
	if time < FADE_IN:
		return smoothstep(0.0, FADE_IN, time)
	return 1.0 - smoothstep(FADE_IN + HOLD, DURATION, time)


func draw(ci: CanvasItem) -> void:
	if not active():
		return
	var k := _strength()
	# The opening widens slightly as it settles, like a lens focusing.
	var r := radii * lerpf(1.25, 1.0, smoothstep(0.0, FADE_IN, time))
	var dim := Color(DIM, DIM.a * k)
	var clear := Color(DIM, 0.0)
	for i in SEGMENTS:
		var a := TAU * i / SEGMENTS
		var b := TAU * (i + 1) / SEGMENTS
		var da := Vector2(cos(a), sin(a))
		var db := Vector2(cos(b), sin(b))
		var ia := center + da * r
		var ib := center + db * r
		var fa := center + da * (r + Vector2.ONE * FEATHER)
		var fb := center + db * (r + Vector2.ONE * FEATHER)
		ci.draw_polygon(PackedVector2Array([ia, ib, fb, fa]), PackedColorArray([clear, clear, dim, dim]))
		ci.draw_colored_polygon(PackedVector2Array([fa, fb, center + db * FAR, center + da * FAR]), dim)
	# A pulsing gold ring and sparkles orbiting the new element.
	var pulse := 1.0 + sin(time * 7.0) * 0.04
	var ring := PackedVector2Array()
	for i in SEGMENTS + 1:
		var a := TAU * i / SEGMENTS
		ring.append(center + Vector2(cos(a) * r.x, sin(a) * r.y) * pulse)
	Shapes.polyline(ci, ring, Color(GOLD, 0.9 * k), 3.0, true)
	for i in 6:
		var a := time * 1.6 + TAU * i / 6.0
		var p := center + Vector2(cos(a) * r.x, sin(a) * r.y) * (1.08 + 0.05 * sin(time * 5.0 + i))
		Icons.star(ci, p, (4.0 + 1.5 * sin(time * 6.0 + i * 1.3)) * k, Color(1.0, 0.92, 0.6, k))
