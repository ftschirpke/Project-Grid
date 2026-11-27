class_name AbilityEditor
extends HBoxContainer
## Sandbox tab for abilities: the list of every ability in the design on the
## left, the selected one on the right (pattern, switches, effects, areas).

signal changed

## Effect kinds the "add" buttons offer. A new kind is one line here plus its
## script; its exported numbers show up through PropertyForm.
const EFFECT_KINDS := {
	"Damage": preload("res://src/core/abilities/effects/damage_effect.gd"),
	"Stun": preload("res://src/core/abilities/effects/stun_effect.gd"),
}
const NEW_COLORS: Array[Color] = [
	Color(0.85, 0.45, 0.1), Color(0.2, 0.6, 0.25), Color(0.55, 0.3, 0.8),
	Color(0.1, 0.55, 0.75), Color(0.8, 0.25, 0.55), Color(0.6, 0.55, 0.1),
]

var design: Design
var _selected: AbilityDef
## Effect whose own area the grid edits; null for the shared area.
var _area_target: AbilityEffect
var _list: ItemList
var _detail: VBoxContainer
var _pattern_view: PatternView
var _pattern_text: Label
var _grid: AreaGrid


func _init() -> void:
	add_theme_constant_override("separation", 24)

	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 250
	add_child(side)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(index: int) -> void: _select(design.abilities[index]))
	side.add_child(_list)
	var buttons := HBoxContainer.new()
	side.add_child(buttons)
	buttons.add_child(_button("New", _new_ability))
	buttons.add_child(_button("Duplicate", _duplicate_ability))
	buttons.add_child(_button("Delete", _delete_ability))
	side.add_child(_note("[x] marks the abilities the player starts with. When one move triggers several, they resolve in list order."))

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 10)
	scroll.add_child(_detail)


func bind(new_design: Design) -> void:
	design = new_design
	_select(design.abilities[0] if not design.abilities.is_empty() else null)


# --- List --------------------------------------------------------------------

func _select(ability: AbilityDef) -> void:
	_selected = ability
	_area_target = null
	_refresh_list()
	_rebuild_detail()


func _refresh_list() -> void:
	_list.clear()
	for ability in design.abilities:
		var mark := "[x]" if design.is_starting(ability) else "[  ]"
		var index := _list.add_item("%s  %s" % [mark, ability.display_name])
		_list.set_item_custom_fg_color(index, ability.color.lerp(Color.WHITE, 0.55))
	var selected := design.abilities.find(_selected)
	if selected >= 0:
		_list.select(selected)


func _new_ability() -> void:
	var ability := AbilityDef.new()
	ability.id = design.free_ability_id()
	ability.display_name = "New Ability"
	ability.color = NEW_COLORS[design.abilities.size() % NEW_COLORS.size()]
	ability.area = [Vector2i(0, 1)] as Array[Vector2i]
	ability.effects = [DamageEffect.new()] as Array[AbilityEffect]
	design.add_ability(ability)
	_select(ability)
	changed.emit()


func _duplicate_ability() -> void:
	if _selected == null:
		return
	var copy := Design.deep_copy(_selected) as AbilityDef
	copy.id = design.free_ability_id(String(_selected.id))
	copy.display_name = "%s Copy" % _selected.display_name
	design.add_ability(copy, design.is_starting(_selected))
	_select(copy)
	changed.emit()


func _delete_ability() -> void:
	if _selected == null:
		return
	var index := design.abilities.find(_selected)
	design.remove_ability(_selected)
	var next := mini(index, design.abilities.size() - 1)
	_select(design.abilities[next] if next >= 0 else null)
	changed.emit()


# --- Detail ------------------------------------------------------------------

func _rebuild_detail() -> void:
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	_pattern_view = null
	_grid = null
	if _selected == null:
		_detail.add_child(_note("No ability selected. Create one with New."))
		return
	var ability := _selected
	_build_identity(ability)
	_detail.add_child(HSeparator.new())
	_build_pattern(ability)
	_detail.add_child(HSeparator.new())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 30)
	_detail.add_child(columns)
	_build_effects(ability, columns)
	_build_area(ability, columns)


func _build_identity(ability: AbilityDef) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_detail.add_child(row)
	var name_edit := LineEdit.new()
	name_edit.text = ability.display_name
	name_edit.custom_minimum_size.x = 220
	name_edit.text_changed.connect(func(text: String) -> void:
		ability.display_name = text
		_refresh_list()
		changed.emit())
	row.add_child(name_edit)
	var color := ColorPickerButton.new()
	color.color = ability.color
	color.custom_minimum_size = Vector2(44, 0)
	color.edit_alpha = false
	color.color_changed.connect(func(value: Color) -> void:
		ability.color = value
		_refresh_list()
		if _grid != null:
			_grid.queue_redraw()
		changed.emit())
	row.add_child(color)
	row.add_child(_check("Player starts with it", design.is_starting(ability), func(on: bool) -> void:
		design.set_starting(ability, on)
		_refresh_list()))

	var switches := HBoxContainer.new()
	switches.add_theme_constant_override("separation", 12)
	_detail.add_child(switches)
	switches.add_child(_check("Rotatable (all four directions)", ability.rotatable, func(on: bool) -> void:
		ability.rotatable = on))
	switches.add_child(_check("Mirrorable (also the left-right mirror image)", ability.mirrorable, func(on: bool) -> void:
		ability.mirrorable = on))


func _build_pattern(ability: AbilityDef) -> void:
	_detail.add_child(_heading("Pattern"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_detail.add_child(row)
	for dir in 4:
		row.add_child(_button("+ %s" % Grid.NAMES[dir], func() -> void:
			ability.pattern.append(dir)
			_pattern_changed()))
	row.add_child(VSeparator.new())
	row.add_child(_button("Remove last", func() -> void:
		if not ability.pattern.is_empty():
			ability.pattern.pop_back()
			_pattern_changed()))
	row.add_child(_button("Clear", func() -> void:
		if not ability.pattern.is_empty():
			ability.pattern.clear()
			_pattern_changed()))
	var shown := HBoxContainer.new()
	shown.add_theme_constant_override("separation", 16)
	_detail.add_child(shown)
	_pattern_view = PatternView.new()
	_pattern_view.pattern = ability.pattern
	shown.add_child(_pattern_view)
	_pattern_text = _note("")
	_pattern_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_pattern_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shown.add_child(_pattern_text)
	_update_pattern_text()


func _pattern_changed() -> void:
	_pattern_view.pattern = _selected.pattern
	_update_pattern_text()
	_grid.queue_redraw()
	changed.emit()


func _update_pattern_text() -> void:
	var moves: PackedStringArray = []
	for dir in _selected.pattern:
		moves.append(Grid.NAMES[dir])
	if moves.is_empty():
		_pattern_text.text = "No moves yet: an empty pattern never fires."
	else:
		_pattern_text.text = "%s\nThe last move is the direction the player faces." % ", ".join(moves)


func _build_effects(ability: AbilityDef, parent: Control) -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 330
	column.add_theme_constant_override("separation", 8)
	parent.add_child(column)
	column.add_child(_heading("Effects"))
	for effect in ability.effects:
		var panel := PanelContainer.new()
		column.add_child(panel)
		var box := VBoxContainer.new()
		panel.add_child(box)
		var header := HBoxContainer.new()
		box.add_child(header)
		var title := Label.new()
		title.text = _effect_title(ability, effect)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(title)
		header.add_child(_button("Remove", func() -> void:
			ability.effects.erase(effect)
			if _area_target == effect:
				_area_target = null
			_rebuild_detail()
			changed.emit()))
		PropertyForm.add_fields(box, effect, func() -> void:
			changed.emit(), ["area"])
		box.add_child(_check("Own area (otherwise the shared area)", not effect.area.is_empty(), func(on: bool) -> void:
			_set_own_area(ability, effect, on)))
	var add_row := HBoxContainer.new()
	column.add_child(add_row)
	for kind: String in EFFECT_KINDS:
		add_row.add_child(_button("+ %s" % kind, func() -> void:
			ability.effects.append(EFFECT_KINDS[kind].new())
			_rebuild_detail()
			changed.emit()))
	if ability.effects.is_empty():
		column.add_child(_note("Without effects the ability fires but does nothing."))


## An effect has its own area exactly when that area is not empty, so
## switching it on starts from a copy of the shared area.
func _set_own_area(ability: AbilityDef, effect: AbilityEffect, on: bool) -> void:
	if on:
		var own: Array[Vector2i] = ability.area.duplicate()
		if own.is_empty():
			own.append(Vector2i(0, 1))
		effect.area = own
		_area_target = effect
	else:
		var none: Array[Vector2i] = []
		effect.area = none
		if _area_target == effect:
			_area_target = null
	_rebuild_detail()
	changed.emit()


func _build_area(ability: AbilityDef, parent: Control) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	parent.add_child(column)
	column.add_child(_heading("Area"))
	var targets: Array[AbilityEffect] = [null]
	var picker := OptionButton.new()
	picker.add_item("Shared area")
	for effect in ability.effects:
		if not effect.area.is_empty():
			targets.append(effect)
			picker.add_item("Own area of %s" % _effect_title(ability, effect))
	picker.select(maxi(0, targets.find(_area_target)))
	picker.item_selected.connect(func(index: int) -> void:
		_area_target = targets[index]
		_grid.target = _area_target
		_grid.queue_redraw())
	column.add_child(picker)
	_grid = AreaGrid.new()
	_grid.ability = ability
	_grid.target = _area_target
	_grid.player_color = design.player.color
	_grid.edited.connect(_on_area_edited)
	column.add_child(_grid)
	column.add_child(_note("Click tiles to add or remove them. The square is the tile where the pattern ends, the arrow is the last move. Letters show which effects reach a tile. The area turns and mirrors with the pattern."))


func _on_area_edited() -> void:
	# An own area with no tiles left means "use the shared area" again.
	if _area_target != null and _area_target.area.is_empty():
		_area_target = null
		_rebuild_detail()
	changed.emit()


## "Damage", or "Damage 2" when the ability has several effects of a kind.
func _effect_title(ability: AbilityDef, effect: AbilityEffect) -> String:
	var kind := String(effect.kind()).capitalize()
	var same := 0
	var number := 0
	for other in ability.effects:
		if other.kind() == effect.kind():
			same += 1
			if other == effect:
				number = same
	return kind if same <= 1 else "%s %d" % [kind, number]


# --- Small builders ----------------------------------------------------------

func _button(text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(pressed)
	return button


## Checkbox that reports a change after running `toggled`.
func _check(text: String, on: bool, toggled: Callable) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.button_pressed = on
	box.focus_mode = Control.FOCUS_NONE
	box.toggled.connect(func(value: bool) -> void:
		toggled.call(value)
		changed.emit())
	return box


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
	label.custom_minimum_size.x = 240
	return label
