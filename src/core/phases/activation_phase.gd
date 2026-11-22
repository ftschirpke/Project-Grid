class_name ActivationPhase
extends StepPhase
## Idle enemies in range wake up. Runs after vision, at the end of the step,
## so a newly activated enemy takes its first action on the next step.


func run(state: GameState, _ctx: StepContext) -> void:
	state.update_activation()
