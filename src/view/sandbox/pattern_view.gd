class_name PatternView
extends Control
## A movement pattern as a path of arrows starting at a dot.

const STEP := 30.0
const PAD := 14.0

var pattern: Array = []:
	set(value):
		pattern = value
		refresh()


## Call after the pattern array was changed in place.
func refresh() -> void:
	var box := _bounds()
	custom_minimum_size = Vector2(box.size) * STEP + Vector2(PAD, PAD) * 2.0
	queue_redraw()


func _points() -> Array[Vector2i]:
	var points: Array[Vector2i] = [Vector2i.ZERO]
	for dir: int in pattern:
		points.append(points[-1] + Grid.vec(dir))
	return points


func _bounds() -> Rect2i:
	var box := Rect2i(Vector2i.ZERO, Vector2i.ZERO)
	for point in _points():
		box = box.expand(point)
	return box


func _draw() -> void:
	var points := _points()
	var low := _bounds().position
	var to_screen := func(p: Vector2i) -> Vector2:
		return Vector2(p - low) * STEP + Vector2(PAD, PAD)
	for i in range(1, points.size()):
		# Shorten each segment a little so consecutive arrow heads stay visible.
		var from: Vector2 = to_screen.call(points[i - 1])
		var to: Vector2 = to_screen.call(points[i])
		DrawUtil.arrow(self, from.lerp(to, 0.12), from.lerp(to, 0.92), Color.WHITE, 2.5, 9.0)
	draw_circle(to_screen.call(points[0]), 5.0, Color.WHITE)
