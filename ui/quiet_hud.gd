extends CanvasLayer

signal close_requested
signal pause_requested
signal phone_requested
signal mode_requested(mode: int)

var root: Control
var objective: Label
var bottom_scrim: TextureRect
var prompt: Label
var prompt_scrim: PanelContainer
var state_text: Label
var state_scrim: PanelContainer
var toast: Label
var toast_panel: PanelContainer
var toast_time: float = 0.0
var modal: PanelContainer
var panel_content: Control
var panel_open: bool = false
var is_widget_modal: bool = false
var title_mark: TextureRect
var resources: Control
var panel_body: RichTextLabel
var page_hint: Label
var pages: Array[String] = []
var page_index: int = 0
var choice_count: int = 0
var choice_buttons: Array[Button] = []
var phone_keytip: Label
var phone_keytip_enabled := false
var resources_visible_preference := true
var defense_notice: Label
var defense_notice_time := 0.0
var default_phone_actor: PlayerController
var default_phone_widget: Control
var archive_page := ""
var journal_note := ""
var journal_note_provider := Callable()
var journal_page_factory := Callable()
var inventory_page_factory := Callable()
var recent_noise := PackedStringArray()
var live_noise_enabled := false
var live_noise_notice: Label
var live_noise_time := 0.0
const OFFER_HINT_AFTER := 60.0
var hint_actor: PlayerController
var hint_steps := PackedStringArray()
var hint_progress := 0
var hint_idle := 0.0
var hint_index := 0
var hint_duration := 0.0
var investigation_hint: Label
var bag_dock: Label
var bag_toast_panel: PanelContainer
var bag_toast_icon: TextureRect
var bag_toast_label: Label
var bag_toast_time := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.active_hud = self
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	var font := UiFont.song()
	theme.default_font = font
	theme.default_font_size = 14
	root.theme = theme
	add_child(root)
	var horror_fx := preload("res://core/components/horror_director.gd").new()
	horror_fx.name = "HorrorDirector"
	horror_fx.hud_ref = self
	root.add_child(horror_fx)
	resources = preload("res://ui/status_readout.gd").new()
	resources.position = Vector2(65, 25)
	resources.visible = resources_visible_preference
	root.add_child(resources)
	title_mark = TextureRect.new()
	title_mark.texture = preload("res://assets/ui/title_mark.png")
	title_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_mark.position = Vector2(470, 2)
	title_mark.size = Vector2(112, 38)
	title_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_mark)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.02, 0.04, 0.035, 0.0), Color(0.02, 0.045, 0.038, 0.66)])
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.5, 0.0)
	grad_tex.fill_to = Vector2(0.5, 1.0)
	grad_tex.width = 4
	grad_tex.height = 56
	bottom_scrim = TextureRect.new()
	bottom_scrim.texture = grad_tex
	bottom_scrim.position = Vector2(0, 304)
	bottom_scrim.size = Vector2(640, 56)
	bottom_scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bottom_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom_scrim)
	objective = label("", Vector2(65, 333), Vector2(510, 20), 12, Color("b9c1af"))
	state_scrim = PanelContainer.new()
	state_scrim.position = Vector2(58, 309)
	state_scrim.size = Vector2(460, 22)
	state_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s_skin := StyleBoxFlat.new()
	s_skin.bg_color = Color(0.03, 0.072, 0.058, 0.88)
	s_skin.border_color = Color(0.76, 0.65, 0.42, 0.65)
	s_skin.set_border_width_all(1)
	s_skin.set_corner_radius_all(3)
	state_scrim.add_theme_stylebox_override("panel", s_skin)
	state_scrim.hide()
	root.add_child(state_scrim)
	state_text = label("", Vector2(65, 312), Vector2(510, 20), 12, Color("f3e5b4"))
	prompt_scrim = PanelContainer.new()
	prompt_scrim.position = Vector2(160, 287)
	prompt_scrim.size = Vector2(320, 24)
	prompt_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p_skin := StyleBoxFlat.new()
	p_skin.bg_color = Color(0.03, 0.075, 0.06, 0.80)
	p_skin.border_color = Color(0.72, 0.64, 0.44, 0.56)
	p_skin.set_border_width_all(1)
	p_skin.set_corner_radius_all(3)
	prompt_scrim.add_theme_stylebox_override("panel", p_skin)
	prompt_scrim.hide()
	root.add_child(prompt_scrim)
	prompt = label("", Vector2(140, 289), Vector2(360, 22), 13, Color("ede8c2"))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_panel = PanelContainer.new()
	toast_panel.position = Vector2(90, 46)
	toast_panel.size = Vector2(460, 24)
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t_skin := StyleBoxFlat.new()
	t_skin.bg_color = Color(0.04, 0.095, 0.075, 0.88)
	t_skin.border_color = Color(0.78, 0.68, 0.44, 0.72)
	t_skin.set_border_width_all(1)
	t_skin.set_corner_radius_all(3)
	t_skin.content_margin_left = 10
	t_skin.content_margin_right = 10
	t_skin.content_margin_top = 3
	t_skin.content_margin_bottom = 3
	toast_panel.add_theme_stylebox_override("panel", t_skin)
	toast_panel.hide()
	root.add_child(toast_panel)
	toast = label("", Vector2.ZERO, Vector2(440, 18), 12, Color("efe2b4"), toast_panel)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phone_keytip = label("[ Q / Tab ] 嘉敏的手机", Vector2(226, 11), Vector2(210, 18), 11, Color("e6d093"))
	phone_keytip.hide()
	defense_notice = label("", Vector2(65, 46), Vector2(550, 19), 12, Color("e2d49d"))
	defense_notice.hide()
	EventBus.phone_defense_feedback.connect(show_resource_feedback)
	EventBus.flashlight_feedback.connect(show_resource_feedback)
	live_noise_notice = label("", Vector2(65, 88), Vector2(320, 20), 12, Color("e0d6b8"))
	live_noise_notice.hide()
	EventBus.noise_emitted.connect(_record_nearby_noise)
	investigation_hint = label("", Vector2(65, 112), Vector2(510, 34), 13, Color("ead8a1"))
	investigation_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	investigation_hint.add_theme_color_override("font_shadow_color", Color("101914"))
	investigation_hint.add_theme_constant_override("shadow_offset_y", 1)
	investigation_hint.hide()
	# Compact tactile backpack dock (shows count & currently taken-out/equipped item)
	bag_dock = label("", Vector2(436, 333), Vector2(188, 20), 11, Color("d8cca4"))
	bag_dock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bag_toast_panel = PanelContainer.new()
	bag_toast_panel.position = Vector2(416, 286)
	bag_toast_panel.size = Vector2(208, 42)
	bag_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bt_skin := StyleBoxFlat.new()
	bt_skin.bg_color = Color(0.05, 0.09, 0.075, 0.92)
	bt_skin.border_color = Color("b29d6a")
	bt_skin.set_border_width_all(1)
	bt_skin.set_corner_radius_all(3)
	bt_skin.content_margin_left = 8
	bt_skin.content_margin_right = 8
	bt_skin.content_margin_top = 4
	bt_skin.content_margin_bottom = 4
	bag_toast_panel.add_theme_stylebox_override("panel", bt_skin)
	bag_toast_panel.hide()
	root.add_child(bag_toast_panel)
	var bt_row := HBoxContainer.new()
	bt_row.add_theme_constant_override("separation", 8)
	bt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bag_toast_panel.add_child(bt_row)
	bag_toast_icon = TextureRect.new()
	bag_toast_icon.custom_minimum_size = Vector2(28, 28)
	bag_toast_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bag_toast_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bag_toast_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bt_row.add_child(bag_toast_icon)
	bag_toast_label = Label.new()
	bag_toast_label.add_theme_font_size_override("font_size", 11)
	bag_toast_label.add_theme_color_override("font_color", Color("efe2b4"))
	bag_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bt_row.add_child(bag_toast_label)
	EventBus.item_acquired.connect(_on_item_acquired_toast)
	modal = PanelContainer.new()
	modal.position = Vector2(5, 5)
	modal.size = Vector2(630, 176)
	modal.visible = false
	modal.gui_input.connect(_on_modal_gui_input)
	var style := StyleBoxTexture.new()
	style.texture = preload("res://assets/ui/dialogue_window.png")
	style.texture_margin_left = 6
	style.texture_margin_right = 6
	style.texture_margin_top = 6
	style.texture_margin_bottom = 6
	modal.add_theme_stylebox_override("panel", style)
	root.add_child(modal)
	panel_content = Control.new()
	panel_content.custom_minimum_size = Vector2(618, 164)
	modal.add_child(panel_content)

func label(text: String, at: Vector2, dimensions: Vector2, size_value: int = 14, color: Color = Color("e0e4d4"), parent: Control = null) -> Label:
	var node := Label.new()
	node.text = text
	node.position = at
	node.size = dimensions
	node.add_theme_font_size_override("font_size", size_value)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_shadow_color", Color("06120e"))
	node.add_theme_constant_override("shadow_offset_x", 1)
	node.add_theme_constant_override("shadow_offset_y", 1)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else root).add_child(node)
	return node

func make_button(text: String, at: Vector2, dimensions: Vector2, parent: Control) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color("e2e4d1"))
	button.add_theme_color_override("font_hover_color", Color("eee097"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.16, 0.13, 0.45)
	style.border_color = Color(0.35, 0.46, 0.38, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 8
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("244d3c")
	hover.border_color = Color("d8c78a")
	hover.content_margin_left = 14
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	parent.add_child(button)
	return button

static var _jiamin_portrait_cached: Texture2D = null
static var _ahhao_portrait_cached: Texture2D = null
static var _granny_portrait_cached: Texture2D = null
static var _uncle_portrait_cached: Texture2D = null
static var _dawen_expr_sheet_v10: Texture2D = null
static var _jiamin_expr_sheet_v10: Texture2D = null
static var _ahhao_expr_sheet_v10: Texture2D = null
static var _dawen_expr_sheet: Texture2D = null
static var _jiamin_expr_sheet: Texture2D = null

static func _detect_emotion(title: String, body: String, speaker: String = "") -> String:
	var combined := title + " " + body
	if speaker in ["阿豪", "黄梓豪", "黃梓豪"]:
		for kw in ["别管我", "快去救", "滑落", "倒在血泊", "姐……姐夫", "撑不住"]:
			if kw in combined:
				return "injured"
		for kw in ["快跑", "追", "尖叫", "鬼", "扑", "吓", "救命", "后面"]:
			if kw in combined:
				return "fear"
		for kw in ["我来", "挡住", "顶住", "一定要", "绝不", "合闸", "掩护"]:
			if kw in combined:
				return "determined"
		for kw in ["哈哈", "葡挞", "拍照", "出发", "打卡", "好啦", "逛街", "太棒", "走啦", "开心"]:
			if kw in combined:
				return "warm"
		for kw in ["不对", "奇怪", "听见", "怎么", "黑", "冷", "停电", "咔哒"]:
			if kw in combined:
				return "thinking"
		return "playful"
	for kw in ["阿豪呢", "没拉住", "对不起", "遇害", "倒在血泊", "闭环", "遗憾", "安息", "说不出话", "没能把阿豪", "再也回不来"]:
		if kw in combined:
			return "sad"
	for kw in ["尖叫", "白骨", "惨", "扑过来", "冲过来", "渗血", "破墙", "扑倒", "吓", "追上", "发抖", "恐怖", "溺水影", "剁骨刀", "血口", "怨灵"]:
		if kw in combined:
			return "fear"
	for kw in ["强闪", "拉闸", "突围", "锁定", "一定要", "绝不", "冲进", "反杀", "拆开", "赶过去", "修好", "撑住", "救她", "救出"]:
		if kw in combined:
			return "determined"
	for kw in ["葡挞", "拍照", "出发", "趁热", "笑", "好啦", "旅行", "一起", "久仰", "猪扒包", "天亮", "破晓", "海风"]:
		if kw in combined:
			return "warm"
	for kw in ["什么", "怎么", "竟然", "消失", "不对", "奇怪", "忙音", "异象", "谁", "不可能", "不见了"]:
		if kw in combined:
			return "surprised"
	for kw in ["线索", "记录", "核对", "档案", "旧闻", "鞋印", "工单", "支路", "台阶", "暗道", "推理", "判断"]:
		if kw in combined:
			return "thinking"
	return "normal"

static func _expr_atlas_grid(sheet: Texture2D, col: int, row: int, cols: int, rows: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = sheet
	var cw := sheet.get_width() / float(cols)
	var ch := sheet.get_height() / float(rows)
	a.region = Rect2(col * cw, row * ch, cw, ch)
	a.filter_clip = true
	return a

static func _get_emotional_portrait(speaker_name: String, emotion: String) -> Texture2D:
	if speaker_name in ["大文", "陈大文", ""]:
		if emotion == "normal":
			return preload("res://assets/ui/dawen_portrait_004.png")
		if _dawen_expr_sheet_v10 == null and ResourceLoader.exists("res://assets/ui/dawen_expressions_v10.png"):
			_dawen_expr_sheet_v10 = load("res://assets/ui/dawen_expressions_v10.png")
		if _dawen_expr_sheet_v10 != null:
			match emotion:
				"warm": return _expr_atlas_grid(_dawen_expr_sheet_v10, 0, 0, 3, 2)
				"thinking": return _expr_atlas_grid(_dawen_expr_sheet_v10, 1, 0, 3, 2)
				"surprised": return _expr_atlas_grid(_dawen_expr_sheet_v10, 2, 0, 3, 2)
				"fear": return _expr_atlas_grid(_dawen_expr_sheet_v10, 0, 1, 3, 2)
				"determined": return _expr_atlas_grid(_dawen_expr_sheet_v10, 1, 1, 3, 2)
				"sad": return _expr_atlas_grid(_dawen_expr_sheet_v10, 2, 1, 3, 2)
		if _dawen_expr_sheet == null and ResourceLoader.exists("res://assets/ui/dawen_expressions_v3.png"):
			_dawen_expr_sheet = load("res://assets/ui/dawen_expressions_v3.png")
		if _dawen_expr_sheet != null:
			match emotion:
				"surprised", "thinking": return _expr_atlas_grid(_dawen_expr_sheet, 0, 0, 2, 2)
				"fear": return _expr_atlas_grid(_dawen_expr_sheet, 1, 0, 2, 2)
				"determined": return _expr_atlas_grid(_dawen_expr_sheet, 0, 1, 2, 2)
				"sad": return _expr_atlas_grid(_dawen_expr_sheet, 1, 1, 2, 2)
		return preload("res://assets/ui/dawen_portrait_004.png")
	if speaker_name == "黄嘉敏":
		if emotion == "normal":
			return _get_default_npc_portrait(speaker_name)
		if _jiamin_expr_sheet_v10 == null and ResourceLoader.exists("res://assets/ui/jiamin_expressions_v10.png"):
			_jiamin_expr_sheet_v10 = load("res://assets/ui/jiamin_expressions_v10.png")
		if _jiamin_expr_sheet_v10 != null:
			match emotion:
				"warm": return _expr_atlas_grid(_jiamin_expr_sheet_v10, 0, 0, 3, 2)
				"thinking": return _expr_atlas_grid(_jiamin_expr_sheet_v10, 1, 0, 3, 2)
				"determined": return _expr_atlas_grid(_jiamin_expr_sheet_v10, 2, 0, 3, 2)
				"surprised": return _expr_atlas_grid(_jiamin_expr_sheet_v10, 0, 1, 3, 2)
				"fear": return _expr_atlas_grid(_jiamin_expr_sheet_v10, 1, 1, 3, 2)
				"sad": return _expr_atlas_grid(_jiamin_expr_sheet_v10, 2, 1, 3, 2)
		if _jiamin_expr_sheet == null and ResourceLoader.exists("res://assets/ui/jiamin_expressions_v3.png"):
			_jiamin_expr_sheet = load("res://assets/ui/jiamin_expressions_v3.png")
		if _jiamin_expr_sheet != null:
			match emotion:
				"warm": return _expr_atlas_grid(_jiamin_expr_sheet, 0, 0, 2, 2)
				"surprised", "determined", "thinking": return _expr_atlas_grid(_jiamin_expr_sheet, 1, 0, 2, 2)
				"fear": return _expr_atlas_grid(_jiamin_expr_sheet, 0, 1, 2, 2)
				"sad": return _expr_atlas_grid(_jiamin_expr_sheet, 1, 1, 2, 2)
		return _get_default_npc_portrait(speaker_name)
	if speaker_name in ["阿豪", "黄梓豪", "黃梓豪"]:
		# Keep ahhao_portrait_252.png for neutral/default checks (preserves player_feedback_251 assertion)
		if emotion == "normal" or emotion == "playful":
			return _get_default_npc_portrait(speaker_name)
		if _ahhao_expr_sheet_v10 == null and ResourceLoader.exists("res://assets/ui/ahhao_expressions_v10.png"):
			_ahhao_expr_sheet_v10 = load("res://assets/ui/ahhao_expressions_v10.png")
		if _ahhao_expr_sheet_v10 != null:
			match emotion:
				"warm": return _expr_atlas_grid(_ahhao_expr_sheet_v10, 0, 0, 3, 2)
				"thinking", "surprised": return _expr_atlas_grid(_ahhao_expr_sheet_v10, 2, 0, 3, 2)
				"fear": return _expr_atlas_grid(_ahhao_expr_sheet_v10, 0, 1, 3, 2)
				"determined": return _expr_atlas_grid(_ahhao_expr_sheet_v10, 1, 1, 3, 2)
				"injured", "sad": return _expr_atlas_grid(_ahhao_expr_sheet_v10, 2, 1, 3, 2)
		return _get_default_npc_portrait(speaker_name)
	return _get_default_npc_portrait(speaker_name)

func show_resources(enabled: bool) -> void:
	resources_visible_preference = enabled
	if is_instance_valid(resources):
		resources.visible = enabled and not panel_open

static func _get_default_npc_portrait(speaker_name: String) -> Texture2D:
	if speaker_name == "黄嘉敏":
		if _jiamin_portrait_cached == null and ResourceLoader.exists("res://assets/characters/jiamin_006.png"):
			var atlas := AtlasTexture.new()
			atlas.atlas = load("res://assets/characters/jiamin_006.png")
			atlas.region = Rect2(274, 13, 247, 309)
			_jiamin_portrait_cached = atlas
		return _jiamin_portrait_cached
	if speaker_name in ["阿豪", "黄梓豪", "黃梓豪"]:
		if _ahhao_portrait_cached == null:
			_ahhao_portrait_cached = preload("res://assets/ui/ahhao_portrait_252.png")
		return _ahhao_portrait_cached
	if speaker_name == "陈阿婆":
		if _granny_portrait_cached == null:
			_granny_portrait_cached = preload("res://assets/ui/granny_portrait_feedback.png")
		return _granny_portrait_cached
	if speaker_name == "梁伯":
		if _uncle_portrait_cached == null:
			_uncle_portrait_cached = preload("res://assets/ui/uncle_portrait_feedback.png")
		return _uncle_portrait_cached
	return null

var compact_ending := false

func _exit_tree() -> void:
	if GameState.active_hud == self:
		GameState.active_hud = null

func _on_modal_gui_input(event: InputEvent) -> void:
	if not panel_open or is_widget_modal:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if page_index < pages.size() - 1 or choice_count == 0:
			advance()
			modal.accept_event()

func open_panel(title: String, body: String, choices: Array = [], photo: bool = false, speaker: String = "陈大文", portrait: Texture2D = null, photo_texture: Texture2D = null) -> void:
	compact_ending = false
	is_widget_modal = false
	for child in panel_content.get_children():
		panel_content.remove_child(child)
		child.queue_free()
	panel_open = true
	modal.show()
	modal.modulate.a = 0.72
	var modal_fade := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	modal_fade.tween_property(modal, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE)
	title_mark.hide()
	resources.hide()
	prompt.hide()
	if is_instance_valid(bottom_scrim):
		bottom_scrim.hide()
	if is_instance_valid(state_scrim):
		state_scrim.hide()
	if is_instance_valid(prompt_scrim):
		prompt_scrim.hide()
	if is_instance_valid(toast_panel):
		toast_panel.hide()
	phone_keytip.hide()
	_set_background_stamps_visible(false)
	choice_count = choices.size()
	choice_buttons.clear()
	var use_keyboard_diagram := (title == "暂停")
	var content_height: float = (206 if use_keyboard_diagram else 164) if choice_count == 0 else ((188 if use_keyboard_diagram else 158) + choice_count * 36 + 22)
	modal.position = Vector2(5, 5)
	panel_content.custom_minimum_size = Vector2(618, content_height)
	modal.set_deferred("size", Vector2(630, content_height + 12))
	
	var is_protagonist := (speaker in ["大文", "陈大文", "黄嘉敏"] or speaker.is_empty())
	var emotion := _detect_emotion(title, body, speaker)
	var effective_portrait: Texture2D = portrait
	var is_ch6_jiamin_opening := (speaker == "黄嘉敏" and ("渗血石屎夹层" in title or "石屎封墙夹层" in title))
	if effective_portrait == null:
		effective_portrait = _get_default_npc_portrait(speaker) if is_ch6_jiamin_opening else _get_emotional_portrait(speaker, emotion)
	elif speaker == "黄嘉敏" and emotion != "normal" and not is_ch6_jiamin_opening:
		effective_portrait = _get_emotional_portrait(speaker, emotion)
	
	if is_protagonist:
		label(speaker if not speaker.is_empty() else "陈大文", Vector2(110, 11), Vector2(120, 23), 16, Color("e1d684"), panel_content)
		label(title, Vector2(235, 14), Vector2(350, 20), 12, Color("acbfa9"), panel_content)
	else:
		label(speaker, Vector2(24, 11), Vector2(140, 23), 16, Color("e1d684"), panel_content)
		label(title, Vector2(170, 14), Vector2(330, 20), 12, Color("acbfa9"), panel_content)
	
	if photo and photo_texture == null:
		make_archive_photo()
	else:
		var image := TextureRect.new()
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var chosen_tex: Texture2D = photo_texture if photo_texture != null else (effective_portrait if effective_portrait != null else (preload("res://assets/ui/dawen_portrait_004.png") if is_protagonist else null))
		image.texture = chosen_tex
		image.flip_h = speaker == "陈阿婆" and photo_texture == null
		if chosen_tex != null:
			var target_pos := Vector2(12, 40) if is_protagonist else Vector2(518, 40)
			image.position = target_pos + Vector2(0, 6)
			image.size = Vector2(90, 62) if photo_texture != null else Vector2(86, 108)
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel_content.add_child(image)
			var p_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			p_tween.tween_property(image, "position", target_pos, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			if emotion == "fear" and not GameState.reduced_flash and photo_texture == null:
				p_tween.tween_property(image, "position:x", target_pos.x + 2.5, 0.04)
				p_tween.tween_property(image, "position:x", target_pos.x - 2.5, 0.04)
				p_tween.tween_property(image, "position:x", target_pos.x + 1.5, 0.04)
				p_tween.tween_property(image, "position:x", target_pos.x, 0.04)
		else:
			image.free()
	
	var header_rule := ColorRect.new()
	header_rule.position = Vector2(110 if is_protagonist else 24, 34)
	header_rule.size = Vector2(495 if is_protagonist else 484, 1)
	header_rule.color = Color(0.55, 0.62, 0.52, 0.35)
	header_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_content.add_child(header_rule)

	panel_body = RichTextLabel.new()
	if is_protagonist:
		panel_body.position = Vector2(110, 40)
		panel_body.size = Vector2(495, 94)
	else:
		panel_body.position = Vector2(24, 40)
		panel_body.size = Vector2(484, 94)
	panel_body.fit_content = false
	panel_body.bbcode_enabled = false
	panel_body.scroll_active = false
	var body_font_size := 16 if GameState.large_dialogue_text else 14
	panel_body.add_theme_font_size_override("normal_font_size", body_font_size)
	panel_body.add_theme_color_override("default_color", Color("edf0e0"))
	panel_body.add_theme_constant_override("line_separation", 3)
	panel_content.add_child(panel_body)
	if use_keyboard_diagram:
		panel_body.hide()
		var kb := preload("res://ui/controls_keyboard.gd").new()
		kb.position = Vector2(106, 36)
		kb.size = Vector2(498, 146)
		panel_content.add_child(kb)
	pages = _paginate_dialogue(body, panel_body.get_theme_font("normal_font"), body_font_size, panel_body.size.x - 8.0)
	page_index = 0
	panel_body.text = pages[0]
	panel_body.visible_ratio = 0.0
	var reveal := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	reveal.tween_property(panel_body, "visible_ratio", 1.0, 0.14)
	var choice_y: float = 186 if use_keyboard_diagram else 142
	var choice_x: float = 110 if is_protagonist else 24
	var choice_w: float = 380 if is_protagonist else 470
	for choice in choices:
		var button := make_button(choice["text"], Vector2(choice_x, choice_y), Vector2(choice_w, 32), panel_content)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(AudioManager.play_dialogue_advance)
		button.pressed.connect(choice["callback"])
		choice_buttons.append(button)
		choice_y += 36
	page_hint = label("", Vector2(469, content_height - 18), Vector2(140, 16), 10, Color("a6baa7"), panel_content)
	update_page_hint()

func _paginate_dialogue(body: String, font: Font, font_size: int, width: float) -> Array[String]:
	var result: Array[String] = []
	var page_start := 0
	var index := 0
	var sentence_end := 0
	var line_start := 0
	var line_count := 1
	while index < body.length():
		var character := body[index]
		var wraps := character == "\n" or font.get_string_size(body.substr(line_start, index - line_start + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width
		if wraps and line_count >= 4:
			var page_end := sentence_end if sentence_end > page_start else index
			result.append(body.substr(page_start, page_end - page_start).strip_edges())
			index = page_end
			while index < body.length() and body[index] in ["\n", " ", "\t"]:
				index += 1
			page_start = index
			line_start = index
			line_count = 1
			continue
		if wraps:
			line_count += 1
			line_start = index + (1 if character == "\n" else 0)
		if character in ["。", "！", "？", "!", "?", "」", "”"] or (character == "\n" and index > 0 and body[index - 1] == "\n"):
			sentence_end = index + 1
		index += 1
	var remaining := body.substr(page_start).strip_edges()
	if not remaining.is_empty() or result.is_empty():
		result.append(remaining)
	return result

func update_page_hint() -> void:
	for button in choice_buttons:
		button.visible = page_index >= pages.size() - 1
	if GameState.touch_mode_active:
		page_hint.text = "轻触继续  ▼" if page_index < pages.size() - 1 else ("请点选选项" if choice_count > 0 else "轻触关闭  ▼")
	else:
		page_hint.text = "E 下一页  ▼" if page_index < pages.size()-1 else ("Esc 返回" if choice_count > 0 else "E 返回  ▼")
	if compact_ending and page_index >= pages.size() - 1:
		page_hint.text = ""

func apply_ending_letterbox_layout() -> void:
	compact_ending = true
	var content_h := 110.0
	var caption_font_size := 16 if GameState.large_dialogue_text else 14
	modal.position = Vector2(5, 234)
	panel_content.custom_minimum_size = Vector2(618, content_h)
	modal.set_deferred("size", Vector2(630, content_h + 12.0))
	for child in panel_content.get_children():
		if child is Label and child != page_hint:
			if child.text == "结局":
				child.hide()
			else:
				child.position.y = minf(child.position.y, 1.0)
				child.size.x = 580.0
		elif child is ColorRect:
			child.position = Vector2(20, 23)
			child.size = Vector2(578, 1)
		elif child is TextureRect:
			child.hide()
	if is_instance_valid(panel_body):
		panel_body.position = Vector2(20, 25)
		panel_body.size = Vector2(578, 57)
		panel_body.add_theme_font_size_override("normal_font_size", caption_font_size)
		panel_body.add_theme_constant_override("line_separation", 2)
	# Repaginate for 3 compact lines per page so text never clips inside 56px height
	var full_text := "\n".join(pages)
	pages.clear()
	var current := ""
	var line := ""
	var line_count := 1
	var font := root.get_theme_default_font()
	for character in full_text:
		var line_break: bool = character == "\n" or font.get_string_size(line + character, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_font_size).x > 564.0
		if line_break:
			if line_count >= 3:
				if not current.strip_edges().is_empty():
					pages.append(current.strip_edges())
				current = ""
				line_count = 1
				line = ""
				if character == "\n":
					continue
			else:
				line_count += 1
				line = ""
		current += character
		if character != "\n":
			line += character
	if not current.strip_edges().is_empty():
		pages.append(current.strip_edges())
	if pages.is_empty():
		pages.append("")
	page_index = 0
	if is_instance_valid(panel_body):
		panel_body.text = pages[0]
	var choice_x := 20.0
	for btn in choice_buttons:
		if is_instance_valid(btn):
			btn.position = Vector2(choice_x, 84)
			btn.size = Vector2(208, 24)
			btn.add_theme_font_size_override("font_size", 12)
			choice_x += 220.0
	if is_instance_valid(page_hint):
		page_hint.position = Vector2(468, content_h - 20.0)
	update_page_hint()

func make_archive_photo() -> void:
	# Compose an in-game archival view from the same room/furniture artwork.
	# The bed stands at its former position; no obsolete prototype art is shown.
	var clip := Control.new()
	clip.position = Vector2(12, 40)
	clip.size = Vector2(90, 72)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_content.add_child(clip)
	var stage := Node2D.new()
	stage.scale = Vector2(0.45, 0.45)
	clip.add_child(stage)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){vec4 c=texture(TEXTURE,UV);float g=dot(c.rgb,vec3(0.299,0.587,0.114));COLOR=vec4(g*vec3(1.08,0.99,0.79),c.a);}"
	var material := ShaderMaterial.new()
	material.shader = shader
	stage.material = material
	var background := Sprite2D.new()
	background.texture = preload("res://assets/tilesets/tanglau_room_003.png")
	background.centered = false
	background.scale = Vector2(640, 360) / background.texture.get_size()
	background.position = Vector2(-368, -64)
	background.use_parent_material = true
	stage.add_child(background)
	var patch := Sprite2D.new()
	var patch_texture := AtlasTexture.new()
	patch_texture.atlas = background.texture
	var factor: Vector2 = background.texture.get_size() / Vector2(640, 360)
	patch_texture.region = Rect2(Vector2(480, 184) * factor, Vector2(80, 32) * factor)
	patch.texture = patch_texture
	patch.centered = false
	patch.scale = Vector2(80, 32) / patch_texture.region.size
	patch.position = Vector2(22, 120)
	patch.use_parent_material = true
	stage.add_child(patch)
	var bed := Sprite2D.new()
	var bed_texture := AtlasTexture.new()
	bed_texture.atlas = preload("res://assets/props/furniture_atlas_003_source.png")
	bed_texture.region = Rect2(641, 25, 259, 467)
	bed.texture = bed_texture
	bed.centered = false
	bed.scale = Vector2(66, 90) / bed_texture.region.size
	bed.position = Vector2(37, 0)
	bed.use_parent_material = true
	stage.add_child(bed)

func advance() -> void:
	if is_instance_valid(panel_body) and panel_body.visible_ratio < 0.99:
		panel_body.visible_ratio = 1.0
	if page_index < pages.size()-1:
		AudioManager.play_dialogue_advance()
		page_index += 1
		panel_body.text = pages[page_index]
		panel_body.visible_ratio = 0.0
		var reveal := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		reveal.tween_property(panel_body, "visible_ratio", 1.0, 0.14)
		update_page_hint()
	elif choice_count == 0:
		AudioManager.play_dialogue_advance()
		close_requested.emit()

func open_widget(widget: Control, dimensions := Vector2(618, 330)) -> void:
	open_panel("", "")
	is_widget_modal = true
	archive_page = ""
	for child in panel_content.get_children():
		panel_content.remove_child(child)
		child.queue_free()
	choice_count = 1
	modal.position = Vector2(5, 5)
	panel_content.custom_minimum_size = dimensions
	modal.set_deferred("size", dimensions + Vector2(12, 12))
	widget.size = dimensions
	panel_content.add_child(widget)

func set_phone_keytip(enabled: bool) -> void:
	phone_keytip_enabled = enabled
	phone_keytip.visible = enabled and not panel_open and not GameState.touch_mode_active

func _set_background_stamps_visible(show_stamps: bool) -> void:
	if not is_instance_valid(root):
		return
	var known := [objective, state_text, prompt, toast, defense_notice, live_noise_notice, investigation_hint, bag_dock, phone_keytip]
	for child in root.get_children():
		if child is Label and child not in known:
			child.visible = show_stamps

func close_panel() -> void:
	panel_open = false
	is_widget_modal = false
	archive_page = ""
	modal.hide()
	title_mark.show()
	resources.visible = resources_visible_preference
	prompt.show()
	phone_keytip.visible = phone_keytip_enabled and not GameState.touch_mode_active
	_set_background_stamps_visible(true)

func notify(text: String) -> void:
	toast.text = text
	toast_time = 4.0

func show_resource_feedback(message: String) -> void:
	defense_notice.text = message
	defense_notice_time = 4.0

func set_investigation_hints(actor: PlayerController, steps: PackedStringArray, progress := 0) -> void:
	if hint_actor == actor and hint_steps == steps and hint_progress == progress:
		return
	hint_actor = actor
	hint_steps = steps
	hint_progress = progress
	hint_idle = 0.0
	hint_index = 0
	hint_duration = 0.0

func _hint_available() -> bool:
	return not panel_open and not get_tree().paused and not hint_steps.is_empty() and is_instance_valid(hint_actor) and hint_actor.controls_enabled and not hint_actor.hidden_in_wardrobe

func _update_investigation_hint(delta: float) -> void:
	investigation_hint.hide()
	if GameState.profile != "test":
		return
	if not _hint_available():
		return
	hint_duration = maxf(0.0, hint_duration - delta)
	if hint_duration > 0.0:
		investigation_hint.show()
	else:
		hint_idle += delta
		if hint_index == 0 and hint_idle >= OFFER_HINT_AFTER:
			investigation_hint.text = "[ H ] 查看调查提示"
			investigation_hint.show()

func _active_phone_actor(allow_locked := false) -> PlayerController:
	if GameState.current_role != "dawen" or not GameState.opening_flags.jiamin_phone_found or not GameState.has_demo_item("jiamin_phone"):
		return null
	var scene_root := get_parent()
	for candidate in get_tree().get_nodes_in_group("phone_flash_actor"):
		if candidate is PlayerController and scene_root.is_ancestor_of(candidate) and candidate.appearance not in ["jiamin", "ah_hao"]:
			if allow_locked or (candidate.controls_enabled and not candidate.hidden_in_wardrobe):
				return candidate
	return null

func _open_default_phone(actor: PlayerController, page: String) -> void:
	if not inventory_page_factory.is_valid():
		default_phone_actor = actor
	actor.controls_enabled = false
	actor.clear_motion()
	open_archive_page(page)
	get_tree().paused = true

func open_archive_page(page: String) -> void:
	var next: Control
	match page:
		"phone":
			next = make_phone()
		"map":
			next = preload("res://ui/demo_travel_map.gd").new()
			next.current_objective = objective.text
		"journal":
			if journal_page_factory.is_valid() and GameState.profile == "test":
				next = journal_page_factory.call()
			else:
				next = preload("res://ui/demo_bag.gd").new()
				next.journal_mode = true
				next.journal_note = journal_note_provider.call() if journal_note_provider.is_valid() else journal_note
		"inventory":
			next = inventory_page_factory.call() if inventory_page_factory.is_valid() else preload("res://ui/demo_bag.gd").new()
		"macau_guide":
			next = preload("res://ui/macau_guide_view.gd").new()
			next.back_requested.connect(open_archive_page.bind("phone"))
	if is_instance_valid(default_phone_actor):
		default_phone_widget = next
	open_widget(next)
	archive_page = page

func _close_default_phone() -> void:
	if is_instance_valid(default_phone_widget):
		default_phone_widget.queue_free()
	default_phone_widget = null
	archive_page = ""
	close_panel()
	get_tree().paused = false
	if is_instance_valid(default_phone_actor):
		default_phone_actor.controls_enabled = true
		default_phone_actor.clear_motion()
	default_phone_actor = null

func make_phone() -> Control:
	var phone = preload("res://ui/demo_phone.gd").new()
	phone.map_requested.connect(open_archive_page.bind("map"))
	phone.journal_requested.connect(open_archive_page.bind("journal"))
	phone.bag_requested.connect(open_archive_page.bind("inventory"))
	phone.macau_guide_requested.connect(open_archive_page.bind("macau_guide"))
	phone.recent_noise = recent_noise.duplicate()
	phone.live_noise_enabled = live_noise_enabled
	phone.live_noise_toggled.connect(_set_live_noise_enabled)
	return phone

func _set_live_noise_enabled(enabled: bool) -> void:
	live_noise_enabled = enabled
	if not enabled:
		live_noise_time = 0.0
		live_noise_notice.hide()

func _record_nearby_noise(origin: Vector2, radius: float, source_id: String) -> void:
	if get_tree().paused or radius <= 0.0 or GameState.current_role != "dawen":
		return
	var actor := _active_phone_actor(true)
	if not is_instance_valid(actor):
		return
	var distance := actor.global_position.distance_to(origin)
	if distance >= minf(radius, 160.0):
		return
	var level := clampi(ceili((radius - distance) / 28.0), 1, 5)
	var source: String = {"footstep":"脚步", "shaft_bucket_084":"水桶响动"}.get(source_id, "附近响动")
	var reading := "%s　%d / 5" % [source, level]
	recent_noise.insert(0, reading)
	if recent_noise.size() > 4:
		recent_noise.resize(4)
	if live_noise_enabled:
		live_noise_notice.text = "声强　" + reading
		live_noise_time = 2.0

func _process(delta: float) -> void:
	_update_investigation_hint(delta)
	if GameState.transition_save_failed and not panel_open and not get_tree().paused:
		GameState.transition_save_failed = false
		show_resource_feedback("进度保存失败，仍可继续。请检查存储空间和文件夹权限后重试。")
	if not get_tree().paused and not panel_open:
		defense_notice_time = maxf(0.0, defense_notice_time - delta)
	if not get_tree().paused:
		live_noise_time = maxf(0.0, live_noise_time - delta)
	defense_notice.visible = defense_notice_time > 0.0 and not panel_open
	live_noise_notice.visible = live_noise_time > 0.0 and not panel_open and GameState.current_role == "dawen"
	if toast_time > 0.0:
		toast_time = maxf(0.0, toast_time - delta)
	var show_toast := toast_time > 0.0 and not panel_open and not toast.text.is_empty()
	toast.visible = show_toast
	if is_instance_valid(toast_panel):
		toast_panel.visible = show_toast
		toast_panel.position.y = 70.0 if defense_notice.visible else 46.0
		toast_panel.modulate.a = clampf(toast_time / 0.45, 0.0, 1.0)
	if is_instance_valid(bottom_scrim):
		var show_bottom := not panel_open and (
			(objective.visible and not objective.text.is_empty())
			or (state_text.visible and not state_text.text.is_empty())
			or (is_instance_valid(bag_dock) and bag_dock.visible)
		)
		bottom_scrim.visible = show_bottom
	if is_instance_valid(state_scrim):
		var show_state := state_text.visible and not panel_open and not state_text.text.is_empty()
		state_scrim.visible = show_state
		if show_state:
			var s_font := root.get_theme_default_font()
			var sw: float = clampf(s_font.get_string_size(state_text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 20.0, 140.0, 535.0)
			state_scrim.size = Vector2(sw, 22.0)
			state_scrim.position = Vector2(state_text.position.x - 8.0, state_text.position.y - 2.0)
	if is_instance_valid(prompt_scrim):
		var show_prompt := prompt.visible and not panel_open and not prompt.text.is_empty()
		prompt_scrim.visible = show_prompt
		if show_prompt:
			var p_font := root.get_theme_default_font()
			var tw: float = clampf(p_font.get_string_size(prompt.text, HORIZONTAL_ALIGNMENT_CENTER, -1, 13).x + 28.0, 124.0, 356.0)
			prompt_scrim.size = Vector2(tw, 24.0)
			prompt_scrim.position = Vector2(prompt.position.x + (prompt.size.x - tw) * 0.5, prompt.position.y - 2.0)
	if bag_toast_time > 0.0:
		bag_toast_time = maxf(0.0, bag_toast_time - delta)
	if is_instance_valid(bag_toast_panel):
		bag_toast_panel.visible = bag_toast_time > 0.0 and not panel_open
	if is_instance_valid(title_mark):
		title_mark.visible = not panel_open and not GameState.touch_mode_active
	if is_instance_valid(resources):
		resources.position = Vector2(16, 40) if GameState.touch_mode_active else Vector2(65, 25)
	if is_instance_valid(bag_dock):
		var count := GameState.opening_items.size()
		if count > 0 and not panel_open and not GameState.touch_mode_active:
			var can_combine := GameState.has_demo_item("service_grip") and GameState.has_demo_item("service_spindle")
			var bag_prefix := "背包" if GameState.touch_mode_active else "[ B ] 背包"
			if can_combine:
				bag_dock.text = bag_prefix + " · ✦ 可组合手柄！"
				bag_dock.add_theme_color_override("font_color", Color("ffe38a"))
			else:
				bag_dock.text = bag_prefix + (" · %d 件物品" % count)
				bag_dock.add_theme_color_override("font_color", Color("d8cca4"))
			bag_dock.show()
		else:
			bag_dock.hide()

func _on_item_acquired_toast(item_id: String, _count: int) -> void:
	if not is_instance_valid(bag_toast_panel) or not DemoItems.ENTRIES.has(item_id):
		return
	bag_toast_icon.texture = DemoItems.texture(item_id)
	if item_id in ["service_grip", "service_spindle"] and GameState.has_demo_item("service_grip") and GameState.has_demo_item("service_spindle"):
		bag_toast_label.text = "零件已集齐！\n按 [ B ] 打开背包组合手柄"
		bag_toast_time = 4.6
		notify("已集齐「旧握柄」与「方轴」！请按 [ B ] 打开背包点击「立即组装」。")
	else:
		bag_toast_label.text = "收入背包：%s\n按 [ B ] 放大查看或使用" % DemoItems.title(item_id)
		bag_toast_time = 3.2

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("investigation_hint") and _hint_available():
		investigation_hint.text = hint_steps[hint_index] + ("　[ H ] 下一条" if hint_index < hint_steps.size() - 1 else "")
		hint_index = mini(hint_index + 1, hint_steps.size() - 1)
		hint_duration = 8.0
		get_viewport().set_input_as_handled()
		return
	var requested_page := ""
	for page in ["phone", "map", "journal", "inventory"]:
		if event.is_action_pressed(page):
			requested_page = page
			break
	if panel_open and (event.is_action_pressed("pause") or not requested_page.is_empty()):
		for child in panel_content.get_children():
			if child.has_method("close_subview") and child.close_subview():
				get_viewport().set_input_as_handled()
				return
	if panel_open and not archive_page.is_empty() and (event.is_action_pressed("pause") or not requested_page.is_empty()):
		get_viewport().set_input_as_handled()
		if requested_page.is_empty() or requested_page == "phone" or requested_page == archive_page:
			if is_instance_valid(default_phone_widget):
				_close_default_phone()
			else:
				close_requested.emit()
		else:
			open_archive_page(requested_page)
		return
	if not panel_open and not requested_page.is_empty():
		var actor := _active_phone_actor()
		if is_instance_valid(actor):
			get_viewport().set_input_as_handled()
			if requested_page == "phone" and not phone_requested.get_connections().is_empty():
				phone_requested.emit()
			else:
				_open_default_phone(actor, requested_page)
			return
		if is_instance_valid(_active_phone_actor(true)):
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if panel_open:
			close_requested.emit()
		else:
			pause_requested.emit()
	elif panel_open and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		advance()
	elif panel_open and event.is_action_pressed("phone") and phone_keytip_enabled:
		get_viewport().set_input_as_handled()
		phone_requested.emit()
	elif panel_open and (event.is_action_pressed("phone") or event.is_action_pressed("journal") or event.is_action_pressed("map") or event.is_action_pressed("inventory")):
		get_viewport().set_input_as_handled()
		close_requested.emit()
	elif panel_open:
		get_viewport().set_input_as_handled()
