extends Control

signal verified

const CRATE_BG := preload("res://assets/tilesets/ammo_floor_026.png")

var heard := [false, false]
var embedded_in_bag := false
var confirmed := false
const TITLES := ["磁带 A 面 · 洞口铁链与急促喘息", "磁带 B 面 · 嘉敏临走前的留声"]
const TRANSCRIPTS := [
	"「（铁门晃动声）正门从外面被粗铁链锁死了……阿豪……九十九级那边还有脚步声在追！」",
	"「我不能留在这里等死，我要顺着防空洞深处的排风竖井暗道往大关斜巷方向逃！」"
]
var status := "按下机身上的播放键复听两段旧磁带录音，核实嘉敏遗落录音机后的真实去向。"
var info: Label
var classify: Button
var dismiss: Button
var transcripts: Array[Label] = []
var play_buttons: Array[Button] = []
var active_reel := -1
var play_anim_timer := 0.0
var reel_angle := 0.0
var vu_level := 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var header := _label("复听旧式微型卡带录音机 · 松山子弹房", Vector2(18, 10), 15, Color("ecd8a0"))
	header.size.x = 460
	if not embedded_in_bag:
		_label("Esc 返回", Vector2(534, 12), 12, Color("bfb89e"))

	# Authentic physical microcassette recorder sprite nestled on the brushed dark-metal deck left bay
	var recorder := TextureRect.new()
	recorder.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	recorder.texture = DemoItems.texture("bunker_recording")
	recorder.position = Vector2(24, 52)
	recorder.size = Vector2(138, 134)
	recorder.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	recorder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(recorder)

	for i in range(2):
		var row_y := 54 + i * 82
		_label(TITLES[i], Vector2(192, row_y + 2), 13, Color("eadcb6"))
		var tr := _label("按下右侧【▶ 播放】复听该段磁带内容……", Vector2(192, row_y + 26), 11, Color("a6b0a6"))
		tr.size = Vector2(296, 42)
		tr.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		transcripts.append(tr)
		var play := _styled_btn("▶ 播放", Vector2(498, row_y + 16), Vector2(88, 30), Color("1f2924"))
		play.pressed.connect(_play.bind(i))
		add_child(play)
		play_buttons.append(play)

	info = _label(status, Vector2(188, 226), 11, Color("dfd6b8"))
	info.size = Vector2(408, 24)
	classify = _styled_btn("她已沿通风暗道逃向大关斜巷", Vector2(20, 272), Vector2(280, 36), Color("1e3328"))
	classify.disabled = true
	classify.pressed.connect(func():
		if confirmed or classify.disabled:
			return
		confirmed = true
		classify.disabled = true
		dismiss.disabled = true
		info.text = "已核对去向。她打算沿通风暗道往大关斜巷撤离。"
		verified.emit()
	)
	add_child(classify)
	dismiss = _styled_btn("她现在一定还被困在防空洞里", Vector2(314, 272), Vector2(282, 36), Color("2b2220"))
	dismiss.disabled = true
	dismiss.pressed.connect(func(): info.text = "这是她脱身前遗落在子弹房的旧录音——再听听 B 面提到的撤离方向。")
	add_child(dismiss)

func _process(delta: float) -> void:
	if play_anim_timer > 0.0:
		play_anim_timer = maxf(0.0, play_anim_timer - delta)
		reel_angle += delta * 5.2
		var target_vu := 0.35 + 0.45 * absf(sin(reel_angle * 1.9)) + 0.18 * absf(cos(reel_angle * 4.3))
		vu_level = lerpf(vu_level, target_vu, clampf(delta * 14.0, 0.0, 1.0))
		if play_anim_timer <= 0.0:
			active_reel = -1
		queue_redraw()
	elif vu_level > 0.005:
		vu_level = lerpf(vu_level, 0.0, clampf(delta * 9.0, 0.0, 1.0))
		queue_redraw()

func _styled_btn(caption: String, at: Vector2, sz: Vector2, bg: Color) -> Button:
	var btn := Button.new()
	btn.text = caption
	btn.position = at
	btn.size = sz
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color("ede5cc"))
	btn.add_theme_color_override("font_hover_color", Color("f8e09c"))
	btn.add_theme_color_override("font_disabled_color", Color("666e68"))
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = Color("766c50")
	st.border_width_top = 1
	st.border_width_left = 1
	st.border_width_right = 1
	st.border_width_bottom = 2
	st.set_corner_radius_all(2)
	btn.add_theme_stylebox_override("normal", st)
	var hv := st.duplicate() as StyleBoxFlat
	hv.bg_color = bg.lightened(0.15)
	hv.border_color = Color("dfc57d")
	btn.add_theme_stylebox_override("hover", hv)
	btn.add_theme_stylebox_override("pressed", hv)
	var dis := st.duplicate() as StyleBoxFlat
	dis.bg_color = Color("141816")
	dis.border_color = Color("363e39")
	btn.add_theme_stylebox_override("disabled", dis)
	return btn

func _label(value: String, at: Vector2, points: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _play(index: int) -> void:
	# Always play authentic tape recording voice/static (layered with subtle chain rattle on A-side via polyphonic AudioManager!)
	AudioManager.play_voice("jiamin_bunker_tape", -1.5)
	AudioManager.play_world_effect("recording_fragment")
	if index == 0:
		AudioManager.play_world_effect("gate_chain")
	heard[index] = true
	active_reel = index
	play_anim_timer = 2.0
	transcripts[index].text = TRANSCRIPTS[index]
	transcripts[index].add_theme_color_override("font_color", Color("f2e4b8"))
	play_buttons[index].text = "↺ 重播"
	if not confirmed:
		info.text = "已打开两面录音。请判断嘉敏提到的撤离路线。" if heard[0] and heard[1] else "继续播放磁带的另一面。"
		classify.disabled = not (heard[0] and heard[1])
		dismiss.disabled = classify.disabled
	queue_redraw()

func _draw() -> void:
	var font := get_theme_default_font()
	# Damp bunker ammunition table surface + dark anodized 1980s tape deck chassis (ZERO cartoon neon bars!)
	draw_texture_rect(CRATE_BG, Rect2(Vector2.ZERO, size), false, Color(0.24, 0.25, 0.22, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.035, 0.03, 0.80))
	draw_rect(Rect2(0, 0, size.x, 34), Color(0.02, 0.028, 0.024, 0.94))
	draw_line(Vector2(0, 34), Vector2(size.x, 34), Color("5a523e"), 1.0)

	# Left brushed gunmetal tape-deck chassis frame
	var deck := Rect2(16, 44, 156, 212)
	draw_rect(deck, Color("141716"))
	draw_rect(deck, Color("4c493c"), false, 1.5)
	draw_rect(Rect2(deck.position + Vector2(3, 3), deck.size - Vector2(6, 6)), Color("222523"), false, 1.0)

	# Warm amber-backlit analog VU meter window (classic 1980s mechanical swing needle — NO neon green equalizer!)
	var vu := Rect2(26, 194, 136, 52)
	draw_rect(vu, Color("1c1811"))
	draw_rect(vu, Color("5a4e36"), false, 1.2)
	var warm_glow := 0.28 + 0.32 * vu_level if play_anim_timer > 0.0 else 0.12
	draw_rect(vu.grow(-2), Color(0.84, 0.64, 0.28, warm_glow))
	var vu_pivot := Vector2(94.0, 240.0)
	for ti in range(9):
		var tf := float(ti) / 8.0
		var ta := lerpf(-0.92, 0.92, tf)
		var td := Vector2.UP.rotated(ta)
		var tc := Color("b43a2c") if ti >= 6 else Color("2b2318")
		draw_line(vu_pivot + td * 28.0, vu_pivot + td * 34.0, tc, 1.4 if ti % 2 == 0 else 1.0, true)
	var vu_ang := lerpf(-0.85, 0.78, vu_level)
	draw_line(vu_pivot, vu_pivot + Vector2.UP.rotated(vu_ang) * 33.0, Color("1a140e"), 1.8, true)
	draw_circle(vu_pivot, 3.2, Color("4e4028"))
	draw_string(font, Vector2(32, 208), "VU", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("382d1c"))
	draw_string(font, Vector2(118, 208), "+3dB", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("8a2b20"))
	# Tiny red recording/playback LED pilot
	draw_circle(Vector2(148, 56), 3.4, Color("c43428") if play_anim_timer > 0.0 else Color("2d1a18"))
	draw_arc(Vector2(148, 56), 3.4, 0.0, TAU, 12, Color("584a3c"), 1.0, true)

	# Right weathered archival transcript cards
	for index in range(2):
		var card := Rect2(184, 46 + index * 82, 414, 72)
		draw_rect(card, Color(0.055, 0.075, 0.065, 0.92))
		var b_col := Color("dfc478") if active_reel == index else (Color("85764f") if heard[index] else Color("434d44"))
		draw_rect(card, b_col, false, 1.5 if active_reel == index else 1.0)

func _exit_tree() -> void:
	AudioManager.stop_voice()
