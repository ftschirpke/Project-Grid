class_name GameConfig
extends Resource
## Root configuration: points at everything a run needs. See data/game.tres.

@export var rules: GameRules
@export var player: PlayerConfig
@export_file("*.txt") var room_file := "res://data/rooms/room_01.txt"
## Every TileDef / EnemyDef resource in these folders is loaded automatically
## and placed in rooms through its `symbol`.
@export_dir var tiles_dir := "res://data/tiles"
@export_dir var enemies_dir := "res://data/enemies"
## Tile placed under the player start, under enemies and for unknown symbols.
@export var default_tile_symbol := "."
@export var player_symbol := "P"
## 0 picks a different seed on every run.
@export var random_seed := 0
