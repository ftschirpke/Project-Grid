extends SceneTree
## Headless smoke test of the view: starts the real main scene, opens the
## sandbox layer, edits through the same handlers the buttons call, closes it
## and checks that the room restarted with the edits and that they were saved.
## It cannot see pixels; it catches script errors and broken wiring. Run with:
##   godot --headless --path . --script res://tests/run_view_smoke.gd
## Uses its own files in local/ and removes them, so a real sandbox design is
## left alone.

const DESIGN := "res://local/_smoke_design.tres"
const SETTINGS := "res://local/_smoke_settings.cfg"

var _failures := 0
var _checks := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, what: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("FAIL  %s" % what)


func _key(keycode: Key, ctrl := false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.ctrl_pressed = ctrl
	event.pressed = true
	root.push_input(event)


## A real left click at `at` (viewport coordinates), routed like a mouse click.
func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		root.push_input(event, true)


## Clicks the first visible button under `parent` with this text.
func _click_button(parent: Node, text: String) -> void:
	await process_frame
	for button: BaseButton in parent.find_children("*", "BaseButton", true, false):
		if button.get("text") == text and button.is_visible_in_tree():
			_click(button.get_global_rect().get_center())
			break
	await process_frame
	await process_frame


## Controls of the layer that reach outside the window, as readable text.
func _outside(layer: Control) -> String:
	var window := Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(0.5)
	var out: PackedStringArray = []
	for control: Control in layer.find_children("*", "Control", true, false):
		if not control.is_visible_in_tree() or control.get_parent() is ScrollContainer:
			continue
		var inside_scroll := false
		var up := control.get_parent()
		while up != null and up != layer:
			if up is ScrollContainer or up is ItemList:
				inside_scroll = true
			up = up.get_parent()
		if not inside_scroll and not window.encloses(control.get_global_rect()):
			out.append("%s %s" % [control.get_class(), control.get_global_rect()])
	return ", ".join(out)


func _start() -> Control:
	var main: Control = (load("res://src/view/main.tscn") as PackedScene).instantiate()
	main.design_path = DESIGN
	main.settings_path = SETTINGS
	root.add_child(main)
	return main


func _cleanup() -> void:
	for path: String in [DESIGN, SETTINGS]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _run() -> void:
	_cleanup()
	root.size = Vector2i(1280, 720)
	var main := _start()
	await process_frame
	await process_frame
	check(main.get_global_rect().size == Vector2(1280, 720), "the test window is 1280x720")
	var layer: SandboxLayer = main._sandbox
	check(not layer.visible, "layer starts closed")
	check(main.game.state.width == 16 and not main._design_edited, "plays the defaults")

	# D moves, Ctrl+D opens the layer, and the game ignores keys under it.
	var start: Vector2i = main.game.state.player.pos
	_key(KEY_D)
	await process_frame
	check(main.game.state.player.pos == start + Vector2i(1, 0), "D still moves right")
	_key(KEY_D, true)
	await process_frame
	check(layer.visible, "Ctrl+D opens the layer")
	check(main.game.state.player.pos == start + Vector2i(1, 0), "Ctrl+D is not a move")
	_key(KEY_W)
	await process_frame
	check(main.game.state.player.pos == start + Vector2i(1, 0), "no moves while the layer is open")

	# Closing without edits keeps the running room and saves nothing.
	var same_game: Game = main.game
	_key(KEY_D, true)
	await process_frame
	check(not layer.visible and main.game == same_game, "closing without edits keeps the room")
	check(not FileAccess.file_exists(DESIGN), "and writes no file")

	# Map: paint, place, resize.
	_key(KEY_D, true)
	await process_frame
	var design: Design = main._design
	await process_frame
	var canvas_size: Vector2 = layer._map._canvas.size
	check(canvas_size.x > 400 and canvas_size.y > 400, "the map canvas has room (%s)" % canvas_size)
	check(_outside(layer) == "", "map tab fits the window: %s" % _outside(layer))
	layer._map._canvas.brush = "#"
	layer._map._canvas._paint(Vector2i(0, 0), "#")
	layer._map._canvas._paint(Vector2i(1, 0), "c")
	layer._map._width.value = 10
	layer._map._height.value = 12
	check(design.cell(Vector2i(0, 0)) == "#" and design.cell(Vector2i(1, 0)) == "c", "canvas paints")
	check(design.width() == 10 and design.height() == 12, "size boxes resize")

	# Abilities: new, pattern, effect, own area, switches, duplicate, delete.
	var editor: AbilityEditor = layer._abilities
	var before := design.abilities.size()
	editor._new_ability()
	var made: AbilityDef = editor._selected
	check(design.abilities.size() == before + 1 and design.is_starting(made), "new ability, starting")
	made.pattern.append(Grid.Dir.UP)
	made.pattern.append(Grid.Dir.LEFT)
	editor._pattern_changed()
	made.mirrorable = true
	made.effects.append(StunEffect.new())
	editor._rebuild_detail()
	editor._set_own_area(made, made.effects[1], true)
	check(made.effects[1].area == made.area and editor._area_target == made.effects[1], "own area starts as a copy")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(AreaGrid.RADIUS + 1.5, AreaGrid.RADIUS + 0.5) * AreaGrid.CELL
	editor._grid._gui_input(click)
	check(made.effects[1].area.has(Vector2i(1, 0)) and not made.area.has(Vector2i(1, 0)), "grid edits the selected area only")
	editor._duplicate_ability()
	check(editor._selected != made and editor._selected.pattern == made.pattern, "duplicate")
	check(editor._selected.id != made.id, "with its own id")
	editor._delete_ability()
	check(design.abilities.size() == before + 1, "delete")
	await process_frame

	# Real mouse clicks: a list entry, then the New button.
	var tabs := layer.find_children("*", "TabContainer", true, false)[0] as TabContainer
	tabs.current_tab = 1
	await process_frame
	await process_frame
	var list: ItemList = editor._list
	_click(list.get_global_rect().position + list.get_item_rect(1).get_center())
	await process_frame
	check(editor._selected == design.abilities[1], "clicking a list entry selects it")
	check(list.is_selected(1), "and the list shows it")
	for button: Button in editor.find_children("*", "Button", true, false):
		if button.text == "New":
			_click(button.get_global_rect().get_center())
	await process_frame
	check(design.abilities.size() == before + 2, "clicking New adds an ability")
	# These buttons rebuild the panel they sit in from their own click.
	var fresh: AbilityDef = editor._selected
	await _click_button(editor, "+ Stun")
	check(fresh.effects.size() == 2 and fresh.effects[1] is StunEffect, "clicking + Stun adds the effect")
	await _click_button(editor, "Own area (otherwise the shared area)")
	check(not fresh.effects[0].area.is_empty() and editor._area_target == fresh.effects[0], "clicking Own area gives the effect an area")
	await _click_button(editor, "Remove")
	check(fresh.effects.size() == 1 and fresh.effects[0] is StunEffect, "clicking Remove removes the effect")
	check(editor._grid != null and editor._grid.is_inside_tree(), "and the panel is rebuilt")
	check(_outside(layer) == "", "abilities tab fits the window: %s" % _outside(layer))
	var detail_scroll := editor._detail.get_parent() as ScrollContainer
	check(editor._detail.size.x <= detail_scroll.size.x, "ability detail needs no sideways scrolling")
	print("ability detail: %s in a view of %s" % [editor._detail.size, detail_scroll.size])
	tabs.current_tab = 2
	await process_frame
	await process_frame
	check(_outside(layer) == "", "numbers tab fits the window: %s" % _outside(layer))
	check(layer._tuning._columns.size.x <= layer._tuning.size.x, "numbers need no sideways scrolling")
	print("numbers: %s in a view of %s" % [layer._tuning._columns.size, layer._tuning.size])
	tabs.current_tab = 1
	editor._delete_ability()
	editor._select(design.abilities[1])
	var kept: AbilityDef = editor._selected

	# Numbers: the generated fields write into the design.
	design.enemy_by_symbol("c").max_health = 5
	layer._tuning.bind(design)
	var spins := layer._tuning.find_children("*", "SpinBox", true, false)
	check(spins.size() >= 10, "number fields are generated (%d)" % spins.size())
	(spins[0] as SpinBox).value = 8
	check(design.player.max_health == 8, "first field is the player's health")
	layer._invulnerable.button_pressed = true
	check(design.invulnerable, "testing aid switches the design")
	await process_frame

	# Close: the room restarts with the edits and they are saved.
	_key(KEY_D, true)
	await process_frame
	var state: GameState = main.game.state
	check(not layer.visible and main.game != same_game, "closing with edits restarts the room")
	check(state.width == 10 and state.height == 12, "edited size is played")
	check(state.tile_at(Vector2i(0, 0)).id == &"wall", "edited tile is played")
	check(state.player.max_hp == 8, "edited health is played")
	check(state.abilities.size() == 3 and state.abilities[2].id == made.id, "new ability is played")
	check(main.game.config.rules.player_invulnerable, "testing aid is on")
	check(FileAccess.file_exists(DESIGN), "the design was saved")

	# A testing aid alone does not restart the room.
	var edited_game: Game = main.game
	_key(KEY_D, true)
	await process_frame
	check(editor._selected == kept and tabs.current_tab == 1, "reopening keeps the selection and the tab")
	layer._fog_off.button_pressed = true
	_key(KEY_D, true)
	await process_frame
	check(main.game == edited_game and not main.game.config.rules.fog_enabled, "fog off applies to the running room")
	check(main.game.state.is_visible(Vector2i(9, 0)), "everything is visible")

	# A number typed into a field but not confirmed with Enter still counts.
	_key(KEY_D, true)
	await process_frame
	(layer.find_children("*", "TabContainer", true, false)[0] as TabContainer).current_tab = 2
	await process_frame
	var typed := layer._tuning.find_children("*", "SpinBox", true, false)[0] as SpinBox
	typed.get_line_edit().grab_focus()
	check(typed.get_line_edit().has_focus(), "the field takes focus")
	typed.get_line_edit().text = "6"
	_key(KEY_D, true)
	await process_frame
	check(main._design.player.max_health == 6, "a typed number is applied on Ctrl+D")
	check(main.game != edited_game and main.game.state.player.max_hp == 6, "and played")
	check((Design.load_saved(DESIGN) as Design).player.max_health == 6, "and saved")

	# A new start loads the saved design.
	main.queue_free()
	await process_frame
	main = _start()
	await process_frame
	check(main._design_edited and main.game.state.width == 10, "saved design is loaded on start")
	check(main._design.fog_off and not main.game.config.rules.fog_enabled, "with its testing aids")

	# Reset returns to the defaults and removes the file.
	_key(KEY_D, true)
	await process_frame
	for button: Button in main._sandbox.find_children("*", "Button", true, false):
		if button.text == "Reset to defaults":
			_click(button.get_global_rect().get_center())
	await process_frame
	var dialog: ConfirmationDialog = main._sandbox._confirm_reset
	check(dialog.visible, "the reset button asks first")
	check(FileAccess.file_exists(DESIGN), "and nothing is reset before the answer")
	dialog.get_ok_button().pressed.emit()
	await process_frame
	check(main.game.state.width == 16 and main.game.state.abilities.size() == 2, "reset plays the defaults")
	check(not FileAccess.file_exists(DESIGN) and not main._design_edited, "reset removes the saved design")
	check(main._sandbox._map.design == main._design, "the layer shows the new design")
	main._toggle_enemy_phase()
	check(FileAccess.file_exists(SETTINGS), "settings are written inside the project")

	main.queue_free()
	await process_frame
	_cleanup()
	print("\n%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
