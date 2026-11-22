class_name TileDamageEffect
extends TileEffect

@export var amount := 1


func apply(state: GameState, unit: Unit, _pos: Vector2i) -> void:
	state.damage_unit(unit, amount)
