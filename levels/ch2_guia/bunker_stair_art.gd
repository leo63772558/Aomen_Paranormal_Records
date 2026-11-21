extends Node2D

const START_Y := 2490.0
const TREAD := 23.0
const LEVELS := 100
const SOURCES := [Rect2(0, 183, 941, 67), Rect2(0, 316, 941, 68), Rect2(0, 450, 941, 65), Rect2(0, 584, 941, 67)]
var art: Texture2D
var letters: SystemFont
var marked := false

static func y_at(step: int) -> float:
	return START_Y - TREAD * step

func _ready() -> void:
	art = load("res://assets/tilesets/bunker_deep_steps_2d_021.png")
	letters = SystemFont.new()
	letters.font_names = PackedStringArray(["SimSun", "Noto Serif CJK SC"])

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, START_Y + 96), Color("080b0a"))
	for i in range(LEVELS + 1):
		var appearance := 2 if i in [89, 99] else i % 4
		draw_texture_rect_region(art, Rect2(0, y_at(i), 640, TREAD), SOURCES[appearance])
	for step in [89, 99]:
		var y := y_at(step)
		draw_colored_polygon(PackedVector2Array([Vector2(201, y + 8), Vector2(248, y + 9), Vector2(229, y + 18), Vector2(199, y + 16)]), Color("181a16"))
		draw_line(Vector2(202, y + 8), Vector2(245, y + 9), Color("bbb292"), 1.3)
		draw_string(letters, Vector2(124, y + 14), "89", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("efe7c6"))
		for i in range(3):
			draw_line(Vector2(175 + i * 7, y + 12), Vector2(179 + i * 7, y - 1), Color("e3d6a8"), 2.0)
		_draw_track(Vector2(313, y + 12), Color("a88d67"))
		if marked:
			draw_line(Vector2(186, y - 7), Vector2(194, y - 15), Color("eee4ca"), 2.4)
			draw_line(Vector2(186, y - 15), Vector2(194, y - 7), Color("eee4ca"), 2.4)
		draw_string(letters, Vector2(453, y + 13), "白记止于此", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f0dabb"))
	for step in [88, 86, 82, 74, 62, 50, 38, 26, 14, 3]:
		_draw_track(Vector2(318, y_at(step) + 10), Color(0.59, 0.51, 0.35, 0.61))
	draw_string(letters, Vector2(278, START_Y + 22), "← 返机房", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e5cf9d"))

func _draw_track(at: Vector2, tint: Color) -> void:
	for i in range(2):
		var foot := at + Vector2(12 * i, -8 * i)
		draw_colored_polygon(PackedVector2Array([
			foot + Vector2(-3, -5), foot + Vector2(2, -5), foot + Vector2(3, 4),
			foot + Vector2(0, 9), foot + Vector2(-4, 3)
		]), tint)
