extends Control
signal unlocked
const LOCK := preload("res://assets/props/maintenance_lock_012.png")
var digits := [0, 0, 0]
var message := "左键递增 · 右键递减 · 点把手尝试 · Esc 返回"
var busy := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if busy or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	for i in range(3):
		if event.position.distance_to(Vector2(151 + i * 158, 142)) < 65:
			digits[i] = posmod(digits[i] + (1 if event.button_index == MOUSE_BUTTON_LEFT else -1), 10)
			AudioManager.play_world_effect("power_switch")
			queue_redraw()
			accept_event()
			return
	if Rect2(225, 250, 165, 58).has_point(event.position):
		if digits == [4, 0, 3]:
			busy = true
			unlocked.emit.call_deferred()
		else:
			message = "锁舌未动。先找检修牌，再想想房门号码。"
			queue_redraw()
		accept_event()

func _draw() -> void:
	var font := get_theme_default_font()
	draw_texture_rect(LOCK, Rect2(Vector2.ZERO, size), false)
	for i in range(3):
		var center := Vector2(151 + i * 158, 142)
		draw_string(font, center + Vector2(-10, 12), str(digits[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color("e6d2a5"))
	draw_rect(Rect2(24, 312, 570, 22), Color(0, 0, 0, 0.82))
	draw_string(font, Vector2(36,328), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e6dbc0"))
