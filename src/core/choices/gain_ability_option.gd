class_name GainAbilityOption
extends ChoiceOption
## Adds a new ability to the end of the player's ability list.

@export var ability: AbilityDef


func get_label(_state: GameState) -> String:
	return label if label != "" else "New ability: %s" % ability.display_name


func get_description(_state: GameState) -> String:
	if description != "":
		return description
	var moves: PackedStringArray = []
	for dir in ability.pattern:
		moves.append(Grid.NAMES[dir])
	return "%s  (%s)" % [ability.describe(), ", ".join(moves)]


func is_available(state: GameState) -> bool:
	return ability != null and state.find_ability(ability.id) == null


func apply(state: GameState) -> void:
	state.abilities.append(ability.instantiate())
