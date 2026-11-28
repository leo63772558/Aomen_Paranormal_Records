extends Control

signal recording_verified
signal phone_open_requested

const JOURNAL_ITEMS := [
	"old_304_photo", "power_record", "wet_tag", "crypt_old_photo", "crypt_survey",
	"crypt_doodle", "interview_index", "gate_work_order", "stair_rubbing", "bunker_recording",
	"w17_bus_ticket", "laochen_handoff_note", "jiamin_lens_cap", "jiamin_severed_finger", "ahhao_camera",
	"shoe_repair_photo", "hotel_maintenance_plan"
]
# Items that can be zoomed / opened interactively inside the backpack
const INSPECTABLE_ITEMS := [
	"jiamin_phone", "trip_map", "old_304_photo", "power_record", "wet_tag", "crypt_old_photo", "crypt_survey",
	"crypt_doodle", "interview_index", "gate_work_order", "stair_rubbing", "w17_bus_ticket",
	"laochen_handoff_note", "shoe_repair_photo", "hotel_maintenance_plan", "ahhao_camera",
	"jiamin_lens_cap", "jiamin_severed_finger", "multitool_pliers", "service_handle"
]
const EQUIPABLE_ITEMS := [
	"multitool_pliers", "service_handle", "oil", "loose_stone", "ahhao_camera",
	"gate_key_1", "gate_key_2", "gate_key_3", "archive_spare_key", "beach_cabinet_key"
]
const TAPE_AUDIO_PATH := "res://assets/audio/v6/voice/jiamin_bunker_tape_v6.wav"
const TAPE_PLAY_LABEL := "▶ 打开双轨录音机（A/B面）"
const TAPE_STOP_LABEL := "■ 关闭录音机"
const TAPE_TRANSCRIPT := "【正在播放嘉敏的防空洞录音】\n「……阿豪……阿豪你在哪……楼梯口站着三个穿红衣的人……正门被从外面锁死了，我退进里面试着找排风竖井绕去大关斜巷……」"
const TIMETABLE_BACK_NOTE := "【时刻表背面 · 嘉敏匆忙写下的圆珠笔字迹】\n「大文、阿豪：\n大关斜巷后面有拿着剁骨刀的东西在追我。手机早落在 304 了，我只能先去亚马喇前地搭唯一亮灯的 33 路末班车往路环求援！如果你们看到这页纸，千万小心车上的怪事……」"
const CHAPTER_GUIDE_ID := "__chapter_guide__"
const FOLKLORE_CODEX_ID := "__folklore_codex__"
const FOLKLORE_CODEX_SUMMARY := "【主线逃生链】嘉敏在福荣里304听见封门异响被卷入地底，沿途借旧城暗道求生留痕；阿豪在唐楼后廊断后牺牲，大文循迹一路追查至百利新邨地基。\n● 点击下方「放大查看完整七章诡谈档案」可查阅每关鬼怪对应的澳门都市传说。"
const FOLKLORE_CODEX_FULL := """福荣里 304　〔虚构〕
旧照拍到了后来从图纸上消失的一扇门。福荣里旧酒店取材于澳门唐楼。

大三巴地宫　〔地标与传闻〕
有人说看见黑袍老人招手，也有人说灯下只有白骨。牌坊与墓室是场景参考，地下路线为虚构。

松山防空洞　〔传闻〕
街坊说深夜会多出十级石阶，身后传来的声音还认得你的名字。三道红衣影是游戏改编。

大关斜巷旧肉铺　〔虚构〕
店铺关门后，半句粤剧和剁骨声仍会从门缝传出来。现实旧案的剪报另行记录。

雾桥 33 路　〔虚构〕
起雾以后，车厢里只剩报站声。游戏中的车次和站点按剧情改编。

黑沙海滩　〔地标与传闻〕
海里传来的哭声像熟人。海滩是场景参考，救援车与海边的异常是游戏改编。

石屎封墙夹层　〔虚构〕
墙补过之后，夜里仍有人听见敲击。地下路线和工事文书均为虚构。"""

var journal_mode: bool = false
var journal_note: String = ""
var item_list: ItemList
var item_title: Label
var detail: RichTextLabel
var preview: TextureRect
var preview_btn: Button
var waveform_bar: Control
var assemble: Button
var play_tape_btn: Button
var inspect_btn: Button
var equip_btn: Button
var action_row: HBoxContainer
var combo_banner: PanelContainer
var combo_label: Label
var tape_player: AudioStreamPlayer
var subview_layer: Control
var lightbox_flipped: bool = false
var item_ids: Array[String] = []
var current_item_id: String = ""
var tape_playing: bool = false
var wave_phase: float = 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var header := Label.new()
	header.text = "随身背包 · 线索" if journal_mode else "随身背包"
	header.position = Vector2(16, 8)
	header.add_theme_font_size_override("font_size", 17)
	header.add_theme_color_override("font_color", Color("ecd99f"))
	add_child(header)
	var back_hint := Label.new()
	back_hint.text = "Esc / J 返回" if journal_mode else "Esc / B 返回"
	back_hint.position = Vector2(510, 11)
	back_hint.add_theme_font_size_override("font_size", 12)
	back_hint.add_theme_color_override("font_color", Color("b2c2b4"))
	back_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back_hint)

	var guide_btn := Button.new()
	guide_btn.name = "MacauGuideBagButton"
	guide_btn.text = "✦ 澳门见闻 (%d/%d)" % [GameState.macau_guide_unlocked.size(), MacauGuide.total_count()]
	guide_btn.position = Vector2(362, 7)
	guide_btn.size = Vector2(138, 24)
	_style_action_button(guide_btn)
	guide_btn.pressed.connect(_open_macau_guide_subview)
	add_child(guide_btn)

	item_list = ItemList.new()
	item_list.position = Vector2(16, 40)
	item_list.size = Vector2(235, 274)
	item_list.fixed_icon_size = Vector2i(34, 34)
	item_list.add_theme_constant_override("v_separation", 5)
	item_list.item_selected.connect(_inspect)
	item_list.item_activated.connect(func(_idx: int): _on_primary_inspect())
	add_child(item_list)

	item_title = Label.new()
	item_title.position = Vector2(268, 40)
	item_title.size = Vector2(334, 24)
	item_title.add_theme_font_size_override("font_size", 15)
	item_title.add_theme_color_override("font_color", Color("efe0ae"))
	add_child(item_title)

	preview = TextureRect.new()
	preview.position = Vector2(268, 68)
	preview.size = Vector2(334, 128)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preview)

	# Clickable hitbox over preview image so clicking any map/photo/document zooms/opens it!
	preview_btn = Button.new()
	preview_btn.position = preview.position
	preview_btn.size = preview.size
	preview_btn.focus_mode = Control.FOCUS_NONE
	preview_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	preview_btn.text = ""
	preview_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var phover := StyleBoxFlat.new()
	phover.bg_color = Color(0.95, 0.88, 0.68, 0.08)
	phover.border_color = Color("d8be7a", 0.55)
	phover.set_border_width_all(1)
	preview_btn.add_theme_stylebox_override("hover", phover)
	preview_btn.add_theme_stylebox_override("pressed", phover)
	preview_btn.pressed.connect(_on_primary_inspect)
	add_child(preview_btn)

	waveform_bar = Control.new()
	waveform_bar.position = Vector2(268, 166)
	waveform_bar.size = Vector2(334, 26)
	waveform_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	waveform_bar.draw.connect(_draw_cassette_waveform)
	waveform_bar.hide()
	add_child(waveform_bar)

	detail = RichTextLabel.new()
	detail.position = Vector2(268, 200)
	detail.size = Vector2(334, 70)
	detail.add_theme_font_size_override("normal_font_size", 13)
	detail.add_theme_constant_override("line_separation", 2)
	detail.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(detail)

	# Interactive Action Bar (Zoom/Open Map/Flip Back/Play Tape/Equip)
	action_row = HBoxContainer.new()
	action_row.position = Vector2(268, 276)
	action_row.size = Vector2(334, 30)
	action_row.add_theme_constant_override("separation", 8)
	add_child(action_row)

	inspect_btn = Button.new()
	inspect_btn.text = "放大查看"
	inspect_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_action_button(inspect_btn)
	inspect_btn.pressed.connect(_on_primary_inspect)
	action_row.add_child(inspect_btn)

	play_tape_btn = Button.new()
	play_tape_btn.text = TAPE_PLAY_LABEL
	play_tape_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_action_button(play_tape_btn)
	play_tape_btn.pressed.connect(_on_play_tape_pressed)
	play_tape_btn.hide()
	action_row.add_child(play_tape_btn)

	equip_btn = Button.new()
	equip_btn.text = "取出手持"
	equip_btn.custom_minimum_size = Vector2(96, 28)
	_style_action_button(equip_btn)
	equip_btn.pressed.connect(_on_equip_pressed)
	equip_btn.hide()
	action_row.add_child(equip_btn)

	# Dedicated golden workbench banner shown when combinable parts are owned
	combo_banner = PanelContainer.new()
	combo_banner.position = Vector2(268, 276)
	combo_banner.size = Vector2(334, 36)
	var cskin := StyleBoxFlat.new()
	cskin.bg_color = Color(0.14, 0.21, 0.14, 0.96)
	cskin.border_color = Color("e2c478")
	cskin.set_border_width_all(1)
	cskin.set_corner_radius_all(3)
	cskin.content_margin_left = 8
	cskin.content_margin_right = 6
	combo_banner.add_theme_stylebox_override("panel", cskin)
	combo_banner.hide()
	add_child(combo_banner)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 8)
	combo_banner.add_child(crow)
	combo_label = Label.new()
	combo_label.text = "✦ 可组合：旧握柄 + 方轴"
	combo_label.add_theme_font_size_override("font_size", 11)
	combo_label.add_theme_color_override("font_color", Color("f2dc98"))
	combo_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crow.add_child(combo_label)
	assemble = Button.new()
	assemble.text = "立即组装"
	assemble.custom_minimum_size = Vector2(88, 24)
	_style_action_button(assemble)
	assemble.pressed.connect(_assemble)
	crow.add_child(assemble)

	tape_player = AudioStreamPlayer.new()
	tape_player.bus = "Voice"
	tape_player.process_mode = Node.PROCESS_MODE_ALWAYS
	tape_player.volume_db = -3.0
	tape_player.finished.connect(_on_tape_finished)
	add_child(tape_player)

	_refresh()

func _process(delta: float) -> void:
	if tape_playing and is_instance_valid(waveform_bar) and waveform_bar.visible:
		wave_phase += delta * 7.2
		waveform_bar.queue_redraw()

func _style_action_button(btn: Button) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color("f4e6b8"))
	btn.add_theme_color_override("font_hover_color", Color("fff6d4"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.24, 0.19, 0.94)
	normal.border_color = Color("cfa964")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("264d3c")
	hover.border_color = Color("f4df9b")
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)

func _current_chapter_guide() -> Dictionary:
	var room := GameState.current_room_id
	if room.begins_with("ch6_"):
		return {
			"title": "终章档案 · 百利新邨渗血石屎夹层",
			"tex": DemoItems.texture("hotel_maintenance_plan"),
			"body": "嘉敏可以用钢管传声。切回大文后，先看墙上的管线图，再试一组与旧暗号不同的节奏。听哪一路回应了你刚才敲的节拍。\n需要撤离时，可以直接带嘉敏走。核对齐五组故事档案还会解锁完整结局。"
		}
	elif room.begins_with("ch5_"):
		return {
			"title": "第五章档案 · 路环黑沙海滩与沿海暗渠",
			"tex": DemoItems.texture("shoe_repair_photo"),
			"body": "黑沙的救援车远光能挡住白影。用修鞋照的右跟缺角辨认鞋印，再看海草和潮线盖住了哪一道痕迹。\n进沿海工事后，找地面较高、能避开回流的路。"
		}
	elif room.begins_with("ch4_"):
		return {
			"title": "第四章档案 · 末班车后门告示",
			"tex": DemoItems.texture("w17_bus_ticket"),
			"body": "这辆 33 路一直在雾里兜圈。后门贴着一张旧告示。"
		}
	elif room.begins_with("ch3_"):
		return {
			"title": "第三章档案 · 大关斜巷旧肉铺后间",
			"tex": DemoItems.texture("laochen_handoff_note"),
			"body": "【现场笔记】破旧收音机里飘着沙哑的粤剧唱腔，嘉敏曾在此躲避持剁骨刀的屠夫怨灵。\n● 破关要点：先检查冷柜门与桌上司马十六两杆秤账册（半斤八两），找齐铜权在旧杆秤上配平取出方牌备用钥匙与 33 路时刻表，遇到屠夫破门时利用中岛台周旋脱身。"
		}
	elif room.begins_with("ch2_"):
		return {
			"title": "第二章档案 · 松山防空洞与九十九级鬼阶",
			"tex": DemoItems.texture("stair_rubbing"),
			"body": "山脚有旧维修箱。检查钥匙刻痕，再对照铁链和挂锁。\n子弹房里有嘉敏的录音机。内侧石阶走到重复出现的缺角时，面朝深处，沿来路倒退回机房。脱险后复听两面录音，核对她去了哪里。"
		}
	elif room.begins_with("ch1_"):
		return {
			"title": "第一章档案 · 大三巴圣保禄地宫",
			"tex": DemoItems.texture("crypt_old_photo"),
			"body": "街坊都说见过黑袍老人，谁也说不清他去了哪里。\n在地宫找巡查旧照、孩童涂鸦和测绘描图，分别比对凿痕、封龛物件与维护门。石廊里，手电照中黑袍人时可以边照边退。"
		}
	return {
		"title": "序章档案 · 福荣里唐楼 304 与雨夜街口",
		"tex": DemoItems.texture("old_304_photo"),
		"body": "出发前，看看台灯下的旧合照和桌上的澳门路线图。到了澳门，可向街坊打听福荣里。\n进楼后，按工单检查电表箱的支路。到了 304，再拿旧照对照现在的床脚和地砖。"
	}

func _refresh(selected: String = "") -> void:
	_stop_tape_playback(false)
	item_ids.clear()
	item_list.clear()
	if journal_mode:
		item_ids.append(CHAPTER_GUIDE_ID)
		var cg := _current_chapter_guide()
		item_list.add_item("★ 当前章节线索与调查手记", cg["tex"])
		item_ids.append(FOLKLORE_CODEX_ID)
		item_list.add_item("★ 澳门七大诡谈与鬼怪图鉴", DemoItems.texture("trip_map"))
	var available_ids: Array = JOURNAL_ITEMS if journal_mode else DemoItems.ENTRIES.keys()
	for raw_id in available_ids:
		var item_id: String = String(raw_id)
		if GameState.has_demo_item(item_id):
			item_ids.append(item_id)
			item_list.add_item(DemoItems.title(item_id), DemoItems.texture(item_id))
	var can_combine: bool = not journal_mode and GameState.has_demo_item("service_grip") and GameState.has_demo_item("service_spindle")
	combo_banner.visible = can_combine
	assemble.visible = can_combine
	if item_ids.is_empty():
		item_title.text = "还没有记录到证据" if journal_mode else "背包是空的"
		preview.texture = null
		preview_btn.hide()
		detail.text = ""
		waveform_bar.hide()
		action_row.hide()
	else:
		var first: int = maxi(0, item_ids.find(selected))
		item_list.select(first)
		_inspect(first)

func _apply_right_pane_layout(can_play_tape: bool, has_actions: bool) -> void:
	var has_combo := combo_banner.visible
	var bottom_reserved := 0.0
	if has_combo:
		combo_banner.position = Vector2(268, 280)
		combo_banner.size = Vector2(334, 34)
		bottom_reserved += 40.0
	if has_actions:
		action_row.visible = true
		action_row.position = Vector2(268, 280 - bottom_reserved)
		action_row.size = Vector2(334, 28)
		bottom_reserved += 34.0
	else:
		action_row.visible = false

	var content_bottom := 312.0 - bottom_reserved
	if can_play_tape and tape_playing:
		preview.position = Vector2(268, 66)
		preview.size = Vector2(334, maxf(64.0, content_bottom - 178.0))
		waveform_bar.position = Vector2(268, preview.position.y + preview.size.y + 4.0)
		waveform_bar.size = Vector2(334, 24)
		waveform_bar.show()
		detail.position = Vector2(268, waveform_bar.position.y + 28.0)
		detail.size = Vector2(334, maxf(54.0, content_bottom - detail.position.y))
	else:
		waveform_bar.hide()
		var prev_h := clampf((content_bottom - 68.0) * 0.56, 80.0, 128.0)
		preview.position = Vector2(268, 68)
		preview.size = Vector2(334, prev_h)
		detail.position = Vector2(268, preview.position.y + prev_h + 6.0)
		detail.size = Vector2(334, maxf(48.0, content_bottom - detail.position.y))
	preview_btn.position = preview.position
	preview_btn.size = preview.size

func _inspect(index: int) -> void:
	var item_id: String = item_ids[index]
	if item_id != current_item_id and tape_playing:
		_stop_tape_playback(false)
	current_item_id = item_id
	if item_id == CHAPTER_GUIDE_ID:
		waveform_bar.hide()
		var cg := _current_chapter_guide()
		item_title.text = String(cg["title"])
		preview.texture = cg["tex"]
		var extra_note := ("\n● 现场提示：" + journal_note) if not journal_note.is_empty() else ""
		detail.text = String(cg["body"]) + extra_note
		preview_btn.visible = false
		play_tape_btn.visible = false
		equip_btn.visible = false
		inspect_btn.visible = false
		_apply_right_pane_layout(false, false)
		if GameState.current_room_id == "ch4_bus_loop" and not journal_note.is_empty():
			detail.text = journal_note
			preview.size.y = 54.0
			detail.position.y = preview.position.y + preview.size.y + 6.0
			detail.size.y = 312.0 - detail.position.y
		return
	if item_id == FOLKLORE_CODEX_ID:
		waveform_bar.hide()
		item_title.text = "澳门七大诡谈与鬼怪图鉴 · 主线串联"
		preview.texture = DemoItems.texture("trip_map")
		detail.text = FOLKLORE_CODEX_SUMMARY
		preview_btn.visible = true
		play_tape_btn.visible = false
		equip_btn.visible = false
		inspect_btn.visible = true
		inspect_btn.text = "放大查看完整七章诡谈档案"
		_apply_right_pane_layout(false, true)
		return
	item_title.text = DemoItems.title(item_id)
	preview.texture = DemoItems.texture(item_id)
	detail.text = TAPE_TRANSCRIPT if (item_id == "bunker_recording" and tape_playing) else DemoItems.description(item_id)

	var can_play_tape: bool = (item_id == "bunker_recording")
	var can_inspect: bool = item_id in INSPECTABLE_ITEMS
	var can_equip: bool = false

	preview_btn.visible = can_inspect or can_play_tape
	play_tape_btn.visible = can_play_tape
	play_tape_btn.text = TAPE_PLAY_LABEL
	inspect_btn.visible = can_inspect
	if item_id == "jiamin_phone":
		inspect_btn.text = "打开嘉敏的手机"
	elif item_id == "trip_map":
		inspect_btn.text = "展开全幅澳门互动地图"
	elif item_id == "w17_bus_ticket":
		inspect_btn.text = "放大 / 翻看背面留言"
	elif item_id == "old_304_photo" or item_id == "shoe_repair_photo" or item_id == "crypt_old_photo":
		inspect_btn.text = "放大细看照片"
	else:
		inspect_btn.text = "放大检视细节"
	equip_btn.visible = can_equip
	if can_equip:
		equip_btn.text = "收起道具" if GameState.equipped_item_id == item_id else "取出手持"

	_apply_right_pane_layout(can_play_tape, can_play_tape or can_inspect or can_equip)

func _on_equip_pressed() -> void:
	if current_item_id.is_empty():
		return
	if GameState.equipped_item_id == current_item_id:
		GameState.equipped_item_id = ""
	else:
		GameState.equipped_item_id = current_item_id
	AudioManager.play_effect("click")
	_refresh(current_item_id)

func _on_primary_inspect() -> void:
	if current_item_id.is_empty() or is_instance_valid(subview_layer):
		return
	if current_item_id == "bunker_recording":
		_on_play_tape_pressed()
	elif current_item_id == "jiamin_phone":
		_open_phone_subview()
	elif current_item_id == "trip_map":
		_open_interactive_map()
	elif current_item_id == FOLKLORE_CODEX_ID:
		_open_folklore_codex_lightbox()
	elif current_item_id in INSPECTABLE_ITEMS:
		_open_item_lightbox(current_item_id)

func _open_folklore_codex_lightbox() -> void:
	AudioManager.play_dialogue_advance()
	var sz := size if size.x > 10.0 else Vector2(618.0, 330.0)
	var overlay := PanelContainer.new()
	overlay.position = Vector2.ZERO
	overlay.size = sz
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.035, 0.055, 0.048, 0.99)
	st.border_color = Color("b69f68")
	st.set_border_width_all(1)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	overlay.add_theme_stylebox_override("panel", st)
	add_child(overlay)
	subview_layer = overlay
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	overlay.add_child(vbox)
	var top := HBoxContainer.new()
	vbox.add_child(top)
	var t_lbl := Label.new()
	t_lbl.text = "《澳诡实录》主线叙事与澳门七大都市传说鬼怪全录"
	t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_lbl.add_theme_font_size_override("font_size", 14)
	t_lbl.add_theme_color_override("font_color", Color("f0dc9e"))
	top.add_child(t_lbl)
	var back_btn := Button.new()
	back_btn.text = "返回背包 [ Esc ]"
	back_btn.custom_minimum_size = Vector2(106, 22)
	_style_action_button(back_btn)
	back_btn.pressed.connect(close_subview)
	top.add_child(back_btn)
	var body_text := RichTextLabel.new()
	body_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_text.add_theme_font_size_override("normal_font_size", 12)
	body_text.add_theme_constant_override("line_separation", 3)
	body_text.add_theme_color_override("default_color", Color("e4e8d6"))
	body_text.text = FOLKLORE_CODEX_FULL
	vbox.add_child(body_text)

func _open_phone_subview() -> void:
	if phone_open_requested.get_connections().size() > 0:
		phone_open_requested.emit()
		return
	AudioManager.play_dialogue_advance()
	var container := Control.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.size = size if size.x > 10.0 else Vector2(618.0, 330.0)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(container)
	subview_layer = container
	var phone_widget := preload("res://ui/demo_phone.gd").new()
	phone_widget.size = container.size
	phone_widget.bag_requested.connect(close_subview)
	phone_widget.macau_guide_requested.connect(func():
		close_subview()
		_open_macau_guide_subview()
	)
	phone_widget.map_requested.connect(func():
		close_subview()
		_open_interactive_map()
	)
	container.add_child(phone_widget)
	var close_btn := Button.new()
	close_btn.text = "← 返回背包"
	close_btn.position = Vector2(14, 8)
	close_btn.size = Vector2(76, 22)
	_style_action_button(close_btn)
	close_btn.add_theme_font_size_override("font_size", 10)
	close_btn.pressed.connect(close_subview)
	container.add_child(close_btn)

func _open_macau_guide_subview() -> void:
	AudioManager.play_dialogue_advance()
	var container := Control.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.size = size if size.x > 10.0 else Vector2(618.0, 330.0)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(container)
	subview_layer = container
	var guide_view := preload("res://ui/macau_guide_view.gd").new()
	guide_view.size = container.size
	guide_view.back_requested.connect(close_subview)
	container.add_child(guide_view)

func _draw() -> void:
	if is_instance_valid(preview) and preview.texture != null:
		var r := Rect2(preview.position - Vector2(3, 3), preview.size + Vector2(6, 6))
		draw_rect(r, Color(0.04, 0.07, 0.055, 0.72), true)
		draw_rect(r, Color("4a6152", 0.75), false, 1.0)
		var arm := 9.0
		var bc := Color("d6b872", 0.92)
		for pt in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
			var sx := 1.0 if pt.x == r.position.x else -1.0
			var sy := 1.0 if pt.y == r.position.y else -1.0
			draw_line(pt, pt + Vector2(sx * arm, 0.0), bc, 1.6)
			draw_line(pt, pt + Vector2(0.0, sy * arm), bc, 1.6)

func _open_interactive_map() -> void:
	AudioManager.play_dialogue_advance()
	var container := Control.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.size = size if size.x > 10.0 else Vector2(618.0, 330.0)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(container)
	subview_layer = container
	var map_widget := preload("res://ui/demo_travel_map.gd").new()
	map_widget.size = container.size
	container.add_child(map_widget)
	var close_btn := Button.new()
	close_btn.text = "← 返回背包"
	close_btn.position = Vector2(536, 4)
	close_btn.size = Vector2(74, 21)
	_style_action_button(close_btn)
	close_btn.add_theme_font_size_override("font_size", 10)
	close_btn.pressed.connect(close_subview)
	container.add_child(close_btn)

func _open_item_lightbox(item_id: String) -> void:
	AudioManager.play_dialogue_advance()
	lightbox_flipped = false
	var sz := size if size.x > 10.0 else Vector2(618.0, 330.0)
	var overlay := PanelContainer.new()
	overlay.position = Vector2.ZERO
	overlay.size = sz
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.035, 0.055, 0.048, 1.0)
	st.border_color = Color("b69f68")
	st.set_border_width_all(1)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	overlay.add_theme_stylebox_override("panel", st)
	add_child(overlay)
	subview_layer = overlay

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	overlay.add_child(vbox)

	var top := HBoxContainer.new()
	vbox.add_child(top)
	var t_lbl := Label.new()
	t_lbl.text = "细看物品 · " + DemoItems.title(item_id)
	t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_lbl.add_theme_font_size_override("font_size", 15)
	t_lbl.add_theme_color_override("font_color", Color("f0dc9e"))
	top.add_child(t_lbl)

	var body_text := RichTextLabel.new()
	body_text.fit_content = false
	body_text.custom_minimum_size = Vector2(0, 54)
	body_text.add_theme_font_size_override("normal_font_size", 12)
	body_text.add_theme_color_override("default_color", Color("e4e8d6"))
	body_text.text = DemoItems.description(item_id)

	var img := TextureRect.new()
	img.texture = DemoItems.texture(item_id)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.size_flags_vertical = Control.SIZE_EXPAND_FILL
	img.custom_minimum_size = Vector2(0, 198)

	if item_id == "w17_bus_ticket":
		var flip_btn := Button.new()
		flip_btn.text = "翻看背面手写字"
		flip_btn.custom_minimum_size = Vector2(116, 24)
		_style_action_button(flip_btn)
		flip_btn.pressed.connect(func():
			lightbox_flipped = not lightbox_flipped
			AudioManager.play_dialogue_advance()
			if lightbox_flipped:
				flip_btn.text = "翻回正面时刻表"
				img.modulate = Color(0.55, 0.50, 0.44, 0.55)
				body_text.text = TIMETABLE_BACK_NOTE
				body_text.custom_minimum_size = Vector2(0, 108)
			else:
				flip_btn.text = "翻看背面手写字"
				img.modulate = Color.WHITE
				body_text.text = DemoItems.description(item_id)
				body_text.custom_minimum_size = Vector2(0, 54)
		)
		top.add_child(flip_btn)

	var back_btn := Button.new()
	back_btn.text = "返回背包 [ Esc ]"
	back_btn.custom_minimum_size = Vector2(106, 24)
	_style_action_button(back_btn)
	back_btn.pressed.connect(close_subview)
	top.add_child(back_btn)

	vbox.add_child(img)
	vbox.add_child(body_text)

func close_subview() -> bool:
	if is_instance_valid(subview_layer):
		subview_layer.queue_free()
		subview_layer = null
		return true
	return false

func _on_play_tape_pressed() -> void:
	if is_instance_valid(subview_layer):
		return
	_open_tape_deck_subview()

func _open_tape_deck_subview() -> void:
	AudioManager.play_dialogue_advance()
	var container := Control.new()
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	subview_layer = container
	var tape_board := preload("res://ui/bunker_tape_board.gd").new()
	tape_board.size = container.size
	tape_board.embedded_in_bag = true
	tape_board.verified.connect(func():
		if GameState.current_chapter_id == "ch2_guia_tunnel":
			GameState.opening_flags.bunker_recording_verified = true
		recording_verified.emit()
	)
	container.add_child(tape_board)
	var close_btn := Button.new()
	close_btn.text = "← 返回背包"
	close_btn.position = Vector2(520, 4)
	close_btn.size = Vector2(78, 22)
	_style_action_button(close_btn)
	close_btn.add_theme_font_size_override("font_size", 10)
	close_btn.pressed.connect(close_subview)
	container.add_child(close_btn)

func _on_tape_finished() -> void:
	if tape_playing:
		_stop_tape_playback(true)

func _stop_tape_playback(restore_detail: bool) -> void:
	tape_playing = false
	if is_instance_valid(tape_player):
		if tape_player.playing:
			tape_player.stop()
	if is_instance_valid(play_tape_btn):
		play_tape_btn.text = TAPE_PLAY_LABEL
	if is_instance_valid(waveform_bar):
		waveform_bar.hide()
	if restore_detail and current_item_id == "bunker_recording" and is_instance_valid(detail):
		detail.text = DemoItems.description("bunker_recording")
		_apply_right_pane_layout(not journal_mode, true)

func _draw_cassette_waveform() -> void:
	var c: Control = waveform_bar
	var sz: Vector2 = c.size
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.06, 0.11, 0.09, 0.96), true)
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color("c8ac68"), false, 1.0)
	var spool_center := Vector2(14.0, sz.y * 0.5)
	var spool_r: float = minf(7.0, sz.y * 0.34)
	c.draw_circle(spool_center, spool_r, Color(0.14, 0.22, 0.17, 1.0))
	c.draw_arc(spool_center, spool_r, 0.0, TAU, 16, Color("e6cf8e"), 1.2, true)
	for spoke in range(3):
		var ang: float = wave_phase * 0.65 + float(spoke) * (TAU / 3.0)
		c.draw_line(spool_center, spool_center + Vector2(cos(ang), sin(ang)) * (spool_r - 1.5), Color("f2dc98"), 1.2, true)
	var rec_alpha: float = 0.55 + 0.45 * sin(wave_phase * 0.9)
	c.draw_circle(Vector2(29.0, sz.y * 0.5), 2.8, Color(0.92, 0.25, 0.22, rec_alpha))
	var bar_count: int = 26
	var start_x: float = 40.0
	var avail_w: float = sz.x - start_x - 46.0
	var step_w: float = avail_w / float(bar_count)
	var bar_w: float = maxf(3.0, step_w - 3.0)
	var max_h: float = sz.y - 8.0
	var mid_y: float = sz.y * 0.5
	for i in range(bar_count):
		var fi: float = float(i)
		var energy: float = 0.22 + 0.78 * absf(sin(wave_phase * 1.15 + fi * 0.52) * cos(wave_phase * 0.68 - fi * 0.29))
		var h: float = maxf(3.0, max_h * energy)
		var bar_col: Color = Color("f6e09a").lerp(Color("b68d3a"), 1.0 - energy)
		c.draw_rect(Rect2(start_x + fi * step_w, mid_y - h * 0.5, bar_w, h), bar_col, true)
	var elapsed: float = tape_player.get_playback_position() if (is_instance_valid(tape_player) and tape_player.playing) else fmod(wave_phase / 7.2, 60.0)
	var font: Font = get_theme_default_font()
	var time_str: String = "00:%02d" % int(elapsed)
	c.draw_string(font, Vector2(sz.x - 38.0, sz.y * 0.5 + 4.0), time_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e6cf8e"))

func _assemble() -> void:
	if GameState.assemble_service_handle():
		AudioManager.play_world_effect("use_install_snap")
		_refresh("service_handle")

func _exit_tree() -> void:
	tape_playing = false
	if is_instance_valid(tape_player):
		tape_player.stop()
		tape_player.stream = null
