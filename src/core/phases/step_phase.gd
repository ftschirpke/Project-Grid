class_name StepPhase
extends Resource
## One phase of a world step. The ordered list lives in GameRules.phases
## (data/rules.tres). A new phase is one new script extending this, added to
## that list. Phases after a win or loss are skipped.


## Run only on the last step of a turn (see GameRules.player_moves_per_turn).
@export var turn_end_only := false


func run(_state: GameState, _ctx: StepContext) -> void:
	pass
