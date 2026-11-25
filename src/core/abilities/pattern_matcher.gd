class_name PatternMatcher
extends RefCounted
## Pure pattern matching on the move history (DESIGN.md section 6.1).
## Used for real triggers and for the next-move preview alike.


class Match extends RefCounted:
	var ability: AbilityDef
	var rotation := 0 ## clockwise quarter turns from the canonical pattern
	var start_index := 0 ## history index of the first move of the match


## All abilities whose pattern is completed by the last move in `history`,
## in ability-list order. `last_trigger` maps ability id -> history index of
## the final move of that ability's previous trigger.
## With `turn_length` > 0, a pattern of at most that many moves only matches if
## it starts at or after `turn_start`, i.e. lies inside the current turn.
static func find_matches(history: Array[int], abilities: Array[AbilityDef], last_trigger: Dictionary, turn_start := 0, turn_length := 0) -> Array[Match]:
	var out: Array[Match] = []
	for ability in abilities:
		var earliest := 0
		if turn_length > 0 and ability.pattern.size() <= turn_length:
			earliest = turn_start
		var m := match_ability(history, ability, last_trigger.get(ability.id, -1), earliest)
		if m != null:
			out.append(m)
	return out


static func match_ability(history: Array[int], ability: AbilityDef, last_trigger_index: int, earliest_start := 0) -> Match:
	var length := ability.pattern.size()
	if length == 0 or history.size() < length:
		return null
	var start := history.size() - length
	# An ability cannot overlap with itself: every move of the new match must
	# come after the previous trigger of the same ability.
	if start <= last_trigger_index or start < earliest_start:
		return null
	for rotation in ability.rotation_count():
		var matches := true
		for i in length:
			if history[start + i] != Grid.rotate_dir(ability.pattern[i], rotation):
				matches = false
				break
		if matches:
			var m := Match.new()
			m.ability = ability
			m.rotation = rotation
			m.start_index = start
			return m
	return null
