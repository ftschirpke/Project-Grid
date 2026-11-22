class_name Projectile
extends RefCounted

var pos := Vector2i.ZERO
var dir: int = Grid.Dir.UP
var speed := 1 ## tiles per step
var damage := 1
var source: Unit
var alive := true
