class_name TuningEditor
extends ScrollContainer
## Sandbox tab for numbers: the player, every enemy type with its behaviour,
## and every tile type with its terrain effects. All fields are generated
## from the exported properties (see PropertyForm).

signal changed

var design: Design
var _columns: HBoxContainer


func _init() -> void:
	_columns = HBoxContainer.new()
	_columns.add_theme_constant_override("separation", 40)
	add_child(_columns)


func bind(new_design: Design) -> void:
	design = new_design
	for child in _columns.get_children():
		_columns.remove_child(child)
		child.queue_free()

	var player := _column("Player")
	_add_section(player, design.player, "Player", design.player.color)

	var enemies := _column("Enemies")
	for enemy in design.enemies:
		_add_section(enemies, enemy, enemy.display_name, enemy.color)

	var tiles := _column("Tiles")
	for tile in design.tiles:
		_add_section(tiles, tile, tile.display_name, tile.color)


func _column(title: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 20)
	column.add_child(label)
	_columns.add_child(column)
	return column


func _add_section(column: VBoxContainer, res: Resource, title: String, color: Color) -> void:
	var header := HBoxContainer.new()
	var swatch := ColorRect.new()
	swatch.color = color
	swatch.custom_minimum_size = Vector2(14, 14)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(swatch)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 17)
	header.add_child(label)
	var body := VBoxContainer.new()
	if _fill(body, res) == 0:
		body.free()
		header.free()
		return
	column.add_child(HSeparator.new())
	column.add_child(header)
	column.add_child(body)


## Fields of `res`, then one indented block per resource it holds (an enemy's
## behaviour, a tile's effects). Returns the number of fields added in total.
func _fill(parent: VBoxContainer, res: Resource) -> int:
	var count := PropertyForm.add_fields(parent, res, changed.emit)
	for child in PropertyForm.children(res):
		if not _is_tunable(child):
			continue
		var block := VBoxContainer.new()
		var label := Label.new()
		label.text = PropertyForm.type_title(child)
		label.modulate = Color(1, 1, 1, 0.6)
		block.add_child(label)
		var added := _fill(block, child)
		if added == 0:
			block.free()
			continue
		var indent := MarginContainer.new()
		indent.add_theme_constant_override("margin_left", 18)
		indent.add_child(block)
		parent.add_child(indent)
		count += added
	return count


## Abilities have their own tab; pickup contents are not editable yet.
func _is_tunable(res: Resource) -> bool:
	return not (res is AbilityDef or res is TilePickupEffect)
