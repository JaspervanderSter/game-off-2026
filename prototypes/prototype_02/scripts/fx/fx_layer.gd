class_name FxLayer
extends Node2D
## Visual-only effects. Nothing here has gameplay logic or collisions.

var items: Array[Dictionary] = []


func add(kind: String, pos: Vector2, extra: Dictionary = {}) -> void:
	var item := {"kind": kind, "pos": pos, "t": 0.0, "life": 0.5}
	item.merge(extra, true)
	match kind:
		"shift":
			item.life = 0.7
			var shift_col: Color = extra.get("col", Color(0.8, 0.65, 1.0))
			for i in 8:
				add("puff", pos + Vector2.from_angle(TAU * i / 8.0) * 14.0, {"vel": Vector2.from_angle(TAU * i / 8.0) * 60.0, "col": Color(shift_col.r, shift_col.g, shift_col.b, 0.8), "size": 9.0})
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
		"fizzle":
			item.life = 0.35
		"blocked":
			item.life = 0.4
		"interrupt":
			item.life = 0.45
		"dodge":
			item.life = 0.4
		"combo":
			item.life = 0.8
		"special", "special_blast", "special_heal":
			item.life = 0.65
		"need_special":
			item.life = 0.45
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
		if item.t >= item.life:
			items.erase(item)
	queue_redraw()


func _draw() -> void:
	for item in items:
		var k: float = item.t / item.life
		var p: Vector2 = item.pos
		match item.kind:
			"shift":
				var col := Icons.MAGIC
				col.a = 1.0 - k
				draw_arc(p, 10.0 + k * 50.0, 0, TAU, 32, col, 6.0 * (1.0 - k) + 1.0, true)
				for i in 6:
					var a := TAU * i / 6.0 + k * 3.0
					Icons.star(self, p + Vector2.from_angle(a) * (16.0 + k * 34.0), 6.0 * (1.0 - k) + 1.0, Color(1.0, 0.9, 0.5, 1.0 - k))
			"rocket":
				draw_set_transform(p, item.t * item.spin, Vector2.ONE)
				Icons.token(self, item.form, Vector2.ZERO, Rules.BODY_RADIUS * Rules.CELL, item.team)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"puff":
				var col: Color = item.get("col", Color(0.8, 0.8, 0.8, 0.7))
				col.a *= 1.0 - k
				draw_circle(p, item.get("size", 8.0) * (1.0 + k * 1.5), col)
			"blast":
				draw_circle(p, item.get("radius", 40.0) * (0.4 + 0.6 * k), Color(1.0, 0.5, 0.1, 0.5 * (1.0 - k)))
				draw_arc(p, item.get("radius", 40.0) * (0.4 + 0.6 * k), 0, TAU, 24, Color(1.0, 0.85, 0.3, 1.0 - k), 3.0, true)
			"spray":
				draw_circle(p, item.radius * (0.5 + 0.5 * k), Color(0.55, 0.8, 0.2, 0.35 * (1.0 - k)))
			"display":
				for i in 3:
					draw_arc(p, item.radius * (0.3 + 0.7 * k) - i * 6.0, 0, TAU, 32, Color(0.3, 0.6, 1.0, 0.8 * (1.0 - k)), 3.0, true)
			"heal":
				if item.has("from"):
					draw_line(item.from, p, Color(1.0, 0.95, 0.6, 0.7 * (1.0 - k)), 3.0, true)
				var q := p + Vector2(0, -20.0 * k)
				var c := Color(0.5, 1.0, 0.5, 1.0 - k)
				draw_line(q + Vector2(-8, 0), q + Vector2(8, 0), c, 4.0)
				draw_line(q + Vector2(0, -8), q + Vector2(0, 8), c, 4.0)
			"impact", "charge", "dive", "hop", "shell":
				draw_arc(p, 12.0 + 30.0 * k, 0, TAU, 24, Color(1, 1, 1, 1.0 - k), 3.0, true)
			"fizzle":
				var c := Color(0.7, 0.7, 0.75, 1.0 - k)
				draw_line(p + Vector2(-8, -8), p + Vector2(8, 8), c, 3.0)
				draw_line(p + Vector2(-8, 8), p + Vector2(8, -8), c, 3.0)
			"blocked":
				var c := Color(0.85, 0.8, 1.0, 1.0 - k)
				draw_arc(p, 24.0 + 10.0 * k, 0, TAU, 24, c, 3.0, true)
				draw_line(p + Vector2(-9, -9), p + Vector2(9, 9), Color(1.0, 0.35, 0.35, 1.0 - k), 3.0)
			"interrupt":
				var c := Color(1.0, 0.55, 0.2, 1.0 - k)
				draw_line(p + Vector2(-12, -12), p + Vector2(12, 12), c, 4.0, true)
				draw_line(p + Vector2(-12, 12), p + Vector2(12, -12), c, 4.0, true)
				draw_arc(p, 18.0 + 18.0 * k, 0, TAU, 20, Color(1.0, 0.8, 0.3, 1.0 - k), 2.0, true)
			"dodge":
				var c := Color(0.7, 0.9, 1.0, 1.0 - k)
				draw_arc(p, 14.0 + 30.0 * k, 0, TAU, 24, c, 3.0, true)
				for i in 4:
					var a := TAU * i / 4.0 + k * 3.0
					draw_circle(p + Vector2.from_angle(a) * (18.0 + 16.0 * k), 2.5 * (1.0 - k), c)
			"combo":
				var c := Color(1.0, 0.78, 0.2, 1.0 - k)
				draw_arc(p, 12.0 + 52.0 * k, 0, TAU, 32, c, 4.0 * (1.0 - k) + 1.0, true)
				for i in 8:
					var a := TAU * i / 8.0 + k * 2.0
					Icons.star(self, p + Vector2.from_angle(a) * (18.0 + 40.0 * k), 5.0 * (1.0 - k) + 1.0, Color(1.0, 0.9, 0.4, 1.0 - k))
			"special":
				var col: Color = item.get("color", Color(0.8, 0.7, 1.0))
				col.a = 1.0 - k
				draw_arc(p, 12.0 + 46.0 * k, 0, TAU, 28, col, 4.0 * (1.0 - k) + 1.0, true)
				for i in 6:
					var a := TAU * i / 6.0 + k * 3.0
					Icons.star(self, p + Vector2.from_angle(a) * (16.0 + 34.0 * k), 5.0 * (1.0 - k) + 1.0, col)
			"special_blast":
				var col: Color = item.get("color", Color(1.0, 0.55, 0.2))
				col.a = 0.5 * (1.0 - k)
				draw_circle(p, item.get("radius", 70.0) * (0.4 + 0.6 * k), col)
				draw_arc(p, item.get("radius", 70.0) * (0.4 + 0.6 * k), 0, TAU, 28, Color(col.r, col.g, col.b, 1.0 - k), 3.0, true)
			"special_heal":
				var col: Color = item.get("color", Color(0.5, 1.0, 0.5))
				col.a = 0.45 * (1.0 - k)
				draw_circle(p, item.get("radius", 70.0) * (0.4 + 0.6 * k), col)
				draw_arc(p, item.get("radius", 70.0) * (0.5 + 0.5 * k), 0, TAU, 28, Color(col.r, col.g, col.b, 1.0 - k), 2.5, true)
			"need_special":
				var col := Color(1.0, 0.85, 0.35, 1.0 - k)
				Icons.special_rune(self, p, 12.0, col, false, false)
				draw_line(p + Vector2(-13, -13), p + Vector2(13, 13), Color(1.0, 0.35, 0.3, 1.0 - k), 3.0, true)
