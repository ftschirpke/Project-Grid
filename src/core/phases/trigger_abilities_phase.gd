class_name TriggerAbilitiesPhase
extends StepPhase
## Step 2: abilities completed by this move trigger, in ability-list order.
## Runs on every step; with the rule switch `abilities_only_at_turn_end` only
## the last move of a turn can complete a pattern.


func run(state: GameState, ctx: StepContext) -> void:
	if not ctx.moved:
		return
	if state.rules.abilities_only_at_turn_end and not ctx.ends_turn:
		return
	var last_index := state.history.size() - 1
	for m in state.ability_matches(state.history, state.turn_start_index):
		state.last_trigger[m.ability.id] = last_index
		var tiles := state.effect_tiles(m.ability, state.player.pos, m.rotation, null, m.mirrored)
		state.emit_event(&"ability_fired", {"ability": m.ability, "tiles": tiles, "rotation": m.rotation, "mirrored": m.mirrored})
		for effect in m.ability.effects:
			effect.apply(state, state.player, state.effect_tiles(m.ability, state.player.pos, m.rotation, effect, m.mirrored))
		if state.rules.abilities_destroy_projectiles:
			state.destroy_projectiles_on(tiles)
