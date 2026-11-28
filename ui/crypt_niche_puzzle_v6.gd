extends Control

signal aligned

const LOCK_PLATE_BG := preload("res://assets/props/crypt_niche_lock_v10.png")
const STONE_WHEEL_TEX := preload("res://assets/props/crypt_dial_stone_v10.png")
const IRON_BOLT_TEX := preload("res://assets/props/crypt_iron_bolt_v10.png")
const CLUE_PHOTO_TEX := preload("res://assets/props/crypt_photo_013.png")
const CLUE_DOODLE_TEX := preload("res://assets/props/crypt_doodle_013.png")
const CLUE_PLAN_TEX := preload("res://assets/props/crypt_plan_013.png")

# Three heavy carved stone tumbler discs on the 1961 St. Paul's Crypt bulkhead
const DIAL_CENTERS := [Vector2(170, 142), Vector2(310, 142), Vector2(450, 142)]
const DIAL_RADIUS := 42.0
const PIN_SIZE := Vector2(44, 44)
const UNLOCK_BTN := Rect2(160, 236, 298, 38)

const DIAL_TITLES := ["Ⅰ · 石壁旧伤", "Ⅱ · 中龛封印", "Ⅲ · 逃生去向"]
const DIAL_SYMBOLS := [
	["单裂纹", "三斜痕", "十字刻", "圆洞"],
	["空壁龛", "铁栏封", "石像封龛", "木板封"],
	["左暗阶", "井口", "封死原路", "右维护门"]
]
const WHEEL_CLUES := [
	"仔细看《巡查旧照》里墙上的凿痕。",
	"仔细看《孩童涂鸦》里中央壁龛前画了什么。",
	"在《测绘描图》上找仍能通行的维护门。"
]
# Exact evidence deduced from the 3 clues in ch1_crypt_entry:
# 1) Old photo + stone wall: 三斜痕 (index 1)
# 2) Child's doodle: 石像封龛 (index 2)
# 3) Survey plan: 右维护门 (index 3)
const TARGET_INDICES := [1, 2, 3]

var dial_values := [0, 0, 0]
var dial_angles := [0.0, 0.0, 0.0]
var drawn_angles := [0.0, 0.0, 0.0]
# Neutral brass latch pins — NO auto-green spoilers when rotating wheels!
var pin_engaged := [false, false, false]
var pin_drop := [0.0, 0.0, 0.0]
var pin_bounce := [0.0, 0.0, 0.0]
var bolt_slide := 0.0
var dragging_bolt := false
var drag_start_x := 0.0
var drag_moved := false
var last_drag_tick := 0
var bolt_tween: Tween
var particles: Array[Dictionary] = []
var solved_verified := false
var fitted := false
var done := false
var unlocking := false
var hover_dial := -1
var hover_pin := -1
var hover_bolt := false
var hover_clue := -1
var zoomed_clue := -1
var pulse_clock := 0.0
var shake_timer := 0.0
var status := "根据大厅三处现场证据拨动三枚石印，再向右拉动（或点击）底部重铁闩校验开锁。"

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and dragging_bolt:
		dragging_bolt = false
		if not done and not unlocking:
			bolt_slide = 0.0
			queue_redraw()

func _pin_rect(idx: int) -> Rect2:
	var c: Vector2 = DIAL_CENTERS[idx]
	return Rect2(c.x - PIN_SIZE.x * 0.5, c.y + DIAL_RADIUS + 4.0, PIN_SIZE.x, PIN_SIZE.y)

func _spawn_sparks(origin: Vector2, count: int, warm := true) -> void:
	for _k in range(count):
		var ang := randf_range(-PI, 0.0)
		var spd := randf_range(26.0, 88.0)
		particles.append({
			"pos": origin + Vector2(randf_range(-6.0, 6.0), randf_range(-3.0, 3.0)),
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"life": randf_range(0.28, 0.55),
			"max_life": 0.55,
			"size": randf_range(1.6, 3.0),
			"color": Color("e8c474") if warm else Color("9e9784"),
			"gravity": 135.0 if warm else 185.0
		})

func _spawn_stone_dust(count: int) -> void:
	for _k in range(count):
		particles.append({
			"pos": Vector2(randf_range(UNLOCK_BTN.position.x + 8.0, UNLOCK_BTN.end.x - 8.0), randf_range(UNLOCK_BTN.position.y - 6.0, UNLOCK_BTN.end.y)),
			"vel": Vector2(randf_range(-24.0, 38.0), randf_range(-18.0, 22.0)),
			"life": randf_range(0.45, 0.90),
			"max_life": 0.90,
			"size": randf_range(1.8, 3.6),
			"color": Color(0.62, 0.58, 0.50, 0.85),
			"gravity": 165.0
		})

func _process(delta: float) -> void:
	pulse_clock += delta
	shake_timer = maxf(0.0, shake_timer - delta)
	for i in range(3):
		drawn_angles[i] = lerp_angle(drawn_angles[i], dial_angles[i], clampf(delta * 11.0, 0.0, 1.0))
		var target_drop := 1.0 if pin_engaged[i] else 0.0
		pin_drop[i] = lerpf(pin_drop[i], target_drop, clampf(delta * 13.0, 0.0, 1.0))
		pin_bounce[i] = maxf(0.0, pin_bounce[i] - delta * 4.5)
	if not particles.is_empty():
		var next_particles: Array[Dictionary] = []
		for p in particles:
			var life: float = float(p.life) - delta
			if life <= 0.0:
				continue
			var vel: Vector2 = p.vel
			vel.y += float(p.gravity) * delta
			p.vel = vel
			p.pos = (p.pos as Vector2) + vel * delta
			p.life = life
			next_particles.append(p)
		particles = next_particles
	queue_redraw()

func _all_dials_correct() -> bool:
	return dial_values[0] == TARGET_INDICES[0] and dial_values[1] == TARGET_INDICES[1] and dial_values[2] == TARGET_INDICES[2]

func _gui_input(event: InputEvent) -> void:
	if done or unlocking:
		return
	if event is InputEventMouseMotion:
		if dragging_bolt:
			var dx: float = event.position.x - drag_start_x
			if absf(dx) > 10.0:
				drag_moved = true
			if _all_dials_correct():
				bolt_slide = clampf(dx / 164.0, 0.0, 1.0)
				var tick := int(floor(bolt_slide * 4.0))
				if tick > last_drag_tick:
					last_drag_tick = tick
					AudioManager.play_world_effect("tool_clink")
					_spawn_stone_dust(5)
				if bolt_slide >= 0.72:
					dragging_bolt = false
					_begin_live_bolt_open()
			else:
				# Heavy jammed resistance when any stone seal is wrong!
				bolt_slide = clampf(dx / 900.0, 0.0, 0.06)
			accept_event()
			queue_redraw()
			return
		hover_dial = -1
		hover_pin = -1
		hover_clue = -1
		for i in range(3):
			var c: Vector2 = DIAL_CENTERS[i]
			if Rect2(c.x - 65.0, 26.0, 130.0, 56.0).has_point(event.position):
				hover_clue = i
				break
			if event.position.distance_to(c) <= DIAL_RADIUS + 4.0:
				hover_dial = i
				break
			if _pin_rect(i).has_point(event.position):
				hover_pin = i
				break
		hover_bolt = UNLOCK_BTN.has_point(event.position)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if dragging_bolt:
			dragging_bolt = false
			if not _all_dials_correct():
				_reject_bolt()
			elif not drag_moved or bolt_slide >= 0.58:
				_begin_live_bolt_open()
			else:
				AudioManager.play_world_effect("valve_resist_clank")
				status = "重铁闩未拉到位弹回原处，请向右拉到底（或直接点击铁闩）。"
				if is_instance_valid(bolt_tween):
					bolt_tween.kill()
				bolt_tween = create_tween()
				bolt_tween.tween_property(self, "bolt_slide", 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			accept_event()
			queue_redraw()
			return
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if zoomed_clue >= 0:
		zoomed_clue = -1
		AudioManager.play_dialogue_advance()
		accept_event()
		queue_redraw()
		return
	if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	for i in range(3):
		var c: Vector2 = DIAL_CENTERS[i]
		if event.button_index == MOUSE_BUTTON_LEFT and Rect2(c.x - 65.0, 26.0, 130.0, 56.0).has_point(event.position):
			zoomed_clue = i
			AudioManager.play_dialogue_advance()
			accept_event()
			queue_redraw()
			return
	var step := -1 if event.button_index == MOUSE_BUTTON_RIGHT else 1
	for i in range(3):
		if event.position.distance_to(DIAL_CENTERS[i]) <= DIAL_RADIUS + 6.0:
			_rotate_dial(i, step)
			accept_event()
			return
		if _pin_rect(i).has_point(event.position):
			_toggle_brass_pin(i)
			accept_event()
			return
	if UNLOCK_BTN.has_point(event.position):
		dragging_bolt = true
		drag_start_x = event.position.x
		drag_moved = false
		last_drag_tick = 0
		AudioManager.play_world_effect("lock_mechanism")
		status = "正用力拉动锈蚀重铁闩……"
		accept_event()

func _rotate_dial(idx: int, step: int) -> void:
	# Pure realistic mechanical stone turn — ZERO auto-green spoilers or auto-dropping pins!
	dial_values[idx] = posmod(dial_values[idx] + step, 4)
	dial_angles[idx] += float(step) * (PI * 0.5)
	pin_engaged[idx] = false
	AudioManager.play_world_effect("lock_mechanism")
	_spawn_sparks(DIAL_CENTERS[idx] + Vector2(0, DIAL_RADIUS), 4, false)
	status = "沉重的石印磨出低响，已转至「%s」。三印就位后拉动底部重铁闩检验。" % DIAL_SYMBOLS[idx][dial_values[idx]]
	queue_redraw()

func _toggle_brass_pin(idx: int) -> void:
	# Neutral tactile pin check — never spoils correctness before pulling the iron bolt!
	pin_engaged[idx] = not pin_engaged[idx]
	AudioManager.play_world_effect("tool_clink")
	status = "已%s第 %d 枚定位铜栓。全部校对完毕后拉动底部重铁闩试开。" % ["压下" if pin_engaged[idx] else "拨起", idx + 1]
	queue_redraw()

func _reject_bolt() -> void:
	shake_timer = 0.36
	bolt_slide = 0.0
	AudioManager.play_world_effect("valve_resist_clank")
	_spawn_stone_dust(10)
	var wrong_indices: Array[int] = []
	for i in range(3):
		if dial_values[i] != TARGET_INDICES[i]:
			wrong_indices.append(i)
			pin_engaged[i] = false
			pin_bounce[i] = 1.0
	# Give helpful non-spoiler deduction guidance pointing to the first mismatched room clue
	var hint_clue: String = WHEEL_CLUES[wrong_indices[0]] if not wrong_indices.is_empty() else ""
	status = "重铁闩卡死纹丝不动（仍有 %d 处石印未扣准）！%s" % [wrong_indices.size(), hint_clue]
	queue_redraw()

func _begin_live_bolt_open() -> void:
	if done or unlocking:
		return
	if not _all_dials_correct():
		_reject_bolt()
		return
	unlocking = true
	solved_verified = true
	for i in range(3):
		pin_engaged[i] = true
		_spawn_sparks(DIAL_CENTERS[i] + Vector2(0, DIAL_RADIUS + 34.0), 8, true)
	AudioManager.play_world_effect("entrance_door")
	_spawn_stone_dust(28)
	status = "三枚铜栓齐声落槽！重铁闩轰然滑开，石像后的 1961 隐蔽维护门已解锁！"
	if is_instance_valid(bolt_tween):
		bolt_tween.kill()
	var remain := maxf(0.16, (1.0 - bolt_slide) * 0.45)
	bolt_tween = create_tween()
	bolt_tween.tween_property(self, "bolt_slide", 1.0, remain).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bolt_tween.tween_callback(func():
		_spawn_stone_dust(18)
		_spawn_sparks(Vector2(UNLOCK_BTN.end.x - 24.0, UNLOCK_BTN.get_center().y), 14, true)
		fitted = true
		done = true
		unlocking = false
		aligned.emit.call_deferred()
	)

func _try_unlock() -> void:
	if _all_dials_correct():
		solved_verified = true
		for i in range(3):
			pin_engaged[i] = true
			pin_drop[i] = 1.0
		bolt_slide = 1.0
		fitted = true
		done = true
		unlocking = false
		AudioManager.play_world_effect("entrance_door")
		_spawn_stone_dust(24)
		status = "三枚石印严丝扣合，重铁闩轰然弹开！隐蔽维护门已解锁！"
		aligned.emit.call_deferred()
	else:
		_reject_bolt()

func _draw() -> void:
	var font := get_theme_default_font()
	var sx := sin(shake_timer * 64.0) * 4.5 if shake_timer > 0.0 else 0.0

	# Authentic damp carved stone & recessed granite altar housing
	draw_texture_rect(LOCK_PLATE_BG, Rect2(Vector2(sx * 0.35, 0.0), size), false)
	draw_rect(Rect2(0, 0, size.x, 24), Color(0.02, 0.028, 0.024, 0.92))
	draw_string(font, Vector2(16, 17), "大三巴地宫 · 摆开三份证据对照三印石盘（轻点旋转石盘，调准后向右拉动底部铁闩）" if GameState.touch_mode_active else "大三巴地宫 · 摆开三份证据对照三印石盘（左/右键旋转石盘，调准后拉动底部铁闩）", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ebd8a2"))
	draw_string(font, Vector2(534, 17), "右上返回" if GameState.touch_mode_active else "Esc 返回", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("bfb89e"))

	# Three laid-out physical evidence cards directly above the 3 stone wheels — NO answer spoilers!
	# Players click any card to zoom the raw photo/doodle/blueprint and deduce the matching wheel symbol themselves.
	var clue_textures: Array[Texture2D] = [CLUE_PHOTO_TEX, CLUE_DOODLE_TEX, CLUE_PLAN_TEX]
	var clue_headers := ["证据① 巡查旧照", "证据② 孩童涂鸦", "证据③ 测绘描图"]
	var clue_prompts := ["点击放大查壁痕", "点击放大查中龛", "点击放大查去向"]
	for i in range(3):
		var c: Vector2 = DIAL_CENTERS[i] + Vector2(sx, 0)
		var card_rect := Rect2(c.x - 65.0, 26.0, 130.0, 56.0)
		draw_rect(card_rect, Color(0.05, 0.075, 0.065, 0.95))
		draw_rect(card_rect, Color("f0d890", 0.98) if hover_clue == i else Color("9e8858", 0.85), false, 1.5 if hover_clue == i else 1.1)
		var thumb_rect := Rect2(card_rect.position.x + 4.0, card_rect.position.y + 4.0, 44.0, 48.0)
		draw_texture_rect(clue_textures[i], thumb_rect, false)
		draw_rect(thumb_rect, Color("7c6b48"), false, 1.0)
		draw_string(font, Vector2(card_rect.position.x + 51.0, card_rect.position.y + 17.0), clue_headers[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("f0da9c"))
		draw_string(font, Vector2(card_rect.position.x + 51.0, card_rect.position.y + 33.0), clue_prompts[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("d2dac8"))
		draw_string(font, Vector2(card_rect.position.x + 51.0, card_rect.position.y + 47.0), "↓ 自行推演" + DIAL_TITLES[i].substr(0, 1) + "轮", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("9eb4a2"))
		# Brass leader line from evidence card straight down to the top pointer of its stone wheel
		draw_line(Vector2(c.x, card_rect.end.y), Vector2(c.x, c.y - DIAL_RADIUS - 6.0), Color("c4ab6c", 0.65), 1.1)

	# Three realistic mossy carved granite wheels + tarnished brass locking pins
	for i in range(3):
		var c: Vector2 = DIAL_CENTERS[i] + Vector2(sx, 0)
		var is_hover: bool = (hover_dial == i)

		# Draw real carved granite stone wheel texture rotating smoothly in place
		var w_sz := DIAL_RADIUS * 2.04
		draw_set_transform(c, drawn_angles[i], Vector2.ONE)
		draw_texture_rect(STONE_WHEEL_TEX, Rect2(-w_sz * 0.5, -w_sz * 0.5, w_sz, w_sz), false, Color(1.08, 1.04, 0.98, 1.0) if is_hover else Color(0.95, 0.93, 0.88, 1.0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if is_hover:
			draw_arc(c, DIAL_RADIUS + 2.0, 0.0, TAU, 32, Color("d8bf7a", 0.78), 1.6, true)

		# Oxidized bronze top index pointer tooth
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -DIAL_RADIUS + 4), c + Vector2(-5.5, -DIAL_RADIUS - 5), c + Vector2(5.5, -DIAL_RADIUS - 5)]), Color("bfa058"))

		# Center recessed stone seal plaque showing the selected engraved relief text (neutral stone tone, zero neon green!)
		var sym: String = DIAL_SYMBOLS[i][dial_values[i]]
		draw_circle(c, 22.5, Color(0.08, 0.09, 0.08, 0.76))
		draw_arc(c, 22.5, 0.0, TAU, 24, Color("8a7b58", 0.85) if not solved_verified else Color("d8bd72"), 1.3, true)
		draw_string(font, c + Vector2(-24, 4), sym, HORIZONTAL_ALIGNMENT_CENTER, 48, 11, Color("eee3c4") if not solved_verified else Color("f8e49c"))

		# Forged aged-brass vertical bolt pin seated in the carved stone slot below each wheel
		var pr := _pin_rect(i)
		var bounce_y: float = sin(pin_bounce[i] * PI * 2.0) * 3.5 if pin_bounce[i] > 0.0 else 0.0
		var slide_y: float = float(pin_drop[i]) * 11.0 + bounce_y
		var bolt_body := Rect2(c.x - 6.0, pr.position.y + 4.0 + slide_y, 12.0, 21.0)
		var brass_fill := Color("a68848") if (pin_engaged[i] or solved_verified) else (Color("8c7442") if hover_pin == i else Color("685838"))
		var brass_hi := Color("d6bb76") if (pin_engaged[i] or solved_verified) else Color("9e8858")
		draw_rect(bolt_body, brass_fill)
		draw_rect(Rect2(bolt_body.position + Vector2(2, 2), Vector2(3, bolt_body.size.y - 4)), brass_hi)
		draw_rect(bolt_body, Color("2e2414"), false, 1.2)
		var cap := Rect2(c.x - 9.5, bolt_body.position.y - 1.0, 19.0, 6.0)
		draw_rect(cap, brass_hi)
		draw_rect(cap, Color("2c2212"), false, 1.0)
		draw_circle(Vector2(c.x, bolt_body.position.y + 12.0), 2.0, Color("261e12"))

	# Heavy rusted forged-iron horizontal release bolt sprite inside the recessed stone channel
	var track := Rect2(UNLOCK_BTN.position + Vector2(sx, 0), UNLOCK_BTN.size)
	var handle_w := 124.0
	var max_travel := track.size.x - handle_w - 8.0
	var handle_x := track.position.x + 4.0 + bolt_slide * max_travel
	var handle_rect := Rect2(handle_x, track.position.y + 3.0, handle_w, track.size.y - 6.0)
	draw_texture_rect(IRON_BOLT_TEX, handle_rect, false, Color(1.12, 1.06, 0.96, 1.0) if hover_bolt else Color(0.96, 0.94, 0.90, 1.0))
	if hover_bolt:
		draw_rect(handle_rect, Color("dec47c", 0.75), false, 1.4)
	var bar_label := "已解锁释放" if solved_verified else "向右拉动重铁闩 →"
	draw_string(font, handle_rect.position + Vector2(0, 21), bar_label, HORIZONTAL_ALIGNMENT_CENTER, int(handle_rect.size.x), 11, Color("f4e6bc"))

	# Falling stone dust & tarnished spark particles
	for p in particles:
		var a := clampf(float(p.life) / maxf(0.01, float(p.max_life)), 0.0, 1.0)
		var col: Color = p.color
		col.a *= a
		draw_circle(p.pos as Vector2, float(p.size), col)

	# Bottom weathered status bar
	draw_rect(Rect2(16, 283, 586, 38), Color(0.035, 0.055, 0.048, 0.92))
	draw_rect(Rect2(16, 283, 586, 38), Color("5b5845"), false, 1.0)
	draw_string(font, Vector2(24, 307), status, HORIZONTAL_ALIGNMENT_LEFT, 570, 11, Color("eee4c8"))

	# Enlarged raw evidence viewer overlay when player clicks any of the 3 top cards
	if zoomed_clue >= 0 and zoomed_clue < 3:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.025, 0.022, 0.86))
		var box := Rect2(94, 28, 430, 274)
		draw_rect(box, Color(0.055, 0.08, 0.07, 0.98))
		draw_rect(box, Color("ccb476"), false, 1.6)
		draw_string(font, Vector2(110, 50), clue_headers[zoomed_clue] + "（点击任意处收起）", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f0da9c"))
		draw_texture_rect(clue_textures[zoomed_clue], Rect2(124, 60, 370, 204), false)
		draw_rect(Rect2(124, 60, 370, 204), Color("7c6b48"), false, 1.0)
		draw_string(font, Vector2(110, 288), WHEEL_CLUES[zoomed_clue], HORIZONTAL_ALIGNMENT_LEFT, 398, 11, Color("e4e2d0"))
