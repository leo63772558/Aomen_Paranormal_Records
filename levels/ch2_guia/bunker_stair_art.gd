extends Node2D

const START_Y := 2490.0
const TREAD := 23.0
const LEVELS := 100
const SOURCES := [Rect2(0, 183, 941, 67), Rect2(0, 316, 941, 68), Rect2(0, 450, 941, 65), Rect2(0, 584, 941, 67)]
var art: Texture2D
var floor_slab: Texture2D
var deadend_art: Texture2D
var letters: Font
var marked := false

static func y_at(step: int) -> float:
	return START_Y - TREAD * step

func _ready() -> void:
	art = load("res://assets/tilesets/bunker_deep_steps_2d_021.png")
	floor_slab = load("res://assets/tilesets/ammo_floor_026.png")
	deadend_art = load("res://assets/tilesets/bunker_99_deadend_v7.png")
	letters = UiFont.song()

func _draw() -> void:
	# Clean dark bunker stonework landing ONLY at bottom entry (from bunker hall),
	# and our custom painted sealed damp concrete bulkhead wall at the top (99th step dead-end)!
	draw_rect(Rect2(0, y_at(LEVELS) - 320, 640, START_Y + 540), Color("060807"))
	if floor_slab != null:
		draw_texture_rect_region(floor_slab, Rect2(148, START_Y + TREAD, 344, 156), Rect2(120, 260, 460, 200), Color(0.66, 0.70, 0.66, 1.0))
	draw_rect(Rect2(162, START_Y + TREAD, 316, 6), Color("1e221d"))
	draw_string(letters, Vector2(284, START_Y + TREAD + 38), "机房铁门方向", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.76, 0.74, 0.62, 0.58))

	# Top of 99th step: painted damp sealed concrete bulkhead with flickering crimson cage lamp (NO doorway, NO beds!)
	var top_y := y_at(LEVELS) - 240.0
	if deadend_art != null:
		draw_texture_rect_region(deadend_art, Rect2(48, top_y, 544, 246), Rect2(0, 0, deadend_art.get_width(), deadend_art.get_height() * 0.80))
	elif floor_slab != null:
		draw_texture_rect_region(floor_slab, Rect2(148, top_y + 60, 344, 180), Rect2(80, 140, 420, 210), Color(0.30, 0.28, 0.26, 1.0))

	for i in range(LEVELS + 1):
		var appearance := 2 if i in [89, 99] else i % 4
		draw_texture_rect_region(art, Rect2(0, y_at(i), 640, TREAD), SOURCES[appearance])
		if i > 0 and i < LEVELS and (i % 10 == 0 or i in [87, 88, 90, 95, 98]):
			var sy := y_at(i) + 14.0
			draw_string(letters, Vector2(138, sy), str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.76, 0.72, 0.58, 0.55))
	for step in [89, 99]:
		var y := y_at(step)
		draw_colored_polygon(PackedVector2Array([Vector2(201, y + 8), Vector2(248, y + 9), Vector2(229, y + 18), Vector2(199, y + 16)]), Color("181a16"))
		draw_line(Vector2(202, y + 8), Vector2(245, y + 9), Color("bbb292"), 1.3)
		draw_string(letters, Vector2(128, y + 14), "89", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("efe7c6"))
		for i in range(3):
			draw_line(Vector2(175 + i * 7, y + 12), Vector2(179 + i * 7, y - 1), Color("e3d6a8"), 2.0)
		_draw_track(Vector2(313, y + 12), Color("a88d67"))
		if marked:
			draw_line(Vector2(186, y - 7), Vector2(194, y - 15), Color("eee4ca"), 2.4)
			draw_line(Vector2(186, y - 15), Vector2(194, y - 7), Color("eee4ca"), 2.4)
	for step in [88, 86, 82, 74, 62, 50, 38, 26, 14, 3]:
		_draw_track(Vector2(318, y_at(step) + 10), Color(0.59, 0.51, 0.35, 0.52))

func _draw_track(at: Vector2, tint: Color) -> void:
	for i in range(2):
		var foot := at + Vector2(12 * i, -8 * i)
		draw_colored_polygon(PackedVector2Array([
			foot + Vector2(-3, -5), foot + Vector2(2, -5), foot + Vector2(3, 4),
			foot + Vector2(0, 9), foot + Vector2(-4, 3)
		]), tint)
