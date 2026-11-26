class_name Cursors
extends RefCounted
## The game's six mouse cursors, 32x32 pixel art validated on 26 November 2026
## (docs/design/Art Direction.md, "Mouse cursors"). They replace six of the system cursor shapes, so
## any Control keeps working through its usual cursor shape, and a platform
## that refuses custom images falls back to the matching system cursor. The
## Web export hands them to the browser as CSS cursors, kept at 32 pixels so
## browsers accept them everywhere on the page.
##
##   NORMAL       the wand at rest, everywhere nothing reacts
##   CLICK        the wand lit with sparks, over anything that reacts to a click
##   GRAB         an open hand, over a creature that can be dragged
##   HOLD         a closed hand, while a creature is dragged
##   CAST         the wand casting, over a creature the spell can reach now
##   UNAVAILABLE  the wand greyed, over a target the spell cannot reach yet
##                (no charge, or the creature is still immune)
##
## The spell is the same on allies and enemies, so CAST is one cursor for both.

const NORMAL := Input.CURSOR_ARROW
const CLICK := Input.CURSOR_POINTING_HAND
const GRAB := Input.CURSOR_MOVE
const HOLD := Input.CURSOR_DRAG
const CAST := Input.CURSOR_CROSS
const UNAVAILABLE := Input.CURSOR_FORBIDDEN
const SHAPES: Array[int] = [NORMAL, CLICK, GRAB, HOLD, CAST, UNAVAILABLE]

const SIZE := 32
const OUTLINE := Color("1b1026")
## The wand's star, where the wand cursors click.
const TIP := Vector2i(7, 7)
## The middle of the palm, where both hands click, so grabbing does not jump.
const PALM := Vector2i(17, 17)

const MAGIC := Color("b86bff")
const GOLD := Color("ffd140")
const PALE := Color("e6ccff")
const SKIN := Color("f2c9a0")
const SKIN_SHADE := Color("c98f6a")
const SLEEVE := Color("5a3a8c")
const SLEEVE_TRIM := Color("ddba70")

const WANDS := {
	"normal": {"core": Color("8c5933"), "hi": Color("b07a48"), "grip": Color("5e3a22"), "band": Color("ddba70"),
		"arm": Color("8e52c9"), "block": Color("b986ef"), "center": PALE, "arms": 1},
	"click": {"core": Color("8c5933"), "hi": Color("b07a48"), "grip": Color("5e3a22"), "band": GOLD,
		"arm": MAGIC, "block": PALE, "center": Color.WHITE, "arms": 2},
	"cast": {"core": Color("8c5933"), "hi": Color("b07a48"), "grip": Color("5e3a22"), "band": GOLD,
		"arm": MAGIC, "block": PALE, "center": Color.WHITE, "arms": 3},
	"off": {"core": Color("6e6258"), "hi": Color("857a70"), "grip": Color("4e4540"), "band": Color("8a8478"),
		"arm": Color("4f4859"), "block": Color("6a6276"), "center": Color("7f778c"), "arms": 1},
}

const SIDES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## Replaces the system cursor shapes with the game's cursors.
static func install() -> void:
	for shape in SHAPES:
		Input.set_custom_mouse_cursor(ImageTexture.create_from_image(image(shape)), shape, hotspot(shape))


## Shows `shape` wherever no Control sets its own cursor (Godot only acts on a change).
static func show(shape: int) -> void:
	Input.set_default_cursor_shape(shape)


static func hotspot(shape: int) -> Vector2:
	return Vector2(PALM) if shape == GRAB or shape == HOLD else Vector2(TIP)


static func image(shape: int) -> Image:
	match shape:
		CLICK:
			return _wand("click")
		GRAB:
			return _open_hand()
		HOLD:
			return _fist()
		CAST:
			return _wand("cast")
		UNAVAILABLE:
			return _wand("off")
	return _wand("normal")


## A diagonal wand, its star at TIP and its dark grip at the bottom right.
static func _wand(state: String) -> Image:
	var p: Dictionary = WANDS[state]
	var img := _blank()
	for i in range(11, 28):
		var band := i <= 12
		var grip := i >= 23
		_put(img, i, i, p.band if band else (p.grip if grip else p.core))
		_put(img, i + 1, i, p.band if band else (p.grip if grip else p.hi))
	for y in range(-1, 2):
		for x in range(-1, 2):
			_put(img, TIP.x + x, TIP.y + y, p.block)
	for k in range(2, 2 + int(p.arms)):
		for side in SIDES:
			_put(img, TIP.x + side.x * k, TIP.y + side.y * k, p.arm)
	_put(img, TIP.x, TIP.y, p.center)
	if state == "click" or state == "cast":
		for side in SIDES:
			_put(img, TIP.x + side.x, TIP.y + side.y, p.center)
	_outline(img)
	if state == "click":
		_put(img, TIP.x + 5, TIP.y - 4, GOLD)
		_put(img, TIP.x - 4, TIP.y + 5, GOLD)
		_put(img, TIP.x - 4, TIP.y - 4, PALE)
	elif state == "cast":
		# A dashed aiming ring around the star, broken where the wand passes.
		for a in range(0, 360, 3):
			if floori(a / 30.0) % 2 == 1:
				continue
			var x := TIP.x + roundi(cos(deg_to_rad(a)) * 7.0)
			var y := TIP.y + roundi(sin(deg_to_rad(a)) * 7.0)
			if _inside(x, y) and img.get_pixel(x, y).a == 0.0:
				img.set_pixel(x, y, MAGIC)
		_put(img, TIP.x + 5, TIP.y - 5, GOLD)
		_put(img, TIP.x - 5, TIP.y + 5, GOLD)
	return img


## A closed hand from above, its four curled fingers on top, over a sleeve.
static func _fist() -> Image:
	var img := _blank()
	var o := Vector2i(8, 6)
	for y in range(7, 16):
		for x in range(3, 16):
			if y == 15 and (x == 3 or x == 15):
				continue
			_put(img, o.x + x, o.y + y, SKIN)
	for k in 4:
		var x0 := 3 + 3 * k
		for y in range(4, 8):
			for x in range(x0, x0 + 3):
				if y == 4 and (x == x0 or x == x0 + 2):
					continue
				_put(img, o.x + x, o.y + y, SKIN)
		for y in range(6, 8):
			_put(img, o.x + x0 + 2, o.y + y, SKIN_SHADE)
	for x in range(3, 11):
		_put(img, o.x + x, o.y + 9, SKIN)
		_put(img, o.x + x, o.y + 11, SKIN_SHADE)
	_put(img, o.x + 11, o.y + 9, SKIN_SHADE)
	_put(img, o.x + 11, o.y + 10, SKIN_SHADE)
	_sleeve(img, o, 16)
	_outline(img)
	return img


## An open hand, four fingers up and the thumb aside, over the same sleeve.
static func _open_hand() -> Image:
	var img := _blank()
	var o := Vector2i(8, 5)
	for y in range(9, 17):
		for x in range(4, 15):
			if y == 16 and (x == 4 or x == 14):
				continue
			_put(img, o.x + x, o.y + y, SKIN)
	var tops := [3, 1, 1, 3]
	for k in 4:
		var x0: int = [4, 7, 10, 13][k]
		for y in range(tops[k], 10):
			_put(img, o.x + x0, o.y + y, SKIN)
			_put(img, o.x + x0 + 1, o.y + y, SKIN_SHADE if y >= 8 else SKIN)
	for p in [Vector2i(3, 13), Vector2i(2, 13), Vector2i(2, 12), Vector2i(1, 12), Vector2i(1, 11),
			Vector2i(0, 11), Vector2i(0, 10), Vector2i(3, 12), Vector2i(3, 14), Vector2i(2, 14)]:
		_put(img, o.x + p.x, o.y + p.y, SKIN)
	for x in range(6, 13):
		_put(img, o.x + x, o.y + 13, SKIN_SHADE)
	_sleeve(img, o, 17)
	_outline(img)
	return img


static func _sleeve(img: Image, o: Vector2i, y0: int) -> void:
	for x in range(5, 14):
		_put(img, o.x + x, o.y + y0, SLEEVE_TRIM)
		for y in range(y0 + 1, y0 + 4):
			_put(img, o.x + x, o.y + y, SLEEVE)


static func _blank() -> Image:
	return Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)


static func _inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < SIZE and y < SIZE


static func _put(img: Image, x: int, y: int, c: Color) -> void:
	if _inside(x, y):
		img.set_pixel(x, y, c)


## Rings every drawn shape with a dark one-pixel outline (four neighbours).
static func _outline(img: Image) -> void:
	var source := img.duplicate() as Image
	for y in SIZE:
		for x in SIZE:
			if source.get_pixel(x, y).a > 0.0:
				continue
			for side in SIDES:
				if _inside(x + side.x, y + side.y) and source.get_pixel(x + side.x, y + side.y).a > 0.0:
					img.set_pixel(x, y, OUTLINE)
					break
