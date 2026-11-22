class_name WinCheckPhase
extends StepPhase
## Step 4: exit reached or no enemies left. Placed before the lose check, so
## the player wins a simultaneous kill.


func run(state: GameState, _ctx: StepContext) -> void:
	if state.rules.win_on_exit and state.exit_reached:
		state.win("Exit reached")
	elif state.rules.win_on_all_enemies_dead and state.enemies.is_empty():
		state.win("All enemies defeated")
