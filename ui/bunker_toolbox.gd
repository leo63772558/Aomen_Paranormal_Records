extends Control

signal key_selected(index: int)

const TOOLS := preload("res://assets/props/bunker_tools_025.png")
const OPEN_BOX := preload("res://assets/props/bunker_box_open_025.png")
const KEY_SHEET := preload("res://assets/props/bunker_keys_025.png")
var closed_box: AtlasTexture
var keys: Array[AtlasTexture] = []
var opened := false
var opening := false
var motion: Tween
var focus_suspended := false
var open_progress := 0.0:
	set(value):
		open_progress = value
		queue_redraw()
var feedback := "旧维修箱的锁扣只是被细铁丝缠住。点击锁扣，用工具钳拆开。"

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not focus_suspended:
		focus_suspended = true
		process_mode = Node.PROCESS_MODE_DISABLED
		if is_instance_valid(motion): motion.pause()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and focus_suspended:
		focus_suspended = false
		process_mode = Node.PROCESS_MODE_ALWAYS
		if is_instance_valid(motion): motion.play()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	closed_box = AtlasTexture.new()
	closed_box.atlas = TOOLS
	closed_box.region = Rect2(0, 0, 1086, 724)
	for i in range(3):
		var texture := AtlasTexture.new()
		texture.atlas = KEY_SHEET
		texture.region = Rect2(i * 724, 180, 724, 320)
		keys.append(texture)

func key_rect(index: int) -> Rect2:
	return Rect2(222, 130 + index * 53, 174, 48)

func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if opening:
		accept_event()
		return
	if not opened:
		if Rect2(250, 150, 120, 80).has_point(event.position):
			opening = true
			feedback = "锁扣松开，正在打开工具箱。"
			AudioManager.play_world_effect("metal_cover")
			motion = create_tween()
			motion.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			motion.tween_property(self, "open_progress", 1.0, 0.62).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			motion.tween_callback(func():
				opening = false
				opened = true
				feedback = "比较匙肩与磨槽。点钥匙将它收进背包。"
				queue_redraw()
			)
		else:
			feedback = "箱盖被细铁丝固定，先检查中间的锁扣。"
	else:
		for i in range(3):
			if key_rect(i).has_point(event.position):
				key_selected.emit(i + 1)
				accept_event()
				return
		feedback = "点选钥匙。门锁和换锁工单能排除不合用的那两把。"
	queue_redraw()
	accept_event()

func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color("181b18"))
	# The tray, hinges and lid share the same photographed/painted material.
	# Rotate the textured lid about its fixed rear hinge instead of crossfading boxes.
	draw_texture_rect_region(OPEN_BOX, Rect2(0, 0, 618, 124), Rect2(0, 0, 185, 384))
	draw_texture_rect_region(OPEN_BOX, Rect2(0, 124, 618, 206), Rect2(0, 384, 1536, 640))
	if opened or opening:
		for i in range(3):
			var r := key_rect(i)
			draw_texture_rect(keys[i], r, false)
			for j in range(1 if i == 0 else 2):
				draw_line(r.position + Vector2(11, 12 + j * 5), r.position + Vector2(20, 17 + j * 5), Color("ead9b7"), 1.5)
			var item_id := "gate_key_%d" % (i + 1)
			draw_string(font, r.position + Vector2(165, 31), DemoItems.title(item_id) + (" · 已取" if GameState.has_demo_item(item_id) else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e5d5ac"))
	var quad := lid_quad()
	var uv := PackedVector2Array([Vector2(0.13, 0.36), Vector2(0.87, 0.36), Vector2(0.87, 0.015), Vector2(0.13, 0.015)])
	if absf(quad[2].y - quad[0].y) >= 0.5:
		draw_polygon(quad, PackedColorArray([Color.WHITE]), uv, OPEN_BOX)
	else:
		draw_line(quad[0], quad[1], Color("95866a"), 2.5)
	var rim := quad.duplicate()
	rim.append(quad[0])
	draw_polyline(rim, Color("665b48"), 2.0, true)
	if not opened and not opening:
		draw_line(Vector2(279, 172), Vector2(321, 199), Color("a19882"), 1.4)
		draw_line(Vector2(320, 173), Vector2(279, 200), Color("6e6b60"), 1.4)
	draw_rect(Rect2(12, 306, 594, 28), Color(0, 0, 0, 0.84))
	draw_string(font, Vector2(22, 325), feedback, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e6d9bd"))
	draw_rect(Rect2(510, 8, 96, 22), Color(0, 0, 0, 0.72))
	draw_string(font, Vector2(519, 24), "Esc 返回", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e6d9bd"))

func lid_quad() -> PackedVector2Array:
	var angle := deg_to_rad(128.0) * open_progress
	var edge_y := 125.0 + cos(angle) * 180.0
	var spread := sin(angle) * 6.0
	return PackedVector2Array([Vector2(80,125), Vector2(538,125), Vector2(538 + spread,edge_y), Vector2(80 - spread,edge_y)])
