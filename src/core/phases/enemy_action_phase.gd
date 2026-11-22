class_name EnemyActionPhase
extends StepPhase
## Step 5a: every active enemy decides from the same board state, then all
## actions are executed. Stunned enemies skip their action instead.


func run(state: GameState, _ctx: StepContext) -> void:
	var actors: Array[Unit] = []
	var actions: Array[UnitAction] = []
	for enemy in state.enemies:
		if not enemy.is_alive() or not enemy.active:
			continue
		if enemy.stun > 0:
			enemy.stun -= 1
			continue
		if enemy.def == null or enemy.def.behavior == null:
			continue
		var action := enemy.def.behavior.decide(enemy, state)
		if action != null:
			actors.append(enemy)
			actions.append(action)
	for i in actions.size():
		actions[i].execute(actors[i], state)
