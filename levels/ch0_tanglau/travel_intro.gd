extends Node2D

@export_enum("work", "home", "bus") var stage := "work"
var player: PlayerController
var hud
var girl: StaticBody2D
var active_target := ""
var after_panel: Callable
var targets := {}
var bus_dialogue: PanelContainer
var bus_stage := 0
var bus_back_sprite: Sprite2D
var bus_words: Label
var bus_coin_btn: Button
var bus_next_btn: Button
var bridge_fx: Node2D
var bus_layer: CanvasLayer
var home_photo: Sprite2D
var home_photo_frame: Polygon2D
var arrival_transition := false

func _ready() -> void:
	AudioManager.set_scene_ambience("transit" if stage == "bus" else "home")
	var backgrounds := {"work":"hk_work_026", "home":"hk_home_029", "bus":"bridge_bus_026"}
	var back := Sprite2D.new()
	back.name = "Background"
	back.texture = load("res://assets/tilesets/%s.png" % backgrounds[stage])
	back.centered = false
	back.scale = Vector2(640, 360) / back.texture.get_size()
	add_child(back)
	bus_back_sprite = back
	if stage == "home":
		_create_home_photo_overlay()
	if stage == "bus":
		_create_bus_controls()
		return
	LevelGeometry.room_bounds(self, 175 if stage == "work" else 156)
	if stage == "work":
		LevelGeometry.wall(self, Rect2(92, 156, 166, 27))
		targets = {
			"bench": [Vector2(172, 191), "整理工作台"],
			"board": [Vector2(388, 182), "看值班板"],
			"exit": [Vector2(527, 181), "回家"]
		}
		if GameState.opening_flags.intro_job_done:
			_show_jiamin()
	else:
		LevelGeometry.wall(self, Rect2(63, 139, 189, 22))
		LevelGeometry.wall(self, Rect2(286, 132, 141, 29))
		LevelGeometry.wall(self, Rect2(456, 139, 43, 17))
		targets = {
			"photo": [Vector2(196, 147), "摊开旧合照"],
			"map": [Vector2(344, 172), "和嘉敏看澳门路线图"],
			"exit": [Vector2(544, 166), "收拾行李，翌日出发"]
		}
		_show_jiamin(Vector2(390, 193), false)
	player = preload("res://entities/player/player.tscn").instantiate()
	player.position = Vector2(171, 223) if stage == "work" else Vector2(475, 228)
	player.visual_size_multiplier = 1.65
	player.allow_flashlight = false
	player.flashlight_on = false
	add_child(player)
	player.reset_physics_interpolation()
	hud = preload("res://ui/quiet_hud.gd").new()
	add_child(hud)
	hud.show_resources(false)
	hud.close_requested.connect(_close)
	hud.pause_requested.connect(_pause)
	var location_label := "香港 · 工程维修间" if stage == "work" else "香港 · 大文家 · 出发前夜"
	var chapter_stamp: Label = hud.label(location_label, Vector2(20, 16), Vector2(340, 30), 15, Color("e6d6ac"))
	hud.root.move_child(chapter_stamp, 0)
	_refresh_objective()
	if not GameState.opening_load_notice.is_empty():
		hud.notify(GameState.opening_load_notice)
		GameState.opening_load_notice = ""
	if stage == "home" and GameState.pending_entry_id == "from_work":
		_play_home_arrival()

func _play_home_arrival() -> void:
	arrival_transition = true
	player.controls_enabled = false
	var layer := CanvasLayer.new()
	layer.layer = 25
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color("121914")
	shade.size = Vector2(640, 360)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
	var caption: Label = hud.label("香港 · 大文家\n出发前夜", Vector2(60, 137), Vector2(520, 86), 19, Color("eadcbd"), shade)
	caption.add_theme_font_override("font", hud.root.get_theme_default_font())
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var transition := create_tween()
	transition.tween_interval(0.65)
	transition.tween_property(caption, "modulate:a", 0.0, 0.20).set_trans(Tween.TRANS_SINE)
	transition.tween_property(shade, "modulate:a", 0.0, 0.65).set_trans(Tween.TRANS_SINE)
	transition.tween_callback(func():
		layer.queue_free()
		arrival_transition = false
		player.controls_enabled = not hud.panel_open
	)

func _create_home_photo_overlay() -> void:
	var photo_texture: Texture2D = DemoItems.texture("old_304_photo")
	if photo_texture == null:
		push_warning("Home scene photo texture is unavailable; background print remains visible.")
		return
	# Place the physical old photo neatly on the wooden desk tabletop right beside the lamp
	# (NEVER sitting over the wooden chair backrest below the desk lip!).
	var photo_center := Vector2(204.0, 119.0)
	var frame := Polygon2D.new()
	frame.name = "OldPhotoFrame"
	frame.position = photo_center
	frame.rotation = deg_to_rad(-3.2)
	frame.polygon = PackedVector2Array([Vector2(-12, -7.5), Vector2(12, -7.5), Vector2(12, 7.5), Vector2(-12, 7.5)])
	frame.color = Color("cbb98f")
	frame.z_index = 2
	add_child(frame)
	home_photo_frame = frame
	var photo_area := Area2D.new()
	photo_area.name = "OldPhotoInteractionArea"
	photo_area.position = photo_center
	photo_area.collision_layer = 8
	photo_area.collision_mask = 2
	photo_area.monitoring = true
	photo_area.monitorable = true
	photo_area.set_meta("interactable_id", "old_304_photo")
	var photo_area_shape := CollisionPolygon2D.new()
	photo_area_shape.name = "PhotoBounds"
	photo_area_shape.polygon = PackedVector2Array([Vector2(-14, -9), Vector2(14, -9), Vector2(14, 9), Vector2(-14, 9)])
	photo_area.add_child(photo_area_shape)
	photo_area.z_index = 4
	add_child(photo_area)
	home_photo = Sprite2D.new()
	home_photo.name = "OldPhotoUnderLamp"
	home_photo.texture = photo_texture
	home_photo.position = photo_center
	home_photo.rotation = frame.rotation
	home_photo.z_index = 3
	var photo_size := Vector2(20.0, 12.5)
	home_photo.scale = Vector2(photo_size.x / photo_texture.get_width(), photo_size.y / photo_texture.get_height())
	add_child(home_photo)
	var settle := create_tween()
	settle.set_parallel(true)
	settle.tween_property(home_photo_frame, "rotation", 0.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	settle.tween_property(home_photo, "rotation", 0.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _target_label(id: String) -> String:
	if stage == "home":
		match id:
			"photo":
				return "检查台灯下的旧合照" if not GameState.opening_flags.intro_photo_seen else "重看旧合照"
			"map":
				return "查看澳门手绘路线图" if not GameState.opening_flags.intro_plan_seen else "重看澳门手绘路线图"
			"exit":
				if not GameState.opening_flags.intro_photo_seen and not GameState.opening_flags.intro_plan_seen:
					return "先看左侧台灯下的旧合照，再查看路线图"
				if not GameState.opening_flags.intro_photo_seen:
					return "先查看左侧台灯下的旧合照"
				if not GameState.opening_flags.intro_plan_seen:
					return "先查看桌上的澳门路线图"
				return "离开家，按计划出发"
	if id == "exit" and stage == "work" and not GameState.opening_flags.intro_invited:
		return "嘉敏还在等你，先和她说话"
	return str(targets[id][1])

func _show_jiamin(at := Vector2(444, 207), can_talk := true) -> void:
	if is_instance_valid(girl):
		return
	girl = StaticBody2D.new()
	girl.position = at
	girl.collision_layer = 1
	girl.collision_mask = 2
	girl.z_index = int(girl.position.y)
	var feet := CircleShape2D.new()
	feet.radius = 11.0
	var body := CollisionShape2D.new()
	body.shape = feet
	girl.add_child(body)
	var pose: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://core/data/opening_art.json"))
	var sprite := PoseArt.sprite(load("res://assets/characters/jiamin_006.png"), pose.girl[2])
	sprite.scale = Vector2.ONE * (float(pose.girl[2]["scale"]) * 1.65)
	girl.add_child(sprite)
	add_child(girl)
	if can_talk:
		targets["invite"] = [girl.position + Vector2(0, 12), "和嘉敏说话"]

func _process(_delta: float) -> void:
	if not is_instance_valid(hud) or hud.panel_open:
		return
	active_target = ""
	var reach := 45.0
	for id in targets:
		var distance := player.position.distance_to(targets[id][0])
		if distance < reach:
			reach = distance
			active_target = id
	hud.prompt.text = "[ E ] " + _target_label(active_target) if not active_target.is_empty() else ""

func _unhandled_input(event: InputEvent) -> void:
	if arrival_transition:
		return
	if stage == "bus":
		if event.is_action_pressed("interact") and not event.is_echo():
			get_viewport().set_input_as_handled()
			match bus_stage:
				0: _board_transmac_bus()
				1: _pay_bus_fare()
				2: _arrive()
		return
	if hud.panel_open or event.is_echo():
		return
	if event.is_action_pressed("interact") and not active_target.is_empty():
		get_viewport().set_input_as_handled()
		interact_intro(active_target)
	elif event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		_widget(preload("res://ui/demo_bag.gd").new())
	elif event.is_action_pressed("map") and GameState.has_demo_item("trip_map"):
		get_viewport().set_input_as_handled()
		_widget(preload("res://ui/demo_travel_map.gd").new())

func _checkpoint() -> void:
	if not GameState.save_opening_checkpoint():
		hud.show_resource_feedback("进度保存失败，仍可继续。请检查存储空间和文件夹权限后重试。")

func interact_intro(id: String) -> void:
	match id:
		"bench":
			if not GameState.opening_flags.intro_job_done:
				GameState.opening_flags.intro_job_done = true
				AudioManager.play_world_effect("metal_cover")
				_checkpoint()
				_show_jiamin()
				AudioManager.play_world_effect("entrance_door")
				_say("香港 · 工程维修间", "陈大文收起自己的工具钳，在值班表上划掉最后一项。门口传来脚步，有人轻轻敲了两下。")
			else:
				_say("工作台", "工具钳已经收进背包。按 B 可以查看。")
		"board":
			_say("维修班 · 陈大文", "最后一单已经结工。明后两天休假。")
		"invite":
			if GameState.opening_flags.intro_invited:
				_say("下班之后", "走吧，回去给你看阿豪找到的照片。", "黄嘉敏")
				return
			GameState.opening_flags.intro_invited = true
			_checkpoint()
			_say_sequence([
				{"title": "下班之后", "speaker": "黄嘉敏", "body": "明天陪我去澳门玩两天好不好？阿豪在旧报馆翻到了福荣旧酒店 304 失踪案的底片。"},
				{"title": "旧楼传闻", "speaker": "陈大文", "body": "又是你那个民俗专栏？网上说什么床底秘道有黑袍老伯变成白骨，全是编来吓人的。"},
				{"title": "同行约定", "speaker": "黄嘉敏", "body": "所以才要带陈大工程师去揭秘呀！走嘛，回家给你看那张 304 旧照和我整理的手绘怪谈地图。"}
			])
		"photo":
			GameState.opening_flags.intro_photo_seen = true
			GameState.take_demo_item("old_304_photo")
			_checkpoint()
			var photo: Texture2D = DemoItems.texture("old_304_photo")
			_photo(photo)
		"map":
			GameState.opening_flags.intro_plan_seen = true
			GameState.take_demo_item("trip_map")
			_checkpoint()
			_widget(preload("res://ui/demo_travel_map.gd").new())
		"exit":
			if stage == "work":
				if GameState.opening_flags.intro_invited:
					_move_to("ch0_hk_home", "from_work")
				else:
					_say("收工", "先把工具收好。有人在门口等你。" if GameState.opening_flags.intro_job_done else "值班表还有最后一项，先回工作台。")
			elif GameState.opening_flags.intro_photo_seen and GameState.opening_flags.intro_plan_seen:
				_say_sequence([
					{"title": "出发前夜", "speaker": "黄嘉敏", "body": "旧照片带上，到了 304 好对照。阿豪去拱北买镜头配件了。明早他带着补光灯，在大三巴街口等我们。"},
					{"title": "出发前夜", "speaker": "陈大文", "body": "好。车票、工具钳和手电都收好了。明早坐金巴过桥，到澳门口岸再换车。"}
				], 0, func(): _move_to("ch0_bridge_bus", "from_home"))
			else:
				_say("门边行李", "嘉敏把 304 旧照放在台灯下，金巴车票和手绘路线图还摊在饭桌上。")
	_refresh_objective()

func _photo(texture: Texture2D) -> void:
	var board := Control.new()
	_widget(board)
	hud.label("福荣里三楼旧合照", Vector2(18, 7), Vector2(380, 24), 16, Color("e8d8a2"), board)
	hud.label("Esc 返回", Vector2(530, 8), Vector2(72, 22), 12, Color("c1c8b3"), board)
	
	# Photo card container on the left (vintage archival 3:2 frame)
	var photo_card := PanelContainer.new()
	photo_card.position = Vector2(38, 61)
	photo_card.size = Vector2(304, 208)
	var card_skin := StyleBoxFlat.new()
	card_skin.bg_color = Color("0d1712")
	card_skin.border_color = Color("3e4a3c")
	card_skin.set_border_width_all(1)
	card_skin.set_corner_radius_all(2)
	card_skin.shadow_color = Color(0, 0, 0, 0.45)
	card_skin.shadow_size = 4
	photo_card.add_theme_stylebox_override("panel", card_skin)
	board.add_child(photo_card)
	
	var photo_box := Control.new()
	photo_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	photo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo_card.add_child(photo_box)
	
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture = texture
	image.position = Vector2(13, 11)
	image.size = Vector2(276, 184)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo_box.add_child(image)
	
	var photo_rim := ReferenceRect.new()
	photo_rim.position = Vector2(13, 11)
	photo_rim.size = Vector2(276, 184)
	photo_rim.border_color = Color(0.24, 0.30, 0.23, 0.75)
	photo_rim.border_width = 1.0
	photo_rim.editor_only = false
	photo_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo_box.add_child(photo_rim)
	
	# Note panel on the right: position = Vector2(369, 61), size = Vector2(223, 208)
	var note_panel := PanelContainer.new()
	note_panel.position = Vector2(369, 61)
	note_panel.size = Vector2(223, 208)
	var note_skin := StyleBoxFlat.new()
	note_skin.bg_color = Color("101a15")
	note_skin.border_color = Color("3e4a3c")
	note_skin.set_border_width_all(1)
	note_skin.set_corner_radius_all(2)
	note_skin.content_margin_left = 12
	note_skin.content_margin_right = 12
	note_skin.content_margin_top = 10
	note_skin.content_margin_bottom = 10
	note_panel.add_theme_stylebox_override("panel", note_skin)
	board.add_child(note_panel)
	
	var note_vbox := VBoxContainer.new()
	note_vbox.add_theme_constant_override("separation", 6)
	note_panel.add_child(note_vbox)
	
	var note_title := Label.new()
	note_title.text = "【 嘉敏的发现 】"
	note_title.add_theme_font_size_override("font_size", 14)
	note_title.add_theme_color_override("font_color", Color("e0d6a0"))
	note_vbox.add_child(note_title)
	
	var sep := HSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = Color("2d3a2c")
	sep_style.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	note_vbox.add_child(sep)
	
	var note := RichTextLabel.new()
	note.fit_content = true
	note.scroll_active = false
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.add_theme_font_size_override("normal_font_size", 13)
	note.add_theme_color_override("default_color", Color("d0d5c4"))
	note.add_theme_constant_override("line_separation", 4)
	note.text = "街坊说，有小孩在旧唐楼床底见过一位黑袍老人。也有人说，灯照过去只有一具白骨。嘉敏把两种说法都抄在纸背。\n\n这张 304 旧照里，铁床后有扇半开的百叶木门。新图纸却把那里画成实墙。"
	note_vbox.add_child(note)

func _style_macau_button(btn: Button, accent := false) -> void:
	var face := UiFont.song()
	btn.add_theme_font_override("font", face)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color("f4e6b8") if accent else Color("e4e8d8"))
	btn.add_theme_color_override("font_hover_color", Color("fff4cf"))
	btn.add_theme_color_override("font_disabled_color", Color("9aa494"))
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.27, 0.20, 0.94) if accent else Color(0.08, 0.16, 0.13, 0.92)
	normal.border_color = Color("d8bd7b") if accent else Color("8f825b")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.26, 0.38, 0.28, 0.98) if accent else Color("234a3a")
	hover.border_color = Color("f0da9a")
	var disabled_s := normal.duplicate() as StyleBoxFlat
	disabled_s.bg_color = Color(0.09, 0.13, 0.11, 0.72)
	disabled_s.border_color = Color("5c5c4b")
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("disabled", disabled_s)

func _create_bus_controls() -> void:
	# Animated Hong Kong-Zhuhai-Macau Bridge sea-crossing parallax + Transmac Macau bus silhouette
	bridge_fx = BridgeCrossingLayer.new()
	bridge_fx.z_index = 4
	add_child(bridge_fx)

	bus_layer = CanvasLayer.new()
	add_child(bus_layer)
	# Fixed compact 608x88 bottom dialogue bar (y=260..348) so it NEVER overflows 640x360!
	bus_dialogue = PanelContainer.new()
	bus_dialogue.position = Vector2(16, 260)
	bus_dialogue.size = Vector2(608, 88)
	bus_dialogue.custom_minimum_size = Vector2(608, 88)
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(0.06, 0.10, 0.08, 0.94)
	skin.border_color = Color("8c7d57")
	skin.set_border_width_all(1)
	skin.set_corner_radius_all(4)
	skin.content_margin_left = 12
	skin.content_margin_right = 12
	skin.content_margin_top = 8
	skin.content_margin_bottom = 8
	bus_dialogue.add_theme_stylebox_override("panel", skin)
	bus_layer.add_child(bus_dialogue)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	bus_dialogue.add_child(content)
	var bus_portrait := TextureRect.new()
	bus_portrait.name = "BusSpeakerPortrait"
	bus_portrait.custom_minimum_size = Vector2(52, 66)
	bus_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bus_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var dawen_warm := preload("res://ui/quiet_hud.gd")._get_emotional_portrait("陈大文", "warm")
	if dawen_warm != null:
		bus_portrait.texture = dawen_warm
	content.add_child(bus_portrait)
	bus_words = Label.new()
	var face := UiFont.song()
	bus_words.add_theme_font_override("font", face)
	bus_words.add_theme_font_size_override("font_size", 12)
	bus_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bus_words.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bus_words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bus_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bus_words.clip_text = true
	bus_words.text = "港珠澳大桥 · 金巴跨海段\n大文：嘉敏，朝我这边看。过了海就到澳门了。"
	content.add_child(bus_words)
	var btn_col := VBoxContainer.new()
	btn_col.custom_minimum_size = Vector2(146, 68)
	btn_col.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_col.add_theme_constant_override("separation", 6)
	content.add_child(btn_col)
	bus_coin_btn = Button.new()
	bus_coin_btn.text = "投币 6 元 [ E ]"
	bus_coin_btn.custom_minimum_size = Vector2(144, 30)
	bus_coin_btn.visible = false
	_style_macau_button(bus_coin_btn, true)
	bus_coin_btn.pressed.connect(_pay_bus_fare)
	btn_col.add_child(bus_coin_btn)
	bus_next_btn = Button.new()
	bus_next_btn.text = "换乘新福利 [ E ]"
	bus_next_btn.custom_minimum_size = Vector2(144, 32)
	_style_macau_button(bus_next_btn, false)
	bus_next_btn.pressed.connect(func():
		if bus_stage == 0:
			_board_transmac_bus()
		else:
			_arrive()
	)
	btn_col.add_child(bus_next_btn)

func _pay_bus_fare() -> void:
	if bus_stage != 1:
		return
	bus_stage = 2
	AudioManager.play_world_effect("pickup_coin")
	GameState.unlock_macau_guide("transmac_bus", false)
	bus_coin_btn.disabled = true
	bus_coin_btn.text = "已投币 6 元"
	bus_next_btn.disabled = false
	var portrait := bus_dialogue.find_child("BusSpeakerPortrait", true, false) as TextureRect
	if portrait != null:
		portrait.texture = preload("res://ui/quiet_hud.gd")._get_emotional_portrait("黄嘉敏", "warm")
	_play_real_coin_drop_animation(bus_words.get_theme_font("font"))
	bus_words.text = "嘉敏：先去大三巴吃葡挞。等天黑前，我们再去看看 304。"
	get_tree().create_timer(0.45).timeout.connect(func():
		if is_inside_tree() and bus_stage == 2:
			AudioManager.play_bus_pa("bus_handrail_4lang", -3.0)
	)

func _play_real_coin_drop_animation(face: Font) -> void:
	if not is_instance_valid(bus_layer):
		return
	# Drop real spinning MOP $5 + $1 coins straight into the painted Transmac silver coin-box slot at (398, 204)!
	var anim := CoinDropOverlay.new()
	anim.position = Vector2.ZERO
	anim.size = Vector2(640, 260)
	anim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bus_layer.add_child(anim)
	var tw := anim.create_tween()
	tw.tween_property(anim, "progress", 1.0, 0.92).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.28)
	tw.tween_property(anim, "modulate:a", 0.0, 0.30)
	tw.tween_callback(anim.queue_free)
	var drop := Label.new()
	drop.text = "MOP $6"
	drop.position = Vector2(282, 152)
	drop.add_theme_font_override("font", face)
	drop.add_theme_font_size_override("font_size", 12)
	drop.add_theme_color_override("font_color", Color("f6e29c"))
	drop.add_theme_color_override("font_shadow_color", Color("07100c"))
	drop.add_theme_constant_override("shadow_offset_y", 1)
	drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bus_layer.add_child(drop)
	var rise := create_tween()
	rise.set_parallel(true)
	rise.tween_property(drop, "position:y", 128.0, 1.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rise.tween_property(drop, "modulate:a", 0.0, 1.15).set_delay(0.35)
	rise.chain().tween_callback(drop.queue_free)

func _board_transmac_bus() -> void:
	if bus_stage != 0:
		return
	bus_stage = 1
	AudioManager.play_dialogue_advance()
	AudioManager.set_scene_ambience("transit")
	if is_instance_valid(bridge_fx):
		bridge_fx.visible = false
		bridge_fx.set_process(false)
	if ResourceLoader.exists("res://assets/tilesets/macau_transmac_bus_v4.png") and is_instance_valid(bus_back_sprite):
		var tex := load("res://assets/tilesets/macau_transmac_bus_v4.png") as Texture2D
		if tex != null:
			bus_back_sprite.texture = tex
			bus_back_sprite.scale = Vector2(640, 360) / tex.get_size()
	if is_instance_valid(bus_words):
		bus_words.text = "澳门口岸 · 换乘新福利巴士\n司机：往大三巴，投币六元。"
		AudioManager.play_bus_pa("bus_driver_pa", -2.0)
	if is_instance_valid(bus_coin_btn):
		bus_coin_btn.visible = true
	if is_instance_valid(bus_next_btn):
		bus_next_btn.text = "下车去大三巴 [ E ]"
		bus_next_btn.custom_minimum_size = Vector2(144, 30)
		bus_next_btn.disabled = true

func _arrive() -> void:
	if bus_stage != 2 or not is_instance_valid(bus_dialogue) or not bus_dialogue.visible:
		return
	AudioManager.stop_bus_pa()
	AudioManager.stop_voice()
	AudioManager.play_dialogue_advance()
	GameState.opening_flags.intro_boarded = true
	if _move_to("ch0_street", "arrival"):
		bus_dialogue.hide()
	else:
		GameState.opening_flags.intro_boarded = false

func _move_to(room_id: String, entry_id: String) -> bool:
	var tree := get_tree()
	if not GameState.request_room_change(room_id, entry_id):
		return false
	tree.paused = false
	GameState.save_transition_checkpoint()
	return true

func _say_sequence(turns: Array, index: int = 0, finished: Callable = Callable()) -> void:
	if index >= turns.size():
		if finished.is_valid():
			finished.call()
		return
	var turn: Dictionary = turns[index]
	var continuation := finished
	if index + 1 < turns.size():
		var next_index := index + 1
		continuation = func(): _say_sequence(turns, next_index, finished)
	_say(str(turn.get("title", "")), str(turn.get("body", "")), str(turn.get("speaker", "陈大文")), continuation)

func _say(title: String, body: String, speaker := "陈大文", next := Callable()) -> void:
	player.clear_motion()
	player.controls_enabled = false
	after_panel = next
	hud.open_panel(title, body, [], false, speaker)
	get_tree().paused = true

func _widget(widget: Control) -> void:
	AudioManager.play_dialogue_advance()
	player.clear_motion()
	player.controls_enabled = false
	hud.open_widget(widget)
	get_tree().paused = true

func _close() -> void:
	AudioManager.play_dialogue_advance()
	hud.close_panel()
	player.controls_enabled = true
	player.clear_motion()
	get_tree().paused = false
	var next := after_panel
	after_panel = Callable()
	if next.is_valid():
		next.call()
	if is_inside_tree():
		_refresh_objective()

func _pause() -> void:
	if arrival_transition:
		return
	player.clear_motion()
	player.controls_enabled = false
	hud.open_panel("暂停", "香港 · 出发前夜", [
		{"text": "继续", "callback": _close},
		{"text": "退出游戏", "callback": func(): get_tree().quit()}
	])
	get_tree().paused = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud) and is_instance_valid(player) and not hud.panel_open and not get_tree().paused:
		_pause()

func _refresh_objective() -> void:
	if stage == "work":
		if not GameState.opening_flags.intro_job_done:
			hud.objective.text = "在左侧工作台收工"
		elif not GameState.opening_flags.intro_invited:
			hud.objective.text = "嘉敏来了。去门口和她说话"
		else:
			hud.objective.text = "从右侧门回家，看看嘉敏找到的资料"
	elif GameState.opening_flags.intro_plan_seen and GameState.opening_flags.intro_photo_seen:
		hud.objective.text = "路线图已经准备好。从右侧门出发"
	else:
		if not GameState.opening_flags.intro_photo_seen and not GameState.opening_flags.intro_plan_seen:
			hud.objective.text = "大文家 · 先查左侧台灯下的旧合照，再整理桌上的澳门路线图"
		elif not GameState.opening_flags.intro_photo_seen:
			hud.objective.text = "大文家 · 查看左侧台灯下的旧合照"
		elif not GameState.opening_flags.intro_plan_seen:
			hud.objective.text = "大文家 · 整理桌上的澳门手绘路线图"

class BridgeCrossingLayer extends Node2D:
	var clock := 0.0

	func _process(delta: float) -> void:
		clock += delta
		queue_redraw()

	func _draw() -> void:
		# Subtle golden coastal light shimmer passing smoothly across the painted HZMB bus window (y=36..148)
		var speed := 110.0
		for i in range(3):
			var tx := fposmod(640.0 - clock * speed + i * 240.0, 760.0) - 80.0
			if tx > 110.0 and tx < 530.0:
				var sheen := PackedVector2Array([
					Vector2(tx, 34), Vector2(tx + 28, 34),
					Vector2(tx + 8, 148), Vector2(tx - 18, 148)
				])
				draw_colored_polygon(sheen, Color(1.0, 0.94, 0.78, 0.065))

class CoinDropOverlay extends Control:
	var progress: float = 0.0:
		set(value):
			progress = value
			queue_redraw()

	func _draw() -> void:
		# Aim tumbling MOP $5 + $1 coins straight into the real painted Transmac coin-box slot at (398, 200)!
		var slot_center := Vector2(398.0, 200.0)
		var font := get_theme_default_font()
		# Subtle brass glint highlight ring around the painted coin-box slot opening
		var slot_glow := 0.25 + 0.45 * sin(progress * PI)
		draw_arc(slot_center, 11.0, 0.0, TAU, 20, Color(0.98, 0.86, 0.50, slot_glow * 0.55), 1.4, true)
		# Two tumbling coins ($5 brass-gold + $1 silver) arcing cleanly down into the painted slot!
		for c_idx in range(2):
			var local_p := clampf((progress - float(c_idx) * 0.18) / 0.76, 0.0, 1.0)
			if local_p <= 0.0:
				continue
			var cx := lerpf(322.0 + float(c_idx) * 38.0, slot_center.x, local_p)
			var arc_y := lerpf(118.0, slot_center.y, local_p * local_p) - sin(local_p * PI) * 32.0
			var flip_scale := maxf(0.18, absf(cos(local_p * PI * 4.5)))
			var fade := 1.0 if local_p < 0.84 else clampf((1.0 - local_p) / 0.16, 0.0, 1.0)
			var r := 12.0 if c_idx == 0 else 9.5
			var col_outer := Color(0.92, 0.76, 0.34, fade) if c_idx == 0 else Color(0.84, 0.86, 0.84, fade)
			var col_inner := Color(0.76, 0.60, 0.24, fade) if c_idx == 0 else Color(0.66, 0.70, 0.68, fade)
			var sides := 12 if c_idx == 0 else 18
			var pts := PackedVector2Array()
			for s in range(sides):
				var a := TAU * float(s) / float(sides)
				pts.append(Vector2(cx + cos(a) * r * flip_scale, arc_y + sin(a) * r))
			draw_colored_polygon(pts, col_outer)
			var inner_pts := PackedVector2Array()
			for s in range(14):
				var a := TAU * float(s) / 14.0
				inner_pts.append(Vector2(cx + cos(a) * (r * 0.72) * flip_scale, arc_y + sin(a) * (r * 0.72)))
			draw_colored_polygon(inner_pts, col_inner)
			if flip_scale > 0.48:
				draw_string(font, Vector2(cx - 3.5, arc_y + 3.5), "5" if c_idx == 0 else "1", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.16, 0.12, 0.06, fade))
		# Golden metallic glint starburst right at the slot as coins drop inside
		if progress > 0.60 and progress < 0.96:
			var g_alpha := sin(((progress - 0.60) / 0.36) * PI) * 0.82
			draw_circle(slot_center, 16.0 * (progress - 0.54), Color(0.98, 0.88, 0.55, g_alpha * 0.35))
			draw_line(slot_center + Vector2(-14, 0), slot_center + Vector2(14, 0), Color(1.0, 0.95, 0.76, g_alpha), 1.6)
			draw_line(slot_center + Vector2(0, -10), slot_center + Vector2(0, 10), Color(1.0, 0.95, 0.76, g_alpha), 1.4)
		if progress > 0.65:
			var led_a := clampf((progress - 0.65) / 0.20, 0.0, 1.0)
			var badge := Rect2(slot_center + Vector2(-46, -34), Vector2(92, 18))
			draw_rect(badge, Color(0.05, 0.14, 0.09, 0.92 * led_a))
			draw_rect(badge, Color(0.45, 0.88, 0.55, 0.90 * led_a), false, 1.0)
			draw_string(font, badge.position + Vector2(6, 13), "MOP $6.00 已收讫", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.70, 0.98, 0.76, led_a))
