class_name TileEndStepPhase
extends StepPhase
## Tiles act on whoever ends the step standing on them (hazards).


func run(state: GameState, _ctx: StepContext) -> void:
	for unit in state.all_units():
		if unit.is_alive():
			state.run_tile_effects(state.tile_at(unit.pos).on_end_step, unit, unit.pos)
