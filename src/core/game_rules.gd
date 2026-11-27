class_name GameRules
extends Resource
## Rule switches for the open [Default] points of DESIGN.md, plus the ordered
## list of step phases. Edit data/rules.tres to compare variants.

enum BoxedIn {
	PASS_TURN, ## A key press passes the turn without moving.
	LOSE, ## Being boxed in loses the room.
	NOTHING, ## Key presses do nothing.
}
enum MoveIntoEnemy {
	INVALID, ## The move is rejected like a move into a wall.
	SWAP, ## Player and enemy swap tiles; counts as a normal move.
}

@export_group("Movement")
@export var boxed_in: BoxedIn = BoxedIn.PASS_TURN
@export var move_into_enemy: MoveIntoEnemy = MoveIntoEnemy.INVALID
## Player moves per turn. Phases flagged `turn_end_only` (abilities, enemies,
## projectiles, hazards) run once per turn, after the last of these moves.
@export_range(1, 4) var player_moves_per_turn := 2

@export_group("Abilities")
## The player is hit by their own abilities when standing in the area.
@export var self_damage := false
## Off: an ability fires on the move that completes its pattern, on any move
## of a turn, and a pattern may start in one turn and end in the next.
## On: abilities fire only on the last move of a turn, and a pattern no longer
## than a turn must lie inside that turn.
@export var abilities_only_at_turn_end := false
## Ability areas need a clear line from the end tile to each affected tile.
@export var walls_block_effects := false
@export var abilities_destroy_projectiles := false

@export_group("Terrain")
## Hazard damage and slow move cost apply to the player.
@export var terrain_affects_player := true
## Hazard damage and slow move cost apply to enemies.
@export var terrain_affects_enemies := true

@export_group("Vision and activation")
@export var fog_enabled := true
## Tiles seen once stay on the map in a dimmed state.
@export var remember_seen_tiles := true
## How "N tiles" is measured for vision and activation range.
@export var distance_metric: Grid.Metric = Grid.Metric.EUCLIDEAN
## Enemies only activate while the player can see them.
@export var activation_requires_sight := true
## An idle enemy that takes damage becomes active.
@export var damage_activates_enemies := true

@export_group("Winning")
@export var win_on_exit := true
@export var win_on_all_enemies_dead := true

@export_group("Testing aids")
## The player takes no damage. Switched from the sandbox layer.
@export var player_invulnerable := false

@export_group("Step resolution")
## Runs top to bottom once per world step. Reorder, remove or insert phases here.
@export var phases: Array[StepPhase] = []
