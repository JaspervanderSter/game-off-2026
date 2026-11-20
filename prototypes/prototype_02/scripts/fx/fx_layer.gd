class_name FxLayer
extends Node2D
## Visual-only effects. Nothing here has gameplay logic or collisions.

var items: Array[Dictionary] = []


func add(kind: String, pos: Vector2, extra: Dictionary = {}) -> void:
	var item := {"kind": kind, "pos": pos, "t": 0.0, "life": 0.5}
	item.merge(extra, true)
	match kind:
		"merge", "combine":
			item.life = 0.65 if kind == "merge" else 0.32
		"shift_bless":
			# Shapeshift of one of the caster's own creatures: a golden pillar of
			# light, a double ring, rising sparks and a level-up chevron.
			item.life = 0.95
			for i in 14:
				var a := -PI / 2 + randf_range(-1.1, 1.1)
				add("spark", pos + Vector2(randf_range(-14, 14), randf_range(-6, 10)), {
					"vel": Vector2.from_angle(a) * randf_range(90, 230), "col": Color(1.0, 0.9, 0.45),
					"size": randf_range(3.0, 6.0), "drag": 2.2, "lift": -60.0})
		"shift_hex":
			# Shapeshift of an enemy creature: a violet vortex implodes into the
			# target, then bursts with crackles and dark smoke.
			item.life = 0.85
			item.cracks = []
			for i in 6:
				var a := TAU * i / 6.0 + randf_range(-0.3, 0.3)
				var pts := [Vector2.ZERO]
				for j in 4:
					pts.append(Vector2.from_angle(a + randf_range(-0.45, 0.45)) * (10.0 + j * 11.0))
				item.cracks.append(pts)
		"spark":
			item.life = randf_range(0.5, 0.8)
		"rocket":
			item.life = 1.6
			var side := -1.0 if randf() < 0.5 else 1.0
			item.vel = Vector2(side * randf_range(250, 420), randf_range(-700, -520))
			item.spin = side * randf_range(8.0, 14.0)
			item.puff_t = 0.0
		"puff":
			item.life = item.get("life_override", 0.6)
		"heal":
			item.life = 0.7
		"blast", "spray", "display":
			item.life = 0.45
		"fear":
			# Skunk blessing: a stink cloud bursts out to the fear radius.
			item.life = 0.7
			for i in 12:
				var dir := Vector2.from_angle(TAU * i / 12.0 + randf_range(-0.2, 0.2))
				add("puff", pos + dir * 12.0, {"vel": dir * randf_range(110, 170), "col": Color(0.55, 0.75, 0.2, 0.75), "size": randf_range(8.0, 12.0), "life_override": 0.7})
		"fizzle":
			item.life = 0.35
		"song":
			# Beat ring on the bard, plus one note flying to every ally it inspires.
			item.life = 0.6
			var source: Variant = extra.get("source")
			for target in extra.get("targets", []):
				if target != source and is_instance_valid(target):
					add("song_note", pos, {"unit": target, "to": target.position})
			item.erase("targets")
			item.erase("source")
		"song_note":
			item.life = 0.6
	items.append(item)


func _process(dt: float) -> void:
	for item in items.duplicate():
		item.t += dt
		match item.kind:
			"rocket":
				item.vel.y += 900.0 * dt
				item.pos += item.vel * dt
				item.puff_t -= dt
				if item.puff_t <= 0.0:
					item.puff_t = 0.03
					add("puff", item.pos, {"vel": -item.vel * 0.05, "col": Color(0.85, 0.85, 0.85, 0.7), "size": 7.0})
			"puff":
				item.pos += item.get("vel", Vector2.ZERO) * dt
			"spark":
				item.vel *= maxf(0.0, 1.0 - item.get("drag", 0.0) * dt)
				item.vel.y += item.get("lift", 0.0) * dt
				item.pos += item.vel * dt
			"shift_hex":
				# Dark smoke bursts out once the vortex has collapsed.
				if item.t >= item.life * 0.45 and not item.get("burst", false):
					item.burst = true
					for i in 10:
						var dir := Vector2.from_angle(TAU * i / 10.0 + randf_range(-0.2, 0.2))
						add("puff", item.pos + dir * 10.0, {"vel": dir * randf_range(70, 130), "col": Color(0.45, 0.15, 0.6, 0.8), "size": randf_range(7.0, 11.0)})
					for i in 6:
						add("spark", item.pos, {"vel": Vector2.from_angle(randf() * TAU) * randf_range(120, 220), "col": Color(0.85, 0.5, 1.0), "size": 4.0, "drag": 3.0})
			"song_note":
				# Home in on the ally while it moves; keep the last spot if it dies.
				var unit: Variant = item.unit
				if is_instance_valid(unit) and unit.alive:
					item.to = unit.position
		if item.t >= item.life:
			items.erase(item)
	queue_redraw()


func _draw() -> void:
	for item in items:
		var k: float = item.t / item.life
		var p: Vector2 = item.pos
		match item.kind:
			"merge", "combine":
				Shapes.arc(self, p, 15 + 38 * k, 0, TAU, 32, Color(1, 0.85, 0.25, 1.0 - k), 4 * (1.0 - k) + 1, true)
				if item.kind == "merge":
					Icons.star(self, p + Vector2(0, -35 - 25 * k), 18 * sin(PI * k), Color(1, 0.9, 0.3, 1.0 - k))
					for j in 8:
						Icons.star(self, p + Vector2.from_angle(TAU * j / 8.0) * (20 + 35 * k), 5 * (1.0 - k), Color(1, 0.9, 0.3, 1.0 - k))
			"shift_bless":
				# White flash, then a narrowing pillar of golden light.
				if k < 0.18:
					Shapes.circle(self, p, 34.0 + 30.0 * k, Color(1, 1, 0.9, 0.85 * (1.0 - k / 0.18)))
				var w := 34.0 * (1.0 - k)
				var top := maxf(p.y - 150.0, -12.0) # stay on the board, off the HUD
				for i in 4:
					var band := Rect2(p.x - w * (1.0 - i * 0.22) * 0.5, top, w * (1.0 - i * 0.22), p.y + 15.0 - top)
					draw_rect(band, Color(1.0, 0.92, 0.55, 0.16 * (1.0 - k)))
				for i in 2:
					var ring := clampf(k * 1.5 - i * 0.25, 0.0, 1.0)
					if ring > 0.0 and ring < 1.0:
						Shapes.arc(self, p, 16.0 + 48.0 * ring, 0, TAU, 40, Color(1.0, 0.85, 0.3, 1.0 - ring), 5.0 * (1.0 - ring) + 1.0, true)
				# Level-up chevrons rising above the creature.
				for i in 2:
					var c := Color(1.0, 0.95, 0.6, 1.0 - k)
					var q := p + Vector2(0, -34.0 - 40.0 * k - i * 9.0)
					Shapes.polyline(self, PackedVector2Array([q + Vector2(-9, 6), q, q + Vector2(9, 6)]), c, 4.0, true)
			"shift_hex":
				var col := Color(0.62, 0.2, 0.9)
				if k < 0.45:
					# Implosion: a dark disc and particles spiralling into the target.
					var e := k / 0.45
					Shapes.circle(self, p, 26.0 * (1.0 - e) + 8.0, Color(0.18, 0.02, 0.25, 0.55))
					for i in 12:
						var a := TAU * i / 12.0 + e * 5.0
						var q := p + Vector2.from_angle(a) * 70.0 * (1.0 - e * e)
						Shapes.circle(self, q, 4.0 + 2.0 * e, Color(col.r, col.g, col.b, 0.4 + 0.6 * e))
					Shapes.arc(self, p, 70.0 * (1.0 - e * e), 0, TAU, 40, Color(col.r, col.g, col.b, 0.35 + 0.5 * e), 3.0, true)
				else:
					# Burst: a dark flash, a fast violet shock ring and crackles.
					var e := (k - 0.45) / 0.55
					if e < 0.2:
						Shapes.circle(self, p, 30.0, Color(0.1, 0.0, 0.15, 0.7 * (1.0 - e / 0.2)))
					Shapes.arc(self, p, 12.0 + 62.0 * e, 0, TAU, 40, Color(0.85, 0.5, 1.0, 1.0 - e), 6.0 * (1.0 - e) + 1.0, true)
					for crack in item.cracks:
						var pts := PackedVector2Array()
						for v in crack:
							pts.append(p + v * (0.6 + 0.6 * e))
						Shapes.polyline(self, pts, Color(0.9, 0.7, 1.0, 1.0 - e), 2.5, true)
			"spark":
				var c: Color = item.col
				c.a *= 1.0 - k
				Icons.star(self, p, item.size * (1.0 - 0.5 * k), c)
			"rocket":
				Shapes.set_transform(self, p, item.t * item.spin, Vector2.ONE)
				Icons.token(self, item.form, Vector2.ZERO, Rules.BODY_RADIUS * Rules.CELL, item.team)
				Shapes.set_transform(self, Vector2.ZERO, 0.0, Vector2.ONE)
			"puff":
				var col: Color = item.get("col", Color(0.8, 0.8, 0.8, 0.7))
				col.a *= 1.0 - k
				Shapes.circle(self, p, item.get("size", 8.0) * (1.0 + k * 1.5), col)
			"blast":
				Shapes.circle(self, p, item.get("radius", 40.0) * (0.4 + 0.6 * k), Color(1.0, 0.5, 0.1, 0.5 * (1.0 - k)))
				Shapes.arc(self, p, item.get("radius", 40.0) * (0.4 + 0.6 * k), 0, TAU, 24, Color(1.0, 0.85, 0.3, 1.0 - k), 3.0, true)
			"spray":
				Shapes.circle(self, p, item.radius * (0.5 + 0.5 * k), Color(0.55, 0.8, 0.2, 0.35 * (1.0 - k)))
			"fear":
				var e := 1.0 - (1.0 - k) * (1.0 - k)
				Shapes.circle(self, p, item.radius * e, Color(0.5, 0.7, 0.15, 0.3 * (1.0 - k)))
				Shapes.arc(self, p, item.radius * e, 0, TAU, 40, Color(0.75, 0.45, 0.95, 1.0 - k), 5.0 * (1.0 - k) + 1.0, true)
			"display":
				for i in 3:
					Shapes.arc(self, p, item.radius * (0.3 + 0.7 * k) - i * 6.0, 0, TAU, 32, Color(0.3, 0.6, 1.0, 0.8 * (1.0 - k)), 3.0, true)
			"heal":
				if item.has("from"):
					Shapes.line(self, item.from, p, Color(1.0, 0.95, 0.6, 0.7 * (1.0 - k)), 3.0, true)
				var q := p + Vector2(0, -20.0 * k)
				var c := Color(0.5, 1.0, 0.5, 1.0 - k)
				Shapes.line(self, q + Vector2(-8, 0), q + Vector2(8, 0), c, 4.0)
				Shapes.line(self, q + Vector2(0, -8), q + Vector2(0, 8), c, 4.0)
			"parry":
				Icons.parry_mark(self, p + Vector2(0, -10), 10.0 + 6.0 * k)
			"impact", "charge", "dive", "hop", "shell":
				Shapes.arc(self, p, 12.0 + 30.0 * k, 0, TAU, 24, Color(1, 1, 1, 1.0 - k), 3.0, true)
			"song":
				# Two golden sound waves and a small fan of notes above the bard.
				for i in 2:
					var wave := clampf(k * 1.4 - i * 0.3, 0.0, 1.0)
					if wave > 0.0 and wave < 1.0:
						Shapes.arc(self, p, 14.0 + 52.0 * wave, 0, TAU, 32, Color(1.0, 0.85, 0.3, 0.8 * (1.0 - wave)), 3.0 * (1.0 - wave) + 1.0, true)
				for i in 3:
					var drift := Vector2((i - 1) * 16.0 * k, -26.0 - 26.0 * k)
					var c := Icons.GOLD
					c.a = 1.0 - k
					Icons.note_shadowed(self, p + drift, 10.0, c)
			"song_note":
				var to: Vector2 = item.to
				if k < 0.6:
					# Flight: an arc from the bard to the ally, slightly overhead.
					var e := k / 0.6
					e = e * e * (3.0 - 2.0 * e)
					var q := p.lerp(to, e) + Vector2(0, -sin(e * PI) * 34.0 - 18.0 * e)
					Icons.note_shadowed(self, q, 11.0, Icons.GOLD)
				else:
					# Arrival: a golden ring burst and a note popping above the ally.
					var e := (k - 0.6) / 0.4
					Shapes.arc(self, to, 14.0 + 26.0 * e, 0, TAU, 24, Color(1.0, 0.85, 0.3, 1.0 - e), 4.0 * (1.0 - e) + 1.0, true)
					var c := Icons.GOLD
					c.a = 1.0 - e
					Icons.note_shadowed(self, to + Vector2(0, -18.0 - 14.0 * e), 10.0 + 5.0 * sin(e * PI), c)
			"fizzle":
				var c := Color(0.7, 0.7, 0.75, 1.0 - k)
				Shapes.line(self, p + Vector2(-8, -8), p + Vector2(8, 8), c, 3.0)
				Shapes.line(self, p + Vector2(-8, 8), p + Vector2(8, -8), c, 3.0)
