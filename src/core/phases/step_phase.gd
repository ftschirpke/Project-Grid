class_name StepPhase
extends Resource
## One phase of a world step. The ordered list lives in GameRules.phases
## (data/rules.tres). A new phase is one new script extending this, added to
## that list. Phases after a win or loss are skipped.


func run(_state: GameState, _ctx: StepContext) -> void:
	pass
