class_name LoseCheckPhase
extends StepPhase
## Step 6: the player loses at zero health.


func run(state: GameState, _ctx: StepContext) -> void:
	if not state.player.is_alive():
		state.lose("Out of health")
