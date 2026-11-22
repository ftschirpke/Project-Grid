class_name RoomLoader
extends RefCounted
## Builds a GameState from a plain-text room. One character per tile; the
## characters are the `symbol` of a TileDef or EnemyDef, or the player symbol.
## Lines starting with ';' are comments.


static func build(config: GameConfig, text: String, tile_types: Array[TileDef], enemy_types: Array[EnemyDef]) -> GameState:
	var state := GameState.new()
	state.rules = config.rules
	state.vision_radius = config.player.vision_radius
	state.player_color = config.player.color
	if config.random_seed != 0:
		state.rng.seed = config.random_seed
	else:
		state.rng.randomize()

	var enemy_by_symbol := {}
	for t in tile_types:
		state.tile_types[t.symbol] = t
	for e in enemy_types:
		enemy_by_symbol[e.symbol] = e
	var floor_tile: TileDef = state.tile_types.get(config.default_tile_symbol)
	assert(floor_tile != null, "No tile type uses the default tile symbol")

	var rows: Array[String] = []
	for raw in text.split("\n"):
		var row := raw.strip_edges(false, true)
		if row == "" or row.begins_with(";"):
			continue
		rows.append(row)
		state.width = maxi(state.width, row.length())
	state.height = rows.size()

	state.player = Unit.new()
	state.player.is_player = true
	state.player.max_hp = config.player.max_health
	state.player.hp = config.player.max_health
	state.player.active = true

	state.tiles.resize(state.width * state.height)
	for y in state.height:
		for x in state.width:
			var pos := Vector2i(x, y)
			var symbol := rows[y][x] if x < rows[y].length() else config.default_tile_symbol
			var tile := floor_tile
			if state.tile_types.has(symbol):
				tile = state.tile_types[symbol]
			elif enemy_by_symbol.has(symbol):
				state.enemies.append(_make_enemy(enemy_by_symbol[symbol], pos))
			elif symbol == config.player_symbol:
				state.player.pos = pos
			else:
				push_warning("Room: unknown symbol '%s' at %s" % [symbol, pos])
			state.set_tile(pos, tile)
			if tile.always_visible:
				state.seen_tiles[pos] = true

	state.player.prev_pos = state.player.pos
	state.trail.append(state.player.pos)
	for ability in config.player.starting_abilities:
		if ability != null:
			state.abilities.append(ability.instantiate())
	return state


static func _make_enemy(def: EnemyDef, pos: Vector2i) -> Unit:
	var unit := Unit.new()
	unit.def = def
	unit.pos = pos
	unit.prev_pos = pos
	unit.max_hp = def.max_health
	unit.hp = def.max_health
	return unit
