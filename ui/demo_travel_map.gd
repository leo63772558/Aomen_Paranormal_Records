extends Control

const WARM := Color("e9cf96")
const PAPER := Color("e6e4d2")
const MUTED := Color("b4c2b5")
const CRIMSON := Color("d65249")

const STOPS := [
	{"pos": Vector2(184, 118), "title": "① 福荣里 304", "lore": "传说旧唐楼床后藏有秘道，住户小孩常对着黑袍老伯自言自语。", "room_prefix": "ch0_"},
	{"pos": Vector2(236, 86), "title": "② 大三巴地宫", "lore": "1961年牌坊后挖出数十具遗骨；手电直射黑袍老伯会显出森然白骨。", "room_prefix": "ch1_"},
	{"pos": Vector2(362, 78), "title": "③ 松山防空洞", "lore": "夜巡烧香禁回头、白天89级夜里99级鬼阶，洞内有流浪汉易拉罐与无底洞。", "room_prefix": "ch2_"},
	{"pos": Vector2(272, 116), "title": "④ 大关斜巷肉铺", "lore": "二战饥荒盛传「肥人慎入大关斜巷」，紧邻长楼斜巷猪仔馆大火旧址。", "room_prefix": "ch3_"},
	{"pos": Vector2(168, 166), "title": "⑤ 友谊大桥 33路", "lore": "2004年末班33路后排无声乘客与跨海雾中白衣招手女鬼，连对5次突围。", "room_prefix": "ch4_"},
	{"pos": Vector2(344, 236), "title": "⑥ 黑沙 → 路氹旧赌厅", "lore": "黑沙海滩车灯白影与1985八仙饭店旧报辟谣；深处连通渗血石屎墙与废弃VIP赌厅。", "room_prefix": "ch5_"}
]

var current_objective := ""
var map_tex: Texture2D
var selected_stop := -1
var pulse_clock := 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	map_tex = load("res://assets/ui/macau_folklore_map_252.png")
	selected_stop = _active_stop_index()

func _active_stop_index() -> int:
	var room := GameState.current_room_id
	if room.begins_with("ch6_"):
		return 5
	for i in range(STOPS.size()):
		if room.begins_with(STOPS[i].room_prefix):
			return i
	return 0

func _process(delta: float) -> void:
	pulse_clock += delta
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for i in range(STOPS.size()):
			if event.position.distance_to(STOPS[i].pos) <= 22.0:
				selected_stop = i
				AudioManager.play_dialogue_advance()
				queue_redraw()
				accept_event()
				return

func _draw() -> void:
	var font := get_theme_default_font()
	var area := Rect2(Vector2.ZERO, size if size.x > 10 else Vector2(618, 338))
	draw_rect(area, Color("0e1814"))

	# Draw the hand-drawn Macau folklore map artwork
	var map_rect := Rect2(14, 36, 590, 224)
	if map_tex != null:
		draw_texture_rect(map_tex, map_rect, false)
	draw_rect(map_rect, Color("5a6b58"), false, 1.5)

	# Top header bar
	draw_string(font, Vector2(18, 25), "《澳门怪谈手札》 · 手绘寻人路线图", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, WARM)
	draw_string(font, Vector2(390, 24), "点击地图红标查传说  ·  Esc 返回", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)

	# Dashed red route connecting the 6 Macau folklore landmarks
	var active_idx := _active_stop_index()
	for i in range(STOPS.size() - 1):
		var a: Vector2 = STOPS[i].pos
		var b: Vector2 = STOPS[i + 1].pos
		var line_col := CRIMSON if i <= active_idx else Color(0.55, 0.52, 0.42, 0.55)
		draw_dashed_line(a, b, line_col, 2.2, 5.0)

	# Draw landmark pins & labels
	for i in range(STOPS.size()):
		var stop: Dictionary = STOPS[i]
		var pt: Vector2 = stop.pos
		var is_current := (i == active_idx)
		var is_selected := (i == selected_stop)
		var is_done := (i < active_idx)

		if is_current:
			var r := 11.0 + sin(pulse_clock * 5.0) * 3.0
			draw_arc(pt, r, 0, TAU, 24, Color(0.95, 0.35, 0.30, 0.85), 2.0)
		if is_selected:
			draw_circle(pt, 10.0, Color(0.95, 0.84, 0.45, 0.35))

		draw_circle(pt, 6.5, Color("161d19"))
		draw_circle(pt, 5.0, CRIMSON if is_current else (Color("6dbf7e") if is_done else Color("d8c383")))

		var tag_text: String = stop.title + (" ✓" if is_done else "")
		var tag_pos := pt + Vector2(9, 4)
		draw_rect(Rect2(tag_pos - Vector2(3, 12), Vector2(tag_text.length() * 10.5 + 8, 16)), Color(0.06, 0.11, 0.09, 0.86))
		draw_string(font, tag_pos, tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, WARM if is_selected or is_current else PAPER)

	# Bottom folklore card + current objective
	var info_rect := Rect2(14, 265, 590, 62)
	draw_rect(info_rect, Color("15231d"))
	draw_rect(info_rect, Color("4a6152"), false, 1.0)

	var shown_idx := selected_stop if selected_stop >= 0 else active_idx
	var shown: Dictionary = STOPS[clampi(shown_idx, 0, STOPS.size() - 1)]
	draw_string(font, Vector2(24, 284), "【" + shown.title + " · 都市传说伏笔】 " + shown.lore, HORIZONTAL_ALIGNMENT_LEFT, 570, 12, WARM)
	var obj_text := current_objective if not current_objective.is_empty() else "顺着嘉敏留下的现场痕迹追查，揭开旧案真相。"
	draw_string(font, Vector2(24, 308), "当前行动：" + obj_text, HORIZONTAL_ALIGNMENT_LEFT, 570, 12, PAPER)
