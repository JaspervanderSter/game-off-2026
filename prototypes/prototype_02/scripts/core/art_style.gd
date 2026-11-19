class_name ArtStyle
extends RefCounted
## Chooses between the two art styles the game can draw.
##
## VECTOR (the default) is the procedural art in Icons. PIXEL draws the pixel
## art sprites found under res://sprites/ and falls back to the vector art for
## everything that has no sprite yet, so the game stays complete while the
## pixel art is in progress. The choice is toggled in game (see main.gd) and
## survives restarts through `save_path`.
##
## Sprite files keep the artist's names: <Name>-A.png is the red team (team 1),
## <Name>-B.png the blue team (team 0), in any folder under res://sprites/.
## <Name> is the creature id in PascalCase (frost_mage -> FrostMage) unless
## FILE_NAMES says otherwise. Each sprite is a full token: a team disc of
## DISC_RADIUS pixels centred in the image, with the creature on it.

enum Style { VECTOR, PIXEL }

const SPRITE_DIR := "res://sprites"
## Creature ids whose sprite name is not the id in PascalCase.
const FILE_NAMES := {"crossbowman": "Crossbow"}
## File suffix per team: team 0 (player, blue) is B, team 1 (enemy, red) is A.
const TEAM_SUFFIX := ["B", "A"]
## Radius in pixels of the team disc painted in the sprites.
const DISC_RADIUS := 24.0
## Draw scales this close to a whole number snap to it, keeping pixels crisp.
const SNAP_TOLERANCE := 0.08

static var save_path := "user://art_style.cfg"
static var _style := -1 # -1 until loaded from save_path
static var _paths := {} # "Archer-A" -> "res://sprites/humans/Archer-A.png"
static var _scanned := false
static var _textures := {} # path -> CanvasTexture


static func current() -> Style:
	if _style < 0:
		var config := ConfigFile.new()
		_style = Style.VECTOR
		if config.load(save_path) == OK and config.get_value("art", "style", "vector") == "pixel":
			_style = Style.PIXEL
	return _style as Style


static func is_pixel() -> bool:
	return current() == Style.PIXEL


static func set_style(style: Style) -> void:
	_style = style
	var config := ConfigFile.new()
	config.set_value("art", "style", "pixel" if style == Style.PIXEL else "vector")
	var error := config.save(save_path)
	if error != OK:
		push_warning("Could not save the art style to %s (error %d)." % [save_path, error])


static func toggle() -> Style:
	set_style(Style.VECTOR if is_pixel() else Style.PIXEL)
	return current()


## Forgets the loaded choice and sprites: the next calls read save_path and
## res://sprites/ again. Also releases the sprites before the game exits.
static func reload() -> void:
	_style = -1
	_paths.clear()
	_scanned = false
	_textures.clear()


## Sprite file name (without extension) for a creature of a team.
static func sprite_name(id: String, team: int) -> String:
	return "%s-%s" % [FILE_NAMES.get(id, id.to_pascal_case()), TEAM_SUFFIX[team]]


## Whether a pixel art sprite exists for this creature, whatever the style.
static func has_sprite(id: String, team: int) -> bool:
	_scan()
	return _paths.has(sprite_name(id, team))


## The sprite to draw for a creature, or null when the vector art applies
## (vector style, or no sprite for this creature yet).
static func creature_texture(id: String, team: int) -> Texture2D:
	if not is_pixel():
		return null
	_scan()
	var path: String = _paths.get(sprite_name(id, team), "")
	if path == "":
		return null
	if not _textures.has(path):
		var image := load(path) as Texture2D
		if image == null:
			_textures[path] = null
		else:
			# Nearest filtering whatever the drawing node uses.
			var texture := CanvasTexture.new()
			texture.diffuse_texture = image
			texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_textures[path] = texture
	return _textures[path]


## Draws a sprite token with its team disc of radius r centred on p.
static func draw_token(ci: CanvasItem, texture: Texture2D, p: Vector2, r: float) -> void:
	var size := texture.get_size()
	var k := r / DISC_RADIUS
	if k >= 1.0 - SNAP_TOLERANCE and absf(k - roundf(k)) <= SNAP_TOLERANCE:
		k = roundf(k)
		p = p.round()
	ci.draw_texture_rect(texture, Rect2(p - size * k * 0.5, size * k), false)


static func _scan() -> void:
	if _scanned:
		return
	_scanned = true
	_scan_dir(SPRITE_DIR)


static func _scan_dir(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub in DirAccess.get_directories_at(dir):
		_scan_dir(dir.path_join(sub))
	for file in DirAccess.get_files_at(dir):
		# Exported games list the import files instead of the images.
		file = file.trim_suffix(".import").trim_suffix(".remap")
		if file.get_extension().to_lower() == "png":
			_paths[file.get_basename()] = dir.path_join(file)
