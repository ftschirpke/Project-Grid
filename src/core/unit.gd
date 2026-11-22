class_name Unit
extends RefCounted
## Runtime state of the player or of one enemy.

var is_player := false
var def: EnemyDef ## null for the player
var pos := Vector2i.ZERO
var prev_pos := Vector2i.ZERO ## position at the start of the current step
var hp := 1
var max_hp := 1
var stun := 0 ## number of actions this unit will skip
var active := false ## enemies idle until activated
## Free per-unit storage for behaviours (cooldowns, timers).
var memory: Dictionary = {}
## Tiles this unit has marked for an attack on its next action.
var telegraph: Array[Vector2i] = []
## Progress of a multi-step move into slow terrain.
var wade_target := GameState.NO_TILE
var wade_progress := 0


func is_alive() -> bool:
	return hp > 0


func display_name() -> String:
	if is_player:
		return "Player"
	return def.display_name if def != null else "Enemy"
