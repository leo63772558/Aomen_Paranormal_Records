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
var oil_progress := 0.0
var turn_progress := 0.0
var active_key := -1
var busy := false
var lock_shake := 0.0
var status := "锁面有两道磨槽。锁梁被绷紧的链条压着。"
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
		elif CHAIN_ZONE.grow(28.0 if chain_lift > 0.5 else 6.0).has_point(pointer) or pointer.distance_to(HOOK) < 29.0:
			dragging = "chain"
		else:
			for i in range(3):
				if pointer.distance_to(KEY_TRAYS[i]) < 63.0 and GameState.has_demo_item("gate_key_%d" % (i + 1)):
					dragging = "key"
					active_key = i
			if pointer.distance_to(KEYHOLE) < 52.0 and dragging.is_empty():
				status = "双磨槽。换锁工单写了锁芯肩形，铁链先挂到右侧托钩。"
	else:
		var clicked := pointer.distance_to(press_point) < 7.0
		if dragging == "chain":
			if GameState.opening_flags.bunker_lock_open and (clicked or pointer.x > 496.0):
				_remove_chain()
			elif clicked or pointer.distance_to(HOOK) < 50.0:
				_support_chain()
			else:
				status = "右侧铁板有个托钩。拖动链条搭上去。"
		elif dragging == "oil" and (clicked or pointer.distance_to(KEYHOLE) < 56.0):
			_oil_lock()
		elif dragging == "key":
			if clicked or pointer.distance_to(KEYHOLE) < 52.0:
				_try_key()
			else:
				active_key = -1
		dragging = ""
	queue_redraw()
	accept_event()

func _support_chain() -> void:
	if GameState.opening_flags.bunker_chain_relieved:
		status = "铁链已经挂牢。锁梁松了一点。"
		return
	busy = true
	AudioManager.play_world_effect("gate_chain")
	var motion := create_tween()
	motion.tween_property(self, "chain_lift", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	motion.tween_callback(func():
		GameState.opening_flags.bunker_chain_relieved = true
		state_changed.emit()
		status = "铁链搭上托钩，锁梁卸力了。"
		busy = false
	)

func _oil_lock() -> void:
	if GameState.opening_flags.bunker_lock_oiled:
		status = "油已渗进锁芯。"
		return
	busy = true
	AudioManager.play_world_effect("oil_drops")
	var motion := create_tween()
	motion.tween_property(self, "oil_progress", 1.0, 0.73)
	motion.tween_callback(func():
		oil_progress = 0.0
		GameState.opening_flags.bunker_lock_oiled = true
		state_changed.emit()
		status = "油沿锁眼渗下去。可以试钥匙。"
		busy = false
	)

func _try_key() -> void:
	if GameState.opening_flags.bunker_lock_open:
		status = "锁梁已经弹开。把铁链拖出右边的门扣。"
	elif not GameState.opening_flags.bunker_lock_oiled:
		status = "钥匙顶进锈层就卡住了。先用油壶。"
		lock_shake = 0.22
	elif not GameState.opening_flags.bunker_chain_relieved:
		status = "锁芯能动一点，但链条绷住锁梁。先用右侧托钩卸力。"
		lock_shake = 0.22
	elif active_key != 1:
		status = "只顶进一半。匙身的槽数不合。" if active_key == 0 else "匙身能进，圆肩却抵住换过的锁口。"
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
			status = "锁梁弹起。把铁链往右侧拖离门扣。"
			busy = false
		)
		return
	active_key = -1

func _remove_chain() -> void:
	busy = true
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
		return "4 · 点击链条，将它移出门扣"
	if not GameState.opening_flags.bunker_chain_relieved:
		return "1 · 点击铁链，搭到右侧托钩"
	if not GameState.opening_flags.bunker_lock_oiled:
		return "2 · 点击油壶润滑锁眼" if GameState.opening_flags.bunker_oil_found else "2 · 返回门外，拾取维修角的油壶"
	for i in range(1, 4):
		if GameState.has_demo_item("gate_key_%d" % i):
			return "3 · 点击一把钥匙试锁：换锁工单写着方肩，锁面有双槽"
	return "3 · 返回门外，打开旧维修箱取钥匙"

func _draw() -> void:
	var font := get_theme_default_font()
	draw_texture_rect(background, Rect2(Vector2.ZERO, size), false)
	var right := Vector2(311 + chain_offset, 104.0 - 18.0 * chain_lift)
	var left := Vector2(168 + chain_offset, 102.0 - 4.0 * chain_lift)
	if dragging == "chain":
		right.y += clampf(pointer.y - right.y, -34.0, 25.0) * 0.45
	var shake_x := sin(lock_shake * 110.0) * 3.5 if (lock_shake > 0.0 and not GameState.reduced_flash) else 0.0
	if chain_offset < 190.0:
		draw_texture_rect(shackle, Rect2(273 + chain_offset + shake_x, 104.0 - turn_progress * 31.0, 74, 74), false)
		draw_texture_rect(chain, Rect2(left, Vector2(151, 34)), false)
		draw_texture_rect(chain, Rect2(right, Vector2(151 + chain_lift * 19.0, 34)), false)
		draw_texture_rect(body, Rect2(268 + chain_offset + shake_x, 137, 84, 73), false)
		for row in range(2):
			var mark := Vector2(331 + chain_offset + shake_x, 158 + row * 5)
			draw_line(mark, mark + Vector2(7, 4), Color("ddc38a"), 1.2)
	if busy and oil_progress > 0.0:
		var at := KEYHOLE + Vector2(-61, -26)
		draw_set_transform(at, lerpf(0, 1.18, minf(oil_progress * 2.5, 1.0)))
		draw_texture_rect(oil, Rect2(-41, -43, 89, 60), false)
		draw_set_transform(Vector2.ZERO)
		for i in range(3):
			var fall := fmod(oil_progress * 63.0 + 8.0 * i, 24.0)
			draw_ellipse_fall(KEYHOLE + Vector2(-1, fall))
	if active_key >= 0 and (turn_progress > 0.0 or dragging == "key"):
		var at := pointer if dragging == "key" else KEYHOLE
		draw_set_transform(at, turn_progress * 0.83 if dragging != "key" else 0.0)
		draw_texture_rect(keys[active_key], Rect2(-10, -18, 99, 38), false)
		draw_set_transform(Vector2.ZERO)
	if dragging == "oil":
		draw_texture_rect(oil, Rect2(pointer - Vector2(38, 26), Vector2(76, 52)), false)
	draw_rect(Rect2(0, 0, 618, 29), Color(0, 0, 0, 0.72))
	draw_string(font, Vector2(14, 20), "松山 · 铁链与锈锁", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("e8d7a6"))
	draw_string(font, Vector2(532, 20), "Esc 返回", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d6ccb3"))
	draw_rect(Rect2(0, 29, 618, 29), Color(0.035, 0.065, 0.052, 0.93))
	draw_string(font, Vector2(14, 49), _step_hint(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f2dda4"))
	if not busy and (chain_lift < 0.5 or GameState.opening_flags.bunker_lock_open):
		draw_arc(HOOK, 16, 0.0, TAU, 28, Color("ddc38a"), 1.2, true)
	draw_rect(Rect2(0, 251, 618, 79), Color("121b17"))
	if GameState.opening_flags.bunker_oil_found:
		if not busy and pointer.distance_to(OIL_TRAY) < 43.0:
			draw_rect(Rect2(OIL_TRAY - Vector2(45, 29), Vector2(90, 58)), Color("f0d78c"), false, 1.5)
		draw_texture_rect(oil, Rect2(OIL_TRAY - Vector2(42, 26), Vector2(84, 52)), false)
		draw_string(font, Vector2(57, 304), "油壶", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e1d2a9"))
	for i in range(3):
		var item := "gate_key_%d" % (i + 1)
		if not GameState.has_demo_item(item):
			continue
		if not busy and pointer.distance_to(KEY_TRAYS[i]) < 63.0:
			draw_rect(Rect2(KEY_TRAYS[i] - Vector2(51, 25), Vector2(102, 50)), Color("f0d78c"), false, 1.5)
		draw_texture_rect(keys[i], Rect2(KEY_TRAYS[i] - Vector2(47, 22), Vector2(94, 39)), false)
		draw_string(font, KEY_TRAYS[i] + Vector2(-39, 21), DemoItems.title(item), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e1d2a9"))
	draw_string(font, Vector2(14, 322), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f0e3bc"))

func draw_ellipse_fall(at: Vector2) -> void:
	draw_line(at, at + Vector2(0, 3.7), Color(0.84, 0.62, 0.26, 0.82), 1.7)
