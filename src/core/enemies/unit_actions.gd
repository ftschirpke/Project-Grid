class_name UnitActions
extends RefCounted
## Stock actions that behaviours can return.


## Step onto an adjacent tile (takes several steps on slow terrain).
class Move extends UnitAction:
	var target: Vector2i

	func _init(target_tile: Vector2i) -> void:
		target = target_tile

	func execute(unit: Unit, state: GameState) -> void:
		state.try_move_enemy(unit, target)


## Step onto an adjacent tile, then strike the next tile in the same
## direction. The strike only happens if the step succeeded and something
## hostile stands there.
class MoveAndAttack extends UnitAction:
	var target: Vector2i
	var damage: int

	func _init(target_tile: Vector2i, amount: int) -> void:
		target = target_tile
		damage = amount

	func execute(unit: Unit, state: GameState) -> void:
		var step := target - unit.pos
		if not state.try_move_enemy(unit, target):
			return
		var ahead: Array[Vector2i] = [unit.pos + step]
		if state.targets_on(ahead, unit).is_empty():
			return
		Attack.new(ahead, damage).execute(unit, state)


## Damage everything hostile on the given tiles. Clears the unit's telegraph.
class Attack extends UnitAction:
	var tiles: Array[Vector2i]
	var damage: int

	func _init(target_tiles: Array[Vector2i], amount: int) -> void:
		tiles = target_tiles
		damage = amount

	func execute(unit: Unit, state: GameState) -> void:
		unit.telegraph = []
		state.emit_event(&"attack", {"unit": unit, "tiles": tiles})
		for target in state.targets_on(tiles, unit):
			state.damage_unit(target, damage, unit)


## Launch a projectile from the unit's tile.
class Shoot extends UnitAction:
	var dir: int
	var speed: int
	var damage: int

	func _init(direction: int, tiles_per_step: int, amount: int) -> void:
		dir = direction
		speed = tiles_per_step
		damage = amount

	func execute(unit: Unit, state: GameState) -> void:
		state.spawn_projectile(unit.pos, dir, speed, damage, unit)


## Mark tiles as a visible warning for an attack on a later step.
class Telegraph extends UnitAction:
	var tiles: Array[Vector2i]

	func _init(marked_tiles: Array[Vector2i]) -> void:
		tiles = marked_tiles

	func execute(unit: Unit, _state: GameState) -> void:
		unit.telegraph = tiles
