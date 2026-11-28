extends Control

# Stylish 60% mechanical keyboard diagram with non-overlapping angled brass callout leader lines
# pointing directly from each active keycap to its gameplay function badge.
const FULL_ROWS := [
	[
		{"l": "Esc", "w": 21, "c": KEY_ESCAPE, "hi": true},
		{"l": "1", "w": 16, "c": KEY_1, "hi": false},
		{"l": "2", "w": 16, "c": KEY_2, "hi": false},
		{"l": "3", "w": 16, "c": KEY_3, "hi": false},
		{"l": "4", "w": 16, "c": KEY_4, "hi": false},
		{"l": "5", "w": 16, "c": KEY_5, "hi": false},
		{"l": "6", "w": 16, "c": KEY_6, "hi": false},
		{"l": "7", "w": 16, "c": KEY_7, "hi": false},
		{"l": "8", "w": 16, "c": KEY_8, "hi": false},
		{"l": "9", "w": 16, "c": KEY_9, "hi": false},
		{"l": "0", "w": 16, "c": KEY_0, "hi": false},
		{"l": "-", "w": 16, "c": KEY_MINUS, "hi": false},
		{"l": "=", "w": 16, "c": KEY_EQUAL, "hi": false},
		{"l": "←", "w": 27, "c": KEY_BACKSPACE, "hi": false}
	],
	[
		{"l": "Tab", "w": 26, "c": KEY_TAB, "hi": true},
		{"l": "Q", "w": 17, "c": KEY_Q, "hi": true},
		{"l": "W", "w": 17, "c": KEY_W, "hi": true},
		{"l": "E", "w": 17, "c": KEY_E, "hi": true},
		{"l": "R", "w": 17, "c": KEY_R, "hi": true},
		{"l": "T", "w": 17, "c": KEY_T, "hi": false},
		{"l": "Y", "w": 17, "c": KEY_Y, "hi": false},
		{"l": "U", "w": 17, "c": KEY_U, "hi": false},
		{"l": "I", "w": 17, "c": KEY_I, "hi": false},
		{"l": "O", "w": 17, "c": KEY_O, "hi": false},
		{"l": "P", "w": 17, "c": KEY_P, "hi": false},
		{"l": "[", "w": 16, "c": KEY_BRACELEFT, "hi": false},
		{"l": "]", "w": 16, "c": KEY_BRACERIGHT, "hi": false},
		{"l": "\\", "w": 19, "c": KEY_BACKSLASH, "hi": false}
	],
	[
		{"l": "Caps", "w": 29, "c": KEY_CAPSLOCK, "hi": false},
		{"l": "A", "w": 17, "c": KEY_A, "hi": true},
		{"l": "S", "w": 17, "c": KEY_S, "hi": true},
		{"l": "D", "w": 17, "c": KEY_D, "hi": true},
		{"l": "F", "w": 17, "c": KEY_F, "hi": true},
		{"l": "G", "w": 17, "c": KEY_G, "hi": false},
		{"l": "H", "w": 17, "c": KEY_H, "hi": true},
		{"l": "J", "w": 17, "c": KEY_J, "hi": true},
		{"l": "K", "w": 17, "c": KEY_K, "hi": false},
		{"l": "L", "w": 17, "c": KEY_L, "hi": false},
		{"l": ";", "w": 16, "c": KEY_SEMICOLON, "hi": false},
		{"l": "'", "w": 16, "c": KEY_APOSTROPHE, "hi": false},
		{"l": "Enter", "w": 34, "c": KEY_ENTER, "hi": false}
	],
	[
		{"l": "Shift", "w": 36, "c": KEY_SHIFT, "hi": true},
		{"l": "Z", "w": 17, "c": KEY_Z, "hi": false},
		{"l": "X", "w": 17, "c": KEY_X, "hi": false},
		{"l": "C", "w": 17, "c": KEY_C, "hi": true},
		{"l": "V", "w": 17, "c": KEY_V, "hi": false},
		{"l": "B", "w": 17, "c": KEY_B, "hi": true},
		{"l": "N", "w": 17, "c": KEY_N, "hi": false},
		{"l": "M", "w": 17, "c": KEY_M, "hi": true},
		{"l": ",", "w": 16, "c": KEY_COMMA, "hi": false},
		{"l": ".", "w": 16, "c": KEY_PERIOD, "hi": false},
		{"l": "/", "w": 16, "c": KEY_SLASH, "hi": false},
		{"l": "Shift", "w": 43, "c": KEY_SHIFT, "hi": false}
	],
	[
		{"l": "Ctrl", "w": 28, "c": KEY_CTRL, "hi": true},
		{"l": "Win", "w": 21, "c": KEY_META, "hi": false},
		{"l": "Alt", "w": 21, "c": KEY_ALT, "hi": false},
		{"l": "Space", "w": 108, "c": KEY_SPACE, "hi": true},
		{"l": "Alt", "w": 22, "c": KEY_ALT, "hi": false},
		{"l": "Fn", "w": 22, "c": KEY_META, "hi": false},
		{"l": "Ctrl", "w": 30, "c": KEY_CTRL, "hi": false}
	]
]


var _touch_buttons: Array[Button] = []
var _btn_auto_sprint: Button
var _btn_scale: Button
var _btn_pref_mode: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS if GameState.touch_mode_active else Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_touch_controls()


func _build_touch_controls() -> void:
	_btn_auto_sprint = _make_touch_btn(Vector2(308, 22), Vector2(180, 26))
	_btn_auto_sprint.pressed.connect(func():
		GameState.set_touch_auto_sprint(not GameState.touch_auto_sprint)
		_refresh_touch_labels()
	)
	_btn_scale = _make_touch_btn(Vector2(308, 56), Vector2(180, 26))
	_btn_scale.pressed.connect(func():
		var next := 1.15 if is_equal_approx(GameState.touch_scale, 1.0) else (0.85 if GameState.touch_scale > 1.05 else 1.0)
		GameState.set_touch_scale(next)
		_refresh_touch_labels()
	)
	_btn_pref_mode = _make_touch_btn(Vector2(308, 90), Vector2(180, 26))
	_btn_pref_mode.pressed.connect(func():
		var order := ["auto", "on", "off"]
		var idx := (order.find(GameState.touch_controls_preference) + 1) % order.size()
		GameState.set_touch_controls_preference(order[idx])
		_refresh_touch_labels()
	)
	_refresh_touch_labels()


func _make_touch_btn(at: Vector2, sz: Vector2) -> Button:
	var btn := Button.new()
	btn.position = at
	btn.size = sz
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", Color("f6e4aa"))
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.075, 0.135, 0.105, 0.96)
	st.border_color = Color("b89c58")
	st.set_border_width_all(1)
	st.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", st)
	var hv := st.duplicate() as StyleBoxFlat
	hv.bg_color = Color(0.14, 0.25, 0.19, 0.98)
	hv.border_color = Color("ffe6a0")
	btn.add_theme_stylebox_override("hover", hv)
	btn.add_theme_stylebox_override("pressed", hv)
	add_child(btn)
	_touch_buttons.append(btn)
	return btn


func _refresh_touch_labels() -> void:
	var active := GameState.touch_mode_active
	mouse_filter = Control.MOUSE_FILTER_PASS if active else Control.MOUSE_FILTER_IGNORE
	for btn in _touch_buttons:
		btn.visible = active
	if is_instance_valid(_btn_auto_sprint):
		_btn_auto_sprint.text = "方向盘推满冲刺：" + ("开" if GameState.touch_auto_sprint else "关")
	if is_instance_valid(_btn_scale):
		var sz_name := "小" if GameState.touch_scale < 0.95 else ("大" if GameState.touch_scale > 1.05 else "中")
		_btn_scale.text = "触屏按键尺寸：" + sz_name
	if is_instance_valid(_btn_pref_mode):
		var mode_labels := {"auto": "自动识别", "on": "始终显示", "off": "隐藏"}
		var mode_name := str(mode_labels.get(GameState.touch_controls_preference, "自动识别"))
		_btn_pref_mode.text = "触屏按键显示：" + mode_name


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		queue_redraw()


func _draw_callout_right(font: Font, src: Vector2, gutter_y: float, elbow_x: float, dst_y: float, tag_col: Color, key_name: String, fn_text: String) -> void:
	var pts := PackedVector2Array([
		src,
		Vector2(src.x, gutter_y),
		Vector2(elbow_x, gutter_y),
		Vector2(elbow_x, dst_y),
		Vector2(308.0, dst_y),
	])
	draw_polyline(pts, Color(tag_col.r, tag_col.g, tag_col.b, 0.88), 1.15, true)
	draw_circle(src, 2.2, tag_col)
	draw_circle(Vector2(308.0, dst_y), 2.0, tag_col)
	var pill := Rect2(310.0, dst_y - 7.5, 180.0, 15.0)
	draw_rect(pill, Color(0.055, 0.095, 0.078, 0.94))
	draw_rect(pill, Color(tag_col.r, tag_col.g, tag_col.b, 0.65), false, 0.9)
	draw_string(font, Vector2(314.0, dst_y + 3.2), key_name, HORIZONTAL_ALIGNMENT_LEFT, 48, 8, Color("f6e4aa"))
	draw_string(font, Vector2(362.0, dst_y + 3.2), fn_text, HORIZONTAL_ALIGNMENT_LEFT, 124, 9, Color("dae5d4"))


func _draw_callout_top(font: Font, src: Vector2, dst: Vector2, label_txt: String, col: Color) -> void:
	var knee := Vector2(dst.x + 28.0, src.y - 6.0)
	draw_polyline(PackedVector2Array([src, Vector2(src.x, knee.y), Vector2(dst.x + 28.0, dst.y + 13.0)]), Color(col.r, col.g, col.b, 0.82), 1.1, true)
	draw_circle(src, 2.2, col)
	var box := Rect2(dst.x, dst.y, 62.0, 13.0)
	draw_rect(box, Color(0.055, 0.095, 0.078, 0.92))
	draw_rect(box, Color(col.r, col.g, col.b, 0.72), false, 0.9)
	draw_string(font, Vector2(dst.x + 2.0, dst.y + 9.5), label_txt, HORIZONTAL_ALIGNMENT_CENTER, 58, 8, Color("f3e5b4"))


func _draw() -> void:
	var font := get_theme_default_font()
	var panel_w := size.x if size.x > 100.0 else 498.0
	var panel_h := size.y if size.y > 80.0 else 156.0

	# Recessed dark-emerald brass-trimmed hardware plaque
	draw_rect(Rect2(0, 0, panel_w, panel_h), Color(0.032, 0.056, 0.046, 0.96))
	draw_rect(Rect2(0, 0, panel_w, panel_h), Color("889474", 0.82), false, 1.0)

	if GameState.touch_mode_active:
		_refresh_touch_labels()
		draw_string(font, Vector2(14, 18), "移动端触屏操作说明与偏好设置", HORIZONTAL_ALIGNMENT_LEFT, 280, 11, Color("f6e4aa"))
		var card := Rect2(12, 24, 282, 112)
		draw_rect(card, Color(0.05, 0.085, 0.072, 0.96))
		draw_rect(card, Color("6c7a5f", 0.85), false, 1.0)
		var lines := [
			"• 左半屏方向盘：360° 移动（推到外圈自动冲刺）",
			"• 右半屏空白处划动：独立转动手电照向",
			"• 右下主按键：调查 / 开门 / 进柜屏息 / 拍照快门",
			"• 右手常用键：开关手电 / 蹲行 / 强闪驱鬼",
			"• 顶部功能栏：手机图鉴 / 背包 / 地图 / 笔记 / 提示",
			"• 对话翻页：轻触对话框任意位置即可继续",
		]
		for i in range(lines.size()):
			draw_string(font, Vector2(20, 42 + i * 16), lines[i], HORIZONTAL_ALIGNMENT_LEFT, 268, 9, Color("dfe6d2"))
		draw_string(font, Vector2(308, 132), "提示：竖屏时画面自动置顶不遮挡", HORIZONTAL_ALIGNMENT_LEFT, 180, 9, Color("a9baa7"))
		return
	_refresh_touch_labels()

	var kb_rect := Rect2(12, 24, 282, 95)
	draw_rect(Rect2(kb_rect.position + Vector2(0, 2), kb_rect.size), Color(0.01, 0.015, 0.012, 0.95))
	draw_rect(kb_rect, Color(0.058, 0.09, 0.076, 0.98))
	draw_rect(kb_rect, Color("5c6e5b", 0.92), false, 1.2)

	var centers: Dictionary = {}
	var ry := 29.0
	var kh := 15.0
	for r_idx in range(FULL_ROWS.size()):
		var cx := 16.0
		var row: Array = FULL_ROWS[r_idx]
		for k in row:
			var kw := float(k["w"])
			var code := int(k["c"])
			var hi: bool = k["hi"]
			var pressed := Input.is_key_pressed(code) and hi
			var r := Rect2(cx, ry + (1.2 if pressed else 0.0), kw, kh)
			if not pressed:
				draw_rect(Rect2(cx, ry + 1.6, kw, kh), Color(0.012, 0.02, 0.016, 0.95))
			var bg := Color("efd075") if pressed else (Color("2e2514") if hi else Color("111b17"))
			var bd := Color("fff5c8") if pressed else (Color("ddb862") if hi else Color("2a3a31"))
			var fg := Color("121814") if pressed else (Color("fae5a2") if hi else Color("53665a"))
			draw_rect(r, bg)
			draw_rect(r, bd, false, 1.2 if hi else 0.85)
			if hi and not pressed:
				draw_line(r.position + Vector2(1, 1), Vector2(r.end.x - 1, r.position.y + 1), Color(1.0, 0.92, 0.68, 0.25), 1.0)
			var lbl: String = k["l"]
			draw_string(font, r.position + Vector2(1.0, 10.8), lbl, HORIZONTAL_ALIGNMENT_CENTER, int(kw) - 2, 8 if lbl.length() <= 3 else 7, fg)
			if hi and not centers.has(lbl):
				centers[lbl] = r.get_center()
			cx += kw + 2.0
		ry += 17.5

	# Top tidy callouts pointing straight down to Esc, Q, W/ASD, E, R without touching right-hand lane
	var gold := Color("e2be68")
	var cyan := Color("84cbb8")
	var rose := Color("e08572")
	_draw_callout_top(font, centers.get("Esc", Vector2(26, 36)), Vector2(10, 4), "Esc 暂停/返回", gold)
	_draw_callout_top(font, centers.get("Q", Vector2(52, 54)), Vector2(76, 4), "Q / Tab 手机", cyan)
	_draw_callout_top(font, centers.get("W", Vector2(70, 54)), Vector2(142, 4), "WASD 移动", gold)
	_draw_callout_top(font, centers.get("E", Vector2(89, 54)), Vector2(208, 4), "E 调查交互", gold)
	_draw_callout_top(font, centers.get("R", Vector2(108, 54)), Vector2(274, 4), "R 强闪驱鬼", rose)

	# Bottom left: Shift / Ctrl / Space short crisp pointer tags + Mouse control strip
	var sh_p: Vector2 = centers.get("Shift", Vector2(34, 88))
	draw_polyline(PackedVector2Array([sh_p + Vector2(-10, 3), Vector2(12, 91), Vector2(12, 125)]), Color(gold.r, gold.g, gold.b, 0.78), 1.1, true)
	draw_circle(sh_p + Vector2(-10, 3), 2.0, gold)

	var ct_p: Vector2 = centers.get("Ctrl", Vector2(30, 106))
	draw_polyline(PackedVector2Array([ct_p, Vector2(30, 125)]), Color(gold.r, gold.g, gold.b, 0.78), 1.1, true)
	draw_circle(ct_p, 2.0, gold)

	var mx := 10.0
	var my := 125.0
	draw_rect(Rect2(mx, my, 286, 22), Color(0.05, 0.085, 0.07, 0.94))
	draw_rect(Rect2(mx, my, 286, 22), Color("536858", 0.85), false, 0.9)
	draw_string(font, Vector2(mx + 6, my + 14.5), "Shift 冲刺 · Ctrl 蹲行 · Space 屏息/敲击 · 鼠标 转向/左键", HORIZONTAL_ALIGNMENT_LEFT, 276, 8, Color("e3dbc0"))

	# Right Column: Ordered PCB-trace routing through inter-row gutters so ZERO wires cross over key letters!
	# Row 2 center_y=71.5 -> upper gutter=62.5, lower gutter=80.0
	# Row 3 center_y=89.0 -> upper gutter=81.5, lower gutter=97.5
	var fp: Vector2 = centers.get("F", Vector2(114, 71.5))
	var hp: Vector2 = centers.get("H", Vector2(152, 71.5))
	var jp: Vector2 = centers.get("J", Vector2(171, 71.5))
	var cp: Vector2 = centers.get("C", Vector2(100, 89.0))
	var bp: Vector2 = centers.get("B", Vector2(138, 89.0))
	var mp: Vector2 = centers.get("M", Vector2(176, 89.0))
	var sp_p: Vector2 = centers.get("Space", Vector2(140, 106.5))
	_draw_callout_right(font, fp + Vector2(0, -6.0), 62.6, 291.0, 26.0, gold, "F 键", "手电筒 开关")
	_draw_callout_right(font, hp + Vector2(0, 6.0), 80.2, 294.0, 46.0, cyan, "H 键", "现场提示 / 澳门图鉴")
	_draw_callout_right(font, jp + Vector2(5.0, 0.0), 71.5, 297.0, 66.0, cyan, "J 键", "线索笔记档案")
	_draw_callout_right(font, cp + Vector2(0, 6.0), 97.6, 300.0, 86.0, rose, "C 键", "快速拍照取证")
	_draw_callout_right(font, bp + Vector2(0, 6.0), 99.6, 303.0, 106.0, cyan, "B 键", "随身物证背包")
	_draw_callout_right(font, mp + Vector2(5.0, 0.0), 89.0, 305.0, 126.0, cyan, "M 键", "澳门路线地图")
	_draw_callout_right(font, sp_p + Vector2(36.0, 0.0), 106.5, 307.0, 144.0, gold, "Space", "躲藏屏息 / 敲击节奏")
