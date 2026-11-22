class_name VisionPhase
extends StepPhase
## Step 7: vision and fog are updated.


func run(state: GameState, _ctx: StepContext) -> void:
	state.update_vision()
