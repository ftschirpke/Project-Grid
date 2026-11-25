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
## Stop before the enemy phase of each turn until resume_enemy_phase() is
## called. Presentation only: the outcome is identical either way.
var pause_before_enemies := false
## Steps of the current key press still to run (several on slow terrain).
var _queue: Array[StepContext] = []
## Index of the phase the paused step continues with, or -1.
var _paused_at := -1


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
	_queue.clear()
	_paused_at = -1
	state = RoomLoader.build(config, _room_text, tile_types, enemy_types)
	state.update_vision()
	state.update_activation()


## Handles one direction key. Returns true if time passed.
func try_move(dir: int) -> bool:
	if state.status != GameState.Status.PLAYING or state.current_choice() != null or is_enemy_phase_pending():
		return false
	var target := state.player.pos + Grid.vec(dir)
	if not state.can_player_enter(target):
		if state.player_has_valid_move():
			return false
		match config.rules.boxed_in:
			GameRules.BoxedIn.PASS_TURN:
				_queue.append(StepContext.new())
				_run_queue()
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
		_queue.append(ctx)
	_run_queue()
	return true


## True while the game waits (pause_before_enemies) for the enemy phase.
func is_enemy_phase_pending() -> bool:
	return _paused_at >= 0


## Runs the enemy phase the game paused before, and any steps of the same key
## press after it. Returns false if nothing was pending.
func resume_enemy_phase() -> bool:
	if not is_enemy_phase_pending():
		return false
	var from := _paused_at
	_paused_at = -1
	if _run_step(_queue[0], from):
		_queue.pop_front()
		_run_queue()
	return true


## Applies option `index` of the open pick-one-of-N choice.
func choose(index: int) -> bool:
	return state.resolve_choice(index)


## What moving in `dir` would do right now:
## { valid: bool, dir: int, target: Vector2i, ends_turn: bool,
##   hits: [{ ability, tiles }] }
## Abilities only fire on the last move of a turn, so `hits` is empty on the
## others.
func preview(dir: int) -> Dictionary:
	var target := state.player.pos + Grid.vec(dir)
	var result := {"valid": state.can_player_enter(target), "dir": dir, "target": target, "ends_turn": false, "hits": []}
	if not result.valid:
		return result
	var per_turn := _moves_per_turn()
	var steps_after := state.turn_step + state.move_cost(state.player, target)
	result.ends_turn = steps_after % per_turn == 0
	if not result.ends_turn:
		return result
	# A move that spills over into a later turn (slow terrain) starts that turn.
	var turn_start := state.turn_start_index if steps_after <= per_turn else state.history.size()
	var hypothetical := state.history.duplicate()
	hypothetical.append(dir)
	for m in state.ability_matches(hypothetical, turn_start):
		result.hits.append({
			"ability": m.ability,
			"tiles": state.effect_tiles(m.ability, target, m.rotation),
		})
	return result


## Steps the player takes before the world reacts once.
func _moves_per_turn() -> int:
	return maxi(1, config.rules.player_moves_per_turn)


## Runs queued steps until the queue is empty or a step pauses.
func _run_queue() -> void:
	while not _queue.is_empty():
		if state.status != GameState.Status.PLAYING:
			_queue.clear()
			break
		if not _run_step(_queue[0]):
			return
		_queue.pop_front()
	state.reserved_tile = GameState.NO_TILE


## Runs one world step from phase `from`. Returns false if it paused before
## the enemy phase; resume_enemy_phase() continues it.
func _run_step(ctx: StepContext, from := 0) -> bool:
	var phases := config.rules.phases
	if from == 0:
		ctx.ends_turn = state.turn_step + 1 >= _moves_per_turn()
		state.begin_step()
	for i in range(from, phases.size()):
		if state.status != GameState.Status.PLAYING:
			break
		var phase := phases[i]
		if phase == null or (phase.turn_end_only and not ctx.ends_turn):
			continue
		if i != from and phase.opens_enemy_phase and _should_pause():
			_paused_at = i
			state.emit_event(&"enemy_phase_pending")
			return false
		phase.run(state, ctx)
	_finish_step(ctx)
	return true


## Pause only when something will visibly act, so empty turns stay instant.
func _should_pause() -> bool:
	if not pause_before_enemies:
		return false
	if not state.projectiles.is_empty():
		return true
	for e in state.enemies:
		if e.is_alive() and e.active:
			return true
	return false


func _finish_step(ctx: StepContext) -> void:
	if ctx.ends_turn:
		state.turn_count += 1
		state.turn_step = 0
		state.turn_start_index = state.history.size()
	else:
		state.turn_step += 1
	state.emit_event(&"step_finished")
