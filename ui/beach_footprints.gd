extends Control

signal solved

var beach: Node2D
var focus := "sole"
var source_image: TextureRect
var field_image: TextureRect
var status: Label
var matching := ""
var earlier := ""
var choice_buttons: Array[Button] = []
var evidence_buttons: Array[Button] = []
var source_clip: Control
var field_clip: Control
var zoom := 1.0
var detail_anchor := 0.5
var zoom_motion: Tween
var detail_buttons: Array[Button] = []
var drag_ghost: TextureRect
var dragging_sole := false
var drag_offset := Vector2.ZERO
var notch_highlight: Line2D
var tide_wave_overlay: Polygon2D
var guide_clock := 0.0

func configure(scene: Node2D, initial_focus: String) -> void:
	beach = scene
	focus = initial_focus

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_label("对照鞋底照片与现场鞋印", Vector2(18, 7), 18)
	for index in range(3):
		var id: String = ["trace_a", "wrack", "trace_b"][index]
		var button := Button.new()
		button.text = ["A · 鞋印", "A · 潮线压痕", "B · 新鞋印"][index]
		button.position = Vector2(18 + index * 194, 35)
		button.size = Vector2(188, 25)
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_select_field.bind(id))
		add_child(button)
		evidence_buttons.append(button)
	source_clip = _clip(Vector2(18, 85), Vector2(278, 115))
	field_clip = _clip(Vector2(320, 85), Vector2(278, 115))
	source_image = _image(source_clip, beach.footprint_cell(0))
	field_image = _image(field_clip, beach.footprint_cell(1))
	source_clip.mouse_filter = Control.MOUSE_FILTER_PASS
	source_clip.mouse_default_cursor_shape = Control.CURSOR_DRAG
	notch_highlight = Line2D.new()
	notch_highlight.points = PackedVector2Array([
		Vector2(168, 72), Vector2(196, 56), Vector2(204, 86), Vector2(168, 72)
	])
	notch_highlight.width = 2.6
	notch_highlight.default_color = Color("f6dc86", 0.0)
	notch_highlight.antialiased = true
	field_clip.add_child(notch_highlight)
	tide_wave_overlay = Polygon2D.new()
	tide_wave_overlay.polygon = PackedVector2Array([
		Vector2(0, 48), Vector2(278, 36), Vector2(278, 115), Vector2(0, 115)
	])
	tide_wave_overlay.color = Color(0.28, 0.56, 0.54, 0.0)
	field_clip.add_child(tide_wave_overlay)
	drag_ghost = TextureRect.new()
	drag_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_ghost.texture = beach.footprint_cell(0)
	drag_ghost.size = Vector2(220, 92)
	drag_ghost.modulate = Color(1.0, 0.94, 0.76, 0.68)
	drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_ghost.visible = false
	add_child(drag_ghost)
	_label("出发前的鞋底照（可拖到右图叠合）", Vector2(22, 67), 12)
	_label("现场照片", Vector2(323, 67), 12)
	_label("两图对照", Vector2(22, 211), 11)
	for index in range(4):
		var detail := Button.new()
		detail.text = ["全图", "前掌鞋纹", "鞋跟边缘", "潮线位置"][index]
		detail.position = Vector2(86 + index * 117, 204)
		detail.size = Vector2(108, 31)
		detail.add_theme_font_size_override("font_size", 12)
		detail.pressed.connect(_focus_detail.bind(index))
		add_child(detail)
		detail_buttons.append(detail)
	_label("① 哪枚鞋纹相同？", Vector2(18, 246), 12)
	_label("② 哪枚早于潮线？", Vector2(320, 246), 12)
	for index in range(2):
		var value := "A" if index == 0 else "B"
		var pattern := Button.new()
		pattern.text = value
		pattern.position = Vector2(159 + index * 69, 240)
		pattern.size = Vector2(59, 28)
		pattern.pressed.connect(func():
			matching = value
			_refresh_status()
		)
		add_child(pattern)
		choice_buttons.append(pattern)
		var time := Button.new()
		time.text = value
		time.position = Vector2(462 + index * 69, 240)
		time.size = Vector2(59, 28)
		time.pressed.connect(func():
			earlier = value
			_refresh_status()
		)
		add_child(time)
		choice_buttons.append(time)
	status = _label("到沙滩调查金色标记，照片就会出现在这里。", Vector2(18, 273), 12)
	status.size = Vector2(580, 19)
	var confirm := Button.new()
	confirm.text = "确认判断"
	confirm.position = Vector2(18, 296)
	confirm.size = Vector2(223, 28)
	confirm.pressed.connect(submit)
	add_child(confirm)
	_label("Esc / J 返回", Vector2(463, 303), 12)
	_select_field(focus if focus != "sole" else "trace_a")
	detail_buttons[0].modulate = Color("ead493")
	if GameState.opening_flags.beach_footprints_solved:
		matching = "A"
		earlier = "A"
		_refresh_status()

func _label(value: String, at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	return label

func _clip(at: Vector2, dimensions: Vector2) -> Control:
	var clip := Control.new()
	clip.position = at
	clip.size = dimensions
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	return clip

func _image(parent: Control, texture: Texture2D) -> TextureRect:
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.texture = texture
	image.size = parent.size
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _select_field(id: String) -> void:
	if not is_instance_valid(field_image): return
	focus = id
	var flag: String = {"trace_a":"beach_trace_a_seen", "wrack":"beach_wrack_seen", "trace_b":"beach_trace_b_seen"}.get(id, "beach_trace_a_seen")
	for i in range(evidence_buttons.size()):
		evidence_buttons[i].modulate = Color("e7ce89") if ["trace_a", "wrack", "trace_b"][i] == id else Color.WHITE
		evidence_buttons[i].tooltip_text = "已调查" if GameState.opening_flags[["beach_trace_a_seen", "beach_wrack_seen", "beach_trace_b_seen"][i]] else "到现场按 E 调查"
	if not GameState.opening_flags[flag]:
		field_image.hide()
		status.text = "还没拍下这处痕迹。到沙滩的金色标记旁按 E。"
		return
	field_image.show()
	field_image.texture = beach.footprint_cell({"trace_a":1, "wrack":2, "trace_b":3}[id])
	_set_zoom(zoom)
	if GameState.opening_flags.beach_footprints_solved:
		_refresh_status()
	else:
		status.text = {"trace_a":"A · 向水边延伸的鞋印。", "wrack":"A · 压痕中的海草、碎贝与薄水。", "trace_b":"B · 干沙与泡沫边缘的鞋印。"}[id]

func _focus_detail(index: int) -> void:
	if index == 3:
		_select_field("wrack")
	detail_anchor = [0.5, 0.28, 0.86, 0.42][index]
	for i in range(detail_buttons.size()):
		detail_buttons[i].modulate = Color("ead493") if i == index else Color.WHITE
	if is_instance_valid(zoom_motion):
		zoom_motion.kill()
	zoom_motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	zoom_motion.tween_method(_set_zoom, zoom, 1.0 if index == 0 else 2.9, 0.16)

func _set_zoom(value: float) -> void:
	zoom = value
	for photo in [source_image, field_image]:
		var clip_size: Vector2 = photo.size
		var native_size: Vector2 = photo.texture.get_size()
		var fitted := native_size * minf(clip_size.x / native_size.x, clip_size.y / native_size.y)
		photo.scale = Vector2.ONE * zoom
		photo.position.x = clip_size.x * (1.0 - zoom) * 0.5
		var anchor_y := (clip_size.y - fitted.y) * 0.5 + fitted.y * detail_anchor
		photo.position.y = clampf(clip_size.y * 0.5 - anchor_y * zoom, clip_size.y * (1.0 - zoom), 0.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if is_instance_valid(zoom_motion):
			zoom_motion.kill()
		_set_zoom(clampf(zoom + (0.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.2), 1.0, 3.4))
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and source_clip.get_rect().has_point(event.position):
			dragging_sole = true
			drag_offset = event.position - source_clip.position
			drag_ghost.position = event.position - drag_ghost.size * 0.5
			drag_ghost.visible = true
			accept_event()
		elif not event.pressed and dragging_sole:
			dragging_sole = false
			drag_ghost.visible = false
			if field_clip.get_rect().grow(24.0).has_point(event.position):
				_apply_sole_overlay()
			accept_event()
	elif event is InputEventMouseMotion and dragging_sole:
		drag_ghost.position = event.position - drag_ghost.size * 0.5
		var over := field_clip.get_rect().grow(24.0).has_point(event.position)
		notch_highlight.default_color.a = 0.92 if (over and focus != "trace_b") else 0.0
		accept_event()

func _apply_sole_overlay() -> void:
	AudioManager.play_world_effect("archive_ticket_pickup")
	if focus == "trace_b":
		status.text = "叠合不符：B 是横梯纹且无缺角，不是嘉敏那双靴。"
		return
	matching = "A"
	earlier = "A"
	notch_highlight.default_color.a = 0.95
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(tide_wave_overlay, "color:a", 0.34, 0.25)
	tw.tween_property(tide_wave_overlay, "color:a", 0.14, 0.35)
	_refresh_status()
	if GameState.opening_flags.beach_trace_a_seen and GameState.opening_flags.beach_wrack_seen and GameState.opening_flags.beach_trace_b_seen:
		submit()
	else:
		status.text = "缺角吻合且被潮线覆盖（已填入 A / A）。拍齐沙滩三处标记即可确认。"

func _refresh_status() -> void:
	if status == null: return
	var options := [matching == "A", earlier == "A", matching == "B", earlier == "B"]
	for i in range(choice_buttons.size()):
		choice_buttons[i].modulate = Color("ead493") if options[i] else Color.WHITE
	if matching.is_empty():
		status.text = "还差第①项：对照鞋底照片，在左侧选出相同鞋纹。"
	elif earlier.is_empty():
		status.text = "还差第②项：看潮线与压痕谁盖住谁，在右侧选择。"
	else:
		status.text = "两项已选，可以确认判断。"
	if GameState.opening_flags.beach_footprints_solved:
		status.text = "嘉敏来过这里。涨潮盖住了她的鞋印。"

func submit() -> void:
	if GameState.opening_flags.beach_footprints_solved:
		_refresh_status()
		return
	var missing_hint := {
		"beach_trace_a_seen": "还差 A 鞋印。返回沙滩，靠近 A 标记按 E。",
		"beach_wrack_seen": "还差潮线照片。返回沙滩，在 A 鞋印旁的潮线按 E。",
		"beach_trace_b_seen": "还差 B 鞋印。返回沙滩，靠近 B 标记按 E。"
	}
	for flag in missing_hint:
		if not GameState.opening_flags[flag]:
			status.text = missing_hint[flag]
			return
	if matching.is_empty() or earlier.is_empty():
		_refresh_status()
		return
	if matching != "A":
		_select_field("trace_b")
		status.text = "B 是横梯纹，没有相同的缺角；新鲜不等于来自嘉敏。"
		return
	if earlier != "A":
		_select_field("wrack")
		status.text = "潮线碎屑盖在 A 的凹槽上；A 先形成，随后才被水与海草覆盖。"
		return
	solved.emit()
	_refresh_status()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if not GameState.opening_flags.beach_footprints_solved and matching.is_empty():
		guide_clock += delta
		queue_redraw()

func _draw() -> void:
	if is_instance_valid(source_clip) and is_instance_valid(field_clip):
		draw_rect(source_clip.get_rect().grow(1.5), Color("807050"), false, 1.5)
		draw_rect(field_clip.get_rect().grow(1.5), Color("e8cf88") if dragging_sole else Color("807050"), false, 2.0 if dragging_sole else 1.5)
	if not GameState.opening_flags.beach_footprints_solved and matching.is_empty() and not dragging_sole and field_image != null and field_image.visible:
		var pulse := 0.45 + 0.45 * sin(guide_clock * 4.2)
		var shift := fmod(guide_clock * 22.0, 20.0)
		var arrow_col := Color(0.95, 0.85, 0.54, pulse)
		var start := Vector2(286.0 + shift * 0.45, 142.0)
		var tip := Vector2(314.0 + shift * 0.45, 142.0)
		draw_line(start, tip, arrow_col, 2.2, true)
		draw_line(tip, tip + Vector2(-7, -5), arrow_col, 2.2, true)
		draw_line(tip, tip + Vector2(-7, 5), arrow_col, 2.2, true)
