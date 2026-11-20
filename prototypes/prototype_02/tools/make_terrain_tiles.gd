extends SceneTree
## Draws the terrain tiles of every environment recipe below and saves them as
## PNG files in res://tiles/<environment>/ (see Terrain for the naming rules).
## Requires a rendering device (do not use --headless), then an import:
##   godot --path prototypes/prototype_02 --minimized --script res://tools/make_terrain_tiles.gd
##   godot --path prototypes/prototype_02 --headless --import
## Every drawing is seeded, so running the tool again rewrites identical files.
## Hand-painted tiles can replace or join the generated ones: drop CELL-sized
## PNGs that follow the naming rules into the folder and import them as Image.

const SIZE := 72 # Rules.CELL
const EDGE := 7.0 # details stay this far from the tile edges (no cut-off at seams)
const CLEAR := 26.0 # ...and this far from the centre, where tokens stand

## Meadow (proposal "Prairie à brins"): two grasses for the checker, a few
## blades on every tile, clover or two tiny flowers on the rarer ones. The board
## multiplies each half by a team tint (Terrain.ENVIRONMENTS), so the base
## colours are the brightest of both halves in each channel.
const MEADOW_GRASS := {"light": Color8(147, 176, 102), "dark": Color8(137, 166, 93)}
const MEADOW_VARIANTS := {"grass": 5, "clover": 2, "flowers": 2}
const FLOWER_COLOURS := [Color8(244, 239, 220, 217), Color8(240, 216, 112, 217)]

var output_root := "res://tiles"


func _initialize() -> void:
	_export.call_deferred()


func _export() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="):
			output_root = arg.trim_prefix("--output-dir=")
	var count := 0
	var folder := ProjectSettings.globalize_path(output_root.path_join("meadow"))
	var err := DirAccess.make_dir_recursive_absolute(folder)
	if err != OK:
		push_error("Cannot create %s: %s" % [folder, error_string(err)])
		quit(1)
		return
	var seed := 1
	for family: String in MEADOW_GRASS:
		for kind: String in MEADOW_VARIANTS:
			for n in MEADOW_VARIANTS[kind]:
				var file := folder.path_join("%s-%s-%d.png" % [family, kind, n + 1])
				var image := await _render(_draw_meadow.bind(MEADOW_GRASS[family], kind, seed))
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


## Renders one tile with `painter` (a Callable taking the CanvasItem).
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


func _draw_meadow(ci: CanvasItem, grass: Color, kind: String, seed: int) -> void:
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
