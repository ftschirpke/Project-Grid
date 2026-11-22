class_name AbilityDef
extends Resource
## An ability is data: a movement pattern, an effect area and a list of
## composable effects. New abilities are new .tres files in data/abilities.

@export var id: StringName
@export var display_name := ""
## Used for the panel, the next-move preview and the flash.
@export var color := Color(0.95, 0.3, 0.3)
## Canonical movement pattern; the ability fires when the most recent moves
## equal it (or one of its rotations).
@export var pattern: Array[Grid.Dir] = []
## Allow the pattern (and its area) in all four 90 degree rotations.
## Patterns are never mirrored.
@export var rotatable := true
## Affected tiles as offsets from the tile where the pattern ENDS, in the
## canonical orientation, written as in DESIGN.md: x to the right, y UP.
## "In front of the player" is the direction of the pattern's last move.
## An effect with its own `area` ignores this one.
@export var area: Array[Vector2i] = []
## Applied in order to the affected tiles.
@export var effects: Array[AbilityEffect] = []


func rotation_count() -> int:
	return 4 if rotatable else 1


## The area one effect uses: its own if it has one, otherwise the ability's.
func effect_area(effect: AbilityEffect) -> Array[Vector2i]:
	if effect != null and not effect.area.is_empty():
		return effect.area
	return area


## Every offset any effect of this ability touches (design convention, y up).
func combined_area() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for effect in effects:
		for offset in effect_area(effect):
			if not out.has(offset):
				out.append(offset)
	return out if not effects.is_empty() else area


## Area offsets in grid space (y down) for the given rotation. With `effect`
## the area of that effect, without it the combined area of all effects.
func area_offsets(rotation: int, effect: AbilityEffect = null) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for offset in (effect_area(effect) if effect != null else combined_area()):
		out.append(Grid.rotate_offset(Grid.design_to_grid(offset), rotation))
	return out


func area_tiles(anchor: Vector2i, rotation: int, effect: AbilityEffect = null) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for offset in area_offsets(rotation, effect):
		out.append(anchor + offset)
	return out


func describe() -> String:
	var parts: PackedStringArray = []
	for effect in effects:
		if effect != null:
			parts.append(effect.describe())
	return ", ".join(parts)


## Independent runtime copy, so upgrades never touch the data file.
func instantiate() -> AbilityDef:
	var copy: AbilityDef = duplicate()
	var own_effects: Array[AbilityEffect] = []
	for effect in effects:
		if effect != null:
			own_effects.append(effect.duplicate())
	copy.effects = own_effects
	copy.pattern = pattern.duplicate()
	copy.area = area.duplicate()
	return copy
