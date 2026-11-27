class_name Terrain
extends RefCounted
## Battlefield environments, assembled cell by cell from whole-zone tiles.
##
## An environment is a folder res://tiles/<id>/ of CELL-sized PNG tiles named
## <family>-<kind>-<n>.png:
## - family follows the board checker: "light" where x + y is even, "dark"
##   elsewhere. An environment without dark tiles uses its light ones everywhere.
## - kind sets how often a tile appears (relative weights in ENVIRONMENTS). The
##   commonest kind is the plain ground; two cells touching each other never
##   share a rarer kind, so details stay sparse.
## - n numbers interchangeable drawings of a kind. Cells of the same family that
##   touch (diagonally, or two apart) never repeat the same drawing, provided
##   the commonest kind has at least five drawings per family.
## The tiles are scenery only: they never affect the rules.
##
## Tiles are imported as Image resources, not textures: the board is composed
## once into a single image (see board_image, cached by board_texture) and
## drawn with one call per half, each half multiplied by its team tint. tools/make_terrain_tiles.gd draws the
## generated tiles; hand-painted ones can join them.

const TILE_DIR := "res://tiles"
const DEFAULT := "forest"
## In the order the hidden Ctrl+Shift+T switch cycles through them.
const ENVIRONMENTS := {
	"forest": {
		"kinds": {"grass": 0.72, "clover": 0.2, "flowers": 0.08},
		# Player half (team 0), enemy half (team 1).
		"tints": [Color(0.937, 1.0, 1.0), Color(1.0, 0.988, 0.96)],
		"midline": Color(0.31, 0.42, 0.21, 0.8),
	},
	"town": {
		"kinds": {"stone": 1.0},
		"tints": [Color(0.961, 0.99, 1.0), Color(1.0, 1.0, 0.96)],
		"midline": Color(0.49, 0.467, 0.431, 0.9),
	},
	"school": {
		"kinds": {"slab": 1.0},
		"tints": [Color(0.961, 0.99, 1.0), Color(1.0, 1.0, 0.96)],
		"midline": Color(0.36, 0.33, 0.44, 0.9),
	},
}

static var _catalogue := {} # environment -> {family -> {kind -> [paths]}}
static var _boards := {} # "environment:seed" -> composed board texture


## {family: {kind: [tile paths]}} found in the environment's folder.
static func tiles(environment: String) -> Dictionary:
	if _catalogue.has(environment):
		return _catalogue[environment]
	var found := {}
	var dir := TILE_DIR.path_join(environment)
	if DirAccess.dir_exists_absolute(dir):
		var files := DirAccess.get_files_at(dir)
		files.sort()
		for file in files:
			# Exported games list the import files instead of the images.
			file = file.trim_suffix(".import").trim_suffix(".remap")
			if file.get_extension().to_lower() != "png":
				continue
			var parts := file.get_basename().split("-")
			if parts.size() != 3:
				push_warning("Terrain tile %s does not follow <family>-<kind>-<n>.png." % file)
				continue
			var kinds: Dictionary = found.get_or_add(parts[0], {})
			var paths: Array = kinds.get_or_add(parts[1], [])
			var path := dir.path_join(file)
			if not paths.has(path):
				paths.append(path)
	_catalogue[environment] = found
	return found


## The tile path of every cell, as rows: layout(...)[y][x]. Deterministic for
## an environment and a seed.
static func layout(environment: String, seed: int, cols := Rules.COLS, rows := Rules.ROWS) -> Array:
	var set := tiles(environment)
	var weights: Dictionary = ENVIRONMENTS.get(environment, {}).get("kinds", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var grid := []
	var kind_of := {} # Vector2i -> kind
	for y in rows:
		var row: Array[String] = []
		for x in cols:
			var family := "light" if (x + y) % 2 == 0 or not set.has("dark") else "dark"
			var kinds: Dictionary = set.get(family, {})
			if kinds.is_empty():
				row.append("")
				continue
			var plain := _commonest(kinds, weights)
			var kind := _pick_kind(rng, kinds, weights)
			if kind != plain:
				for n in [Vector2i(x - 1, y), Vector2i(x - 1, y - 1), Vector2i(x, y - 1), Vector2i(x + 1, y - 1)]:
					if kind_of.get(n, "") == kind:
						kind = plain
						break
			var taken := [] # drawings on same-family cells this one touches
			for n in [Vector2i(x - 1, y - 1), Vector2i(x + 1, y - 1), Vector2i(x - 2, y), Vector2i(x, y - 2)]:
				if n.y >= 0 and n.x >= 0 and n.x < cols:
					taken.append(grid[n.y][n.x] if n.y < y else row[n.x])
			var choices := (kinds[kind] as Array).filter(func(path): return not taken.has(path))
			if choices.is_empty() and kind != plain:
				kind = plain # every drawing of the rarer kind is next door
				choices = (kinds[kind] as Array).filter(func(path): return not taken.has(path))
			if choices.is_empty():
				choices = kinds[kind] # fewer than five plain drawings: a repeat is unavoidable
			kind_of[Vector2i(x, y)] = kind
			row.append(choices[rng.randi_range(0, choices.size() - 1)])
		grid.append(row)
	return grid


## The whole board as one image, BOARD_SIZE pixels, untinted.
static func board_image(environment: String, seed: int) -> Image:
	var size := Vector2i(Rules.BOARD_SIZE)
	var board := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var cell := int(Rules.CELL)
	var grid := layout(environment, seed)
	var loaded := {} # path -> Image: a board repeats a dozen drawings over 48 cells
	for y in grid.size():
		for x in grid[y].size():
			var path: String = grid[y][x]
			if not loaded.has(path):
				loaded[path] = _tile_image(path)
			var tile: Image = loaded[path]
			if tile == null:
				continue
			board.blit_rect(tile, Rect2i(Vector2i.ZERO, Vector2i(cell, cell)), Vector2i(x, y) * cell)
	return board


## The board as a texture, composed once per environment and seed. Composing
## takes tens of milliseconds on Web, enough to break up the music in the
## frame that opens a duel, so warm_up composes every board while loading.
static func board_texture(environment: String, seed: int) -> Texture2D:
	var key := "%s:%d" % [environment, seed]
	if not _boards.has(key):
		_boards[key] = ImageTexture.create_from_image(board_image(environment, seed))
	return _boards[key]


## Composes every environment's board now rather than when a duel opens.
static func warm_up(seed: int) -> void:
	for environment: String in ENVIRONMENTS:
		board_texture(environment, seed)


## Draws an environment's board on `ci` with its top-left corner at the origin:
## tinted halves, then the midline.
static func draw_board(ci: CanvasItem, texture: Texture2D, environment: String) -> void:
	var look: Dictionary = ENVIRONMENTS.get(environment, ENVIRONMENTS[DEFAULT])
	var half := Vector2(Rules.BOARD_SIZE.x, Rules.BOARD_SIZE.y * 0.5)
	var enemy := Rect2(Vector2.ZERO, half)
	var player := Rect2(Vector2(0, half.y), half)
	ci.draw_texture_rect_region(texture, enemy, enemy, look.tints[1])
	ci.draw_texture_rect_region(texture, player, player, look.tints[0])
	Shapes.line(ci, Vector2(0, half.y), Vector2(half.x, half.y), look.midline, 2.0)


static func _tile_image(path: String) -> Image:
	if path == "":
		return null
	var resource := load(path)
	var image: Image = null
	if resource is Image:
		image = resource
	elif resource is Texture2D: # imported as a texture by mistake
		image = resource.get_image()
	if image == null:
		push_warning("Terrain tile %s could not be loaded." % path)
		return null
	image = image.duplicate()
	image.convert(Image.FORMAT_RGBA8)
	return image


static func _commonest(kinds: Dictionary, weights: Dictionary) -> String:
	var best := ""
	for kind: String in kinds:
		if best == "" or weights.get(kind, 0.0) > weights.get(best, 0.0):
			best = kind
	return best


static func _pick_kind(rng: RandomNumberGenerator, kinds: Dictionary, weights: Dictionary) -> String:
	var total := 0.0
	for kind: String in kinds:
		total += weights.get(kind, 0.0)
	if total <= 0.0:
		return _commonest(kinds, weights)
	var roll := rng.randf() * total
	for kind: String in kinds:
		roll -= weights.get(kind, 0.0)
		if roll < 0.0:
			return kind
	return _commonest(kinds, weights)
