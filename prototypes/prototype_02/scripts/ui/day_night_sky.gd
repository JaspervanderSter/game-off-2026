extends Node2D
## Four procedural sky palettes blended in a seamless, map-local cycle.
## The clock pauses outside the map and never restarts when it is reopened.
@export_range(8.0, 1200.0, 1.0) var cycle_seconds := 160.0
var elapsed := 0.0
var drift_time := 0.0
var scroll_offset := 0.0
## Horizontal counterpart of scroll_offset: the pan from the title island.
var scroll_x := 0.0
const TOP := [Color("688f9f"), Color("bba08b"), Color("655770"), Color("222d44")]
const BOTTOM := [Color("a8bdba"), Color("e5ca9e"), Color("ad929a"), Color("48546b")]
const CLOUD := [Color("d1dccf"), Color("ecdbb9"), Color("c5acb4"), Color("637087")]

## How much of each of the four sky states (day, golden mist, dusk, night) the
## cycle shows at `phase`; the weights add up to 1. The map ambience follows them.
static func weights(phase: float) -> PackedFloat32Array:
	var position := fposmod(phase, 1.0) * 4.0
	var index := int(position) % 4
	var blend := _blend(position)
	var result := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	result[index] += 1.0 - blend
	result[(index + 1) % 4] += blend
	return result

## A short rest at each palette lets the four visual identities read clearly.
static func _blend(position: float) -> float:
	return smoothstep(0.18, 0.88, fmod(position, 1.0))

static func palette(phase: float) -> Dictionary:
	var position := fposmod(phase, 1.0) * 4.0
	var index := int(position) % 4
	var next := (index + 1) % 4
	var blend := _blend(position)
	var night := lerpf(1.0 if index == 3 else 0.0, 1.0 if next == 3 else 0.0, blend)
	return {
		"top": TOP[index].lerp(TOP[next], blend),
		"bottom": BOTTOM[index].lerp(BOTTOM[next], blend),
		"cloud": CLOUD[index].lerp(CLOUD[next], blend),
		"night": night,
		"ribbon": lerpf(0.0 if index == 0 else 1.0, 0.0 if next == 0 else 1.0, blend),
	}

func advance(dt: float) -> void:
	elapsed = fposmod(elapsed + dt, maxf(cycle_seconds, 0.01))
	drift_time += dt
	queue_redraw()

func _process(dt: float) -> void:
	if is_visible_in_tree():
		advance(dt)

func colors() -> Dictionary:
	return palette(elapsed / maxf(cycle_seconds, 0.01))

func _draw() -> void:
	var size := get_viewport_rect().size
	var state := colors()
	for i in 128:
		var y := size.y * i / 128.0
		draw_rect(Rect2(0, y, size.x, size.y / 128.0 + 1), state.top.lerp(state.bottom, i / 127.0))
	# Deterministic positions avoid any flicker while scrolling or resizing.
	for i in 70:
		var p := Vector2(fmod(41 + i * 137.31, size.x), fposmod(20 + i * 97.17 - scroll_offset * 0.035, size.y))
		var alpha: float = state.night * (0.6 + sin(drift_time * 0.7 + i) * 0.18)
		if i % 13 == 0:
			Icons.star(self, p, 3.5, Color(1, 0.89, 0.65, alpha))
		else:
			Shapes.circle(self, p, 1.0 + (i % 3) * 0.3, Color(0.86, 0.9, 0.96, alpha))
	# A crescent polygon avoids painting a false sky-coloured disc over a gradient.
	var moon := PackedVector2Array()
	var origin := Vector2(size.x * 0.87, 280 if size.y > size.x else 115)
	for i in 41:
		var a := lerpf(0.5 * PI, 1.5 * PI, i / 40.0)
		moon.append(origin + Vector2(cos(a), sin(a)) * 27)
	for i in 41:
		var a := lerpf(1.5 * PI, 0.5 * PI, i / 40.0)
		moon.append(origin + Vector2(10 + cos(a) * 20, sin(a) * 27))
	draw_colored_polygon(moon, Color(0.94, 0.89, 0.71, state.night))
	for i in 9:
		var x := fposmod(i * 239.0 + drift_time * (1.8 + i % 3) - scroll_x * 0.07, size.x + 340) - 170
		var y := fposmod(90 + i * 181.0 - scroll_offset * 0.07, size.y + 120) - 30
		cloud(self, Vector2(x, y), 0.85 + (i % 3) * 0.3, Color(state.cloud, 0.55), state.ribbon)

static func cloud(ci: CanvasItem, p: Vector2, scale_factor: float, color: Color, ribbon := 0.0) -> void:
	# One outline per cloud prevents overlapping translucent discs.
	var outline := PackedVector2Array()
	var knots := [Vector2(-90, 8), Vector2(-43, -14), Vector2(9, -27), Vector2(49, -12), Vector2(92, 12), Vector2(-90, 8)]
	var controls := [Vector2(-85, -10), Vector2(-65, -17), Vector2(-35, -42), Vector2(-10, -39), Vector2(26, -41), Vector2(49, -25), Vector2(83, -21), Vector2(110, 0), Vector2(32, 22), Vector2(-50, 24)]
	for segment in 5:
		for i in 9:
			var t := i / 8.0
			var q: Vector2 = knots[segment].bezier_interpolate(controls[segment * 2], controls[segment * 2 + 1], knots[segment + 1], t)
			q.y *= lerpf(1.0, 0.28, ribbon)
			q.x *= lerpf(1.0, 1.25, ribbon)
			outline.append(p + q * scale_factor)
	ci.draw_colored_polygon(outline, color)
