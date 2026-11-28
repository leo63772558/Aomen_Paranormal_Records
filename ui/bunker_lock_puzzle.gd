extends Control

signal state_changed
signal unlocked

const KEYHOLE := Vector2(310, 174)
const HOOK := Vector2(488, 92)
const CHAIN_ZONE := Rect2(180, 80, 293, 55)
const OIL_TRAY := Vector2(75, 280)
const KEY_TRAYS := [Vector2(209, 280), Vector2(362, 280), Vector2(512, 280)]
const PART_RECTS := [Rect2(173, 189, 425, 374), Rect2(900, 165, 370, 407), Rect2(1468, 274, 689, 218)]
var background: Texture2D
var body: Texture2D
var shackle: Texture2D
var chain: Texture2D
var oil: Texture2D
var keys: Array[Texture2D] = []
var dragging := ""
var pointer := Vector2.ZERO
var press_point := Vector2.ZERO
var chain_lift := 0.0
var chain_offset := 0.0
var padlock_removed := false
var padlock_drop := 0.0
var oil_progress := 0.0
var turn_progress := 0.0
var active_key := -1
var busy := false
var lock_shake := 0.0
var status := "锁面刻有两道磨槽。锁梁被沉重铁链死死绷住——按住铁链向右上方拖到托钩卸力。"
var focus_suspended := false
var focus_previous_mode := Node.PROCESS_MODE_INHERIT

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not focus_suspended:
		if not dragging.is_empty():
			if dragging == "key": active_key = -1
			dragging = ""
			status = "拖动已中断，请重新拿起物件操作。"
			queue_redraw()
		focus_previous_mode = process_mode
		focus_suspended = true
		process_mode = Node.PROCESS_MODE_DISABLED
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and focus_suspended:
		process_mode = focus_previous_mode
		focus_suspended = false

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	clip_contents = true
	background = load("res://assets/tilesets/bunker_lock_bg_026.png")
	var source: Texture2D = load("res://assets/props/bunker_lock_parts_026.png")
	body = _part(source, 0)
	shackle = _part(source, 1)
	chain = _part(source, 2)
	oil = DemoItems.texture("oil")
	for index in range(1, 4):
		keys.append(DemoItems.texture("gate_key_%d" % index))
	chain_lift = 1.0 if GameState.opening_flags.bunker_chain_relieved else 0.0
	turn_progress = 1.0 if GameState.opening_flags.bunker_lock_open else 0.0

func _part(source: Texture2D, index: int) -> Texture2D:
	var art := AtlasTexture.new()
	art.atlas = source
	art.region = PART_RECTS[index]
	art.filter_clip = true
	return art

func _is_auto_test() -> bool:
	return GameState.profile == "test" or DisplayServer.get_name() == "headless"

func _gui_input(event: InputEvent) -> void:
	if busy:
		return
	if event is InputEventMouseMotion:
		pointer = event.position
		queue_redraw()
		if not dragging.is_empty():
			accept_event()
		return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	pointer = event.position
	if event.pressed:
		press_point = pointer
		if pointer.distance_to(OIL_TRAY) < 43.0 and GameState.opening_flags.bunker_oil_found:
			dragging = "oil"
		elif GameState.opening_flags.bunker_lock_open and not padlock_removed and Rect2(258, 132, 108, 86).has_point(pointer):
			dragging = "padlock"
		elif CHAIN_ZONE.grow(28.0 if chain_lift > 0.5 else 10.0).has_point(pointer) or pointer.distance_to(HOOK) < 32.0:
			dragging = "chain"
		else:
			for i in range(3):
				if pointer.distance_to(KEY_TRAYS[i]) < 63.0 and GameState.has_demo_item("gate_key_%d" % (i + 1)):
					dragging = "key"
					active_key = i
			if pointer.distance_to(KEYHOLE) < 52.0 and dragging.is_empty():
				status = "锁面双磨槽。先按住铁链拖到右侧托钩卸力，再给锁眼倒机油。"
	else:
		var clicked := pointer.distance_to(press_point) < 10.0
		var allow_click_shortcut := _is_auto_test()
		if dragging == "padlock":
			# Hardcore physical step 4: Pull/lift the opened padlock OFF the chain FIRST!
			if allow_click_shortcut or pointer.distance_to(press_point) >= 26.0 or pointer.y > 205.0 or pointer.y < 110.0:
				_take_off_padlock()
			else:
				status = "按住弹开的旧挂锁往下拉出锁环，先卸下挂锁才能抽走铁链！"
		elif dragging == "chain":
			if GameState.opening_flags.bunker_lock_open:
				if not padlock_removed and not allow_click_shortcut:
					lock_shake = 0.20
					AudioManager.play_world_effect("valve_resist_clank")
					status = "旧挂锁还扣在链环上拉不走！先按住下方弹开的挂锁往下拽下来。"
				elif allow_click_shortcut or pointer.x > 460.0 or (pointer.x - press_point.x) > 58.0:
					_remove_chain()
				else:
					status = "挂锁已卸下！按住铁链用力向右侧拖出门扣。"
			elif allow_click_shortcut and clicked:
				_support_chain()
			elif pointer.distance_to(HOOK) < 62.0 or (pointer.x > 420.0 and pointer.y < 145.0):
				_support_chain()
			else:
				status = "必须按住铁链向上拖到右侧铁板托钩处搭稳（不能只轻点一下）。"
		elif dragging == "oil":
			if (allow_click_shortcut and clicked) or pointer.distance_to(KEYHOLE) < 68.0:
				_oil_lock()
			else:
				status = "按住油壶拖到锈锁锁眼处倾倒润滑油。"
		elif dragging == "key":
			if (allow_click_shortcut and clicked) or pointer.distance_to(KEYHOLE) < 58.0:
				_try_key()
			else:
				active_key = -1
		dragging = ""
	queue_redraw()
	accept_event()

func _support_chain() -> void:
	if GameState.opening_flags.bunker_chain_relieved:
		status = "铁链已稳稳搭上托钩，锁梁不再受力。"
		return
	busy = true
	AudioManager.play_world_effect("gate_chain")
	var motion := create_tween()
	motion.tween_property(self, "chain_lift", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	motion.tween_callback(func():
		GameState.opening_flags.bunker_chain_relieved = true
		state_changed.emit()
		status = "铁链挂稳在右侧托钩上，锁梁卸力了！接下来拖动油壶润滑锈锁。"
		busy = false
	)

func _oil_lock() -> void:
	if GameState.opening_flags.bunker_lock_oiled:
		status = "润滑油已渗入锁芯，可以直接拖入钥匙试锁。"
		return
	busy = true
	AudioManager.play_world_effect("oil_drops")
	var motion := create_tween()
	motion.tween_property(self, "oil_progress", 1.0, 0.78)
	motion.tween_callback(func():
		oil_progress = 0.0
		GameState.opening_flags.bunker_lock_oiled = true
		state_changed.emit()
		status = "机油顺着细嘴渗进锈死的锁芯。现在拖动对应的钥匙插入开锁。"
		busy = false
	)

func _try_key() -> void:
	if GameState.opening_flags.bunker_lock_open:
		status = "锁梁已弹开！先按住旧挂锁向下拽离链环，再抽走铁链。" if not padlock_removed else "挂锁已卸下，按住铁链向右拖出门扣。"
	elif not GameState.opening_flags.bunker_lock_oiled:
		status = "钥匙顶进锈层就卡死了！先把油壶拖到锁眼倒油。"
		lock_shake = 0.22
	elif not GameState.opening_flags.bunker_chain_relieved:
		status = "锁芯松动了一点，但铁链死死绷着锁梁——先将铁链拖到右侧托钩卸力。"
		lock_shake = 0.22
	elif active_key != 1:
		status = "钥匙只插进一半——锁面有两道磨槽，这把匙身槽数不符。" if active_key == 0 else "匙身能进，但圆肩抵住了换锁工单记录的方肩锁口。"
		lock_shake = 0.25
		AudioManager.play_world_effect("lock_mechanism")
	else:
		busy = true
		AudioManager.play_world_effect("lock_mechanism")
		var turn := create_tween()
		turn.tween_property(self, "turn_progress", 1.0, 0.48).set_trans(Tween.TRANS_BACK)
		turn.tween_callback(func():
			GameState.opening_flags.bunker_lock_open = true
			state_changed.emit()
			status = "咔哒！锁梁高高弹起。先按住旧挂锁往下拽下来，再抽走铁链！"
			busy = false
		)
		return
	active_key = -1

func _take_off_padlock() -> void:
	if padlock_removed:
		return
	busy = true
	AudioManager.play_world_effect("iron_slam")
	var drop := create_tween()
	drop.tween_property(self, "padlock_drop", 1.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_callback(func():
		padlock_removed = true
		active_key = -1
		status = "旧挂锁已完整取下！现在按住松脱的铁链向右侧抽离门扣。"
		busy = false
	)

func _remove_chain() -> void:
	busy = true
	if not padlock_removed:
		padlock_removed = true
		padlock_drop = 1.0
	AudioManager.play_world_effect("gate_chain")
	var motion := create_tween()
	motion.tween_property(self, "chain_offset", 250.0, 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	motion.tween_callback(func(): unlocked.emit())

func _process(delta: float) -> void:
	if lock_shake > 0.0:
		lock_shake = maxf(0.0, lock_shake - delta)
		queue_redraw()
	elif busy:
		queue_redraw()

func _step_hint() -> String:
	if GameState.opening_flags.bunker_lock_open:
		if not padlock_removed:
			return "4 · 按住弹开的旧挂锁往下拖拽，先把挂锁从铁链上取下来"
		return "5 · 按住松脱的铁链向右侧拖离门扣"
	if not GameState.opening_flags.bunker_chain_relieved:
		return "1 · 按住铁链向上拖到右侧铁板托钩挂稳卸力"
	if not GameState.opening_flags.bunker_lock_oiled:
		return "2 · 按住油壶拖到锈锁锁眼处倾倒润滑" if GameState.opening_flags.bunker_oil_found else "2 · 返回门外，拾取维修角的旧油壶"
	for i in range(1, 4):
		if GameState.has_demo_item("gate_key_%d" % i):
			return "3 · 拖入对应钥匙试锁（换锁工单：方肩 · 锁面：双磨槽）"
	return "3 · 返回门外，打开旧工具箱取钥匙"

func _draw() -> void:
	var font := get_theme_default_font()
	draw_texture_rect(background, Rect2(Vector2.ZERO, size), false)
	var live_lift := chain_lift
	var live_pull_x := chain_offset
	if dragging == "chain":
		if not GameState.opening_flags.bunker_chain_relieved:
			live_lift = clampf((120.0 - pointer.y) / 48.0, 0.0, 1.0)
		elif padlock_removed:
			live_pull_x = clampf(pointer.x - press_point.x, 0.0, 175.0)
	var right := Vector2(311 + live_pull_x, 104.0 - 18.0 * live_lift)
	var left := Vector2(168 + live_pull_x, 102.0 - 4.0 * live_lift)
	var shake_x := sin(lock_shake * 110.0) * 3.5 if (lock_shake > 0.0 and not GameState.reduced_flash) else 0.0

	# Chain stays visible until dragged off; padlock separates & drops cleanly FIRST before chain moves!
	var lock_drag_y := clampf(pointer.y - press_point.y, -18.0, 90.0) if dragging == "padlock" else 0.0
	var lock_y_off := padlock_drop * 210.0 + lock_drag_y
	var lock_alpha := clampf(1.0 - padlock_drop * 1.15, 0.0, 1.0)

	# 1) Opened/closed shackle behind chain
	if not padlock_removed or padlock_drop < 0.98:
		draw_texture_rect(shackle, Rect2(273 + shake_x, 104.0 - turn_progress * 32.0 + lock_y_off, 74, 74), false, Color(1, 1, 1, lock_alpha))
	# 2) Heavy iron chain segments (stretch dynamically toward cursor when dragging onto hook!)
	if live_pull_x < 200.0:
		draw_texture_rect(chain, Rect2(left, Vector2(151, 34)), false)
		var right_end_x := clampf(pointer.x - right.x + 24.0, 151.0, 210.0) if (dragging == "chain" and not GameState.opening_flags.bunker_chain_relieved) else (151.0 + live_lift * 26.0)
		var chain_rot := clampf((pointer.y - 110.0) * 0.004, -0.22, 0.14) if (dragging == "chain" and not GameState.opening_flags.bunker_chain_relieved) else (-0.11 * live_lift)
		draw_set_transform(right, chain_rot, Vector2.ONE)
		draw_texture_rect(chain, Rect2(Vector2.ZERO, Vector2(right_end_x, 34)), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 3) Heavy padlock body in front of chain (detaches downward first!)
	if not padlock_removed or padlock_drop < 0.98:
		draw_texture_rect(body, Rect2(268 + shake_x, 137 + lock_y_off, 84, 73), false, Color(1, 1, 1, lock_alpha))
		for row in range(2):
			var mark := Vector2(331 + shake_x, 158 + row * 5 + lock_y_off)
			draw_line(mark, mark + Vector2(7, 4), Color("ddc38a", lock_alpha), 1.2)
		if GameState.opening_flags.bunker_lock_open and not padlock_removed and not busy:
			var bob := sin(float(Time.get_ticks_msec()) * 0.006) * 4.0
			draw_rect(Rect2(265, 134, 90, 79), Color("f2da8d", 0.55), false, 1.5)
			draw_line(Vector2(310, 215), Vector2(310, 234 + bob), Color("f5dc8c"), 2.2, true)
			draw_line(Vector2(310, 234 + bob), Vector2(303, 226 + bob), Color("f5dc8c"), 2.2, true)
			draw_line(Vector2(310, 234 + bob), Vector2(317, 226 + bob), Color("f5dc8c"), 2.2, true)

	# 4) CORRECT OIL CAN ORIENTATION! Spout in bunker_tools_025.png points TOP-LEFT, so place can RIGHT-TOP of keyhole & tilt CCW (-0.52 rad)!
	if busy and oil_progress > 0.0:
		var tilt := lerpf(0.0, -0.56, clampf(oil_progress * 2.4, 0.0, 1.0))
		var at := KEYHOLE + Vector2(62.0, -18.0)
		draw_set_transform(at, tilt, Vector2.ONE)
		draw_texture_rect(oil, Rect2(-44, -36, 92, 64), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if oil_progress > 0.22:
			var stream_t := clampf((oil_progress - 0.22) / 0.65, 0.0, 1.0)
			# Spout nozzle tip sits precisely above-right of the keyhole after -0.56 rad tilt!
			var spout := KEYHOLE + Vector2(14.0, -28.0)
			var hole := KEYHOLE + Vector2(0.0, 3.0)
			var tip := spout.lerp(hole, minf(stream_t * 1.8, 1.0))
			var mid := spout.lerp(tip, 0.5) + Vector2(-4.0, -2.5)
			draw_line(spout, mid, Color(0.28, 0.16, 0.04, 0.92), 3.6, true)
			draw_line(mid, tip, Color(0.32, 0.19, 0.05, 0.94), 3.0, true)
			draw_line(spout + Vector2(0.8, 0), mid + Vector2(0.8, 0), Color(0.80, 0.58, 0.20, 0.78), 1.2, true)
			draw_line(mid + Vector2(0.6, 0), tip + Vector2(0.6, 0), Color(0.80, 0.58, 0.20, 0.78), 1.0, true)
			if stream_t > 0.45:
				var soak := (stream_t - 0.45) / 0.55
				draw_circle(hole, 4.0 + soak * 9.5, Color(0.16, 0.10, 0.03, 0.58 * soak))
				draw_arc(hole, 3.0 + soak * 7.5, 0.0, TAU, 18, Color(0.78, 0.58, 0.22, 0.42 * soak), 1.1, true)
				for d in range(4):
					var da := float(d) * 1.4 + oil_progress * 9.0
					var dr := fmod(oil_progress * 26.0 + d * 3.0, 10.0)
					draw_circle(hole + Vector2(cos(da) * dr, sin(da) * dr * 0.6 - 2.0), 1.3, Color(0.62, 0.42, 0.12, 0.75 * (1.0 - dr / 10.0)))
	elif GameState.opening_flags.bunker_lock_oiled and not padlock_removed:
		draw_circle(KEYHOLE + Vector2(-1 + shake_x, 2 + lock_y_off), 9.5, Color(0.14, 0.09, 0.03, 0.48 * lock_alpha))

	if active_key >= 0 and not padlock_removed and (turn_progress > 0.0 or dragging == "key"):
		var at := pointer if dragging == "key" else KEYHOLE + Vector2(0, lock_y_off)
		draw_set_transform(at, turn_progress * 0.83 if dragging != "key" else 0.0)
		draw_texture_rect(keys[active_key], Rect2(-10, -18, 99, 38), false)
		draw_set_transform(Vector2.ZERO)
	if dragging == "oil":
		draw_texture_rect(oil, Rect2(pointer - Vector2(38, 26), Vector2(76, 52)), false)

	draw_rect(Rect2(0, 0, 618, 29), Color(0, 0, 0, 0.72))
	draw_string(font, Vector2(14, 20), "松山防空洞 · 铁链与锈锁", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("e8d7a6"))
	draw_string(font, Vector2(532, 20), "Esc 返回", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d6ccb3"))
	draw_rect(Rect2(0, 29, 618, 29), Color(0.035, 0.065, 0.052, 0.93))
	draw_string(font, Vector2(14, 49), _step_hint(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f2dda4"))

	if not busy and chain_lift < 0.5:
		draw_arc(HOOK, 17, 0.0, TAU, 28, Color("f0d788", 0.82), 1.6, true)
		draw_dashed_line(Vector2(382, 114), HOOK, Color("e8cf86", 0.72), 1.5, 5.0)
	elif not busy and padlock_removed:
		var arrow_x := 408.0 + fmod(float(Time.get_ticks_msec()) * 0.04, 24.0)
		draw_line(Vector2(360, 118), Vector2(arrow_x + 48.0, 118), Color("f5dc8c"), 2.4, true)
		draw_line(Vector2(arrow_x + 48.0, 118), Vector2(arrow_x + 38.0, 110), Color("f5dc8c"), 2.4, true)
		draw_line(Vector2(arrow_x + 48.0, 118), Vector2(arrow_x + 38.0, 126), Color("f5dc8c"), 2.4, true)
		draw_string(font, Vector2(366, 102), "向右拖出铁链 →", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f5dc8c"))

	draw_rect(Rect2(0, 251, 618, 79), Color("111915"))
	draw_line(Vector2(0, 251), Vector2(618, 251), Color("4f5848"), 1.0)
	if GameState.opening_flags.bunker_oil_found:
		if not busy and pointer.distance_to(OIL_TRAY) < 43.0:
			draw_rect(Rect2(OIL_TRAY - Vector2(45, 29), Vector2(90, 58)), Color("f0d78c"), false, 1.5)
		draw_texture_rect(oil, Rect2(OIL_TRAY - Vector2(42, 26), Vector2(84, 52)), false)
		draw_string(font, Vector2(57, 304), "旧油壶", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e1d2a9"))
	for i in range(3):
		var item := "gate_key_%d" % (i + 1)
		if not GameState.has_demo_item(item):
			continue
		if not busy and pointer.distance_to(KEY_TRAYS[i]) < 63.0:
			draw_rect(Rect2(KEY_TRAYS[i] - Vector2(51, 25), Vector2(102, 50)), Color("f0d78c"), false, 1.5)
		draw_texture_rect(keys[i], Rect2(KEY_TRAYS[i] - Vector2(47, 22), Vector2(94, 39)), false)
		draw_string(font, KEY_TRAYS[i] + Vector2(-39, 21), DemoItems.title(item), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e1d2a9"))
	draw_string(font, Vector2(14, 322), status, HORIZONTAL_ALIGNMENT_LEFT, 594, 12, Color("f0e3bc"))

func draw_ellipse_fall(at: Vector2) -> void:
	draw_line(at, at + Vector2(0, 3.7), Color(0.84, 0.62, 0.26, 0.82), 1.7)
