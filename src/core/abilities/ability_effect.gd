class_name AbilityEffect
extends Resource
## Base class for one composable effect of an ability. A new effect kind is
## one new script extending this; every ability can then list it.

## Optional own area for this effect, written like AbilityDef.area (offsets
## from the end tile, canonical orientation, x right, y UP). Leave empty to
## use the ability's area. Lets one ability stun around the player and deal
## damage in front, for example.
@export var area: Array[Vector2i] = []


## Short identifier that upgrades use to find this effect (e.g. &"damage").
func kind() -> StringName:
	return &""


## `tiles` are the board tiles of the ability's area, already rule-filtered.
func apply(_state: GameState, _source: Unit, _tiles: Array[Vector2i]) -> void:
	pass


func describe() -> String:
	return ""
