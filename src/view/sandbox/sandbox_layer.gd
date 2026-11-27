class_name SandboxLayer
extends Control
## The debug and editing layer (Ctrl+D). Covers the game and edits a Design:
## the room, the abilities and the numbers, plus the testing aids. It only
## changes the design and reports it; Main saves and restarts the room.

## The room, abilities or numbers changed: the room must restart.
signal design_changed
## A testing aid was switched: applies to the running room as it is.
signal aids_changed
signal reset_requested
signal close_requested

const BACKGROUND := Color(0.11, 0.12, 0.15)
const CHECK_FRAME := Color(0.85, 0.87, 0.92)
const CHECK_ON := Color(1.0, 0.75, 0.0)

var design: Design
var _map: MapEditor
var _abilities: AbilityEditor
var _tuning: TuningEditor
var _fog_off: CheckBox
var _invulnerable: CheckBox
var _confirm_reset: ConfirmationDialog


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	theme = _make_theme()

	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	column.add_child(bar)
	var title := Label.new()
	title.text = "Sandbox"
	title.add_theme_font_size_override("font_size", 24)
	bar.add_child(title)
	var hint := Label.new()
	hint.text = "Edits are kept in local/ on this machine. Closing restarts the room with them."
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(hint)
	_fog_off = _aid("Fog off", func(on: bool) -> void: design.fog_off = on)
	bar.add_child(_fog_off)
	_invulnerable = _aid("Invulnerable", func(on: bool) -> void: design.invulnerable = on)
	bar.add_child(_invulnerable)
	bar.add_child(VSeparator.new())
	var reset := Button.new()
	reset.text = "Reset to defaults"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(func() -> void: _confirm_reset.popup_centered())
	bar.add_child(reset)
	var close := Button.new()
	close.text = "Close and play (Ctrl+D)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_requested.emit)
	bar.add_child(close)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	_map = MapEditor.new()
	_abilities = AbilityEditor.new()
	_tuning = TuningEditor.new()
	var titles := ["Map", "Abilities", "Numbers"]
	var editors: Array[Control] = [_map, _abilities, _tuning]
	for i in editors.size():
		var pad := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			pad.add_theme_constant_override("margin_" + side, 12)
		pad.add_child(editors[i])
		tabs.add_child(pad)
		tabs.set_tab_title(i, titles[i])
		editors[i].connect(&"changed", design_changed.emit)

	_confirm_reset = ConfirmationDialog.new()
	_confirm_reset.title = "Reset to defaults"
	_confirm_reset.dialog_text = "Discard every sandbox edit on this machine and return to the game as it is in data/?"
	_confirm_reset.ok_button_text = "Reset"
	_confirm_reset.confirmed.connect(reset_requested.emit)
	add_child(_confirm_reset)


## Shows `new_design` in every tab. Call again after the design was replaced.
## The same design again changes nothing, so reopening the layer keeps the
## tab, the selected ability and the scroll positions.
func bind(new_design: Design) -> void:
	if new_design == design:
		return
	design = new_design
	_fog_off.set_pressed_no_signal(design.fog_off)
	_invulnerable.set_pressed_no_signal(design.invulnerable)
	_map.bind(design)
	_abilities.bind(design)
	_tuning.bind(design)


## Applies a number that was typed into the focused field but not confirmed
## with Enter. Call before reading what changed. Only the focused field: its
## text is what the user typed, the others show their value already.
func commit_fields() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit and focused.get_parent() is SpinBox and is_ancestor_of(focused):
		(focused.get_parent() as SpinBox).apply()


## Checkboxes that stand out on the dark background: a bright frame when off,
## a filled box with a dark tick when on. Applies to every tab of the layer.
func _make_theme() -> Theme:
	var out := Theme.new()
	var off := _check_icon(false)
	var on := _check_icon(true)
	for state in ["unchecked", "unchecked_disabled"]:
		out.set_icon(state, "CheckBox", off)
	for state in ["checked", "checked_disabled"]:
		out.set_icon(state, "CheckBox", on)
	out.set_constant("h_separation", "CheckBox", 8)
	return out


func _check_icon(on: bool) -> Texture2D:
	var side := 20
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	image.fill(CHECK_ON if on else CHECK_FRAME)
	if on:
		# The tick: a short stroke down to the right, a long one up to the right.
		for i in 12:
			var x := 4 + i
			var y := 10 + i if i < 4 else 16 - i
			image.fill_rect(Rect2i(x, y, 2, 3), BACKGROUND)
	else:
		image.fill_rect(Rect2i(2, 2, side - 4, side - 4), BACKGROUND.lightened(0.08))
	return ImageTexture.create_from_image(image)


func _aid(text: String, apply: Callable) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.focus_mode = Control.FOCUS_NONE
	box.toggled.connect(func(on: bool) -> void:
		apply.call(on)
		aids_changed.emit())
	return box
