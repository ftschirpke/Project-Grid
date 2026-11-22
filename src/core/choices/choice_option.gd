class_name ChoiceOption
extends Resource
## Base class for one option of a pickup choice. A new kind of reward is one
## new script extending this.

@export var label := ""
@export var description := ""


func get_label(_state: GameState) -> String:
	return label


func get_description(_state: GameState) -> String:
	return description


## Options that make no sense right now are not offered.
func is_available(_state: GameState) -> bool:
	return true


func apply(_state: GameState) -> void:
	pass
