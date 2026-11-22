class_name EnemyBehavior
extends Resource
## Base class for enemy behaviours. The step resolution only knows this
## interface: once per step every active, unstunned enemy is asked for one
## action. All enemies decide from the same board state before any action is
## executed, so decide() must not change the board. The resource is shared by
## all enemies of a type; keep per-enemy state in `unit.memory`.


func decide(_unit: Unit, _state: GameState) -> UnitAction:
	return null
