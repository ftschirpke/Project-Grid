class_name GameState
extends RefCounted
## The complete state of one room plus the queries and mutations the rules
## need. No dependency on rendering or input: the view only reads this object
## and listens to `event`.

## Everything worth showing or logging. Types used by the core:
## ability_fired {ability, tiles, rotation, mirrored} · damaged {unit, amount, pos, source}
## died {unit, pos} · attack {unit, tiles} · activated {unit}
## projectile_spawned {projectile} · projectile_hit {projectile, unit}
## choice_opened {choice} · choice_resolved {option}
## won {reason} · lost {reason} · step_finished {}
signal event(type: StringName, data: Dictionary)

enum Status { PLAYING, WON, LOST }

const NO_TILE := Vector2i(-9999, -9999)

var rules: GameRules
var width := 0
var height := 0
var tiles: Array[TileDef] = []
var tile_types: Dictionary = {} ## symbol -> TileDef

var player: Unit
var player_color := Color.BLUE
var vision_radius := 6.0
var enemies: Array[Unit] = []
var projectiles: Array[Projectile] = []

## Runtime copies of the player's abilities; upgrades modify these.
var abilities: Array[AbilityDef] = []
## Successful player moves (Grid.Dir values). Never altered by anything else.
var history: Array[int] = []
## Player positions, one per history entry plus the start tile.
var trail: Array[Vector2i] = []
## ability id -> history index of the last move of its last trigger.
var last_trigger: Dictionary = {}

var status: Status = Status.PLAYING
var end_reason := ""
var exit_reached := false
var step_count := 0
## Completed turns, steps already taken in the current turn, and the history
## index of the current turn's first move.
var turn_count := 0
var turn_step := 0
var turn_start_index := 0

var visible_tiles: Dictionary = {} ## Vector2i -> true, current vision
var seen_tiles: Dictionary = {} ## Vector2i -> true, ever seen
var pending_choices: Array[Choice] = []
## Tile the player is committed to (slow terrain); enemies may not take it.
var reserved_tile := NO_TILE
var rng := RandomNumberGenerator.new()


func emit_event(type: StringName, data: Dictionary = {}) -> void:
	event.emit(type, data)


# --- Board queries -----------------------------------------------------------

func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < width and pos.y < height


func tile_at(pos: Vector2i) -> TileDef:
	return tiles[pos.y * width + pos.x]


func set_tile(pos: Vector2i, tile: TileDef) -> void:
	tiles[pos.y * width + pos.x] = tile


func enemy_at(pos: Vector2i) -> Unit:
	for e in enemies:
		if e.pos == pos and e.is_alive():
			return e
	return null


func unit_at(pos: Vector2i) -> Unit:
	if player.pos == pos:
		return player
	return enemy_at(pos)


func all_units() -> Array[Unit]:
	var units: Array[Unit] = [player]
	units.append_array(enemies)
	return units


func can_player_enter(pos: Vector2i) -> bool:
	if not in_bounds(pos) or tile_at(pos).blocks_movement:
		return false
	if enemy_at(pos) != null:
		return rules.move_into_enemy == GameRules.MoveIntoEnemy.SWAP
	return true


func player_has_valid_move() -> bool:
	for v in Grid.VECTORS:
		if can_player_enter(player.pos + v):
			return true
	return false


func can_enemy_enter(pos: Vector2i, unit: Unit) -> bool:
	if not in_bounds(pos) or tile_at(pos).blocks_movement:
		return false
	if pos == reserved_tile:
		return false
	var other := unit_at(pos)
	return other == null or other == unit


func terrain_affects(unit: Unit) -> bool:
	return rules.terrain_affects_player if unit.is_player else rules.terrain_affects_enemies


## Number of world steps a unit needs to enter the tile (slow terrain > 1).
func move_cost(unit: Unit, pos: Vector2i) -> int:
	if not terrain_affects(unit):
		return 1
	return maxi(1, tile_at(pos).move_cost)


## True if no sight-blocking tile lies strictly between a and b.
func has_line_of_sight(a: Vector2i, b: Vector2i) -> bool:
	return _line_clear(Grid.line(a, b)) or _line_clear(Grid.line(b, a))


func _line_clear(points: Array[Vector2i]) -> bool:
	for i in range(1, points.size() - 1):
		if tile_at(points[i]).blocks_sight:
			return false
	return true


func is_visible(pos: Vector2i) -> bool:
	return not rules.fog_enabled or visible_tiles.has(pos)


func is_seen(pos: Vector2i) -> bool:
	if is_visible(pos) or tile_at(pos).always_visible:
		return true
	return rules.remember_seen_tiles and seen_tiles.has(pos)


# --- Units -------------------------------------------------------------------

func begin_step() -> void:
	step_count += 1
	for unit in all_units():
		unit.prev_pos = unit.pos


func move_player(target: Vector2i) -> void:
	var from := player.pos
	var other := enemy_at(target)
	if other != null:
		other.pos = from
	player.pos = target
	trail.append(target)
	# With several moves per turn the player can walk into a projectile between
	# two projectile phases; running into it is a hit.
	for p in projectiles.duplicate():
		if p.pos == target:
			hit_player_with(p)
	run_tile_effects(tile_at(target).on_enter, player, target)


## Moves an enemy, honouring slow terrain. Returns true once it has arrived.
func try_move_enemy(unit: Unit, target: Vector2i) -> bool:
	if not can_enemy_enter(target, unit):
		unit.wade_target = NO_TILE
		unit.wade_progress = 0
		return false
	var cost := move_cost(unit, target)
	if cost > 1:
		if unit.wade_target != target:
			unit.wade_target = target
			unit.wade_progress = 0
		unit.wade_progress += 1
		if unit.wade_progress < cost:
			return false
	unit.wade_target = NO_TILE
	unit.wade_progress = 0
	unit.pos = target
	run_tile_effects(tile_at(target).on_enter, unit, target)
	return true


func run_tile_effects(effects: Array[TileEffect], unit: Unit, pos: Vector2i) -> void:
	for effect in effects:
		if effect == null:
			continue
		if effect.is_terrain() and not terrain_affects(unit):
			continue
		effect.apply(self, unit, pos)


func damage_unit(unit: Unit, amount: int, source: Unit = null) -> void:
	if amount <= 0 or not unit.is_alive():
		return
	if unit.is_player and rules.player_invulnerable:
		return
	unit.hp -= amount
	if not unit.is_player and rules.damage_activates_enemies:
		unit.active = true
	emit_event(&"damaged", {"unit": unit, "amount": amount, "pos": unit.pos, "source": source})


func stun_unit(unit: Unit, turns: int) -> void:
	unit.stun = maxi(unit.stun, turns)


## Units an attack by `source` on `tiles` would affect: everyone on the other
## side, plus the source itself if the self-damage rule is on.
func targets_on(tiles_hit: Array[Vector2i], source: Unit) -> Array[Unit]:
	var out: Array[Unit] = []
	for unit in all_units():
		if not unit.is_alive() or not tiles_hit.has(unit.pos):
			continue
		if unit == source:
			if rules.self_damage:
				out.append(unit)
		elif source == null or unit.is_player != source.is_player:
			out.append(unit)
	return out


func remove_dead_enemies() -> void:
	for e in enemies.duplicate():
		if not e.is_alive():
			enemies.erase(e)
			emit_event(&"died", {"unit": e, "pos": e.pos})


# --- Abilities ---------------------------------------------------------------

## Board tiles an ability hits when its pattern ends on `anchor`: those of
## one effect, or of all its effects together when `effect` is null.
func effect_tiles(ability: AbilityDef, anchor: Vector2i, rotation: int, effect: AbilityEffect = null, mirrored := false) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for pos in ability.area_tiles(anchor, rotation, effect, mirrored):
		if not in_bounds(pos):
			continue
		if rules.walls_block_effects:
			if tile_at(pos).blocks_sight or not has_line_of_sight(anchor, pos):
				continue
		out.append(pos)
	return out


## Abilities completed by the last move of `moves`. With the rule switch
## `abilities_only_at_turn_end`, a pattern no longer than a turn must lie
## inside the turn starting at history index `turn_start`; otherwise any
## pattern may reach into earlier turns.
func ability_matches(moves: Array[int], turn_start: int) -> Array[PatternMatcher.Match]:
	var turn_length := rules.player_moves_per_turn if rules.abilities_only_at_turn_end else 0
	return PatternMatcher.find_matches(moves, abilities, last_trigger, turn_start, turn_length)


func find_ability(id: StringName) -> AbilityDef:
	for a in abilities:
		if a.id == id:
			return a
	return null


# --- Projectiles -------------------------------------------------------------

func spawn_projectile(pos: Vector2i, dir: int, speed: int, damage: int, source: Unit = null) -> Projectile:
	var p := Projectile.new()
	p.pos = pos
	p.dir = dir
	p.speed = speed
	p.damage = damage
	p.source = source
	projectiles.append(p)
	emit_event(&"projectile_spawned", {"projectile": p})
	return p


func hit_player_with(p: Projectile) -> void:
	p.alive = false
	projectiles.erase(p)
	emit_event(&"projectile_hit", {"projectile": p, "unit": player})
	damage_unit(player, p.damage, p.source)


func destroy_projectiles_on(tiles_hit: Array[Vector2i]) -> void:
	for p in projectiles.duplicate():
		if tiles_hit.has(p.pos):
			projectiles.erase(p)


# --- Vision and activation ---------------------------------------------------

func update_vision() -> void:
	visible_tiles.clear()
	var r := int(ceil(vision_radius))
	for y in range(player.pos.y - r, player.pos.y + r + 1):
		for x in range(player.pos.x - r, player.pos.x + r + 1):
			var pos := Vector2i(x, y)
			if not in_bounds(pos):
				continue
			if not Grid.within(player.pos, pos, vision_radius, rules.distance_metric):
				continue
			if has_line_of_sight(player.pos, pos):
				visible_tiles[pos] = true
				seen_tiles[pos] = true


func update_activation() -> void:
	for e in enemies:
		if e.active or e.def == null:
			continue
		# Never larger than the vision radius, so nothing activates unseen.
		var activation_range := minf(e.def.activation_range, vision_radius)
		if not Grid.within(player.pos, e.pos, activation_range, rules.distance_metric):
			continue
		if rules.activation_requires_sight and not is_visible(e.pos):
			continue
		e.active = true
		emit_event(&"activated", {"unit": e})


# --- Choices (pickups) -------------------------------------------------------

func offer_choice(choice: Choice) -> void:
	pending_choices.append(choice)
	emit_event(&"choice_opened", {"choice": choice})


func current_choice() -> Choice:
	return pending_choices[0] if not pending_choices.is_empty() else null


func resolve_choice(index: int) -> bool:
	var choice := current_choice()
	if choice == null or index < 0 or index >= choice.options.size():
		return false
	var option := choice.options[index]
	pending_choices.pop_front()
	option.apply(self)
	emit_event(&"choice_resolved", {"option": option})
	return true


# --- End of room -------------------------------------------------------------

func win(reason: String) -> void:
	if status != Status.PLAYING:
		return
	status = Status.WON
	end_reason = reason
	emit_event(&"won", {"reason": reason})


func lose(reason: String) -> void:
	if status != Status.PLAYING:
		return
	status = Status.LOST
	end_reason = reason
	emit_event(&"lost", {"reason": reason})
