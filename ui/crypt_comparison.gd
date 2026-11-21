extends Control
signal aligned
const PHOTO := preload("res://assets/props/crypt_photo_013.png")
const PLAN := preload("res://assets/props/crypt_plan_013.png")
var phase := 0
var feedback := "先点击旧照片中的三道刻痕。"
var finished := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if finished or not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var point: Vector2 = event.position
	if phase == 0:
		if point.distance_to(Vector2(124,135)) < 28:
			phase = 1
			feedback = "再点击图纸上相同的三道记号。"
		else:
			feedback = "旧照片里哪处有三道平行刻痕？"
	elif phase == 1:
		if point.distance_to(Vector2(402,146)) < 30:
			phase = 2
			feedback = "记号已对齐。点击图纸中现实墙面没有的壁龛。"
		else:
			feedback = "对照照片，再找图纸上相同的记号。"
	else:
		if point.distance_to(Vector2(458,130)) < 28:
			finished = true
			aligned.emit.call_deferred()
		else:
			feedback = "看看照片：两座壁龛之间是石像还是壁龛？"
	queue_redraw()
	accept_event()

func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO,size), Color("182720"))
	draw_texture_rect(PHOTO, Rect2(18,80,280,158), false)
	draw_texture_rect(PLAN, Rect2(318,80,280,158), false)
	draw_string(font, Vector2(25,57), "旧照片", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("eadba9"))
	draw_string(font, Vector2(325,57), "管理复制图", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("eadba9"))
	draw_string(font, Vector2(25,280), feedback, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e1e6d6"))
	draw_string(font, Vector2(25,313), "鼠标选择  ·  Esc 返回", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("aebfae"))
