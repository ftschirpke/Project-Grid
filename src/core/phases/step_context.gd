class_name StepContext
extends RefCounted
## Per-step scratch data handed from phase to phase.

## Direction the player is moving in, or -1 for a passed turn.
var dir := -1
var target := GameState.NO_TILE
## False on the extra steps spent wading into slow terrain.
var completes_move := false
## Set by the move phase once the player actually changed tile.
var moved := false
