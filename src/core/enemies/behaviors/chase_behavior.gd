class_name ChaseBehavior
extends EnemyBehavior
## Melee: walks the shortest path to the player and attacks when adjacent.

@export var damage := 1
## After a step, also strike the next tile in the walking direction, so the
## enemy threatens the player from two tiles away.
@export var attack_after_move := false
## Path around tiles flagged `enemies_avoid` (hazards) when another way exists.
@export var avoid_hazards := true


func decide(unit: Unit, state: GameState) -> UnitAction:
	var target := state.player.pos
	if Grid.manhattan(unit.pos, target) == 1:
		var tiles: Array[Vector2i] = [target]
		return UnitActions.Attack.new(tiles, damage)
	var next := Pathing.next_step(state, unit, target, avoid_hazards)
	if next != unit.pos:
		if attack_after_move:
			return UnitActions.MoveAndAttack.new(next, damage)
		return UnitActions.Move.new(next)
	return null
