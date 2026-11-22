class_name ShootBehavior
extends EnemyBehavior
## Ranged: fires a stepping projectile along its row or column when the player
## is lined up with nothing in the way, otherwise moves to line up.

## Maximum distance (tiles) at which it fires.
@export var max_range := 8
## Fires at most once every this many steps.
@export var fire_interval := 3
## Tiles the projectile travels per step.
@export var projectile_speed := 1
@export var projectile_damage := 1
@export var avoid_hazards := true


func decide(unit: Unit, state: GameState) -> UnitAction:
	var cooldown: int = unit.memory.get("cooldown", 0)
	if cooldown > 0:
		unit.memory["cooldown"] = cooldown - 1

	var dir := _firing_direction(unit.pos, state.player.pos, state)
	if dir >= 0:
		if cooldown > 0:
			return null
		unit.memory["cooldown"] = fire_interval - 1
		return UnitActions.Shoot.new(dir, projectile_speed, projectile_damage)

	var next := _line_up_step(unit, state)
	if next != unit.pos:
		return UnitActions.Move.new(next)
	return null


## Direction to fire in, or -1 if there is no clear shot.
func _firing_direction(from: Vector2i, to: Vector2i, state: GameState) -> int:
	var delta := to - from
	if (delta.x != 0) == (delta.y != 0):
		return -1
	if absi(delta.x) + absi(delta.y) > max_range:
		return -1
	var step := Vector2i(signi(delta.x), signi(delta.y))
	var pos := from + step
	while pos != to:
		if state.tile_at(pos).blocks_projectiles:
			return -1
		pos += step
	return Grid.VECTORS.find(step)


func _line_up_step(unit: Unit, state: GameState) -> Vector2i:
	var delta := state.player.pos - unit.pos
	if delta.x != 0 and delta.y != 0:
		# Close the smaller offset first: the quickest way into a firing line.
		var along_x := unit.pos + Vector2i(signi(delta.x), 0)
		var along_y := unit.pos + Vector2i(0, signi(delta.y))
		var first := along_x if absi(delta.x) <= absi(delta.y) else along_y
		var second := along_y if first == along_x else along_x
		for option: Vector2i in [first, second]:
			if state.can_enemy_enter(option, unit) and not _avoided(option, state):
				return option
	# Lined up but blocked or out of range, or both sidesteps are blocked.
	return Pathing.next_step(state, unit, state.player.pos, avoid_hazards)


func _avoided(pos: Vector2i, state: GameState) -> bool:
	return avoid_hazards and state.rules.terrain_affects_enemies and state.tile_at(pos).enemies_avoid
