class_name Pathing
extends RefCounted
## Shortest-path helpers for enemy behaviours.


## Breadth-first distances (in tiles) from `target` to every reachable tile.
## Units do not block; `avoid` skips tiles flagged `enemies_avoid`.
static func distance_map(state: GameState, target: Vector2i, avoid: bool) -> Dictionary:
	var dist := {target: 0}
	var queue: Array[Vector2i] = [target]
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		for v in Grid.VECTORS:
			var next := cur + v
			if dist.has(next) or not state.in_bounds(next):
				continue
			var tile := state.tile_at(next)
			if tile.blocks_movement or (avoid and tile.enemies_avoid):
				continue
			dist[next] = dist[cur] + 1
			queue.append(next)
	return dist


## The neighbouring tile that brings `unit` closer to `target` along a
## shortest path, or the unit's own tile if it cannot get closer.
static func next_step(state: GameState, unit: Unit, target: Vector2i, avoid_hazards: bool) -> Vector2i:
	if avoid_hazards and state.rules.terrain_affects_enemies:
		var safe := distance_map(state, target, true)
		if _reachable(safe, unit.pos):
			return _best_neighbour(state, unit, safe)
	return _best_neighbour(state, unit, distance_map(state, target, false))


static func _reachable(dist: Dictionary, pos: Vector2i) -> bool:
	if dist.has(pos):
		return true
	for v in Grid.VECTORS:
		if dist.has(pos + v):
			return true
	return false


static func _best_neighbour(state: GameState, unit: Unit, dist: Dictionary) -> Vector2i:
	var best := unit.pos
	var best_dist: int = dist.get(unit.pos, 1 << 30)
	for v in Grid.VECTORS:
		var next := unit.pos + v
		if dist.has(next) and dist[next] < best_dist and state.can_enemy_enter(next, unit):
			best = next
			best_dist = dist[next]
	return best
