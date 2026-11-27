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


## One move per turn and the original L-strike and loop: the engine tests
## below were written for that setup and still cover the shared mechanics.
func classic(room: String, overrides: Dictionary = {}) -> Game:
	var o := overrides.duplicate()
	o["player_moves_per_turn"] = 1
	var game := make(room, o)
	var list: Array[AbilityDef] = []
	for path in ["res://data/abilities/l_strike.tres", "res://data/abilities/loop.tres"]:
		list.append((load(path) as AbilityDef).instantiate())
	game.state.abilities = list
	return game


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
	var game := classic(OPEN_ROOM, NO_KILL_WIN)
	var fired := record_abilities(game)
	moves(game, "URDLURDL")
	for move in [1, 3, 5, 7]:
		eq(fired.get(move), null, "nothing on move %d" % move)
	for move in [2, 4, 6, 8]:
		eq(fired.get(move), ["L-Strike"], "L-strike on move %d, never the loop" % move)


func test_counter_clockwise_circle_fires_loop_every_fourth_move() -> void:
	var game := classic(OPEN_ROOM, NO_KILL_WIN)
	var fired := record_abilities(game)
	moves(game, "ULDRULDR")
	eq(fired.size(), 2, "only two triggers, no L-strike")
	eq(fired.get(4), ["Loop"], "loop on move 4")
	eq(fired.get(8), ["Loop"], "loop on move 8")


func test_different_abilities_overlap_in_list_order() -> void:
	var game := classic(OPEN_ROOM, NO_KILL_WIN)
	var turn := AbilityDef.new()
	turn.id = &"turn"
	turn.display_name = "Turn"
	turn.pattern = [D, R] as Array[Grid.Dir]
	game.state.abilities.append(turn)
	var fired := record_abilities(game)
	moves(game, "ULDR")
	eq(fired.get(4), ["Loop", "Turn"], "one move completes both, resolved in list order")


func test_lstrike_stuns_around_and_damages_in_front() -> void:
	var game := classic(OPEN_ROOM, NO_KILL_WIN)
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
	var game := classic(OPEN_ROOM, NO_KILL_WIN)
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
	var game := classic(OPEN_ROOM, NO_KILL_WIN)
	moves(game, "U")
	var p := game.preview(R)
	eq(p.valid, true, "right is valid")
	eq(p.hits.size(), 1, "right would fire one ability")
	eq(p.hits[0].ability.id, &"l_strike", "it is the L-strike")
	eq(game.preview(L).hits.size(), 0, "left (counter-clockwise) fires nothing")
	eq(game.state.history.size(), 1, "preview does not touch the history")


# --- two-move turns and spear attacks ---------------------------------------

const ROW_ROOM := """
........
........
........
"""


func test_enemies_act_once_per_two_moves() -> void:
	var game := make("P.......\n........\n.......c", NO_KILL_WIN)
	var chaser := game.state.enemies[0]
	chaser.active = true
	moves(game, "R")
	eq(chaser.pos, Vector2i(7, 2), "first move: the world waits")
	eq(game.state.turn_step, 1, "one move into the turn")
	moves(game, "D")
	check(chaser.pos != Vector2i(7, 2), "second move: enemies act")
	eq(game.state.turn_count, 1, "one turn completed")
	eq(game.state.turn_step, 0, "next turn starts")


func test_spear_throw_hits_three_tiles_ahead() -> void:
	var game := make("P...sss", NO_KILL_WIN)
	for e in game.state.enemies:
		e.stun = 99
	var fired := record_abilities(game)
	moves(game, "RR") # ends on (2,0) facing right
	eq(fired.get(2), ["Spear Throw"], "two moves in one direction")
	var hp: Array = game.state.enemies.map(func(e: Unit) -> int: return e.hp)
	eq(hp, [1, 1, 2], "tiles 1 to 3 ahead take 1 damage, the 4th is untouched")


func test_spear_thrust_back_and_forth() -> void:
	var game := make("..P.c..")
	game.state.enemies[0].stun = 99
	var fired := record_abilities(game)
	moves(game, "LR") # back on (2,0), the second move faces right
	eq(fired.get(2), ["Spear Thrust"], "step and step back")
	eq(game.state.enemies.size(), 0, "2 damage two tiles ahead kills a chaser")
	eq(game.state.status, GameState.Status.WON, "all enemies dead wins")

	var reverse := make("c.P....", NO_KILL_WIN)
	reverse.state.enemies[0].stun = 99
	moves(reverse, "RL")
	eq(reverse.state.enemies.size(), 0, "right then left strikes to the left")


func test_spear_attacks_rotate() -> void:
	var game := make(ROW_ROOM, NO_KILL_WIN)
	var throw := game.state.find_ability(&"spear_throw")
	var tiles: Array = game.state.effect_tiles(throw, Vector2i(4, 1), 1)
	tiles.sort()
	eq(tiles, [Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)], "throw facing right")
	var thrust := game.state.find_ability(&"spear_thrust")
	tiles = game.state.effect_tiles(thrust, Vector2i(4, 1), 2)
	tiles.sort()
	eq(tiles, [Vector2i(4, 2)], "thrust facing down, clipped at the room edge")


func test_patterns_cross_the_turn_boundary() -> void:
	var game := make(ROW_ROOM, NO_KILL_WIN)
	game.state.player.pos = Vector2i(0, 1)
	var fired := record_abilities(game)
	moves(game, "UR")
	eq(fired.size(), 0, "a corner fires nothing")
	eq(game.preview(R).ends_turn, false, "the next move is the first of a turn")
	eq(game.preview(R).hits[0].ability.id, &"spear_throw", "and the preview shows the throw")
	eq(game.ability_progress(game.state.find_ability(&"spear_throw")), 1, "one move of the throw is walked")
	moves(game, "R") # R, R straddles the two turns
	eq(fired.get(3), ["Spear Throw"], "started in one turn, finished in the next")
	eq(game.state.turn_step, 1, "mid-turn: the enemies have not acted")
	eq(game.preview(R).hits.size(), 0, "a third step cannot reuse the throw's moves")
	eq(game.preview(L).hits[0].ability.id, &"spear_thrust", "but another ability can share its last move")


func test_turn_end_switch_keeps_patterns_inside_the_turn() -> void:
	var rules := NO_KILL_WIN.duplicate()
	rules["abilities_only_at_turn_end"] = true
	var game := make(ROW_ROOM, rules)
	game.state.player.pos = Vector2i(0, 1)
	eq(game.preview(R).hits.size(), 0, "the first move of a turn previews nothing")
	var fired := record_abilities(game)
	moves(game, "URRD") # R, R straddles the two turns
	eq(fired.size(), 0, "no spear throw across turns")
	moves(game, "LR") # U-turn inside one turn
	eq(fired.get(6), ["Spear Thrust"], "inside a turn it fires")


func test_turning_a_corner_fires_nothing() -> void:
	var game := make(ROW_ROOM, NO_KILL_WIN)
	var fired := record_abilities(game)
	moves(game, "DRUR") # two corners
	eq(fired.size(), 0, "a corner is pure movement")


func test_preview_in_two_move_turns() -> void:
	var game := make(ROW_ROOM, NO_KILL_WIN)
	game.state.player.pos = Vector2i(3, 1)
	var first := game.preview(R)
	eq(first.ends_turn, false, "first move does not end the turn")
	eq(first.hits.size(), 0, "so it fires nothing")
	moves(game, "R")
	eq(game.preview(R).hits[0].ability.id, &"spear_throw", "same direction: throw")
	eq(game.preview(L).hits[0].ability.id, &"spear_thrust", "back again: thrust")
	eq(game.preview(U).hits.size(), 0, "corner: nothing")
	eq(game.preview(U).ends_turn, true, "but it ends the turn")


func test_chaser_steps_then_strikes_ahead() -> void:
	var game := make("P.c\n...", NO_KILL_WIN)
	var chaser := game.state.enemies[0]
	chaser.active = true
	moves(game, "DU") # thrust points up and misses; player back on (0,0)
	eq(chaser.pos, Vector2i(1, 0), "chaser stepped once")
	eq(game.state.player.hp, 2, "and struck the tile ahead: 1 damage")
	moves(game, "DU")
	eq(chaser.pos, Vector2i(1, 0), "adjacent: attacks without stepping")
	eq(game.state.player.hp, 1, "1 damage")


func test_chaser_strike_only_in_walking_direction() -> void:
	var game := make("P..\n...\n..c", NO_KILL_WIN)
	var chaser := game.state.enemies[0]
	chaser.active = true
	game.state.player.pos = Vector2i(1, 0)
	moves(game, "LR") # chaser walks one step, the player is not straight ahead
	eq(Grid.manhattan(chaser.pos, Vector2i(1, 0)), 2, "chaser moved one tile closer")
	eq(game.state.player.hp, 3, "no strike around a corner")


func test_hazard_only_counts_at_turn_end() -> void:
	var through := make("P^..", NO_KILL_WIN)
	moves(through, "RR")
	eq(through.state.player.hp, 3, "passing over a hazard mid-turn is safe")
	var stay := make("P.^.", NO_KILL_WIN)
	moves(stay, "RR")
	eq(stay.state.player.hp, 2, "ending the turn on it hurts")


func test_walking_into_a_projectile_hits() -> void:
	var game := make("P....", NO_KILL_WIN)
	game.state.spawn_projectile(Vector2i(1, 0), R, 1, 1)
	moves(game, "R")
	eq(game.state.player.hp, 2, "hit on entering its tile, mid-turn")
	eq(game.state.projectiles.size(), 0, "projectile destroyed")


# --- separate enemy phase (view toggle) --------------------------------------

func test_enemy_phase_pauses_and_resumes() -> void:
	var game := make("P.......\n........\n.......c", NO_KILL_WIN)
	game.pause_before_enemies = true
	var chaser := game.state.enemies[0]
	chaser.active = true
	moves(game, "R")
	eq(game.is_enemy_phase_pending(), false, "no pause after the first move")
	moves(game, "D")
	eq(game.is_enemy_phase_pending(), true, "paused after the second move")
	eq(game.state.player.pos, Vector2i(1, 1), "the player's moves are done")
	eq(chaser.pos, Vector2i(7, 2), "enemies have not acted yet")
	eq(game.try_move(R), false, "no input while the enemy phase is pending")
	eq(game.resume_enemy_phase(), true, "resumed")
	check(chaser.pos != Vector2i(7, 2), "enemies acted")
	eq(game.is_enemy_phase_pending(), false, "nothing pending afterwards")
	eq(game.state.turn_count, 1, "turn completed")
	eq(game.resume_enemy_phase(), false, "nothing to resume")


func test_enemy_phase_skipped_when_nothing_acts() -> void:
	var game := make("P.......\n........\n.......c", NO_KILL_WIN)
	game.pause_before_enemies = true
	moves(game, "RD")
	eq(game.is_enemy_phase_pending(), false, "idle enemies: no pause")


func test_enemy_phase_pause_does_not_change_the_outcome() -> void:
	var room := "P....\n.....\n..c.s\n....."
	var results := []
	for pause in [false, true]:
		var game := make(room, NO_KILL_WIN)
		game.pause_before_enemies = pause
		for e in game.state.enemies:
			e.active = true
		for c in "RRDULRDD":
			game.try_move("URDL".find(c))
			while game.is_enemy_phase_pending():
				game.resume_enemy_phase()
		var enemies: Array = game.state.enemies.map(func(e: Unit) -> Array: return [e.pos, e.hp])
		results.append([game.state.player.pos, game.state.player.hp, enemies, game.state.projectiles.size(), game.state.turn_count])
	eq(results[1], results[0], "same board with and without the pause")


func test_enemy_phase_pause_inside_slow_terrain() -> void:
	var game := make("P~..\n....\n...c", NO_KILL_WIN)
	game.pause_before_enemies = true
	game.state.enemies[0].active = true
	moves(game, "D") # first move of the turn
	moves(game, "U") # second move ends the turn
	eq(game.is_enemy_phase_pending(), true, "paused")
	game.resume_enemy_phase()
	moves(game, "R") # wading takes both steps of the next turn; the second ends it
	eq(game.is_enemy_phase_pending(), true, "paused on the wading move's second step")
	eq(game.state.player.pos, Vector2i(1, 0), "player arrived in the slow tile")
	game.resume_enemy_phase()
	eq(game.state.reserved_tile, GameState.NO_TILE, "reservation released afterwards")


func test_restart_clears_pending_enemy_phase() -> void:
	var game := make("P.......\n........\n.......c", NO_KILL_WIN)
	game.pause_before_enemies = true
	game.state.enemies[0].active = true
	moves(game, "RD")
	game.restart()
	eq(game.is_enemy_phase_pending(), false, "restart drops the pause")
	eq(game.try_move(R), true, "input works again")


# --- movement and time -------------------------------------------------------

func test_invalid_move_costs_nothing() -> void:
	var game := classic("P.\n..", NO_KILL_WIN)
	eq(game.try_move(U), false, "off-grid move rejected")
	eq(game.try_move(L), false, "off-grid move rejected")
	eq(game.state.step_count, 0, "no step passed")
	eq(game.state.history.size(), 0, "history untouched")
	var walled := classic("P#\n..", NO_KILL_WIN)
	eq(walled.try_move(R), false, "wall rejected")
	eq(walled.state.step_count, 0, "no step passed")


func test_move_into_enemy_is_invalid_by_default() -> void:
	var game := classic("Pc\n..")
	game.state.enemies[0].stun = 99
	eq(game.try_move(R), false, "enemy tile rejected")
	eq(game.state.step_count, 0, "no step passed")


func test_boxed_in_passes_turn_and_chaser_attacks() -> void:
	var game := classic("P..c")
	moves(game, "R") # chaser steps next to the player and strikes ahead
	eq(game.state.enemies[0].pos, Vector2i(2, 0), "chaser approached")
	eq(game.state.player.hp, 2, "struck right after its step")
	moves(game, "L") # chaser follows and strikes again; player is now boxed in
	eq(game.state.player.hp, 1, "moving away one tile is not enough")
	eq(game.try_move(R), true, "boxed in: key press passes the turn")
	eq(game.state.history.size(), 2, "passed turn is not in the history")
	eq(game.state.status, GameState.Status.LOST, "adjacent chaser attacks, lost at zero health")


func test_boxed_in_lose_variant() -> void:
	var game := classic("P..c", {"boxed_in": GameRules.BoxedIn.LOSE})
	moves(game, "RLR")
	eq(game.state.status, GameState.Status.LOST, "boxed in counts as a loss")


# --- combat ------------------------------------------------------------------

func test_loop_kills_chaser_and_wins() -> void:
	var game := classic("....\n....\n.Pc.\n....")
	game.state.enemies[0].stun = 99
	moves(game, "ULDR") # ends where it started, facing right at the chaser
	eq(game.state.enemies.size(), 0, "chaser removed")
	eq(game.state.status, GameState.Status.WON, "all enemies dead wins")


func test_lstrike_damages_and_stuns() -> void:
	var game := classic("...s.\n..s..\nP....\n.....")
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
	var game := classic("P...\n....\n....\n...c")
	var chaser := game.state.enemies[0]
	chaser.active = true
	chaser.stun = 1
	moves(game, "R")
	eq(chaser.pos, Vector2i(3, 3), "skipped its action")
	moves(game, "L")
	check(chaser.pos != Vector2i(3, 3), "acts again afterwards")


func test_shooter_fires_stepping_projectile() -> void:
	var game := classic(".P.....s", NO_KILL_WIN)
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
	var swap := classic(".P....", NO_KILL_WIN)
	swap.state.spawn_projectile(Vector2i(2, 0), L, 1, 1)
	moves(swap, "R")
	eq(swap.state.player.hp, 2, "swapping tiles is a hit")
	eq(swap.state.projectiles.size(), 0, "projectile destroyed")

	var dodge := classic(".P....\n......", NO_KILL_WIN)
	dodge.state.spawn_projectile(Vector2i(2, 0), L, 1, 1)
	moves(dodge, "D")
	eq(dodge.state.player.hp, 3, "stepping aside dodges")
	eq(dodge.state.projectiles[0].pos, Vector2i(1, 0), "projectile flew on")


func test_projectile_destroyed_by_wall() -> void:
	var game := classic("P..\n#..", NO_KILL_WIN)
	game.state.spawn_projectile(Vector2i(2, 1), L, 1, 1)
	moves(game, "R")
	eq(game.state.projectiles.size(), 1, "still flying")
	moves(game, "R")
	eq(game.state.projectiles.size(), 0, "destroyed by the wall")


func test_boss_telegraphs_then_slams() -> void:
	var game := classic(".......\nP.....B\n.......")
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
	var game := classic("PE.....c")
	moves(game, "R")
	eq(game.state.status, GameState.Status.WON, "exit wins")


func test_player_advantage_on_simultaneous_resolution() -> void:
	var game := classic("cPE")
	game.state.player.hp = 1
	moves(game, "R")
	eq(game.state.status, GameState.Status.WON, "win is checked before enemies act")
	eq(game.state.player.hp, 1, "the adjacent chaser never attacked")


# --- terrain and pickups -----------------------------------------------------

func test_slow_terrain_takes_two_steps_one_history_entry() -> void:
	var game := classic("P~..", NO_KILL_WIN)
	moves(game, "R")
	eq(game.state.player.pos, Vector2i(1, 0), "advanced one tile")
	eq(game.state.step_count, 2, "world stepped twice")
	eq(game.state.history.size(), 1, "one history entry")
	moves(game, "R")
	eq(game.state.step_count, 3, "leaving slow terrain is a normal step")


func test_hazard_damages_at_end_of_step() -> void:
	var game := classic("P^.", NO_KILL_WIN)
	moves(game, "R")
	eq(game.state.player.hp, 2, "1 damage")
	moves(game, "R")
	eq(game.state.player.hp, 2, "no damage after leaving")
	var off := classic("P^.", {"win_on_all_enemies_dead": false, "terrain_affects_player": false})
	moves(off, "R")
	eq(off.state.player.hp, 3, "switch turns terrain off for the player")


func test_upgrade_pickup() -> void:
	var game := make("PU..", NO_KILL_WIN)
	moves(game, "R")
	var choice := game.state.current_choice()
	check(choice != null, "choice opened")
	eq(choice.options.size(), 2, "one upgrade per spear attack")
	eq(game.state.step_count, 1, "picking up costs no extra step")
	eq(game.try_move(R), false, "world is paused while the choice is open")
	game.choose(0)
	eq(game.state.current_choice(), null, "choice closed")
	eq(game.state.find_ability(&"spear_throw").effects[0].amount, 2, "+1 damage applied")
	var source: AbilityDef = load("res://data/abilities/spear_throw.tres")
	eq(source.effects[0].amount, 1, "data file untouched")
	eq(game.state.tile_at(Vector2i(1, 0)).id, &"floor", "pickup consumed")
	eq(game.try_move(R), true, "game continues")


func test_new_ability_pickup() -> void:
	var game := make("PA......", NO_KILL_WIN)
	var fired := record_abilities(game)
	moves(game, "R")
	eq(game.state.current_choice().options.size(), 2, "recoil is no longer offered")
	game.choose(0)
	eq(game.state.abilities.size(), 3, "ability added")
	eq(game.state.abilities[2].id, &"lance", "lance gained")
	moves(game, "R")
	eq(fired.get(2), ["Spear Throw"], "two moves: only the spear throw")
	moves(game, "RR")
	eq(fired.get(3), ["Lance"], "the lance completes mid-turn, across the turn boundary")
	eq(fired.get(4), ["Spear Throw"], "the next throw, no lance self-overlap")
	moves(game, "RR")
	eq(fired.get(5), null, "nothing on move 5: both would overlap themselves")
	eq(fired.get(6), ["Spear Throw", "Lance"], "both again on move 6")


# --- vision ------------------------------------------------------------------

func test_walls_block_sight_and_activation() -> void:
	var game := classic("P#c\n...")
	eq(game.state.is_visible(Vector2i(2, 0)), false, "tile behind wall hidden")
	eq(game.state.enemies[0].active, false, "unseen enemy stays idle")
	moves(game, "D")
	moves(game, "R")
	eq(game.state.is_visible(Vector2i(2, 0)), true, "visible around the corner")
	eq(game.state.enemies[0].active, true, "activates once seen in range")


func test_enemy_out_of_range_stays_idle() -> void:
	var game := classic("P.......c\n.........")
	moves(game, "D")
	eq(game.state.enemies[0].active, false, "idle beyond activation range")
	eq(game.state.enemies[0].pos, Vector2i(8, 0), "did not move")


# --- mirroring ---------------------------------------------------------------

func test_mirrorable_pattern_matches_its_mirror_image() -> void:
	var ability := AbilityDef.new()
	ability.id = &"hook"
	ability.pattern = [U, R] as Array[Grid.Dir]
	ability.area = [Vector2i(1, 0)] as Array[Vector2i] # one tile further right
	var list: Array[AbilityDef] = [ability]
	var mirror: Array[int] = [U, L]
	var mirror_rotated: Array[int] = [R, U] # mirror image, one quarter turn
	eq(PatternMatcher.find_matches(mirror, list, {}).size(), 0, "not mirrored by default")
	ability.mirrorable = true
	var m := PatternMatcher.find_matches(mirror, list, {})
	eq(m.size(), 1, "mirror image matches")
	eq(m[0].mirrored, true, "flagged as mirrored")
	eq(m[0].rotation, 0, "no rotation needed")
	eq(ability.area_tiles(Vector2i(5, 5), 0, null, true), [Vector2i(4, 5)], "area flips to the left")
	var as_written: Array[int] = [U, R]
	eq(PatternMatcher.find_matches(as_written, list, {})[0].mirrored, false, "the pattern as written is not mirrored")
	m = PatternMatcher.find_matches(mirror_rotated, list, {})
	eq(m.size(), 1, "mirror image matches rotated")
	eq([m[0].mirrored, m[0].rotation], [true, 1], "mirrored, one quarter turn")
	eq(ability.area_tiles(Vector2i(5, 5), 1, null, true), [Vector2i(5, 4)], "area flips, then rotates")
	ability.rotatable = false
	eq(PatternMatcher.find_matches(mirror_rotated, list, {}).size(), 0, "mirroring alone does not rotate")
	eq(PatternMatcher.find_matches(mirror, list, {}).size(), 1, "but still mirrors")


func test_mirrored_ability_hits_the_mirrored_tiles() -> void:
	var game := make("""
.....
c....
.....
.P...
.....
""", NO_KILL_WIN)
	var hook := AbilityDef.new()
	hook.id = &"hook"
	hook.pattern = [U, L] as Array[Grid.Dir]
	hook.mirrorable = true
	hook.area = [Vector2i(0, 1)] as Array[Vector2i]
	var damage := DamageEffect.new()
	damage.amount = 1
	hook.effects = [damage] as Array[AbilityEffect]
	var list: Array[AbilityDef] = [hook]
	game.state.abilities = list
	# U, R is the mirror image of U, L. Canonical ends on (0,2) and hits (0,1).
	moves(game, "U")
	eq(game.preview(R).hits[0].tiles, [Vector2i(2, 1)], "preview of the mirrored move")
	eq(game.preview(L).hits[0].tiles, [Vector2i(0, 1)], "preview of the move as written")
	moves(game, "L")
	eq(game.state.enemies[0].hp, 1, "the pattern as written hits the chaser")


# --- pattern progress --------------------------------------------------------

func test_progress_counts_the_walked_start_of_a_pattern() -> void:
	var ability := AbilityDef.new()
	ability.id = &"long"
	ability.pattern = [U, U, R, R] as Array[Grid.Dir]
	# Turns of two moves; the pattern is longer than a turn.
	var none: Array[int] = []
	eq(PatternMatcher.progress(none, ability, -1, 0, 0, 2), 0, "nothing walked")
	var one: Array[int] = [L]
	eq(PatternMatcher.progress(one, ability, -1, 0, 1, 2), 1, "any first move starts a rotatable pattern")
	eq(PatternMatcher.progress(one, ability, -1, 1, 0, 1), 1, "also with one move per turn")
	eq(PatternMatcher.progress(one, ability, -1, 0, 1, 3), 0, "but not if it could not end on a turn end")
	var two: Array[int] = [L, L]
	eq(PatternMatcher.progress(two, ability, -1, 2, 0, 2), 2, "two moves, rotated")
	var three: Array[int] = [L, L, U]
	eq(PatternMatcher.progress(three, ability, -1, 2, 1, 2), 3, "three moves")
	var broken: Array[int] = [L, L, D]
	eq(PatternMatcher.progress(broken, ability, -1, 2, 1, 2), 1, "a wrong move starts over with itself")
	eq(PatternMatcher.progress(two, ability, 0, 2, 0, 2), 0, "moves of the previous trigger do not count")
	var mirror: Array[int] = [U, U, L]
	eq(PatternMatcher.progress(mirror, ability, -1, 2, 1, 2), 1, "not mirrored by default: only the last move counts")
	ability.mirrorable = true
	eq(PatternMatcher.progress(mirror, ability, -1, 2, 1, 2), 3, "mirror image counts when mirrorable")
	ability.rotatable = false
	ability.mirrorable = false
	eq(PatternMatcher.progress(two, ability, -1, 2, 0, 2), 0, "no rotation when not rotatable")


func test_progress_of_a_short_pattern_stays_inside_the_turn() -> void:
	var ability := AbilityDef.new()
	ability.id = &"short"
	ability.pattern = [U, R] as Array[Grid.Dir]
	var first: Array[int] = [U]
	eq(PatternMatcher.progress(first, ability, -1, 0, 1, 2), 1, "first move of the turn")
	var second: Array[int] = [D, U]
	eq(PatternMatcher.progress(second, ability, -1, 2, 0, 2), 0, "last move of a turn cannot start it")


func test_game_reports_progress_and_resets_after_the_trigger() -> void:
	var game := make("""
.....
.....
.....
.P...
.....
""", NO_KILL_WIN)
	var hook := AbilityDef.new()
	hook.id = &"hook"
	hook.pattern = [U, L] as Array[Grid.Dir]
	var list: Array[AbilityDef] = [hook]
	game.state.abilities = list
	eq(game.ability_progress(hook), 0, "nothing yet")
	moves(game, "U")
	eq(game.ability_progress(hook), 1, "one move walked")
	moves(game, "L")
	eq(game.ability_progress(hook), 0, "starts over after firing")
	moves(game, "R")
	eq(game.ability_progress(hook), 1, "rotated start")
	moves(game, "R")
	eq(game.ability_progress(hook), 1, "the turn boundary does not reset it")

	var rules := NO_KILL_WIN.duplicate()
	rules["abilities_only_at_turn_end"] = true
	var strict := make(OPEN_ROOM, rules)
	strict.state.abilities = list
	moves(strict, "U")
	eq(strict.ability_progress(hook), 1, "turn-end rule: first move of the turn counts")
	moves(strict, "U")
	eq(strict.ability_progress(hook), 0, "turn-end rule: the last move of a turn cannot start it")


# --- sandbox -----------------------------------------------------------------

func test_invulnerable_player_takes_no_damage() -> void:
	var room := """
.c.
.P.
...
"""
	var game := make(room, {"player_moves_per_turn": 1})
	moves(game, "D")
	eq(game.state.player.hp, 2, "normally the chaser's strike lands")
	game = make(room, {"player_moves_per_turn": 1, "player_invulnerable": true})
	moves(game, "D")
	eq(game.state.player.hp, 3, "no damage when invulnerable")


func test_default_design_plays_like_the_shipped_game() -> void:
	var design := Design.from_defaults(_base)
	check(design.is_usable(), "usable")
	eq([design.width(), design.height()], [16, 16], "room size")
	eq(design.abilities.size(), 7, "all abilities listed")
	var game := Game.new(design.make_config(_base), design.room_text(), design.tiles, design.enemies)
	eq(game.state.enemies.size(), 6, "six enemies")
	eq(game.state.player.pos, Vector2i(5, 15), "player start")
	eq(game.state.tile_at(Vector2i(13, 0)).id, &"exit", "exit tile")
	eq(game.state.abilities.map(func(a: AbilityDef) -> StringName: return a.id), [&"spear_throw", &"spear_thrust"], "starting abilities")
	eq(game.config.rules.fog_enabled, true, "fog on")


func test_design_is_independent_of_the_data_files() -> void:
	var design := Design.from_defaults(_base)
	var chaser := design.enemy_by_symbol("c")
	chaser.max_health = 9
	(chaser.behavior as ChaseBehavior).damage = 5
	design.tile_by_symbol("^").on_end_step[0].set("amount", 4)
	design.player.max_health = 7
	var throw := design.player.starting_abilities[0]
	check(design.abilities.has(throw), "starting abilities are entries of the ability list")
	throw.pattern.append(U)
	throw.effects[0].set("amount", 6)
	eq((load("res://data/enemies/chaser.tres") as EnemyDef).max_health, 2, "enemy data untouched")
	eq(((load("res://data/enemies/chaser.tres") as EnemyDef).behavior as ChaseBehavior).damage, 1, "behaviour data untouched")
	eq((load("res://data/tiles/hazard.tres") as TileDef).on_end_step[0].get("amount"), 1, "tile data untouched")
	eq(_base.player.max_health, 3, "player data untouched")
	var data_throw := load("res://data/abilities/spear_throw.tres") as AbilityDef
	eq(data_throw.pattern.size(), 2, "ability pattern untouched")
	eq(data_throw.effects[0].get("amount"), 1, "ability effect untouched")
	var game := Game.new(design.make_config(_base), design.room_text(), design.tiles, design.enemies)
	eq(game.state.player.max_hp, 7, "the game plays the edited player")
	eq(game.state.enemies.filter(func(e: Unit) -> bool: return e.def.id == &"chaser")[0].max_hp, 9, "and the edited chaser")
	eq(game.state.abilities[0].pattern.size(), 3, "and the edited ability")


func test_design_room_editing() -> void:
	var design := Design.from_defaults(_base)
	design.set_room_text("...\n.P.\n...")
	eq(design.set_cell(Vector2i(0, 0), "#"), true, "paint a wall")
	eq(design.set_cell(Vector2i(0, 0), "#"), false, "painting the same again changes nothing")
	eq(design.set_cell(Vector2i(2, 2), "c"), true, "place a chaser")
	eq(design.set_cell(Vector2i(1, 1), "#"), false, "the player start cannot be painted over")
	eq(design.set_cell(Vector2i(2, 0), "P"), true, "move the player start")
	eq(Array(design.rows), ["#.P", "...", "..c"], "one player start, old one is floor")
	design.resize(5, 4)
	eq(Array(design.rows), ["#.P..", ".....", "..c..", "....."], "grows with floor")
	design.resize(1, 1)
	eq([design.width(), design.height()], [Design.MIN_SIZE, Design.MIN_SIZE], "size is clamped")
	design.resize(5, 5)
	design.set_cell(Vector2i(4, 4), "P")
	design.resize(3, 3)
	eq(design.player_pos(), Vector2i(2, 2), "a cut-off player start moves inside")
	var game := Game.new(design.make_config(_base), design.room_text(), design.tiles, design.enemies)
	eq([game.state.width, game.state.height], [3, 3], "the game plays the edited room")
	eq(game.state.player.pos, Vector2i(2, 2), "from the edited start")


func test_design_ability_list() -> void:
	var design := Design.from_defaults(_base)
	var lance: AbilityDef
	for a in design.abilities:
		if a.id == &"lance":
			lance = a
	design.set_starting(lance, true)
	eq(design.player.starting_abilities.map(func(a: AbilityDef) -> StringName: return a.id), [&"lance", &"spear_throw", &"spear_thrust"], "starting abilities keep list order")
	var fresh := AbilityDef.new()
	fresh.id = design.free_ability_id()
	eq(fresh.id, &"custom_1", "first free id")
	design.add_ability(fresh)
	eq(design.free_ability_id(), &"custom_2", "next free id")
	check(design.is_starting(fresh), "a new ability is a starting ability")
	design.remove_ability(fresh)
	check(not design.abilities.has(fresh) and not design.is_starting(fresh), "removed everywhere")


func test_design_testing_aids() -> void:
	var design := Design.from_defaults(_base)
	design.fog_off = true
	design.invulnerable = true
	var config := design.make_config(_base)
	eq([config.rules.fog_enabled, config.rules.player_invulnerable], [false, true], "switches set")
	eq([_base.rules.fog_enabled, _base.rules.player_invulnerable], [true, false], "shipped rules untouched")


func test_design_survives_saving_and_loading() -> void:
	var path := "res://local/_test_design.tres"
	var design := Design.from_defaults(_base)
	design.set_cell(Vector2i(0, 15), "#")
	design.enemy_by_symbol("B").max_health = 11
	design.abilities[0].mirrorable = true
	design.invulnerable = true
	var added := AbilityDef.new()
	added.id = design.free_ability_id()
	added.pattern = [U, L, U] as Array[Grid.Dir]
	added.area = [Vector2i(0, 1)] as Array[Vector2i]
	var stun := StunEffect.new()
	stun.turns = 3
	stun.area = [Vector2i(1, 1)] as Array[Vector2i]
	added.effects = [stun] as Array[AbilityEffect]
	design.add_ability(added)
	eq(design.save(path), OK, "saved")
	var loaded := Design.load_saved(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(loaded != null, "loaded")
	if loaded == null:
		return
	eq(Array(loaded.rows), Array(design.rows), "room")
	eq(loaded.enemy_by_symbol("B").max_health, 11, "enemy tuning")
	eq(loaded.abilities[0].mirrorable, true, "ability flag")
	eq(loaded.invulnerable, true, "testing aid")
	eq(loaded.abilities.size(), 8, "added ability kept")
	var again := loaded.abilities[7]
	eq([again.id, Array(again.pattern)], [&"custom_1", [U, L, U]], "its id and pattern")
	eq([(again.effects[0] as StunEffect).turns, again.effects[0].area], [3, [Vector2i(1, 1)]], "its effect with its own area")
	check(loaded.abilities.has(loaded.player.starting_abilities[0]), "starting abilities are still entries of the list")
	eq(loaded.player.starting_abilities.size(), 3, "three starting abilities")
	eq(Design.load_saved("res://local/_missing.tres"), null, "no file, no design")


# --- shipped content ---------------------------------------------------------

func test_shipped_room_loads() -> void:
	var game := Game.new(_base)
	eq(game.state.width, 16, "width")
	eq(game.state.height, 16, "height")
	eq(game.state.enemies.size(), 6, "six enemies")
	eq(game.state.player.pos, Vector2i(5, 15), "player start")
	eq(game.state.tile_at(Vector2i(13, 0)).id, &"exit", "exit tile")
	eq(game.state.abilities.size(), 2, "two starting abilities")
	eq(game.state.abilities[0].id, &"spear_throw", "spear throw")
	eq(game.state.abilities[1].id, &"spear_thrust", "spear thrust")
	eq(game.config.rules.player_moves_per_turn, 2, "two moves per turn")
	var hp := {}
	for e in game.state.enemies:
		hp[e.def.id] = e.max_hp
	eq(hp, {&"chaser": 2, &"shooter": 2, &"boss": 6}, "enemy health")
	eq(game.state.is_seen(Vector2i(14, 0)), true, "exit visible from the start")
	eq(game.state.is_visible(Vector2i(14, 0)), false, "but not in current vision")
	eq(game.try_move(U), true, "can move")
