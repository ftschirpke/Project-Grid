class_name DrawUtil
extends RefCounted
## Small drawing helpers shared by the view controls. Arrows are drawn as
## shapes so the prototype does not depend on font glyphs.

const INK := Color(0.1, 0.1, 0.12)
const MUTED := Color(0.42, 0.42, 0.46)


static func arrow(ci: CanvasItem, from: Vector2, to: Vector2, color: Color, width: float = 2.0, head: float = 7.0) -> void:
	var delta := to - from
	if delta.length() < 0.01:
		return
	var dir := delta.normalized()
	var side := Vector2(-dir.y, dir.x)
	ci.draw_line(from, to - dir * head * 0.8, color, width, true)
	ci.draw_colored_polygon(PackedVector2Array([to, to - dir * head + side * head * 0.6, to - dir * head - side * head * 0.6]), color)


## Arrow for a Grid.Dir, centred on `center`.
static func dir_arrow(ci: CanvasItem, center: Vector2, dir: int, length: float, color: Color, width: float = 2.0) -> void:
	var v := Vector2(Grid.vec(dir))
	arrow(ci, center - v * length * 0.5, center + v * length * 0.5, color, width, maxf(5.0, length * 0.4))


static func text(ci: CanvasItem, font: Font, pos: Vector2, string: String, size: int, color: Color = INK) -> void:
	ci.draw_string(font, pos, string, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Text centred horizontally and vertically in `rect`.
static func text_centered(ci: CanvasItem, font: Font, rect: Rect2, string: String, size: int, color: Color = INK) -> void:
	var baseline := rect.position.y + rect.size.y * 0.5 + size * 0.36
	ci.draw_string(font, Vector2(rect.position.x, baseline), string, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)
