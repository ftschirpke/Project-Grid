class_name PlayerConfig
extends Resource

@export var max_health := 3
@export var vision_radius := 6.0
@export var color := Color(0.05, 0.3, 0.9)
## Order matters: abilities triggered by the same move resolve in this order.
@export var starting_abilities: Array[AbilityDef] = []
