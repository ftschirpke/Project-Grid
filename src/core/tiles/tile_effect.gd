class_name TileEffect
extends Resource
## Base class for something a tile does to a unit. A new tile effect is one
## new script extending this.


## Terrain effects obey the "terrain affects player / enemies" rule switches.
## Return false for effects that must always run (exit, pickups).
func is_terrain() -> bool:
	return true


func apply(_state: GameState, _unit: Unit, _pos: Vector2i) -> void:
	pass
