extends Control

signal map_requested
signal journal_requested
signal bag_requested
signal live_noise_toggled(enabled: bool)
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

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	phone_bg = load("res://assets/ui/jiamin_phone_011.png")
	ahhao_tex = load("res://assets/ui/ahhao_portrait_252.png")
	jiamin_tex = hud_jiamin_portrait()
	shoe_tex = DemoItems.texture("shoe_repair_photo")

	var heading := Label.new()
	heading.text = "嘉敏的手机  ·  离线终端"
	heading.position = Vector2(18, 6)
	heading.add_theme_font_size_override("font_size", 17)
	heading.add_theme_color_override("font_color", Color("e8dcb5"))
	add_child(heading)

	var footer := Label.new()
	footer.text = "Q / Tab / Esc 返回"
	footer.position = Vector2(482, 10)
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color("b4c2b5"))
	add_child(footer)

	battery_status = Label.new()
	battery_status.position = Vector2(36, 40)
	battery_status.add_theme_font_size_override("font_size", 12)
	battery_status.add_theme_color_override("font_color", Color("c6e3c8"))
	add_child(battery_status)

	charge_button = _make_styled_button(
		"接电充能" if GameState.at_phone_preparation() else "入口处可接电",
		Vector2(458, 36), Vector2(138, 26), Color("1b3329")
	)
	charge_button.disabled = not GameState.at_phone_preparation()
	charge_button.pressed.connect(func():
		GameState.recharge_preparation()
		_refresh_battery()
		queue_redraw()
	)
	add_child(charge_button)
	_refresh_battery()

	# Chat Bubble 1: Ah Hao WeChat message
	_add_chat_bubble(
		Vector2(24, 74), Vector2(376, 72),
		ahhao_tex, "阿豪 · 出发前微信",
		"姐，金巴票订好啦！下车先吃安德鲁葡挞，再去探福荣里304！",
		Color("1a2e25"), Color("496b58"), false
	)

	# Chat Bubble 2: Jiamin unsent draft in 304
	_add_chat_bubble(
		Vector2(24, 154), Vector2(376, 80),
		jiamin_tex, "嘉敏 · 304 未发送草稿",
		"大文！铁床后真是通往大三巴地底的暗道！\n里面有人在敲「两短一长」，我进去看一眼！",
		Color("2a1f21"), Color("8c4b45"), true
	)

	var reduce := CheckButton.new()
	reduce.position = Vector2(444, 240)
	reduce.size = Vector2(154, 26)
	reduce.text = "减弱强闪画面"
	reduce.add_theme_font_size_override("font_size", 11)
	reduce.button_pressed = GameState.reduced_flash
	reduce.toggled.connect(GameState.set_reduced_flash)
	add_child(reduce)

	var map := _make_styled_button("行程地图", Vector2(18, 276), Vector2(96, 36), Color("182c24"))
	map.pressed.connect(func(): map_requested.emit())
	add_child(map)

	var journal := _make_styled_button("证据手札", Vector2(121, 276), Vector2(96, 36), Color("182c24"))
	journal.pressed.connect(func(): journal_requested.emit())
	add_child(journal)

	var bag := _make_styled_button("随身背包", Vector2(224, 276), Vector2(96, 36), Color("182c24"))
	bag.pressed.connect(func(): bag_requested.emit())
	add_child(bag)

	var shoe := _make_styled_button("原有照片 · 鞋底维修", Vector2(327, 276), Vector2(178, 36), Color("22352b"))
	shoe.pressed.connect(_show_shoe_photo)
	add_child(shoe)

	var meter := _make_styled_button("声强表", Vector2(512, 276), Vector2(86, 36), Color("182c24"))
	meter.name = "NoiseMeter"
	meter.pressed.connect(_show_noise_meter)
	add_child(meter)

func hud_jiamin_portrait() -> Texture2D:
	if ResourceLoader.exists("res://assets/characters/jiamin_006.png"):
		var atlas := AtlasTexture.new()
		atlas.atlas = load("res://assets/characters/jiamin_006.png")
		atlas.region = Rect2(274, 13, 247, 309)
		return atlas
	return null

func _make_styled_button(caption: String, at: Vector2, sz: Vector2, bg: Color) -> Button:
	var btn := Button.new()
	btn.text = caption
	btn.position = at
	btn.size = sz
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color("e7ebd8"))
	btn.add_theme_color_override("font_hover_color", Color("f4df9b"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = Color("526b5c")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.16)
	hover.border_color = Color("e3cd8b")
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	return btn

func _add_chat_bubble(at: Vector2, sz: Vector2, avatar_tex: Texture2D, sender: String, msg: String, bg: Color, border: Color, unsent: bool) -> void:
	var card := Control.new()
	card.position = at
	card.size = sz
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)

	if avatar_tex != null:
		var av := TextureRect.new()
		av.texture = avatar_tex
		av.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		av.position = Vector2(8, 10)
		av.size = Vector2(44, 52)
		av.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(av)

	var title := Label.new()
	title.text = sender + ("  [ ! 未发出 ]" if unsent else "")
	title.position = Vector2(60, 6)
	title.size = Vector2(sz.x - 68, 18)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color("f29b8e") if unsent else Color("dfc98b"))
	card.add_child(title)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	body.position = Vector2(60, 25)
	body.size = Vector2(sz.x - 70, sz.y - 28)
	body.text = msg
	body.add_theme_font_size_override("font_size", 11)
	body.add_theme_color_override("font_color", Color("e4e8d8"))
	card.add_child(body)

func _draw() -> void:
	var font := get_theme_default_font()
	# Background glass screen & cracked smartphone preview card on the right
	draw_rect(Rect2(16, 32, 584, 206), Color(0.05, 0.10, 0.08, 0.92))
	draw_rect(Rect2(16, 32, 584, 206), Color("3c5245"), false, 1.0)
	# Status bar icons (Signal SOS + Battery bar)
	draw_rect(Rect2(24, 43, 8, 10), Color("c95b4d"))
	# Draw chat bubble boxes
	draw_rect(Rect2(24, 74, 376, 72), Color("16261f"))
	draw_rect(Rect2(24, 74, 376, 72), Color("466353"), false, 1.0)
	draw_rect(Rect2(24, 154, 376, 80), Color("261a1c"))
	draw_rect(Rect2(24, 154, 376, 80), Color("874943"), false, 1.0)

	# Right-side Polaroid preview card of the shoe repair photo + phone frame
	draw_rect(Rect2(410, 74, 182, 160), Color("121e19"))
	draw_rect(Rect2(410, 74, 182, 160), Color("5b6e5d"), false, 1.0)
	draw_string(font, Vector2(418, 89), "相册预存 · 靴底缺角照", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("d8ca98"))
	if shoe_tex != null:
		draw_rect(Rect2(418, 95, 166, 98), Color("0a0f0d"))
		draw_texture_rect(shoe_tex, Rect2(422, 98, 158, 92), false)
	draw_string(font, Vector2(418, 210), "嘉敏登山靴：右跟三角缺口", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("d7decb"))
	draw_string(font, Vector2(418, 226), "[R] 强闪防身 (眩晕恶灵 2.5s)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e2c678"))
	draw_string(font, Vector2(20, 256), "无网络服务 · 已缓存离线地图、手札、相册与声波监测", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("9ab0a1"))

func _refresh_battery() -> void:
	battery_status.text = "无服务 · 电量 %d%% · 强闪 %d / 2 次" % [roundi(GameState.phone_battery), GameState.phone_flash_charges]

func _show_shoe_photo() -> void:
	if is_instance_valid(photo_cover) or is_instance_valid(meter_cover):
		return
	GameState.take_demo_item("shoe_repair_photo")
	var cover := PanelContainer.new()
	photo_cover = cover
	cover.position = Vector2(12, 36)
	cover.size = Vector2(592, 238)
	add_child(cover)
	var column := VBoxContainer.new()
	cover.add_child(column)
	var image := TextureRect.new()
	image.texture = DemoItems.texture("shoe_repair_photo")
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(580, 196)
	column.add_child(image)
	var back := Button.new()
	back.text = "照片已收进证据背包 · 返回离线资料"
	back.pressed.connect(_close_shoe_photo)
	column.add_child(back)

func _close_shoe_photo() -> void:
	if is_instance_valid(photo_cover):
		photo_cover.queue_free()
	photo_cover = null

func _show_noise_meter() -> void:
	if is_instance_valid(photo_cover) or is_instance_valid(meter_cover):
		return
	meter_cover = PanelContainer.new()
	meter_cover.position = Vector2(12, 36)
	meter_cover.size = Vector2(592, 285)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("17251e")
	background.border_color = Color("778a73")
	background.set_border_width_all(1)
	background.content_margin_left = 14
	background.content_margin_right = 14
	background.content_margin_top = 12
	background.content_margin_bottom = 12
	meter_cover.add_theme_stylebox_override("panel", background)
	add_child(meter_cover)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	meter_cover.add_child(column)
	var heading := Label.new()
	heading.text = "声强表 · 附近环境声波监测"
	heading.add_theme_font_size_override("font_size", 18)
	column.add_child(heading)
	var scale_hint := Label.new()
	scale_hint.text = "1 弱 · 5 强（脚步、易拉罐、管道敲击）"
	scale_hint.add_theme_font_size_override("font_size", 12)
	column.add_child(scale_hint)
	var history := Label.new()
	history.text = "附近暂未记录到响动" if recent_noise.is_empty() else "\n".join(recent_noise)
	history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(history)
	var toggle := CheckButton.new()
	toggle.name = "LiveNoise"
	toggle.text = "返回现场后显示实时声强"
	toggle.button_pressed = live_noise_enabled
	toggle.toggled.connect(func(enabled: bool):
		live_noise_enabled = enabled
		live_noise_toggled.emit(enabled)
	)
	column.add_child(toggle)
	var back := Button.new()
	back.text = "返回离线资料"
	back.pressed.connect(close_subview)
	column.add_child(back)

func close_subview() -> bool:
	if is_instance_valid(meter_cover):
		meter_cover.queue_free()
		meter_cover = null
		return true
	if is_instance_valid(photo_cover):
		_close_shoe_photo()
		return true
	return false
