extends Node2D

const ROOM_ID := "ch3_amparo_archive"
const COLD_PASSAGE_ENTRY := Rect2(520, 70, 58, 23)
const EVIDENCE_FLAGS := ["ch3_photo_seen", "ch3_register_seen", "ch3_delivery_seen", "ch3_visitor_log_seen"]
const TARGET_POINTS := {
	"photo": Vector2(367, 92),
	"resident_register": Vector2(254, 108),
	"balance_rule": Vector2(278, 108),
	"delivery_letter": Vector2(310, 108),
	"visitor_log": Vector2(333, 108),
	"cold_door": Vector2(548, 145),
	"balance": Vector2(420, 91),
	"archive_key": Vector2(386, 117),
	"w17_ticket": Vector2(426, 117)
	,"lens_cap": Vector2(513, 166)
}
const TARGET_NAMES := {
	"photo":"查看四人旧合照",
	"resident_register":"查阅常住登记册",
	"balance_rule":"翻阅秤账背页",
	"delivery_letter":"查看送药旧信",
	"visitor_log":"查阅访客签名页",
	"cold_door":"检查冷柜后维护门",
	"balance":"检查旧杆秤",
	"archive_key":"检查方牌备用钥匙",
	"w17_ticket":"查看 33 路时刻表"
	,"lens_cap":"查看冷柜下的镜头盖"
}

var player: PlayerController
var hud
var selected_id := ""
var after_dialog := Callable()
var balance_board: Control
var inventory_panel: Control
var work_in_progress := false
var hotspots: Dictionary = {}
var warm_lamp: PointLight2D
var cold_door_body: StaticBody2D
var cold_door_collision: CollisionShape2D
var cold_door_occluder: LightOccluder2D
var cold_door_overlay: Sprite2D
var opened_leaf_collision: CollisionShape2D
var opened_leaf_occluder: LightOccluder2D
var departing_to_bus := false

func _ready() -> void:
	GameState.prepare_opening_resume()
	call_deferred("_setup_room")

func _setup_room() -> void:
	if GameState.current_room_id != ROOM_ID:
		push_error("第三章资料室由存档或正式路线进入；当前房间状态不匹配。")
		return
	AudioManager.set_scene_ambience("street")
	var background = preload("res://core/components/room_tile_layer.gd").new()
	background.background_texture = preload("res://assets/tilesets/ch3_archive_room_030.png")
	add_child(background)
	_build_cold_door_overlay()
	_build_evidence_photo()
	var ambient := CanvasModulate.new()
	ambient.color = Color(0.78, 0.77, 0.69)
	add_child(ambient)
	_build_room_geometry()
	_build_lamp()
	_create_hotspots()
	_build_archive_pickups()
	player = preload("res://entities/player/player.tscn").instantiate()
	player.visual_size_multiplier = 1.65
	player.appearance = "flashlight"
	player.position = Vector2(548, 124) if GameState.pending_entry_id == "from_passage" else Vector2(320, 258)
	add_child(player)
	player.reset_physics_interpolation()
	hud = preload("res://ui/quiet_hud.gd").new()
	add_child(hud)
	hud.close_requested.connect(_close_active_ui)
	hud.pause_requested.connect(_show_pause_menu)
	hud.resources.show_flashlight = true
	update_objective()
	if not GameState.opening_flags.ch3_intro_seen:
		GameState.opening_flags.ch3_intro_seen = true
		checkpoint()
		show_text("大关斜巷 · 肉铺后间", "二战饥荒年代这里盛传「肥人慎入大关斜巷」，紧邻的长楼斜巷早年更是烧毁过猪仔馆铁笼。嘉敏刚在这间旧肉铺躲过，先按 E 检查右边冷柜后的铁门。")

func _build_room_geometry() -> void:
	LevelGeometry.wall(self, Rect2(0, 0, 640, 14))
	LevelGeometry.wall(self, Rect2(0, 14, 14, 332))
	LevelGeometry.wall(self, Rect2(626, 14, 14, 332))
	LevelGeometry.wall(self, Rect2(14, 346, 612, 14))
	# Counters, cabinets and the cold-room door match the painted foreground.
	LevelGeometry.polygon_wall(self, PackedVector2Array([
		Vector2(14, 120), Vector2(51, 120), Vector2(51, 158), Vector2(14, 158)
	]), false)
	LevelGeometry.wall(self, Rect2(51, 120, 108, 38))
	LevelGeometry.wall(self, Rect2(158, 136, 32, 24))
	LevelGeometry.wall(self, Rect2(230, 130, 278, 43))
	_build_cold_door_geometry()
	# Seal the back closet threshold so the player cannot walk behind the counter onto the upper wall.
	LevelGeometry.polygon_wall(self, PackedVector2Array([
		Vector2(189, 120), Vector2(231, 120), Vector2(231, 158), Vector2(189, 158)
	]), false)

func _build_cold_door_geometry() -> void:
	var door_rect := Rect2(508, 43, 89, 119)
	LevelGeometry.wall(self, Rect2(508, 31, 112, 39))
	LevelGeometry.wall(self, Rect2(498, 70, 19, 65))
	cold_door_body = StaticBody2D.new()
	cold_door_body.name = "ColdRoomDoorCollision"
	cold_door_body.collision_layer = 1
	cold_door_body.collision_mask = 2
	cold_door_collision = CollisionShape2D.new()
	cold_door_collision.name = "CollisionShape2D"
	var door_shape := RectangleShape2D.new()
	door_shape.size = door_rect.size
	cold_door_collision.shape = door_shape
	cold_door_collision.position = door_rect.get_center()
	cold_door_collision.disabled = GameState.opening_flags.ch3_cold_door_open
	cold_door_body.add_child(cold_door_collision)
	add_child(cold_door_body)
	cold_door_occluder = LightOccluder2D.new()
	var polygon := OccluderPolygon2D.new()
	polygon.polygon = PackedVector2Array([door_rect.position, Vector2(door_rect.end.x, door_rect.position.y), door_rect.end, Vector2(door_rect.position.x, door_rect.end.y)])
	cold_door_occluder.occluder = polygon
	cold_door_occluder.visible = not GameState.opening_flags.ch3_cold_door_open
	add_child(cold_door_occluder)
	# The swung iron leaf remains a solid object on the right of the opening.
	var leaf_rect := Rect2(582, 27, 38, 136)
	var leaf := LevelGeometry.wall(self, leaf_rect)
	leaf.name = "OpenedIronDoorLeaf"
	opened_leaf_collision = leaf.get_child(0) as CollisionShape2D
	opened_leaf_collision.disabled = not GameState.opening_flags.ch3_cold_door_open
	opened_leaf_occluder = get_child(get_child_count() - 1) as LightOccluder2D
	opened_leaf_occluder.visible = GameState.opening_flags.ch3_cold_door_open

func _build_lamp() -> void:
	warm_lamp = PointLight2D.new()
	# The bulb is at the upper workbench, not on the counter surface.
	warm_lamp.position = Vector2(375, 34)
	warm_lamp.texture = preload("res://assets/lighting/soft_light.png")
	warm_lamp.texture_scale = 0.47
	warm_lamp.color = Color("ffd18e")
	warm_lamp.energy = 0.34
	warm_lamp.range_item_cull_mask = 3
	warm_lamp.shadow_enabled = true
	warm_lamp.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	add_child(warm_lamp)

func _build_evidence_photo() -> void:
	# Reuse the four-person archival image seen earlier in the story.
	# The empty frame painted on the desk is its physical mount.
	var texture := AtlasTexture.new()
	texture.atlas = preload("res://assets/props/room304_old_photo_026.png")
	texture.region = Rect2(150, 72, 660, 440)
	texture.filter_clip = true
	var photograph := Sprite2D.new()
	photograph.name = "FourPersonArchivePhoto"
	photograph.texture = texture
	photograph.position = Vector2(367, 92)
	photograph.scale = Vector2(33.0 / 660.0, 22.0 / 440.0)
	photograph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	photograph.z_index = 2
	add_child(photograph)

func _build_cold_door_overlay() -> void:
	var texture := AtlasTexture.new()
	texture.atlas = preload("res://assets/tilesets/ch3_archive_room_open_032.png")
	texture.region = Rect2(1298, 37, 352, 390)
	texture.filter_clip = true
	cold_door_overlay = Sprite2D.new()
	cold_door_overlay.name = "OpenedColdRoomDoorArt"
	cold_door_overlay.texture = texture
	cold_door_overlay.centered = false
	cold_door_overlay.position = Vector2(1298.0 * 640.0 / 1672.0, 37.0 * 360.0 / 941.0)
	cold_door_overlay.scale = Vector2(640.0 / 1672.0, 360.0 / 941.0)
	cold_door_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cold_door_overlay.visible = GameState.opening_flags.ch3_cold_door_open
	cold_door_overlay.z_index = 1
	add_child(cold_door_overlay)

func _create_hotspots() -> void:
	for id in TARGET_POINTS:
		var area := Area2D.new()
		area.name = "Interactable_%s" % id
		area.position = TARGET_POINTS[id]
		area.collision_layer = 8
		area.collision_mask = 0
		var shape := CircleShape2D.new()
		shape.radius = 17.0
		var collision := CollisionShape2D.new()
		collision.name = "InteractionShape"
		collision.shape = shape
		area.add_child(collision)
		add_child(area)
		hotspots[id] = area

func _build_archive_pickups() -> void:
	var lens := Sprite2D.new()
	lens.texture = DemoItems.texture("jiamin_lens_cap")
	lens.scale = Vector2.ONE * (19.0 / lens.texture.get_width())
	lens.position = TARGET_POINTS.lens_cap
	lens.visible = not GameState.has_demo_item("jiamin_lens_cap")
	lens.name = "JiaminLensCap"
	add_child(lens)
	var key_area := hotspots["archive_key"] as Area2D
	var key_visual := Node2D.new()
	key_visual.name = "ArchiveSpareKeyVisual"
	key_visual.position = Vector2.ZERO
	key_visual.z_index = 3
	var key_sprite := Sprite2D.new()
	key_sprite.texture = preload("res://assets/props/bunker_key_025.png")
	key_sprite.scale = Vector2.ONE * 0.018
	key_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	key_sprite.z_index = 2
	key_visual.add_child(key_sprite)
	var badge_texture := AtlasTexture.new()
	badge_texture.atlas = preload("res://assets/props/bunker_lock_parts_026.png")
	badge_texture.region = Rect2(160, 160, 460, 440)
	badge_texture.filter_clip = true
	var badge := Sprite2D.new()
	badge.name = "SquareCopperTag"
	badge.texture = badge_texture
	badge.position = Vector2(-15, 4)
	badge.scale = Vector2.ONE * 0.017
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	badge.z_index = 1
	key_visual.add_child(badge)
	var tag_cord := Line2D.new()
	tag_cord.name = "TagCord"
	tag_cord.points = PackedVector2Array([Vector2(-6, 0), Vector2(-9, 2), Vector2(-13, 4)])
	tag_cord.width = 1.1
	tag_cord.default_color = Color("5d472c")
	tag_cord.z_index = 1
	key_visual.add_child(tag_cord)
	key_area.add_child(key_visual)
	key_area.set_meta("visual", key_visual)

	var ticket_area := hotspots["w17_ticket"] as Area2D
	var ticket_visual := Node2D.new()
	ticket_visual.name = "W17TicketVisual"
	ticket_visual.z_index = 3
	var ticket_texture := AtlasTexture.new()
	ticket_texture = DemoItems.texture("w17_bus_ticket") as AtlasTexture
	ticket_texture.filter_clip = true
	var ticket_sprite := Sprite2D.new()
	ticket_sprite.name = "TicketPaper"
	ticket_sprite.texture = ticket_texture
	ticket_sprite.scale = Vector2.ONE * (28.0 / ticket_texture.get_width())
	ticket_sprite.rotation = deg_to_rad(-3.0)
	ticket_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ticket_visual.add_child(ticket_sprite)
	var ticket_mark := Label.new()
	ticket_mark.name = "TicketW17Mark"
	ticket_mark.position = Vector2(-10, -3)
	ticket_mark.size = Vector2(21, 8)
	ticket_mark.text = "33"
	ticket_mark.rotation = deg_to_rad(-3.0)
	ticket_mark.add_theme_font_size_override("font_size", 6)
	ticket_mark.add_theme_color_override("font_color", Color("37261d"))
	ticket_mark.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	ticket_mark.add_theme_constant_override("shadow_offset_x", 0)
	ticket_mark.add_theme_constant_override("shadow_offset_y", 0)
	ticket_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticket_visual.add_child(ticket_mark)
	ticket_area.add_child(ticket_visual)
	ticket_area.set_meta("visual", ticket_visual)
	_refresh_archive_pickups()

func _refresh_archive_pickups() -> void:
	for entry in [["archive_key", "ch3_key_found"], ["w17_ticket", "ch3_ticket_found"]]:
		var area: Area2D = hotspots.get(entry[0])
		if not is_instance_valid(area):
			continue
		var available: bool = GameState.opening_flags.ch3_balance_solved and not GameState.opening_flags[entry[1]]
		area.visible = available
		area.monitoring = available
		area.monitorable = available
		var visual := area.get_meta("visual") as Node2D
		if is_instance_valid(visual) and not available:
			visual.modulate = Color.WHITE
			visual.scale = Vector2.ONE
			visual.position = Vector2.ZERO

func _reveal_archive_pickups() -> void:
	var delay := 0.0
	for id in ["archive_key", "w17_ticket"]:
		var area: Area2D = hotspots[id]
		if not area.visible:
			continue
		var visual := area.get_meta("visual") as Node2D
		visual.position = Vector2(0, -5)
		visual.scale = Vector2.ONE * 0.82
		visual.modulate = Color(1, 1, 1, 0)
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(visual, "position", Vector2.ZERO, 0.22)
		tween.parallel().tween_property(visual, "scale", Vector2.ONE, 0.22)
		tween.parallel().tween_property(visual, "modulate", Color.WHITE, 0.22)
		delay += 0.12

func _target_available(id: String) -> bool:
	if id == "lens_cap": return not GameState.has_demo_item("jiamin_lens_cap")
	if id == "archive_key":
		return GameState.opening_flags.ch3_balance_solved and not GameState.opening_flags.ch3_key_found
	if id == "w17_ticket":
		return GameState.opening_flags.ch3_balance_solved and not GameState.opening_flags.ch3_ticket_found
	return true

func _process(delta: float) -> void:
	if is_instance_valid(warm_lamp):
		warm_lamp.energy = 0.32 + sin(float(Time.get_ticks_msec()) * 0.0031) * 0.025
	if not is_instance_valid(player) or not is_instance_valid(hud) or hud.panel_open or work_in_progress:
		return
	if not departing_to_bus and _can_depart_to_bus():
		_depart_to_bus()
		return
	selected_id = ""
	hud.prompt.text = ""
	# A person cannot pass through the counter, so the usable reach must clear
	# the desk's front collision while still requiring the player to face the item.
	var best_score := INF
	for id in TARGET_POINTS:
		if not _target_available(id):
			continue
		var point: Vector2 = TARGET_POINTS[id]
		var delta_to_target := point - player.position
		var distance := delta_to_target.length()
		var alignment := player.look_dir.dot(delta_to_target.normalized()) if distance > 0.01 else 1.0
		if distance > 100.0 or (distance > 10.0 and alignment < -0.12):
			continue
		# Table evidence is closely spaced. Give the object under the player's
		# actual viewing direction priority over a slightly closer neighbouring page.
		var score := distance + (1.0 - alignment) * 120.0
		if score >= best_score:
			continue
		selected_id = id
		best_score = score
	if not selected_id.is_empty():
		hud.prompt.text = "[ E ] " + _target_name(selected_id)
		hud.prompt.position = Vector2(clampf(player.position.x - 70.0, 65.0, 445.0), clampf(player.position.y + 15.0, 145.0, 289.0))

func _target_name(id: String) -> String:
	if id == "cold_door" and GameState.opening_flags.ch3_cold_door_open:
		return "进入冷柜后的暗道"
	if id == "balance" and GameState.opening_flags.ch3_ticket_found:
		return "查看已打开的档案柜"
	if id == "archive_key" and GameState.opening_flags.ch3_balance_solved:
		return "拾取方牌备用钥匙"
	if id == "w17_ticket" and GameState.opening_flags.ch3_balance_solved:
		return "拾取 33 路时刻表"
	if id == "cold_door" and GameState.opening_flags.ch3_key_found:
		return "检查方牌备用钥匙对应的门"
	return TARGET_NAMES.get(id, "调查")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if hud != null and hud.panel_open:
		return
	if work_in_progress or departing_to_bus:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		interact_target(selected_id)
	elif event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		_open_inventory()
	elif event.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		show_text("两日攻略", "攻略页停在澳门旧街区。大关斜巷是竖井便签留下的下一处方向。")

func interact_target(id: String) -> void:
	if id.is_empty():
		return
	match id:
		"lens_cap":
			GameState.take_demo_item("jiamin_lens_cap")
			$JiaminLensCap.hide()
			checkpoint()
			hud.show_resource_feedback("白胶带是嘉敏贴的，她刚在这间肉铺冷柜边躲过。")
		"archive_key":
			_collect_archive_item("archive_key", "ch3_key_found", "archive_spare_key", "archive_key_pickup")
		"w17_ticket":
			_open_timetable()
		"photo":
			_record_evidence("ch3_photo_seen")
			show_text("四人合照", "照片里有四个人，最右边那人腰间挂着方形铜牌。", [], _maybe_prompt_inference)
		"resident_register":
			_record_evidence("ch3_register_seen")
			show_text("常住登记册", "常住册只记了三名住户。来访的人记在另一本簿子里。", [], _maybe_prompt_inference)
		"balance_rule":
			_inspect_balance_rule()
		"delivery_letter":
			_record_evidence("ch3_delivery_seen")
			show_text("送药旧信", "送药的人只待了一会儿，从后门递药。信末有签名。", [], _maybe_prompt_inference)
		"visitor_log":
			_record_evidence("ch3_visitor_log_seen")
			show_text("访客簿", "访客簿上的签名和送药信一样。", [], _maybe_prompt_inference)
		"cold_door":
			_use_cold_room_door()
		"balance":
			_open_balance_board()

func _collect_archive_item(target_id: String, flag_id: String, item_id: String, effect_id: String) -> void:
	if not _target_available(target_id) or not GameState.take_demo_item(item_id):
		return
	GameState.opening_flags[flag_id] = true
	if target_id == "w17_ticket":
		GameState.take_demo_item("laochen_handoff_note")
	AudioManager.play_world_effect(effect_id)
	checkpoint()
	_refresh_archive_pickups()
	update_objective()
	if target_id == "archive_key":
		show_text("方牌备用钥匙", "方牌和照片里的一样。用这把钥匙开冷柜后的铁门。")

func _open_timetable() -> void:
	if not _target_available("w17_ticket"):
		return
	var board := Control.new()
	board.name = "Timetable"
	hud.open_widget(board)
	get_tree().paused = true
	player.controls_enabled = false
	player.clear_motion()
	var paper := TextureRect.new()
	paper.name = "TimetablePaper"
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	paper.texture = DemoItems.texture("w17_bus_ticket")
	paper.position = Vector2(172, 28)
	paper.size = Vector2(274, 268)
	paper.pivot_offset = paper.size * 0.5
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(paper)
	var note: Label = hud.label("街上有东西追我。\n我去亚马喇前地，\n找亮灯的 33 路，\n往路环报警。", Vector2(221, 143), Vector2(176, 96), 15, Color("473323"), board)
	note.add_theme_constant_override("outline_size", 0)
	note.hide()
	var flip: Button = hud.make_button("翻到背面", Vector2(462, 259), Vector2(126, 33), board)
	flip.name = "FlipTimetable"
	flip.pressed.connect(func():
		if GameState.opening_flags.ch3_ticket_found:
			close_dialog()
			return
		flip.disabled = true
		var turn := paper.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		turn.tween_property(paper, "scale:x", 0.02, 0.14).set_trans(Tween.TRANS_SINE)
		turn.tween_callback(func(): paper.texture = DemoItems.texture("laochen_handoff_note"))
		turn.tween_property(paper, "scale:x", 1.0, 0.14).set_trans(Tween.TRANS_SINE)
		await turn.finished
		if not is_instance_valid(board) or not board.is_visible_in_tree() or not hud.panel_open:
			return
		note.show()
		_collect_archive_item("w17_ticket", "ch3_ticket_found", "w17_bus_ticket", "archive_ticket_pickup")
		flip.text = "收好时刻表"
		flip.disabled = false
	)
	hud.label("Esc 返回", Vector2(496, 302), Vector2(110, 20), 12, Color("d6ceb9"), board)

func _record_evidence(flag_id: String) -> void:
	if not GameState.opening_flags[flag_id]:
		GameState.opening_flags[flag_id] = true
		checkpoint()
		update_objective()

func _all_evidence_seen() -> bool:
	for flag_id in EVIDENCE_FLAGS:
		if not GameState.opening_flags[flag_id]:
			return false
	return true

func _maybe_prompt_inference() -> void:
	if _all_evidence_seen() and not GameState.opening_flags.ch3_guest_inferred:
		_show_inference()

func _show_inference() -> void:
	show_text("照片与记录", "照片四人，住户三名。送药信和访客簿的签名一样。第四人可能是谁？", [
		{"text":"先列作临时送药访客，不认定为常住者", "callback":_accept_guest_hypothesis},
		{"text":"认定是被漏掉的第四名常住者", "callback":_reject_guest_hypothesis.bind(1)},
		{"text":"把两笔签名当成不同的人", "callback":_reject_guest_hypothesis.bind(2)}
	])

func _accept_guest_hypothesis() -> void:
	close_dialog(false)
	GameState.opening_flags.ch3_guest_inferred = true
	checkpoint()
	update_objective()
	show_text("暂定判断", "第四人是来送药的访客。他戴着方铜牌。")

func _reject_guest_hypothesis(reason: int) -> void:
	close_dialog(false)
	var body := "常住册的登记范围并不等于当天到访名单。四个人同框不能单独证明四人都住在这里。" if reason == 1 else "信件落款和访客簿的起笔、回锋一致；目前没有证据说明是两个人。"
	show_text("证据还不够", body + "\n\n再按记录范围判断一次。", [
		{"text":"重新核对材料", "callback":_show_inference}
	])

func _inspect_cold_door() -> void:
	if not GameState.opening_flags.ch3_cold_door_seen:
		GameState.opening_flags.ch3_cold_door_seen = true
		checkpoint()
		update_objective()
	AudioManager.play_world_effect("lock_mechanism")
	show_text("维护门锁孔", "门牌后留着一圈旧铜锈，方形牌槽的四角都有磨亮的擦痕。访客簿里的签名能把送药记录对上，但钥匙还锁在档案柜里。\n\n旧杆秤旁压着一页账册，翻开后才能确认开柜规则。")

func _use_cold_room_door() -> void:
	if not GameState.opening_flags.ch3_cold_door_seen:
		GameState.opening_flags.ch3_cold_door_seen = true
		checkpoint()
		update_objective()
	if not GameState.opening_flags.ch3_key_found:
		AudioManager.play_world_effect("lock_mechanism")
		show_text("维护门锁孔", "铁门通往隔壁长楼斜巷旧址，要用方形铜牌钥匙打开。钥匙锁在柜台档案柜里，先翻开十六两旧杆秤旁的账页。")
		return
	if not GameState.opening_flags.ch3_cold_door_open:
		_open_cold_room_door()
		return
	if not GameState.opening_flags.ch3_ticket_found:
		show_text("维护门后的暗道", "方牌钥匙已经打开维护门。后巷通向地面街道；时刻表还没收好，先回柜台拿上那张撕页。")
		return
	show_text("维护门后的暗道", "向前穿过门，走后巷去亚马喇前地。")

func _open_cold_room_door() -> void:
	GameState.opening_flags.ch3_cold_door_open = true
	checkpoint()
	work_in_progress = true
	player.controls_enabled = false
	player.clear_motion()
	cold_door_collision.set_deferred("disabled", true)
	cold_door_occluder.visible = false
	opened_leaf_collision.set_deferred("disabled", false)
	opened_leaf_occluder.visible = true
	cold_door_overlay.visible = true
	cold_door_overlay.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(cold_door_overlay, "modulate", Color.WHITE, 0.32)
	AudioManager.play_world_effect("gate_iron")
	await tween.finished
	if not is_inside_tree():
		return
	work_in_progress = false
	update_objective()
	show_text("方牌钥匙转动", "铁门开了，门后隐约飘来长楼斜巷旧址的阴风。拿上柜台的 33 路时刻表，穿门走后巷。")

func _can_depart_to_bus() -> bool:
	return GameState.opening_flags.ch3_cold_door_open and GameState.opening_flags.ch3_key_found and GameState.opening_flags.ch3_ticket_found and COLD_PASSAGE_ENTRY.has_point(player.position)

func _depart_to_bus() -> void:
	departing_to_bus = true
	player.controls_enabled = false
	player.clear_motion()
	show_text("肉铺后巷", "窄道尽头，街上暂时没有动静。", [], Callable(self, "_enter_quiet_passage"))

func _enter_quiet_passage() -> void:
	get_tree().paused = false
	if not GameState.request_room_change("ch3_quiet_passage", "from_archive"):
		departing_to_bus = false
		player.controls_enabled = true
		show_text("暗道尽头", "后巷暂时无法载入。大文仍留在资料室，请稍后重试。")

func _inspect_balance_rule() -> void:
	if not GameState.opening_flags.ch3_balance_rule_seen:
		GameState.opening_flags.ch3_balance_rule_seen = true
		checkpoint()
		update_objective()
	show_text("秤账背页", "账页写着：「半斤开柜，左盘三枚；饥寒同在。」\n左盘放 3 枚、合计 8 两，必须包含「饥」和「寒」。")

func _open_balance_board() -> void:
	if GameState.opening_flags.ch3_balance_solved:
		var remaining: Array[String] = []
		if not GameState.opening_flags.ch3_key_found:
			remaining.append("方牌备用钥匙")
		if not GameState.opening_flags.ch3_ticket_found:
			remaining.append("33 路时刻表与求生留言")
		show_text("档案柜", "柜门已经打开。柜台前沿还放着：%s。请分别查看并收好。" % "、".join(remaining) if not remaining.is_empty() else "柜内物品已经收好。按 B 可复查方牌钥匙、33 路时刻表和嘉敏的求生留言。")
		return
	if not GameState.opening_flags.ch3_cold_door_seen:
		show_text("旧杆秤", "秤梁旁的锁扣连着档案柜。先检查冷柜后维护门，确认照片上方铜牌的用途。")
		return
	if not GameState.opening_flags.ch3_balance_rule_seen:
		show_text("旧杆秤", "秤梁被锁扣牵住，手推不动。账册还没翻到背页；开柜条件得从那行旧记法里读出来。")
		return
	balance_board = preload("res://levels/ch3_amparo_alley/balance_board.gd").new()
	balance_board.solved.connect(_on_balance_solved)
	balance_board.close_requested.connect(_close_balance_board)
	balance_board.effect_requested.connect(AudioManager.play_world_effect)
	hud.open_widget(balance_board)
	get_tree().paused = true
	player.controls_enabled = false
	player.clear_motion()

func _on_balance_solved() -> void:
	GameState.opening_flags.ch3_balance_solved = true
	checkpoint()
	_refresh_archive_pickups()
	_reveal_archive_pickups()
	_close_balance_board(true)
	hud.show_resource_feedback("柜锁退开了。钥匙和时刻表落在柜台边。")
	update_objective()

func _close_balance_board(completed := false) -> void:
	# Once the scale settles, let its short success animation commit before
	# accepting Back; otherwise the player sees success but loses progress.
	if is_instance_valid(balance_board) and balance_board.get("solved_once") and not completed:
		return
	if is_instance_valid(balance_board):
		balance_board.queue_free()
	balance_board = null
	if is_instance_valid(hud):
		hud.close_panel()
	get_tree().paused = false
	if is_instance_valid(player):
		player.controls_enabled = true
		player.clear_motion()
	update_objective()

func show_text(title: String, body: String, choices: Array = [], after: Callable = Callable()) -> void:
	after_dialog = after
	if is_instance_valid(player):
		player.controls_enabled = false
		player.clear_motion()
	hud.open_panel(title, body, choices)
	get_tree().paused = true

func close_dialog(run_after := true) -> void:
	if not is_instance_valid(hud) or not hud.panel_open or is_instance_valid(balance_board):
		return
	var callback := after_dialog
	after_dialog = Callable()
	hud.close_panel()
	get_tree().paused = false
	player.controls_enabled = not work_in_progress and not departing_to_bus
	player.clear_motion()
	if run_after and callback.is_valid():
		callback.call()
	update_objective()

func _close_active_ui() -> void:
	if is_instance_valid(inventory_panel):
		inventory_panel.queue_free()
		inventory_panel = null
		hud.close_panel()
		get_tree().paused = false
		player.controls_enabled = true
		player.clear_motion()
		update_objective()
	elif is_instance_valid(balance_board):
		_close_balance_board()
	else:
		close_dialog()

func _open_inventory() -> void:
	inventory_panel = preload("res://ui/demo_bag.gd").new()
	hud.open_widget(inventory_panel)
	get_tree().paused = true
	player.controls_enabled = false
	player.clear_motion()

func _show_pause_menu() -> void:
	show_text("暂停", "调查会停在这里。", [
		{"text":"继续调查", "callback":close_dialog.bind(false)},
		{"text":"回到标题", "callback":_return_to_title}
	])

func _return_to_title() -> void:
	close_dialog(false)
	if not GameState.save_opening_checkpoint():
		show_text("保存失败", "当前进度未能保存，仍留在现场。请检查存储空间和文件夹权限后重试。")
		return
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")

func update_objective() -> void:
	if not is_instance_valid(hud): return
	var hints := PackedStringArray()
	if GameState.opening_flags.ch3_cold_door_seen and not GameState.opening_flags.ch3_balance_solved:
		hints = PackedStringArray([
			"用柜台上的杆秤打开资料柜，账页背面写了要求。",
			"对照半斤基准、砝码上的重量和“饥寒同在”。左盘还必须恰好三枚。",
			"把饥、寒、贪放入左盘。它们是 1、3、4 两，合计 8 两。"
		])
	hud.set_investigation_hints(player, hints, int(GameState.opening_flags.ch3_balance_rule_seen))
	if not GameState.opening_flags.ch3_cold_door_seen:
		hud.objective.text = "检查冷库后的维护门；旧账页就在柜台上。"
	elif not GameState.opening_flags.ch3_balance_rule_seen:
		hud.objective.text = "翻开秤账背页，确认半斤、三枚与饥寒的开柜条件。"
	elif not GameState.opening_flags.ch3_balance_solved:
		hud.objective.text = "按账页规则操作杆秤，打开旧铺资料柜。"
	elif not (GameState.opening_flags.ch3_key_found and GameState.opening_flags.ch3_ticket_found):
		hud.objective.text = "柜台前沿有备用钥匙与嘉敏写过字的时刻表，分别查看。"
	elif not GameState.opening_flags.ch3_cold_door_open:
		hud.objective.text = "用方牌钥匙打开维护门，沿后巷返回地面。"
	else:
		hud.objective.text = "穿过冷柜后的铁门，走后巷。"
	hud.state_text.text = "旧铺档案可选调查：合照 %s  登记 %s  送药信 %s  访客簿 %s" % [
		"✓" if GameState.opening_flags.ch3_photo_seen else "·",
		"✓" if GameState.opening_flags.ch3_register_seen else "·",
		"✓" if GameState.opening_flags.ch3_delivery_seen else "·",
		"✓" if GameState.opening_flags.ch3_visitor_log_seen else "·"]

func _evidence_status() -> String:
	return "合照：%s\n常住登记：%s\n送药旧信：%s\n访客簿：%s\n方牌钥匙：%s\n时刻表撕页：%s" % [
		"已查" if GameState.opening_flags.ch3_photo_seen else "未查",
		"已查" if GameState.opening_flags.ch3_register_seen else "未查",
		"已查" if GameState.opening_flags.ch3_delivery_seen else "未查",
		"已查" if GameState.opening_flags.ch3_visitor_log_seen else "未查",
		"已取得" if GameState.opening_flags.ch3_key_found else "未取得",
		"已取得" if GameState.opening_flags.ch3_ticket_found else "未取得"
	]

func checkpoint() -> void:
	if not GameState.save_opening_checkpoint() and is_instance_valid(hud):
		hud.show_resource_feedback("进度保存失败，仍可继续。请检查存储空间和文件夹权限后重试。")

func _notification(what: int) -> void:
	if is_instance_valid(balance_board):
		if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
			balance_board.set_focus_suspended(true)
		elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
			balance_board.set_focus_suspended(false)
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud) and is_instance_valid(player) and not hud.panel_open and not get_tree().paused:
		_show_pause_menu()
	if what == NOTIFICATION_PREDELETE and is_inside_tree():
		get_tree().paused = false
		AudioManager.set_scene_ambience("street")
