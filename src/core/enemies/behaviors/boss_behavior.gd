class_name BossBehavior
extends EnemyBehavior
## Wraps another behaviour and adds a telegraphed area attack: every
## `slam_interval` actions it marks the square around itself, and on its next
## action it damages everything hostile on the marked tiles.

## What the boss does between slams (for example a ChaseBehavior).
@export var base: EnemyBehavior
## Actions between two telegraphs.
@export_range(1, 99) var slam_interval := 4
## 1 marks the 3x3 around the boss, 2 the 5x5, and so on.
@export var slam_radius := 1
@export var slam_damage := 2


func decide(unit: Unit, state: GameState) -> UnitAction:
	if unit.memory.get("slam_armed", false):
		unit.memory["slam_armed"] = false
		return UnitActions.Attack.new(unit.telegraph.duplicate(), slam_damage)

	var timer: int = unit.memory.get("slam_timer", slam_interval) - 1
	if timer <= 0:
		unit.memory["slam_timer"] = slam_interval
		unit.memory["slam_armed"] = true
		var tiles: Array[Vector2i] = []
		for dy in range(-slam_radius, slam_radius + 1):
			for dx in range(-slam_radius, slam_radius + 1):
				var pos := unit.pos + Vector2i(dx, dy)
				if state.in_bounds(pos) and not state.tile_at(pos).blocks_movement:
					tiles.append(pos)
		return UnitActions.Telegraph.new(tiles)

	unit.memory["slam_timer"] = timer
	return base.decide(unit, state) if base != null else null
