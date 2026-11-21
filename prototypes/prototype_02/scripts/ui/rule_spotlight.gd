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
const DISMISS_FADE := 0.1 # a dismissed spotlight goes out this fast
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
## Seconds at full strength, between the fade in and the fade out.
var hold := HOLD
## While valid, called every frame for [center, radii] (an empty array keeps
## them): the spotlight follows a moving element, such as harvest coins.
var track := Callable()
## Time at which dismiss() cut the spotlight short, and its strength then;
## negative while it runs its full course.
var _dismissed_at := -1.0
var _dismissed_from := 0.0


## Prepares a duel: `introduced_rule` waits for its moment ("" for none).
func reset(introduced_rule: String) -> void:
	rule = introduced_rule
	time = -1.0
	unit = null
	track = Callable()
	hold = HOLD
	_dismissed_at = -1.0


## True while the rule still waits for its moment.
func pending() -> bool:
	return rule != "" and time < 0.0


func duration() -> float:
	if _dismissed_at >= 0.0:
		return _dismissed_at + DISMISS_FADE
	return FADE_IN + hold + FADE_OUT


func active() -> bool:
	return time >= 0.0 and time < duration()


## Starts the spotlight on an ellipse (screen coordinates), on `follow`, or on
## what `track_with` returns; it stays at full strength for `hold_for` seconds.
func begin(at: Vector2, ellipse: Vector2, follow: Unit = null, hold_for := HOLD, track_with := Callable()) -> void:
	center = at
	radii = ellipse
	unit = follow
	hold = hold_for
	track = track_with
	time = 0.0
	_dismissed_at = -1.0
	Sfx.play("ui/difficulty_unlock")


## Puts an active spotlight out within DISMISS_FADE: the player has used what
## it showed.
func dismiss() -> void:
	if not active() or _dismissed_at >= 0.0:
		return
	_dismissed_from = _strength()
	_dismissed_at = time


func advance(dt: float) -> void:
	if time < 0.0:
		return
	time += dt
	if track.is_valid():
		var shot: Array = track.call()
		if shot.size() == 2:
			center = shot[0]
			radii = shot[1]
	elif unit != null and is_instance_valid(unit) and unit.alive:
		center = Rules.BOARD_POS + unit.position
	if time >= duration():
		rule = ""
		unit = null
		track = Callable()


## Combat speed while the spotlight is on: slow while fully dimmed.
func time_scale() -> float:
	return lerpf(1.0, SLOW_MOTION, _strength()) if active() else 1.0


func _strength() -> float:
	if _dismissed_at >= 0.0:
		return _dismissed_from * (1.0 - smoothstep(_dismissed_at, duration(), time))
	if time < FADE_IN:
		return smoothstep(0.0, FADE_IN, time)
	return 1.0 - smoothstep(FADE_IN + hold, duration(), time)


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
