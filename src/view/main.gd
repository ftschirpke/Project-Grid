extends Control
## Presentation and input. Builds the UI, forwards key presses to the rules
## layer (Game) and redraws from its state. Holds no game rules.

const LOG_LINES := 8
const BACKGROUND := Color(0.95, 0.95, 0.96)

@export var config: GameConfig

var game: Game
var _board: BoardView
var _abilities: AbilityPanel
var _side: SidePanel
var _choice_layer: Control
var _choice_title: Label
var _choice_buttons: VBoxContainer
var _shown_choice: Choice
var _log: Array[String] = []


func _ready() -> void:
	if config == null:
		config = load("res://data/game.tres")
	_build_ui()
	game = Game.new(config)
	_bind_state()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)

	_abilities = AbilityPanel.new()
	_abilities.custom_minimum_size = Vector2(250, 0)
	row.add_child(_abilities)

	_board = BoardView.new()
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_board)

	_side = SidePanel.new()
	_side.custom_minimum_size = Vector2(290, 0)
	row.add_child(_side)

	# Pick-one-of-N overlay.
	_choice_layer = ColorRect.new()
	(_choice_layer as ColorRect).color = Color(0, 0, 0, 0.45)
	_choice_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choice_layer.visible = false
	add_child(_choice_layer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choice_layer.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var panel_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		panel_margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(panel_margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel_margin.add_child(column)
	_choice_title = Label.new()
	_choice_title.add_theme_font_size_override("font_size", 22)
	_choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_choice_title)
	_choice_buttons = VBoxContainer.new()
	_choice_buttons.add_theme_constant_override("separation", 8)
	column.add_child(_choice_buttons)


func _restart() -> void:
	game.restart()
	_log.clear()
	_bind_state()


## The GameState object is replaced on restart, so (re)connect to it here.
func _bind_state() -> void:
	game.state.event.connect(_on_event)
	_board.bind(game)
	_abilities.bind(game)
	_side.bind(game)
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_R:
			_restart()
		KEY_UP, KEY_W:
			_move(Grid.Dir.UP)
		KEY_RIGHT, KEY_D:
			_move(Grid.Dir.RIGHT)
		KEY_DOWN, KEY_S:
			_move(Grid.Dir.DOWN)
		KEY_LEFT, KEY_A:
			_move(Grid.Dir.LEFT)
		_:
			if key.keycode >= KEY_1 and key.keycode <= KEY_9:
				_choose(key.keycode - KEY_1)
			else:
				return
	get_viewport().set_input_as_handled()


func _move(dir: int) -> void:
	game.try_move(dir)
	_refresh()


func _choose(index: int) -> void:
	if game.choose(index):
		_refresh()


func _refresh() -> void:
	var state := game.state
	var previews: Array = []
	if state.status == GameState.Status.PLAYING and state.current_choice() == null:
		for dir in 4:
			previews.append(game.preview(dir))
	_board.previews = previews
	_side.previews = previews
	_side.log_lines = _log
	_board.queue_redraw()
	_abilities.queue_redraw()
	_side.queue_redraw()
	_update_choice()


func _update_choice() -> void:
	var choice := game.state.current_choice()
	_choice_layer.visible = choice != null
	if choice == _shown_choice:
		return
	_shown_choice = choice
	for child in _choice_buttons.get_children():
		child.queue_free()
	if choice == null:
		return
	_choice_title.text = choice.title
	for i in choice.options.size():
		var option := choice.options[i]
		var button := Button.new()
		button.text = "%d.  %s\n%s" % [i + 1, option.get_label(game.state), option.get_description(game.state)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(420, 0)
		button.pressed.connect(_choose.bind(i))
		_choice_buttons.add_child(button)


func _on_event(type: StringName, data: Dictionary) -> void:
	var state := game.state
	match type:
		&"ability_fired":
			var ability: AbilityDef = data.ability
			_board.flash(data.tiles, ability.color)
			_add_log("%s fired" % ability.display_name)
		&"attack":
			_board.flash(data.tiles.filter(state.is_visible), Color(0.8, 0.0, 0.0))
		&"damaged":
			var unit: Unit = data.unit
			if unit.is_player:
				_board.flash([data.pos], Color(1.0, 0.0, 0.0))
				_add_log("You take %d damage" % data.amount)
			elif state.is_visible(data.pos):
				_add_log("%s takes %d damage" % [unit.display_name(), data.amount])
		&"died":
			_add_log("%s destroyed" % data.unit.display_name())
		&"activated":
			_add_log("%s noticed you" % data.unit.display_name())
		&"choice_resolved":
			_add_log("Picked: %s" % data.option.get_label(state))
		&"won":
			_add_log("Room cleared: %s" % data.reason)
		&"lost":
			_add_log("Defeated: %s" % data.reason)


func _add_log(line: String) -> void:
	_log.append(line)
	while _log.size() > LOG_LINES:
		_log.pop_front()
