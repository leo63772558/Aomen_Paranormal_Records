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
	selected = ""
	AudioManager.play_world_effect("metal_cover")
	_emit_sparks(SLOT_POS[slot], 8, Color("f6d687"))
	status = "备件扣进了接点。可以继续检查或试运行。"

func _inspect(branch: int) -> void:
	status = [
		"斜槽支路：梯灯断在一对空接点，两端缺一件连接件。",
		"双铆支路：三楼门扣的陶瓷芯烧蚀，试表不动。",
		"圆环支路：水泵舱进过水。值班记录要求保持隔离。"
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
	_move_needles(readings, 0.32)
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
		status = "水泵仍接通，保护闸跳开。检查值班工单。"
		_emit_sparks(SLOT_POS[2], 14, Color("9ce8ff"))
		shake_time = 0.24
	elif not (levers[0] and levers[1]):
		status = "梯灯和门扣要一起恢复。检查仍关闭的支路。"
		shake_time = 0.14
	elif parts["insulated_bridge"] != 0:
		status = "梯灯表针不起。看斜槽支路的空接点。"
		shake_time = 0.14
	elif parts["ceramic_fuse"] != 1:
		status = "门扣试表仍断路。双铆支路的烧蚀芯没有换对。"
		shake_time = 0.14
	else:
		powered = true
		_emit_sparks(SLOT_POS[0], 10, Color("c8f0a4"))
		_emit_sparks(SLOT_POS[1], 10, Color("c8f0a4"))
		status = "两路通过试运行。楼梯灯亮起，门扣接通。"
		completed.emit.call_deferred()
	if not powered:
		_move_needles.call_deferred(Vector3.ZERO, 0.26)
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
	draw_rect(Rect2(0, 0, 618, 30), Color(0.02, 0.03, 0.025, 0.95))
	draw_string(font, Vector2(12, 20), "唐楼 · 一楼检修箱", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("efe1b4"))
	draw_string(font, Vector2(442, 20), "右键取件   ·   Esc 返回", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d1c8a7"))
	var hover_slot := _near(SLOT_POS, pointer, 37) if not powered else -1
	var hover_lever := _near(LEVER_POS, pointer, 32) if not powered else -1
	var hover_meter := _near(METER_POS, pointer, 30) if not powered else -1
	for i in range(3):
		draw_rect(Rect2(STAMP_POS[i] - Vector2(68, 9), Vector2(136, 20)), Color("202920"))
		draw_string(font, STAMP_POS[i] + Vector2(-53, 6), ROUTES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("eadcb0"))
		var meter: Vector2 = METER_POS[i]
		if hover_meter == i and not dragging:
			draw_arc(meter, 28.0, 0.0, TAU, 24, Color("f0d78c"), 1.6)
		var needle_pivot := meter + Vector2(0, 12)
		var needle_angle := lerpf(-0.62, 0.67, needle_levels[i])
		draw_line(needle_pivot, needle_pivot + Vector2.UP.rotated(needle_angle) * 24.0, Color("dacba9"), 2.0)
		var point: Vector2 = SLOT_POS[i]
		var slot_hl := (hover_slot == i and (dragging or not selected.is_empty()))
		draw_rect(Rect2(point - Vector2(26, 20), Vector2(52, 40)), Color("f4df9b") if slot_hl else Color("ab9b70"), false, 2.0 if slot_hl else 1.0)
		var lever: Vector2 = LEVER_POS[i]
		if levers[i]:
			var crop_scale := background.get_size() / size
			var crop_size := Vector2(38, 43)
			draw_set_transform(offset + lever, PI)
			draw_texture_rect_region(background, Rect2(-crop_size * 0.5, crop_size),
				Rect2((lever - crop_size * 0.5) * crop_scale, crop_size * crop_scale))
			draw_set_transform(offset, 0.0)
		if hover_lever == i and not dragging:
			draw_rect(Rect2(lever - Vector2(22, 23), Vector2(44, 46)), Color("f0d78c"), false, 1.5)
		draw_circle(lever + Vector2(26, 0), 3.5, Color("acc293") if levers[i] else Color("46342b"))
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
			draw_texture_rect(texture, Rect2(at - Vector2(32, 22), Vector2(64, 44)), false)
		else:
			draw_string(font, at + Vector2(-24, 4), DemoItems.title(item), HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	var note := "缺件时回值班台或街口检修柜。" if parts.values().has(-1) else "插好后检查开关。"
	if GameState.has_demo_item("power_record"):
		note = "工单：泵舱进水，隔离；梯灯与门扣都要通过。"
	draw_string(font, Vector2(350, 288), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("c0cbb3"))
	draw_string(font, Vector2(159, 320), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("eadfbe"))
	for s in sparks:
		var p := Vector2(s["pos"])
		var c := Color(s["color"])
		c.a = clampf(float(s["life"]) / float(s["max_life"]), 0.0, 1.0)
		draw_line(p, p - Vector2(s["vel"]).normalized() * 7.0, c, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0)
