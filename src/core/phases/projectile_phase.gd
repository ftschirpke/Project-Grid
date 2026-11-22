class_name ProjectilePhase
extends StepPhase
## Step 5b: projectiles advance. A projectile hits when it enters the player's
## tile or when the two swap tiles in the same step. Walls destroy it.


func run(state: GameState, _ctx: StepContext) -> void:
	var player := state.player
	for p in state.projectiles:
		var step := Grid.vec(p.dir)
		var swapped := player.pos != player.prev_pos and p.pos == player.pos and p.pos + step == player.prev_pos
		if swapped:
			_hit(state, p)
			continue
		for i in p.speed:
			var next := p.pos + step
			if not state.in_bounds(next) or state.tile_at(next).blocks_projectiles:
				p.alive = false
				break
			p.pos = next
			if next == player.pos:
				_hit(state, p)
				break
	var remaining: Array[Projectile] = []
	for p in state.projectiles:
		if p.alive:
			remaining.append(p)
	state.projectiles = remaining


func _hit(state: GameState, p: Projectile) -> void:
	p.alive = false
	state.emit_event(&"projectile_hit", {"projectile": p, "unit": state.player})
	state.damage_unit(state.player, p.damage, p.source)
