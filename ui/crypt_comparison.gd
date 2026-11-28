extends Control
signal aligned
const PHOTO := preload("res://assets/props/crypt_photo_013.png")
const PLAN := preload("res://assets/props/crypt_plan_013.png")
const TABLE_BG := preload("res://assets/tilesets/crypt_entrance_013.png")
const MARK_PHOTO := Vector2(124, 135)
const MARK_PLAN := Vector2(402, 146)
const MARK_NICHE := Vector2(458, 130)
var phase := 0
var feedback := "① 在左侧 1961 实拍老照片上，点击墙脚的「三道斜刻痕」。"
var finished := false
var pointer := Vector2.ZERO
var clock := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pointer = event.position
		return
	if finished or not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var point: Vector2 = event.position
	if phase == 0:
		if point.distance_to(MARK_PHOTO) < 34:
			phase = 1
			AudioManager.play_world_effect("archive_ticket_pickup")
			feedback = "② 刻痕已锁定！再点击右侧测绘描图上对应的同一组三道刻痕。"
		else:
			feedback = "看左侧老照片的石墙中下部——哪里有三道平行斜刻痕？"
	elif phase == 1:
		if point.distance_to(MARK_PLAN) < 36:
			phase = 2
			AudioManager.play_world_effect("archive_ticket_pickup")
			feedback = "③ 两图对齐！对比发现右侧图纸多了一座被封死的暗壁龛——点击它！"
		else:
			feedback = "沿着左图刻痕对应的石墙位置，在右图找到相同的三道记号。"
	else:
		if point.distance_to(MARK_NICHE) < 34:
			finished = true
			AudioManager.play_world_effect("lock_mechanism")
			feedback = "真相揭晓：1961 年掘出遗骨后，第四座壁龛被人用水泥石像封死了！"
			aligned.emit.call_deferred()
		else:
			feedback = "对比左右两图：右侧图纸在两座壁龛之间多画了什么？"
	queue_redraw()
	accept_event()

func _draw() -> void:
	var font := get_theme_default_font()
	# Real stone-crypt close-up surface instead of flat green backdrop!
	draw_texture_rect(TABLE_BG, Rect2(Vector2.ZERO, size), false, Color(0.28, 0.30, 0.27, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.04, 0.04, 0.62))
	draw_string(font, Vector2(18, 24), "大三巴地宫 · 1961 掘骨旧照与测绘叠图比对", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f0dca2"))
	draw_string(font, Vector2(526, 24), "Esc 返回", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c4ccb8"))

	# Vintage photo cards with dark drop shadow and antique parchment border
	for card in [Rect2(14, 72, 288, 172), Rect2(314, 72, 288, 172)]:
		draw_rect(Rect2(card.position + Vector2(3, 4), card.size), Color(0, 0, 0, 0.55))
		draw_rect(card, Color("1a1814"))
		draw_rect(card, Color("8a7a56"), false, 1.5)
	draw_texture_rect(PHOTO, Rect2(18, 80, 280, 158), false)
	draw_texture_rect(PLAN, Rect2(318, 80, 280, 158), false)
	draw_string(font, Vector2(22, 64), "1961 年掘骨实拍旧照", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("eadba9"))
	draw_string(font, Vector2(322, 64), "管理处暗道测绘描图", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("eadba9"))

	var pulse := 0.45 + 0.45 * sin(clock * 4.5)
	# Subtle visual magnifying reticle around current pointer inside photos
	if Rect2(18, 80, 280, 158).has_point(pointer) or Rect2(318, 80, 280, 158).has_point(pointer):
		draw_arc(pointer, 16.0, 0.0, TAU, 24, Color("f4df9b", 0.55), 1.3, true)
		draw_line(pointer + Vector2(-5, 0), pointer + Vector2(5, 0), Color("f4df9b", 0.45), 1.0)
		draw_line(pointer + Vector2(0, -5), pointer + Vector2(0, 5), Color("f4df9b", 0.45), 1.0)

	# Visual alignment marks & connecting dashed line as player progresses
	if phase >= 1:
		draw_arc(MARK_PHOTO, 18.0, 0.0, TAU, 24, Color("88e09c"), 2.0, true)
	else:
		draw_arc(MARK_PHOTO, 24.0 + pulse * 4.0, 0.0, TAU, 24, Color(0.95, 0.84, 0.52, 0.25 + pulse * 0.28), 1.4, true)
	if phase >= 2:
		draw_arc(MARK_PLAN, 18.0, 0.0, TAU, 24, Color("88e09c"), 2.0, true)
		draw_dashed_line(MARK_PHOTO, MARK_PLAN, Color("88e09c", 0.85), 1.8, 6.0)
		draw_arc(MARK_NICHE, 22.0 + pulse * 4.0, 0.0, TAU, 24, Color(0.96, 0.42, 0.36, 0.38 + pulse * 0.42), 1.8, true)
	elif phase == 1:
		draw_arc(MARK_PLAN, 24.0 + pulse * 4.0, 0.0, TAU, 24, Color(0.95, 0.84, 0.52, 0.25 + pulse * 0.28), 1.4, true)
	if finished:
		draw_arc(MARK_NICHE, 20.0, 0.0, TAU, 24, Color("f06858"), 2.4, true)

	draw_rect(Rect2(14, 258, 588, 58), Color(0.05, 0.08, 0.07, 0.90))
	draw_rect(Rect2(14, 258, 588, 58), Color("626e5c"), false, 1.0)
	draw_string(font, Vector2(24, 284), feedback, HORIZONTAL_ALIGNMENT_LEFT, 568, 13, Color("f2ebd4"))
	draw_string(font, Vector2(24, 306), "步骤 %d / 3   ·   左键点击对应特征点完成叠图核验" % [mini(phase + 1, 3)], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("9eb5a2"))
