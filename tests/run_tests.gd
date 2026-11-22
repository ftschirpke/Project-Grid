extends SceneTree
## Headless rules tests. Run from the project folder with:
##   godot --headless --path . --script res://tests/run_tests.gd
## (run `godot --headless --path . --import` once first if classes are new)

const U := Grid.Dir.UP
const R := Grid.Dir.RIGHT
const D := Grid.Dir.DOWN
const L := Grid.Dir.LEFT

var _base: GameConfig
var _failures := 0
var _checks := 0
var _current := ""


func _init() -> void:
	_base = load("res://data/game.tres")
	for method in get_method_list():
		var method_name: String = method.name
		if method_name.begins_with("test_"):
			_current = method_name
			call(method_name)
	print("\n%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


# --- helpers -----------------------------------------------------------------

func check(condition: bool, what: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("FAIL  %s: %s" % [_current, what])


func eq(actual: Variant, expected: Variant, what: String) -> void:
	check(actual == expected, "%s (expected %s, got %s)" % [what, expected, actual])


## Game on an inline room, with optional rule overrides.
func make(room: String, overrides: Dictionary = {}) -> Game:
	var cfg: GameConfig = _base.duplicate()
	cfg.rules = _base.rules.duplicate()
	cfg.random_seed = 1
	for key in overrides:
		cfg.rules.set(key, overrides[key])
	return Game.new(cfg, room)


func moves(game: Game, sequence: String) -> void:
	for c in sequence:
		game.try_move("URDL".find(c))


## Records ability names per history length, e.g. {2: ["L-Strike"]}.
func record_abilities(game: Game) -> Dictionary:
	var fired := {}
	game.state.event.connect(func(type: StringName, data: Dictionary) -> void:
		if type == &"ability_fired":
			var key := game.state.history.size()
			if not fired.has(key):
				fired[key] = []
			fired[key].append(data.ability.display_name))
	return fired


const OPEN_ROOM := """
.....
.....
.....
.P...
.....
"""
const NO_KILL_WIN := {"win_on_all_enemies_dead": false}


# --- pattern system ----------------------------------------------------------

func test_clockwise_circle_fires_lstrike_every_second_move() -> void:
	var game := make(OPEN_ROOM, NO_KILL_WIN)
	var fired := record_abilities(game)
	moves(game, "URDLURDL")
	for move in [1, 3, 5, 7]:
		eq(fired.get(move), null, "nothing on move %d" % move)
	for move in [2, 4, 6, 8]:
		eq(fired.get(move), ["L-Strike"], "L-strike on move %d, never the loop" % move)


func test_counter_clockwise_circle_fires_loop_every_fourth_move() -> void:
	var game := make(OPEN_ROOM, NO_KILL_WIN)
	var fired := record_abilities(game)
	moves(game, "ULDRULDR")
	eq(fired.size(), 2, "only two triggers, no L-strike")
	eq(fired.get(4), ["Loop"], "loop on move 4")
	eq(fired.get(8), ["Loop"], "loop on move 8")


func test_different_abilities_overlap_in_list_order() -> void:
	var game := make(OPEN_ROOM, NO_KILL_WIN)
	var turn := AbilityDef.new()
	turn.id = &"turn"
	turn.display_name = "Turn"
	turn.pattern = [D, R] as Array[Grid.Dir]
	game.state.abilities.append(turn)
	var fired := record_abilities(game)
	moves(game, "ULDR")
	eq(fired.get(4), ["Loop", "Turn"], "one move completes both, resolved in list order")


func test_lstrike_stuns_around_and_damages_in_front() -> void:
	var game := make(OPEN_ROOM, NO_KILL_WIN)
	var ability := game.state.find_ability(&"l_strike")
	var end := Vector2i(2, 2) # after U, R from (1,3); facing right
	var damage: Array = game.state.effect_tiles(ability, end, 0, ability.effects[0])
	damage.sort()
	eq(damage, [Vector2i(3, 2), Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3)], "damage cone in front")
	var stun := game.state.effect_tiles(ability, end, 0, ability.effects[1])
	eq(stun.size(), 8, "stun on the 8 tiles around the player")
	check(not stun.has(end), "not on the player's own tile")
	check(stun.has(Vector2i(1, 1)) and stun.has(Vector2i(3, 3)), "includes diagonals")
	var fired := []
	game.state.event.connect(func(type: StringName, data: Dictionary) -> void:
		if type == &"ability_fired":
			fired.append_array(data.tiles))
	moves(game, "UR")
	eq(fired.size(), 11, "flash covers both areas (they share one tile)")


func test_area_rotates_with_pattern() -> void:
	var game := make(OPEN_ROOM, NO_KILL_WIN)
	var ability := game.state.find_ability(&"l_strike")
	# L, U from (1,3) ends on (0,2) facing up: three quarter turns.
	var damage: Array = game.state.effect_tiles(ability, Vector2i(0, 2), 3, ability.effects[0])
	damage.sort()
	eq(damage, [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0)], "cone points up, clipped at the room edge")
	eq(game.preview(L).hits.size(), 0, "first move fires nothing")
	moves(game, "L")
	eq(game.preview(U).hits[0].tiles.size(), 7, "preview shows ring plus cone, clipped")


func test_non_rotatable_ability() -> void:
	var ability := AbilityDef.new()
	ability.id = &"fixed"
	ability.pattern = [U, R] as Array[Grid.Dir]
	ability.rotatable = false
	var list: Array[AbilityDef] = [ability]
	var canonical: Array[int] = [U, R]
	var rotated: Array[int] = [R, D]
	eq(PatternMatcher.find_matches(canonical, list, {}).size(), 1, "canonical matches")
	eq(PatternMatcher.find_matches(rotated, list, {}).size(), 0, "rotation rejected")
	ability.rotatable = true
	var m := PatternMatcher.find_matches(rotated, list, {})
	eq(m.size(), 1, "rotation accepted when rotatable")
	eq(m[0].rotation, 1, "one quarter turn")


func test_preview_matches_what_happens() -> void:
	var game := make(OPEN_ROOM, NO_KILL_WIN)
	moves(game, "U")
	var p := game.preview(R)
	eq(p.valid, true, "right is valid")
	eq(p.hits.size(), 1, "right would fire one ability")
	eq(p.hits[0].ability.id, &"l_strike", "it is the L-strike")
	eq(game.preview(L).hits.size(), 0, "left (counter-clockwise) fires nothing")
	eq(game.state.history.size(), 1, "preview does not touch the history")


# --- movement and time -------------------------------------------------------

func test_invalid_move_costs_nothing() -> void:
	var game := make("P.\n..", NO_KILL_WIN)
	eq(game.try_move(U), false, "off-grid move rejected")
	eq(game.try_move(L), false, "off-grid move rejected")
	eq(game.state.step_count, 0, "no step passed")
	eq(game.state.history.size(), 0, "history untouched")
	var walled := make("P#\n..", NO_KILL_WIN)
	eq(walled.try_move(R), false, "wall rejected")
	eq(walled.state.step_count, 0, "no step passed")


func test_move_into_enemy_is_invalid_by_default() -> void:
	var game := make("Pc\n..")
	game.state.enemies[0].stun = 99
	eq(game.try_move(R), false, "enemy tile rejected")
	eq(game.state.step_count, 0, "no step passed")


func test_boxed_in_passes_turn_and_chaser_attacks() -> void:
	var game := make("P..c")
	moves(game, "R") # chaser steps next to the player
	eq(game.state.enemies[0].pos, Vector2i(2, 0), "chaser approached")
	moves(game, "L") # chaser follows; player is now boxed in
	eq(game.state.player.hp, 3, "not hit while moving away")
	eq(game.try_move(R), true, "boxed in: key press passes the turn")
	eq(game.state.player.hp, 2, "adjacent chaser attacks")
	eq(game.state.history.size(), 2, "passed turn is not in the history")
	moves(game, "RR")
	eq(game.state.status, GameState.Status.LOST, "lost at zero health")


func test_boxed_in_lose_variant() -> void:
	var game := make("P..c", {"boxed_in": GameRules.BoxedIn.LOSE})
	moves(game, "RLR")
	eq(game.state.status, GameState.Status.LOST, "boxed in counts as a loss")


# --- combat ------------------------------------------------------------------

func test_loop_kills_chaser_and_wins() -> void:
	var game := make("....\n....\n.Pc.\n....")
	game.state.enemies[0].stun = 99
	moves(game, "ULDR") # ends where it started, facing right at the chaser
	eq(game.state.enemies.size(), 0, "chaser removed")
	eq(game.state.status, GameState.Status.WON, "all enemies dead wins")


func test_lstrike_damages_and_stuns() -> void:
	var game := make("...s.\n..s..\nP....\n.....")
	var beside := game.state.enemies[0] if game.state.enemies[0].pos == Vector2i(2, 1) else game.state.enemies[1]
	var far := game.state.enemies[0] if beside == game.state.enemies[1] else game.state.enemies[1]
	beside.stun = 1 # keep it from firing on the first step
	far.active = false
	moves(game, "UR") # ends on (1,1) facing right
	eq(beside.hp, 1, "directly in front: 1 damage")
	eq(beside.stun, 0, "and stunned (consumed by the skipped action)")
	eq(far.hp, 1, "tip of the cone: 1 damage")
	eq(game.state.projectiles.size(), 0, "stunned shooter did not fire")


func test_stunned_enemy_skips_one_action() -> void:
	var game := make("P...\n....\n....\n...c")
	var chaser := game.state.enemies[0]
	chaser.active = true
	chaser.stun = 1
	moves(game, "R")
	eq(chaser.pos, Vector2i(3, 3), "skipped its action")
	moves(game, "L")
	check(chaser.pos != Vector2i(3, 3), "acts again afterwards")


func test_shooter_fires_stepping_projectile() -> void:
	var game := make(".P.....s", NO_KILL_WIN)
	game.state.enemies[0].active = true
	moves(game, "L")
	eq(game.state.projectiles.size(), 1, "fired when lined up")
	eq(game.state.projectiles[0].pos, Vector2i(6, 0), "projectile advanced one tile")
	moves(game, "R")
	eq(game.state.projectiles.size(), 1, "fire interval respected")
	moves(game, "R")
	eq(game.state.projectiles.size(), 1, "fire interval respected")
	eq(game.state.player.hp, 3, "not hit yet")
	moves(game, "R") # player (3,0), first projectile enters the tile
	eq(game.state.player.hp, 2, "projectile hit")
	eq(game.state.projectiles.size(), 1, "old projectile gone, new one fired after 3 steps")


func test_projectile_swap_hits_and_sidestep_dodges() -> void:
	var swap := make(".P....", NO_KILL_WIN)
	swap.state.spawn_projectile(Vector2i(2, 0), L, 1, 1)
	moves(swap, "R")
	eq(swap.state.player.hp, 2, "swapping tiles is a hit")
	eq(swap.state.projectiles.size(), 0, "projectile destroyed")

	var dodge := make(".P....\n......", NO_KILL_WIN)
	dodge.state.spawn_projectile(Vector2i(2, 0), L, 1, 1)
	moves(dodge, "D")
	eq(dodge.state.player.hp, 3, "stepping aside dodges")
	eq(dodge.state.projectiles[0].pos, Vector2i(1, 0), "projectile flew on")


func test_projectile_destroyed_by_wall() -> void:
	var game := make("P..\n#..", NO_KILL_WIN)
	game.state.spawn_projectile(Vector2i(2, 1), L, 1, 1)
	moves(game, "R")
	eq(game.state.projectiles.size(), 1, "still flying")
	moves(game, "R")
	eq(game.state.projectiles.size(), 0, "destroyed by the wall")


func test_boss_telegraphs_then_slams() -> void:
	var game := make(".......\nP.....B\n.......")
	var boss := game.state.enemies[0]
	boss.active = true
	var telegraphed := false
	var cleared_after := false
	for i in 8:
		moves(game, "U" if i % 2 == 0 else "D")
		if not boss.telegraph.is_empty():
			telegraphed = true
		elif telegraphed:
			cleared_after = true
	check(telegraphed, "boss marked tiles")
	check(cleared_after, "telegraph resolved on a later step")


# --- win and lose ------------------------------------------------------------

func test_exit_wins() -> void:
	var game := make("PE.....c")
	moves(game, "R")
	eq(game.state.status, GameState.Status.WON, "exit wins")


func test_player_advantage_on_simultaneous_resolution() -> void:
	var game := make("cPE")
	game.state.player.hp = 1
	moves(game, "R")
	eq(game.state.status, GameState.Status.WON, "win is checked before enemies act")
	eq(game.state.player.hp, 1, "the adjacent chaser never attacked")


# --- terrain and pickups -----------------------------------------------------

func test_slow_terrain_takes_two_steps_one_history_entry() -> void:
	var game := make("P~..", NO_KILL_WIN)
	moves(game, "R")
	eq(game.state.player.pos, Vector2i(1, 0), "advanced one tile")
	eq(game.state.step_count, 2, "world stepped twice")
	eq(game.state.history.size(), 1, "one history entry")
	moves(game, "R")
	eq(game.state.step_count, 3, "leaving slow terrain is a normal step")


func test_hazard_damages_at_end_of_step() -> void:
	var game := make("P^.", NO_KILL_WIN)
	moves(game, "R")
	eq(game.state.player.hp, 2, "1 damage")
	moves(game, "R")
	eq(game.state.player.hp, 2, "no damage after leaving")
	var off := make("P^.", {"win_on_all_enemies_dead": false, "terrain_affects_player": false})
	moves(off, "R")
	eq(off.state.player.hp, 3, "switch turns terrain off for the player")


func test_upgrade_pickup() -> void:
	var game := make("PU..", NO_KILL_WIN)
	moves(game, "R")
	var choice := game.state.current_choice()
	check(choice != null, "choice opened")
	eq(choice.options.size(), 3, "three options")
	eq(game.state.step_count, 1, "picking up costs no extra step")
	eq(game.try_move(R), false, "world is paused while the choice is open")
	game.choose(0)
	eq(game.state.current_choice(), null, "choice closed")
	eq(game.state.find_ability(&"l_strike").effects[0].amount, 2, "+1 damage applied")
	var source: AbilityDef = load("res://data/abilities/l_strike.tres")
	eq(source.effects[0].amount, 1, "data file untouched")
	eq(game.state.tile_at(Vector2i(1, 0)).id, &"floor", "pickup consumed")
	eq(game.try_move(R), true, "game continues")


func test_new_ability_pickup() -> void:
	var game := make("PA....", NO_KILL_WIN)
	var fired := record_abilities(game)
	moves(game, "R")
	game.choose(0)
	eq(game.state.abilities.size(), 3, "ability added")
	eq(game.state.abilities[2].id, &"lance", "lance gained")
	moves(game, "RR") # the move onto the pickup counts as the first of three
	eq(fired.get(3), ["Lance"], "three moves in a line fire the lance")
	moves(game, "RR")
	eq(fired.get(4), null, "no self-overlap")
	eq(fired.get(5), null, "needs three fresh moves")


# --- vision ------------------------------------------------------------------

func test_walls_block_sight_and_activation() -> void:
	var game := make("P#c\n...")
	eq(game.state.is_visible(Vector2i(2, 0)), false, "tile behind wall hidden")
	eq(game.state.enemies[0].active, false, "unseen enemy stays idle")
	moves(game, "D")
	moves(game, "R")
	eq(game.state.is_visible(Vector2i(2, 0)), true, "visible around the corner")
	eq(game.state.enemies[0].active, true, "activates once seen in range")


func test_enemy_out_of_range_stays_idle() -> void:
	var game := make("P.......c\n.........")
	moves(game, "D")
	eq(game.state.enemies[0].active, false, "idle beyond activation range")
	eq(game.state.enemies[0].pos, Vector2i(8, 0), "did not move")


# --- shipped content ---------------------------------------------------------

func test_shipped_room_loads() -> void:
	var game := Game.new(_base)
	eq(game.state.width, 16, "width")
	eq(game.state.height, 16, "height")
	eq(game.state.enemies.size(), 6, "six enemies")
	eq(game.state.player.pos, Vector2i(5, 15), "player start")
	eq(game.state.tile_at(Vector2i(13, 0)).id, &"exit", "exit tile")
	eq(game.state.abilities.size(), 2, "two starting abilities")
	eq(game.state.is_seen(Vector2i(14, 0)), true, "exit visible from the start")
	eq(game.state.is_visible(Vector2i(14, 0)), false, "but not in current vision")
	eq(game.try_move(U), true, "can move")
