class_name MapCameraTuning
extends RefCounted
## The map's camera on small screens (playtest request, 27 November 2026): on
## a phone the whole map and the title frame read too small, so the camera
## zooms in on the next opponent, follows the footsteps and the roads' traces,
## lets the player pan, and comes back to the next opponent after a few idle
## seconds. On every device the player may also zoom with two fingers, the
## wheel or a touchpad; that zoom too lasts until the idle return. These values are tuned live in a hidden panel (Ctrl+Shift+C, or a
## three-finger tap), saved in user:// so a phone keeps them across reloads.

enum Scope { MOBILE, ALWAYS, OFF }
enum Follow { SMOOTH_DAMP, LERP }

const PATH := "user://map_camera.cfg"
const DEFAULTS := {
	"scope": Scope.MOBILE,
	"map_zoom": 2.0, # times the whole-map framing
	"follow": Follow.SMOOTH_DAMP,
	"follow_time": 0.9, # seconds to (nearly) reach the target
	"pan": true,
	"gestures": true, # pinch, wheel and touchpad zoom, on every device
	"max_zoom": 4.0, # the closest the player may zoom, times the whole map
	"idle_return": 5.0, # seconds without touching before the camera returns
	"title_fill": 0.6, # 0: the title's whole frame, 1: its island and medallion fill the screen
}

## False in the test runner, so a tuned phone or desktop never changes tests.
static var persist := true
static var values := DEFAULTS.duplicate()
static var _loaded := false


static func value(key: String) -> Variant:
	_ensure_loaded()
	return values.get(key, DEFAULTS[key])


static func set_value(key: String, v: Variant) -> void:
	_ensure_loaded()
	values[key] = v
	save()


static func reset() -> void:
	values = DEFAULTS.duplicate()
	save()


static func save() -> void:
	if not persist:
		return
	var file := ConfigFile.new()
	for key in values:
		file.set_value("camera", key, values[key])
	file.save(PATH)


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not persist:
		return
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return
	for key in DEFAULTS:
		values[key] = file.get_value("camera", key, DEFAULTS[key])


## A phone or tablet: a mobile build, a mobile browser, or a touch screen.
static func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") \
		or DisplayServer.is_touchscreen_available()


## Whether the zoomed camera applies on this device.
static func active() -> bool:
	match int(value("scope")):
		Scope.ALWAYS:
			return true
		Scope.MOBILE:
			return is_mobile()
	return false


## The islands' zoom, relative to the whole map fitting the screen.
static func map_zoom() -> float:
	return maxf(1.0, float(value("map_zoom"))) if active() else 1.0


static func title_fill() -> float:
	return clampf(float(value("title_fill")), 0.0, 1.0) if active() else 0.0

