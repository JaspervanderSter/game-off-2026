class_name Shapes
extends RefCounted
## Drop-in replacements for CanvasItem.draw_circle, draw_arc, draw_line,
## draw_polyline and draw_set_transform that draw textured rectangles instead
## of polygons.
##
## Godot builds a GPU vertex buffer and vertex array for every circle, arc,
## polyline, antialiased line and polygon each time a canvas item is redrawn,
## then frees them at the next redraw. On native builds this is cheap; in a
## browser each of those calls crosses the WebGL layer and the game dropped to
## 20-30 frames per second on integrated GPUs (see README, "Tests"). Rectangles
## that share one texture are batched with no per-frame buffers, so these
## helpers sample an atlas, generated once at startup, holding an antialiased
## disc, rings of several thicknesses, a line band, a star and hearts. The
## same procedural shapes are drawn, with smooth edges at every size.
##
## Arguments follow the CanvasItem methods they replace, after the canvas item.
## Lines and arcs rotate rectangles with draw_set_transform: callers that need a
## transform must set it through Shapes.set_transform so it is composed.

const CELL := 128
const RADIUS := 56.0 # texels from a cell's centre to the unit radius
const SPAN := CELL * 0.5 / RADIUS # unit radii from a cell's centre to its edge
const COLUMNS := 8
const ATLAS_FILE := "res://ui/shapes_atlas.png"

enum { DISC, BAR, STAR, HEART, HEART_LEFT, HEART_RIGHT, RING0 }
## Ring thickness as a fraction of the outer radius, one atlas cell each.
const RING_LEVELS := 16
const RING_MIN := 0.03

static var _atlas: CanvasTexture
static var _ring_t := PackedFloat32Array()
## Transform last set on each canvas item through set_transform, by instance id.
static var _transforms := {}


## The atlas, built on first use (Shapes.warm_up() builds it at startup).
static func atlas() -> CanvasTexture:
	if _atlas == null:
		_build_atlas()
	return _atlas


static func warm_up() -> void:
	atlas()


# --- Drop-in drawing -------------------------------------------------------------

## draw_circle: a filled disc, or a ring of `width` when not filled.
static func circle(ci: CanvasItem, p: Vector2, r: float, col: Color, filled := true, width := -1.0, _antialiased := false) -> void:
	if r <= 0.0:
		return
	if filled:
		_cell(ci, DISC, p, r, col)
	else:
		ring(ci, p, r, maxf(1.0, width), col)


## Ring centred on radius r (as draw_arc over a full turn).
static func ring(ci: CanvasItem, p: Vector2, r: float, width: float, col: Color) -> void:
	var outer := r + width * 0.5
	if outer <= 0.0:
		return
	var t := width / outer
	if t >= 1.0:
		_cell(ci, DISC, p, outer, col)
		return
	_cell(ci, RING0 + _ring_level(t), p, outer, col)


## draw_arc. A full turn is one ring; a partial arc is a chain of line bands.
static func arc(ci: CanvasItem, p: Vector2, r: float, from: float, to: float, point_count: int, col: Color, width := -1.0, _antialiased := false) -> void:
	var w := maxf(1.0, width)
	if absf(to - from) >= TAU - 0.001:
		ring(ci, p, r, w, col)
		return
	var steps := maxi(maxi(point_count - 1, 1), ceili(absf(to - from) / (TAU / 48.0)))
	var previous := p + Vector2.from_angle(from) * r
	for i in range(1, steps + 1):
		var point := p + Vector2.from_angle(lerpf(from, to, float(i) / steps)) * r
		_band(ci, previous, point, w, col, 0.25)
		previous = point


## draw_line. Antialiased lines become a smooth band; others stay native lines,
## which Godot batches.
static func line(ci: CanvasItem, from: Vector2, to: Vector2, col: Color, width := -1.0, antialiased := false) -> void:
	if not antialiased:
		ci.draw_line(from, to, col, width)
		return
	_band(ci, from, to, maxf(1.0, width), col, 0.0)


## draw_polyline, as a chain of smooth bands.
static func polyline(ci: CanvasItem, points: PackedVector2Array, col: Color, width := -1.0, _antialiased := false) -> void:
	var w := maxf(1.0, width)
	for i in range(1, points.size()):
		_band(ci, points[i - 1], points[i], w, col, 0.25)


## A filled ellipse of radii rx, ry rotated by `rotation`.
static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, rotation := 0.0) -> void:
	if rx <= 0.0 or ry <= 0.0:
		return
	if rotation == 0.0:
		_cell_rect(ci, DISC, Rect2(c - Vector2(rx, ry) * SPAN, Vector2(rx, ry) * 2.0 * SPAN), col)
		return
	var base := current_transform(ci)
	ci.draw_set_transform_matrix(base * Transform2D(rotation, c))
	_cell_rect(ci, DISC, Rect2(-Vector2(rx, ry) * SPAN, Vector2(rx, ry) * 2.0 * SPAN), col)
	ci.draw_set_transform_matrix(base)


## Ten-point star of outer radius r (inner radius 0.45 r).
static func star(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	if r > 0.0:
		_cell(ci, STAR, p, r, col)


## Heart of scale r (two lobes and a point, as Icons.heart), or one half of it
## (side 0 left, 1 right).
static func heart(ci: CanvasItem, p: Vector2, r: float, col: Color, side := -1) -> void:
	if r > 0.0:
		_cell(ci, HEART if side < 0 else (HEART_LEFT if side == 0 else HEART_RIGHT), p, r, col)


## draw_set_transform that later Shapes calls compose with.
static func set_transform(ci: CanvasItem, position: Vector2, rotation := 0.0, scale := Vector2.ONE) -> void:
	var xform := Transform2D(rotation, scale, 0.0, position)
	if xform == Transform2D.IDENTITY:
		_transforms.erase(ci.get_instance_id())
	else:
		_transforms[ci.get_instance_id()] = xform
	ci.draw_set_transform_matrix(xform)


static func current_transform(ci: CanvasItem) -> Transform2D:
	return _transforms.get(ci.get_instance_id(), Transform2D.IDENTITY)


# --- Internals -------------------------------------------------------------------

static func _cell(ci: CanvasItem, index: int, p: Vector2, r: float, col: Color) -> void:
	_cell_rect(ci, index, Rect2(p - Vector2(r, r) * SPAN, Vector2(r, r) * 2.0 * SPAN), col)


static func _cell_rect(ci: CanvasItem, index: int, rect: Rect2, col: Color) -> void:
	var src := Rect2((index % COLUMNS) * CELL, (index / COLUMNS) * CELL, CELL, CELL)
	ci.draw_texture_rect_region(atlas(), rect, src, col)


## A straight band of `width` from a to b, its ends cut square and lengthened
## by `overlap` pixels so consecutive bands meet without seams.
static func _band(ci: CanvasItem, a: Vector2, b: Vector2, width: float, col: Color, overlap: float) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.001:
		return
	var base := current_transform(ci)
	ci.draw_set_transform_matrix(base * Transform2D(d.angle(), a))
	# The band's rows span the unit radius; its columns are uniform, so a
	# narrow strip in the middle of the cell avoids its neighbours.
	var src := Rect2((BAR % COLUMNS) * CELL + CELL * 0.25, (BAR / COLUMNS) * CELL + CELL * 0.5 - RADIUS, CELL * 0.5, RADIUS * 2.0)
	ci.draw_texture_rect_region(atlas(), Rect2(-overlap, -width * 0.5, length + overlap * 2.0, width), src, col)
	ci.draw_set_transform_matrix(base)


static func _ring_level(t: float) -> int:
	if _ring_t.is_empty():
		_build_ring_levels()
	var best := 0
	for i in RING_LEVELS:
		if absf(log(_ring_t[i] / t)) < absf(log(_ring_t[best] / t)):
			best = i
	return best


static func _build_ring_levels() -> void:
	_ring_t.resize(RING_LEVELS)
	for i in RING_LEVELS:
		# Geometric steps from RING_MIN to 0.85 of the outer radius.
		_ring_t[i] = RING_MIN * pow(0.85 / RING_MIN, float(i) / (RING_LEVELS - 1))


## The atlas image as drawn by code (no mipmaps). tools/make_shapes_atlas.gd
## saves it to ATLAS_FILE; the tests check that the saved file still matches.
static func build_image() -> Image:
	_build_ring_levels()
	var count := RING0 + RING_LEVELS
	var rows := ceili(float(count) / COLUMNS)
	var width := COLUMNS * CELL
	var height := rows * CELL
	# Transparent texels stay white so filtering never darkens edges.
	var blank := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	blank.fill(Color(1, 1, 1, 0))
	var data := blank.get_data()
	var star_pts := PackedVector2Array()
	for i in 10:
		star_pts.append(Vector2.from_angle(-PI / 2 + TAU * i / 10.0) * (1.0 if i % 2 == 0 else 0.45))
	var heart_tri := PackedVector2Array([Vector2(-0.93, 0.0), Vector2(0.93, 0.0), Vector2(0, 0.95)])
	var halves: Array[PackedVector2Array] = []
	for side in 2:
		var pts := PackedVector2Array()
		for i in 16:
			var angle := lerpf(-0.45, -3.55, i / 15.0)
			var x := -0.45 + cos(angle) * 0.5
			pts.append(Vector2(x if side == 0 else -x, -0.2 + sin(angle) * 0.5))
		pts.append(Vector2(0, 0.95))
		halves.append(pts)
	var texel := 1.0 / RADIUS
	for index in count:
		var ox := (index % COLUMNS) * CELL
		var oy := (index / COLUMNS) * CELL
		for y in CELL:
			var v := (y + 0.5 - CELL * 0.5) / RADIUS
			for x in CELL:
				var u := Vector2((x + 0.5 - CELL * 0.5) / RADIUS, v)
				var d := 0.0
				match index:
					DISC:
						d = u.length() - 1.0
					BAR:
						# Rows across the band; columns stop short of the neighbouring cells.
						d = maxf(absf(v), absf(u.x)) - 1.0
					STAR:
						d = _polygon_distance(u, star_pts)
					HEART:
						d = minf(minf((u - Vector2(-0.45, -0.2)).length() - 0.5, (u - Vector2(0.45, -0.2)).length() - 0.5),
							_polygon_distance(u, heart_tri))
					HEART_LEFT, HEART_RIGHT:
						d = _polygon_distance(u, halves[index - HEART_LEFT])
					_:
						var inner := 1.0 - _ring_t[index - RING0]
						d = maxf(u.length() - 1.0, inner - u.length())
				var alpha := clampf(0.5 - d / texel, 0.0, 1.0)
				if alpha > 0.0:
					data[((oy + y) * width + ox + x) * 4 + 3] = int(alpha * 255.0 + 0.5)
	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)


## Loads the saved atlas (imported with mipmaps); draws it if the file is missing.
static func _build_atlas() -> void:
	_build_ring_levels()
	var texture: Texture2D = load(ATLAS_FILE) if ResourceLoader.exists(ATLAS_FILE) else null
	if texture == null:
		push_warning("%s missing: drawing the shape atlas at startup" % ATLAS_FILE)
		var image := build_image()
		image.generate_mipmaps()
		texture = ImageTexture.create_from_image(image)
	_atlas = CanvasTexture.new()
	_atlas.diffuse_texture = texture
	_atlas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## Signed distance from u to a closed polygon (negative inside).
static func _polygon_distance(u: Vector2, pts: PackedVector2Array) -> float:
	var n := pts.size()
	var d := (u - pts[0]).length_squared()
	var s := 1.0
	var j := n - 1
	for i in n:
		var e := pts[j] - pts[i]
		var w := u - pts[i]
		var b := w - e * clampf(w.dot(e) / e.length_squared(), 0.0, 1.0)
		d = minf(d, b.length_squared())
		var c1 := u.y >= pts[i].y
		var c2 := u.y < pts[j].y
		var c3 := e.x * w.y > e.y * w.x
		if (c1 and c2 and c3) or (not c1 and not c2 and not c3):
			s = -s
		j = i
	return s * sqrt(d)
