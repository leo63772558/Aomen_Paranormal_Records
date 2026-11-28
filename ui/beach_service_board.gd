extends Control

var beach: Node2D
var mode := "key_box"
var status: RichTextLabel
var lid_hinge: Node2D
var key_sprite: Sprite2D
var pointer: Sprite2D
var grabbed := false
var grab_origin := Vector2.ZERO
var lift := 0.0
var openness := 0.0
var knob_mode := 0
var motion: Tween
var spring_open := 0.0
var spring_lift := 0.0
var trace: Line2D
var trace_progress := 0
var latch_lifted := false
const BEACH_BG := preload("res://assets/tilesets/hacsa_beach_038.png")
const ROUTE := [Vector2(65, 140), Vector2(158, 140), Vector2(158, 160), Vector2(232, 160), Vector2(232, 125), Vector2(340, 125)]
const LIGHT_TABS := [Rect2(56, 260, 72, 26), Rect2(187, 276, 72, 26), Rect2(318, 260, 72, 26)]
const LOW_DRAIN_ENTRY := Rect2(62, 179, 50, 52)
var anim_clock := 0.0

static func shaft_mark() -> Node2D:
	var mark := Node2D.new()
	var rim := Line2D.new()
	for index in range(19):
		rim.add_point(Vector2.from_angle(TAU * index / 18.0) * 11.0)
	rim.default_color = Color("e5cb9b")
	rim.width = 1.5
	rim.antialiased = true
	mark.add_child(rim)
	for x in [-4.0, 4.0]:
		var upright := Line2D.new()
		upright.points = PackedVector2Array([Vector2(x, -6), Vector2(x, 6)])
		upright.width = 1.3
		upright.default_color = rim.default_color
		mark.add_child(upright)
	for y in [-4.0, 0.0, 4.0]:
		var rung := Line2D.new()
		rung.points = PackedVector2Array([Vector2(-4, y), Vector2(4, y)])
		rung.width = 1.3
		rung.default_color = rim.default_color
		mark.add_child(rung)
	return mark

func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT or not grabbed:
		return
	grabbed = false
	if is_instance_valid(motion):
		motion.kill()
		motion = null
	match mode:
		"key_box":
			if openness < 0.95 and is_instance_valid(lid_hinge):
				lift = 0.0
				openness = 0.0
				_set_lid_pose()
				status.text = "拖动已中断。回到箱盖后可重新提起并侧拉。"
		"car":
			if is_instance_valid(pointer):
				pointer.rotation = (knob_mode - 1) * PI / 3.0
				status.text = "旋钮操作已中断，仍保持原来的灯光档位。"
		"plan":
			if is_instance_valid(trace) and trace_progress < ROUTE.size():
				trace_progress = 0
				trace.clear_points()
				status.text = "描线已中断。回到左侧入口重新核对。"

func configure(scene: Node2D, service_mode: String) -> void:
	beach = scene
	mode = service_mode

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_label({"key_box":"高地保管箱 · 提盖与止扣", "car":"救援车灯 · 实物旋钮", "plan":"沿海工事示意图 · 核对通路"}[mode], Vector2(18, 8), 18)
	_label("Esc / B 返回", Vector2(480, 306), 12)
	status = RichTextLabel.new()
	status.position = Vector2(401, 56)
	status.size = Vector2(198, 227)
	status.add_theme_font_size_override("normal_font_size", 14)
	status.add_theme_constant_override("line_separation", 5)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status)
	match mode:
		"key_box": _build_key_box()
		"car": _build_switch()
		"plan": _build_plan()

func _process(delta: float) -> void:
	anim_clock += delta
	queue_redraw()

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(anim_clock * 4.2)
	# Atmospheric darkened Hac Sa Beach midnight backdrop instead of flat default panel
	draw_texture_rect(BEACH_BG, Rect2(Vector2.ZERO, size), false, Color(0.24, 0.28, 0.27, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.05, 0.74))
	# Recessed vintage info panel behind right-side status instructions
	draw_rect(Rect2(394, 48, 212, 244), Color(0.05, 0.09, 0.08, 0.88))
	draw_rect(Rect2(394, 48, 212, 244), Color("5b695d"), false, 1.0)
	if mode == "car":
		# Sleek riveted dark-brass car dashboard bezel & etched detent plates (no clunky overlapping corner boxes!)
		draw_rect(Rect2(44, 42, 344, 258), Color(0.05, 0.065, 0.06, 0.72))
		draw_rect(Rect2(44, 42, 344, 258), Color("665a42"), false, 1.4)
		for i in range(LIGHT_TABS.size()):
			var tab: Rect2 = LIGHT_TABS[i]
			var active := (knob_mode == i)
			draw_rect(tab, Color("1d2922") if active else Color("101513"))
			draw_rect(tab, Color("d8bf78") if active else Color("4c524a"), false, 1.4 if active else 1.0)
			# Small embedded amber/emerald automotive indicator LED beside active detent
			var led_p := Vector2(tab.position.x + 11.0, tab.get_center().y)
			draw_circle(led_p, 3.2, Color("141715"))
			var led_col := Color("62c87a") if (active and i == 2) else (Color("d8a94e") if active else Color("2b302d"))
			draw_circle(led_p, 2.2, led_col)
	elif mode == "key_box":
		if openness < 0.95:
			draw_rect(Rect2(138, 44, 232, 228), Color(0.95, 0.84, 0.50, 0.28 + 0.42 * pulse), false, 2.0)
		elif is_instance_valid(key_sprite) and key_sprite.visible:
			draw_arc(Vector2(255, 171), 42.0 + pulse * 4.0, 0.0, TAU, 24, Color(0.96, 0.84, 0.48, 0.45 + 0.4 * pulse), 1.8, true)

func _label(value: String, at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _clean_part(index: int) -> AtlasTexture:
	var crop := AtlasTexture.new()
	crop.atlas = preload("res://assets/props/beach_mechanism_clean_040b.png")
	var regions := [Rect2(56, 70, 537, 521), Rect2(708, 93, 490, 486), Rect2(91, 678, 470, 491), Rect2(844, 786, 183, 265)]
	crop.region = regions[index]
	crop.filter_clip = true
	return crop

func _sprite(texture: Texture2D, at: Vector2, height: float, parent: Node = null) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = at
	sprite.scale = Vector2.ONE * height / texture.get_height()
	(parent if parent != null else self).add_child(sprite)
	return sprite

func _build_key_box() -> void:
	_sprite(_clean_part(0), Vector2(255, 159), 232)
	key_sprite = _sprite(beach._mechanism_cell(2), Vector2(255, 171), 145)
	key_sprite.visible = not GameState.opening_flags.beach_cabinet_key_found
	lid_hinge = Node2D.new()
	lid_hinge.position = Vector2(143, 47)
	add_child(lid_hinge)
	var lid := _sprite(_clean_part(1), Vector2(111, 111), 222, lid_hinge)
	lid.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	openness = 1.0 if GameState.opening_flags.beach_key_box_open else 0.0
	lift = 1.0 if openness > 0 else 0.0
	_set_lid_pose()
	status.text = "按住箱盖先向上提起，再向左拉开（或点两下箱盖直接打开）。"
	if openness >= 0.95:
		status.text = "箱盖已经打开。挂钩上的黄铜钥匙可以直接取下。"
	_label("开盖后点击挂钩上的钥匙", Vector2(18, 287), 12)

func _set_lid_pose() -> void:
	lid_hinge.position.y = 47 - lift * 6
	lid_hinge.scale.x = 1.0 - openness * 0.93
	lid_hinge.skew = 0.0
	lid_hinge.modulate = Color.WHITE.darkened(openness * 0.15)

func _build_switch() -> void:
	# Center rotary switch plate & pointer precisely on hub (223, 152) with balanced stem pivot (zero eccentric orbiting!)
	_sprite(_clean_part(2), Vector2(223, 152), 212)
	pointer = _sprite(_clean_part(3), Vector2(223, 152), 110)
	pointer.offset.y = -14
	knob_mode = 2 if GameState.opening_flags.beach_headlights_on else (1 if GameState.opening_flags.beach_parking_lights_on else 0)
	pointer.rotation = (knob_mode - 1) * PI / 3.0
	var l0 := _label("关闭", Vector2(76, 265), 12)
	var l1 := _label("示宽灯", Vector2(204, 281), 12)
	var l2 := _label("远光", Vector2(338, 265), 12)
	for lbl in [l0, l1, l2]:
		lbl.add_theme_color_override("font_color", Color("e8dcc0"))
	status.text = "点击下方「远光」档位，或按住旋转车灯总成旋钮至右档。强远光能劈开黑沙水边的浓雾。"

func _build_plan() -> void:
	var image := TextureRect.new()
	image.position = Vector2(18, 49)
	image.size = Vector2(368, 230)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture = DemoItems.texture("hotel_maintenance_plan")
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)
	trace = Line2D.new()
	trace.width = 2.5
	trace.default_color = Color("41584c")
	trace.antialiased = true
	add_child(trace)
	var mark := shaft_mark()
	mark.position = ROUTE.back()
	mark.modulate = Color("69613f")
	mark.scale = Vector2.ONE * 1.16
	add_child(mark)
	status.text = "海水已经漫过排水口。找一条能一直走在潮线以上的路。"
	_label("按住入口，沿纸上的通道描到尽头", Vector2(18, 290), 12)
	if GameState.opening_flags.beach_circuit_matched:
		trace.points = PackedVector2Array(ROUTE)
		trace_progress = ROUTE.size()
		status.text = "井梯标记在左侧上方步道。沿着高地走就能看见。"

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if mode == "plan" and (trace_progress == ROUTE.size() or LOW_DRAIN_ENTRY.has_point(event.position)):
				if trace_progress < ROUTE.size():
					status.text = "这条是低位排水道。图的右端画着潮水，换一处入口试试。"
				accept_event()
				return
			if mode == "car":
				for i in range(LIGHT_TABS.size()):
					if LIGHT_TABS[i].has_point(event.position):
						_set_knob_mode(i)
						accept_event()
						return
			if mode == "key_box" and GameState.opening_flags.beach_key_box_open:
				if openness >= 0.95 and key_sprite.visible and Rect2(210, 102, 90, 141).has_point(event.position):
					beach.take_cabinet_key()
					key_sprite.hide()
					AudioManager.play_world_effect("archive_key_pickup")
					status.text = "黄铜钥匙已取下。盖板与挂钩还在，钥匙收进了背包。"
				return
			grabbed = Rect2(128, 44, 254, 236).has_point(event.position) if mode == "key_box" else (event.position.distance_to(Vector2(223, 166)) < 118 if mode == "car" else event.position.distance_to(ROUTE[0]) < 25)
			grab_origin = event.position
			if grabbed and is_instance_valid(motion):
				motion.kill()
				motion = null
				if mode == "key_box":
					lift = 0.0
					openness = 0.0
					_set_lid_pose()
				elif mode == "car":
					pointer.rotation = (knob_mode - 1) * PI / 3.0
			if mode == "plan" and grabbed:
				trace_progress = 1
				trace.points = PackedVector2Array([ROUTE[0]])
		else:
			if mode == "key_box" and grabbed and openness < 0.95:
				if event.position.distance_to(grab_origin) < 7.0:
					if latch_lifted:
						_open_key_box()
					else:
						latch_lifted = true
						lift = 1.0
						_set_lid_pose()
						status.text = "止扣已提起。再点箱盖，向左推开。"
						AudioManager.play_world_effect("lock_mechanism")
				else:
					latch_lifted = false
					_spring_back()
			elif mode == "car" and grabbed:
				_commit_knob()
			grabbed = false
		accept_event()
	elif event is InputEventMouseMotion and grabbed:
		match mode:
			"key_box":
				var displacement: Vector2 = event.position - grab_origin
				lift = maxf(lift, clampf(-displacement.y / 18.0, 0, 1))
				if lift >= 0.95: openness = clampf(absf(displacement.x) / 115.0, 0, 1)
				_set_lid_pose()
				if openness >= 0.95:
					_open_key_box()
			"car": pointer.rotation = clampf((event.position - Vector2(223, 152)).angle() + PI * 0.5, -PI / 3.0, PI / 3.0)
			"plan": _follow_route(event.position)
		accept_event()

func _spring_back() -> void:
	status.text = "止扣还压在盖边。先向上提起，再侧拉；盖板退回原位，可以重试。"
	if is_instance_valid(motion): motion.kill()
	spring_open = openness
	spring_lift = lift
	motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	motion.tween_method(_spring_pose, 1.0, 0.0, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _open_key_box() -> void:
	GameState.opening_flags.beach_key_box_open = true
	beach.key_box_overlay.show()
	beach.checkpoint()
	grabbed = false
	latch_lifted = false
	lift = 1.0
	status.text = "箱盖已开。点击挂钩上的黄铜钥匙。"
	AudioManager.play_world_effect("lock_mechanism")
	if is_instance_valid(motion):
		motion.kill()
	motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	motion.tween_method(_show_lid_opening, openness, 1.0, 0.22).set_trans(Tween.TRANS_SINE)

func _show_lid_opening(value: float) -> void:
	openness = value
	_set_lid_pose()

func _spring_pose(value: float) -> void:
	lift = spring_lift * value
	openness = spring_open * value
	_set_lid_pose()

func _commit_knob() -> void:
	_set_knob_mode(clampi(roundi(pointer.rotation / (PI / 3.0)) + 1, 0, 2))

func _set_knob_mode(setting: int) -> void:
	knob_mode = setting
	if is_instance_valid(motion): motion.kill()
	motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	motion.tween_property(pointer, "rotation", (knob_mode - 1) * PI / 3.0, 0.2).set_trans(Tween.TRANS_BACK)
	beach.set_light_mode(knob_mode)
	AudioManager.play_world_effect("power_switch")
	status.text = ["车灯关闭，水边仍由手电和路灯照明。", "位置灯亮了，光只落在车头近处；远处白影不受它限制。", "远光继电器吸合，两束灯从车头展开。到现场看清光照边界，再走低地。"][knob_mode]

func _follow_route(at: Vector2) -> void:
	if trace_progress >= ROUTE.size(): return
	var from: Vector2 = ROUTE[trace_progress - 1]
	var target: Vector2 = ROUTE[trace_progress]
	if Geometry2D.get_closest_point_to_segment(at, from, target).distance_to(at) > 18.0:
		grabbed = false
		trace_progress = 0
		trace.clear_points()
		status.text = "手指离开了维护线路。回到左侧入口，沿折线和连接点重新核对。"
		return
	var visible_points := PackedVector2Array()
	for index in range(trace_progress): visible_points.append(ROUTE[index])
	visible_points.append(Geometry2D.get_closest_point_to_segment(at, from, target))
	trace.points = visible_points
	if target.distance_to(at) < 18.0:
		trace.add_point(target)
		trace_progress += 1
		if trace_progress == ROUTE.size():
			grabbed = false
			beach.verify_maintenance_plan()
			status.text = "找到高位通道了。按 Esc 看现场的井梯标记。"
