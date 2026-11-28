extends Control

signal finished

const PAYPHONE_ART := preload("res://assets/props/payphone_booth_v9.png")

# Standard 7-segment bitmask: [top, top_right, bot_right, bot, bot_left, top_left, mid]
const SEG_MASKS := {
	"0": [1, 1, 1, 1, 1, 1, 0],
	"1": [0, 1, 1, 0, 0, 0, 0],
	"2": [1, 1, 0, 1, 1, 0, 1],
	"3": [1, 1, 1, 1, 0, 0, 1],
	"4": [0, 1, 1, 0, 0, 1, 1],
	"5": [1, 0, 1, 1, 0, 1, 1],
	"6": [1, 0, 1, 1, 1, 1, 1],
	"7": [1, 1, 1, 0, 0, 0, 0],
	"8": [1, 1, 1, 1, 1, 1, 1],
	"9": [1, 1, 1, 1, 0, 1, 1],
	"-": [0, 0, 0, 0, 0, 0, 1],
	"*": [0, 0, 0, 0, 0, 0, 1],
	"#": [0, 0, 0, 0, 0, 0, 1],
}

var dialed := ""
var status_label: Label
var digits_label: Label
var key_buttons: Array[Button] = []
var dial_clock := 0.0
var press_flash := 0.0
var busy_serial := 0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(618, 330)
	_build_ui()

func _exit_tree() -> void:
	AudioManager.stop_world_effect("phone_busy")

func _process(delta: float) -> void:
	dial_clock += delta
	press_flash = maxf(0.0, press_flash - delta * 4.0)
	queue_redraw()

func _draw_7seg_char(origin: Vector2, ch: String, w: float, h: float, lit_col: Color, dim_col: Color) -> void:
	var mask: Array = SEG_MASKS.get(ch, SEG_MASKS["-"])
	var half_h := h * 0.5
	var t := 2.2
	var segs := [
		[Vector2(2.0, 0.0), Vector2(w - 2.0, 0.0)],
		[Vector2(w, 2.0), Vector2(w, half_h - 1.5)],
		[Vector2(w, half_h + 1.5), Vector2(w, h - 2.0)],
		[Vector2(2.0, h), Vector2(w - 2.0, h)],
		[Vector2(0.0, half_h + 1.5), Vector2(0.0, h - 2.0)],
		[Vector2(0.0, 2.0), Vector2(0.0, half_h - 1.5)],
		[Vector2(2.0, half_h), Vector2(w - 2.0, half_h)],
	]
	for idx in range(7):
		var col := lit_col if mask[idx] == 1 else dim_col
		draw_line(origin + segs[idx][0], origin + segs[idx][1], col, t, true)

func _draw() -> void:
	draw_texture_rect(PAYPHONE_ART, Rect2(Vector2.ZERO, size), false)
	# Recessed backlit vintage CTM monochrome olive-emerald LCD inside painted glass bay
	var lcd_rect := Rect2(268, 60, 96, 38)
	draw_rect(lcd_rect, Color(0.045, 0.095, 0.068, 0.94))
	draw_rect(lcd_rect, Color(0.28, 0.42, 0.32, 0.85), false, 1.2)
	var lcd_alpha := 0.14 + 0.04 * sin(dial_clock * 4.5) + 0.22 * press_flash
	draw_rect(lcd_rect.grow(-2.0), Color(0.45, 0.88, 0.54, lcd_alpha))
	# Crisp header bar & MOP $1.00 coin tag inside LCD
	var font := get_theme_default_font()
	draw_string(font, Vector2(273, 70), "CTM  MOP$1.00", HORIZONTAL_ALIGNMENT_LEFT, 86, 7, Color(0.70, 0.92, 0.72, 0.78))
	# Authentic 7-segment display digits
	var shown := dialed if not dialed.is_empty() else "---"
	while shown.length() < 3:
		shown += " "
	var is_busy := dialed == "999"
	var lit_col := Color("ff9e86") if is_busy else Color("b4f5be")
	var dim_col := Color(0.18, 0.34, 0.23, 0.35)
	for di in range(3):
		var dx := 284.0 + float(di) * 23.0
		var dy := 76.0
		var ch := shown[di]
		if ch == " ":
			_draw_7seg_char(Vector2(dx, dy), "-", 12.0, 17.0, dim_col, dim_col)
		else:
			_draw_7seg_char(Vector2(dx, dy), ch, 12.0, 17.0, lit_col, dim_col)
	# Diagonal specular glass reflection streak
	draw_line(Vector2(272, 92), Vector2(304, 62), Color(0.90, 0.98, 0.92, 0.10), 2.5, true)
	# Clean bottom caption strip placed strictly below keypad bezel (y=278..324)
	draw_rect(Rect2(14, 278, 590, 46), Color(0.025, 0.045, 0.04, 0.93))
	draw_rect(Rect2(14, 278, 590, 46), Color("7a6c4e"), false, 1.0)

func _build_ui() -> void:
	var badge := PanelContainer.new()
	badge.position = Vector2(14, 12)
	badge.size = Vector2(162, 38)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bskin := StyleBoxFlat.new()
	bskin.bg_color = Color(0.03, 0.055, 0.048, 0.88)
	bskin.border_color = Color("8c7b56")
	bskin.set_border_width_all(1)
	bskin.set_corner_radius_all(3)
	badge.add_theme_stylebox_override("panel", bskin)
	add_child(badge)

	var header := Label.new()
	header.text = "澳门电讯公用电话\n已投入 1 澳门元"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color("ebd9a2"))
	badge.add_child(header)

	# Keep digits_label cleanly synchronized for QA/regression reads while 7-seg visual renders above
	digits_label = Label.new()
	digits_label.text = "拨号 999"
	digits_label.position = Vector2(273, 60)
	digits_label.size = Vector2(86, 30)
	digits_label.modulate.a = 0.0
	digits_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(digits_label)

	var keys := ["1","2","3","4","5","6","7","8","9","*","0","#"]
	for i in range(keys.size()):
		var col := i % 3
		var row := i / 3
		var btn := Button.new()
		btn.text = ""
		btn.tooltip_text = "按键 " + keys[i]
		btn.position = Vector2(311 + col * 27, 169 + row * 21)
		btn.size = Vector2(24, 18)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		var kh := StyleBoxFlat.new()
		kh.bg_color = Color(0.95, 0.88, 0.65, 0.18)
		kh.border_color = Color("e8cd7e", 0.82)
		kh.set_border_width_all(1)
		kh.set_corner_radius_all(2)
		btn.add_theme_stylebox_override("hover", kh)
		var kp := StyleBoxFlat.new()
		kp.bg_color = Color(0.02, 0.03, 0.025, 0.50)
		kp.border_color = Color("bfa35e", 0.90)
		kp.border_width_top = 2
		kp.set_corner_radius_all(2)
		btn.add_theme_stylebox_override("pressed", kp)
		btn.pressed.connect(_press_key.bind(keys[i]))
		add_child(btn)
		key_buttons.append(btn)

	status_label = Label.new()
	status_label.text = "拨打 999 报警。可点击金属键盘或直接按数字键。"
	status_label.position = Vector2(24, 283)
	status_label.size = Vector2(386, 36)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color("e4dcc6"))
	add_child(status_label)

	var hangup := Button.new()
	hangup.text = "挂断听筒 [ Esc ]"
	hangup.position = Vector2(422, 288)
	hangup.size = Vector2(170, 26)
	hangup.focus_mode = Control.FOCUS_NONE
	hangup.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hangup.add_theme_font_size_override("font_size", 11)
	hangup.add_theme_color_override("font_color", Color("eee2b8"))
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color("16261f")
	hs.border_color = Color("9c8a5d")
	hs.set_border_width_all(1)
	hs.set_corner_radius_all(2)
	hangup.add_theme_stylebox_override("normal", hs)
	var hh := hs.duplicate() as StyleBoxFlat
	hh.bg_color = Color("233d32")
	hh.border_color = Color("e4cb86")
	hangup.add_theme_stylebox_override("hover", hh)
	hangup.add_theme_stylebox_override("pressed", hh)
	hangup.pressed.connect(func(): finished.emit())
	add_child(hangup)

func _press_key(ch: String) -> void:
	AudioManager.play_world_effect("use_keypad_dead")
	press_flash = 1.0
	if dialed.length() == 3:
		dialed = ""
	dialed += ch
	digits_label.text = dialed
	if dialed == "999":
		AudioManager.play_world_effect("phone_busy")
		busy_serial += 1
		var sid := busy_serial
		var t := get_tree().create_timer(2.2, true)
		t.timeout.connect(func():
			if is_instance_valid(self) and sid == busy_serial:
				AudioManager.stop_world_effect("phone_busy")
		)
		status_label.text = "听筒里只有忙音。紧急热线接不通。"
	elif dialed.length() == 3:
		status_label.text = "号码无效。再按 999 试一次。"
	else:
		status_label.text = "正在拨号…"
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.unicode >= 48 and event.unicode <= 57:
		_press_key(String.chr(event.unicode))
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_BACKSPACE:
		dialed = dialed.left(-1)
		digits_label.text = dialed if not dialed.is_empty() else "拨号 999"
		status_label.text = "拨打 999 报警。可点击金属键盘或直接按数字键。"
		queue_redraw()
		get_viewport().set_input_as_handled()
