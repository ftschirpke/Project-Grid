class_name PatternMatcher
extends RefCounted
## Pure pattern matching on the move history (DESIGN.md section 6.1).
## Used for real triggers and for the next-move preview alike.


class Match extends RefCounted:
	var ability: AbilityDef
	var rotation := 0 ## clockwise quarter turns from the canonical pattern
	var mirrored := false ## left-right mirror image, applied before the rotation
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
	var orientation := _orientation(history, start, length, ability)
	if orientation.x < 0:
		return null
	var m := Match.new()
	m.ability = ability
	m.rotation = orientation.x
	m.mirrored = orientation.y == 1
	m.start_index = start
	return m


## How many moves of the pattern the player has walked so far: the longest
## beginning of the pattern (shorter than the whole) that the latest moves
## match and that can still become a trigger. 0 if there is none.
## Counts only what the rules allow: nothing the ability's previous trigger
## used. With `turn_length` > 0 (abilities fire only at the end of a turn) the
## pattern must also end on the last move of a turn, a pattern no longer than
## a turn inside the current one; `turn_step` is the number of steps already
## taken in the current turn, and the moves still missing are assumed to cost
## one step each.
static func progress(history: Array[int], ability: AbilityDef, last_trigger_index: int, turn_start := 0, turn_step := 0, turn_length := 0) -> int:
	var length := ability.pattern.size()
	for count in range(mini(length - 1, history.size()), 0, -1):
		var start := history.size() - count
		if start <= last_trigger_index:
			continue
		var missing := length - count
		if turn_length <= 0:
			pass
		elif length <= turn_length:
			if start < turn_start or turn_step + missing != turn_length:
				continue
		elif (turn_step + missing) % turn_length != 0:
			continue
		if _orientation(history, start, count, ability).x >= 0:
			return count
	return 0


## The orientation in which the first `count` moves of the pattern equal the
## history from `start` on, as (rotation, 1 if mirrored else 0), or (-1, 0).
## The pattern as written wins over its mirror image, so symmetric patterns
## behave the same with or without `mirrorable`.
static func _orientation(history: Array[int], start: int, count: int, ability: AbilityDef) -> Vector2i:
	for attempt in (2 if ability.mirrorable else 1):
		var mirrored := attempt == 1
		for rotation in ability.rotation_count():
			var matches := true
			for i in count:
				var dir: int = ability.pattern[i]
				if mirrored:
					dir = Grid.mirror_dir(dir)
				if history[start + i] != Grid.rotate_dir(dir, rotation):
					matches = false
					break
			if matches:
				return Vector2i(rotation, 1 if mirrored else 0)
	return Vector2i(-1, 0)
