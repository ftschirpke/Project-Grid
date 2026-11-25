class_name TriggerAbilitiesPhase
extends StepPhase
## Step 2: abilities completed by this move trigger, in ability-list order.
## Flagged `turn_end_only` in rules.tres, so only the last move of a turn
## can complete a pattern.


func run(state: GameState, ctx: StepContext) -> void:
	if not ctx.moved:
		return
	var last_index := state.history.size() - 1
	for m in state.ability_matches(state.history, state.turn_start_index):
		state.last_trigger[m.ability.id] = last_index
		var tiles := state.effect_tiles(m.ability, state.player.pos, m.rotation)
		state.emit_event(&"ability_fired", {"ability": m.ability, "tiles": tiles, "rotation": m.rotation})
		for effect in m.ability.effects:
			effect.apply(state, state.player, state.effect_tiles(m.ability, state.player.pos, m.rotation, effect))
		if state.rules.abilities_destroy_projectiles:
			state.destroy_projectiles_on(tiles)
