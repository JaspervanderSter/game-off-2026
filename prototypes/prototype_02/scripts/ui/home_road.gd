class_name HomeRoad
extends Node2D
## What leads from the title island into the journey (playtest decision,
## 22 November 2026), drawn in the map's world coordinates by world_map.gd:
## - the island medallion, standing on the title island's bridge near the
##   screen's right edge, gold chevrons gliding along the deck towards it;
## - the footsteps from the cottage door, over the bridge, to the hunter;
## - during the journey's replay, the gold dots running along the beaten
##   roads and the stars of each opponent popping up as they reach it.

const GOLD := Color("ddba70")
const DOT := Color("e4cb94")

var map # world_map.gd
## The footsteps' dots, and the distance of each along the road; the bridge
## lies between deck_from and deck_to.
var dots := PackedVector2Array()
var dot_at := PackedFloat32Array()
var deck_from := 0.0
var deck_to := 0.0
## How many footsteps show.
var shown := 0
var clock := 0.0
var _stars: Array[Dictionary] = []


func _process(dt: float) -> void:
	if not is_visible_in_tree():
		return
	clock += dt
	for s in _stars:
		s.age += dt
		s.vel *= 1.0 - minf(1.0, 4.0 * dt)
		s.pos += s.vel * dt
	_stars = _stars.filter(func(s): return s.age < 0.5)
	queue_redraw()


## A burst of stars and puffs where an opponent pops up.
func burst(at: Vector2) -> void:
	for i in 8:
		var dir := Vector2.from_angle(TAU * i / 8.0 + randf() * 0.3)
		_stars.append({"pos": at + Vector2(0, -16), "vel": dir * randf_range(90, 150), "age": 0.0, "star": i % 2 == 0})


## Where footstep i stands now: on the island it floats with it, on the
## bridge it follows the deck.
func step_position(i: int) -> Vector2:
	if dot_at[i] > deck_from and dot_at[i] < deck_to:
		return map.home_bridge.point_at((dot_at[i] - deck_from) / (deck_to - deck_from))
	if dot_at[i] <= deck_from:
		return dots[i] + Vector2(0, map.title.lift()) * map.title.scale.y
	return dots[i]


## Where the medallion stands now, in world coordinates.
func medallion_position() -> Vector2:
	var title: TitleScreen = map.title
	return title.position + (TitleScreen.MEDALLION + Vector2(0, title.lift() + sin(clock * 2.0) * 3.0)) * title.scale.x


func _draw() -> void:
	for i in shown:
		var tip: bool = i == shown - 1 and map.menu_blend > 0.0
		_dot(step_position(i), tip)
	# The beaten roads being walked, until each opponent pops up.
	for i in int(map.walk_pos):
		if map.walk_stage[i] not in map.discovered:
			_dot(map.walk[i], i == int(map.walk_pos) - 1)
	for s in _stars:
		var k: float = 1.0 - s.age / 0.5
		if s.star:
			Icons.star(self, s.pos, 6.0 * k, Color(GOLD, k))
		else:
			Shapes.circle(self, s.pos, 5.0 * k, Color(1, 1, 1, 0.8 * k))
	_draw_medallion()


func _dot(p: Vector2, tip: bool) -> void:
	if tip:
		Shapes.circle(self, p, 6.0, Color(GOLD, 0.18))
	Shapes.circle(self, p, 3.5, Color(0.18, 0.13, 0.10, 0.55))
	Shapes.circle(self, p, 2.3, GOLD if tip else DOT)


## The way to the map: on the bridge, chevrons gliding towards it. It fades as
## the camera leaves the title.
func _draw_medallion() -> void:
	var title: TitleScreen = map.title
	var age := title.medallion_age()
	var leave := clampf(1.0 - (1.0 - map.menu_blend) * 5.0, 0.0, 1.0)
	if age <= 0.0 or leave <= 0.0:
		return
	var at := medallion_position()
	# At least 30 pixels across the screen, also when a portrait screen shrinks the title.
	var size := maxf(38.0, 30.0 / maxf(0.01, get_global_transform_with_canvas().get_scale().x))
	var r := size * minf(1.0, age / 0.25) * (1.0 + 0.25 * sin(minf(age / 0.35, 1.0) * PI) * exp(-age * 2.0)) * leave
	for i in 4:
		var u := fmod(clock * 0.5 + i * 0.25, 1.0)
		var p: Vector2 = map.home_bridge.point_at(lerpf(0.05, 0.45, u)) + Vector2(0, -34)
		if p.x > at.x - r - 10.0:
			continue
		var a := sin(u * PI) * 0.8 * leave * minf(1.0, age / 0.4)
		Shapes.polyline(self, PackedVector2Array([p + Vector2(-6, -8), p, p + Vector2(-6, 8)]), Color(GOLD, a), 3.0)
	var hot: bool = map.on_title() and not title.animating() \
		and get_local_mouse_position().distance_to(at) < TitleScreen.MEDALLION_RADIUS / maxf(0.01, get_global_transform_with_canvas().get_scale().x)
	Icons.island_medallion(self, at, r, clock, hot)
