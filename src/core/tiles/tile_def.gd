class_name TileDef
extends Resource
## A tile type. Everything a tile does is described here, so hazard, slow,
## exit and pickups are data, not special cases in the movement code.
## New tile types are new .tres files in data/tiles.

@export var id: StringName
@export var display_name := ""
## Character that places this tile in a room file.
@export var symbol := "."
@export var color := Color.WHITE
## Short text drawn on the tile (keep to plain letters and punctuation).
@export var label := ""

@export_group("Blocking")
@export var blocks_movement := false
@export var blocks_sight := false
@export var blocks_projectiles := false

@export_group("Behaviour")
## World steps needed to enter the tile. 2 or more makes it slow terrain: the
## unit commits to the move and arrives on the last step.
@export_range(1, 5) var move_cost := 1
## Enemy pathfinding goes around this tile when it can.
@export var enemies_avoid := false
## Shown on the map from the start, even under fog.
@export var always_visible := false
## Run when a unit moves onto the tile.
@export var on_enter: Array[TileEffect] = []
## Run for a unit standing on the tile at the end of every step.
@export var on_end_step: Array[TileEffect] = []
