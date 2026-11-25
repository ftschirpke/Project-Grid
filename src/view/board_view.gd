class_name BoardView
extends Control
## Draws the room. Reads GameState only; never changes it.

const FOG := Color(0.2, 0.2, 0.24)
const DIM := Color(0.24, 0.24, 0.3)
const GRID_LINE := Color(0, 0, 0, 0.6)
const FLASH_TIME := 0.5
const TRAIL_LENGTH := 6

var game: Game
## Results of Game.preview() for the four directions.
var previews: Array = []
## Text shown across the top of the board, e.g. during the enemy phase.
var phase_banner := ""
var _flashes: Array = [] # { tiles, color, time }


func bind(new_game: Game) -> void:
	game = new_game
	_flashes.clear()
	queue_redraw()


## Briefly highlights tiles (ability fired, attack landed).
func flash(tiles: Array, color: Color) -> void:
	_flashes.append({"tiles": tiles.duplicate(), "color": color, "time": FLASH_TIME})
	set_process(true)
	queue_redraw()


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	for f in _flashes:
		f.time -= delta
	_flashes = _flashes.filter(func(f: Dictionary) -> bool: return f.time > 0.0)
	if _flashes.is_empty():
		set_process(false)
	queue_redraw()


func _tile_size() -> float:
	var s := game.state
	return floorf(minf(size.x / s.width, size.y / s.height))


func _origin() -> Vector2:
	var s := game.state
	var ts := _tile_size()
	return ((size - Vector2(s.width, s.height) * ts) * 0.5).floor()


func _rect(pos: Vector2i, inset: float = 0.0) -> Rect2:
	var ts := _tile_size()
	return Rect2(_origin() + Vector2(pos) * ts + Vector2(inset, inset), Vector2(ts - inset * 2.0, ts - inset * 2.0))


func _center(pos: Vector2i) -> Vector2:
	return _rect(pos).get_center()


func _draw() -> void:
	if game == null:
		return
	var s := game.state
	var ts := _tile_size()
	var font := get_theme_default_font()

	_draw_tiles(s, ts, font)
	_draw_trail(s, ts)
	_draw_telegraphs(s)
	_draw_previews(ts)
	_draw_units(s, ts, font)
	_draw_flashes()
	draw_rect(Rect2(_origin(), Vector2(s.width, s.height) * ts), Color.BLACK, false, 2.0)
	_draw_phase_banner(s, ts, font)
	_draw_end_banner(s, font)


func _draw_phase_banner(s: GameState, ts: float, font: Font) -> void:
	if phase_banner == "" or s.status != GameState.Status.PLAYING:
		return
	var board := Rect2(_origin(), Vector2(s.width, s.height) * ts)
	draw_rect(board, Color(0.6, 0.0, 0.08), false, 5.0)
	var band := Rect2(board.position, Vector2(board.size.x, 34))
	draw_rect(band, Color(0.45, 0.0, 0.06, 0.85))
	DrawUtil.text_centered(self, font, band, phase_banner, 20, Color.WHITE)


func _draw_tiles(s: GameState, ts: float, font: Font) -> void:
	for y in s.height:
		for x in s.width:
			var pos := Vector2i(x, y)
			var rect := _rect(pos)
			var tile := s.tile_at(pos)
			if s.is_visible(pos):
				draw_rect(rect, tile.color)
				_draw_tile_label(tile, rect, ts, font, 0.75)
			elif s.is_seen(pos):
				draw_rect(rect, tile.color.lerp(DIM, 0.55))
				_draw_tile_label(tile, rect, ts, font, 0.4)
			else:
				draw_rect(rect, FOG)
			draw_rect(rect, GRID_LINE, false, 1.0)


func _draw_tile_label(tile: TileDef, rect: Rect2, ts: float, font: Font, alpha: float) -> void:
	if tile.label != "":
		var font_size := int(ts * (0.5 if tile.label.length() <= 1 else 0.3))
		DrawUtil.text_centered(self, font, rect, tile.label, font_size, Color(0, 0, 0, alpha))


func _draw_trail(s: GameState, ts: float) -> void:
	var count := mini(TRAIL_LENGTH, s.trail.size() - 1)
	for i in count:
		var index := s.trail.size() - count + i
		var from := s.trail[index - 1]
		var to := s.trail[index]
		if Grid.manhattan(from, to) != 1:
			continue
		var alpha := 0.15 + 0.45 * float(i + 1) / count
		var color := Color(s.player_color, alpha)
		DrawUtil.arrow(self, _center(from), _center(to), color, maxf(2.0, ts * 0.08), ts * 0.22)


func _draw_telegraphs(s: GameState) -> void:
	for enemy in s.enemies:
		for pos in enemy.telegraph:
			if not s.is_visible(pos):
				continue
			var rect := _rect(pos, 2.0)
			draw_rect(rect, Color(1, 0, 0, 0.28))
			draw_rect(rect, Color(0.85, 0, 0), false, 3.0)
			draw_line(rect.position, rect.end, Color(0.85, 0, 0, 0.7), 2.0)
			draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), Color(0.85, 0, 0, 0.7), 2.0)


## For every direction that would fire something: an arrow on the tile the
## player would step to, and outlines on the tiles that would be hit. Each
## hit uses the ability's colour and its own inset so overlaps stay readable.
func _draw_previews(ts: float) -> void:
	var slot := 0
	for preview in previews:
		if not preview.valid or preview.hits.is_empty():
			continue
		for hit in preview.hits:
			var color: Color = hit.ability.color
			var inset := 2.0 + 3.0 * (slot % 5)
			for pos in hit.tiles:
				draw_rect(_rect(pos, inset), color, false, 2.0)
			slot += 1
		var first_color: Color = preview.hits[0].ability.color
		DrawUtil.dir_arrow(self, _center(preview.target), preview.dir, ts * 0.5, first_color, maxf(3.0, ts * 0.1))


func _draw_units(s: GameState, ts: float, font: Font) -> void:
	var font_size := int(ts * 0.38)
	for enemy in s.enemies:
		if not s.is_visible(enemy.pos):
			continue
		var rect := _rect(enemy.pos, ts * 0.16)
		var color := enemy.def.color
		if not enemy.active:
			color = color.lerp(Color(0.75, 0.75, 0.75), 0.55)
		draw_rect(rect, color)
		draw_rect(rect, Color.BLACK, false, 1.5)
		if enemy.stun > 0:
			draw_rect(rect.grow(3.0), Color(1.0, 0.85, 0.0), false, 3.0)
		DrawUtil.text_centered(self, font, rect, str(enemy.hp), font_size, Color.WHITE)

	for p in s.projectiles:
		if not s.is_visible(p.pos):
			continue
		var c := _center(p.pos)
		draw_circle(c, ts * 0.17, Color(0.85, 0.1, 0.1))
		draw_arc(c, ts * 0.17, 0.0, TAU, 20, Color.BLACK, 1.5, true)
		DrawUtil.dir_arrow(self, c + Vector2(Grid.vec(p.dir)) * ts * 0.3, p.dir, ts * 0.3, Color.BLACK, 2.0)

	var player_rect := _rect(s.player.pos, ts * 0.16)
	draw_rect(player_rect, s.player_color)
	draw_rect(player_rect, Color.BLACK, false, 1.5)
	DrawUtil.text_centered(self, font, player_rect, str(maxi(s.player.hp, 0)), font_size, Color.WHITE)


func _draw_flashes() -> void:
	for f in _flashes:
		var strength: float = f.time / FLASH_TIME
		var color: Color = f.color
		for pos in f.tiles:
			draw_rect(_rect(pos), Color(color, 0.7 * strength))
			draw_rect(_rect(pos, 1.5), Color(color, strength), false, 3.0)


func _draw_end_banner(s: GameState, font: Font) -> void:
	if s.status == GameState.Status.PLAYING:
		return
	var won := s.status == GameState.Status.WON
	var band := Rect2(Vector2(0, size.y * 0.5 - 60), Vector2(size.x, 120))
	draw_rect(band, Color(0, 0, 0, 0.82))
	var title := "ROOM CLEARED" if won else "DEFEATED"
	var title_color := Color(0.4, 1.0, 0.6) if won else Color(1.0, 0.4, 0.4)
	DrawUtil.text_centered(self, font, Rect2(band.position, Vector2(band.size.x, 70)), title, 40, title_color)
	DrawUtil.text_centered(self, font, Rect2(band.position + Vector2(0, 62), Vector2(band.size.x, 40)),
			"%s  -  press R to restart" % s.end_reason, 18, Color.WHITE)
