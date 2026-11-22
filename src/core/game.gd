class_name Game
extends RefCounted
## Entry point of the rules layer: owns the configuration and the current
## GameState, turns a direction input into world steps, and answers preview
## queries. Usable without a scene tree (see tests/run_tests.gd).

var config: GameConfig
var state: GameState
var tile_types: Array[TileDef] = []
var enemy_types: Array[EnemyDef] = []
var _room_text := ""


## `room_text` overrides the configured room file (used by tests).
func _init(game_config: GameConfig, room_text: String = "") -> void:
	config = game_config
	for res in ContentLoader.load_dir(config.tiles_dir):
		if res is TileDef:
			tile_types.append(res)
	for res in ContentLoader.load_dir(config.enemies_dir):
		if res is EnemyDef:
			enemy_types.append(res)
	_room_text = room_text if room_text != "" else FileAccess.get_file_as_string(config.room_file)
	restart()


## Rebuilds the room from scratch. `state` is a new object afterwards.
func restart() -> void:
	state = RoomLoader.build(config, _room_text, tile_types, enemy_types)
	state.update_vision()
	state.update_activation()


## Handles one direction key. Returns true if time passed.
func try_move(dir: int) -> bool:
	if state.status != GameState.Status.PLAYING or state.current_choice() != null:
		return false
	var target := state.player.pos + Grid.vec(dir)
	if not state.can_player_enter(target):
		if state.player_has_valid_move():
			return false
		match config.rules.boxed_in:
			GameRules.BoxedIn.PASS_TURN:
				_run_step(StepContext.new())
				return true
			GameRules.BoxedIn.LOSE:
				state.lose("Boxed in")
				return true
		return false

	# Slow terrain: one key press commits to the move for several world steps.
	var cost := state.move_cost(state.player, target)
	state.reserved_tile = target
	for i in cost:
		var ctx := StepContext.new()
		ctx.dir = dir
		ctx.target = target
		ctx.completes_move = i == cost - 1
		_run_step(ctx)
		if state.status != GameState.Status.PLAYING:
			break
	state.reserved_tile = GameState.NO_TILE
	return true


## Applies option `index` of the open pick-one-of-N choice.
func choose(index: int) -> bool:
	return state.resolve_choice(index)


## What moving in `dir` would do right now:
## { valid: bool, dir: int, target: Vector2i, hits: [{ ability, tiles }] }
func preview(dir: int) -> Dictionary:
	var target := state.player.pos + Grid.vec(dir)
	var result := {"valid": state.can_player_enter(target), "dir": dir, "target": target, "hits": []}
	if not result.valid:
		return result
	var hypothetical := state.history.duplicate()
	hypothetical.append(dir)
	for m in PatternMatcher.find_matches(hypothetical, state.abilities, state.last_trigger):
		result.hits.append({
			"ability": m.ability,
			"tiles": state.effect_tiles(m.ability, target, m.rotation),
		})
	return result


func _run_step(ctx: StepContext) -> void:
	state.begin_step()
	for phase in config.rules.phases:
		if state.status != GameState.Status.PLAYING:
			break
		if phase != null:
			phase.run(state, ctx)
	state.emit_event(&"step_finished")
