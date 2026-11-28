extends Control

signal back_requested

var card_ids: Array[String] = []
var progress_label: Label
var progress_fill: ColorRect
var grid: GridContainer
var inspector: PanelContainer
var insp_image: TextureRect
var insp_title: Label
var insp_meta: Label
var insp_desc: Label
var _unlocked_count := 0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_refresh()


func _draw() -> void:
	var panel_w := size.x if size.x > 100.0 else 618.0
	var panel_h := size.y if size.y > 100.0 else 330.0
	draw_rect(Rect2(0, 0, panel_w, panel_h), Color(0.032, 0.056, 0.048, 0.98))
	draw_rect(Rect2(2, 2, panel_w - 4, panel_h - 4), Color("a28b58", 0.88), false, 1.2)
	draw_line(Vector2(14, 38), Vector2(panel_w - 14, 38), Color("536958", 0.72), 1.0)


func _build_ui() -> void:
	var header := Label.new()
	header.text = "✦ 澳门见闻成就图鉴"
	header.position = Vector2(16, 9)
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", Color("efd89a"))
	add_child(header)

	progress_label = Label.new()
	progress_label.position = Vector2(182, 11)
	progress_label.size = Vector2(164, 18)
	progress_label.add_theme_font_size_override("font_size", 11)
	progress_label.add_theme_color_override("font_color", Color("a9c2af"))
	add_child(progress_label)

	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(342, 17)
	bar_bg.size = Vector2(150, 7)
	bar_bg.color = Color("101b16")
	add_child(bar_bg)

	progress_fill = ColorRect.new()
	progress_fill.position = Vector2(343, 18)
	progress_fill.size = Vector2(0, 5)
	progress_fill.color = Color("e0bf6d")
	add_child(progress_fill)

	var back_btn := Button.new()
	back_btn.text = "< 返回"
	back_btn.position = Vector2(526, 7)
	back_btn.size = Vector2(78, 24)
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_btn.add_theme_font_size_override("font_size", 11)
	back_btn.add_theme_color_override("font_color", Color("f4e6b8"))
	var st := StyleBoxFlat.new()
	st.bg_color = Color("16261f")
	st.border_color = Color("bfa362")
	st.set_border_width_all(1)
	st.set_corner_radius_all(3)
	back_btn.add_theme_stylebox_override("normal", st)
	var hv := st.duplicate() as StyleBoxFlat
	hv.bg_color = Color("244134")
	back_btn.add_theme_stylebox_override("hover", hv)
	back_btn.add_theme_stylebox_override("pressed", hv)
	back_btn.pressed.connect(func():
		if is_instance_valid(inspector) and inspector.visible:
			inspector.hide()
		else:
			back_requested.emit()
	)
	add_child(back_btn)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(14, 44)
	scroll.size = Vector2(590, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	var opt_note := Label.new()
	opt_note.text = "点击已解锁卡片放大欣赏实景档案（纯探索成就收集，不影响通关与三结局）"
	opt_note.position = Vector2(16, 308)
	opt_note.size = Vector2(586, 18)
	opt_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opt_note.add_theme_font_size_override("font_size", 10)
	opt_note.add_theme_color_override("font_color", Color("95aa99"))
	add_child(opt_note)

	_build_inspector()


func _build_inspector() -> void:
	inspector = PanelContainer.new()
	inspector.position = Vector2(36, 46)
	inspector.size = Vector2(546, 264)
	inspector.visible = false
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(0.03, 0.055, 0.045, 0.98)
	skin.border_color = Color("dfc379")
	skin.set_border_width_all(2)
	skin.set_corner_radius_all(5)
	skin.content_margin_left = 12
	skin.content_margin_right = 12
	skin.content_margin_top = 10
	skin.content_margin_bottom = 10
	inspector.add_theme_stylebox_override("panel", skin)
	add_child(inspector)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	inspector.add_child(v)

	insp_image = TextureRect.new()
	insp_image.custom_minimum_size = Vector2(520, 152)
	insp_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	insp_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(insp_image)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)

	insp_title = Label.new()
	insp_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	insp_title.add_theme_font_size_override("font_size", 14)
	insp_title.add_theme_color_override("font_color", Color("f2de9d"))
	row.add_child(insp_title)

	insp_meta = Label.new()
	insp_meta.add_theme_font_size_override("font_size", 10)
	insp_meta.add_theme_color_override("font_color", Color("90bfa0"))
	row.add_child(insp_meta)

	insp_desc = Label.new()
	insp_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	insp_desc.custom_minimum_size = Vector2(518, 36)
	insp_desc.add_theme_font_size_override("font_size", 11)
	insp_desc.add_theme_color_override("font_color", Color("dde4d3"))
	v.add_child(insp_desc)

	var close_btn := Button.new()
	close_btn.text = "收起大图"
	close_btn.custom_minimum_size = Vector2(110, 22)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.add_theme_font_size_override("font_size", 10)
	var cst := StyleBoxFlat.new()
	cst.bg_color = Color("1b3027")
	cst.border_color = Color("bfa362")
	cst.set_border_width_all(1)
	cst.set_corner_radius_all(3)
	close_btn.add_theme_stylebox_override("normal", cst)
	close_btn.pressed.connect(func(): inspector.hide())
	v.add_child(close_btn)


func _refresh() -> void:
	for ch in grid.get_children():
		ch.queue_free()
	card_ids = MacauGuide.ordered_ids()
	_unlocked_count = 0
	for cid in card_ids:
		var card := MacauGuide.get_card(cid)
		var unlocked := cid in GameState.macau_guide_unlocked
		if unlocked:
			_unlocked_count += 1
		grid.add_child(_make_achievement_tile(cid, card, unlocked))
	progress_label.text = "已收集 %d / %d 枚见闻成就" % [_unlocked_count, card_ids.size()]
	var pct := float(_unlocked_count) / maxf(1.0, float(card_ids.size()))
	progress_fill.size.x = 148.0 * pct


func _make_achievement_tile(_cid: String, card: Dictionary, unlocked: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(138, 108)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if unlocked else Control.CURSOR_ARROW

	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.06, 0.10, 0.085, 0.96) if unlocked else Color(0.035, 0.052, 0.046, 0.85)
	n.border_color = Color("cda85c", 0.88) if unlocked else Color("34443a", 0.72)
	n.set_border_width_all(1)
	n.set_corner_radius_all(4)
	n.content_margin_left = 5
	n.content_margin_right = 5
	n.content_margin_top = 5
	n.content_margin_bottom = 5
	btn.add_theme_stylebox_override("normal", n)
	var hv := n.duplicate() as StyleBoxFlat
	if unlocked:
		hv.bg_color = Color(0.095, 0.16, 0.13, 0.98)
		hv.border_color = Color("f6df96")
	btn.add_theme_stylebox_override("hover", hv)
	btn.add_theme_stylebox_override("pressed", hv)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(5, 5)
	vbox.size = Vector2(128, 98)
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	var img_box := PanelContainer.new()
	img_box.custom_minimum_size = Vector2(128, 64)
	img_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ib_style := StyleBoxFlat.new()
	ib_style.bg_color = Color(0.02, 0.035, 0.03, 0.95)
	ib_style.border_color = Color("3a4d40", 0.75)
	ib_style.set_border_width_all(1)
	img_box.add_theme_stylebox_override("panel", ib_style)
	vbox.add_child(img_box)

	var img_rect := TextureRect.new()
	img_rect.custom_minimum_size = Vector2(126, 62)
	img_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var img_path := str(card.get("image", ""))
	if not img_path.is_empty() and ResourceLoader.exists(img_path):
		img_rect.texture = load(img_path)
	img_rect.modulate = Color.WHITE if unlocked else Color(0.16, 0.22, 0.20, 0.65)
	img_box.add_child(img_rect)

	var badge := Label.new()
	badge.text = ("✦ " + str(card.get("tag", ""))) if unlocked else ("？ " + str(card.get("location", "待探索")))
	badge.add_theme_font_size_override("font_size", 8)
	badge.add_theme_color_override("font_color", Color("dfc374") if unlocked else Color("6c7e72"))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(badge)

	var t := Label.new()
	t.text = str(card.get("title", "")) if unlocked else "未收录风物"
	t.clip_text = true
	t.add_theme_font_size_override("font_size", 10)
	t.add_theme_color_override("font_color", Color("f2f0df") if unlocked else Color("697b70"))
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(t)

	if unlocked:
		btn.pressed.connect(_open_inspector.bind(card))
	return btn


func _open_inspector(card: Dictionary) -> void:
	AudioManager.play_dialogue_advance()
	var img_path := str(card.get("image", ""))
	insp_image.texture = load(img_path) if (not img_path.is_empty() and ResourceLoader.exists(img_path)) else null
	insp_title.text = "✦ " + str(card.get("title", ""))
	insp_meta.text = "%s  ·  %s" % [str(card.get("tag", "")), str(card.get("location", ""))]
	insp_desc.text = "%s  （改编：%s）" % [str(card.get("fact", "")), str(card.get("adaptation", ""))]
	inspector.show()
