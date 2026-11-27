class_name EnemyDef
extends Resource
## An enemy type: shared stats plus a pluggable behaviour. New enemy types are
## new .tres files in data/enemies; attack parameters live on the behaviour.

@export var id: StringName
@export var display_name := ""
## Character that places this enemy in a room file.
@export var symbol := "e"
@export var color := Color(0.63, 0.0, 0.15)
@export_range(1, 99) var max_health := 1
## Idle until the player comes this close (capped by the vision radius).
@export var activation_range := 5.0
@export var behavior: EnemyBehavior
