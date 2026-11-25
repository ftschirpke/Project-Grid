class_name SidePanel
extends Control
## Status column: health, recent moves, what each next move would trigger,
## a legend generated from the tile and enemy data, and a short event log.

const HISTORY_SHOWN := 8

var game: Game
var previews: Array = []
var log_lines: Array[String] = []


func bind(new_game: Game) -> void:
	game = new_game
	queue_redraw()


func _draw() -> void:
	if game == null:
		return
	var s := game.state
	var font := get_theme_default_font()
	var y := 22.0

	DrawUtil.text(self, font, Vector2(0, y), "Health", 18)
	for i in s.player.max_hp:
		var pip := Rect2(74 + i * 24, y - 15, 18, 18)
		if i < s.player.hp:
			draw_rect(pip, s.player_color)
		draw_rect(pip, Color.BLACK, false, 1.5)
	y += 26
	var per_turn := maxi(1, s.rules.player_moves_per_turn)
	DrawUtil.text(self, font, Vector2(0, y), "Turn %d, move %d/%d      Enemies left: %d" % [s.turn_count + 1, s.turn_step + 1, per_turn, s.enemies.size()], 14)

	y += 32
	DrawUtil.text(self, font, Vector2(0, y), "Last moves", 16)
	y += 10
	var shown := mini(HISTORY_SHOWN, s.history.size())
	for i in shown:
		var dir := s.history[s.history.size() - shown + i]
		var newest := i == shown - 1
		var color := DrawUtil.INK if newest else DrawUtil.MUTED
		DrawUtil.dir_arrow(self, Vector2(12 + i * 28, y + 14), dir, 20, color, 3.0 if newest else 2.0)
	if shown == 0:
		DrawUtil.text(self, font, Vector2(0, y + 18), "none yet", 13, DrawUtil.MUTED)

	y += 54
	DrawUtil.text(self, font, Vector2(0, y), "Next move", 16)
	y += 8
	for dir in 4:
		y += 22
		DrawUtil.dir_arrow(self, Vector2(10, y - 5), dir, 16, DrawUtil.INK, 2.0)
		_draw_preview_line(dir, Vector2(28, y), font)

	y += 34
	DrawUtil.text(self, font, Vector2(0, y), "Legend", 16)
	y += 8
	var column := 0
	var entries: Array = [[s.player_color, "You (health)"]]
	for enemy in game.enemy_types:
		entries.append([enemy.color, "%s (%d hp)" % [enemy.display_name, enemy.max_health]])
	for tile in game.tile_types:
		if tile.id != &"floor":
			entries.append([tile.color, tile.display_name])
	for entry in entries:
		var x := column * 140.0
		if column == 0:
			y += 22
		draw_rect(Rect2(x, y - 12, 14, 14), entry[0])
		draw_rect(Rect2(x, y - 12, 14, 14), Color.BLACK, false, 1.0)
		DrawUtil.text(self, font, Vector2(x + 20, y), entry[1], 13)
		column = (column + 1) % 2
	y += 20
	DrawUtil.text(self, font, Vector2(0, y), "Pale enemy = idle.  Yellow frame = stunned.", 11, DrawUtil.MUTED)
	y += 15
	DrawUtil.text(self, font, Vector2(0, y), "Red crossed tiles = attack lands next step.", 11, DrawUtil.MUTED)

	y += 32
	DrawUtil.text(self, font, Vector2(0, y), "Log", 16)
	for line in log_lines:
		y += 18
		DrawUtil.text(self, font, Vector2(0, y), line, 12, DrawUtil.MUTED)

	DrawUtil.text(self, font, Vector2(0, size.y - 6), "Arrows / WASD: move    1-3: choose    R: restart", 12, DrawUtil.MUTED)


func _draw_preview_line(dir: int, pos: Vector2, font: Font) -> void:
	if dir >= previews.size():
		DrawUtil.text(self, font, pos, "-", 13, DrawUtil.MUTED)
		return
	var preview: Dictionary = previews[dir]
	if not preview.valid:
		DrawUtil.text(self, font, pos, "blocked", 13, DrawUtil.MUTED)
		return
	if preview.hits.is_empty():
		var note := "nothing" if preview.ends_turn else "turn continues"
		DrawUtil.text(self, font, pos, note, 13, DrawUtil.MUTED)
		return
	var x := pos.x
	for hit in preview.hits:
		var ability: AbilityDef = hit.ability
		draw_rect(Rect2(x, pos.y - 11, 12, 12), ability.color)
		DrawUtil.text(self, font, Vector2(x + 16, pos.y), ability.display_name, 14)
		x += 24 + font.get_string_size(ability.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
