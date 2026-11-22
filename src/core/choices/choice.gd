class_name Choice
extends RefCounted
## An open pick-one-of-N decision. The world is paused while one is pending.

var title := ""
var options: Array[ChoiceOption] = []


func _init(choice_title: String, choice_options: Array[ChoiceOption]) -> void:
	title = choice_title
	options = choice_options
