class_name PlayerMovePhase
extends StepPhase
## Step 1: the player moves and the move is appended to the history.


func run(state: GameState, ctx: StepContext) -> void:
	if ctx.dir < 0 or not ctx.completes_move:
		return
	if not state.can_player_enter(ctx.target):
		return
	state.history.append(ctx.dir)
	state.move_player(ctx.target)
	ctx.moved = true
