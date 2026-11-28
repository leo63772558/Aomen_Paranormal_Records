extends Control

signal aligned

const PHOTO_RECT := Rect2(12, 45, 388, 225)
const PLAN_TRAY := Rect2(411, 46, 193, 102)
const DOODLE_TRAY := Rect2(411, 163, 193, 108)
const TABLE_BG := preload("res://assets/tilesets/crypt_entrance_013.png")
const GUIDE_ORIGIN := Vector2(208, 164)
const STRIP := Vector2(329, 139)
const MARK := Vector2(-50, -37)
const JAMB := Vector2(128, -23)
const EVIDENCE := [Vector2(159, 124), Vector2(336, 142)]
const BAY_POINTS := [Vector2(159, 96), Vector2(208, 94), Vector2(254, 96)]
const ROT_LEFT_BTN := Rect2(14, 271, 88, 21)
const ROT_RIGHT_BTN := Rect2(108, 271, 88, 21)
const ANGLE_STEP := PI / 12.0
const LANDMARK_TOLERANCE := 16.0
var photo: Texture2D
var plan: Texture2D
var doodle: Texture2D
var sheet_center := Vector2(511, 102)
var sheet_angle := PI
var drawn_angle := PI
var turn_motion: Tween
var dragging := false
var fitted := false
var done := false
var pulse_clock := 0.0
var status := "① 将右侧透明测绘描图拖至左图，用右键/滚轮旋转，令三斜痕与侧门框重合。"
var focus_suspended := false
var focus_previous_mode := Node.PROCESS_MODE_INHERIT

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not focus_suspended:
		if dragging:
			dragging = false
			if not fitted:
				sheet_center = PLAN_TRAY.get_center()
			status = "拖动已中断，描图已收回托盘。重新按住描图再对齐两处记号。"
			queue_redraw()
		focus_previous_mode = process_mode
		focus_suspended = true
		process_mode = Node.PROCESS_MODE_DISABLED
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and focus_suspended:
		process_mode = focus_previous_mode
		focus_suspended = false

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	photo = DemoItems.texture("crypt_old_photo")
	plan = DemoItems.texture("crypt_survey")
	doodle = DemoItems.texture("crypt_doodle")

func _process(delta: float) -> void:
	if focus_suspended:
		return
	pulse_clock += delta
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if done:
		return
	if event is InputEventMouseMotion:
		if dragging:
			sheet_center = event.position
			queue_redraw()
		return
	if not event is InputEventMouseButton:
		return
	if event.pressed and not fitted and event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var steps := -1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else (3 if event.button_index == MOUSE_BUTTON_RIGHT else 1)
		_turn_to(sheet_angle + steps * ANGLE_STEP)
		accept_event()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		if not fitted and ROT_LEFT_BTN.has_point(event.position):
			_turn_to(sheet_angle - ANGLE_STEP)
			accept_event()
			return
		if not fitted and ROT_RIGHT_BTN.has_point(event.position):
			_turn_to(sheet_angle + ANGLE_STEP)
			accept_event()
			return
		if fitted:
			_choose_bay(event.position)
		elif PLAN_TRAY.has_point(event.position) or Rect2(sheet_center - STRIP * 0.5, STRIP).has_point(event.position):
			dragging = true
			sheet_center = event.position
	elif dragging:
		dragging = false
		sheet_center = event.position
		var slash_error := (sheet_center + MARK.rotated(sheet_angle)).distance_to(EVIDENCE[0])
		var jamb_error := (sheet_center + JAMB.rotated(sheet_angle)).distance_to(EVIDENCE[1])
		if slash_error <= LANDMARK_TOLERANCE and jamb_error <= LANDMARK_TOLERANCE:
			fitted = true
			_turn_to(roundf(sheet_angle / TAU) * TAU)
			var settle := create_tween()
			settle.tween_method(_move_fitted_plan, sheet_center, GUIDE_ORIGIN, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			status = "两处记号对齐了。照着孩子的涂鸦，点出照片中已经封上的那格。"
			AudioManager.play_dialogue_advance()
		elif minf(slash_error, jamb_error) <= LANDMARK_TOLERANCE:
			status = "只重合了一处。另一处能检验描图的方向。"
		else:
			status = "两处记号都还没对上。先找一处可用来定位的实物纹路。"
	queue_redraw()
	accept_event()

func _turn_to(angle: float) -> void:
	sheet_angle = angle
	if turn_motion != null and turn_motion.is_running():
		turn_motion.kill()
	turn_motion = create_tween()
	turn_motion.tween_method(_draw_angle, drawn_angle, angle, 0.17).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _draw_angle(angle: float) -> void:
	drawn_angle = angle
	queue_redraw()

func _move_fitted_plan(point: Vector2) -> void:
	sheet_center = point
	queue_redraw()

func _choose_bay(point: Vector2) -> void:
	if point.distance_to(BAY_POINTS[1]) < 25:
		done = true
		aligned.emit.call_deferred()
	elif point.distance_to(BAY_POINTS[0]) < 25 or point.distance_to(BAY_POINTS[2]) < 25:
		status = "这一格还能看到壁龛。对照涂鸦中石像的位置。"

func _draw() -> void:
	var font := get_theme_default_font()
	var pulse := 0.5 + 0.5 * sin(pulse_clock * 4.2)
	# Real stone-crypt close-up table backdrop instead of flat green box
	draw_texture_rect(TABLE_BG, Rect2(Vector2.ZERO, size), false, Color(0.24, 0.27, 0.24, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.04, 0.72))
	draw_string(font, Vector2(16, 25), "大三巴地宫 · 1961 掘骨石壁与旧测绘叠图核验", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f0dfb0"))
	draw_string(font, Vector2(522, 24), "右上返回" if GameState.touch_mode_active else "Esc 返回", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c0c9b6"))
	# Vintage parchment frames with soft depth shadow
	for frame in [PHOTO_RECT.grow(3), PLAN_TRAY.grow(3), DOODLE_TRAY.grow(3)]:
		draw_rect(Rect2(frame.position + Vector2(2, 3), frame.size), Color(0, 0, 0, 0.55))
		draw_rect(frame, Color("1a1814"))
		draw_rect(frame, Color("8a7a56"), false, 1.4)
	draw_texture_rect(photo, PHOTO_RECT, false)
	draw_texture_rect(plan, PLAN_TRAY, false)
	draw_texture_rect(doodle, DOODLE_TRAY, false)
	draw_string(font, Vector2(414, 159), "测绘描图 · 拖动 / 点左下按钮旋转" if GameState.touch_mode_active else "测绘描图 · 左键拖放 / 右键或滚轮旋转", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e5d6a9"))
	draw_string(font, Vector2(414, 284), "孩童涂鸦 · 记录石像封壁位置", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e5d6a9"))
	if not fitted:
		for pair in [[ROT_LEFT_BTN, "< 左转 15°"], [ROT_RIGHT_BTN, "右转 15° >"]]:
			var r: Rect2 = pair[0]
			var txt: String = pair[1]
			draw_rect(r, Color(0.08, 0.14, 0.11, 0.94))
			draw_rect(r, Color("c9ad6a"), false, 1.1)
			draw_string(font, r.position + Vector2(6, 15), txt, HORIZONTAL_ALIGNMENT_LEFT, int(r.size.x) - 10, 10, Color("f4e6bd"))
	for at in EVIDENCE:
		draw_arc(at, 8.0 + pulse * 2.5, 0.0, TAU, 24, Color(0.92, 0.80, 0.48, 0.45 + pulse * 0.45), 1.4, true)
		draw_circle(at, 2.2, Color("f4df9b"))
	if dragging or fitted or PHOTO_RECT.has_point(sheet_center):
		_draw_tracing()
	if fitted:
		for point in BAY_POINTS:
			draw_rect(Rect2(point - Vector2(22, 17), Vector2(44, 34)), Color(0.95, 0.80, 0.48, 0.55 + pulse * 0.4), false, 1.5)
	draw_rect(Rect2(12, 294, 594, 34), Color(0.05, 0.08, 0.07, 0.88))
	draw_rect(Rect2(12, 294, 594, 34), Color("626e5c"), false, 1.0)
	draw_string(font, Vector2(20, 316), status, HORIZONTAL_ALIGNMENT_LEFT, 580, 12, Color("efe7cf"))

func _draw_tracing() -> void:
	draw_set_transform(sheet_center, drawn_angle)
	draw_texture_rect(plan, Rect2(-STRIP * 0.5, STRIP), false, Color(0.88, 0.91, 0.72, 0.57 if not fitted else 0.34))
	draw_circle(MARK, 5, Color("e5d697"), false, 1.6)
	draw_circle(JAMB, 5, Color("e5d697"), false, 1.6)
	draw_set_transform(Vector2.ZERO)
