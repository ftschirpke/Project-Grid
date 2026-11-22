class_name UpgradeAbilityOption
extends ChoiceOption
## Changes one number on one effect of an ability the player owns, for
## example +1 `amount` on the `damage` effect of `l_strike`.

@export var ability_id: StringName
## AbilityEffect.kind() of the effect to change (&"damage", &"stun", ...).
@export var effect_kind: StringName = &"damage"
## Name of the exported number on that effect (`amount`, `turns`, ...).
@export var property: StringName = &"amount"
@export var delta := 1


func is_available(state: GameState) -> bool:
	return _find_effect(state) != null


func apply(state: GameState) -> void:
	var effect := _find_effect(state)
	if effect != null:
		effect.set(property, effect.get(property) + delta)


func _find_effect(state: GameState) -> AbilityEffect:
	var ability := state.find_ability(ability_id)
	if ability == null:
		return null
	for effect in ability.effects:
		if effect.kind() == effect_kind and effect.get(property) != null:
			return effect
	return null
