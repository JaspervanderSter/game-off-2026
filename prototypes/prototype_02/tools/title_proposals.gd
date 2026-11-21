extends Node2D
## Playtest tool: four proposals for the menu's title animation, drawn with the
## game's own assets (creature tokens, journey opponents, terrain tiles, the
## shapeshift effects) and sounds. Keys 1 to 4 play a proposal from its start;
## Space replays the current one; keys 5 to 9 switch the letter style (pixel,
## blackletter preview, calligraphic preview, vector strokes, sprite pixels).
## The two previews use Windows fonts that cannot ship: an equivalent free (OFL)
## font would replace them. Run this scene on its own (F6 in the editor):
##   godot --path . res://tools/title_proposals.tscn
## The letters and their font are placeholders.

const LINE1 := "SHAPESHIFTERS"
const LINE2 := "DUEL"
const CREATURES := ["skunk", "hedgehog", "archer", "peacock", "eagle", "snake", "guardian", "cleric", "frost_mage",
	"turtle", "rabbit", "rhino", "spearman", "duelist", "wolf", "berserker", "leopard"]
const OPPONENTS := ["hunter", "druid", "@hat", "lumberjack", "swamp_witch", "archdruid", "merchant", "@wand", "innkeeper",
	"thief", "court_mage", "king", "apprentice", "caretaker", "adept", "transmutation_teacher", "archmage"]
const BLUE := Color("8cb8ff")
const RED := Color("ff7a66")
const GOLD := Color("ddba70")
const INK := Color("1a100a")
const MEDALLION_AT := 5.0 # the way to the map appears once the title stands
## 5 x 7 pixel glyphs of the title's letters (pixel and sprite styles).
const GLYPHS := {
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"I": ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
}
const STYLES := 5

var proposal := 0
var t := 0.0
var fired := {}
var font: Font
var tiles := {}
var fx: FxLayer
var letter_style := 3
## Screen behind the title: 0 the map's sky, 1 the board, 2 a starry night,
## 3 a lit table (keys Q, W, E, R).
var backdrop := 0
var sky: Node2D
const BACKDROP_KEYS := [KEY_Q, KEY_W, KEY_E, KEY_R]
var blackletter := SystemFont.new()
var calligraphic := SystemFont.new()


func _ready() -> void:
	Shapes.warm_up()
	font = ThemeDB.fallback_font
	blackletter.font_names = PackedStringArray(["Old English Text MT"])
	calligraphic.font_names = PackedStringArray(["Viner Hand ITC"])
	for env in ["forest", "town", "school"]:
		var list: Array[Texture2D] = []
		for file in DirAccess.get_files_at("res://tiles/" + env):
			if file.ends_with(".png"):
				var res = load("res://tiles/%s/%s" % [env, file])
				list.append(ImageTexture.create_from_image(res) if res is Image else res)
		tiles[env] = list
	sky = preload("res://scripts/ui/day_night_sky.gd").new()
	sky.z_index = -1
	add_child(sky)
	fx = FxLayer.new()
	add_child(fx)
	play(0)
	if "--compare-fonts" in OS.get_cmdline_user_args():
		_compare_fonts.call_deferred()


func play(index: int) -> void:
	proposal = index
	t = 0.0
	fired.clear()
	fx.items.clear()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_4:
			play(event.keycode - KEY_1)
		elif event.keycode == KEY_SPACE:
			play(proposal)
		elif event.keycode >= KEY_5 and event.keycode <= KEY_9:
			letter_style = event.keycode - KEY_5
		elif event.keycode in BACKDROP_KEYS:
			backdrop = BACKDROP_KEYS.find(event.keycode)


func _process(dt: float) -> void:
	t += dt
	_events()
	queue_redraw()


func count() -> int:
	return LINE1.length() + LINE2.length()


func ch(k: int) -> String:
	return LINE1[k] if k < LINE1.length() else LINE2[k - LINE1.length()]


func line_of(k: int) -> int:
	return 0 if k < LINE1.length() else 1


## Baseline centre of letter k.
func slot(k: int) -> Vector2:
	if k < LINE1.length():
		return Vector2(256 + k * 64, 330)
	return Vector2(520 + (k - LINE1.length()) * 80, 520)


func letter_size(k: int) -> int:
	return 78 if line_of(k) == 0 else 96


## When letter k turns from its character into a letter.
func turn_time(k: int) -> float:
	match proposal:
		0:
			return 0.75 + k * 0.2
		1:
			return 2.3 + k * 0.12
		2:
			return 0.5 + steps(k) * 0.42 + k * 0.07
		_:
			return 1.7 + k * 0.2


func steps(k: int) -> int:
	return 2 + k % 3


func _once(key: Variant, at: float) -> bool:
	if t >= at and not fired.has(key):
		fired[key] = true
		return true
	return false


func _events() -> void:
	for k in count():
		var at := slot(k) + Vector2(0, -34)
		match proposal:
			0:
				if _once("appear%d" % k, 0.15 + k * 0.2):
					Sfx.play("shapeshift/bless" if OPPONENTS[k].begins_with("@") else "ui/map_opponent_appear")
					if OPPONENTS[k].begins_with("@"):
						fx.add("shift_bless", at)
			1:
				if _once("drop%d" % k, 0.45 + k * 0.1):
					Sfx.play("ui/place")
			2:
				for j in steps(k):
					if _once("%d-%d" % [k, j], 0.5 + j * 0.42 + k * 0.07):
						fx.add("merge", at)
						Sfx.play("ui/combine")
		if not (proposal == 0 and OPPONENTS[k].begins_with("@")) and _once(k, turn_time(k)):
			var bless := line_of(k) == 0 and proposal != 0
			fx.add("shift_bless" if bless else "shift_hex", at)
			Sfx.play("shapeshift/bless" if bless else "shapeshift/hex")
	if _once("medallion", MEDALLION_AT):
		Sfx.play("ui/difficulty_unlock")


func _draw() -> void:
	sky.visible = backdrop == 0
	_backdrop()
	match proposal:
		0: _journey()
		1: _board()
		2: _chains()
		3: _duel()
	var show := smoothstep(MEDALLION_AT - 0.1, MEDALLION_AT + 0.4, t)
	if show > 0.1:
		Icons.island_medallion(self, Vector2(640, 640), 40 * show, t)
	# Which proposal plays, as pips (a development tool, not game interface).
	for i in 4:
		Shapes.circle(self, Vector2(24 + i * 22, 24), 7, GOLD if i == proposal else Color(1, 1, 1, 0.2))


## The screen behind the title.
func _backdrop() -> void:
	var size := Vector2(1280, 720)
	match backdrop:
		0:
			pass # the map's own sky cycle (the sky node)
		1:
			var list: Array = tiles["forest"]
			for y in 11:
				for x in 18:
					var tex: Texture2D = list[(x * 7 + y * 13) % list.size()]
					draw_texture_rect(tex, Rect2(Vector2(x, y) * 72.0 - Vector2(16, 36), Vector2(72, 72)), false, Color(0.62, 0.62, 0.62) if (x + y) % 2 else Color(0.55, 0.55, 0.55))
			for r in 12:
				Shapes.ellipse(self, size * 0.5, 900 - r * 40.0, 620 - r * 30.0, Color(0, 0, 0, 0.04))
		2:
			for i in 72:
				var y := size.y * i / 72.0
				draw_rect(Rect2(0, y, size.x, size.y / 72.0 + 1), Color("10142a").lerp(Color("3a2448"), i / 71.0))
			for i in 90:
				var p := Vector2(fmod(37 + i * 137.31, size.x), fmod(19 + i * 97.17, size.y))
				var a := 0.45 + 0.4 * sin(t * 1.3 + i)
				if i % 9 == 0:
					Icons.star(self, p, 4.0, Color(1, 0.9, 0.65, a))
				else:
					Shapes.circle(self, p, 1.2 + (i % 3) * 0.4, Color(0.86, 0.9, 1.0, a))
		_:
			for i in 72:
				var y := size.y * i / 72.0
				draw_rect(Rect2(0, y, size.x, size.y / 72.0 + 1), Color(0.18, 0.12, 0.08) if i % 6 < 3 else Color(0.2, 0.135, 0.09))
			for r in 14:
				Shapes.ellipse(self, Vector2(640, 380), 120 + r * 50.0, 80 + r * 30.0, Color(1.0, 0.8, 0.45, 0.035))
			for r in 10:
				Shapes.ellipse(self, Vector2(640, 380), 1500 - r * 40.0, 1000 - r * 40.0, Color(0, 0, 0, 0.05))


## Letter k, popping in, in the current letter style, with `head` drawn on top
## of it. `sprite_id` is the creature whose pixels fill the sprite style.
func _letter(k: int, fill: Color, head: Callable, sprite_id := "") -> void:
	var age := t - turn_time(k)
	if age < 0.0:
		return
	var pop := 1.0 + 0.35 * sin(minf(age / 0.3, 1.0) * PI) * exp(-age * 3.0)
	var base := slot(k)
	var size := letter_size(k)
	var height := size * 0.72
	Shapes.set_transform(self, base, 0.0, Vector2.ONE * pop)
	match letter_style:
		0:
			_pixel_letter(ch(k), height, fill, null)
		1, 2:
			var face: Font = blackletter if letter_style == 1 else calligraphic
			var w := face.get_string_size(ch(k), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			draw_string_outline(face, Vector2(-w * 0.5, 0), ch(k), HORIZONTAL_ALIGNMENT_LEFT, -1, size, 12, INK)
			draw_string(face, Vector2(-w * 0.5, 0), ch(k), HORIZONTAL_ALIGNMENT_LEFT, -1, size, fill)
		3:
			_vector_letter(ch(k), height, fill)
		_:
			var sprite := ArtStyle.creature_texture(sprite_id, line_of(k)) if sprite_id != "" else null
			_pixel_letter(ch(k), height, fill, sprite)
	Shapes.set_transform(self, Vector2.ZERO)
	head.call(base + Vector2(0, -height * 1.05 * pop - 14))


## A 5 x 7 pixel glyph standing on the origin, outlined in ink and shaded
## (lighter at the top, darker at the bottom), or filled with a sprite's pixels.
func _pixel_letter(c: String, height: float, fill: Color, sprite: Texture2D) -> void:
	var rows: Array = GLYPHS[c]
	var px := height / 7.0
	var columns: int = rows[0].length()
	var origin := Vector2(-columns * px * 0.5, -height)
	for pass_index in 2:
		for y in 7:
			for x in columns:
				if rows[y][x] != "#":
					continue
				var cell := Rect2(origin + Vector2(x, y) * px, Vector2(px, px))
				if pass_index == 0:
					draw_rect(cell.grow(4.0), INK)
				elif sprite != null:
					var size := sprite.get_size()
					var source := Rect2(size * 0.18 + Vector2(x, y) / Vector2(columns, 7) * size * 0.64,
						size * 0.64 / Vector2(columns, 7))
					draw_texture_rect_region(sprite, cell, source)
				else:
					var shade := fill.lightened(0.28) if y < 2 else (fill.darkened(0.22) if y > 4 else fill)
					draw_rect(cell, shade)
					draw_rect(Rect2(cell.position, Vector2(px, px * 0.18)), Color(1, 1, 1, 0.25))


## A letter of thick rounded strokes: an ink outline, the colour, a light core.
func _vector_letter(c: String, height: float, fill: Color) -> void:
	TitleScreen.draw_vector_letter(self, c, height, fill)


## Renders the finished title in every letter style to PNG files, then quits.
func _compare_fonts() -> void:
	set_process(false)
	play(2)
	t = 9.0
	var dir := "user://title_fonts"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(dir)
	for style in STYLES + 4:
		letter_style = style if style < STYLES else 3
		backdrop = maxi(0, style - STYLES)
		queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("style_%d.png" % style))
	get_tree().quit()


# --- 1: the journey's opponents become the letters ---------------------------------

func _journey() -> void:
	for k in count():
		var id: String = OPPONENTS[k]
		var appear := 0.15 + k * 0.2
		if t < appear:
			continue
		var base := slot(k)
		var pop := minf(1.0, (t - appear) / 0.25)
		if id == "@hat":
			Icons.wizard_hat(self, base + Vector2(0, -30), 40 * pop, 0)
		elif id == "@wand":
			Shapes.set_transform(self, base + Vector2(0, -30), -PI * 0.25, Vector2.ONE * pop)
			Icons.wand(self, Vector2.ZERO, 40)
			Shapes.set_transform(self, Vector2.ZERO)
		elif t < turn_time(k):
			# Springs out of the ground, as on the map.
			var rise := minf(1.0, (t - appear) / 0.3)
			Icons.opponent(self, id, base + Vector2(0, -28), 26 * maxf(1.0 - pow(1.0 - rise, 3), 0.05), t)
		else:
			_letter(k, GOLD.lightened(0.15), func(top: Vector2): Icons.opponent(self, id, top + Vector2(0, -4), 13, t))


# --- 2: tokens land on the board and are shapeshifted into letters ------------------

func _board() -> void:
	for k in count():
		var cell := 64.0 if line_of(k) == 0 else 80.0
		var env := "forest" if k < 5 else ("town" if k < 10 else "school")
		var list: Array = tiles[env]
		var tex: Texture2D = list[(k * 7) % list.size()]
		var center := slot(k) + Vector2(0, -30)
		draw_texture_rect(tex, Rect2(center - Vector2(cell, cell) * 0.5, Vector2(cell, cell)), false)
	for k in count():
		var team := line_of(k)
		var id: String = CREATURES[k]
		var drop := 0.1 + k * 0.1
		if t < drop:
			continue
		var center := slot(k) + Vector2(0, -30)
		if t < turn_time(k):
			var fall := minf(1.0, (t - drop) / 0.35)
			Icons.token(self, id, center + Vector2(0, (1.0 - fall * fall) * -220.0), 26 if team == 0 else 32, team)
		else:
			_letter(k, BLUE if team == 0 else RED, func(top: Vector2): Icons.token(self, id, top + Vector2(0, -4), 14, team), id)


# --- 3: every slot runs through its transformation chain ----------------------------

func _chains() -> void:
	for k in count():
		var team := line_of(k)
		if t < 0.2 + k * 0.03:
			continue
		var id: String = CREATURES[k]
		for j in steps(k):
			if t >= 0.5 + j * 0.42 + k * 0.07:
				id = CreatureDB.outcomes(id)[0].id
		if t < turn_time(k):
			Icons.token(self, id, slot(k) + Vector2(0, -30), 26 if team == 0 else 32, team)
		else:
			var final_id := id
			_letter(k, BLUE if team == 0 else RED, func(top: Vector2): Icons.token(self, final_id, top + Vector2(0, -4), 14, team), final_id)


# --- 4: a duel, the wand blessing the blues and hexing the reds ---------------------

func _duel() -> void:
	var target := -1
	for k in count():
		if t < turn_time(k):
			target = k
			break
	for k in count():
		var team := line_of(k)
		var id: String = CREATURES[k]
		var center := slot(k) + Vector2(0, -30)
		if t < turn_time(k):
			var march := smoothstep(0.0, 1.3, t - k * 0.04)
			var from := Vector2(-80, center.y) if team == 0 else Vector2(1360, center.y)
			var hop := absf(sin(t * 12.0 + k)) * 8.0 * (1.0 - march)
			Icons.token(self, id, from.lerp(center, march) + Vector2(0, -hop), 26 if team == 0 else 32, team)
		else:
			_letter(k, BLUE if team == 0 else RED, func(top: Vector2): Icons.token(self, id, top + Vector2(0, -4), 14, team), id)
	if target >= 0 and t > 1.3:
		Icons.shift_reticle(self, slot(target) + Vector2(0, -30), 34, t, line_of(target) == 0, true)
	# The wand's charges under the title, spent and refilled as it casts.
	for i in (3 if t < MEDALLION_AT else 0):
		var filled := fmod(t * 5.0, 3.0) > i or t < 1.3 or target < 0
		Icons.charge_crystal(self, Vector2(600 + i * 40, 620), 16, filled)
