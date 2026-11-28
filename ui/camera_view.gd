extends Control

signal shutter_requested
signal cancel_requested
var center := Vector2(320, 190)
var shutter_busy: bool = false
var is_valid_framing: bool = false
var hint_text: String = "站在嘉敏左侧退后些，把她和身后建筑都框入"
var touch_dragging: bool = false
const HALF_FRAME := Vector2(100, 75)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func frame_rect() -> Rect2:
	return Rect2(center - HALF_FRAME, HALF_FRAME * 2.0)

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
	var ready_msg := "取景就绪，点右下「拍照」" if GameState.touch_mode_active else "取景就绪，左键拍照"
	var status_msg := ready_msg if is_valid_framing else hint_text
	var exit_msg := "右上放下" if GameState.touch_mode_active else "Esc 放下手机"
	var status := Rect2(146, 322, 348, 27)
	draw_rect(status, Color(0.035, 0.07, 0.055, 0.94))
	draw_rect(status, Color("796f55"), false)
	draw_string(font, status.position + Vector2(12, 18), status_msg, HORIZONTAL_ALIGNMENT_LEFT, 252, 12, Color("efe4c8"))
	draw_string(font, status.position + Vector2(272, 18), exit_msg, HORIZONTAL_ALIGNMENT_LEFT, 70, 11, Color("c9bea1"))

func _input(event: InputEvent) -> void:
	if not visible or shutter_busy:
		return
	if event is InputEventScreenTouch:
		touch_dragging = event.pressed
		if event.pressed:
			center = event.position.clamp(Vector2(108, 115), Vector2(532, 244))
			queue_redraw()
		get_viewport().set_input_as_handled()
		return
	elif event is InputEventScreenDrag:
		center = event.position.clamp(Vector2(108, 115), Vector2(532, 244))
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		center = event.position.clamp(Vector2(108, 115), Vector2(532, 244))
		queue_redraw()
	elif event is InputEventMouseMotion and event.device == InputEvent.DEVICE_ID_EMULATION and touch_dragging:
		center = event.position.clamp(Vector2(108, 115), Vector2(532, 244))
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and (GameState.touch_mode_active or event.device == InputEvent.DEVICE_ID_EMULATION):
		touch_dragging = event.pressed
		if event.pressed:
			center = event.position.clamp(Vector2(108, 115), Vector2(532, 244))
			queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("photo_capture"):
		shutter_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") or event.is_action_pressed("camera_mode"):
		cancel_requested.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		get_viewport().set_input_as_handled()
