class_name AbilityPanel
extends Control
## Lists the player's abilities with their pattern and effect area, like the
## left side of the mockup. Entirely generated from the ability data.

const CELL := 20.0
const AREA_X := 150.0

var game: Game


func bind(new_game: Game) -> void:
	game = new_game
	queue_redraw()


func _draw() -> void:
	if game == null:
		return
	var font := get_theme_default_font()
	DrawUtil.text(self, font, Vector2(0, 22), "Player Abilities", 22)
	draw_line(Vector2(0, 28), Vector2(168, 28), DrawUtil.INK, 1.5)
	var y := 46.0
	for ability in game.state.abilities:
		y = _draw_ability(ability, y, font) + 18.0


func _draw_ability(ability: AbilityDef, top: float, font: Font) -> float:
	draw_rect(Rect2(0, top + 2, 14, 14), ability.color)
	DrawUtil.text(self, font, Vector2(22, top + 15), ability.display_name, 17)
	DrawUtil.text(self, font, Vector2(0, top + 36), ability.describe(), 14)
	var note := "any rotation, never mirrored" if ability.rotatable else "this direction only"
	DrawUtil.text(self, font, Vector2(0, top + 53), note, 11, DrawUtil.MUTED)
	var diagram_top := top + 64.0
	var pattern_height := _draw_pattern(ability, Vector2(4, diagram_top))
	var area_height := _draw_area(ability, Vector2(AREA_X, diagram_top))
	return diagram_top + maxf(pattern_height, area_height)


## The movement pattern as a path of arrows starting at a dot.
func _draw_pattern(ability: AbilityDef, origin: Vector2) -> float:
	var points: Array[Vector2i] = [Vector2i.ZERO]
	var lo := Vector2i.ZERO
	var hi := Vector2i.ZERO
	for dir in ability.pattern:
		var next := points[-1] + Grid.vec(dir)
		points.append(next)
		lo = Vector2i(mini(lo.x, next.x), mini(lo.y, next.y))
		hi = Vector2i(maxi(hi.x, next.x), maxi(hi.y, next.y))
	var step := CELL * 1.2
	var to_screen := func(p: Vector2i) -> Vector2:
		return origin + Vector2(p - lo) * step + Vector2(8, 8)
	for i in range(1, points.size()):
		# Shorten each segment a little so consecutive arrow heads stay visible.
		var from: Vector2 = to_screen.call(points[i - 1])
		var to: Vector2 = to_screen.call(points[i])
		DrawUtil.arrow(self, from.lerp(to, 0.12), from.lerp(to, 0.92), DrawUtil.INK, 2.5, 8.0)
	draw_circle(to_screen.call(points[0]), 5.0, DrawUtil.INK)
	return (hi.y - lo.y) * step + 16.0


## The effect area on a small grid; the blue square is the tile where the
## pattern ends (the player), as in the canonical orientation.
func _draw_area(ability: AbilityDef, origin: Vector2) -> float:
	var offsets := ability.area_offsets(0)
	var lo := Vector2i(-1, -1)
	var hi := Vector2i(1, 1)
	for o in offsets:
		lo = Vector2i(mini(lo.x, o.x), mini(lo.y, o.y))
		hi = Vector2i(maxi(hi.x, o.x), maxi(hi.y, o.y))
	# When effects cover different tiles, each cell is marked with the initial
	# of the effects that reach it (D = damage, S = stun).
	var per_effect := false
	for effect in ability.effects:
		if not effect.area.is_empty():
			per_effect = true
	var font := get_theme_default_font()
	var player_color := game.state.player_color
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var cell := Vector2i(x, y)
			var rect := Rect2(origin + Vector2(cell - lo) * CELL, Vector2(CELL, CELL))
			draw_rect(rect, ability.color.lerp(Color.WHITE, 0.5) if offsets.has(cell) else Color.WHITE)
			draw_rect(rect, Color.BLACK, false, 1.0)
			if cell == Vector2i.ZERO:
				draw_rect(rect.grow(-5.0), player_color)
			elif per_effect and offsets.has(cell):
				var marks := ""
				for effect in ability.effects:
					if ability.area_offsets(0, effect).has(cell):
						marks += String(effect.kind()).left(1).to_upper()
				DrawUtil.text_centered(self, font, rect, marks, 10)
	return (hi.y - lo.y + 1) * CELL
