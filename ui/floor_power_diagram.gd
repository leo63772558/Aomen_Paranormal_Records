extends Control

signal completed

const LEFT := ["A", "B", "C"]
const RIGHT := ["1", "2", "3"]
const SOLUTION := {"A":"2", "B":"3", "C":"1"}
const COLORS := {"A": Color("65514a"), "B": Color("6c6350"), "C": Color("505f56")}
const CABINET := preload("res://assets/props/meter_cabinet_009.png")
var connected: Dictionary = {}
var dragging: String = ""
var pointer := Vector2.ZERO
var feedback := "根据维修记录推断线路；拖动接线，右键左侧线头可拔下。"
var focus_suspended := false
var focus_previous_mode := Node.PROCESS_MODE_INHERIT

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not focus_suspended:
		if not dragging.is_empty():
			dragging = ""
			feedback = "拖动已中断，请重新连接线头。"
			queue_redraw()
		focus_previous_mode = process_mode
		focus_suspended = true
		process_mode = Node.PROCESS_MODE_DISABLED
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and focus_suspended:
		process_mode = focus_previous_mode
		focus_suspended = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func port(side: bool, index: int) -> Vector2:
	return Vector2(125 if side else 493, 175 + 55 * index)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		for i in range(3):
			if event.position.distance_to(port(true, i)) < 34 and connected.has(LEFT[i]):
				connected.erase(LEFT[i])
				feedback = "已拔下线路，可以重新接线。"
				AudioManager.play_world_effect("power_switch")
				queue_redraw()
				accept_event()
				return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			for i in range(3):
				if event.position.distance_to(port(true, i)) < 34 and not connected.has(LEFT[i]):
					dragging = LEFT[i]
					pointer = event.position
					break
		elif not dragging.is_empty():
			var target := ""
			for i in range(3):
				if event.position.distance_to(port(false, i)) < 22:
					target = RIGHT[i]
			if not target.is_empty() and not connected.values().has(target):
				connected[dragging] = target
				feedback = "接头锁定。对照记录检查三条线路。"
				AudioManager.play_world_effect("power_switch")
			else:
				feedback = "接头未接好，或这个楼层接头已经占用。"
			dragging = ""
			queue_redraw()
			if connected.size() == 3:
				if connected == SOLUTION:
					completed.emit.call_deferred()
				else:
					feedback = "仪表未恢复。检查维修记录，右键线头拔下重接。"
					queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and not dragging.is_empty():
		pointer = event.position
		queue_redraw()
		accept_event()

func draw_cable(from: Vector2, to: Vector2, tint: Color) -> void:
	var points := PackedVector2Array()
	for i in range(25):
		var t := float(i) / 24.0
		var p := from.lerp(to, t)
		p.y += sin(t * PI) * minf(from.distance_to(to) * 0.05, 16.0)
		points.append(p)
	draw_polyline(points, Color("10100d"), 8, true)
	draw_polyline(points, tint.darkened(0.25), 5, true)
	var shine := PackedVector2Array()
	for p in points:
		shine.append(p + Vector2(0, -1.5))
	draw_polyline(shine, tint.lightened(0.12), 0.7, true)

func _draw() -> void:
	var font := get_theme_default_font()
	draw_texture_rect(CABINET, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(24, 6, 570, 23), Color(0, 0, 0, 0.74))
	draw_string(font, Vector2(34, 23), "三楼支路接线盒    拖动绝缘接头    Esc 返回", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("eee2bd"))
	draw_rect(Rect2(112, 38, 394, 82), Color(0.12, 0.105, 0.075, 0.91))
	draw_rect(Rect2(112, 38, 394, 82), Color("8f8264"), false, 1.0)
	draw_string(font, Vector2(125, 59), "维修记录 · A、B、C 分别对应三个楼层", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e8d9b7"))
	draw_string(font, Vector2(125, 82), "三楼字母紧接在二楼之后；一楼不是 A。", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e8d9b7"))
	draw_string(font, Vector2(125, 104), "每个楼层只接一条线。", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e8d9b7"))
	draw_rect(Rect2(85, 315, 448, 19), Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(95, 329), feedback, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("eee2bd"))
	for i in range(3):
		var left: String = LEFT[i]
		var right: String = RIGHT[i]
		var lp := port(true, i)
		var rp := port(false, i)
		if connected.has(left):
			draw_cable(lp, port(false, RIGHT.find(connected[left])), COLORS[left])
		elif dragging == left:
			draw_cable(lp, pointer, COLORS[left])
		else:
			draw_cable(lp, lp + Vector2(23, 0), COLORS[left])
		draw_string(font, lp + Vector2(-43, 5), left, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("eee2bd"))
		draw_string(font, rp + Vector2(31, 5), right + "楼", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("eee2bd"))
