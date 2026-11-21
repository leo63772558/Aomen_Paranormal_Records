extends Control

signal unlocked

const CENTER := Vector2(309, 170)
const PLATE := Rect2(398, 194, 126, 96)
const TRAY := Rect2(24, 248, 134, 49)
const SLIDE := Rect2(461, 126, 119, 55)
var background: Texture2D
var handle: Texture2D
var attached := false
var relieved := false
var rotated := false
var held := ""
var pointer := Vector2.ZERO
var drag_start := Vector2.ZERO
var angle := -1.1
var slide := 0.0
var busy := false
var status := "这里少了可拆手柄。看过门外检修签，再寻找零件。"
var focus_suspended := false
var focus_previous_mode := Node.PROCESS_MODE_INHERIT

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not focus_suspended:
		if not held.is_empty():
			if held == "turn":
				angle = -1.1
			elif held == "bolt":
				slide = 0.0
			held = ""
			status = "拖动已中断，请重新操作。"
			queue_redraw()
		focus_previous_mode = process_mode
		focus_suspended = true
		process_mode = Node.PROCESS_MODE_DISABLED
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and focus_suspended:
		process_mode = focus_previous_mode
		focus_suspended = false

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	var path := "res://assets/props/service_latch_026.png"
	background = load(path if ResourceLoader.exists(path) else "res://assets/props/maintenance_lock_012.png")
	handle = DemoItems.texture("service_handle")
	if GameState.has_demo_item("service_handle"):
		status = "拖动组装好的手柄到方孔。门舌受力，先把门顶向门框。"

func _gui_input(event: InputEvent) -> void:
	if busy:
		return
	if event is InputEventMouseMotion:
		pointer = event.position
		if held == "turn":
			angle = -1.1 + clampf((pointer.x - drag_start.x) / 57.0, 0.0, 1.0) * 1.65
		if held == "bolt":
			slide = clampf(drag_start.x - pointer.x, 0.0, 56.0)
		queue_redraw()
		return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	pointer = event.position
	if event.pressed:
		drag_start = pointer
		if rotated:
			if SLIDE.has_point(pointer):
				held = "bolt"
			else:
				status = "偏心轮已顶开卡扣。按住右侧锁舌，向左拉。"
		elif not attached and TRAY.has_point(pointer) and GameState.has_demo_item("service_handle"):
			held = "handle"
		elif PLATE.has_point(pointer):
			relieved = true
			status = "门被顶进了门框，锁舌松了。顺着磨痕向右拖手柄。"
			AudioManager.play_world_effect("gate_iron")
		elif attached and pointer.distance_to(CENTER) < 59:
			if relieved:
				held = "turn"
			else:
				status = "锁舌压得太紧。先按门上的顶板。"
		else:
			status = "在 304 和通道工具架找握柄、方轴。按 B 组装。"
	else:
		if held == "handle" and pointer.distance_to(CENTER) <= 65:
			attached = true
			status = "手柄扣进方孔。用右下的顶板给锁舌卸力。"
			AudioManager.play_world_effect("lock_mechanism")
		elif held == "turn":
			if pointer.x - drag_start.x >= 51:
				rotated = true
				angle = 0.55
				status = "偏心轮已顶开卡扣。向左拉回右侧锁舌。"
				AudioManager.play_world_effect("lock_mechanism")
			else:
				angle = -1.1
				status = "旋得还不够。沿磨痕把手柄向右带过去。"
		elif held == "bolt":
			slide = clampf(drag_start.x - pointer.x, 0.0, 56.0)
			if slide >= 48:
				busy = true
				AudioManager.play_world_effect("gate_chain")
				var motion := create_tween()
				motion.tween_method(_finish_slide, slide, 108.0, 0.32)
				motion.tween_callback(func(): unlocked.emit())
			else:
				slide = 0.0
		held = ""
	queue_redraw()
	accept_event()

func _finish_slide(distance: float) -> void:
	slide = distance
	queue_redraw()

func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color("131d1a"))
	draw_texture_rect(background, Rect2(Vector2(-maxf(slide - 57.0, 0.0), 0), size), false)
	draw_rect(Rect2(0, 0, 618, 28), Color(0, 0, 0, 0.85))
	draw_string(font, Vector2(15, 20), "通道 · 配重插栓", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("e8d4a2"))
	draw_string(font, Vector2(535, 20), "Esc 返回", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d9d1b7"))
	draw_rect(PLATE, Color(0.72, 0.62, 0.43, 0.1 if relieved else 0.22), false, 1.0)
	draw_string(font, PLATE.position + Vector2(24, 81), "顶住门板", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("efe1b5"))
	if handle != null and GameState.has_demo_item("service_handle"):
		if attached:
			draw_set_transform(CENTER, angle)
			draw_texture_rect(handle, Rect2(-14, -23, 102, 46), false)
			draw_set_transform(Vector2.ZERO)
		else:
			var where := pointer if held == "handle" else TRAY.get_center()
			draw_texture_rect(handle, Rect2(where - Vector2(61, 29), Vector2(122, 58)), false)
	if rotated:
		draw_rect(Rect2(SLIDE.position - Vector2(slide, 0), SLIDE.size), Color(0.82, 0.73, 0.47, 0.52), false, 2.0)
	draw_rect(Rect2(0, 298, 618, 32), Color("111a16"))
	draw_string(font, Vector2(12, 320), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e8ddc2"))
