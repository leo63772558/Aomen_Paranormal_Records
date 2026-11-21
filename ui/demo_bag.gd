extends Control

const JOURNAL_ITEMS := [
	"old_304_photo", "power_record", "wet_tag", "crypt_old_photo", "crypt_survey",
	"crypt_doodle", "interview_index", "gate_work_order", "stair_rubbing", "bunker_recording",
	"w17_bus_ticket", "laochen_handoff_note", "jiamin_lens_cap", "ahhao_camera",
	"shoe_repair_photo", "hotel_maintenance_plan"
]

var journal_mode := false
var journal_note := ""
var item_list: ItemList
var item_title: Label
var detail: RichTextLabel
var preview: TextureRect
var notice_diagram: Control
var assemble: Button
var item_ids: Array[String] = []

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	var header := Label.new()
	header.text = "手札" if journal_mode else "背包"
	header.position = Vector2(16, 8)
	header.add_theme_font_size_override("font_size", 17)
	add_child(header)
	var back_hint := Label.new()
	back_hint.text = "Esc / J 返回" if journal_mode else "Esc / B 返回"
	back_hint.position = Vector2(498, 11)
	back_hint.add_theme_font_size_override("font_size", 12)
	back_hint.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(back_hint)
	item_list = ItemList.new()
	item_list.position = Vector2(16, 42)
	item_list.size = Vector2(235, 268)
	item_list.fixed_icon_size = Vector2i(34, 34)
	item_list.add_theme_constant_override("v_separation", 5)
	item_list.item_selected.connect(_inspect)
	add_child(item_list)
	item_title = Label.new()
	item_title.position = Vector2(271, 42)
	item_title.size = Vector2(330, 24)
	item_title.add_theme_font_size_override("font_size", 16)
	add_child(item_title)
	preview = TextureRect.new()
	preview.position = Vector2(271, 72)
	preview.size = Vector2(330, 137)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(preview)
	notice_diagram = Control.new()
	notice_diagram.position = Vector2(271, 68)
	notice_diagram.size = Vector2(330, 128)
	notice_diagram.mouse_filter = MOUSE_FILTER_IGNORE
	notice_diagram.draw.connect(_draw_notice_diagram)
	notice_diagram.hide()
	add_child(notice_diagram)
	detail = RichTextLabel.new()
	detail.position = Vector2(271, 213)
	detail.size = Vector2(330, 65)
	detail.add_theme_font_size_override("normal_font_size", 14)
	detail.mouse_filter = MOUSE_FILTER_STOP
	add_child(detail)
	assemble = Button.new()
	assemble.text = "组装握柄与方轴"
	assemble.position = Vector2(271, 283)
	assemble.size = Vector2(201, 29)
	assemble.pressed.connect(_assemble)
	add_child(assemble)
	_refresh()

func _refresh(selected: String = "") -> void:
	item_ids.clear()
	item_list.clear()
	if journal_mode and not journal_note.is_empty():
		item_ids.append("")
		item_list.add_item("现场告示")
	var available_ids: Array = JOURNAL_ITEMS if journal_mode else DemoItems.ENTRIES.keys()
	for item_id in available_ids:
		if GameState.has_demo_item(item_id):
			item_ids.append(item_id)
			item_list.add_item(DemoItems.title(item_id), DemoItems.texture(item_id))
	if item_ids.is_empty():
		item_title.text = "还没有记录到证据" if journal_mode else "背包是空的"
		preview.texture = null
		detail.text = ""
	else:
		var first := maxi(0, item_ids.find(selected))
		item_list.select(first)
		_inspect(first)
	assemble.visible = not journal_mode and GameState.has_demo_item("service_grip") and GameState.has_demo_item("service_spindle")

func _inspect(index: int) -> void:
	var item_id := item_ids[index]
	if item_id.is_empty():
		item_title.text = "现场告示 · 图示对照"
		preview.texture = null
		notice_diagram.show()
		notice_diagram.queue_redraw()
		detail.position.y = 202
		detail.size.y = 98
		detail.text = journal_note
		return
	notice_diagram.hide()
	detail.position.y = 213
	detail.size.y = 65
	item_title.text = DemoItems.title(item_id)
	preview.texture = DemoItems.texture(item_id)
	detail.text = DemoItems.description(item_id)

func _draw_notice_diagram() -> void:
	var c := notice_diagram
	c.draw_rect(Rect2(0, 0, 330, 124), Color("16241e"), true)
	c.draw_rect(Rect2(0, 0, 330, 124), Color("7f7254"), false, 1.5)
	var font := get_theme_default_font()
	if "后视镜" in journal_note or "停车铃" in journal_note:
		# Visual bus carriage diagram with 5 numbered inspection points + front/rear door rules.
		c.draw_rect(Rect2(14, 14, 302, 64), Color("21332b"), true)
		c.draw_rect(Rect2(14, 14, 302, 64), Color("9a8a64"), false, 1.5)
		c.draw_rect(Rect2(18, 22, 34, 48), Color("3c2822"), true)
		c.draw_string(font, Vector2(22, 50), "后门", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f0c098"))
		c.draw_rect(Rect2(276, 22, 34, 48), Color("253f34"), true)
		c.draw_string(font, Vector2(280, 50), "前门", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("bfe3c8"))
		var spots := [
			[Vector2(256, 32), "①镜"],
			[Vector2(256, 62), "②币箱"],
			[Vector2(182, 32), "③报站"],
			[Vector2(124, 62), "④乘客"],
			[Vector2(76, 32), "⑤车窗"]
		]
		for s in spots:
			var pt: Vector2 = s[0]
			c.draw_circle(pt, 5.0, Color("e3c878"))
			c.draw_string(font, pt + Vector2(-14, 15), String(s[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ebe4cc"))
		c.draw_string(font, Vector2(14, 98), "● 见异象：先拉红铃 → 退后门", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f2b89b"))
		c.draw_string(font, Vector2(14, 116), "● 无异象：直接行去前门落车", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("b8dfc6"))
	else:
		# Visual coastal works route schematic (3 rooms: 潮水平台 -> 闸室白影 -> 调压廊).
		var nodes := [Vector2(54, 46), Vector2(165, 46), Vector2(276, 46)]
		var titles := ["① 潮水平台", "② 沿海闸室", "③ 调压廊"]
		c.draw_line(nodes[0], nodes[1], Color("c6b07c"), 3.0, true)
		c.draw_line(nodes[1], nodes[2], Color("c6b07c"), 3.0, true)
		for i in range(3):
			c.draw_circle(nodes[i], 13.0, Color("293d33"))
			c.draw_arc(nodes[i], 13.0, 0, TAU, 24, Color("dfc98b"), 2.0, true)
			c.draw_string(font, nodes[i] + Vector2(-34, 30), titles[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ece3c5"))
		c.draw_string(font, Vector2(18, 108), "沿高处干路与红粉笔箭头推进，避开低池积水。", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("cfd6c4"))

func _assemble() -> void:
	if GameState.assemble_service_handle():
		AudioManager.play_world_effect("lock_mechanism")
		_refresh("service_handle")
