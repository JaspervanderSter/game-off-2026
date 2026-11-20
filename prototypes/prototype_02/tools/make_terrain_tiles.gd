extends SceneTree
## Draws the terrain tiles of every environment recipe below and saves them as
## PNG files in res://tiles/<environment>/ (see Terrain for the naming rules).
## Requires a rendering device (do not use --headless), then an import:
##   godot --path prototypes/prototype_02 --minimized --script res://tools/make_terrain_tiles.gd
##   godot --path prototypes/prototype_02 --headless --import
## Every drawing is seeded, so running the tool again rewrites identical files.
## Hand-painted tiles can replace or join the generated ones: drop CELL-sized
## PNGs that follow the naming rules into the folder and import them as Image.
##
## The board multiplies each half by a team tint (Terrain.ENVIRONMENTS), so the
## base colours below are the brightest of both halves in each channel.

const SIZE := 72 # Rules.CELL
const EDGE := 7.0 # details stay this far from the tile edges (no cut-off at seams)
const CLEAR := 26.0 # ...and this far from the centre, where tokens stand
const GOLD := Color8(207, 174, 92)

## Per environment: the painter, the base colour of each checker family and
## the number of drawings of each kind (per family).
const RECIPES := {
	# Forest: two grasses, a few blades on every tile, clover or two tiny
	# flowers on the rarer ones.
	"forest": {
		"painter": "_draw_forest",
		"families": {"light": Color8(147, 176, 102), "dark": Color8(137, 166, 93)},
		"kinds": {"grass": 5, "clover": 2, "flowers": 2},
	},
	# Medieval town: desaturated stones of all sizes, softened joints, no decoration.
	"town": {
		"painter": "_draw_town",
		"families": {"light": Color8(183, 174, 167), "dark": Color8(171, 163, 156)},
		"kinds": {"stone": 6},
	},
	# Magic school: slate slabs alternating a chamfered double gold fillet
	# (light) and a quiet engraved slab with gold studs (dark).
	"school": {
		"painter": "_draw_school",
		"families": {"light": Color8(171, 164, 181), "dark": Color8(160, 153, 171)},
		"kinds": {"slab": 5},
	},
}
const FLOWER_COLOURS := [Color8(244, 239, 220, 217), Color8(240, 216, 112, 217)]

var output_root := "res://tiles"


func _initialize() -> void:
	_export.call_deferred()


func _export() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="):
			output_root = arg.trim_prefix("--output-dir=")
	var count := 0
	for environment: String in RECIPES:
		var recipe: Dictionary = RECIPES[environment]
		var folder := ProjectSettings.globalize_path(output_root.path_join(environment))
		var err := DirAccess.make_dir_recursive_absolute(folder)
		if err != OK:
			push_error("Cannot create %s: %s" % [folder, error_string(err)])
			quit(1)
			return
		var painter := Callable(self, recipe.painter)
		var seed := 1
		for family: String in recipe.families:
			for kind: String in recipe.kinds:
				for n in recipe.kinds[kind]:
					var file := folder.path_join("%s-%s-%d.png" % [family, kind, n + 1])
					var image := await _render(painter.bind(recipe.families[family], family, kind, seed))
					seed += 1
					err = image.save_png(file)
					if err != OK:
						push_error("Cannot save %s: %s" % [file, error_string(err)])
						quit(1)
						return
					_ensure_image_import(file)
					count += 1
	print("Drew %d terrain tiles in %s" % [count, ProjectSettings.globalize_path(output_root)])
	quit()


## Renders one tile with `painter` (a Callable taking the CanvasItem first).
func _render(painter: Callable) -> Image:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := Node2D.new()
	viewport.add_child(canvas)
	canvas.draw.connect(painter.bind(canvas))
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	image.convert(Image.FORMAT_RGB8)
	return image


## A new tile is imported as an Image (not a texture), so Terrain can compose
## the board from its pixels; the import keeps an existing file's settings.
func _ensure_image_import(file: String) -> void:
	var import_file := file + ".import"
	if FileAccess.file_exists(import_file):
		return
	var f := FileAccess.open(import_file, FileAccess.WRITE)
	f.store_string("[remap]\n\nimporter=\"image\"\ntype=\"Image\"\n")


func _draw_forest(ci: CanvasItem, grass: Color, _family: String, kind: String, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	ci.draw_rect(Rect2(0, 0, SIZE, SIZE), grass)
	var blade := Color(grass.darkened(0.18), 0.6)
	for i in 4:
		var p := _detail_spot(rng, 4.0)
		ci.draw_line(p + Vector2(-2.5, 2), p + Vector2(-1, -3), blade, 1.4, true)
		ci.draw_line(p + Vector2(1, 2), p + Vector2(2, -3.5), blade, 1.4, true)
	if kind == "clover":
		var leaf := grass.darkened(0.12)
		for i in 2:
			var c := _detail_spot(rng, 5.0)
			for offset: Vector2 in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2.5)]:
				ci.draw_circle(c + offset, 1.8, leaf, true, -1.0, true)
	elif kind == "flowers":
		var f := _detail_spot(rng, 4.0) - Vector2(2.5, 1.5) # the pair spans 5 x 3 px
		ci.draw_circle(f, 1.8, FLOWER_COLOURS[0], true, -1.0, true)
		ci.draw_circle(f + Vector2(5, 3), 1.6, FLOWER_COLOURS[1], true, -1.0, true)


## Stones of all sizes: the tile is split again and again into rectangles,
## each a stone with rounded corners and its own faint tone. The joints are
## only 7% darker than the stone.
func _draw_town(ci: CanvasItem, stone: Color, _family: String, _kind: String, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	ci.draw_rect(Rect2(0, 0, SIZE, SIZE), _shade(stone, 0.93))
	var stones: Array[Rect2] = []
	_split_stones(rng, Rect2(0, 0, SIZE, SIZE), 0, stones)
	for r in stones:
		_rounded_rect(ci, r.grow(-0.9), 3.0, _shade(stone, 1.0 + (rng.randf() - 0.5) * 0.05))


func _split_stones(rng: RandomNumberGenerator, r: Rect2, depth: int, out: Array[Rect2]) -> void:
	var w := r.size.x
	var h := r.size.y
	if (w < 34 and h < 34 and rng.randf() < 0.6) or (w < 20 and h < 20) or depth > 4:
		out.append(r)
		return
	if w >= h:
		var c := roundf(w * (0.35 + rng.randf() * 0.3))
		_split_stones(rng, Rect2(r.position, Vector2(c, h)), depth + 1, out)
		_split_stones(rng, Rect2(r.position + Vector2(c, 0), Vector2(w - c, h)), depth + 1, out)
	else:
		var c := roundf(h * (0.35 + rng.randf() * 0.3))
		_split_stones(rng, Rect2(r.position, Vector2(w, c)), depth + 1, out)
		_split_stones(rng, Rect2(r.position + Vector2(0, c), Vector2(w, h - c)), depth + 1, out)


## One slab per tile. Light family: a chamfered gold fillet doubled by a fine
## engraving, a gold stud in each corner. Dark family: a quiet engraved square
## and four gold studs. Nothing near the centre, where tokens stand.
func _draw_school(ci: CanvasItem, slab: Color, family: String, _kind: String, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var tone := _shade(slab, 1.0 + (rng.randf() - 0.5) * 0.03)
	ci.draw_rect(Rect2(0, 0, SIZE, SIZE), _shade(tone, 0.86))
	_rounded_rect(ci, Rect2(1.5, 1.5, SIZE - 3, SIZE - 3), 1.5, tone)
	if family == "light":
		ci.draw_polyline(_octagon(6.0, 8.0), Color(GOLD, 0.6), 1.1, true)
		ci.draw_polyline(_octagon(9.5, 8.0), Color(_shade(tone, 0.8), 0.85), 0.8, true)
		for c in _corners(4.5):
			ci.draw_circle(c, 1.4, Color(GOLD, 0.7), true, -1.0, true)
	else:
		var i := 10.5
		ci.draw_polyline(PackedVector2Array([Vector2(i, i), Vector2(SIZE - i, i), Vector2(SIZE - i, SIZE - i),
			Vector2(i, SIZE - i), Vector2(i, i)]), _shade(tone, 0.84), 0.9, true)
		for c in _corners(5.0):
			ci.draw_circle(c, 1.6, Color(GOLD, 0.75), true, -1.0, true)


## Closed octagon inset by `inset` with corners cut by `cut`.
func _octagon(inset: float, cut: float) -> PackedVector2Array:
	var a := inset
	var b := SIZE - inset
	return PackedVector2Array([Vector2(a + cut, a), Vector2(b - cut, a), Vector2(b, a + cut), Vector2(b, b - cut),
		Vector2(b - cut, b), Vector2(a + cut, b), Vector2(a, b - cut), Vector2(a, a + cut), Vector2(a + cut, a)])


func _corners(inset: float) -> Array[Vector2]:
	return [Vector2(inset, inset), Vector2(SIZE - inset, inset), Vector2(inset, SIZE - inset), Vector2(SIZE - inset, SIZE - inset)]


func _rounded_rect(ci: CanvasItem, r: Rect2, radius: float, colour: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.set_corner_radius_all(int(ceilf(radius)))
	box.anti_aliasing = true
	box.anti_aliasing_size = 0.6
	ci.draw_style_box(box, r)


static func _shade(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


## A random point at least `margin` inside the edge margin (the detail's
## reach) and outside the token area in the middle of the tile.
func _detail_spot(rng: RandomNumberGenerator, margin: float) -> Vector2:
	var centre := Vector2(SIZE, SIZE) * 0.5
	var low := EDGE + margin
	var high := SIZE - EDGE - margin
	for attempt in 1000:
		var p := Vector2(rng.randf_range(low, high), rng.randf_range(low, high))
		if p.distance_to(centre) > CLEAR:
			return p
	push_error("No room for a detail %.0f px from the edges." % margin)
	return Vector2(low, low)
