class_name DamageEffect
extends AbilityEffect

@export var amount := 1


func kind() -> StringName:
	return &"damage"


func apply(state: GameState, source: Unit, tiles: Array[Vector2i]) -> void:
	for unit in state.targets_on(tiles, source):
		state.damage_unit(unit, amount, source)


func describe() -> String:
	return "%d damage" % amount
