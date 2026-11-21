extends Node2D

@export_enum("work", "home", "bus") var stage := "work"
var player: PlayerController
var hud
var girl: StaticBody2D
var active_target := ""
var after_panel: Callable
var targets := {}
var bus_dialogue: PanelContainer
var home_photo: Sprite2D
var home_photo_frame: Polygon2D

func _ready() -> void:
	AudioManager.set_scene_ambience("")
	var backgrounds := {"work":"hk_work_026", "home":"hk_home_029", "bus":"bridge_bus_026"}
	var back := Sprite2D.new()
	back.name = "Background"
	back.texture = load("res://assets/tilesets/%s.png" % backgrounds[stage])
	back.centered = false
	back.scale = Vector2(640, 360) / back.texture.get_size()
	add_child(back)
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
			"map": [Vector2(344, 172), "和嘉敏做旅行攻略"],
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

func _create_home_photo_overlay() -> void:
	var photo_texture: Texture2D = DemoItems.texture("old_304_photo")
	if photo_texture == null:
		push_warning("Home scene photo texture is unavailable; background print remains visible.")
		return
	# Place the physical photo on the front half of the desk surface, clear of
	# the lamp, books and ink cup. The old position floated above the desktop.
	var photo_center := Vector2(196.0, 136.0)
	var frame := Polygon2D.new()
	frame.name = "OldPhotoFrame"
	frame.position = photo_center
	frame.rotation = deg_to_rad(-2.2)
	# The background photo placeholder has been removed. Use a real 3:2 frame and
	# keep the photographed room at the source image's 3:2 aspect ratio.
	frame.polygon = PackedVector2Array([Vector2(-18, -12), Vector2(18, -12), Vector2(18, 12), Vector2(-18, 12)])
	frame.color = Color("c8b891")
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
	photo_area_shape.polygon = PackedVector2Array([Vector2(-18, -12), Vector2(18, -12), Vector2(18, 12), Vector2(-18, 12)])
	photo_area.add_child(photo_area_shape)
	photo_area.z_index = 4
	add_child(photo_area)
	home_photo = Sprite2D.new()
	home_photo.name = "OldPhotoUnderLamp"
	home_photo.texture = photo_texture
	home_photo.position = photo_center
	home_photo.rotation = frame.rotation
	home_photo.z_index = 3
	var photo_size := Vector2(30.0, 20.0)
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
				return "整理澳门两日攻略" if not GameState.opening_flags.intro_plan_seen else "重看澳门两日路线"
			"exit":
				if not GameState.opening_flags.intro_photo_seen and not GameState.opening_flags.intro_plan_seen:
					return "先看左侧台灯下的旧合照，再整理两日攻略"
				if not GameState.opening_flags.intro_photo_seen:
					return "先查看左侧台灯下的旧合照"
				if not GameState.opening_flags.intro_plan_seen:
					return "先整理桌上的澳门两日攻略"
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
	if stage == "bus":
		if event.is_action_pressed("interact") and not event.is_echo():
			get_viewport().set_input_as_handled()
			_arrive()
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
					{"title": "翌日 · 港珠澳大桥", "speaker": "黄嘉敏", "body": "金巴车票阿豪订好啦！过关坐新福利巴士去大三巴吃葡挞，傍晚去探 304 那扇消失的门。"},
					{"title": "出发赴澳", "speaker": "陈大文", "body": "工具钳和强光手电都装进包了。走吧，别让阿豪在口岸等急了。"}
				], 0, func(): _move_to("ch0_bridge_bus", "from_home"))
			else:
				_say("门边行李", "嘉敏把 304 旧照放在台灯下，金巴车票和两日攻略还摊在饭桌上。")
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
	note.text = "1961 年大三巴后曾挖出数十具教会遗骨，民间盛传旧唐楼床底有暗道通往地底墓室：小孩看到黑袍老伯，大人下去看到的却是白骨。\n\n这张 304 旧照里，铁床后有扇半开的百叶木门，新图纸却画成死墙。"
	note_vbox.add_child(note)

func _create_bus_controls() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	bus_dialogue = PanelContainer.new()
	bus_dialogue.position = Vector2(18, 280)
	bus_dialogue.size = Vector2(604, 64)
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("14211b")
	skin.border_color = Color("6f7255")
	skin.set_border_width_all(1)
	skin.content_margin_left = 14
	skin.content_margin_right = 14
	skin.content_margin_top = 8
	skin.content_margin_bottom = 8
	bus_dialogue.add_theme_stylebox_override("panel", skin)
	layer.add_child(bus_dialogue)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	bus_dialogue.add_child(content)
	var words := Label.new()
	var face := SystemFont.new()
	face.font_names = PackedStringArray(["SimSun", "Noto Serif CJK SC"])
	words.add_theme_font_override("font", face)
	words.add_theme_font_size_override("font_size", 14)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.text = "港珠澳大桥金巴 → 换乘澳门新福利巴士（投币 6 元葡币）\n嘉敏：手札里记了大三巴白骨、松山 99 级鬼阶和 33 路末班车，今晚先看 304！"
	content.add_child(words)
	var arrive := Button.new()
	arrive.text = "抵达澳门 [ E ]"
	arrive.custom_minimum_size.x = 136
	arrive.pressed.connect(_arrive)
	content.add_child(arrive)

func _arrive() -> void:
	if not is_instance_valid(bus_dialogue) or not bus_dialogue.visible:
		return
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
		hud.objective.text = "攻略已经准备好。从右侧门出发"
	else:
		if not GameState.opening_flags.intro_photo_seen and not GameState.opening_flags.intro_plan_seen:
			hud.objective.text = "大文家 · 先查左侧台灯下的旧合照，再整理饭桌上的澳门攻略"
		elif not GameState.opening_flags.intro_photo_seen:
			hud.objective.text = "大文家 · 查看左侧台灯下的旧合照"
		elif not GameState.opening_flags.intro_plan_seen:
			hud.objective.text = "大文家 · 整理桌上的澳门两日攻略"
