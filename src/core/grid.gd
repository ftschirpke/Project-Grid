class_name Grid
extends RefCounted
## Direction and geometry helpers shared by the whole rules layer.
## Grid coordinates: x to the right, y DOWN (screen convention).
## Data files use the design document's convention (y UP); see design_to_grid().

## Ordered clockwise, so rotating by a quarter turn is "+1".
enum Dir { UP, RIGHT, DOWN, LEFT }
enum Metric { EUCLIDEAN, MANHATTAN, CHEBYSHEV }

const VECTORS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const NAMES: Array[String] = ["Up", "Right", "Down", "Left"]


static func vec(dir: int) -> Vector2i:
	return VECTORS[dir]


static func rotate_dir(dir: int, quarter_turns: int) -> int:
	return (dir + quarter_turns) % 4


## Left-right mirror image of a direction: up and down stay, left and right swap.
static func mirror_dir(dir: int) -> int:
	return (4 - dir) % 4


## Rotates a grid offset clockwise (as seen on screen) in 90 degree steps.
static func rotate_offset(offset: Vector2i, quarter_turns: int) -> Vector2i:
	var v := offset
	for i in quarter_turns % 4:
		v = Vector2i(-v.y, v.x)
	return v


## Converts an offset written as in DESIGN.md (y up) into grid space (y down).
static func design_to_grid(offset: Vector2i) -> Vector2i:
	return Vector2i(offset.x, -offset.y)


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func within(a: Vector2i, b: Vector2i, radius: float, metric: int) -> bool:
	var dx := absi(a.x - b.x)
	var dy := absi(a.y - b.y)
	match metric:
		Metric.MANHATTAN:
			return dx + dy <= radius
		Metric.CHEBYSHEV:
			return maxi(dx, dy) <= radius
		_:
			return dx * dx + dy * dy <= radius * radius


## Bresenham line from a to b, both endpoints included.
static func line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var cur := a
	while true:
		points.append(cur)
		if cur == b:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			cur.x += sx
		if e2 <= dx:
			err += dx
			cur.y += sy
	return points
