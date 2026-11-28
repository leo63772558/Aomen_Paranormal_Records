extends Control

signal solved

const FIELD_IDS := ["trace_a", "wrack", "trace_b"]
const FIELD_FLAGS := ["beach_trace_a_seen", "beach_wrack_seen", "beach_trace_b_seen"]
const FIELD_TITLES := ["① 户外靴与拖痕 (A)", "② 渔民胶鞋与潮线", "③ 陌生运动鞋 (B)"]

var beach: Node2D
var focus := "sole"
var source_image: TextureRect
var field_image: TextureRect
var source_overlay: Control
var field_overlay: Control
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
var notch_highlight: Line2D
var guide_clock := 0.0

func configure(scene: Node2D, initial_focus: String) -> void:
	beach = scene
	focus = initial_focus

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	var title_lbl := _label("黑沙海滩 · 网购靴底订单叠影比对", Vector2(18, 5), 14)
	title_lbl.add_theme_color_override("font_color", Color("ebd69c"))
	var left_cap := _label("手机 · 37码户外靴网购订单与鞋底实拍", Vector2(22, 58), 9)
	left_cap.add_theme_color_override("font_color", Color("d8c89a"))
	var esc_lbl := _label("Esc 返回", Vector2(546, 7), 11)
	esc_lbl.add_theme_color_override("font_color", Color("bfbca8"))

	for index in range(FIELD_IDS.size()):
		var button := Button.new()
		button.text = FIELD_TITLES[index] if GameState.opening_flags[FIELD_FLAGS[index]] else FIELD_TITLES[index] + " · 待调查"
		button.position = Vector2(18 + index * 195, 26)
		button.size = Vector2(188, 21)
		button.add_theme_font_size_override("font_size", 11)
		_style_button(button, false)
		button.pressed.connect(_select_field.bind(FIELD_IDS[index]))
		add_child(button)
		evidence_buttons.append(button)

	# Generous dark-slate forensic evidence photo frames with clean 9px margin below top tabs and above zoom row!
	source_clip = _clip(Vector2(18, 56), Vector2(282, 126))
	field_clip = _clip(Vector2(318, 56), Vector2(282, 126))
	source_image = _image(source_clip, beach.footprint_cell(0))
	field_image = _image(field_clip, beach.footprint_cell(1))
	source_clip.mouse_filter = Control.MOUSE_FILTER_PASS
	source_clip.mouse_default_cursor_shape = Control.CURSOR_DRAG

	source_overlay = Control.new()
	source_overlay.size = source_clip.size
	source_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	source_overlay.draw.connect(_draw_source_callouts)
	source_clip.add_child(source_overlay)

	field_overlay = Control.new()
	field_overlay.size = field_clip.size
	field_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field_overlay.draw.connect(_draw_field_callouts)
	field_clip.add_child(field_overlay)

	notch_highlight = Line2D.new()
	notch_highlight.points = PackedVector2Array([
		Vector2(158, 86), Vector2(184, 74), Vector2(192, 102), Vector2(158, 86)
	])
	notch_highlight.width = 1.8
	notch_highlight.default_color = Color("d8be7c", 0.0)
	notch_highlight.antialiased = true
	field_clip.add_child(notch_highlight)

	drag_ghost = TextureRect.new()
	drag_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_ghost.texture = beach.footprint_cell(0)
	drag_ghost.size = Vector2(220, 104)
	drag_ghost.modulate = Color(1.0, 0.94, 0.78, 0.65)
	drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_ghost.visible = false
	add_child(drag_ghost)

	_label("放大局部：", Vector2(16, 190), 10)
	for index in range(4):
		var detail := Button.new()
		detail.text = ["全图", "前掌纹", "右跟缺角", "海草压痕"][index]
		detail.position = Vector2(76 + index * 105, 187)
		detail.size = Vector2(98, 20)
		detail.add_theme_font_size_override("font_size", 10)
		_style_button(detail, false)
		detail.pressed.connect(_focus_detail.bind(index))
		add_child(detail)
		detail_buttons.append(detail)

	var overlay_btn := Button.new()
	overlay_btn.name = "QuickOverlayButton"
	overlay_btn.text = "⚡ 一键叠影比对"
	overlay_btn.position = Vector2(504, 187)
	overlay_btn.size = Vector2(96, 20)
	overlay_btn.add_theme_font_size_override("font_size", 10)
	_style_button(overlay_btn, true)
	overlay_btn.pressed.connect(_on_quick_overlay_pressed)
	add_child(overlay_btn)

	# Clean non-overlapping two-column forensic deduction controls
	_label("① 嘉敏的鞋印：", Vector2(18, 228), 11)
	_label("② 涨潮前留下：", Vector2(272, 228), 11)
	for index in range(2):
		var value := "A" if index == 0 else "B"
		var pattern := Button.new()
		pattern.text = value
		pattern.position = Vector2(128 + index * 52, 224)
		pattern.size = Vector2(44, 24)
		pattern.add_theme_font_size_override("font_size", 12)
		_style_button(pattern, false)
		pattern.pressed.connect(func():
			matching = value
			_refresh_status()
		)
		add_child(pattern)
		choice_buttons.append(pattern)
		var time := Button.new()
		time.text = value
		time.position = Vector2(382 + index * 52, 224)
		time.size = Vector2(44, 24)
		time.add_theme_font_size_override("font_size", 12)
		_style_button(time, false)
		time.pressed.connect(func():
			earlier = value
			_refresh_status()
		)
		add_child(time)
		choice_buttons.append(time)

	var confirm := Button.new()
	confirm.text = "确认判断"
	confirm.position = Vector2(504, 223)
	confirm.size = Vector2(96, 26)
	confirm.add_theme_font_size_override("font_size", 11)
	_style_button(confirm, true)
	confirm.pressed.connect(submit)
	add_child(confirm)

	status = _label("对比左图网购户外靴实拍（右跟缺角）与右图（可点「一键叠影比对」或拖动左图），选出①嘉敏鞋印与②涨潮前鞋印后点「确认判断」。", Vector2(24, 266), 11)
	status.size = Vector2(570, 44)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_select_field(focus if focus != "sole" else "trace_a")
	detail_buttons[0].modulate = Color("ead493")
	if GameState.opening_flags.beach_footprints_solved:
		matching = "A"
		earlier = "A"
		_refresh_status()

func _style_button(btn: Button, accent := false) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_color_override("font_color", Color("efe2b4") if accent else Color("dcdcc8"))
	btn.add_theme_color_override("font_hover_color", Color("fff4cf"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.22, 0.18, 0.92) if accent else Color(0.06, 0.10, 0.09, 0.88)
	normal.border_color = Color("b29a64") if accent else Color("5c6454")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	normal.content_margin_top = 1.0
	normal.content_margin_bottom = 1.0
	normal.content_margin_left = 4.0
	normal.content_margin_right = 4.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("1f3a2e")
	hover.border_color = Color("e0c67e")
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)

func _label(value: String, at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e4e0cc"))
	label.add_theme_color_override("font_shadow_color", Color("07100c"))
	label.add_theme_constant_override("shadow_offset_y", 1)
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

func _draw_photo_mounts(ctrl: Control) -> void:
	# Subtle realistic dark-brass forensic corner mounts & millimeter ruler ticks along bottom edge (ZERO neon spoilers!)
	var w := ctrl.size.x
	var h := ctrl.size.y
	var c := Color(0.76, 0.67, 0.45, 0.55)
	for corner in [[Vector2(4, 4), Vector2(14, 4), Vector2(4, 14)], [Vector2(w - 4, 4), Vector2(w - 14, 4), Vector2(w - 4, 14)], [Vector2(4, h - 4), Vector2(14, h - 4), Vector2(4, h - 14)], [Vector2(w - 4, h - 4), Vector2(w - 14, h - 4), Vector2(w - 4, h - 14)]]:
		ctrl.draw_line(corner[0], corner[1], c, 1.2)
		ctrl.draw_line(corner[0], corner[2], c, 1.2)
	for tx in range(18, int(w) - 16, 12):
		var th := 5.0 if (tx % 24 == 0) else 2.5
		ctrl.draw_line(Vector2(tx, h - 2), Vector2(tx, h - 2 - th), Color(0.74, 0.68, 0.52, 0.35), 1.0)

func _draw_source_callouts() -> void:
	if not is_instance_valid(source_image):
		return
	_draw_photo_mounts(source_overlay)

func _draw_field_callouts() -> void:
	if not is_instance_valid(field_image) or not field_image.visible:
		return
	_draw_photo_mounts(field_overlay)

func _select_field(id: String) -> void:
	if not is_instance_valid(field_image): return
	focus = id
	var index := FIELD_IDS.find(id)
	for i in range(evidence_buttons.size()):
		evidence_buttons[i].modulate = Color("e2ca84") if i == index else Color.WHITE
	field_image.show()
	field_image.texture = beach.footprint_cell(index + 1)
	_set_zoom(zoom)
	if GameState.opening_flags.beach_footprints_solved:
		_refresh_status()
	elif not GameState.opening_flags[FIELD_FLAGS[index]]:
		status.text = "这处痕迹还没实地核对。趁退潮走近微光，按 E 调查。"
	else:
		status.text = {
			"trace_a": "① A 处斜人字纹户外靴（右跟三角缺角）与手机网购订单实拍完全吻合，鞋印旁留有倒地挣扎拖向暗渠的滑痕！",
			"wrack": "② 这是渔民深齿胶鞋与涨潮推上来的海草带——海草直接覆在 A 处户外靴拖痕之上，说明她在涨潮前就出事了。",
			"trace_b": "③ 这是另一枚新鲜的陌生运动鞋脚印，前掌横梯纹、鞋跟完整，与嘉敏那双网购户外靴完全对不上。"
		}[id]
	if is_instance_valid(source_overlay): source_overlay.queue_redraw()
	if is_instance_valid(field_overlay): field_overlay.queue_redraw()

func _focus_detail(index: int) -> void:
	if index == 3:
		_select_field("wrack")
	detail_anchor = [0.5, 0.28, 0.86, 0.45][index]
	for i in range(detail_buttons.size()):
		detail_buttons[i].modulate = Color("e2ca84") if i == index else Color.WHITE
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
	if is_instance_valid(source_overlay): source_overlay.queue_redraw()
	if is_instance_valid(field_overlay): field_overlay.queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if is_instance_valid(zoom_motion):
			zoom_motion.kill()
		_set_zoom(clampf(zoom + (0.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.2), 1.0, 3.4))
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and source_clip.get_rect().has_point(event.position):
			dragging_sole = true
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
		notch_highlight.default_color.a = 0.72 if (over and focus != "trace_b") else 0.0
		accept_event()

func _on_quick_overlay_pressed() -> void:
	if is_instance_valid(drag_ghost) and is_instance_valid(source_clip) and is_instance_valid(field_clip):
		drag_ghost.position = source_clip.position + Vector2(30, 12)
		drag_ghost.visible = true
		var tw := drag_ghost.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(drag_ghost, "position", field_clip.position + Vector2(30, 12), 0.24).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(0.18)
		tw.tween_callback(func():
			if is_instance_valid(drag_ghost):
				drag_ghost.visible = false
		)
	_apply_sole_overlay()

func _apply_sole_overlay() -> void:
	AudioManager.play_world_effect("archive_ticket_pickup")
	if not GameState.opening_flags[FIELD_FLAGS[FIELD_IDS.find(focus)]]:
		status.text = "先到现场核对这处痕迹。"
		return
	if focus == "trace_b":
		status.text = "叠影对不上！B 处横梯纹陌生运动鞋与网购 37 码户外靴鞋底不符。"
		return
	if focus == "wrack":
		status.text = "② 处渔民胶鞋与海草压痕清晰显示：涨潮海草压在 A 处靴印之上，先有脚印后涨潮。"
		return
	notch_highlight.default_color.a = 0.80
	status.text = "叠影高度吻合！斜人字纹与右跟缺角和手机网购户外靴订单一致，旁有倒地拖往暗渠的拖痕——请确认下方选项。"

func _refresh_status() -> void:
	if status == null: return
	var options := [matching == "A", earlier == "A", matching == "B", earlier == "B"]
	for i in range(choice_buttons.size()):
		choice_buttons[i].modulate = Color("e2ca84") if options[i] else Color.WHITE
	if GameState.opening_flags.beach_footprints_solved:
		status.add_theme_color_override("font_color", Color("d2e8ba"))
		status.text = "推理成立：A 处户外靴印与手机网购实拍完全吻合，且海草压在倒地拖痕之上——嘉敏早在涨潮前就于沙滩倒地，并被拖进沿海暗渠！海里呼救是水鬼诱饵。"
		return
	status.add_theme_color_override("font_color", Color("e4e0cc"))
	if matching.is_empty():
		status.text = "请先选定①：对比左图右跟三角缺角，哪枚鞋印属于嘉敏？"
	elif earlier.is_empty():
		status.text = "请先选定②：查看潮线海草压痕，哪枚鞋印是在涨潮之前留下的？"
	else:
		status.text = "两项已选。按「确认判断」核对。"

func submit() -> void:
	if GameState.opening_flags.beach_footprints_solved:
		_refresh_status()
		return
	var missing_hint := {
		"beach_trace_a_seen": "还差物证①（A 沙滩鞋印）。返回黑沙滩靠近 A 标记按 E 取证。",
		"beach_wrack_seen": "还差物证②（A 潮线海草）。返回黑沙滩在潮线处按 E 取证。",
		"beach_trace_b_seen": "还差物证③（B 另一处鞋印）。返回黑沙滩靠近 B 标记按 E 取证。"
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
		status.text = "鞋纹没有对上。放大前掌和右后跟，再和修鞋照比一次。"
		return
	if earlier != "A":
		_select_field("wrack")
		status.text = "再看看海草压着哪道鞋印。是先踩出鞋印，还是先有海草？"
		return
	solved.emit()
	_refresh_status()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	guide_clock += delta

func _draw() -> void:
	draw_texture_rect(preload("res://assets/tilesets/hacsa_beach_038.png"), Rect2(Vector2.ZERO, size), false, Color(0.20, 0.23, 0.22, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.042, 0.040, 0.80))
	# Recessed dark photographic trays behind both evidence shots
	if is_instance_valid(source_clip) and is_instance_valid(field_clip):
		draw_rect(source_clip.get_rect().grow(2.0), Color(0.03, 0.045, 0.042, 0.94))
		draw_rect(field_clip.get_rect().grow(2.0), Color(0.03, 0.045, 0.042, 0.94))
		draw_rect(source_clip.get_rect().grow(2.0), Color("706246"), false, 1.4)
		draw_rect(field_clip.get_rect().grow(2.0), Color("dfc67e") if dragging_sole else Color("706246"), false, 1.8 if dragging_sole else 1.4)
	# Clean recessed ledger footer bar for status / conclusion
	draw_rect(Rect2(16, 256, 586, 62), Color(0.035, 0.058, 0.052, 0.92))
	draw_rect(Rect2(16, 256, 586, 62), Color("b8a268") if GameState.opening_flags.beach_footprints_solved else Color("525c50"), false, 1.2)
