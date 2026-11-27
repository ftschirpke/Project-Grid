extends Control
## Presentation and input. Builds the UI, forwards key presses to the rules
## layer (Game) and redraws from its state. Holds no game rules.

const LOG_LINES := 8
const BACKGROUND := Color(0.95, 0.95, 0.96)
## Enemy phase display: pause after the player's last move, then hold the
## result briefly before input is accepted again.
const ENEMY_PHASE_DELAY := 0.35
const ENEMY_PHASE_HOLD := 0.25
## The shipped game: the defaults the sandbox starts from and resets to.
@export var config: GameConfig

## Everything the game's own code writes goes into this git-ignored folder
## inside the project. (Godot itself still keeps logs and caches in its user
## data folder.)
var settings_path := "res://local/settings.cfg"
var design_path := "res://local/sandbox_design.tres"

var game: Game
## What is actually played: the defaults, or the sandbox edits saved in
## design_path. Edited in the sandbox layer (Ctrl+D).
var _design: Design
var _sandbox: SandboxLayer
## The saved design differs from the defaults.
var _design_edited := false
## Edits made since the layer was opened: save them, restart the room.
var _design_dirty := false
var _aids_dirty := false
var _board: BoardView
var _abilities: AbilityPanel
var _side: SidePanel
var _choice_layer: Control
var _choice_title: Label
var _choice_buttons: VBoxContainer
var _shown_choice: Choice
var _log: Array[String] = []
## Show the enemy phase as a separate beat (toggle with P).
var _show_enemy_phase := true
## Input is ignored while the enemy phase plays.
var _busy := false


func _ready() -> void:
	if config == null:
		config = load("res://data/game.tres")
	_build_ui()
	_load_settings()
	_design = Design.load_saved(design_path)
	_design_edited = _design != null
	if _design == null:
		_design = Design.from_defaults(config)
	_start_game()


## Starts the room from the current design with a fresh Game.
func _start_game() -> void:
	game = Game.new(_design.make_config(config), _design.room_text(), _design.tiles, _design.enemies)
	game.pause_before_enemies = _show_enemy_phase
	_log.clear()
	_shown_choice = null
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

	# Debug and editing layer, above everything else.
	_sandbox = SandboxLayer.new()
	_sandbox.design_changed.connect(func() -> void: _design_dirty = true)
	_sandbox.aids_changed.connect(func() -> void: _aids_dirty = true)
	_sandbox.reset_requested.connect(_reset_design)
	_sandbox.close_requested.connect(_close_sandbox)
	add_child(_sandbox)


# --- Sandbox -----------------------------------------------------------------

func _open_sandbox() -> void:
	_design_dirty = false
	_aids_dirty = false
	_sandbox.bind(_design)
	_sandbox.visible = true


## Keeps the edits and returns to the game. The room restarts if the design
## changed; a testing aid alone applies to the room as it stands.
func _close_sandbox() -> void:
	# A number that was typed but not confirmed with Enter still counts.
	_sandbox.commit_fields()
	get_viewport().gui_release_focus()
	_sandbox.visible = false
	_save_design()
	if _design_dirty:
		_start_game()
	elif _aids_dirty:
		_design.apply_testing_aids(game.config.rules, config.rules)
		game.state.update_vision()
		_refresh()
	_design_dirty = false
	_aids_dirty = false


func _save_design() -> void:
	if not (_design_dirty or _aids_dirty):
		return
	if _design.save(design_path) == OK:
		_design_edited = true
	else:
		push_warning("Sandbox: could not save %s" % design_path)


## Throws the saved design away and goes back to the shipped game.
func _reset_design() -> void:
	if FileAccess.file_exists(design_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(design_path))
	_design = Design.from_defaults(config)
	_design_edited = false
	_sandbox.bind(_design)
	_start_game()
	_design_dirty = false
	_aids_dirty = false


func _notification(what: int) -> void:
	# Closing the window with the layer open must not lose the edits.
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _sandbox != null and _sandbox.visible:
		_sandbox.commit_fields()
		_save_design()


func _input(event: InputEvent) -> void:
	# Caught before the UI, so the shortcut also works while a field has focus.
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_D and key.ctrl_pressed:
		if _sandbox.visible:
			_close_sandbox()
		else:
			_open_sandbox()
		get_viewport().set_input_as_handled()


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
	if _sandbox.visible or key.ctrl_pressed:
		return
	match key.keycode:
		KEY_R:
			_restart()
		KEY_P:
			_toggle_enemy_phase()
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
	if _busy:
		return
	game.try_move(dir)
	_refresh()
	if game.is_enemy_phase_pending():
		_play_enemy_phase()


## Your moves are on the board; announce the enemies, then let them all act
## at once.
func _play_enemy_phase() -> void:
	_busy = true
	_board.phase_banner = "ENEMY TURN"
	_refresh()
	await get_tree().create_timer(ENEMY_PHASE_DELAY).timeout
	# A restart in the meantime drops the pending phase.
	if game.is_enemy_phase_pending():
		game.resume_enemy_phase()
		_refresh()
		await get_tree().create_timer(ENEMY_PHASE_HOLD).timeout
	_board.phase_banner = ""
	_busy = false
	_refresh()


func _toggle_enemy_phase() -> void:
	_show_enemy_phase = not _show_enemy_phase
	game.pause_before_enemies = _show_enemy_phase
	_side.show_enemy_phase = _show_enemy_phase
	_add_log("Enemy phase: %s" % ("shown" if _show_enemy_phase else "instant"))
	_save_settings()
	_refresh()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		_show_enemy_phase = cfg.get_value("display", "show_enemy_phase", true)
	_side.show_enemy_phase = _show_enemy_phase


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(settings_path.get_base_dir()))
	cfg.set_value("display", "show_enemy_phase", _show_enemy_phase)
	cfg.save(settings_path)


func _choose(index: int) -> void:
	if game.choose(index):
		_refresh()


func _refresh() -> void:
	var state := game.state
	var previews: Array = []
	if state.status == GameState.Status.PLAYING and state.current_choice() == null and not _busy:
		for dir in 4:
			previews.append(game.preview(dir))
	_board.previews = previews
	_side.previews = previews
	_side.log_lines = _log
	_side.sandbox_note = _sandbox_note()
	_board.queue_redraw()
	_abilities.queue_redraw()
	_side.queue_redraw()
	_update_choice()


## What the status column says about the sandbox, so nobody mistakes an
## edited room or a testing aid for the shipped game.
func _sandbox_note() -> String:
	var parts: PackedStringArray = ["edited design" if _design_edited else "defaults"]
	if _design.fog_off:
		parts.append("fog off")
	if _design.invulnerable:
		parts.append("invulnerable")
	return ", ".join(parts)


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
