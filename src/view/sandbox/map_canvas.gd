class_name MapCanvas
extends Control
## The room of a Design as a paintable grid. Left mouse button paints the
## brush, right mouse button paints floor; both work while dragging.

signal painted

var design: Design
## Symbol of a tile type, an enemy type or the player start.
var brush := "."
var _hover := GameState.NO_TILE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func() -> void:
		_hover = GameState.NO_TILE
		queue_redraw())


func _tile_size() -> float:
	return floorf(minf(size.x / design.width(), size.y / design.height()))


func _origin() -> Vector2:
	return ((size - Vector2(design.width(), design.height()) * _tile_size()) * 0.5).floor()


func _cell_at(point: Vector2) -> Vector2i:
	var ts := _tile_size()
	if ts <= 0.0:
		return GameState.NO_TILE
	var cell := Vector2i(((point - _origin()) / ts).floor())
	return cell if design.in_bounds(cell) else GameState.NO_TILE


func _gui_input(event: InputEvent) -> void:
	if design == null:
		return
	var mouse := event as InputEventMouse
	if mouse == null:
		return
	var cell := _cell_at(mouse.position)
	if cell != _hover:
		_hover = cell
		queue_redraw()
	var button := event as InputEventMouseButton
	if button != null:
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			_paint(cell, brush)
		elif button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
			_paint(cell, design.floor_symbol)
	elif event is InputEventMouseMotion:
		if mouse.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_paint(cell, brush)
		elif mouse.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_paint(cell, design.floor_symbol)


func _paint(cell: Vector2i, symbol: String) -> void:
	if cell != GameState.NO_TILE and design.set_cell(cell, symbol):
		queue_redraw()
		painted.emit()


func _draw() -> void:
	if design == null or design.width() == 0:
		return
	var ts := _tile_size()
	if ts < 4.0:
		return # not laid out yet, or far too small to show anything
	var origin := _origin()
	var font := get_theme_default_font()
	var floor_tile := design.tile_by_symbol(design.floor_symbol)
	for y in design.height():
		for x in design.width():
			var pos := Vector2i(x, y)
			var rect := Rect2(origin + Vector2(pos) * ts, Vector2(ts, ts))
			var symbol := design.cell(pos)
			var tile := design.tile_by_symbol(symbol)
			var shown := tile if tile != null else floor_tile
			draw_rect(rect, shown.color if shown != null else Color.WHITE)
			if shown != null and shown.label != "":
				var label_size := int(ts * (0.5 if shown.label.length() <= 1 else 0.3))
				DrawUtil.text_centered(self, font, rect, shown.label, label_size, Color(0, 0, 0, 0.75))
			if tile == null:
				_draw_unit(rect, symbol, ts, font)
			draw_rect(rect, Color(0, 0, 0, 0.6), false, 1.0)
	draw_rect(Rect2(origin, Vector2(design.width(), design.height()) * ts), Color.BLACK, false, 2.0)
	if _hover != GameState.NO_TILE:
		draw_rect(Rect2(origin + Vector2(_hover) * ts, Vector2(ts, ts)).grow(-1.0), Color(1.0, 0.75, 0.0), false, 3.0)


func _draw_unit(rect: Rect2, symbol: String, ts: float, font: Font) -> void:
	var color := Color.MAGENTA
	var text := "?"
	var enemy := design.enemy_by_symbol(symbol)
	if symbol == design.player_symbol:
		color = design.player.color
		text = "P"
	elif enemy != null:
		color = enemy.color
		text = symbol
	var box := rect.grow(-ts * 0.16)
	draw_rect(box, color)
	draw_rect(box, Color.BLACK, false, 1.5)
	DrawUtil.text_centered(self, font, box, text, int(ts * 0.38), Color.WHITE)
