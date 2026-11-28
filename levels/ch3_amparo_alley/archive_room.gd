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
	"w17_ticket": Vector2(426, 117),
	"lens_cap": Vector2(513, 166)
}
const OPERA_RADIO_POINT := Vector2(182, 134)
const TARGET_NAMES := {
	"photo":"查看屠夫与学徒旧合照",
	"resident_register":"检查断手叉烧包血盆",
	"balance_rule":"翻阅秤账背页",
	"delivery_letter":"查看邮差投诉旧信",
	"visitor_log":"翻阅肉铺封存账单",
	"cold_door":"检查冷柜后维护门",
	"balance":"检查旧杆秤",
	"archive_key":"检查方牌备用钥匙",
	"w17_ticket":"查看 33 路时刻表",
	"lens_cap":"查看冷柜下的镜头盖",
	"opera_radio":"调听桌角旧收音机（粤剧）"
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
var butcher_ref: CharacterBody2D
var clue_glints: Dictionary = {}

func _ready() -> void:
	GameState.prepare_opening_resume()
	call_deferred("_setup_room")

func _setup_room() -> void:
	if GameState.current_room_id != ROOM_ID:
		push_error("第三章资料室由存档或正式路线进入；当前房间状态不匹配。")
		return
	AudioManager.set_scene_ambience("butcher_opera")
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
		GameState.unlock_macau_guide("amparo_alley")
		GameState.unlock_macau_guide("macau_cantonese_opera", false)
		GameState.unlock_macau_guide("archive_ledger", false)
		checkpoint()
		show_text("大关斜巷 · 旧肉铺后间", "街坊说，闹饥荒的时候，天一黑就没人敢走这条巷。肉铺早关了，收音机怎么还在唱？\n先看看右边那扇铁门。嘉敏可能走过这儿。")

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
	# Seal the upper lintel above the open cold-room floor threshold (y < 72) so the player cannot walk onto the door header while still reaching the departure doorway (y=75..94).
	LevelGeometry.wall(self, Rect2(508, 14, 118, 58))
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
	var basin_prop_path := "res://assets/props/ch3_blood_basin_prop_v6.png" if ResourceLoader.exists("res://assets/props/ch3_blood_basin_prop_v6.png") else "res://assets/props/ch3_blood_basin_v6.png"
	if ResourceLoader.exists(basin_prop_path):
		var basin_tex := load(basin_prop_path) as Texture2D
		if basin_tex != null:
			var basin := Sprite2D.new()
			basin.name = "BloodBasinVisual"
			basin.texture = basin_tex
			basin.position = TARGET_POINTS.resident_register
			basin.scale = Vector2(28.0 / float(basin_tex.get_width()), 20.0 / float(basin_tex.get_height()))
			basin.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			basin.z_index = 2
			add_child(basin)
	# Visible painted vintage 1980s wooden AM radio sitting on the left crate playing real Cantonese Opera
	var radio_pos := Vector2(158, 118)
	if ResourceLoader.exists("res://assets/props/butcher_radio_v10.png"):
		var radio_tex := load("res://assets/props/butcher_radio_v10.png") as Texture2D
		if radio_tex != null:
			var radio_sprite := Sprite2D.new()
			radio_sprite.name = "VintageOperaRadio"
			radio_sprite.texture = radio_tex
			radio_sprite.position = radio_pos
			radio_sprite.scale = Vector2(36.0 / float(radio_tex.get_width()), 26.0 / float(radio_tex.get_height()))
			radio_sprite.z_index = 122
			add_child(radio_sprite)
	var radio_glow := PointLight2D.new()
	radio_glow.name = "OperaRadioGlow"
	radio_glow.position = radio_pos + Vector2(6, -2)
	radio_glow.texture = preload("res://assets/lighting/soft_light.png")
	radio_glow.texture_scale = 0.22
	radio_glow.color = Color("f0a848")
	radio_glow.energy = 0.55
	add_child(radio_glow)
	var rtw := create_tween().set_loops()
	rtw.tween_property(radio_glow, "energy", 0.78, 0.9).set_trans(Tween.TRANS_SINE)
	rtw.tween_property(radio_glow, "energy", 0.42, 0.9).set_trans(Tween.TRANS_SINE)
	# Subtle warm amber document glints so closely spaced counter clues are visually unmistakable before inspection
	var glint_tex := preload("res://assets/lighting/soft_light.png")
	for cid in ["photo", "resident_register", "balance_rule", "delivery_letter", "visitor_log"]:
		var g := Sprite2D.new()
		g.name = "ClueGlint_%s" % cid
		g.texture = glint_tex
		g.position = TARGET_POINTS[cid] + Vector2(0, 6)
		g.scale = Vector2.ONE * 0.045
		g.modulate = Color(1.0, 0.86, 0.48, 0.55)
		g.z_index = 140
		add_child(g)
		clue_glints[cid] = g

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
	var tick_s := float(Time.get_ticks_msec()) * 0.001
	if is_instance_valid(warm_lamp):
		warm_lamp.energy = 0.32 + sin(tick_s * 3.1) * 0.025
	var glint_flags := {
		"photo": "ch3_photo_seen",
		"resident_register": "ch3_register_seen",
		"balance_rule": "ch3_balance_rule_seen",
		"delivery_letter": "ch3_delivery_seen",
		"visitor_log": "ch3_visitor_log_seen"
	}
	for cid in clue_glints:
		var g: Sprite2D = clue_glints[cid]
		if is_instance_valid(g):
			var seen: bool = bool(GameState.opening_flags.get(glint_flags[cid], false))
			g.visible = not seen
			if not seen:
				g.modulate.a = 0.32 + 0.28 * (0.5 + 0.5 * sin(tick_s * 3.4 + float(cid.length())))
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
	if selected_id.is_empty():
		var rdelta := OPERA_RADIO_POINT - player.position
		if rdelta.length() <= 92.0 and player.look_dir.dot(rdelta.normalized()) >= -0.1:
			selected_id = "opera_radio"
	if not selected_id.is_empty():
		hud.prompt.text = "[ E ] " + _target_name(selected_id)
		hud.prompt.position = Vector2(clampf(player.position.x - 70.0, 65.0, 445.0), clampf(player.position.y + 15.0, 145.0, 289.0))

func _target_name(id: String) -> String:
	if id == "cold_door" and GameState.opening_flags.ch3_cold_door_open:
		return "冲出冷库铁门" if GameState.opening_flags.ch3_ticket_found else "检查冷柜后的暗道"
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
		show_text("澳门手绘路线图", "路线图停在澳门旧街区。大关斜巷是竖井便签留下的下一处方向。")

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
			show_text("肉铺三人旧合照 · 屠夫与两名学徒", "发黄的旧合照里只有三个人：站在案板中间、围裙沾满血渍的老屠夫，以及左右两名面无血色的年轻学徒——照片里根本没有邮差。\n\n老屠夫腰间赫然挂着一枚「方形铜牌」。右方冷库铁门锁孔正缺一把方铜牌钥匙。", [], _maybe_prompt_inference)
		"resident_register":
			_record_evidence("ch3_register_seen")
			var basin_art := load("res://assets/props/ch3_blood_basin_v6.png") as Texture2D if ResourceLoader.exists("res://assets/props/ch3_blood_basin_v6.png") else null
			show_text("血盆 · 叉烧包与邮差制服碎片", "铁盆里渗着令人作呕的浓重血腥味，几只泛油的叉烧包旁竟混着残破血指与撕碎的绿白色邮差制服布角……", [], func():
				var taken_now := GameState.take_demo_item("jiamin_severed_finger")
				var finger_art := load("res://assets/props/jiamin_severed_finger_v6.png") as Texture2D if ResourceLoader.exists("res://assets/props/jiamin_severed_finger_v6.png") else null
				var desc := "血盆边缘还掉着一根惨白的断指——左手尾指戴着嘉敏那枚细银尾戒，指节旁还粘着出发前贴的米色创可贴！大文倒吸一口冷气，她曾在这里撞破屠夫惨案并拼死逃了出去。"
				if taken_now:
					desc += "\n\n【重要证物已收起】按 B 可在背包复查。"
				show_text("嘉敏带尾戒的断指", desc, [], _maybe_prompt_inference, finger_art)
			, basin_art)
		"balance_rule":
			_record_evidence("ch3_balance_rule_seen")
			_inspect_balance_rule()
		"delivery_letter":
			_record_evidence("ch3_delivery_seen")
			show_text("邮差投诉旧信 · 半夜剁肉与粤剧", "一张沾了油血迹的邮政内部投诉单留在这里，落款写着大关斜巷邮差：\n「邻街肉铺掌柜每到半夜三更就在后间锁门狂剁骨头，还故意把留声机里的粤剧（《蝴蝶梦》）开到震天响掩盖声音，街坊半夜被吵得睡不着——今晚投递完我就去敲他后门理论！」\n\n这正是血盆里那名失踪邮差最后留下的字据。", [], _maybe_prompt_inference)
		"visitor_log":
			_record_evidence("ch3_visitor_log_seen")
			show_text("肉铺封存账单 · 秤柜线索", "账页夹着肉铺查封前的出货单与一条急促红笔批注：\n「店里只报过三名肉铺人员，人手短缺却日日多出大量不明来历的『叉烧大包』熟肉出货。掌柜把后门方铜牌备用钥锁进了十六两老杆秤下的暗柜！开柜口诀压在柜台『秤账背页』里。」\n\n【下一步】去翻看「秤账背页」，再操作柜台右侧的「旧杆秤」开柜取钥匙！", [], _maybe_prompt_inference)
		"cold_door":
			_use_cold_room_door()
		"balance":
			_open_balance_board()
		"opera_radio":
			AudioManager.play_world_effect("scare_radio_static")
			show_text("旧晶体管收音机", "唱腔在一句没唱完的地方停住。大文把旋钮拨过半格，杂音里有人念了一遍店里的地址。\n\n手一松，旋钮自己滑了回去。唱词重新从那半句开始。")

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
	show_text("案卷还原 · 血盆与粤剧", "合照仅有屠夫与两名学徒；血盆里是邮差制服碎片与嘉敏的断指，收音机整夜循环粤剧。这间肉铺当年发生了什么？", [
		{"text":"屠夫半夜剁人做叉烧包并用粤剧掩盖，撞破的邮差已被灭口，嘉敏断指脱逃", "callback":_accept_guest_hypothesis},
		{"text":"邮差是肉铺第四名学徒，两人合伙经营夜间茶楼", "callback":_reject_guest_hypothesis.bind(1)},
		{"text":"血盆只是普通猪骨废料，粤剧和冷库门没有关联", "callback":_reject_guest_hypothesis.bind(2)}
	])

func _accept_guest_hypothesis() -> void:
	close_dialog(false)
	GameState.opening_flags.ch3_guest_inferred = true
	checkpoint()
	update_objective()
	show_text("暂定判断", "旧合照只有屠夫与两名学徒。邮差投诉夜半剁肉与粤剧后下落不明；嘉敏也在这间肉铺遇袭断指后逃往亚马喇前地。")

func _reject_guest_hypothesis(reason: int) -> void:
	close_dialog(false)
	var body := "合照上根本没有第四名学徒，血盆里撕碎的是绿白色邮差制服。" if reason == 1 else "嘉敏带银尾戒与创可贴的断指就在血盆旁，投诉信也明确指出了半夜剁骨与粤剧掩声。"
	show_text("证据还不够", body + "\n\n再核对桌上的四份证物。", [
		{"text":"重新核对材料", "callback":_show_inference}
	])

func _inspect_cold_door() -> void:
	if not GameState.opening_flags.ch3_cold_door_seen:
		GameState.opening_flags.ch3_cold_door_seen = true
		checkpoint()
		update_objective()
	AudioManager.play_world_effect("lock_mechanism")
	show_text("维护门锁孔", "门牌后留着一圈旧铜锈，方形牌槽的四角都有磨亮的擦痕，与合照中老屠夫腰间的方铜牌一致。\n\n旧杆秤旁压着一页账册，翻开后才能确认开柜规则。")

func _use_cold_room_door() -> void:
	if not GameState.opening_flags.ch3_cold_door_seen:
		GameState.opening_flags.ch3_cold_door_seen = true
		checkpoint()
		update_objective()
	if not GameState.opening_flags.ch3_key_found:
		AudioManager.play_world_effect("lock_mechanism")
		show_text("维护门锁孔", "铁门通往隔壁大关斜巷旧街面，要用方形铜牌钥匙打开。钥匙锁在柜台杆秤下的暗柜里，先翻开十六两旧杆秤旁的账页。")
		return
	if not GameState.opening_flags.ch3_cold_door_open:
		_open_cold_room_door()
		return
	if not GameState.opening_flags.ch3_ticket_found:
		AudioManager.play_world_effect("metal_latch")
		show_text("维护门后的暗道", "方牌钥匙已经打开维护门。后巷通向地面街道；时刻表还没收好，先回柜台拿上那张撕页。")
		return
	_depart_to_bus()

func _open_cold_room_door() -> void:
	GameState.opening_flags.ch3_cold_door_open = true
	checkpoint()
	work_in_progress = true
	if is_instance_valid(butcher_ref):
		butcher_ref.active = false
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
	if not is_instance_valid(butcher_ref) and get_node_or_null("ButcherGhost") == null:
		_spawn_butcher_ghost()
	elif is_instance_valid(butcher_ref) and not departing_to_bus:
		butcher_ref.active = true
	var escape_hint := "按 E 直接冲出铁门！" if GameState.opening_flags.ch3_ticket_found else "先拿上柜台的 33 路时刻表，再从铁门按 E 逃出！"
	show_text("铁门开了", "铁门后的冷风灌进屋里——" + escape_hint)

func _spawn_butcher_ghost() -> void:
	if is_instance_valid(butcher_ref) or get_node_or_null("ButcherGhost") != null:
		return
	var butcher = preload("res://entities/shadow_chaser.gd").new()
	butcher.name = "ButcherGhost"
	butcher.target = player
	butcher.position = Vector2(118, 265)
	butcher.speed = 68.0
	add_child(butcher)
	butcher_ref = butcher
	# Swap in dedicated Macau Butcher Ghost sprite: top row = walk cycle, bottom row = cleaver attack lunge!
	if ResourceLoader.exists("res://assets/characters/butcher_ghost_v6.png"):
		var bsheet: Texture2D = load("res://assets/characters/butcher_ghost_v6.png")
		var fig := butcher.get_node_or_null("Figure") as AnimatedSprite2D
		var trail := butcher.get_node_or_null("ShadowAfterimage") as Sprite2D
		if bsheet != null and fig != null:
			var bframes := SpriteFrames.new()
			bframes.add_animation("walk")
			bframes.set_animation_speed("walk", 4.4)
			bframes.add_animation("attack")
			bframes.set_animation_speed("attack", 6.8)
			var cw := bsheet.get_width() * 0.5
			var ch := bsheet.get_height() * 0.5
			for col in range(2):
				var fw := AtlasTexture.new()
				fw.atlas = bsheet
				fw.region = Rect2(col * cw, 0.0, cw, ch)
				fw.filter_clip = true
				bframes.add_frame("walk", fw)
				var fa := AtlasTexture.new()
				fa.atlas = bsheet
				fa.region = Rect2(col * cw, ch, cw, ch)
				fa.filter_clip = true
				bframes.add_frame("attack", fa)
			fig.sprite_frames = bframes
			fig.scale = Vector2.ONE * (110.0 / ch)
			fig.position = Vector2(0, -54)
			fig.play("walk")
			butcher.attack_animation_range = 92.0
			if trail != null:
				trail.scale = fig.scale
				trail.position = fig.position
	GhostTaunt.attach(butcher, PackedStringArray(["大关斜巷的肉……还差一两……", "别跑……八仙炉火正旺……", "躲进冷库也逃不掉……"]), 4.4)
	AudioManager.set_scene_ambience("")
	AudioManager.start_chase_music("butcher")
	butcher.active = false
	get_tree().create_timer(1.1, false).timeout.connect(func():
		if is_instance_valid(butcher) and not departing_to_bus and not work_in_progress:
			GhostTaunt.materialize_from_shadow(self, butcher.position)
			AudioManager.play_at(self, "scare_door_bang", butcher.position)
			butcher.active = true
	)
	butcher.caught.connect(func():
		AudioManager.stop_chase_music()
		if is_instance_valid(butcher):
			butcher.active = false
		player.controls_enabled = false
		player.clear_motion()
		get_tree().paused = true
		await DemoCaptureAnimation.play_on(self, DemoCaptureAnimation.BUTCHER_PATH)
		if not is_inside_tree():
			return
		get_tree().paused = false
		player.position = Vector2(320, 258)
		player.controls_enabled = true
		player.reset_physics_interpolation()
		# Keep the butcher hunting until Dawen actually escapes through the cold-room exit!
		if is_instance_valid(butcher):
			butcher.position = Vector2(118, 265)
			butcher.active = true
			butcher.reset_physics_interpolation()
		AudioManager.start_chase_music("butcher")
		if GameState.opening_flags.ch3_ticket_found:
			hud.notify("时刻表还在背包里。按住 Shift，穿过右上方的铁门。")
		else:
			hud.notify("按住 Shift 拉开距离，带上柜台的时刻表，再从铁门出去。")
	)

func _can_depart_to_bus() -> bool:
	return GameState.opening_flags.ch3_cold_door_open and GameState.opening_flags.ch3_key_found and GameState.opening_flags.ch3_ticket_found and COLD_PASSAGE_ENTRY.has_point(player.position)

func _depart_to_bus() -> void:
	departing_to_bus = true
	AudioManager.stop_chase_music()
	if is_instance_valid(butcher_ref):
		butcher_ref.active = false
	player.controls_enabled = false
	player.clear_motion()
	show_text("冲出冷库后巷", "沉重的冷库铁门在身后轰然合拢，终于甩开了拎着剁骨刀的肉铺怨灵！前方的老巷暂时没有动静。", [], Callable(self, "_enter_quiet_passage"))

func _enter_quiet_passage() -> void:
	AudioManager.stop_chase_music()
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
	_spawn_butcher_ghost()
	hud.show_resource_feedback("柜锁弹开惊动了暗处的屠夫！抓起钥匙与时刻表，开门冲出去！")
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

func show_text(title: String, body: String, choices: Array = [], after: Callable = Callable(), photo: Texture2D = null) -> void:
	after_dialog = after
	if is_instance_valid(player):
		player.controls_enabled = false
		player.clear_motion()
	hud.open_panel(title, body, choices, photo != null, "陈大文", null, photo)
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
	hud.state_text.text = "案卷核查（含真结局登记册）：合照 %s  血盆断指 %s  投诉信 %s  账单 %s  |  秤账 %s" % [
		"✓" if GameState.opening_flags.ch3_photo_seen else "○",
		"✓" if GameState.opening_flags.ch3_register_seen else "○",
		"✓" if GameState.opening_flags.ch3_delivery_seen else "○",
		"✓" if GameState.opening_flags.ch3_visitor_log_seen else "○",
		"✓" if GameState.opening_flags.ch3_balance_rule_seen else "○"]

func _evidence_status() -> String:
	return "三人合照：%s\n血盆与断指：%s\n邮差投诉信：%s\n肉铺账单：%s\n方牌钥匙：%s\n时刻表撕页：%s" % [
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
