class_name UIKit
extends RefCounted
## Small immediate-mode drawing helpers used by the HUD and swap picker.

static var _font: Font = null


static func font() -> Font:
	if _font == null:
		_font = ThemeDB.fallback_font
	return _font


static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	ci.draw_string(font(), pos, s, align, width, size, col)


static func text_right(ci: CanvasItem, right_x: float, baseline_y: float, s: String, size: int, col: Color) -> void:
	var w := font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font(), Vector2(right_x - w, baseline_y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


static func text_center(ci: CanvasItem, center_x: float, baseline_y: float, s: String, size: int, col: Color) -> void:
	var w := font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font(), Vector2(center_x - w * 0.5, baseline_y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


static func text_width(s: String, size: int) -> float:
	return font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func panel(ci: CanvasItem, rect: Rect2, bg: Color = Palette.PANEL, border: Color = Palette.PANEL_EDGE, radius: int = 6, border_w: int = 1) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	ci.draw_style_box(sb, rect)


static func bar(ci: CanvasItem, rect: Rect2, pct: float, fill: Color, bg: Color = Color(0.06, 0.09, 0.14, 0.9)) -> void:
	ci.draw_rect(rect, bg)
	var p := clampf(pct, 0.0, 1.0)
	if p > 0.0:
		ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x * p, rect.size.y)), fill)
		ci.draw_line(rect.position + Vector2(1, 1), Vector2(rect.position.x + rect.size.x * p - 1, rect.position.y + 1), Color(1, 1, 1, 0.18), 1.0)
	ci.draw_rect(rect, Color(1, 1, 1, 0.1), false, 1.0)


static func stylebox(bg: Color, border: Color, radius: int = 4, border_w: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0
	return sb
