extends Control
var show_flashlight: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var font := get_theme_default_font()
	var ink := Color("aeb8ad")
	draw_string(font, Vector2(0, 0), "体力", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ink)
	draw_line(Vector2(26, -4), Vector2(77, -4), Color("34413e"), 1.0)
	draw_line(Vector2(26, -4), Vector2(26 + GameState.stamina * 0.51, -4), Color("959d87"), 1.0)
	if not show_flashlight:
		return
	draw_string(font, Vector2(94, 0), "手电", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ink)
	for i in range(5):
		var color := Color("a29f83") if GameState.flashlight_battery > i * 20 else Color("303b39")
		draw_line(Vector2(121+i*6, -7), Vector2(121+i*6, -2), color, 2.0)
