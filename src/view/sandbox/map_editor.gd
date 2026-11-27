class_name MapEditor
extends HBoxContainer
## Sandbox tab for the room: a palette of every tile type, every enemy type
## and the player start, the room size, and the canvas to paint on.

signal changed

var design: Design
var _canvas: MapCanvas
var _palette: VBoxContainer
var _width: SpinBox
var _height: SpinBox
var _brushes := ButtonGroup.new()


func _init() -> void:
	add_theme_constant_override("separation", 24)

	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 230
	side.add_theme_constant_override("separation", 8)
	add_child(side)

	side.add_child(_heading("Room size"))
	var size_row := HBoxContainer.new()
	_width = _size_box()
	_height = _size_box()
	size_row.add_child(_width)
	var by := Label.new()
	by.text = "x"
	size_row.add_child(by)
	size_row.add_child(_height)
	side.add_child(size_row)
	side.add_child(_note("Grows and shrinks at the right and bottom edge."))

	side.add_child(_heading("Brush"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	_palette = VBoxContainer.new()
	_palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_palette)
	side.add_child(_note("Left mouse button paints the brush.\nRight mouse button paints floor.\nPaint a tile over an enemy to remove it."))

	_canvas = MapCanvas.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.painted.connect(changed.emit)
	add_child(_canvas)


func bind(new_design: Design) -> void:
	design = new_design
	_canvas.design = design
	_width.set_value_no_signal(design.width())
	_height.set_value_no_signal(design.height())
	_build_palette()
	_canvas.queue_redraw()


func _build_palette() -> void:
	for child in _palette.get_children():
		_palette.remove_child(child)
		child.queue_free()
	var first: Button = null
	for tile in design.tiles:
		var button := _brush_button(tile.symbol, tile.display_name, tile.color)
		if first == null or tile.symbol == _canvas.brush:
			first = button
	_palette.add_child(HSeparator.new())
	for enemy in design.enemies:
		var button := _brush_button(enemy.symbol, enemy.display_name, enemy.color)
		if enemy.symbol == _canvas.brush:
			first = button
	_palette.add_child(HSeparator.new())
	var start := _brush_button(design.player_symbol, "Player start", design.player.color)
	if design.player_symbol == _canvas.brush:
		first = start
	if first != null:
		first.button_pressed = true


func _brush_button(symbol: String, title: String, color: Color) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = _brushes
	button.text = title
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.icon = _swatch(color)
	button.toggled.connect(func(on: bool) -> void:
		if on:
			_canvas.brush = symbol)
	_palette.add_child(button)
	return button


func _swatch(color: Color) -> Texture2D:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	image.fill_rect(Rect2i(1, 1, 14, 14), color)
	return ImageTexture.create_from_image(image)


func _size_box() -> SpinBox:
	var box := SpinBox.new()
	box.min_value = Design.MIN_SIZE
	box.max_value = Design.MAX_SIZE
	box.value_changed.connect(_on_size_changed)
	return box


func _on_size_changed(_value: float) -> void:
	design.resize(int(_width.value), int(_height.value))
	_canvas.queue_redraw()
	changed.emit()


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	return label


func _note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.modulate = Color(1, 1, 1, 0.6)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
