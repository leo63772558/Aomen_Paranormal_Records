extends CanvasLayer

signal strike_requested
signal finish_listen_requested

const PIPE_TEX := preload("res://assets/props/short_pipe_086.png")
const FLANGE_TEX := preload("res://assets/props/coastal_console_plate_v10.png")

var mode := "jiamin" # "jiamin" | "dawen"
var target_title := "信号主管接头"
var knock_count := 0
var required_count := 3
var swing_anim := 0.0
var ring_waves: Array[Dictionary] = []
var board: Control
var strike_btn: Button
var finish_btn: Button

func _ready() -> void:
	layer = 16
	add_to_group("pipe_knock_panel")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	board = Control.new()
	board.position = Vector2(130, 224)
	board.size = Vector2(380, 124)
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	add_child(board)

	strike_btn = Button.new()
	strike_btn.text = "敲一下  [ 空格 ]"
	strike_btn.position = Vector2(138, 86)
	strike_btn.size = Vector2(124, 28)
	strike_btn.focus_mode = Control.FOCUS_NONE
	strike_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	strike_btn.add_theme_font_size_override("font_size", 11)
	strike_btn.add_theme_color_override("font_color", Color("f7e8ba"))
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.18, 0.28, 0.22, 0.96)
	st.border_color = Color("dfc174")
	st.set_border_width_all(1)
	st.set_corner_radius_all(3)
	strike_btn.add_theme_stylebox_override("normal", st)
	var sh := st.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.26, 0.40, 0.31, 0.98)
	sh.border_color = Color("fff0b8")
	strike_btn.add_theme_stylebox_override("hover", sh)
	strike_btn.add_theme_stylebox_override("pressed", sh)
	strike_btn.pressed.connect(func():
		strike_requested.emit()
	)
	board.add_child(strike_btn)

	finish_btn = Button.new()
	finish_btn.text = "听回音 [ Enter ]"
	finish_btn.position = Vector2(265, 86)
	finish_btn.size = Vector2(104, 28)
	finish_btn.focus_mode = Control.FOCUS_NONE
	finish_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	finish_btn.add_theme_font_size_override("font_size", 10)
	finish_btn.add_theme_color_override("font_color", Color("d8e6d4"))
	var fst := StyleBoxFlat.new()
	fst.bg_color = Color(0.12, 0.20, 0.17, 0.94)
	fst.border_color = Color("8aa48e")
	fst.set_border_width_all(1)
	fst.set_corner_radius_all(3)
	finish_btn.add_theme_stylebox_override("normal", fst)
	finish_btn.add_theme_stylebox_override("disabled", fst)
	finish_btn.add_theme_color_override("font_disabled_color", Color("77887d"))
	finish_btn.add_theme_stylebox_override("hover", sh)
	finish_btn.add_theme_stylebox_override("pressed", sh)
	finish_btn.visible = (mode == "dawen")
	finish_btn.pressed.connect(func():
		finish_listen_requested.emit()
	)
	board.add_child(finish_btn)

func configure_mode(next_mode: String, title_text: String, req: int = 3) -> void:
	mode = next_mode
	target_title = title_text
	required_count = req
	knock_count = 0
	if is_instance_valid(finish_btn):
		finish_btn.visible = (mode == "dawen")
		finish_btn.disabled = true
	if is_instance_valid(strike_btn):
		strike_btn.size.x = 124.0 if mode == "dawen" else 228.0
	if is_instance_valid(board):
		board.queue_redraw()

func notify_knock(new_count: int) -> void:
	knock_count = new_count
	swing_anim = 1.0
	finish_btn.disabled = knock_count < 3
	ring_waves.append({"r": 10.0, "a": 0.95})
	if is_instance_valid(board):
		board.queue_redraw()

func _process(delta: float) -> void:
	var dirty := false
	if swing_anim > 0.0:
		swing_anim = maxf(0.0, swing_anim - delta * 4.8)
		dirty = true
	if not ring_waves.is_empty():
		var next_rings: Array[Dictionary] = []
		for rw in ring_waves:
			var nr := float(rw["r"]) + delta * 95.0
			var na := float(rw["a"]) - delta * 1.85
			if na > 0.02:
				next_rings.append({"r": nr, "a": na})
		ring_waves = next_rings
		dirty = true
	if dirty and is_instance_valid(board):
		board.queue_redraw()

func _draw_board() -> void:
	var font := ThemeDB.fallback_font
	var sz := board.size
	# Industrial dark-slate acoustic pipe close-up frame
	board.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.035, 0.055, 0.048, 0.94))
	board.draw_rect(Rect2(Vector2.ZERO, sz), Color("b89e64", 0.90), false, 1.4)

	# Left close-up viewport: cast-iron pipe flange + animated swinging steel pipe striker (x=10..126, y=10..114)
	var view_rect := Rect2(10, 10, 116, 104)
	board.draw_rect(view_rect, Color(0.06, 0.08, 0.07, 0.98))
	if FLANGE_TEX != null:
		board.draw_texture_rect(FLANGE_TEX, view_rect, false, Color(0.72, 0.70, 0.65, 0.85))
	board.draw_rect(view_rect, Color("6c5f44"), false, 1.0)

	# Acoustic steel pipe joint in center of left viewport
	var pipe_c := Vector2(58, 62)
	board.draw_rect(Rect2(14, 50, 88, 24), Color(0.24, 0.23, 0.20, 0.96))
	board.draw_rect(Rect2(14, 52, 88, 6), Color(0.44, 0.42, 0.36, 0.75))
	board.draw_circle(pipe_c, 18.0, Color(0.30, 0.27, 0.22, 0.98))
	board.draw_arc(pipe_c, 18.0, 0.0, TAU, 24, Color("c4a868"), 1.6, true)
	board.draw_circle(pipe_c, 10.0, Color(0.14, 0.15, 0.14, 0.98))

	# Expanding metallic soundwave rings on strike
	for rw in ring_waves:
		var rad := float(rw["r"])
		var alp := float(rw["a"])
		board.draw_arc(pipe_c, minf(rad, 52.0), 0.0, TAU, 28, Color(0.96, 0.84, 0.48, alp), 2.0, true)

	# Swinging short steel pipe striker
	if PIPE_TEX != null:
		var ang := lerpf(-0.48, 0.12, sin(swing_anim * PI))
		var pivot := Vector2(96, 36) - Vector2(swing_anim * 18.0, -swing_anim * 14.0)
		board.draw_set_transform(pivot, ang, Vector2(0.26, 0.26))
		board.draw_texture(PIPE_TEX, -PIPE_TEX.get_size() * 0.5)
		board.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if swing_anim > 0.55:
		board.draw_circle(pipe_c + Vector2(8, -4), 5.5 * swing_anim, Color(1.0, 0.90, 0.55, 0.85))

	# Right section: Header, instructions, and live rhythm beat slots
	var title := "嘉敏 · " + target_title if mode == "jiamin" else target_title
	board.draw_string(font, Vector2(138, 25), title, HORIZONTAL_ALIGNMENT_LEFT, 232, 13, Color("f2de9e"))
	var sub := "用钢管敲出约定的三下（两短一长），让大文立刻认出你。" if mode == "jiamin" else "敲击确认。"
	board.draw_string(font, Vector2(138, 43), sub, HORIZONTAL_ALIGNMENT_LEFT, 232, 10, Color("c4d2c2"))

	# Rhythm beat slots
	var slot_count := required_count if mode == "jiamin" else 6
	var slot_step := 56.0 if mode == "jiamin" else 39.0
	var slot_width := slot_step - 8.0
	for i in range(slot_count):
		var sx := 138.0 + float(i) * slot_step
		var sy := 52.0
		var sr := Rect2(sx, sy, slot_width, 24.0)
		var hit := i < knock_count
		board.draw_rect(sr, Color(0.24, 0.34, 0.22, 0.96) if hit else Color(0.08, 0.12, 0.10, 0.92))
		board.draw_rect(sr, Color("f0cf76") if hit else Color("4a5c50"), false, 1.2 if hit else 1.0)
		board.draw_string(font, sr.position + Vector2(4, 16), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, slot_width - 8, 11, Color("fff2be") if hit else Color("a5b3a7"))
