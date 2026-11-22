class_name RemoveDeadPhase
extends StepPhase
## Step 3: killed enemies leave the board before they can act.


func run(state: GameState, _ctx: StepContext) -> void:
	state.remove_dead_enemies()
