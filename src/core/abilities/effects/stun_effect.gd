class_name StunEffect
extends AbilityEffect

## Number of actions the target skips.
@export var turns := 1


func kind() -> StringName:
	return &"stun"


func apply(state: GameState, source: Unit, tiles: Array[Vector2i]) -> void:
	for unit in state.targets_on(tiles, source):
		state.stun_unit(unit, turns)


func describe() -> String:
	return "%d turn stun" % turns
