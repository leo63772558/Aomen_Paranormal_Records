extends Control

signal removed
const SCREWS := [Vector2(179, 162), Vector2(409, 162)]
const HEADS := [Rect2(415, 391, 136, 136), Rect2(1034, 391, 136, 136)]
var background: Texture2D
var turns := [0.0, 0.0]
var loose := [false, false]
var feedback := "用钳松开门框卡扣上的两枚螺钉。"
var focus_suspended := false
var focus_previous_mode := Node.PROCESS_MODE_INHERIT

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not focus_suspended:
		focus_previous_mode = process_mode
		focus_suspended = true
		process_mode = Node.PROCESS_MODE_DISABLED
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and focus_suspended:
		process_mode = focus_previous_mode
		focus_suspended = false

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	background = load("res://assets/props/crypt_door_clip_026.png")

func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	for i in range(SCREWS.size()):
		if event.position.distance_to(SCREWS[i]) < 41 and not loose[i]:
			loose[i] = true
			AudioManager.play_world_effect("lock_mechanism")
			var turn := create_tween()
			turn.tween_method(_set_turn.bind(i), 0.0, 1.0, 0.27).set_trans(Tween.TRANS_SINE)
			feedback = "螺钉松动。再处理另一端。" if not (loose[0] and loose[1]) else "正在松开最后一枚螺钉。"
			if loose[0] and loose[1]:
				turn.tween_interval(0.23)
				turn.tween_callback(func(): removed.emit())
			accept_event()
			return

func _set_turn(value: float, screw: int) -> void:
	turns[screw] = value
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(background, Rect2(Vector2.ZERO, size), false)
	for i in range(SCREWS.size()):
		if turns[i] <= 0.0:
			continue
		draw_set_transform(SCREWS[i], 1.28 * turns[i], Vector2.ONE * (1.0 + 0.15 * turns[i]))
		draw_texture_rect_region(background, Rect2(-25, -23, 50, 47), HEADS[i], Color(0.87, 0.88, 0.81))
		draw_set_transform(Vector2.ZERO)
	var font := get_theme_default_font()
	draw_rect(Rect2(0, 300, 618, 30), Color(0.015, 0.027, 0.023, 0.93))
	draw_string(font, Vector2(15, 320), feedback, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("eee0bc"))
	draw_string(font, Vector2(535, 320), "Esc 返回", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("cfc3a6"))
