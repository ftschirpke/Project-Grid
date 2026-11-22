class_name TilePickupEffect
extends TileEffect
## Opens a pick-one-of-N choice when the player steps on the tile.

@export var title := "Choose one"
## Options to draw from. Unavailable ones (see ChoiceOption) are skipped.
@export var options: Array[ChoiceOption] = []
## How many options are offered.
@export var offer_count := 3
## Offer a random selection instead of the first available ones.
@export var shuffle := false
## Symbol of the tile this one turns into once picked up ("" keeps the tile).
@export var becomes_symbol := "."


func is_terrain() -> bool:
	return false


func apply(state: GameState, unit: Unit, pos: Vector2i) -> void:
	if not unit.is_player:
		return
	var available: Array[ChoiceOption] = []
	for option in options:
		if option != null and option.is_available(state):
			available.append(option)
	if available.is_empty():
		return
	if shuffle:
		for i in range(available.size() - 1, 0, -1):
			var j := state.rng.randi_range(0, i)
			var tmp := available[i]
			available[i] = available[j]
			available[j] = tmp
	var offered: Array[ChoiceOption] = []
	for i in mini(offer_count, available.size()):
		offered.append(available[i])
	state.offer_choice(Choice.new(title, offered))
	if state.tile_types.has(becomes_symbol):
		state.set_tile(pos, state.tile_types[becomes_symbol])
