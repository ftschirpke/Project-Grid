class_name TileExitEffect
extends TileEffect
## Marks the exit as reached; the win check phase turns that into a win.


func is_terrain() -> bool:
	return false


func apply(state: GameState, unit: Unit, _pos: Vector2i) -> void:
	if unit.is_player:
		state.exit_reached = true
