extends Control

const WARM := Color("e9cf96")
const PAPER := Color("e6e4d2")
const MUTED := Color("b4c2b5")
const CRIMSON := Color("d65249")

# Normalized coordinates (0..1) on assets/ui/macau_folklore_map_252.png (1376x768, aspect 1.7917)
const STOPS := [
	{"uv": Vector2(0.285, 0.435), "num": "1", "year": "游戏虚构", "title": "福荣里 304", "legend": "唐楼床后封门", "photo": "res://assets/ui/map_landmarks/stop_1_tanglau.png", "lore": "嘉敏收了一张 304 旧照。铁床背后有扇门，后来画的平面图上却只有墙。", "history": "旧酒店取材于澳门唐楼。酒店与 304 的调查为虚构。", "room_prefix": "ch0_"},
	{"uv": Vector2(0.378, 0.258), "num": "2", "year": "地标与传闻", "title": "大三巴地宫", "legend": "黑袍白骨老伯", "photo": "res://assets/ui/map_landmarks/stop_2_stpaul_crypt.png", "lore": "有人说见到的是黑袍老人，也有人说灯下只有白骨。", "history": "牌坊与墓室为场景参考。游戏中的侧门和地下路线为虚构。", "room_prefix": "ch1_"},
	{"uv": Vector2(0.585, 0.238), "num": "3", "year": "民间传闻", "title": "松山防空洞", "legend": "九十九级鬼阶", "photo": "res://assets/ui/map_landmarks/stop_3_guia_bunker.png", "lore": "夜里数石阶，台阶比白天多出十级。数到最后，好像有人叫你的名字。", "history": "洞内阶梯、竖井与红衣人影经过游戏改编。", "room_prefix": "ch2_"},
	{"uv": Vector2(0.455, 0.365), "num": "4", "year": "民间传闻", "title": "大关斜巷肉铺", "legend": "夜半剁骨声", "photo": "res://assets/ui/map_landmarks/stop_4_amparo_alley.png", "lore": "老铺掩门后，街坊说还听得见剁骨声。旧收音机里只唱半句。", "history": "肉铺、住户和账册均为本作虚构。", "room_prefix": "ch3_"},
	{"uv": Vector2(0.495, 0.485), "num": "5", "year": "旧案剪报", "title": "八仙旧闻档案", "legend": "剪报与坊间附会", "photo": "res://assets/ui/map_landmarks/stop_5_archive_1985.png", "lore": "嘉敏把能从报道核对的内容和传言分开做了标记。", "history": "本作的肉铺调查和嘉敏留下的线索属于虚构。", "room_prefix": "ch3_quiet"},
	{"uv": Vector2(0.262, 0.595), "num": "6", "year": "游戏虚构", "title": "雾桥 33 路末班车", "legend": "午夜末班车异象", "photo": "res://assets/ui/map_landmarks/stop_6_bridge_bus33.png", "lore": "桥上起雾后，司机照常报站。车里的人始终没出声。", "history": "本作车次和站点按剧情改编。", "room_prefix": "ch4_"},
	{"uv": Vector2(0.525, 0.865), "num": "7", "year": "地标与传闻", "title": "路环黑沙海滩", "legend": "海里传来的呼唤", "photo": "res://assets/ui/map_landmarks/stop_7_hacsa_beach.png", "lore": "海浪很响。有人却听得清岸下那一声是谁叫的。", "history": "海滩为场景参考。鞋印、救援车及通道为剧内线索。", "room_prefix": "ch5_"},
	{"uv": Vector2(0.515, 0.695), "num": "8", "year": "游戏虚构", "title": "石屎封墙夹层", "legend": "墙里还有回声", "photo": "res://assets/ui/map_landmarks/stop_8_bleeding_wall.png", "lore": "补过的墙后，还是有人敲了三下。", "history": "百利新邨封墙怪谈是取材线索。游戏里的暗渠、夹层和档案为虚构。", "room_prefix": "ch6_"}
]

var current_objective := ""
var map_tex: Texture2D
var selected_stop := -1
var hovered_stop := -1
var pulse_clock := 0.0
var info_card: PanelContainer
var info_title: Label
var info_badge: Label
var info_photo: TextureRect
var info_year_pill: Label
var info_body: RichTextLabel
var landmark_cache: Dictionary = {}

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	map_tex = load("res://assets/ui/macau_folklore_map_252.png")
	for i in range(STOPS.size()):
		var p: String = String(STOPS[i].get("photo", ""))
		if not p.is_empty() and ResourceLoader.exists(p):
			landmark_cache[i] = load(p)
	selected_stop = _active_stop_index()
	_build_side_dossier_card()
	_refresh_card()

func _build_side_dossier_card() -> void:
	# Dedicated right-side illustrated archival dossier card (photo + concise lore, never a wall of text!)
	info_card = PanelContainer.new()
	info_card.position = Vector2(394, 34)
	info_card.size = Vector2(212, 282)
	info_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var cstyle := StyleBoxFlat.new()
	cstyle.bg_color = Color(0.055, 0.09, 0.075, 0.96)
	cstyle.border_color = Color("b29a66")
	cstyle.set_border_width_all(1)
	cstyle.border_width_top = 2
	cstyle.set_corner_radius_all(3)
	cstyle.content_margin_left = 8
	cstyle.content_margin_right = 8
	cstyle.content_margin_top = 8
	cstyle.content_margin_bottom = 8
	info_card.add_theme_stylebox_override("panel", cstyle)
	add_child(info_card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	info_card.add_child(vbox)

	info_title = Label.new()
	info_title.add_theme_font_size_override("font_size", 12)
	info_title.add_theme_color_override("font_color", WARM)
	vbox.add_child(info_title)

	# Illustrated vintage archival Macau landmark photograph frame (196x108)
	var photo_frame := PanelContainer.new()
	photo_frame.custom_minimum_size = Vector2(194, 108)
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color("0a100d")
	pstyle.border_color = Color("8c7a52")
	pstyle.set_border_width_all(1)
	pstyle.content_margin_left = 2
	pstyle.content_margin_right = 2
	pstyle.content_margin_top = 2
	pstyle.content_margin_bottom = 2
	photo_frame.add_theme_stylebox_override("panel", pstyle)
	vbox.add_child(photo_frame)

	var photo_holder := Control.new()
	photo_holder.custom_minimum_size = Vector2(190, 104)
	photo_holder.clip_contents = true
	photo_frame.add_child(photo_holder)

	info_photo = TextureRect.new()
	info_photo.position = Vector2.ZERO
	info_photo.size = Vector2(190, 104)
	info_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	info_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	info_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo_holder.add_child(info_photo)

	# Dark archival caption strip overlaid along bottom of the photo
	var cap_bg := ColorRect.new()
	cap_bg.position = Vector2(0, 84)
	cap_bg.size = Vector2(190, 20)
	cap_bg.color = Color(0.03, 0.05, 0.04, 0.80)
	cap_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo_holder.add_child(cap_bg)

	info_year_pill = Label.new()
	info_year_pill.position = Vector2(5, 86)
	info_year_pill.size = Vector2(180, 16)
	info_year_pill.add_theme_font_size_override("font_size", 9)
	info_year_pill.add_theme_color_override("font_color", Color("edd596"))
	info_year_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo_holder.add_child(info_year_pill)

	info_badge = Label.new()
	info_badge.add_theme_font_size_override("font_size", 10)
	info_badge.add_theme_color_override("font_color", Color("e4887a"))
	vbox.add_child(info_badge)

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(0.66, 0.57, 0.39, 0.38)
	vbox.add_child(sep)

	info_body = RichTextLabel.new()
	info_body.bbcode_enabled = false
	info_body.fit_content = false
	info_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_body.add_theme_font_size_override("normal_font_size", 10)
	info_body.add_theme_constant_override("line_separation", 2)
	info_body.add_theme_color_override("default_color", PAPER)
	vbox.add_child(info_body)

func _map_rect() -> Rect2:
	# Exact 1376x768 (1.7917) aspect ratio inside the left 370x206 parchment mat — never oversized or stretched!
	var box := Rect2(14.0, 44.0, 368.0, 236.0)
	var tex_aspect := 1376.0 / 768.0
	if map_tex != null and map_tex.get_height() > 0:
		tex_aspect = float(map_tex.get_width()) / float(map_tex.get_height())
	var w := box.size.x
	var h := w / tex_aspect
	if h > box.size.y:
		h = box.size.y
		w = h * tex_aspect
	return Rect2(box.position.x + (box.size.x - w) * 0.5, box.position.y + (box.size.y - h) * 0.5, w, h)

func _stop_pos(index: int, mrect: Rect2) -> Vector2:
	var uv: Vector2 = STOPS[index].uv
	return mrect.position + Vector2(uv.x * mrect.size.x, uv.y * mrect.size.y)

func _active_stop_index() -> int:
	var room := GameState.current_room_id
	if room.begins_with("ch6_"):
		return 7
	if room == "ch3_quiet_passage":
		return 4
	for i in range(STOPS.size()):
		if room.begins_with(STOPS[i].room_prefix):
			return i
	return 0

func _refresh_card() -> void:
	if not is_instance_valid(info_card):
		return
	var focus_idx := clampi(hovered_stop if hovered_stop >= 0 else selected_stop, 0, STOPS.size() - 1)
	var stop: Dictionary = STOPS[focus_idx]
	info_title.text = "第 %s 站 · %s" % [stop.num, stop.title]
	info_badge.text = "怪谈：%s" % String(stop.get("legend", ""))
	if is_instance_valid(info_photo):
		info_photo.texture = landmark_cache.get(focus_idx, null)
	if is_instance_valid(info_year_pill):
		info_year_pill.text = "【%s】%s" % [String(stop.get("year", "澳门旧档")), stop.title]
	var obj := current_objective if not current_objective.is_empty() else "点击左侧 1~8 号地标"
	info_body.text = "%s\n%s\n● 目标：%s" % [stop.lore, String(stop.get("history", "")), obj]

func _process(delta: float) -> void:
	pulse_clock += delta
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var mrect := _map_rect()
	if event is InputEventMouseMotion:
		var next_hover := -1
		for i in range(STOPS.size()):
			if event.position.distance_to(_stop_pos(i, mrect)) <= 15.0:
				next_hover = i
				break
		if next_hover != hovered_stop:
			hovered_stop = next_hover
			_refresh_card()
			queue_redraw()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for i in range(STOPS.size()):
			if event.position.distance_to(_stop_pos(i, mrect)) <= 17.0:
				selected_stop = i
				AudioManager.play_dialogue_advance()
				_refresh_card()
				queue_redraw()
				accept_event()
				return

func _draw() -> void:
	var font := get_theme_default_font()
	var area := Rect2(Vector2.ZERO, size if size.x > 10.0 else Vector2(618.0, 330.0))
	draw_rect(area, Color("0b120f"))

	# Header bar
	draw_string(font, Vector2(14, 21), "澳门寻人 · 手绘民俗路线图", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, WARM)
	draw_string(font, Vector2(204, 21), "点击 1~8 号地标查看档案", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)

	# Outer dark-brass mat frame on the left (x = 12..384, y = 34..316)
	var mat_rect := Rect2(12, 34, 372, 282)
	draw_rect(mat_rect, Color(0.08, 0.095, 0.082, 0.98))
	draw_rect(mat_rect, Color("8a7856"), false, 1.2)

	# Proportional 16:9 hand-drawn Macau map inside the left mat
	var mrect := _map_rect()
	draw_rect(Rect2(mrect.position - Vector2(2, 2), mrect.size + Vector2(4, 4)), Color(0.03, 0.04, 0.035, 0.95))
	if map_tex != null:
		draw_texture_rect(map_tex, mrect, false)
	draw_rect(mrect, Color("b89f6d"), false, 1.2)

	var active_idx := _active_stop_index()
	for i in range(STOPS.size() - 1):
		var a := _stop_pos(i, mrect)
		var b := _stop_pos(i + 1, mrect)
		var col := Color(0.88, 0.34, 0.28, 0.88) if i < active_idx else Color(0.88, 0.81, 0.64, 0.45)
		var segs := 10
		for s in range(0, segs, 2):
			draw_line(a.lerp(b, float(s) / segs), a.lerp(b, minf(1.0, float(s + 1) / segs)), col, 1.4, true)

	var focus_idx := hovered_stop if hovered_stop >= 0 else selected_stop
	for i in range(STOPS.size()):
		var pt := _stop_pos(i, mrect)
		var is_active := (i == active_idx)
		var is_focus := (i == focus_idx)
		if is_active:
			var r := 10.5 + sin(pulse_clock * 4.2) * 2.5
			draw_arc(pt, r, 0.0, TAU, 24, Color(0.96, 0.36, 0.30, 0.90), 1.6)
		var pin_r := 8.2 if is_focus else 6.8
		var pin_col := CRIMSON if is_active else (Color("f0d788") if is_focus else Color("233029"))
		var text_col := Color("fff7e6") if (is_active or not is_focus) else Color("131a15")
		draw_circle(pt, pin_r + 1.2, Color("0d120f"))
		draw_circle(pt, pin_r, pin_col)
		draw_string(font, pt + Vector2(-3.0, 3.5), STOPS[i].num, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, text_col)

	# Bottom map legend strip inside left mat
	var leg_y := mrect.end.y + 18.0
	draw_circle(Vector2(26, leg_y - 3), 4.5, CRIMSON)
	draw_string(font, Vector2(36, leg_y), "当前所在章节", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, PAPER)
	draw_circle(Vector2(126, leg_y - 3), 4.5, Color("f0d788"))
	draw_string(font, Vector2(136, leg_y), "正在检视地标", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, WARM)
	draw_string(font, Vector2(232, leg_y), "比例尺 · 澳门半岛—氹仔—路环", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)
