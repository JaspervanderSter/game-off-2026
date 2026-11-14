class_name Icons
## Interface icons drawn from small SVG paths, tinted on creation.

const SHAPES := {
	"play": '<path d="M7 4.5v15l12.5-7.5z" fill="#fff"/>',
	"stop": '<rect x="6" y="6" width="12" height="12" rx="2" fill="#fff"/>',
	"series": '<rect x="3" y="14" width="4" height="6" rx="1" fill="#fff"/><rect x="10" y="10" width="4" height="10" rx="1" fill="#fff"/><rect x="17" y="5" width="4" height="15" rx="1" fill="#fff"/>',
	"loop": '<path d="M5 12a7 7 0 0 1 12-5M19 12a7 7 0 0 1-12 5" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round"/><path d="M17 2.5v4.5h-4.5M7 21.5V17h4.5" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',
	"save": '<path d="M4 4h12l4 4v12H4z" fill="none" stroke="#fff" stroke-width="2" stroke-linejoin="round"/><rect x="8" y="4" width="7" height="5" fill="#fff"/><rect x="7" y="13" width="10" height="7" rx="1" fill="#fff"/>',
	"revert": '<path d="M5.5 9A7.5 7.5 0 1 1 5 15" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round"/><path d="M4 3.5v6h6" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',
	"folder": '<path d="M2.5 6.5A1.5 1.5 0 0 1 4 5h5l2 2.5h9a1.5 1.5 0 0 1 1.5 1.5v9.5A1.5 1.5 0 0 1 20 20H4a1.5 1.5 0 0 1-1.5-1.5z" fill="#fff"/>',
	"reload": '<path d="M19 12a7 7 0 1 1-2.5-5.4" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round"/><path d="M18 3v5h-5" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',
	"trash": '<path d="M4 6.5h16M9.5 6.5V4h5v2.5" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M6 6.5l1 13.5h10l1-13.5" fill="none" stroke="#fff" stroke-width="2" stroke-linejoin="round"/><path d="M10 10.5v6M14 10.5v6" stroke="#fff" stroke-width="2" stroke-linecap="round"/>',
	"plus":'<path d="M12 5v14M5 12h14" stroke="#fff" stroke-width="2.6" stroke-linecap="round"/>',
	"minus": '<path d="M5 12h14" stroke="#fff" stroke-width="2.6" stroke-linecap="round"/>',
	"speaker": '<path d="M3 9h4l5-4.5v15L7 15H3z" fill="#fff"/><path d="M15.5 8.5a5 5 0 0 1 0 7M18 6a8.5 8.5 0 0 1 0 12" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round"/>',
	"note": '<path d="M9 18V5l11-2v13" fill="none" stroke="#fff" stroke-width="2.2" stroke-linejoin="round"/><circle cx="6.5" cy="18" r="3" fill="#fff"/><circle cx="17.5" cy="16" r="3" fill="#fff"/>',
	"wave": '<path d="M2 12h3l2-6 3 12 3-15 3 15 2-6h4" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
	"fork": '<path d="M8 2.5v8.5a4 4 0 0 0 8 0V2.5" fill="none" stroke="#fff" stroke-width="2.6" stroke-linecap="round"/><path d="M12 15v6.5" stroke="#fff" stroke-width="2.6" stroke-linecap="round"/>',
}

static var _cache := {}


## The icon `shape` in `color`, `size` pixels square.
static func get_icon(shape: String, color := Color.WHITE, size := 20) -> Texture2D:
	var key := "%s/%s/%d" % [shape, color.to_html(), size]
	if _cache.has(key):
		return _cache[key]
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">%s</svg>' % SHAPES[shape]
	svg = svg.replace("#fff", "#" + color.to_html(false))
	var image := Image.new()
	image.load_svg_from_string(svg, size / 24.0)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture
