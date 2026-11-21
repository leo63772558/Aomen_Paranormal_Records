extends Control

signal shutter_requested
signal cancel_requested
var center := Vector2(320, 190)
var shutter_busy: bool = false
var is_valid_framing: bool = false
var hint_text: String = "站在嘉敏左侧退后些，把她和身后建筑都框入"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func frame_rect() -> Rect2:
	return Rect2(center - Vector2(100, 75), Vector2(200, 150))

func _draw() -> void:
	var frame := frame_rect()
	var ink: Color = Color("7cf08a") if is_valid_framing else Color("e57353")
	
	# Viewfinder corner brackets
	for corner in [frame.position, Vector2(frame.end.x, frame.position.y), frame.end, Vector2(frame.position.x, frame.end.y)]:
		var sx: float = 1 if corner.x == frame.position.x else -1
		var sy: float = 1 if corner.y == frame.position.y else -1
		draw_line(corner, corner + Vector2(18 * sx, 0), ink, 2.0)
		draw_line(corner, corner + Vector2(0, 18 * sy), ink, 2.0)
	
	# Center crosshair
	draw_line(center - Vector2(6, 0), center + Vector2(6, 0), ink, 1.5)
	draw_line(center - Vector2(0, 6), center + Vector2(0, 6), ink, 1.5)
	
	# Frame border thin guideline
	draw_rect(frame, Color(ink.r, ink.g, ink.b, 0.22), false, 1.0)
	
	# Status hint bar
	var font := get_theme_default_font()
	var status_msg: String = "✔ 取景完美！点击鼠标左键拍摄  [ C 退出 ]" if is_valid_framing else ("✖ " + hint_text + "  [ C 退出 ]")
	var msg_pos := Vector2(frame.position.x - 20, frame.end.y + 22)
	draw_rect(Rect2(msg_pos + Vector2(-6, -14), Vector2(260, 20)), Color(0.05, 0.08, 0.07, 0.82))
	draw_string(font, msg_pos, status_msg, HORIZONTAL_ALIGNMENT_LEFT, 260, 11, ink)

func _input(event: InputEvent) -> void:
	if not visible or shutter_busy:
		return
	if event is InputEventMouseMotion:
		center = event.position.clamp(Vector2(90, 115), Vector2(550, 260))
		queue_redraw()
	elif event.is_action_pressed("photo_capture"):
		shutter_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") or event.is_action_pressed("camera_mode"):
		cancel_requested.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		get_viewport().set_input_as_handled()
