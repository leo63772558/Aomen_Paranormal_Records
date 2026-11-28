extends Control

signal map_requested
signal journal_requested
signal bag_requested
signal macau_guide_requested
signal live_noise_toggled(enabled: bool)

# Realistic vertical smartphone rendered inside assets/ui/jiamin_phone_011.png (1672x941).
# Zoomed 1.24x centered so the cracked vertical handset fills viewport height cleanly while
# framing the glowing St. Paul's Ruins window on the left and weathered desk/talisman on the right.
const BG_DST := Rect2(-74.0, -40.0, 766.0, 410.0)
const SCREEN_RECT := Rect2(221.0, 24.0, 176.0, 276.0)
const HOME_BTN_RECT := Rect2(290.0, 304.0, 38.0, 16.0)

var battery_status: Label
var charge_button: Button
var photo_cover: PanelContainer
var meter_cover: PanelContainer
var recent_noise := PackedStringArray()
var live_noise_enabled := false
var phone_bg: Texture2D
var ahhao_tex: Texture2D
var jiamin_tex: Texture2D
var shoe_tex: Texture2D
var active_app := "home" # "home" | "wechat"
var home_nodes: Array[Control] = []
var wechat_container: Control
var app_buttons: Array[Dictionary] = []
var status_clock_label: Label
var status_bat_label: Label

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	phone_bg = load("res://assets/ui/jiamin_phone_011.png")
	ahhao_tex = load("res://assets/ui/ahhao_portrait_252.png")
	jiamin_tex = hud_jiamin_portrait()
	shoe_tex = DemoItems.texture("shoe_repair_photo")

	# Subtle top-right close hint & side utility controls resting cleanly on the dark wooden backdrop
	var footer := Label.new()
	footer.text = "Q / Tab / Esc 收起手机"
	footer.position = Vector2(464, 12)
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color("c8c2ae"))
	footer.add_theme_color_override("font_shadow_color", Color("070908"))
	footer.add_theme_constant_override("shadow_offset_y", 1)
	add_child(footer)

	# Compact left desk tag showing handset owner & flash status
	var left_tag := Label.new()
	left_tag.text = "嘉敏的手机\n[ R ] 强闪防身"
	left_tag.position = Vector2(18, 250)
	left_tag.size = Vector2(168, 36)
	left_tag.add_theme_font_size_override("font_size", 11)
	left_tag.add_theme_color_override("font_color", Color("dfd2a8"))
	left_tag.add_theme_color_override("font_shadow_color", Color("060807"))
	left_tag.add_theme_constant_override("shadow_offset_y", 1)
	add_child(left_tag)

	battery_status = Label.new()
	battery_status.position = Vector2(18, 286)
	battery_status.size = Vector2(184, 34)
	battery_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battery_status.add_theme_font_size_override("font_size", 10)
	battery_status.add_theme_color_override("font_color", Color("b8c9bc"))
	battery_status.add_theme_color_override("font_shadow_color", Color("060807"))
	battery_status.add_theme_constant_override("shadow_offset_y", 1)
	add_child(battery_status)

	# Right-side desk controls: Macau Field Guide, charger (when available) & reduced-flash accessibility toggle
	var guide_btn := _make_desk_button("✦ 澳门见闻 (%d/%d)" % [GameState.macau_guide_unlocked.size(), MacauGuide.total_count()], Vector2(452, 210), Vector2(138, 26), Color("1a3028"))
	guide_btn.name = "MacauGuideDeskButton"
	guide_btn.pressed.connect(func():
		AudioManager.play_dialogue_advance()
		macau_guide_requested.emit()
	)
	add_child(guide_btn)

	var can_charge := GameState.at_phone_preparation()
	charge_button = _make_desk_button("⚡ 接电充能", Vector2(452, 246), Vector2(138, 26), Color("223b2e"))
	charge_button.disabled = not can_charge
	charge_button.visible = can_charge
	charge_button.pressed.connect(func():
		GameState.recharge_preparation()
		_refresh_battery()
		queue_redraw()
	)
	add_child(charge_button)

	var reduce := CheckButton.new()
	reduce.position = Vector2(442, 282)
	reduce.size = Vector2(156, 26)
	reduce.text = "减弱强闪画面"
	reduce.add_theme_font_size_override("font_size", 11)
	reduce.add_theme_color_override("font_color", Color("d2d6c6"))
	reduce.button_pressed = GameState.reduced_flash
	reduce.toggled.connect(GameState.set_reduced_flash)
	add_child(reduce)

	# === INSIDE VERTICAL PHONE SCREEN (SCREEN_RECT = 221, 24, 176x276) ===
	status_clock_label = Label.new()
	status_clock_label.text = "23:42"
	status_clock_label.position = Vector2(SCREEN_RECT.position.x + 62, SCREEN_RECT.position.y + 3)
	status_clock_label.size = Vector2(52, 14)
	status_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_clock_label.add_theme_font_size_override("font_size", 10)
	status_clock_label.add_theme_color_override("font_color", Color("e4eae2"))
	add_child(status_clock_label)

	status_bat_label = Label.new()
	status_bat_label.position = Vector2(SCREEN_RECT.end.x - 54, SCREEN_RECT.position.y + 3)
	status_bat_label.size = Vector2(36, 14)
	status_bat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_bat_label.add_theme_font_size_override("font_size", 9)
	status_bat_label.add_theme_color_override("font_color", Color("cce0cf"))
	add_child(status_bat_label)

	# Home Screen: Interactive WeChat Lock/Push Banner
	var push_btn := Button.new()
	push_btn.position = Vector2(SCREEN_RECT.position.x + 8, SCREEN_RECT.position.y + 24)
	push_btn.size = Vector2(SCREEN_RECT.size.x - 16, 46)
	push_btn.focus_mode = Control.FOCUS_NONE
	push_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	push_btn.text = ""
	_style_transparent_tile(push_btn, Color(0.18, 0.11, 0.12, 0.88), Color("9a4c44"))
	push_btn.pressed.connect(func(): _switch_app("wechat"))
	add_child(push_btn)
	home_nodes.append(push_btn)

	var push_lbl := Label.new()
	push_lbl.text = "微信 · 嘉敏 [未发出]\n「铁床后真是大三巴暗道…」"
	push_lbl.position = Vector2(6, 5)
	push_lbl.size = Vector2(push_btn.size.x - 12, 36)
	push_lbl.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	push_lbl.add_theme_font_size_override("font_size", 9)
	push_lbl.add_theme_color_override("font_color", Color("f2d5cb"))
	push_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	push_btn.add_child(push_lbl)

	# 2x3 Smartphone App Icon Grid (Direct Button children of phone so modal_regression_088 & tests find them cleanly!)
	var apps := [
		{"id": "wechat", "text": "微信", "short": "微信", "icon": "chat", "color": Color("2a7a4b"), "badge": "2", "cb": func(): _switch_app("wechat")},
		{"id": "shoe", "text": "原有照片 · 鞋底维修", "short": "靴子订单", "icon": "photo", "color": Color("7d5c32"), "badge": "", "cb": _show_shoe_photo},
		{"id": "map", "text": "路线图", "short": "澳门地图", "icon": "map", "color": Color("2e5f6e"), "badge": "", "cb": func(): map_requested.emit()},
		{"id": "journal", "text": "线索档案", "short": "线索档案", "icon": "journal", "color": Color("5f4636"), "badge": "", "cb": func(): journal_requested.emit()},
		{"id": "bag", "text": "随身背包", "short": "随身背包", "icon": "bag", "color": Color("465a3c"), "badge": "", "cb": func(): bag_requested.emit()},
		{"id": "meter", "text": "声强表", "short": "声强仪", "icon": "meter", "color": Color("2d4e46"), "badge": "", "cb": _show_noise_meter, "name": "NoiseMeter"}
	]
	var col_w := 50.0
	var row_h := 58.0
	var start_x := SCREEN_RECT.position.x + 11.0
	var start_y := SCREEN_RECT.position.y + 82.0
	for i in range(apps.size()):
		var a: Dictionary = apps[i]
		var col := i % 3
		var row := i / 3
		var at := Vector2(start_x + col * (col_w + 2.0), start_y + row * (row_h + 6.0))
		var btn := Button.new()
		btn.text = a.text
		btn.clip_text = true
		if a.has("name"):
			btn.name = a.name
		btn.position = at
		btn.size = Vector2(col_w, row_h)
		btn.custom_minimum_size = Vector2(col_w, row_h)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		# Hide raw long text visually (we render crisp smartphone icon + short app caption in _draw!)
		btn.add_theme_color_override("font_color", Color(0, 0, 0, 0))
		btn.add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
		btn.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
		_style_app_hitbox(btn)
		btn.pressed.connect(a.cb)
		add_child(btn)
		home_nodes.append(btn)
		app_buttons.append({"btn": btn, "rect": Rect2(at, btn.size), "short": a.short, "icon": a.icon, "color": a.color, "badge": a.badge})

	# Bottom Smartphone Flash Widget strip inside vertical screen
	var flash_strip := Label.new()
	flash_strip.name = "PhoneScreenFlashStrip"
	flash_strip.position = Vector2(SCREEN_RECT.position.x + 10, SCREEN_RECT.end.y - 54)
	flash_strip.size = Vector2(SCREEN_RECT.size.x - 20, 32)
	flash_strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flash_strip.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	flash_strip.add_theme_font_size_override("font_size", 9)
	flash_strip.add_theme_color_override("font_color", Color("e9cf86"))
	flash_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_strip)
	home_nodes.append(flash_strip)

	# Build Vertical WeChat App View (hidden until tapping WeChat icon or push banner)
	_build_wechat_view()
	_refresh_battery()

func _build_wechat_view() -> void:
	wechat_container = Control.new()
	wechat_container.position = Vector2(SCREEN_RECT.position.x + 2, SCREEN_RECT.position.y + 18)
	wechat_container.size = Vector2(SCREEN_RECT.size.x - 4, SCREEN_RECT.size.y - 22)
	wechat_container.hide()
	add_child(wechat_container)

	var top_bar := ColorRect.new()
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(wechat_container.size.x, 24)
	top_bar.color = Color("141d19")
	wechat_container.add_child(top_bar)

	var back_btn := _make_desk_button("< 返回", Vector2(3, 3), Vector2(40, 18), Color("1d2e26"))
	back_btn.add_theme_font_size_override("font_size", 9)
	back_btn.pressed.connect(func(): _switch_app("home"))
	wechat_container.add_child(back_btn)

	var chat_title := Label.new()
	chat_title.text = "微信 · 离线记录"
	chat_title.position = Vector2(48, 5)
	chat_title.size = Vector2(120, 16)
	chat_title.add_theme_font_size_override("font_size", 9)
	chat_title.add_theme_color_override("font_color", Color("e4dec6"))
	wechat_container.add_child(chat_title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(4, 28)
	scroll.size = Vector2(wechat_container.size.x - 8, wechat_container.size.y - 32)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	wechat_container.add_child(scroll)

	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(scroll.size.x - 10, 0)
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	_add_vertical_chat_bubble(list, scroll.size.x - 12, ahhao_tex, "阿豪 · 14:18", "姐，金巴票订好啦！我先去拱北取补光灯和备用镜头，大三巴街口碰头！", false)
	_add_vertical_chat_bubble(list, scroll.size.x - 12, jiamin_tex, "嘉敏 · 22:41 [未发出]", "大文！铁床后真是通往大三巴地底的暗道！里面有人在敲「两短一长」，我进去看一眼！", true)
	_add_vertical_chat_bubble(list, scroll.size.x - 12, jiamin_tex, "通话 · 22:44 [失败]", "拨打「陈大文」失败：无蜂窝网络信号（手机遗落于 304 地板）", true)

func _add_vertical_chat_bubble(parent: Node, w: float, avatar_tex: Texture2D, sender: String, msg: String, unsent: bool) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(w, 0)
	var st := StyleBoxFlat.new()
	st.bg_color = Color("261719") if unsent else Color("16241d")
	st.border_color = Color("8c453e") if unsent else Color("385446")
	st.set_border_width_all(1)
	st.set_corner_radius_all(4)
	st.content_margin_left = 5
	st.content_margin_right = 5
	st.content_margin_top = 4
	st.content_margin_bottom = 5
	card.add_theme_stylebox_override("panel", st)
	parent.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	card.add_child(vbox)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 5)
	vbox.add_child(head)

	if avatar_tex != null:
		var av := TextureRect.new()
		av.texture = avatar_tex
		av.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		av.custom_minimum_size = Vector2(18, 20)
		head.add_child(av)

	var who := Label.new()
	who.text = sender
	who.add_theme_font_size_override("font_size", 9)
	who.add_theme_color_override("font_color", Color("f29a8d") if unsent else Color("e0ca8b"))
	head.add_child(who)

	var body := Label.new()
	body.text = msg
	body.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	body.add_theme_font_size_override("font_size", 9)
	body.add_theme_color_override("font_color", Color("e4e8d8"))
	vbox.add_child(body)

func _switch_app(next_app: String) -> void:
	active_app = next_app
	AudioManager.play_dialogue_advance()
	for n in home_nodes:
		if is_instance_valid(n):
			n.visible = (active_app == "home")
	if is_instance_valid(wechat_container):
		wechat_container.visible = (active_app == "wechat")
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Clicking the physical Home button at the bottom of jiamin_phone_011.png returns to Home Screen!
		if HOME_BTN_RECT.has_point(event.position):
			if close_subview():
				AudioManager.play_effect("click")
				accept_event()
				return
			if active_app != "home":
				_switch_app("home")
				accept_event()
				return

func hud_jiamin_portrait() -> Texture2D:
	if ResourceLoader.exists("res://assets/ui/jiamin_expressions_v10.png"):
		var a := AtlasTexture.new()
		a.atlas = load("res://assets/ui/jiamin_expressions_v10.png")
		a.region = Rect2(0, 0, a.atlas.get_width() / 3.0, a.atlas.get_height() / 2.0)
		return a
	if ResourceLoader.exists("res://assets/characters/jiamin_006.png"):
		var atlas := AtlasTexture.new()
		atlas.atlas = load("res://assets/characters/jiamin_006.png")
		atlas.region = Rect2(274, 13, 247, 309)
		return atlas
	return null

func _style_transparent_tile(btn: Button, bg: Color, border: Color) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = bg
	n.border_color = border
	n.set_border_width_all(1)
	n.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", n)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = bg.lightened(0.14)
	h.border_color = Color("f0cf88")
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)

func _style_app_hitbox(btn: Button) -> void:
	var n := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", n)
	var h := StyleBoxFlat.new()
	h.bg_color = Color(1.0, 0.96, 0.84, 0.11)
	h.border_color = Color("e8d290", 0.55)
	h.set_border_width_all(1)
	h.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)

func _make_desk_button(caption: String, at: Vector2, sz: Vector2, bg: Color) -> Button:
	var btn := Button.new()
	btn.text = caption
	btn.position = at
	btn.size = sz
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color("e7ebd8"))
	btn.add_theme_color_override("font_hover_color", Color("f4df9b"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = Color("6b7867")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.18)
	hover.border_color = Color("e3cd8b")
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	return btn

func _draw_app_icon(icon_type: String, icon_rect: Rect2, base_col: Color) -> void:
	# Drop shadow + tactile rounded-square smartphone app icon tile with real miniature textures & glossy glass bevel
	draw_rect(Rect2(icon_rect.position + Vector2(1, 2), icon_rect.size), Color(0, 0, 0, 0.55))
	draw_rect(icon_rect, base_col)
	var inner := Rect2(icon_rect.position + Vector2(2, 2), icon_rect.size - Vector2(4, 4))
	var c := icon_rect.get_center()
	var fg := Color("f5f3e8")
	match icon_type:
		"chat":
			draw_rect(inner, Color("208b46"))
			draw_circle(c + Vector2(-4, -2), 8.2, Color("f5fbf6"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-10, 3), c + Vector2(-12, 8), c + Vector2(-5, 5)]), Color("f5fbf6"))
			draw_circle(c + Vector2(5, 3), 6.2, Color("b4f0c5"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(8, 7), c + Vector2(11, 10), c + Vector2(5, 8)]), Color("b4f0c5"))
			draw_circle(c + Vector2(-6.5, -2.5), 1.4, Color("196b36"))
			draw_circle(c + Vector2(-2.0, -2.5), 1.4, Color("196b36"))
			draw_circle(c + Vector2(3.5, 3.0), 1.1, Color("196b36"))
			draw_circle(c + Vector2(6.8, 3.0), 1.1, Color("196b36"))
		"photo":
			if shoe_tex != null:
				draw_texture_rect(shoe_tex, inner, false)
			draw_rect(inner, Color(1, 0.95, 0.85, 0.15), false, 1.0)
			draw_circle(icon_rect.position + Vector2(26, 8), 3.0, Color("ffe082"))
		"map":
			var map_t := DemoItems.texture("trip_map")
			if map_t != null:
				draw_texture_rect(map_t, inner, false)
			draw_circle(c + Vector2(0, -2), 4.8, Color("e64238"))
			draw_circle(c + Vector2(0, -2), 1.8, Color.WHITE)
		"journal":
			var j_t := DemoItems.texture("old_304_photo")
			if j_t != null:
				draw_texture_rect(j_t, inner, false, Color(0.82, 0.74, 0.60, 0.88))
			draw_rect(Rect2(c - Vector2(7, 9), Vector2(14, 18)), Color("f6ebd2"), false, 1.4)
			draw_line(c + Vector2(-3, -9), c + Vector2(-3, 9), Color("e0c282"), 1.2)
			draw_line(c + Vector2(0, -3), c + Vector2(5, -3), fg, 1.2)
			draw_line(c + Vector2(0, 1), c + Vector2(5, 1), fg, 1.2)
		"bag":
			var b_t := DemoItems.texture("multitool_pliers")
			if b_t != null:
				draw_texture_rect(b_t, inner, false, Color(0.85, 0.88, 0.80, 0.72))
			draw_rect(Rect2(c - Vector2(8, 4), Vector2(16, 12)), fg, false, 1.4)
			draw_arc(c + Vector2(0, -4), 4.5, PI, TAU, 12, fg, 1.4, true)
			draw_rect(Rect2(c + Vector2(-2, -1), Vector2(4, 3)), Color("f5d478"))
		"meter":
			draw_rect(inner, Color("10221d"))
			var heights := [5.0, 11.0, 17.0, 9.0, 14.0, 7.0]
			for k in range(heights.size()):
				var bx := c.x - 10.0 + k * 4.0
				var h_col := Color("62e894") if heights[k] < 13.0 else Color("f2c968")
				draw_line(Vector2(bx, c.y + 8.0), Vector2(bx, c.y + 8.0 - heights[k]), h_col, 2.2)
	# Glossy top-half glass sheen & metallic app border
	draw_rect(Rect2(icon_rect.position, Vector2(icon_rect.size.x, icon_rect.size.y * 0.44)), Color(1, 1, 1, 0.14))
	draw_rect(icon_rect, base_col.lightened(0.42), false, 1.1)

func _draw() -> void:
	var font := get_theme_default_font()
	var sz := size if size.x > 10.0 else Vector2(618.0, 330.0)
	draw_rect(Rect2(Vector2.ZERO, sz), Color("070908"))

	# 1. Draw the authentic painted vertical cracked-glass smartphone on the Macau wooden desk
	if phone_bg != null:
		draw_texture_rect(phone_bg, BG_DST, false)

	# Polished dark titanium phone chassis frame & physical side volume/power buttons around screen
	var chassis := SCREEN_RECT.grow_individual(7.0, 14.0, 7.0, 22.0)
	draw_rect(chassis.grow(1.5), Color(0.03, 0.04, 0.038, 0.72), false, 2.0)
	draw_rect(chassis, Color(0.18, 0.21, 0.20, 0.85), false, 1.4)
	# Side buttons (left volume rocker + right power key)
	draw_rect(Rect2(chassis.position.x - 2.5, chassis.position.y + 44, 2.5, 22), Color("4f5954"))
	draw_rect(Rect2(chassis.position.x - 2.5, chassis.position.y + 72, 2.5, 22), Color("4f5954"))
	draw_rect(Rect2(chassis.end.x, chassis.position.y + 56, 2.5, 28), Color("5c665f"))

	# 2. Inner OLED screen with moody twilight Macau wallpaper, subtle scan sheen & punch-hole/earpiece notch
	draw_rect(SCREEN_RECT, Color(0.032, 0.052, 0.048, 0.99))
	var wp_tex := DemoItems.texture("old_304_photo")
	if wp_tex != null:
		draw_texture_rect(wp_tex, SCREEN_RECT, false, Color(0.20, 0.29, 0.27, 0.36))
	# Vertical ambient OLED twilight gradient
	draw_rect(Rect2(SCREEN_RECT.position, Vector2(SCREEN_RECT.size.x, SCREEN_RECT.size.y * 0.45)), Color(0.06, 0.11, 0.10, 0.24))
	# Top dynamic island / speaker mesh & sapphire selfie camera iris
	var isl := Rect2(SCREEN_RECT.get_center().x - 24.0, SCREEN_RECT.position.y - 8.5, 48.0, 8.0)
	draw_rect(isl, Color(0.03, 0.04, 0.038, 0.98))
	draw_rect(isl, Color("2e3a34"), false, 0.8)
	draw_rect(Rect2(isl.position.x + 8.0, isl.position.y + 2.8, 20.0, 2.2), Color(0.14, 0.17, 0.16, 0.92))
	draw_circle(Vector2(isl.end.x - 7.5, isl.get_center().y), 2.3, Color(0.10, 0.20, 0.28, 0.95))
	draw_circle(Vector2(isl.end.x - 8.0, isl.get_center().y - 0.5), 0.7, Color("72b8d8", 0.75))
	# Top OLED status bar
	draw_rect(Rect2(SCREEN_RECT.position, Vector2(SCREEN_RECT.size.x, 18.0)), Color(0.018, 0.03, 0.028, 0.94))
	draw_line(Vector2(SCREEN_RECT.position.x, SCREEN_RECT.position.y + 18.0), Vector2(SCREEN_RECT.end.x, SCREEN_RECT.position.y + 18.0), Color("2f453c"), 1.0)

	# Status bar icons: CTM No Service signal steps + mini capsule battery gauge
	var sx := SCREEN_RECT.position.x + 6.0
	var sy := SCREEN_RECT.position.y + 12.5
	for b in range(4):
		draw_rect(Rect2(sx + b * 3.0, sy - (2.5 + b * 1.5), 2.0, 2.5 + b * 1.5), Color("46524e"))
	draw_string(font, Vector2(sx + 14.0, sy), "CTM · 无服务", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("df7b70"))
	var bat_x := SCREEN_RECT.end.x - 18.0
	var bat_y := SCREEN_RECT.position.y + 5.5
	draw_rect(Rect2(bat_x, bat_y, 13.0, 7.0), Color("88a392"), false, 1.0)
	draw_rect(Rect2(bat_x + 13.0, bat_y + 2.0, 1.5, 3.0), Color("88a392"))
	var fill := clampf(GameState.phone_battery / 100.0, 0.0, 1.0) * 10.0
	draw_rect(Rect2(bat_x + 1.5, bat_y + 1.5, fill, 4.0), Color("6fe08b") if GameState.phone_battery > 25.0 else Color("e56352"))

	# 3. Home screen app icons & translucent frosted iOS/Harmony dock
	if active_app == "home":
		for item in app_buttons:
			var r: Rect2 = item.rect
			var icon_rect := Rect2(r.position.x + 8.0, r.position.y + 4.0, 34.0, 34.0)
			_draw_app_icon(item.icon, icon_rect, item.color)
			var badge: String = item.badge
			if not badge.is_empty():
				var bp := Vector2(icon_rect.end.x - 1.5, icon_rect.position.y + 1.5)
				draw_circle(bp, 6.8, Color("e03c34"))
				draw_arc(bp, 6.8, 0.0, TAU, 16, Color("101815"), 0.8)
				draw_string(font, bp + Vector2(-2.6, 3.2), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
			var lbl: String = item.short
			draw_string(font, Vector2(r.position.x, r.position.y + 51.0), lbl, HORIZONTAL_ALIGNMENT_CENTER, int(r.size.x), 9, Color("eef1e4"))

		var dock_rect := Rect2(SCREEN_RECT.position.x + 7, SCREEN_RECT.end.y - 59, SCREEN_RECT.size.x - 14, 44)
		draw_rect(dock_rect, Color(0.08, 0.14, 0.12, 0.88))
		draw_rect(dock_rect, Color("5a7365", 0.72), false, 1.0)
		draw_line(dock_rect.position + Vector2(2, 1), Vector2(dock_rect.end.x - 2, dock_rect.position.y + 1), Color(1, 1, 1, 0.12), 1.0)

	# Bottom home swipe bar & subtle cracked glass diagonal specular lines
	draw_rect(Rect2(SCREEN_RECT.get_center().x - 26.0, SCREEN_RECT.end.y - 7.0, 52.0, 2.5), Color("7b9085", 0.90))
	draw_line(SCREEN_RECT.position + Vector2(126, 2), SCREEN_RECT.position + Vector2(174, 48), Color(0.88, 0.95, 0.92, 0.10), 1.1)
	draw_line(SCREEN_RECT.position + Vector2(142, 4), SCREEN_RECT.position + Vector2(176, 34), Color(0.88, 0.95, 0.92, 0.06), 0.8)

func _refresh_battery() -> void:
	var pct := roundi(GameState.phone_battery)
	if is_instance_valid(battery_status):
		battery_status.text = "电量 %d%% · 强闪 %d / 2 次" % [pct, GameState.phone_flash_charges]
	if is_instance_valid(status_bat_label):
		status_bat_label.text = "%d%%" % pct
	var strip := get_node_or_null("PhoneScreenFlashStrip") as Label
	if is_instance_valid(strip):
		strip.text = "[R] 手机强闪：%d / 2 次\n电量 %d%% · 击退眩晕恶灵" % [GameState.phone_flash_charges, pct]

func _apply_cover_skin(cover: PanelContainer) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.075, 0.065, 0.97)
	s.border_color = Color("a89666")
	s.set_border_width_all(1)
	s.set_corner_radius_all(5)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	cover.add_theme_stylebox_override("panel", s)

func _show_shoe_photo() -> void:
	if is_instance_valid(photo_cover) or is_instance_valid(meter_cover):
		return
	GameState.take_demo_item("shoe_repair_photo")
	var cover := PanelContainer.new()
	photo_cover = cover
	cover.position = Vector2(24, 22)
	cover.size = Vector2(570, 272)
	_apply_cover_skin(cover)
	add_child(cover)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	cover.add_child(column)
	var image := TextureRect.new()
	image.texture = DemoItems.texture("shoe_repair_photo")
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(548, 198)
	column.add_child(image)
	var note := Label.new()
	note.text = "网购订单实拍 · 大文以前帮嘉敏网购的 37 码户外靴订单截图与鞋底图：斜人字纹，右跟边缘有一处三角缺角。"
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color("e4dec8"))
	column.add_child(note)
	var back := _make_desk_button("返回手机主屏", Vector2.ZERO, Vector2(118, 26), Color("162721"))
	back.custom_minimum_size = Vector2(118, 26)
	back.pressed.connect(_close_shoe_photo)
	column.add_child(back)

func _close_shoe_photo() -> void:
	if is_instance_valid(photo_cover):
		photo_cover.queue_free()
	photo_cover = null

func _show_noise_meter() -> void:
	if is_instance_valid(meter_cover) or is_instance_valid(photo_cover):
		return
	var cover := PanelContainer.new()
	meter_cover = cover
	cover.position = Vector2(138, 36)
	cover.size = Vector2(342, 246)
	_apply_cover_skin(cover)
	add_child(cover)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	cover.add_child(column)
	var title := Label.new()
	title.text = "相对声强表 · 游戏内近距声响记录"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color("e6d49c"))
	column.add_child(title)
	var note := Label.new()
	note.text = "查看手机时世界暂停；返回世界后实时监测脚步、水声与金属异响。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", Color("b8cabd"))
	column.add_child(note)
	var history := Label.new()
	history.name = "NoiseHistory"
	history.text = "\n".join(recent_noise) if not recent_noise.is_empty() else "刚才附近没有明显声响。"
	history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history.add_theme_font_size_override("font_size", 11)
	history.add_theme_color_override("font_color", Color("e5ebd8"))
	column.add_child(history)
	var live := CheckButton.new()
	live.name = "LiveNoise"
	live.text = "返回世界时开启临时声强提示"
	live.add_theme_font_size_override("font_size", 11)
	live.button_pressed = live_noise_enabled
	live.toggled.connect(func(enabled: bool):
		live_noise_enabled = enabled
		live_noise_toggled.emit(enabled)
	)
	column.add_child(live)
	var back := _make_desk_button("返回手机主屏", Vector2.ZERO, Vector2(118, 26), Color("162721"))
	back.custom_minimum_size = Vector2(118, 26)
	back.pressed.connect(_close_noise_meter)
	column.add_child(back)

func _close_noise_meter() -> void:
	if is_instance_valid(meter_cover):
		meter_cover.queue_free()
	meter_cover = null

func close_subview() -> bool:
	if is_instance_valid(photo_cover):
		_close_shoe_photo()
		return true
	if is_instance_valid(meter_cover):
		_close_noise_meter()
		return true
	if active_app != "home":
		_switch_app("home")
		return true
	return false
