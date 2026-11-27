class_name Design
extends Resource
## Everything the sandbox layer can edit, as one self-contained resource: the
## room, the ability list, the player, and its own copies of the enemy and
## tile types. Built from the defaults in `data/` and never writes back to
## them. A Game is started from a design with make_config() and room_text().

const MIN_SIZE := 3
const MAX_SIZE := 40

## The room, one string per row and one character per tile, in the format of
## the room files (symbols of tiles and enemies, plus the player symbol).
@export var rows: PackedStringArray = []
## Every ability that exists in this design, whether the player has it or not.
@export var abilities: Array[AbilityDef] = []
## `player.starting_abilities` holds entries of `abilities`.
@export var player: PlayerConfig
@export var enemies: Array[EnemyDef] = []
@export var tiles: Array[TileDef] = []
@export var floor_symbol := "."
@export var player_symbol := "P"

@export_group("Testing aids")
@export var fog_off := false
@export var invulnerable := false


# --- Building, saving, loading -----------------------------------------------

## A design equal to the shipped game, made of independent copies.
static func from_defaults(base: GameConfig) -> Design:
	var design := Design.new()
	# One memo for everything, so references between the parts (a starting
	# ability, an ability offered by a pickup tile) point at the design's copy.
	var memo := {}
	for res in ContentLoader.load_dir(base.abilities_dir):
		if res is AbilityDef:
			design.abilities.append(deep_copy(res, memo) as AbilityDef)
	design.player = deep_copy(base.player, memo) as PlayerConfig
	for ability in design.player.starting_abilities:
		if ability != null and not design.abilities.has(ability):
			design.abilities.append(ability)
	for res in ContentLoader.load_dir(base.tiles_dir):
		if res is TileDef:
			design.tiles.append(deep_copy(res, memo) as TileDef)
	for res in ContentLoader.load_dir(base.enemies_dir):
		if res is EnemyDef:
			design.enemies.append(deep_copy(res, memo) as EnemyDef)
	design.floor_symbol = base.default_tile_symbol
	design.player_symbol = base.player_symbol
	design.set_room_text(FileAccess.get_file_as_string(base.room_file))
	return design


## Copy of `res` that shares nothing with it except scripts. Resources reached
## twice are copied once; `memo` maps original -> copy.
static func deep_copy(res: Resource, memo: Dictionary = {}) -> Resource:
	if res == null or res is Script:
		return res
	if memo.has(res):
		return memo[res]
	var copy := res.duplicate()
	memo[res] = copy
	for property in res.get_property_list():
		if not property.usage & PROPERTY_USAGE_STORAGE:
			continue
		var value: Variant = res.get(property.name)
		if value is Resource:
			copy.set(property.name, deep_copy(value, memo))
		elif value is Array:
			var array: Array = value.duplicate()
			for i in array.size():
				if array[i] is Resource:
					array[i] = deep_copy(array[i], memo)
			copy.set(property.name, array)
	return copy


## The saved design at `path`, or null if there is none or it is unusable.
static func load_saved(path: String) -> Design:
	if not FileAccess.file_exists(path):
		return null
	var design := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Design
	if design == null or not design.is_usable():
		push_warning("Sandbox: %s could not be used, starting from the defaults" % path)
		return null
	return design


func save(path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	return ResourceSaver.save(self, path)


func is_usable() -> bool:
	if player == null or rows.is_empty() or width() == 0:
		return false
	if tile_by_symbol(floor_symbol) == null or player_pos() == GameState.NO_TILE:
		return false
	for row in rows:
		if row.length() != width():
			return false
	return not abilities.has(null) and not tiles.has(null) and not enemies.has(null)


## The configuration a Game runs this design with. `base` supplies the rules.
func make_config(base: GameConfig) -> GameConfig:
	var config: GameConfig = base.duplicate()
	config.rules = base.rules.duplicate()
	apply_testing_aids(config.rules, base.rules)
	config.player = player
	return config


## Sets the switches of the testing aids on `rules`, a copy of `base_rules`.
func apply_testing_aids(rules: GameRules, base_rules: GameRules) -> void:
	rules.fog_enabled = base_rules.fog_enabled and not fog_off
	rules.player_invulnerable = base_rules.player_invulnerable or invulnerable


# --- Room --------------------------------------------------------------------

func width() -> int:
	return rows[0].length() if not rows.is_empty() else 0


func height() -> int:
	return rows.size()


func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < width() and pos.y < height()


func cell(pos: Vector2i) -> String:
	return rows[pos.y][pos.x]


## Puts a tile, an enemy or the player start on a cell. The player start
## moves (there is always exactly one) and cannot be painted over. Returns
## true if the room changed.
func set_cell(pos: Vector2i, symbol: String) -> bool:
	if not in_bounds(pos) or symbol.length() != 1 or cell(pos) == symbol:
		return false
	if cell(pos) == player_symbol:
		return false
	if symbol == player_symbol:
		var old := player_pos()
		if old != GameState.NO_TILE:
			_write(old, floor_symbol)
	_write(pos, symbol)
	return true


func player_pos() -> Vector2i:
	for y in rows.size():
		var x := rows[y].find(player_symbol)
		if x >= 0:
			return Vector2i(x, y)
	return GameState.NO_TILE


## Grows or shrinks the room at its right and bottom edges. A player start
## that would be cut off moves to the nearest remaining cell.
func resize(new_width: int, new_height: int) -> void:
	new_width = clampi(new_width, MIN_SIZE, MAX_SIZE)
	new_height = clampi(new_height, MIN_SIZE, MAX_SIZE)
	var start := player_pos()
	var out: PackedStringArray = []
	for y in new_height:
		var row := rows[y] if y < rows.size() else ""
		out.append(row.substr(0, new_width).rpad(new_width, floor_symbol))
	rows = out
	if player_pos() == GameState.NO_TILE:
		if start == GameState.NO_TILE:
			start = Vector2i.ZERO
		_write(Vector2i(mini(start.x, new_width - 1), mini(start.y, new_height - 1)), player_symbol)


## The room in the text format RoomLoader reads.
func room_text() -> String:
	return "\n".join(rows)


## Reads a room file: comment and empty lines are dropped, short rows padded.
func set_room_text(text: String) -> void:
	var out: PackedStringArray = []
	var widest := 0
	for raw in text.split("\n"):
		var row := raw.strip_edges(false, true)
		if row == "" or row.begins_with(";"):
			continue
		out.append(row)
		widest = maxi(widest, row.length())
	for y in out.size():
		out[y] = out[y].rpad(widest, floor_symbol)
	rows = out
	if not rows.is_empty() and player_pos() == GameState.NO_TILE:
		_write(Vector2i.ZERO, player_symbol)


func tile_by_symbol(symbol: String) -> TileDef:
	for tile in tiles:
		if tile != null and tile.symbol == symbol:
			return tile
	return null


func enemy_by_symbol(symbol: String) -> EnemyDef:
	for enemy in enemies:
		if enemy != null and enemy.symbol == symbol:
			return enemy
	return null


func _write(pos: Vector2i, symbol: String) -> void:
	var row := rows[pos.y]
	rows[pos.y] = row.substr(0, pos.x) + symbol + row.substr(pos.x + 1)


# --- Abilities ---------------------------------------------------------------

func is_starting(ability: AbilityDef) -> bool:
	return player.starting_abilities.has(ability)


## Starting abilities keep the order of the ability list, which is the order
## they resolve in when one move triggers several.
func set_starting(ability: AbilityDef, starting: bool) -> void:
	var list: Array[AbilityDef] = []
	for a in abilities:
		if (starting and a == ability) or (a != ability and is_starting(a)):
			list.append(a)
	player.starting_abilities = list


func add_ability(ability: AbilityDef, starting := true) -> void:
	abilities.append(ability)
	if starting:
		set_starting(ability, true)


func remove_ability(ability: AbilityDef) -> void:
	set_starting(ability, false)
	abilities.erase(ability)


## An id no ability of this design uses yet, e.g. &"custom_3".
func free_ability_id(prefix := "custom") -> StringName:
	var n := 1
	while true:
		var id := StringName("%s_%d" % [prefix, n])
		var taken := false
		for a in abilities:
			if a.id == id:
				taken = true
		if not taken:
			return id
		n += 1
	return &""
