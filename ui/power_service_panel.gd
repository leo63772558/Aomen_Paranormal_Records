extends Control

signal completed

const STAMP_POS := [Vector2(144, 41), Vector2(309, 41), Vector2(474, 41)]
const METER_POS := [Vector2(144, 85), Vector2(309, 85), Vector2(474, 85)]
const SLOT_POS := [Vector2(144, 165), Vector2(309, 165), Vector2(474, 165)]
const LEVER_POS := [Vector2(144, 234), Vector2(309, 234), Vector2(474, 234)]
const TRAY_POS := {"ceramic_fuse": Vector2(217, 283), "insulated_bridge": Vector2(303, 283)}
const ROUTES := ["斜槽 · 梯灯", "双铆 · 三楼门扣", "圆环 · 水泵"]
const TEST := Rect2(72, 276, 68, 48)
var parts := {"ceramic_fuse": -1, "insulated_bridge": -1}
var levers := [false, false, false]
var background: Texture2D
var part_art := {}
var selected := ""
var pointer := Vector2.ZERO
var dragging := false
var status := "查看三只测试表。把备件拖进支路，拨动开关，再试运行。"
var in_test := false
var powered := false
var needle_levels := Vector3.ZERO
var needle_motion: Tween
var sparks: Array[Dictionary] = []
var install_anim := {}
var shake_time := 0.0
var focus_suspended := false
var focus_previous_mode := Node.PROCESS_MODE_INHERIT

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not focus_suspended:
		if dragging:
			dragging = false
			selected = ""
			status = "拖动已中断，备件仍在原处。"
			queue_redraw()
		focus_previous_mode = process_mode
		focus_suspended = true
		process_mode = Node.PROCESS_MODE_DISABLED
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and focus_suspended:
		process_mode = focus_previous_mode
		focus_suspended = false

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	var path := "res://assets/props/power_panel_026.png"
	background = load(path if ResourceLoader.exists(path) else "res://assets/props/meter_cabinet_009.png")
	for item_id in parts:
		part_art[item_id] = DemoItems.texture(item_id)
	powered = GameState.opening_flags.floor3_power
	if powered:
		levers = [true, true, false]
		parts = {"ceramic_fuse": 1, "insulated_bridge": 0}
		needle_levels = Vector3(0.72, 0.85, 0.0)
		status = "梯灯和门扣已恢复。水泵支路保持隔离。"

func _gui_input(event: InputEvent) -> void:
	if in_test or powered:
		return
	if event is InputEventMouseMotion:
		pointer = event.position
		queue_redraw()
		return
	if not event is InputEventMouseButton:
		return
	pointer = event.position
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var slot := _near(SLOT_POS, pointer, 36)
		for item in parts:
			if slot >= 0 and parts[item] == slot:
				parts[item] = -1
				status = "备件已取下，回到手边。"
				AudioManager.play_world_effect("metal_cover")
		queue_redraw()
		accept_event()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		for item in TRAY_POS:
			if pointer.distance_to(TRAY_POS[item]) < 36 and parts[item] < 0 and GameState.has_demo_item(item):
				selected = item
				dragging = true
				accept_event()
				return
		var gauge := _near(METER_POS, pointer, 30)
		var lever := _near(LEVER_POS, pointer, 32)
		if TEST.has_point(pointer):
			_test()
		elif gauge >= 0:
			_inspect(gauge)
		elif lever >= 0:
			levers[lever] = not levers[lever]
			AudioManager.play_world_effect("power_switch")
			_emit_sparks(LEVER_POS[lever], 6, Color("ffe59c"))
		elif not selected.is_empty():
			_install(_near(SLOT_POS, pointer, 37))
		else:
			var occupied_slot := _near(SLOT_POS, pointer, 36)
			if occupied_slot >= 0:
				for item in parts:
					if parts[item] == occupied_slot:
						parts[item] = -1
						status = "备件已取下，回到手边。"
						AudioManager.play_world_effect("metal_cover")
						queue_redraw()
						accept_event()
						return
	else:
		if dragging:
			_install(_near(SLOT_POS, pointer, 37))
		dragging = false
	queue_redraw()
	accept_event()

func _near(positions: Array, point: Vector2, radius: float) -> int:
	for i in range(positions.size()):
		if point.distance_to(positions[i]) <= radius:
			return i
	return -1

func _install(slot: int) -> void:
	if slot < 0 or selected.is_empty():
		return
	if parts.values().has(slot):
		status = "这个槽位有备件。右键取下后再装。"
		return
	parts[selected] = slot
	var installed_id := selected
	selected = ""
	install_anim[installed_id] = 1.0
	AudioManager.play_world_effect("use_install_snap")
	_emit_sparks(SLOT_POS[slot], 11, Color("f6d687"))
	status = "咔哒！备件严丝合缝卡入接点。拨动开关后点试运行。"

func _inspect(branch: int) -> void:
	status = [
		"斜槽支路（梯灯）：旧斜槽端头铜片脱焊断路，需装入跨接两端的导通桥件。",
		"双铆支路（三楼门扣）：底座内的老式保险芯已发黑击穿，需换入耐压陶瓷芯。",
		"圆环支路（抽水泵）：台风夜井道渗水受潮——维修红笔批注『湿路严禁合闸』！"
	][branch]
	AudioManager.play_world_effect("power_switch")

func _test() -> void:
	in_test = true
	AudioManager.play_world_effect("power_switch")
	var readings := Vector3(
		0.72 if levers[0] and parts["insulated_bridge"] == 0 else 0.0,
		0.85 if levers[1] and parts["ceramic_fuse"] == 1 else 0.0,
		1.0 if levers[2] else 0.0
	)
	var fast_test := (GameState.profile == "test" or DisplayServer.get_name() == "headless")
	status = "正在通电试运行，观察三只电压表指针读数……"
	_move_needles(readings, 0.28 if fast_test else 0.42)
	if not fast_test:
		# Linger smoothly at energized peak so player clearly sees all 3 needles settle & arc before pass/trip!
		needle_motion.tween_callback(func():
			for bi in range(3):
				if readings[bi] > 0.5:
					_emit_sparks(METER_POS[bi] + Vector2(0, 8), 5, Color("ffd97d") if bi < 2 else Color("8ce8ff"))
		)
		needle_motion.tween_interval(0.85)
	needle_motion.tween_callback(_test_result)

func _move_needles(target: Vector3, duration: float) -> void:
	if needle_motion != null and needle_motion.is_running():
		needle_motion.kill()
	needle_motion = create_tween()
	needle_motion.tween_method(_draw_readings, needle_levels, target, duration).set_trans(Tween.TRANS_SINE)

func _draw_readings(readings: Vector3) -> void:
	needle_levels = readings
	queue_redraw()

func _test_result() -> void:
	in_test = false
	if levers[2]:
		status = "抽水泵渗水支路漏电跳总闸！井道湿路必须保持断开隔离。"
		_emit_sparks(SLOT_POS[2], 14, Color("9ce8ff"))
		shake_time = 0.24
	elif not (levers[0] and levers[1]):
		status = "梯灯和门扣需同时合闸恢复，检查仍处于断开位置的开关。"
		shake_time = 0.14
	elif parts["insulated_bridge"] != 0:
		status = "梯灯表针毫无反应——点上方斜槽电压表核对所需跨接件。"
		shake_time = 0.14
	elif parts["ceramic_fuse"] != 1:
		status = "门扣支路仍断路——双铆底座内烧毁的瓷芯尚未换对。"
		shake_time = 0.14
	else:
		powered = true
		_emit_sparks(SLOT_POS[0], 10, Color("c8f0a4"))
		_emit_sparks(SLOT_POS[1], 10, Color("c8f0a4"))
		status = "双路稳压通过！楼梯冷光灯亮起，三楼防盗门扣已恢复供电。"
		completed.emit.call_deferred()
	if not powered:
		var fast_test := (GameState.profile == "test" or DisplayServer.get_name() == "headless")
		_move_needles.call_deferred(Vector3.ZERO, 0.24 if fast_test else 0.45)
	queue_redraw()

func _emit_sparks(origin: Vector2, count: int, tint: Color) -> void:
	if GameState.reduced_flash:
		return
	for _i in range(count):
		var a := randf() * TAU
		var spd := randf_range(35.0, 125.0)
		sparks.append({"pos": origin, "vel": Vector2.from_angle(a) * spd, "life": randf_range(0.16, 0.34), "max_life": 0.34, "color": tint})

func _process(delta: float) -> void:
	var dirty := false
	if shake_time > 0.0:
		shake_time = maxf(0.0, shake_time - delta)
		dirty = true
	if not install_anim.is_empty():
		for k in install_anim.keys():
			install_anim[k] = maxf(0.0, float(install_anim[k]) - delta * 3.8)
			if install_anim[k] <= 0.0:
				install_anim.erase(k)
		dirty = true
	if not sparks.is_empty():
		var next_sparks: Array[Dictionary] = []
		for s in sparks:
			s["life"] = float(s["life"]) - delta
			if float(s["life"]) > 0.0:
				s["pos"] = Vector2(s["pos"]) + Vector2(s["vel"]) * delta
				s["vel"] = Vector2(s["vel"]) + Vector2(0, 180.0) * delta
				next_sparks.append(s)
		sparks = next_sparks
		dirty = true
	if dirty:
		queue_redraw()

func _draw() -> void:
	var font := get_theme_default_font()
	var offset := Vector2(sin(shake_time * 95.0) * 3.0, 0.0) if (shake_time > 0.0 and not GameState.reduced_flash) else Vector2.ZERO
	draw_set_transform(offset, 0.0)
	draw_texture_rect(background, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(0, 0, 618, 30), Color(0.025, 0.04, 0.032, 0.96))
	draw_line(Vector2(0, 30), Vector2(618, 30), Color("867247", 0.9), 1.4)
	for rx in [10.0, 608.0]:
		draw_circle(Vector2(rx, 15.0), 3.0, Color("3c3322"))
		draw_circle(Vector2(rx, 15.0), 1.6, Color("9a8454"))
	draw_string(font, Vector2(22, 20), "唐楼 · 一楼检修箱", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("efe1b4"))
	draw_string(font, Vector2(406, 20), "点已装槽位取件 · 右上/Esc 返回" if GameState.touch_mode_active else "点已装槽位或右键取件 · Esc 返回", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d1c8a7"))
	var hover_slot := _near(SLOT_POS, pointer, 37) if not powered else -1
	var hover_lever := _near(LEVER_POS, pointer, 32) if not powered else -1
	var hover_meter := _near(METER_POS, pointer, 30) if not powered else -1
	for i in range(3):
		draw_rect(Rect2(STAMP_POS[i] - Vector2(68, 9), Vector2(136, 20)), Color("1b231b"))
		draw_rect(Rect2(STAMP_POS[i] - Vector2(68, 9), Vector2(136, 20)), Color("6e6243", 0.65), false, 1.0)
		draw_string(font, STAMP_POS[i] + Vector2(-53, 6), ROUTES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("eadcb0"))
		var meter: Vector2 = METER_POS[i]
		draw_arc(meter, 26.5, 0.0, TAU, 28, Color("5a4d34", 0.65), 1.2, true)
		if hover_meter == i and not dragging:
			draw_arc(meter, 28.0, 0.0, TAU, 24, Color("f0d78c"), 1.6)
		# Calibrated vintage voltmeter arc ticks + tapered blued-steel needle with brass pivot boss
		var needle_pivot := meter + Vector2(0, 13)
		for tick_i in range(7):
			var tf := float(tick_i) / 6.0
			var ta := lerpf(-0.72, 0.72, tf)
			var td := Vector2.UP.rotated(ta)
			var t_col := Color("a83a2e", 0.85) if tick_i >= 5 else Color("302a1f", 0.78)
			draw_line(needle_pivot + td * 20.5, needle_pivot + td * (24.5 if tick_i % 2 == 0 else 23.0), t_col, 1.4 if tick_i % 2 == 0 else 1.0, true)
		var jitter := sin(Time.get_ticks_msec() * 0.045 + float(i) * 2.1) * 0.025 if (in_test and needle_levels[i] > 0.1) else 0.0
		var needle_angle := lerpf(-0.68, 0.68, needle_levels[i]) + jitter
		var n_dir := Vector2.UP.rotated(needle_angle)
		var n_side := Vector2(-n_dir.y, n_dir.x)
		# Soft cast shadow of needle onto dial paper
		draw_line(needle_pivot + Vector2(1.4, 1.8), needle_pivot + n_dir * 23.5 + Vector2(1.4, 1.8), Color(0, 0, 0, 0.34), 2.2, true)
		# Tapered metallic steel needle polygon + red tip
		var needle_poly := PackedVector2Array([
			needle_pivot - n_dir * 4.0 - n_side * 2.1,
			needle_pivot - n_dir * 4.0 + n_side * 2.1,
			needle_pivot + n_dir * 24.5 + n_side * 0.45,
			needle_pivot + n_dir * 24.5 - n_side * 0.45
		])
		draw_colored_polygon(needle_poly, Color("202527"))
		draw_line(needle_pivot + n_dir * 16.0, needle_pivot + n_dir * 24.5, Color("b83528"), 1.6, true)
		# Recessed brass center cap screw
		draw_circle(needle_pivot, 3.6, Color("5a492e"))
		draw_circle(needle_pivot, 2.2, Color("a68d5b"))
		draw_circle(needle_pivot + Vector2(-0.6, -0.6), 0.9, Color("e6d49e"))
		var point: Vector2 = SLOT_POS[i]
		var slot_hl := (hover_slot == i and (dragging or not selected.is_empty()))
		draw_rect(Rect2(point - Vector2(26, 20), Vector2(52, 40)), Color("f4df9b") if slot_hl else Color("ab9b70"), false, 2.0 if slot_hl else 1.0)
		var lever: Vector2 = LEVER_POS[i]
		# Flip ONLY the real painted rusted toggle handle cleanly in-place via local Y-scale (NEVER sampling wall pixels above!)
		if levers[i] and background != null:
			var bg_size := background.get_size()
			var sx := bg_size.x / maxf(size.x, 1.0)
			var sy := bg_size.y / maxf(size.y, 1.0)
			var inner_w := 18.0
			var inner_h := 28.0
			var src := Rect2((lever.x - inner_w * 0.5) * sx, (lever.y - inner_h * 0.5) * sy, inner_w * sx, inner_h * sy)
			draw_set_transform(lever + offset, 0.0, Vector2(1.0, -1.0))
			draw_texture_rect_region(background, Rect2(-inner_w * 0.5, -inner_h * 0.5, inner_w, inner_h), src)
			draw_set_transform(offset, 0.0, Vector2.ONE)
		if hover_lever == i and not dragging:
			draw_rect(Rect2(lever - Vector2(22, 24), Vector2(44, 48)), Color("e6ca86", 0.85), false, 1.4)
		# Realistic recessed vintage pilot lamp beside each switch plate (no flat neon green dot!)
		var lamp_pos := lever + Vector2(28, 0)
		draw_circle(lamp_pos, 4.6, Color("1a1611"))
		draw_arc(lamp_pos, 4.6, 0.0, TAU, 16, Color("6e5d40"), 1.1, true)
		if levers[i]:
			draw_circle(lamp_pos, 3.0, Color("c8a956", 0.88))
			draw_circle(lamp_pos + Vector2(-0.8, -0.8), 1.2, Color("fff0be", 0.92))
		else:
			draw_circle(lamp_pos, 2.8, Color("2e241b", 0.95))
	draw_rect(Rect2(151, 268, 467, 62), Color(0.05, 0.08, 0.066, 0.93))
	var test_hover := TEST.has_point(pointer) and not powered
	draw_arc(Vector2(107, 297), 18.0, 0.0, TAU, 28, Color("f5dc91") if (in_test or test_hover) else Color("ad946a"), 2.2 if test_hover else 1.5)
	draw_string(font, Vector2(88, 325), "试运行", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("eadfbe"))
	for item in parts:
		if not GameState.has_demo_item(item) and parts[item] < 0:
			continue
		var at: Vector2 = TRAY_POS[item] if parts[item] < 0 else SLOT_POS[parts[item]]
		if selected == item and dragging:
			at = pointer
		elif parts[item] < 0 and not powered and pointer.distance_to(TRAY_POS[item]) < 36.0:
			draw_rect(Rect2(at - Vector2(34, 24), Vector2(68, 48)), Color("f2d98c"), false, 1.5)
		var texture: Texture2D = part_art[item]
		if texture != null:
			var anim_t := float(install_anim.get(item, 0.0))
			var lift := Vector2(0.0, -10.0 * anim_t)
			var zoom := 1.0 + sin(anim_t * PI) * 0.18
			var draw_sz := Vector2(64, 44) * zoom
			draw_texture_rect(texture, Rect2(at + lift - draw_sz * 0.5, draw_sz), false)
			if anim_t > 0.05:
				draw_rect(Rect2(at - Vector2(28, 21), Vector2(56, 42)), Color(1.0, 0.88, 0.52, anim_t * 0.75), false, 2.0)
		else:
			draw_string(font, at + Vector2(-24, 4), DemoItems.title(item), HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	var has_bridge: bool = GameState.has_demo_item("insulated_bridge") or int(parts["insulated_bridge"]) >= 0
	var has_fuse: bool = GameState.has_demo_item("ceramic_fuse") or int(parts["ceramic_fuse"]) >= 0
	var note := ""
	if not has_bridge and not has_fuse:
		note = "缺2件：去【街口检修柜】找跨接片，【大厅信箱】找瓷芯。"
	elif not has_bridge:
		note = "缺件：去外面【街口墙脚检修柜】拿绝缘跨接片。"
	elif not has_fuse:
		note = "缺件：回【大厅值班台/信箱旁】拿陶瓷保险芯。"
	elif GameState.has_demo_item("power_record"):
		note = "工单提示：湿路严禁合闸；点击上方表盘可查三路故障。"
	else:
		note = "备件齐备：点击上方三只表盘读故障，对槽装件并合闸。"
	draw_string(font, Vector2(342, 288), note, HORIZONTAL_ALIGNMENT_LEFT, 270, 10, Color("f0dba0") if (not has_bridge or not has_fuse) else Color("c0cbb3"))
	draw_string(font, Vector2(159, 320), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("eadfbe"))
	for s in sparks:
		var p := Vector2(s["pos"])
		var c := Color(s["color"])
		c.a = clampf(float(s["life"]) / float(s["max_life"]), 0.0, 1.0)
		draw_line(p, p - Vector2(s["vel"]).normalized() * 7.0, c, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0)
