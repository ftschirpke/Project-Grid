class_name StepPhase
extends Resource
## One phase of a world step. The ordered list lives in GameRules.phases
## (data/rules.tres). A new phase is one new script extending this, added to
## that list. Phases after a win or loss are skipped.


## Run only on the last step of a turn (see GameRules.player_moves_per_turn).
@export var turn_end_only := false
## The enemy phase of a turn starts here. Game can pause before this phase
## (Game.pause_before_enemies) so the view can show the two halves apart.
@export var opens_enemy_phase := false


func run(_state: GameState, _ctx: StepContext) -> void:
	pass
