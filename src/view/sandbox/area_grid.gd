class_name AreaGrid
extends Control
## Clickable grid of offsets around the tile where a pattern ends. Shows and
## edits one area of an ability: its shared area, or the own area of one
## effect. Drawn in the canonical orientation, like the ability panel.

signal edited

const RADIUS := 4
const CELL := 34.0

var ability: AbilityDef
## The effect whose own area is edited; null edits the ability's shared area.
var target: AbilityEffect
var player_color := Color.BLUE


func _init() -> void:
	var side := (RADIUS * 2 + 1) * CELL
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_STOP


## The offsets being edited, in the data convention (x right, y UP).
func offsets() -> Array[Vector2i]:
	return target.area if target != null else ability.area


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if ability == null or button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	var cell := Vector2i((button.position / CELL).floor()) - Vector2i(RADIUS, RADIUS)
	if absi(cell.x) > RADIUS or absi(cell.y) > RADIUS:
		return
	var offset := Vector2i(cell.x, -cell.y)
	var list := offsets()
	if list.has(offset):
		list.erase(offset)
	else:
		list.append(offset)
	queue_redraw()
	edited.emit()


func _draw() -> void:
	if ability == null:
		return
	var font := get_theme_default_font()
	var edited_offsets := offsets()
	for y in range(-RADIUS, RADIUS + 1):
		for x in range(-RADIUS, RADIUS + 1):
			var offset := Vector2i(x, -y)
			var rect := Rect2(Vector2(x + RADIUS, y + RADIUS) * CELL, Vector2(CELL, CELL))
			var on := edited_offsets.has(offset)
			draw_rect(rect, ability.color.lerp(Color.WHITE, 0.35) if on else Color.WHITE)
			draw_rect(rect, Color(0, 0, 0, 0.7), false, 1.0)
			# Initials of every effect that reaches the cell (D = damage, S = stun).
			var marks := ""
			for effect in ability.effects:
				if ability.effect_area(effect).has(offset):
					marks += String(effect.kind()).left(1).to_upper()
			if offset == Vector2i.ZERO:
				draw_rect(rect.grow(-8.0), player_color)
				_draw_facing(rect)
			if marks != "":
				var color := Color.WHITE if offset == Vector2i.ZERO else Color(0, 0, 0, 0.8 if on else 0.35)
				DrawUtil.text_centered(self, font, rect, marks, 12, color)


## Small arrow out of the player's tile: the direction of the last move of
## the pattern, which is "in front" for the area.
func _draw_facing(rect: Rect2) -> void:
	if ability.pattern.is_empty():
		return
	var v := Vector2(Grid.vec(ability.pattern[-1]))
	var from := rect.get_center() + v * CELL * 0.3
	DrawUtil.arrow(self, from, from + v * CELL * 0.55, DrawUtil.INK, 3.0, 9.0)
