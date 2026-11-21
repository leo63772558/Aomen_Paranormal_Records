extends Node2D

@export var stage_kind: String = "street"
const GIRL_FOOT := Vector2(405, 226)
const AHHAO_STREET_FOOT := Vector2(525, 238)
const ENTRY := Vector2(487, 159)
const METER := Vector2(210, 139)
const AMMO := preload("res://levels/ch2_guia/bunker_ammo_layout.gd")
const FAMILY := preload("res://entities/bunker_family.gd")
const CAPTURE := preload("res://ui/demo_capture_animation.gd")
const VENT_WORK_SHEET := preload("res://assets/characters/dawen_vent_work_099.png")
const VENT_WORK_SCALE := 0.16
const VENT_WORK_FEET := [Vector2(255,498), Vector2(235,492), Vector2(245,492), Vector2(235,486), Vector2(233,486), Vector2(235,488)]
const VENT_WORK_POSITION := Vector2(487,194)
const SPARE_BATTERIES := {
	"maintenance":["maintenance_spare_battery_taken", Vector2(155, 213)],
	"crypt":["crypt_spare_battery_taken", Vector2(183, 174)],
	"bunker_hall":["bunker_spare_battery_taken", Vector2(241, 198)]
}
var player: PlayerController
var hud
var camera_view
var girl: StaticBody2D
var girl_sprite: Sprite2D
var girl_portrait: Texture2D
var photo_marker: Node2D
var camera_pose: Sprite2D
var pastry_pose: Sprite2D
var pose_data: Dictionary
var dialogues: Dictionary
var camera_active: bool = false
var camera_capture_generation: int = 0
var selected_id: String = ""
var after_dialog: Callable
var work_in_progress: bool = false
var work_pose: Sprite2D
var stair_light: PointLight2D
var power_puzzle: Dictionary
var phone_sprite: Sprite2D
var phone_body: StaticBody2D
var phone_occluder: LightOccluder2D
var room_bed: StaticBody2D
var room_bed_shadow: LightOccluder2D
var room_vent: Sprite2D
var room_ambient: CanvasModulate
var hiding: bool = false
var hiding_return: Vector2
var room_lit_layer: TileMapLayer
var room_dark_layer: TileMapLayer
var shadow_event_running: bool = false
var yard_shadow: CharacterBody2D
var yard_chase_active: bool = false
var priest: CharacterBody2D
var priest_encounter_active: bool = false
var hill_demo_active: bool = false
var hill_reverse_time: float = 0.0
var hill_smoke: Node2D
var bunker_oil_prop: StaticBody2D
var demo_props: Dictionary = {}
var demo_prop_targets: Dictionary = {}
var room_aperture: StaticBody2D
var room_aperture_shadow: LightOccluder2D
var room_hatch: Sprite2D
var vent_work_pose: Sprite2D
var crypt_aperture: StaticBody2D
var crypt_aperture_shadow: LightOccluder2D
var gate_aperture: StaticBody2D
var gate_aperture_shadow: LightOccluder2D
var pit_bones: Sprite2D
var spare_battery
var family: Array[CharacterBody2D] = []
var capture_locked := false
var service_aperture: StaticBody2D
var service_aperture_shadow: LightOccluder2D
var wardrobe_view: CanvasLayer

func _ready() -> void:
	GameState.prepare_opening_resume()
	var expected_room: String={"street":"ch0_street", "foyer":"ch0_foyer", "corridor":"ch0_corridor", "room304":"ch0_room304", "maintenance":"ch0_maintenance", "yard":"ch0_yard", "exit_lane":"ch0_exit_lane", "crypt":"ch1_crypt_entry", "crypt_hall":"ch1_crypt_hall", "crypt_archive":"ch1_archive", "hill_base":"ch2_hill_base", "hill_shelter":"ch2_shelter", "bunker_descent":"ch2_bunker_descent", "bunker_hall":"ch2_bunker_hall", "bunker_ammo":"ch2_bunker_ammo"}[stage_kind]
	if GameState.opening_checkpoint_enabled() and GameState.current_room_id!=expected_room:
		hide()
		call_deferred("resume_saved_room")
		return
	var ambience_kind := "bunker" if stage_kind in ["bunker_descent", "bunker_hall", "bunker_ammo"] else ("crypt" if stage_kind in ["maintenance", "crypt", "crypt_hall", "crypt_archive"] else "")
	AudioManager.set_scene_ambience(ambience_kind)
	pose_data = JSON.parse_string(FileAccess.get_file_as_string("res://core/data/opening_art.json"))
	dialogues = JSON.parse_string(FileAccess.get_file_as_string("res://core/data/opening_dialogues.json"))
	power_puzzle = JSON.parse_string(FileAccess.get_file_as_string("res://core/data/opening_puzzles.json"))["p_ch0_floor_power"]
	var floor_layer = preload("res://core/components/room_tile_layer.gd").new()
	var backgrounds := {"street":"opening_006", "foyer":"foyer_006", "corridor":"corridor_010", "room304":"room304_clear_011", "maintenance":"maintenance_012", "yard":"service_yard_012", "exit_lane":"exit_laneway_012", "crypt":"crypt_marked_013", "crypt_hall":"crypt_hall_013", "crypt_archive":"crypt_archive_013", "hill_base":"hill_base_014", "hill_shelter":"bunker_entrance_2d_019", "bunker_descent":"bunker_stair_2d_019", "bunker_hall":"bunker_lowerroom_routes_023", "bunker_ammo":"bunker_ammo_pits_2d_022"}
	var background_path: String = "res://assets/tilesets/" + backgrounds[stage_kind] + ".png"
	floor_layer.background_texture = load(background_path)
	if stage_kind == "bunker_ammo":
		floor_layer.free()
		add_child(AMMO.new())
	else:
		add_child(floor_layer)
	if stage_kind == "hill_shelter":
		room_lit_layer = floor_layer
		room_dark_layer = preload("res://core/components/room_tile_layer.gd").new()
		room_dark_layer.background_texture = load("res://assets/tilesets/bunker_entrance_open_2d_021.png")
		add_child(room_dark_layer)
		room_dark_layer.visible = GameState.opening_flags.bunker_gate_unlocked
		room_lit_layer.visible = not room_dark_layer.visible
	if stage_kind == "room304":
		room_lit_layer = floor_layer
		room_dark_layer = preload("res://core/components/room_tile_layer.gd").new()
		room_dark_layer.background_texture = load("res://assets/tilesets/room304_outage_011.png")
		add_child(room_dark_layer)
		room_dark_layer.visible = GameState.opening_flags.room_phone_answered
		room_lit_layer.visible = not room_dark_layer.visible
	if stage_kind == "maintenance":
		room_lit_layer = floor_layer
		room_dark_layer = preload("res://core/components/room_tile_layer.gd").new()
		room_dark_layer.background_texture = load("res://assets/tilesets/maintenance_open_026.png")
		add_child(room_dark_layer)
		room_dark_layer.visible = GameState.opening_flags.maintenance_unlocked
		room_lit_layer.visible = not room_dark_layer.visible
	if stage_kind == "yard":
		room_lit_layer = floor_layer
		room_dark_layer = preload("res://core/components/room_tile_layer.gd").new()
		room_dark_layer.background_texture = load("res://assets/tilesets/service_yard_open_012.png")
		add_child(room_dark_layer)
		room_dark_layer.visible = GameState.opening_flags.yard_escaped
		room_lit_layer.visible = not room_dark_layer.visible
	if stage_kind == "exit_lane":
		room_lit_layer = floor_layer
		room_dark_layer = preload("res://core/components/room_tile_layer.gd").new()
		room_dark_layer.background_texture = load("res://assets/tilesets/exit_laneway_empty_phone_012.png")
		add_child(room_dark_layer)
		room_dark_layer.hide()
	if stage_kind == "crypt":
		room_lit_layer = floor_layer
		room_dark_layer = preload("res://core/components/room_tile_layer.gd").new()
		room_dark_layer.background_texture = load("res://assets/tilesets/crypt_open_013.png")
		add_child(room_dark_layer)
		room_dark_layer.visible = GameState.opening_flags.crypt_door_open
		room_lit_layer.visible = not room_dark_layer.visible
	if stage_kind == "crypt_hall":
		room_lit_layer = floor_layer
		room_dark_layer = preload("res://core/components/room_tile_layer.gd").new()
		room_dark_layer.background_texture = load("res://assets/tilesets/crypt_hall_open_013.png")
		add_child(room_dark_layer)
		room_dark_layer.visible = GameState.opening_flags.priest_escaped
		room_lit_layer.visible = not room_dark_layer.visible
	if stage_kind == "crypt_archive":
		room_lit_layer = floor_layer
		room_dark_layer = preload("res://core/components/room_tile_layer.gd").new()
		room_dark_layer.background_texture = load("res://assets/tilesets/crypt_archive_open_013.png")
		add_child(room_dark_layer)
		room_dark_layer.visible = GameState.pending_entry_id == "from_hill"
		room_lit_layer.visible = not room_dark_layer.visible
	var top_boundaries := {"street":147, "foyer":126, "corridor":207, "room304":175, "maintenance":195, "yard":170, "exit_lane":225, "crypt":145, "crypt_hall":185, "crypt_archive":205, "hill_base":218, "hill_shelter":205, "bunker_descent":60, "bunker_hall":168, "bunker_ammo":100}
	var wall_top: float = top_boundaries[stage_kind]
	var opening := Vector2(498, 544) if stage_kind == "room304" else (Vector2(506, 573) if stage_kind == "crypt" else Vector2.ZERO)
	if stage_kind == "hill_shelter":
		opening = Vector2(349, 412)
	if stage_kind == "maintenance":
		opening = Vector2(510, 581)
	if stage_kind != "bunker_ammo":
		LevelGeometry.room_bounds(self, wall_top, opening)
	if stage_kind == "maintenance" and not GameState.opening_flags.maintenance_unlocked:
		service_aperture = LevelGeometry.wall(self, Rect2(510, wall_top - 24, 71, 24))
		service_aperture_shadow = get_child(get_child_count() - 1)
	if stage_kind == "hill_shelter" and not GameState.opening_flags.bunker_gate_unlocked:
		gate_aperture = LevelGeometry.wall(self, Rect2(349, wall_top - 24, 63, 24))
		gate_aperture_shadow = get_child(get_child_count() - 1)
	if stage_kind == "room304" and not GameState.opening_flags.room_cover_open:
		room_aperture = LevelGeometry.wall(self, Rect2(498, wall_top - 24, 46, 24))
		room_aperture_shadow = get_child(get_child_count() - 1)
	if stage_kind == "bunker_descent":
		LevelGeometry.wall(self, Rect2(64,60,176,145))
		LevelGeometry.wall(self, Rect2(400,60,176,145))
	if stage_kind == "bunker_hall":
		for obstacle: Rect2 in AMMO.HALL_BLOCKS:
			LevelGeometry.wall(self, obstacle)
		_paint_machine_wall()
	if stage_kind == "bunker_descent":
		_create_pit_bones()
	if stage_kind == "hill_base":
		add_bunker_prop(Vector2(240,270), false)
	if stage_kind == "hill_shelter" and not GameState.opening_flags.bunker_oil_found:
		bunker_oil_prop = add_bunker_prop(Vector2(200,270), true)
	if stage_kind == "crypt_archive":
		LevelGeometry.wall(self, Rect2(64,205,115,24))
		LevelGeometry.wall(self, Rect2(190,205,280,10))
	if stage_kind == "hill_base":
		hill_smoke = Node2D.new()
		hill_smoke.position = Vector2(139,128)
		var plume := Sprite2D.new()
		plume.texture = load("res://assets/props/incense_smoke_014.png")
		plume.scale = Vector2(18,50) / plume.texture.get_size()
		plume.position = Vector2(0,-25)
		plume.modulate = Color(0.75,0.78,0.76,0.55)
		hill_smoke.add_child(plume)
		add_child(hill_smoke)
	if stage_kind == "crypt_hall":
		LevelGeometry.wall(self, Rect2(64, 276, 200, 34))
		LevelGeometry.wall(self, Rect2(376, 276, 200, 34))
	if stage_kind == "crypt":
		LevelGeometry.wall(self, Rect2(70, 145, 100, 19))
		if not GameState.opening_flags.crypt_door_open:
			crypt_aperture = LevelGeometry.wall(self, Rect2(506, 121, 67, 24))
			crypt_aperture_shadow = get_child(get_child_count() - 1)
	if stage_kind == "yard":
		LevelGeometry.wall(self, Rect2(166, 170, 88, 18))
		LevelGeometry.wall(self, Rect2(449, 170, 30, 18))
	if stage_kind == "exit_lane":
		LevelGeometry.wall(self, Rect2(64, 225, 70, 60))
		LevelGeometry.wall(self, Rect2(134, 225, 108, 31))
		LevelGeometry.wall(self, Rect2(540, 225, 36, 38))
	if stage_kind == "hill_shelter":
		LevelGeometry.wall(self, Rect2(64, 205, 106, 105))
		LevelGeometry.wall(self, Rect2(468, 205, 108, 105))
	if stage_kind == "corridor":
		LevelGeometry.wall(self, Rect2(154, 207, 90, 11))
		LevelGeometry.wall(self, Rect2(558, 207, 18, 11))
		var door_number := Label.new()
		door_number.position = Vector2(470, 95)
		door_number.text = "304"
		door_number.add_theme_font_size_override("font_size", 9)
		door_number.add_theme_color_override("font_color", Color("3b2918"))
		add_child(door_number)
	if stage_kind == "room304":
		LevelGeometry.wall(self, Rect2(70, 175, 126, 15))
		LevelGeometry.wall(self, Rect2(210, 175, 116, 31))
		room_vent = Sprite2D.new()
		room_vent.texture = DemoItems.prop_cell(10)
		if room_vent.texture == null:
			room_vent.texture = load("res://assets/props/vent_006.png")
		room_vent.scale = Vector2(63, 35) / room_vent.texture.get_size()
		room_vent.position = Vector2(520, 165)
		room_hatch = Sprite2D.new()
		var opening_art := AtlasTexture.new()
		opening_art.atlas = load("res://assets/props/room304_hatch_open_100.png")
		opening_art.region = Rect2(185, 155, 1280, 625)
		room_hatch.texture = opening_art
		room_hatch.position = Vector2(519, 165)
		room_hatch.scale = Vector2(50, 24) / opening_art.get_size()
		room_hatch.hide()
		add_child(room_hatch)
		room_vent.visible = GameState.opening_flags.room_bed_moved
		add_child(room_vent)
		if GameState.opening_flags.room_cover_open:
			show_room_vent_open()
		room_bed = LevelGeometry.wall(self, Rect2(490, 185, 65, 60))
		room_bed_shadow = get_child(get_child_count()-1)
		var bed_art := Sprite2D.new()
		bed_art.texture = load("res://assets/props/room304_bed_011.png")
		bed_art.position = Vector2(522, 164)
		bed_art.scale = Vector2(110, 170) / bed_art.texture.get_size()
		room_bed.add_child(bed_art)
		if GameState.opening_flags.room_bed_moved:
			room_bed.position = Vector2(-145, 10)
			room_bed_shadow.position = room_bed.position
		LevelGeometry.wall(self, Rect2(70, 215, 21, 95))
		LevelGeometry.wall(self, Rect2(528, 244, 48, 66))
	if stage_kind in ["corridor", "room304"] and not GameState.opening_flags.jiamin_phone_found:
		var phone_drop := Vector2(345, 280) if stage_kind == "room304" else Vector2(442, 236)
		phone_sprite = Sprite2D.new()
		phone_sprite.name = "JiaminPhoneSprite"
		phone_sprite.texture = load("res://assets/props/jiamin_phone_011.png")
		phone_sprite.position = phone_drop
		phone_sprite.scale = Vector2(19, 14) / phone_sprite.texture.get_size()
		phone_sprite.z_index = 2
		add_child(phone_sprite)
	var in_ch0_dark_304: bool = stage_kind == "room304" and (bool(GameState.opening_flags.get("room_phone_answered", false)) or bool(GameState.opening_flags.get("ah_hao_dead", false)) or GameState.pending_entry_id == "from_ah_escape")
	room_ambient = CanvasModulate.new()
	room_ambient.color = Color("e0d9bf") if stage_kind == "street" else (Color("6b756d") if in_ch0_dark_304 else Color("a6afa1"))
	add_child(room_ambient)
	player = preload("res://entities/player/player.tscn").instantiate()
	player.visual_size_multiplier = 1.65
	player.appearance = "flashlight" if stage_kind in ["maintenance", "yard", "exit_lane", "crypt", "crypt_hall", "crypt_archive", "hill_base", "hill_shelter", "bunker_descent", "bunker_hall", "bunker_ammo"] or in_ch0_dark_304 else "unarmed"
	player.position = Vector2(240, 258) if stage_kind == "street" else Vector2(320, 278)
	if stage_kind == "foyer" and GameState.pending_entry_id == "from_corridor":
		player.position = Vector2(510, 160)
	elif stage_kind == "maintenance":
		player.position = Vector2(110, 235)
	elif stage_kind == "yard":
		player.position = Vector2(115, 230)
	elif stage_kind == "exit_lane":
		player.position = Vector2(470, 260)
	elif stage_kind == "crypt_hall":
		player.position = Vector2(105, 220)
	elif stage_kind == "bunker_descent":
		player.position = Vector2(320, 80) if GameState.pending_entry_id == "from_gate" else Vector2(320, 280)
	elif stage_kind == "bunker_hall":
		player.position = Vector2(525, 210) if GameState.pending_entry_id == "from_ammo" else (Vector2(460, 210) if GameState.pending_entry_id == "from_shaft" else Vector2(320, 220))
	elif stage_kind == "hill_shelter" and GameState.pending_entry_id == "from_descent":
		player.position = Vector2(378, 224)
	elif stage_kind == "bunker_ammo":
		player.position = AMMO.ENTRY
	elif stage_kind == "room304" and GameState.pending_entry_id == "from_maintenance":
		player.position = Vector2(520, 200)
	if stage_kind == "street" and GameState.pending_entry_id == "from_foyer":
		player.position = Vector2(500, 166)
	add_child(player)
	player.reset_physics_interpolation()
	if stage_kind == "bunker_ammo":
		var follow := player.get_node("Camera2D") as Camera2D
		follow.enabled = true
		follow.position_smoothing_enabled = false
		follow.limit_left = 0
		follow.limit_top = 0
		follow.limit_right = int(AMMO.MAP_SIZE.x)
		follow.limit_bottom = int(AMMO.MAP_SIZE.y)
	camera_pose = PoseArt.sprite(load("res://assets/characters/dawen_camera_006.png"), pose_data["camera"])
	if stage_kind == "crypt_archive":
		camera_pose.scale *= 1.8
	pastry_pose = PoseArt.sprite(load("res://assets/characters/dawen_pastry_006.png"), pose_data["pastry"])
	add_child(camera_pose)
	add_child(pastry_pose)
	camera_pose.hide()
	pastry_pose.hide()
	work_pose = PoseArt.sprite(load("res://assets/characters/dawen_pliers_006.png"),pose_data.pliers)
	if stage_kind in ["corridor", "room304", "maintenance", "yard", "exit_lane", "crypt", "crypt_hall", "crypt_archive", "hill_base", "hill_shelter", "bunker_descent", "bunker_hall", "bunker_ammo"]:
		work_pose.scale *= 1.8
	add_child(work_pose)
	work_pose.hide()
	stair_light=PointLight2D.new()
	stair_light.position=Vector2(520,137)
	stair_light.texture=preload("res://assets/lighting/soft_light.png")
	stair_light.texture_scale=1.1
	stair_light.energy=.8
	stair_light.color=Color("ffdeb2")
	stair_light.range_item_cull_mask=3
	stair_light.shadow_enabled=true
	stair_light.enabled=stage_kind=="foyer" and GameState.opening_flags.floor3_power
	add_child(stair_light)
	if stage_kind == "street":
		create_girl()
		if not GameState.opening_flags.ah_hao_dead:
			create_ahhao_street()
		if not GameState.opening_flags.photo_taken:
			_create_photo_marker()
	_place_demo_props()
	if stage_kind == "crypt":
		_place_crypt_trail()
	hud = preload("res://ui/quiet_hud.gd").new()
	add_child(hud)
	hud.close_requested.connect(close_dialog)
	hud.phone_requested.connect(show_phone_notes)
	hud.pause_requested.connect(pause_menu)
	hud.resources.show_flashlight = player.allow_flashlight
	hud.set_phone_keytip(GameState.opening_flags.jiamin_phone_found and not GameState.opening_flags.phone_taught)
	camera_view = preload("res://ui/camera_view.gd").new()
	camera_view.size = Vector2(640, 360)
	camera_view.hide()
	hud.root.add_child(camera_view)
	camera_view.shutter_requested.connect(take_photo)
	camera_view.cancel_requested.connect(stop_camera)
	if stage_kind == "foyer":
		var body: String="楼梯口的灯仍亮着，可以上三零四找嘉敏了。" if GameState.opening_flags.floor3_power else dialogues.foyer.subtitle
		if not GameState.opening_load_notice.is_empty():
			body=GameState.opening_load_notice+"\n\n"+body
			GameState.opening_load_notice=""
		show_text("福荣里 · 门厅",body)
	elif not GameState.opening_load_notice.is_empty():
		hud.notify(GameState.opening_load_notice)
		GameState.opening_load_notice=""
	if stage_kind == "room304" and not GameState.opening_flags.room_phone_answered:
		var ring_timer := Timer.new()
		ring_timer.wait_time = 2.5
		ring_timer.one_shot = true
		add_child(ring_timer)
		ring_timer.timeout.connect(func():
			if not GameState.opening_flags.room_phone_answered:
				AudioManager.play_world_effect("rotary_ring")
				hud.notify("叮铃——桌上的旧电话响了。")
			ring_timer.queue_free()
		)
		ring_timer.start()
	if stage_kind == "street" and GameState.pending_entry_id == "arrival" and not GameState.opening_flags.photo_taken:
		show_text("第一天 · 澳门大三巴街", "前面就是大三巴！哥，你和我姐站近一点，我来选拍照的位置。", [], Callable(), "黄梓豪")
	if stage_kind == "hill_base" and GameState.pending_entry_id == "from_archive" and not GameState.opening_flags.hill_stele_seen:
		show_text("松山山麓", "防空洞在山道上方。先看看入口附近留下的物件。")
	if stage_kind == "bunker_hall" and GameState.pending_entry_id == "from_steps" and GameState.opening_flags.ammo_chase_cleared:
		hud.notify("机房的风声恢复了。沿来路上楼，带录音走出铁门。")
	elif stage_kind == "bunker_hall" and GameState.demo_pursuit == "hall":
		_begin_hall_chase()
	if stage_kind == "hill_shelter" and GameState.pending_entry_id == "from_descent" and GameState.opening_flags.ammo_chase_cleared:
		hud.notify("你已经站在铁门外。到门边复听带出的录音。")
	if stage_kind == "yard" and not GameState.opening_flags.yard_escaped:
		show_text("后院", "身后有脚步逼近。右侧拱门透着光——按住 Shift 冲过去。", [], start_yard_chase)
	if stage_kind == "crypt_hall" and not GameState.opening_flags.priest_escaped:
		show_text("昏暗石廊", "灯一照过去，黑袍底下那双脚就停了。右边有门。", [], start_priest_encounter)
	update_objective()

func _place_crypt_trail() -> void:
	var shoe := preload("res://assets/props/footprint_evidence_039.png")
	var impression := AtlasTexture.new()
	impression.atlas = shoe
	impression.region = Rect2(829, 365, 147, 241)
	impression.filter_clip = true
	for index in range(8):
		var step := Sprite2D.new()
		step.texture = impression
		step.position = Vector2(286 + index * 35, 224.0 - sin(index * 0.69) * 16.0 + (index % 2) * 7.0)
		step.scale = Vector2(7, 10) / impression.region.size
		step.rotation = PI * 0.5 + (-0.18 if index % 2 == 0 else 0.13)
		step.modulate = Color(0.6, 0.66, 0.57, 0.24)
		step.z_index = 1
		add_child(step)
	# A new chalk arrow bends from the sealed niche toward the scuffed side door.
	var arrow := Line2D.new()
	arrow.points = PackedVector2Array([
		Vector2(345, 157), Vector2(361, 162), Vector2(376, 162),
		Vector2(370, 156), Vector2(376, 162), Vector2(369, 166)
	])
	arrow.default_color = Color("c0b695", 0.77)
	arrow.width = 1.3
	arrow.antialiased = true
	arrow.z_index = 1
	add_child(arrow)

func _place_demo_props() -> void:
	if SPARE_BATTERIES.has(stage_kind):
		var supply: Array = SPARE_BATTERIES[stage_kind]
		if not GameState.opening_flags.get(supply[0], false):
			spare_battery = preload("res://core/components/spare_battery.gd").new()
			spare_battery.taken_flag = supply[0]
			spare_battery.position = supply[1]
			add_child(spare_battery)
	match stage_kind:
		"street":
			_add_prop_fixture(Vector2(167, 156), "iron_box")
			_add_demo_prop("insulated_bridge", Vector2(167, 156), Vector2(20, 14), "取出街边检修盒里的跨接片", Vector2(167, 193))
		"foyer":
			_add_prop_fixture(Vector2(124, 134), "wood_shelf")
			_add_prop_fixture(Vector2(304, 134), "clipboard_stand")
			_add_demo_prop("ceramic_fuse", Vector2(124, 134), Vector2(18, 14), "取出信箱架上的陶瓷保险芯", Vector2(124, 170))
			_add_demo_prop("power_record", Vector2(304, 134), Vector2(22, 17), "查看挂板上的电工值班单", Vector2(304, 165))
		"corridor":
			if GameState.opening_flags.wet_tag_left or GameState.opening_flags.shadow_passed:
				_add_demo_prop("wet_tag", Vector2(484, 229), Vector2(26, 18), "拾起门缝下湿透的检修签")
		"hill_base":
			_add_prop_fixture(Vector2(293, 254), "clipboard_stand")
			_add_demo_prop("gate_work_order", Vector2(293, 254), Vector2(26, 20), "拾取石台上的换锁工单")
		"bunker_descent":
			if not GameState.opening_flags.pit_stone_thrown:
				_add_demo_prop("loose_stone", Vector2(418, 235), Vector2(22, 17), "捡起碎石")
			preload("res://core/components/physics_prop.gd").spawn(self, "tin_can", Vector2(288, 215), Rect2(250, 150, 210, 140))
		"bunker_hall":
			preload("res://core/components/physics_prop.gd").spawn(self, "tin_can", Vector2(254, 235), Rect2(140, 185, 390, 105))
			preload("res://core/components/physics_prop.gd").spawn(self, "glass_bottle", Vector2(382, 248), Rect2(140, 185, 390, 105))
		"bunker_ammo":
			_add_demo_prop("bunker_recording", AMMO.RECORDING, Vector2(30, 24), "拾取嘉敏遗落的采访录音机")
		"room304":
			if not GameState.has_demo_item("service_handle"):
				_add_prop_fixture(Vector2(265, 218), "wood_shelf")
				_add_demo_prop("service_grip", Vector2(265, 218), Vector2(28, 19), "拾取抽屉托盘里的旧握柄")
		"crypt":
			_add_prop_fixture(Vector2(393, 151), "clipboard_stand")
			_add_demo_prop("crypt_old_photo", Vector2(393, 151), Vector2(26, 18), "拿起石龛台上的1961地宫旧照")
		"maintenance":
			if not GameState.has_demo_item("service_handle"):
				_add_prop_fixture(Vector2(418, 211), "iron_box")
				_add_demo_prop("service_spindle", Vector2(418, 211), Vector2(24, 18), "取出管线托盒里的方轴")

func _add_prop_fixture(at: Vector2, kind: String) -> void:
	var mount := Node2D.new()
	mount.position = at
	mount.z_index = int(at.y) - 1
	# Ground contact shadow
	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([Vector2(-16, 4), Vector2(16, 4), Vector2(18, 10), Vector2(-18, 10)])
	shadow.color = Color(0.02, 0.02, 0.02, 0.48)
	mount.add_child(shadow)
	# Front face of crate / wall shelf / metal utility cabinet
	var front := Polygon2D.new()
	front.polygon = PackedVector2Array([Vector2(-14, -2), Vector2(14, -2), Vector2(14, 7), Vector2(-14, 7)])
	front.color = Color("1f2622") if kind == "iron_box" else (Color("2e1e14") if kind == "wood_shelf" else Color("241f18"))
	mount.add_child(front)
	# Top tray surface
	var top := Polygon2D.new()
	top.polygon = PackedVector2Array([Vector2(-14, -12), Vector2(14, -12), Vector2(14, -2), Vector2(-14, -2)])
	top.color = Color("344039") if kind == "iron_box" else (Color("4f3622") if kind == "wood_shelf" else Color("3b3326"))
	mount.add_child(top)
	var rim := Line2D.new()
	rim.points = PackedVector2Array([Vector2(-14, -12), Vector2(14, -12), Vector2(14, 7), Vector2(-14, 7), Vector2(-14, -12)])
	rim.width = 1.2
	rim.default_color = Color("6b7668") if kind == "iron_box" else Color("856947")
	mount.add_child(rim)
	add_child(mount)

func _add_demo_prop(item_id: String, at: Vector2, dimensions: Vector2, action: String, interact_override := Vector2.ZERO) -> void:
	if GameState.has_demo_item(item_id):
		return
	var texture := DemoItems.texture(item_id)
	if texture == null:
		return
	var body := StaticBody2D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 2
	body.z_index = int(at.y)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10, 4)
	var shape_node := CollisionShape2D.new()
	shape_node.shape = shape
	body.add_child(shape_node)
	var art := Sprite2D.new()
	art.texture = texture
	art.scale = dimensions / texture.get_size()
	art.position = Vector2(0, -6)
	body.add_child(art)
	add_child(body)
	demo_props[item_id] = body
	var interact_at := interact_override if interact_override != Vector2.ZERO else (at + Vector2(0, 12))
	demo_prop_targets[item_id] = [interact_at, action]

func _collect_demo_prop(item_id: String) -> void:
	if not GameState.take_demo_item(item_id):
		return
	if item_id == "crypt_old_photo":
		GameState.opening_flags.crypt_photo_seen = true
	var prop: Node = demo_props.get(item_id)
	if is_instance_valid(prop):
		prop.queue_free()
	demo_props.erase(item_id)
	demo_prop_targets.erase(item_id)
	checkpoint()
	AudioManager.play_world_effect("metal_cover")
	if item_id == "bunker_recording":
		AudioManager.play_world_effect("recording_fragment")
		show_text("嘉敏的求生留言", "录音机留下了嘉敏在洞内的留言。\n\n转写：‘大文……阿豪……别从正门下来。这里有三道人影，楼梯口被堵住了。我只能试排风竖井。’\n\n阿豪的名字让大文一时说不出话。右侧响起拖地脚步，先把录音机带回机房。", [], start_red_passage, "陈大文", DemoItems.texture(item_id))
	else:
		show_text(DemoItems.title(item_id), DemoItems.description(item_id) + "\n\n已收进背包。按 B 回看。", [], Callable(), "陈大文", DemoItems.texture(item_id))

func add_bunker_prop(at: Vector2, is_oil: bool) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 2
	body.z_index = int(at.y)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(15, 12) if is_oil else Vector2(30, 12)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/props/bunker_tools_025.png")
	atlas.region = Rect2(1086, 0, 1086, 724) if is_oil else Rect2(0, 0, 1086, 724)
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.position = Vector2(0, -9)
	sprite.scale = (Vector2(48, 48) if is_oil else Vector2(72, 45)) / atlas.get_size()
	body.add_child(sprite)
	add_child(body)
	return body

func show_bunker_toolbox() -> void:
	var box = preload("res://ui/bunker_toolbox.gd").new()
	box.key_selected.connect(func(index: int):
		var item_id := "gate_key_%d" % index
		if GameState.take_demo_item(item_id):
			GameState.opening_flags["bunker_key_%d" % index] = true
			checkpoint()
			AudioManager.play_world_effect("lock_mechanism")
		box.feedback = DemoItems.title(item_id) + "已收进背包。对照锁面磨槽与换锁工单。"
		box.queue_redraw()
	)
	open_demo_widget(box)

func add_pit_collision(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = rect.get_center()
	body.add_child(collision)
	add_child(body)

func start_red_passage() -> void:
	if not GameState.demo_pursuit.is_empty() or GameState.opening_flags.ammo_chase_cleared:
		return
	GameState.opening_flags.bunker_red_seen = true
	checkpoint()
	GameState.demo_pursuit = "ammo"
	AudioManager.start_chase_music()
	var grid := AMMO.navigation(AMMO.INNER_ROOM, AMMO.pit_colliders())
	_spawn_family([Vector2(380, 121), Vector2(64, 255), Vector2(706, 403)], grid, 1.30)
	AudioManager.play_at(self, "hall_wail", Vector2(706, 403))
	hud.notify("三个人影在坑边停下。绕开他们，回南边的机房门。")
	update_objective()

func _spawn_family(positions: Array, navigation: AStarGrid2D, delay: float) -> void:
	for role in range(3):
		var figure = FAMILY.new()
		figure.role_id = role
		figure.target = player
		figure.position = positions[role]
		figure.grid = navigation
		figure.caught.connect(_family_caught)
		add_child(figure)
		family.append(figure)
	await get_tree().create_timer(delay, false).timeout
	if capture_locked:
		return
	for figure in family:
		if is_instance_valid(figure):
			figure.active = true

func _begin_hall_chase() -> void:
	AudioManager.start_chase_music()
	AudioManager.play_at(self, "door_approach", Vector2(550, 236))
	var grid := AMMO.navigation(AMMO.HALL_LIMITS, AMMO.HALL_BLOCKS)
	_spawn_family([Vector2(548, 268), Vector2(550, 294), Vector2(322, 289)], grid, 0.95)
	hud.notify("红衣人跟进来了。先从右侧小拱门下到深层梯道。")

func _family_caught(_role: int) -> void:
	AudioManager.stop_chase_music()
	if capture_locked:
		return
	for figure in family:
		figure.active = false
	_capture_cut("res://assets/characters/bunker_family_lunge_026.png", "被红衣人追上", "从子弹房口重新找路。横向走道连通左右两边，录音已经带在身上。", _retry_family)

func _retry_family() -> void:
	AudioManager.stop_chase_music()
	capture_locked = false
	close_dialog(false)
	GameState.demo_pursuit = ""
	change_opening_room("ch2_bunker_ammo", "from_hall")

func _paint_machine_wall() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["SimSun", "Noto Serif CJK SC"])
	var writing := Label.new()
	writing.text = "89  白线到头\n脚印回去，人莫回头"
	writing.position = Vector2(252, 104)
	writing.rotation = -0.048
	writing.add_theme_font_override("font", font)
	writing.add_theme_font_size_override("font_size", 14)
	writing.add_theme_color_override("font_color", Color("dfd4a9"))
	writing.add_theme_color_override("font_shadow_color", Color("2c3022"))
	writing.add_theme_constant_override("shadow_offset_y", 1)
	add_child(writing)

func _create_pit_bones() -> void:
	var texture := DemoItems.prop_cell(11)
	if texture == null:
		return
	pit_bones = Sprite2D.new()
	pit_bones.texture = texture
	pit_bones.position = Vector2(474, 136)
	pit_bones.scale = Vector2(65, 38) / texture.get_size()
	pit_bones.modulate = Color(0.72, 0.70, 0.61, 0.0)
	add_child(pit_bones)

func _inspect_pit() -> void:
	var text := "护沿下面黑得看不见底。手电朝右上方照，试试石壁有没有反光。"
	if GameState.opening_flags.pit_bones_seen:
		text = "手电扫过内壁时，露出一堆卡在窄石沿上的白骨。大文无法分辨是谁。"
	if GameState.has_demo_item("loose_stone") and not GameState.opening_flags.pit_stone_thrown:
		show_text("右侧深坑", text, [{"text":"把碎石抛进坑里", "callback":_throw_stone},{"text":"返回护沿", "callback":close_dialog}])
	else:
		show_text("右侧深坑", text + ("\n\n碎石撞了几次，回声才沉下去。" if GameState.opening_flags.pit_stone_thrown else "\n\n脚边有枚松动的碎石。"))

func _throw_stone() -> void:
	if work_in_progress or not GameState.has_demo_item("loose_stone"):
		return
	close_dialog(false)
	work_in_progress = true
	player.controls_enabled = false
	player.clear_motion()
	var arm: Sprite2D
	var path := "res://assets/characters/dawen_throw_026.png"
	if ResourceLoader.exists(path):
		arm = Sprite2D.new()
		arm.texture = load(path)
		arm.hframes = 2
		arm.scale = Vector2.ONE * 69.0 / arm.texture.get_height()
		arm.position = player.position + Vector2(0, -35)
		arm.offset.x = -35
		arm.z_index = int(player.position.y) + 1
		add_child(arm)
		player.sprite.hide()
		await get_tree().create_timer(0.18, false).timeout
		arm.frame = 1
		arm.offset.x = 103
	var stone := Sprite2D.new()
	stone.texture = DemoItems.texture("loose_stone")
	stone.position = player.position + Vector2(12, -29)
	stone.scale = Vector2.ONE * 10.0 / stone.texture.get_height()
	stone.z_index = 312
	add_child(stone)
	var toss := create_tween()
	toss.tween_property(stone, "position", Vector2(464, 146), 0.29).set_trans(Tween.TRANS_SINE)
	toss.tween_property(stone, "position", Vector2(476, 184), 0.28)
	toss.parallel().tween_property(stone, "modulate:a", 0.0, 0.28)
	await toss.finished
	stone.queue_free()
	if is_instance_valid(arm):
		arm.queue_free()
	player.sprite.show()
	AudioManager.play_at(self, "pit_drop", Vector2(471, 174))
	GameState.opening_items.erase("loose_stone")
	GameState.opening_flags.pit_stone_thrown = true
	checkpoint()
	work_in_progress = false
	player.controls_enabled = true
	hud.notify("先是一声轻响……下面很远的地方，又传回几次碰撞。")

func resume_saved_room() -> void:
	if not GameState.request_room_change(GameState.current_room_id,GameState.pending_entry_id):
		GameState.current_room_id="ch0_street"
		GameState.pending_entry_id="arrival"
		GameState.opening_load_notice="存档场景未能打开，进度文件已保留。"
		get_tree().reload_current_scene()

func checkpoint() -> void:
	if not GameState.save_opening_checkpoint() and is_instance_valid(hud):
		hud.notify("开场进度未能写入磁盘，本次仍可继续游玩。")

func create_ahhao_street() -> void:
	var body := StaticBody2D.new()
	body.name = "AhHaoStreet"
	body.position = AHHAO_STREET_FOOT
	body.z_index = int(AHHAO_STREET_FOOT.y)
	body.collision_layer = 1
	body.collision_mask = 2
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 11.0
	collision.shape = shape
	body.add_child(collision)
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/ahhao_walk_043_layout.json"))
	var frame: Dictionary = layout.frames[4][0].duplicate()
	frame["scale"] = float(layout.scale) * 1.65
	body.add_child(PoseArt.sprite(preload("res://assets/characters/ahhao_walk_043.png"), frame))
	add_child(body)

func create_girl() -> void:
	girl = StaticBody2D.new()
	girl.name = "Jiamin"
	girl.position = GIRL_FOOT
	girl.collision_layer = 1
	girl.collision_mask = 2
	var shape := CircleShape2D.new()
	shape.radius = 11
	var collision := CollisionShape2D.new()
	collision.shape = shape
	girl.add_child(collision)
	add_child(girl)
	set_girl_pose(2)
	var portrait := AtlasTexture.new()
	portrait.atlas = load("res://assets/characters/jiamin_006.png")
	var rect = pose_data["girl_portrait"]
	portrait.region = Rect2(rect[0], rect[1], rect[2], rect[3])
	girl_portrait = portrait

func set_girl_pose(index: int) -> void:
	if girl_sprite != null:
		girl.remove_child(girl_sprite)
		girl_sprite.queue_free()
	girl_sprite = PoseArt.sprite(load("res://assets/characters/jiamin_006.png"), pose_data["girl"][index])
	girl_sprite.scale = Vector2.ONE * (float(pose_data["girl"][index]["scale"]) * 1.65)
	girl.add_child(girl_sprite)
	girl.z_index = int(GIRL_FOOT.y)

func _create_photo_marker() -> void:
	if photo_marker != null:
		return
	photo_marker = Node2D.new()
	photo_marker.position = Vector2(245, 258)
	photo_marker.z_index = 8
	var marker_script := GDScript.new()
	marker_script.source_code = """extends Node2D
func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_arc(Vector2.ZERO, 18.0, 0, TAU, 28, Color(0.95, 0.85, 0.45, 0.7), 1.5)
	draw_arc(Vector2.ZERO, 5.0, 0, TAU, 16, Color(0.95, 0.85, 0.45, 0.85), 1.5)
	draw_string(font, Vector2(-60, -22), "推荐拍照位 [ C 键 ]", HORIZONTAL_ALIGNMENT_CENTER, 120, 11, Color(0.95, 0.88, 0.65, 0.85))
"""
	marker_script.reload()
	photo_marker.set_script(marker_script)
	add_child(photo_marker)

func _process(_delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(hud):
		return
	selected_id = ""
	hud.state_text.hide()
	hud.prompt.text = ""
	if camera_active:
		if is_instance_valid(camera_view):
			camera_view.is_valid_framing = photo_is_valid()
			var dist := player.position.distance_to(GIRL_FOOT)
			if dist < 100:
				camera_view.hint_text = "站得太近了，请退后几步"
			elif dist > 220:
				camera_view.hint_text = "走近一些，不要离太远"
			elif player.position.x >= GIRL_FOOT.x - 50:
				camera_view.hint_text = "请站到嘉敏左侧的推荐拍摄位"
			else:
				camera_view.hint_text = "移动鼠标，将嘉敏与上方建筑移入框内"
			camera_view.queue_redraw()
		return
	if work_in_progress:
		return
	if hiding:
		hud.prompt.text = "[ E ] 离开衣柜"
		return
	var targets: Dictionary = {"jiamin": GIRL_FOOT, "entry": ENTRY} if stage_kind == "street" else ({"door304":Vector2(483,207), "downstairs":Vector2(320,300)} if stage_kind == "corridor" else ({"desk304":Vector2(300,208), "bed304":Vector2(500,240) if not GameState.opening_flags.room_bed_moved else Vector2(365,260), "leave304":Vector2(320,300)} if stage_kind == "room304" else {"meter": METER, "stairs": Vector2(520, 139), "exit": Vector2(320, 298)}))
	if stage_kind in ["corridor", "room304"] and not GameState.opening_flags.jiamin_phone_found:
		targets["fallen_phone"] = Vector2(345, 280) if stage_kind == "room304" else Vector2(442, 236)
	if stage_kind == "room304" and GameState.opening_flags.room_bed_moved:
		targets["vent304"] = Vector2(520, 176)
	if stage_kind == "room304" and GameState.opening_flags.room_phone_answered:
		targets["wardrobe304"] = Vector2(145, 190)
	if stage_kind == "maintenance":
		targets = {"return_hatch":Vector2(100,195), "notice":Vector2(267,195), "steel_door":Vector2(550,195)}
	if stage_kind == "yard":
		targets = {"yard_exit":Vector2(550,170), "yard_return":Vector2(95,170)}
	if stage_kind == "exit_lane":
		targets = {"public_phone":Vector2(115,285), "city_stairs":Vector2(500,225), "back_gate":Vector2(345,225)}
	if stage_kind == "crypt":
		targets = {"crypt_desk":Vector2(120,166), "crypt_niche":Vector2(250,145), "crypt_door":Vector2(545,145), "crypt_exit":Vector2(320,300)}
	if stage_kind == "crypt_hall":
		targets = {"hall_exit":Vector2(550,185), "hall_back":Vector2(95,185)}
	if stage_kind == "crypt_archive":
		targets = {"archive_index":Vector2(125,230), "archive_exit":Vector2(545,205), "archive_back":Vector2(320,300)}
	if stage_kind == "hill_base":
		targets = {"hill_stele":Vector2(330,218), "hill_steps":Vector2(500,218), "hill_shrine":Vector2(140,218), "hill_back":Vector2(320,300), "bunker_toolbox":Vector2(240,250)}
	if stage_kind == "hill_shelter":
		targets = {"shelter_door":Vector2(374,213), "shelter_back":Vector2(320,300)}
		if GameState.opening_flags.ammo_chase_cleared:
			targets["review_tape"] = Vector2(340,246)
		if not GameState.opening_flags.bunker_oil_found:
			targets["bunker_oil"] = Vector2(200,250)
	if stage_kind == "bunker_descent":
		targets = {"descent_return":Vector2(320,69), "descent_hall":Vector2(320,300), "descent_pit":Vector2(465,215)}
	if stage_kind == "bunker_ammo":
		targets = {"ammo_pits":Vector2(373,432), "ammo_exit":AMMO.EXIT}
		if GameState.has_demo_item("bunker_recording") and not GameState.opening_flags.ammo_chase_cleared and GameState.demo_pursuit.is_empty():
			targets["ammo_restart"] = AMMO.RECORDING + Vector2(0, 13)
	if stage_kind == "bunker_hall":
		targets = {"bunker_bed":Vector2(190,232), "bunker_machine":Vector2(180,218), "bunker_graffiti":Vector2(320,180), "bunker_door":Vector2(550,178), "bunker_return":Vector2(320,300), "bunker_deep":Vector2(460,175)}
	if stage_kind == "street":
		targets["street_tiles"] = Vector2(330, 165)
		if has_node("AhHaoStreet"):
			targets["ahhao"] = AHHAO_STREET_FOOT
	for prop_id in demo_prop_targets:
		targets[prop_id] = demo_prop_targets[prop_id][0]
	if is_instance_valid(spare_battery) and not spare_battery.is_queued_for_deletion():
		targets["spare_battery"] = spare_battery.position + Vector2(0, 3)
	var nearest: float = INF
	for id in targets:
		var point: Vector2 = targets[id]
		var delta: Vector2 = point - player.position
		var alignment := player.look_dir.dot(delta.normalized()) if delta.length() > 0.1 else 1.0
		var score := delta.length() + (1.0 - alignment) * 48.0
		if delta.length() > 48.0 or score >= nearest or (delta.length() > 10 and alignment < -0.05):
			continue
		var ray := PhysicsRayQueryParameters2D.create(player.position, point + Vector2(0, 9), 1)
		var hit := get_world_2d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider != girl and not (id == "ahhao" and hit.collider == get_node_or_null("AhHaoStreet")) and not (id == "spare_battery" and hit.collider == spare_battery):
			continue
		selected_id = id
		nearest = score
	if not selected_id.is_empty():
		var names := {"jiamin":"和嘉敏说话", "entry":"进入唐楼", "meter":"检查电表箱", "stairs":"上楼", "exit":"返回街口", "door304":"调查 304 房门", "downstairs":"下楼", "fallen_phone":"拾起手机", "desk304":"查看书桌", "bed304":"查看铁床", "leave304":"回到走廊", "vent304":"检查检修盖", "wardrobe304":"躲进衣柜", "return_hatch":"返回 304", "notice":"查看检修牌", "steel_door":"检查铁门", "yard_exit":"穿过拱门", "yard_return":"返回检修通道", "public_phone":"查看公用电话", "city_stairs":"通往牌坊的石阶", "back_gate":"查看铁门", "crypt_desk":"查看资料桌", "crypt_niche":"查看石壁", "crypt_door":"查看侧门", "crypt_exit":"返回地面", "crypt_seam":"查看石像下的石缝", "hall_exit":"打开走廊尽头的门", "hall_back":"退回地宫入口", "archive_index":"查看采访索引", "archive_exit":"检查出口", "archive_back":"返回石廊", "hill_stele":"查看石碑", "hill_steps":"上山道", "hill_shrine":"查看香炉", "hill_back":"返回资料室", "bunker_toolbox":"检查旧维修箱", "bunker_oil":"拾取油壶", "shelter_door":"检查防空洞门", "shelter_board":"查看告示牌", "shelter_back":"返回山脚", "bunker_bed":"查看床铺", "bunker_door":"检查铁门", "bunker_return":"返回下行楼梯", "bunker_machine":"检查生锈的机器", "bunker_graffiti":"查看涂鸦", "ammo_pits":"查看坑位", "ammo_exit":"返回机房", "bunker_deep":"查看深处", "descent_return":"返回铁门", "descent_hall":"走向下层", "descent_pit":"查看深坑"}
		names["street_tiles"] = "查看街牌和石仔路"
		names["ahhao"] = "和阿豪说话"
		names["review_tape"] = "复听录音" if not GameState.opening_flags.demo_case_closed else "查看调查结语"
		names["ammo_restart"] = "重新从这里带录音撤离"
		names["spare_battery"] = "更换备用电池"
		var action: String = demo_prop_targets[selected_id][1] if demo_prop_targets.has(selected_id) else names.get(selected_id, "调查")
		hud.prompt.text = "[ E ] " + action
		var screen := get_viewport().get_canvas_transform() * player.global_position
		hud.prompt.position = Vector2(clampf(screen.x - 40, 65, 420), clampf(screen.y + 13, 145, 289))

func _physics_process(delta: float) -> void:
	if stage_kind == "bunker_descent" and is_instance_valid(pit_bones):
		var ray := pit_bones.position - player.get_flashlight_origin()
		var lit: bool = player.flashlight_on and player.lamp.enabled and player.position.distance_to(pit_bones.position) < 132.0 and player.look_dir.dot(ray.normalized()) > 0.78
		pit_bones.modulate.a = move_toward(pit_bones.modulate.a, 1.0 if lit else 0.0, delta * 3.7)
		if lit and pit_bones.modulate.a > 0.8 and not GameState.opening_flags.pit_bones_seen:
			GameState.opening_flags.pit_bones_seen = true
			checkpoint()
			hud.notify("光在深处的石沿扫出几根白骨。")
	if stage_kind != "hill_base" or not hill_demo_active or not is_instance_valid(player):
		return
	if player.look_dir.dot(Vector2.UP) < -0.5:
		hill_reverse_time += delta
		if is_instance_valid(hill_smoke):
			hill_smoke.rotation = lerpf(hill_smoke.rotation, 0.9, minf(delta * 5, 1.0))
		if hill_reverse_time >= 0.6:
			hill_demo_active = false
			GameState.opening_flags.hill_warning_seen = true
			checkpoint()
			hud.notify("香烟向后偏了：危险路段不要回头。这里是安全演示。")
			update_objective()
	else:
		hill_reverse_time = 0.0
		if is_instance_valid(hill_smoke):
			hill_smoke.rotation = lerpf(hill_smoke.rotation, 0.0, minf(delta * 5, 1.0))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if work_in_progress:
		return
	if event.is_action_pressed("camera_mode") and stage_kind == "street":
		get_viewport().set_input_as_handled()
		start_camera()
	elif event.is_action_pressed("interact") and not camera_active:
		get_viewport().set_input_as_handled()
		if hiding:
			exit_room_wardrobe()
		else:
			interact_target(selected_id)
	elif event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		show_bag()
	elif event.is_action_pressed("map") and GameState.has_demo_item("trip_map"):
		get_viewport().set_input_as_handled()
		show_travel_map()
	elif event.is_action_pressed("phone") or event.is_action_pressed("journal"):
		get_viewport().set_input_as_handled()
		if GameState.opening_flags.jiamin_phone_found:
			show_phone_notes()
		else:
			var body := "旅行照：%s\n葡挞：%s\n敲门暗号：两下，再一下。" % ["已拍下" if GameState.opening_flags.photo_taken else "还没有拍", "已经分享" if GameState.opening_flags.pastry_shared else "嘉敏还拿着纸袋"]
			show_text("旅行记录", body)
	elif event.is_action_pressed("flashlight"):
		if not player.allow_flashlight:
			hud.notify("手电留在包里，先把眼前的事办好。")

func interact_target(id: String) -> void:
	if id == "spare_battery" and is_instance_valid(spare_battery):
		hud.show_resource_feedback(spare_battery.collect(player))
		return
	if demo_prop_targets.has(id):
		_collect_demo_prop(id)
		return
	match id:
		"ahhao":
			show_text("阿豪", "姐夫，等我调好这盏补光灯，待会进旧唐楼拍片就不用摸黑找开关了。听说这楼地底真连着大三巴墓室！", [], Callable(), "黄梓豪")
		"street_tiles":
			show_text("葡式街牌与土地神龛", "蓝白瓷砖写着「福荣里 Beco da Felicidade」，脚下是黑白波浪石仔路，墙角土地财神龛还燃着三支红香。顺着前面石阶往上就是大三巴牌坊。")
		"jiamin":
			if not GameState.opening_flags.photo_taken:
				show_line("photo_invite")
			elif not GameState.opening_flags.pastry_shared:
				set_girl_pose(1)
				show_line("pastry_offer", [{"text":"接过葡挞", "callback": accept_pastry}, {"text":"等一下", "callback":close_dialog}])
			else:
				show_line("knock", [], agree_knock)
		"entry":
			if not GameState.opening_flags.photo_taken:
				show_text("出发前", "嘉敏还在等你替她拍照。按 C 举起手机，退后一些，把她和建筑一起拍进去。")
			elif not GameState.opening_flags.pastry_shared:
				show_text("出发前", "嘉敏向你举了举纸袋：葡挞还热，先过来拿。")
			elif not GameState.opening_flags.knock_agreed:
				show_line("knock", [], agree_knock)
			else:
				show_line("enter", [], enter_foyer)
		"meter":
			if GameState.opening_flags.floor3_power:
				show_text("三楼支路已恢复", "楼梯口透出暖光。嘉敏还在三零四等你。", [{"text":"查看线路", "callback":show_power_puzzle},{"text":"返回", "callback":close_dialog}])
			elif GameState.opening_flags.meter_cover_open:
				show_power_puzzle()
			else:
				show_text("一楼电表箱", "先用工具钳拆下检修盖。检查测试表，再去值班台和街口找维修备件。值班工单写了哪路需要隔离。", [{"text":"用工具钳拆盖","callback":remove_meter_cover},{"text":"再看看","callback":close_dialog}])
		"stairs":
			if GameState.opening_flags.floor3_power:
				if not GameState.opening_flags.ah_hao_dead and not GameState.opening_flags.jiamin_phone_found:
					change_opening_room("ch0_ah_kin", "from_foyer")
				else:
					change_opening_room("ch0_corridor", "from_foyer")
			else:
				show_text("楼梯一片漆黑", "三楼门牌灯和楼梯灯都没亮。我先把一楼电表箱修好再上去找嘉敏。")
		"door304":
			if GameState.opening_flags.jiamin_phone_found:
				change_opening_room("ch0_room304", "from_corridor")
			else:
				show_text("304 房门", "我按暗号敲了两下，停一停，再敲一下……里面没人应。门边地上掉着嘉敏的手机。")
		"fallen_phone":
			pickup_phone()
		"desk304":
			if not GameState.opening_flags.room_phone_answered:
				show_text("书桌", "旧电话还在响，旁边放着一张泛黄的照片。", [{"text":"接听电话", "callback":answer_room_phone},{"text":"查看旧照", "callback":show_old_photo},{"text":"暂时离开", "callback":close_dialog}])
			else:
				show_old_photo()
		"bed304":
			if GameState.opening_flags.room_bed_moved:
				show_text("铁床", "床已经移开，墙边露出检修位置。")
			elif not GameState.opening_flags.room_phone_answered:
				show_text("铁床", "床脚有新拖痕。书桌上的旧电话正在响，先去看看。")
			elif not GameState.opening_flags.wardrobe_tutorial_done:
				show_text("铁床", "门外脚步还在。先从左边衣柜避一避。")
			elif not GameState.opening_flags.old_photo_seen:
				show_text("铁床", "花砖上的拖痕从床脚一路通到右后墙。先在书桌前展开福荣里旧合照。")
			else:
				show_text("旧照里的门在床后", "窗格和四瓣花砖与旧照相同。照片里铁床靠前，墙上有木门。现在拖痕停在墙脚。\n\n从床尾右侧把铁床推开，看看照片上的百叶还在不在。", [{"text":"推开铁床", "callback":move_room_bed},{"text":"重看旧合照", "callback":show_old_photo},{"text":"返回", "callback":close_dialog}])
		"leave304":
			if not GameState.opening_flags.room_phone_answered:
				if GameState.opening_flags.jiamin_phone_found:
					show_text("房门闩牢", "阿豪在门外遇害，门外隐约有刮擦游荡声，门栓已重重锁死。书桌上的旧座机正在尖响，先去书桌查清线索。")
				else:
					show_text("房门闩牢", "门外怪物正在过道徘徊，门栓已死。嘉敏的手机就在门边地上，书桌上的座机也正在尖响，先在房内排查线索。")
			else:
				change_opening_room("ch0_corridor", "from_room304")
		"wardrobe304":
			enter_room_wardrobe()
		"vent304":
			if GameState.opening_flags.room_cover_open:
				show_text("检修口", "盖板后面有一段狭窄的维护通道。边缘的划痕与嘉敏调查的门有关。", [{"text":"爬进通道", "callback":crawl_into_maintenance},{"text":"暂时离开", "callback":close_dialog}], Callable(), "陈大文", _vent_thread_detail())
			else:
				show_text("墙脚检修盖", "盖板旁有新划痕。嘉敏可能注意到了这里。", [{"text":"用工具钳拆盖", "callback":remove_room_cover}, {"text":"再看看", "callback":close_dialog}])
		"downstairs":
			if not GameState.opening_flags.jiamin_phone_found:
				show_text("先找嘉敏", "已经到三楼了，嘉敏在 304 还没回应，我得先去 304 看看，不能现在退回去。")
			else:
				change_opening_room("ch0_foyer", "from_corridor")
		"exit":
			if not GameState.opening_flags.floor3_power:
				show_text("离开唐楼？", "嘉敏还在三楼等我，我先把电表修好恢复供电，不能丢下她。")
			else:
				return_street()
		"return_hatch":
			change_opening_room("ch0_room304", "from_maintenance")
		"notice":
			show_text("检修牌", "配重门的检修手柄可以拆下。握柄在旧房书桌边，方轴在通道管线下。两件取齐后按 B 组装。\n\n门框上有新的擦痕。门外那张湿检修签记着怎么给锁舌卸力。")
		"steel_door":
			if GameState.opening_flags.maintenance_unlocked:
				change_opening_room("ch0_yard", "from_maintenance")
			else:
				show_maintenance_lock()
		"yard_return":
			if yard_chase_active:
				hud.notify("门被身后的黑影挡住了，快往右侧拱门跑。")
			else:
				change_opening_room("ch0_maintenance", "from_yard")
		"yard_exit":
			escape_yard()
		"public_phone":
			call_public_phone()
		"city_stairs":
			show_text("牌坊方向", "石阶上挂着嘉敏衣服的碎布。她往牌坊去了。", [{"text":"前往牌坊", "callback":go_to_crypt},{"text":"返回", "callback":close_dialog}])
		"back_gate":
			show_text("铁门", "刚才穿出的铁门已经关上，从这里打不开。")
		"crypt_desk":
			show_crypt_desk()
		"crypt_niche":
			show_crypt_evidence("doodle")
		"crypt_door":
			if GameState.opening_flags.crypt_door_open:
				change_opening_room("ch1_crypt_hall", "from_entry")
			elif GameState.opening_flags.crypt_clip_removed:
				open_crypt_door()
			elif GameState.opening_flags.crypt_aligned:
				show_text("右侧维护门", "门框下沿有一枚后加的金属扣，正卡在这扇门的下插销上。", [{"text":"用钳松开门框卡扣", "callback":remove_crypt_clip},{"text":"返回", "callback":close_dialog}])
			else:
				show_text("右侧维护门", "鞋印在这里停了。门框底下有个新装的扣。用资料桌的旧图看看原来的门是怎么开的。")
		"crypt_exit":
			change_opening_room("ch0_exit_lane", "from_crypt")
		"hall_back":
			priest_encounter_active = false
			change_opening_room("ch1_crypt_entry", "from_hall")
		"hall_exit":
			escape_priest()
		"archive_index":
			copy_interview_index()
		"archive_exit":
			if GameState.opening_flags.interview_index_copied:
				show_text("资料室出口", "嘉敏在旧图上圈了东望洋松山防空洞，旁边批注着「99 级鬼阶莫回头」。她已经顺着暗渠往松山去了。", [{"text":"前往松山", "callback":leave_archive_for_hill},{"text":"返回", "callback":close_dialog}])
			else:
				show_text("资料室出口", "门外吹来冷风。先看完桌上那份松山怪谈采访索引再走。")
		"archive_back":
			change_opening_room("ch1_crypt_hall", "from_archive")
		"hill_stele":
			show_hill_stele()
		"hill_shrine":
			show_text("山脚神龛与灯塔光", "松山脚的石龛插着三支引路香，老警员传闻夜巡松山绝不能回头。头顶东望洋灯塔的白光一圈圈扫过浓雾，半山更亭隐约飘来收音机的粤剧唱腔。")
		"hill_steps":
			change_opening_room("ch2_shelter", "from_base")
		"hill_back":
			change_opening_room("ch1_archive", "from_hill")
		"bunker_toolbox":
			show_bunker_toolbox()
		"bunker_oil":
			GameState.opening_flags.bunker_oil_found = true
			GameState.take_demo_item("oil")
			if is_instance_valid(bunker_oil_prop):
				bunker_oil_prop.queue_free()
			checkpoint()
			AudioManager.play_world_effect("metal_cover")
			show_text("旧油壶", "油壶里还剩一点润滑油。或许可以处理锈住的锁眼。")
		"shelter_door":
			if GameState.opening_flags.bunker_gate_unlocked:
				AudioManager.play_world_effect("gate_iron")
				change_opening_room("ch2_bunker_descent", "from_gate")
			else:
				show_bunker_lock()
		"descent_return":
			change_opening_room("ch2_shelter", "from_descent")
		"descent_hall":
			change_opening_room("ch2_bunker_hall", "from_descent")
		"descent_pit":
			_inspect_pit()
		"review_tape":
			_show_tape_board()
		"bunker_bed":
			show_text("流浪汉旧地铺", "发霉的破床垫旁散着空易拉罐、碎玻璃和发黄水渍，角落掉着一只八十年代澳门「同善堂」旧铁盒。走路得小心别踢响罐子。")
		"bunker_machine":
			show_text("生锈的抽风机", "1931 年葡军防空洞遗留的旧抽风机，铜铭牌上刻着葡文造船厂字样，旁边就是深不见底的垂直通风无底洞。")
		"bunker_graffiti":
			GameState.take_demo_item("stair_rubbing")
			checkpoint()
			show_text("机房墙面拓记", "墙上白线画到 89，旁边画着缺角和一枚墙钉。下边的脚印朝来路，人的脸却朝向深处。\n\n「再见白记，照住前面，沿自己脚印倒返。」拓记已收进背包。", [], Callable(), "陈大文", DemoItems.texture("stair_rubbing"))
		"bunker_door":
			if not GameState.demo_pursuit.is_empty():
				hud.notify("脚步堵住了子弹房口。往小拱门撤。")
			elif not GameState.has_demo_item("stair_rubbing"):
				show_text("子弹房入口", "地籍索引显示这里是旧弹药库，嘉敏留下的粉笔箭头指向右边房里。进门前，先看看机房正前方涂鸦里和 89 级有关的白记。")
			else:
				change_opening_room("ch2_bunker_ammo", "from_hall")
		"ammo_exit":
			if GameState.demo_pursuit == "ammo":
				_pursuit_room_change("ch2_bunker_hall", "from_ammo", "hall")
			else:
				change_opening_room("ch2_bunker_hall", "from_ammo")
		"ammo_pits":
			if GameState.demo_pursuit.is_empty():
				show_text("子弹房", "坑与坑之间有横向石道。南边是来时的门，嘉敏的录音机应掉在右边靠墙的落脚处。")
		"ammo_restart":
			start_red_passage()
		"bunker_deep":
			if GameState.demo_pursuit == "hall":
				if GameState.opening_flags.hill_steps_completed:
					_pursuit_room_change("ch2_hill_steps", "from_hall", "steps")
				elif GameState.request_room_change("ch2_bunker_shaft", "from_hall"):
					GameState.demo_pursuit = ""
				else:
					hud.notify("竖井入口暂时无法打开，请稍后重试。")
			elif GameState.has_demo_item("bunker_recording") and not GameState.opening_flags.hill_steps_completed:
				change_opening_room("ch2_bunker_shaft", "from_hall")
			elif GameState.opening_flags.ammo_chase_cleared:
				hud.notify("该带录音出洞了。机房南侧能回到铁门。")
			else:
				show_text("内侧拱门", "下面就是地道深处的梯道。先从右侧子弹房捡起嘉敏留下的录音机。")
		"bunker_return":
			if GameState.demo_pursuit == "hall":
				hud.notify("来路响起三串脚步。往右侧小拱门去。")
			else:
				change_opening_room("ch2_bunker_descent", "from_hall")
		"shelter_back":
			change_opening_room("ch2_hill_base", "from_steps")
	update_objective()

func start_camera() -> void:
	if hud.panel_open or camera_active or work_in_progress:
		return
	camera_active = true
	player.clear_motion()
	player.controls_enabled = false
	player.sprite.hide()
	camera_pose.position = player.position
	camera_pose.z_index = int(player.position.y)
	camera_pose.show()
	camera_view.center = Vector2(300, 190)
	camera_view.show()
	camera_view.queue_redraw()
	hud.resources.hide()
	hud.title_mark.hide()
	hud.objective.text = "移动鼠标调整取景 · 左键拍照 · Esc 放下手机"

func stop_camera() -> void:
	camera_capture_generation += 1
	camera_active = false
	camera_view.shutter_busy = false
	hud.root.show()
	camera_view.hide()
	camera_pose.hide()
	player.sprite.show()
	player.controls_enabled = true
	player.clear_motion()
	hud.resources.show()
	hud.title_mark.show()
	update_objective()

func photo_is_valid() -> bool:
	var distance := player.position.distance_to(GIRL_FOOT)
	if distance < 100 or distance > 220 or player.position.x >= GIRL_FOOT.x - 50:
		return false
	var frame: Rect2 = camera_view.frame_rect()
	if not frame.has_point(GIRL_FOOT+Vector2(-8,0)) or not frame.has_point(GIRL_FOOT+Vector2(8,-49)) or not frame.has_point(Vector2(GIRL_FOOT.x,140)):
		return false
	var ray := PhysicsRayQueryParameters2D.create(player.position+Vector2(0,-32), GIRL_FOOT+Vector2(0,-28), 1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func take_photo() -> void:
	if not camera_active or camera_view.shutter_busy:
		return
	if not photo_is_valid():
		hud.notify("站到嘉敏左侧退后些，把她和身后的建筑一起拍进去。")
		return
	camera_view.shutter_busy = true
	var capture_generation := camera_capture_generation
	if DisplayServer.get_name() != "headless":
		hud.root.hide()
		await RenderingServer.frame_post_draw
		if not camera_active or capture_generation != camera_capture_generation:
			return
		var image := get_viewport().get_texture().get_image()
		var scale_factor := Vector2(image.get_size()) / Vector2(640,360)
		var rect: Rect2 = camera_view.frame_rect()
		var crop := Rect2i(Vector2i(rect.position*scale_factor), Vector2i(rect.size*scale_factor))
		GameState.opening_photo = ImageTexture.create_from_image(image.get_region(crop))
		GameState.opening_photo_file=""
		hud.root.show()
	else:
		var fixture := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		fixture.fill(Color("714f38"))
		GameState.opening_photo = ImageTexture.create_from_image(fixture)
		GameState.opening_photo_file=""
	GameState.opening_flags.photo_taken = true
	if is_instance_valid(photo_marker):
		photo_marker.queue_free()
		photo_marker = null
	checkpoint()
	AudioManager.play_world_effect("camera_shutter")
	stop_camera()
	show_line("photo_done", [], Callable(), GameState.opening_photo)
	update_objective()

func accept_pastry() -> void:
	GameState.opening_flags.pastry_shared = true
	checkpoint()
	set_girl_pose(0)
	pastry_pose.position = player.position
	pastry_pose.z_index = int(player.position.y)
	pastry_pose.show()
	player.sprite.hide()
	show_line("pastry_reply", [], finish_pastry)
	update_objective()

func finish_pastry() -> void:
	pastry_pose.hide()
	player.sprite.show()
	set_girl_pose(0)

func agree_knock() -> void:
	GameState.opening_flags.knock_agreed = true
	checkpoint()
	update_objective()

func enter_foyer() -> void:
	if GameState.request_room_change("ch0_foyer", "from_street"):
		GameState.opening_flags.entered_foyer = true
		checkpoint()
		AudioManager.play_world_effect("entrance_door")
	else:
		hud.notify("门暂时无法打开，请重试。")

func return_street() -> void:
	close_dialog(false)
	if GameState.request_room_change("ch0_street", "from_foyer"):
		checkpoint()
	else:
		hud.notify("街道暂时无法载入，请稍后重试。")

func change_opening_room(room_id: String, entry_id: String) -> void:
	if GameState.request_room_change(room_id, entry_id):
		checkpoint()
		if room_id == "ch0_room304":
			AudioManager.play_world_effect("entrance_door")
	else:
		hud.notify("暂时无法进入，请重试。")

func go_to_crypt() -> void:
	close_dialog(false)
	change_opening_room("ch1_crypt_entry", "from_lane")

func show_old_photo() -> void:
	var first_look: bool = not GameState.opening_flags.old_photo_seen
	GameState.opening_flags.old_photo_seen = true
	GameState.take_demo_item("old_304_photo")
	checkpoint()
	var board := Control.new()
	open_demo_widget(board)
	hud.label("福荣里三楼旧合照 · 嘉敏出发前带来的那张", Vector2(18, 7), Vector2(480, 24), 15, Color("e1d684"), board)
	hud.label("Esc 返回", Vector2(530, 8), Vector2(72, 22), 12, Color("d1c5a8"), board)

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

	var photo := TextureRect.new()
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.texture = DemoItems.texture("old_304_photo")
	photo.position = Vector2(13, 11)
	photo.size = Vector2(276, 184)
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo_box.add_child(photo)

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
	note_title.text = "【 现场线索 】"
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
	note.text = "床脚旁的四瓣花砖与 304 一样。照片里铁床后有半开的木门，门下有百叶。新版图纸上那里是一整面墙。\n\n嘉敏手机里的草稿，说的就是这扇门。"
	note_vbox.add_child(note)

	if first_look:
		get_tree().create_timer(1.0, true).timeout.connect(func():
			if is_instance_valid(board) and stage_kind == "room304":
				AudioManager.play_world_effect("photo_knock")
		)

func show_phone_notes() -> void:
	if not GameState.opening_flags.phone_taught:
		GameState.opening_flags.phone_taught = true
		hud.set_phone_keytip(false)
		checkpoint()
	after_dialog = Callable()
	player.controls_enabled = false
	player.clear_motion()
	hud.open_archive_page("phone")
	get_tree().paused = true

func show_bag() -> void:
	open_demo_widget(preload("res://ui/demo_bag.gd").new())

func show_travel_map() -> void:
	var map := preload("res://ui/demo_travel_map.gd").new()
	map.current_objective = hud.objective.text
	open_demo_widget(map)

func open_demo_widget(widget: Control) -> void:
	after_dialog = Callable()
	player.controls_enabled = false
	player.clear_motion()
	hud.open_widget(widget)
	get_tree().paused = true

func show_crypt_desk() -> void:
	if GameState.opening_flags.crypt_photo_seen and GameState.opening_flags.crypt_plan_seen and GameState.opening_flags.crypt_doodle_seen:
		show_text("资料桌", "图纸显示这里保存的测绘图比现场早。对照墙上的标记，找出改建动过哪里。", [{"text":"摆开三份证据", "callback":show_crypt_comparison}, {"text":"访客素描", "callback":show_crypt_witness},{"text":"返回", "callback":close_dialog}])
	else:
		show_crypt_evidence_menu()

func show_crypt_evidence_menu() -> void:
	show_text("资料桌", "测绘描图留在这里。巡查照片搁在右壁龛旁的石台上，左壁龛脚边还压着一张孩子的画。", [{"text":"查看测绘描图", "callback":show_crypt_evidence.bind("plan")},{"text":"查看访客素描", "callback":show_crypt_witness},{"text":"返回现场", "callback":close_dialog}])

func show_crypt_witness() -> void:
	show_text("访客素描", "")
	hud.modal.size = Vector2(630, 350)
	hud.panel_content.custom_minimum_size = Vector2(618, 338)
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.texture = load("res://assets/props/crypt_witness_sketch_025.png")
	image.size = Vector2(618, 338)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.panel_content.add_child(image)
	hud.label("大三巴秘道 · 白骨传闻", Vector2(335, 72), Vector2(240, 24), 16, Color("3b2a1b"), hud.panel_content)
	hud.label("旧街坊口述：唐楼小孩常说\n床底秘道有位黑袍老伯陪他\n说话；父亲举灯下去，看到的\n却是一具披着黑袍的白骨！\n\n1961年牌坊后确曾挖出遗骨。", Vector2(335, 108), Vector2(245, 155), 13, Color("3b2a1b"), hud.panel_content)
	hud.label("Esc 返回", Vector2(505, 306), Vector2(100, 18), 12, Color("3b2a1b"), hud.panel_content)

func show_crypt_evidence(kind: String) -> void:
	var flags := {"photo":"crypt_photo_seen", "plan":"crypt_plan_seen", "doodle":"crypt_doodle_seen"}
	if not flags.has(kind):
		return
	GameState.opening_flags[flags[kind]] = true
	GameState.take_demo_item({"photo":"crypt_old_photo", "plan":"crypt_survey", "doodle":"crypt_doodle"}[kind])
	checkpoint()
	show_text("现场资料", "")
	hud.modal.size = Vector2(630,350)
	hud.panel_content.custom_minimum_size = Vector2(618,338)
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.texture = load("res://assets/props/crypt_%s_013.png" % kind)
	image.position = Vector2(48,8)
	image.size = Vector2(520,300)
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.panel_content.add_child(image)
	hud.label("已收进背包。回到资料桌对照三份证据。   Esc 返回", Vector2(100,311), Vector2(440,20), 13, Color("e1d684"), hud.panel_content)

func show_crypt_comparison() -> void:
	if not (GameState.opening_flags.crypt_photo_seen and GameState.opening_flags.crypt_plan_seen and GameState.opening_flags.crypt_doodle_seen):
		return
	var board = preload("res://ui/crypt_survey_board.gd").new()
	board.name = "CryptComparison"
	board.aligned.connect(func():
		GameState.opening_flags.crypt_aligned = true
		checkpoint()
		show_text("墙面改建记录", "石像封住了中间壁龛。粉笔箭头转向右侧维护门，鞋印也往那里走。")
	)
	open_demo_widget(board)

func remove_crypt_clip() -> void:
	show_text("拆除卡扣", "")
	hud.modal.size = Vector2(630,350)
	hud.panel_content.custom_minimum_size = Vector2(618,338)
	var clip = preload("res://ui/crypt_clip.gd").new()
	clip.name = "CryptClip"
	clip.size = Vector2(618,338)
	clip.removed.connect(execute_crypt_clip)
	hud.panel_content.add_child(clip)

func execute_crypt_clip() -> void:
	close_dialog(false)
	work_in_progress = true
	player.controls_enabled = false
	player.clear_motion()
	player.sprite.hide()
	work_pose.position = player.position
	work_pose.z_index = int(player.position.y)
	work_pose.show()
	AudioManager.play_world_effect("metal_cover")
	var timer := Timer.new()
	timer.wait_time = 0.7
	timer.one_shot = true
	add_child(timer)
	timer.start()
	await timer.timeout
	if not is_inside_tree():
		if is_instance_valid(timer):
			timer.queue_free()
		return
	timer.queue_free()
	work_pose.hide()
	player.sprite.show()
	GameState.opening_flags.crypt_clip_removed = true
	checkpoint()
	work_in_progress = false
	player.controls_enabled = true
	open_crypt_door()

func open_crypt_door() -> void:
	if GameState.opening_flags.crypt_door_open or work_in_progress:
		return
	close_dialog(false)
	work_in_progress = true
	player.controls_enabled = false
	player.clear_motion()
	var leaf := Sprite2D.new()
	var source := AtlasTexture.new()
	source.atlas = load("res://assets/tilesets/crypt_marked_013.png")
	source.region = Rect2(1341, 83, 170, 282)
	leaf.texture = source
	leaf.centered = false
	leaf.offset.x = -170
	leaf.position = Vector2(577, 31)
	leaf.scale = Vector2(65, 109) / source.get_size()
	add_child(leaf)
	room_lit_layer.hide()
	room_dark_layer.show()
	AudioManager.play_world_effect("entrance_door")
	var swing := create_tween()
	swing.tween_property(leaf, "scale:x", 0.04, 0.45).set_trans(Tween.TRANS_SINE)
	await swing.finished
	leaf.queue_free()
	if is_instance_valid(crypt_aperture):
		crypt_aperture.queue_free()
	if is_instance_valid(crypt_aperture_shadow):
		crypt_aperture_shadow.queue_free()
	GameState.opening_flags.crypt_door_open = true
	checkpoint()
	work_in_progress = false
	player.controls_enabled = true
	hud.notify("右侧维护门打开了。靠近门口按 E 进入。")

func start_priest_encounter() -> void:
	if priest_encounter_active or GameState.opening_flags.priest_escaped:
		return
	AudioManager.start_chase_music()
	priest_encounter_active = true
	priest = preload("res://entities/priest_013.gd").new()
	priest.position = Vector2(500, 220)
	priest.target = player
	priest.active = false
	priest.caught.connect(priest_caught)
	priest.freeze_changed.connect(func(is_frozen: bool):
		hud.notify("黑衣人被光照住，停下了。" if is_frozen else "光线移开，黑衣人再次靠近。")
	)
	add_child(priest)
	var timer := Timer.new()
	timer.wait_time = 1.5
	timer.one_shot = true
	add_child(timer)
	timer.start()
	await timer.timeout
	if not is_inside_tree():
		if is_instance_valid(timer):
			timer.queue_free()
		return
	timer.queue_free()
	if is_instance_valid(priest) and priest_encounter_active:
		priest.active = true
		hud.notify("黑衣人开始靠近。")

func priest_caught() -> void:
	AudioManager.stop_chase_music()
	priest_encounter_active = false
	_capture_cut("res://assets/characters/priest_lunge_026.png", "被黑衣人追上", "回到石廊入口。把光照在他身上可以止住脚步，再从一侧绕开。", retry_priest)

func _capture_cut(art_path: String, title: String, note: String, retry: Callable) -> void:
	capture_locked = true
	player.controls_enabled = false
	player.clear_motion()
	get_tree().paused = true
	await CAPTURE.play_on(self, art_path)
	show_text(title, note, [{"text":"重新尝试", "callback":retry}])

func retry_priest() -> void:
	AudioManager.stop_chase_music()
	capture_locked = false
	close_dialog(false)
	get_tree().call_deferred("reload_current_scene")

func escape_priest() -> void:
	AudioManager.stop_chase_music()
	if GameState.opening_flags.priest_escaped:
		change_opening_room("ch1_archive", "from_hall")
		return
	priest_encounter_active = false
	if is_instance_valid(priest):
		priest.queue_free()
	GameState.opening_flags.priest_escaped = true
	checkpoint()
	room_lit_layer.hide()
	room_dark_layer.show()
	AudioManager.play_world_effect("entrance_door")
	player.controls_enabled = false
	player.clear_motion()
	var timer := Timer.new()
	timer.wait_time = 0.7
	timer.one_shot = true
	add_child(timer)
	timer.start()
	await timer.timeout
	if not is_inside_tree():
		if is_instance_valid(timer):
			timer.queue_free()
		return
	timer.queue_free()
	change_opening_room("ch1_archive", "from_hall")

func copy_interview_index() -> void:
	if work_in_progress:
		return
	if not GameState.opening_flags.interview_index_copied:
		work_in_progress = true
		player.controls_enabled = false
		player.clear_motion()
		player.sprite.hide()
		player.lamp.enabled = false
		camera_pose.position = player.position
		camera_pose.z_index = int(player.position.y)
		camera_pose.show()
		AudioManager.play_world_effect("camera_shutter")
		var timer := Timer.new()
		timer.wait_time = 0.7
		timer.one_shot = true
		add_child(timer)
		timer.start()
		await timer.timeout
		timer.queue_free()
		camera_pose.hide()
		player.sprite.show()
		work_in_progress = false
		player.controls_enabled = true
		GameState.opening_flags.interview_index_copied = true
		GameState.take_demo_item("interview_index")
		checkpoint()
	show_text("采访索引", "")
	hud.modal.size = Vector2(630,350)
	hud.panel_content.custom_minimum_size = Vector2(618,338)
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.texture = load("res://assets/props/interview_index_macau_025.png")
	image.position = Vector2.ZERO
	image.size = Vector2(618,338)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.panel_content.add_child(image)
	hud.label("采访索引 · 松山", Vector2(220,115), Vector2(220,24), 17, Color("3b2a1b"), hud.panel_content)
	hud.label("松山地籍旧口述（传闻）\n一家三口从没上锁的门进入后失踪；\n后来有人在子弹房见三道红影经过门口。\n夜里数楼梯，八十多级会变成九十九级。\n入口下方右侧有一处深坑。", Vector2(160,145), Vector2(320,135), 12, Color("3b2a1b"), hud.panel_content)
	hud.label("已拍照留存 · Esc 返回", Vector2(210,308), Vector2(250,18), 12, Color("3b2a1b"), hud.panel_content)
	update_objective()

func open_archive_exit() -> void:
	room_lit_layer.hide()
	room_dark_layer.show()
	player.controls_enabled = false
	player.clear_motion()
	AudioManager.play_world_effect("entrance_door")
	var timer := Timer.new()
	timer.wait_time = 0.7
	timer.one_shot = true
	add_child(timer)
	timer.start()
	await timer.timeout
	if not is_inside_tree():
		if is_instance_valid(timer):
			timer.queue_free()
		return
	timer.queue_free()
	change_opening_room("ch2_hill_base", "from_archive")

func leave_archive_for_hill() -> void:
	close_dialog(false)
	open_archive_exit()

func show_hill_stele() -> void:
	GameState.opening_flags.hill_stele_seen = true
	checkpoint()
	show_text("山道石碑", "", [], begin_hill_demo)
	hud.modal.size = Vector2(630,350)
	hud.panel_content.custom_minimum_size = Vector2(618,338)
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.texture = load("res://assets/props/hill_stele_014.png")
	image.size = Vector2(618,338)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.panel_content.add_child(image)
	hud.label("数至九十九，莫踏百级门；\n\n灯照前方路，退步不回身。", Vector2(205,125), Vector2(300,100), 16, Color("d5c9a8"), hud.panel_content)
	hud.label("Esc 返回", Vector2(280,313), Vector2(100,18), 12, Color("d5c9a8"), hud.panel_content)
	update_objective()

func begin_hill_demo() -> void:
	if not GameState.opening_flags.hill_warning_seen:
		hill_demo_active = true
		hill_reverse_time = 0.0
		hud.notify("安全区练习：把鼠标朝身后转动，观察香烟警告。")

func show_bunker_lock() -> void:
	GameState.opening_flags.bunker_gate_examined = true
	checkpoint()
	var puzzle = preload("res://ui/bunker_lock_puzzle.gd").new()
	puzzle.state_changed.connect(checkpoint)
	puzzle.unlocked.connect(_swing_bunker_gate)
	open_demo_widget(puzzle)

func _swing_bunker_gate() -> void:
	close_dialog(false)
	work_in_progress = true
	player.controls_enabled = false
	player.clear_motion()
	var moving := Sprite2D.new()
	var crop := AtlasTexture.new()
	crop.atlas = load("res://assets/tilesets/bunker_entrance_2d_019.png")
	crop.region = Rect2(926, 236, 146, 282)
	moving.texture = crop
	moving.centered = false
	moving.offset.x = -146
	moving.position = Vector2(410, 91)
	moving.scale = Vector2(55, 107) / crop.get_size()
	add_child(moving)
	room_lit_layer.hide()
	room_dark_layer.show()
	AudioManager.play_world_effect("gate_iron")
	var motion := create_tween()
	motion.tween_property(moving, "scale:x", 0.06, 0.54).set_trans(Tween.TRANS_SINE)
	await motion.finished
	moving.queue_free()
	if is_instance_valid(gate_aperture):
		gate_aperture.queue_free()
	if is_instance_valid(gate_aperture_shadow):
		gate_aperture_shadow.queue_free()
	GameState.opening_flags.bunker_gate_unlocked = true
	checkpoint()
	work_in_progress = false
	player.controls_enabled = true
	hud.notify("铁链落地，铁门推开。冷气从下面涌上来。")

func _pursuit_room_change(room_id: String, entry_id: String, next_phase: String) -> void:
	if GameState.request_room_change(room_id, entry_id):
		GameState.demo_pursuit = next_phase

func _show_tape_board() -> void:
	if GameState.opening_flags.demo_case_closed:
		_show_demo_conclusion()
		return
	if not GameState.opening_flags.ammo_chase_cleared or not GameState.has_demo_item("bunker_recording"):
		return
	var board = preload("res://ui/bunker_tape_board.gd").new()
	board.verified.connect(func():
		GameState.opening_flags.demo_case_closed = true
		checkpoint()
		_show_demo_conclusion()
	)
	open_demo_widget(board)

func _show_demo_conclusion() -> void:
	show_text("松山 · 洞外", "录音停了，她最后还在喊阿豪……\n竖井便签指向大关斜巷——就是手札里写过二战饥荒肉铺与长楼猪仔馆的那条老巷，我得马上赶过去！", [
		{"text":"查看更新的攻略", "callback":show_travel_map},
		{"text":"前往大关斜巷", "callback":begin_ch3_archive},
		{"text":"回到标题", "callback":_return_to_title}
	])

func begin_ch3_archive() -> void:
	close_dialog(false)
	if GameState.opening_flags.demo_case_closed and GameState.request_room_change("ch3_amparo_archive", "from_bunker"):
		GameState.save_transition_checkpoint()
	else:
		show_text("大关斜巷", "还没有核对嘉敏录音里提到的避险路线。先读清留言，再往大关斜巷。")

func _return_to_title() -> void:
	close_dialog(false)
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")

func show_maintenance_lock() -> void:
	var lock = preload("res://ui/service_latch.gd").new()
	lock.name = "MaintenanceLock"
	lock.unlocked.connect(_open_service_exit)
	open_demo_widget(lock)

func _open_service_exit() -> void:
	close_dialog(false)
	work_in_progress = true
	player.controls_enabled = false
	player.clear_motion()
	var crop := AtlasTexture.new()
	crop.atlas = load("res://assets/tilesets/maintenance_012.png")
	crop.region = Rect2(1344, 157, 193, 344)
	var leaf := Sprite2D.new()
	leaf.texture = crop
	leaf.centered = false
	leaf.offset.x = -193
	leaf.position = Vector2(591, 60)
	leaf.scale = Vector2(73, 132) / crop.get_size()
	add_child(leaf)
	room_lit_layer.hide()
	room_dark_layer.show()
	AudioManager.play_world_effect("gate_iron")
	var motion := create_tween()
	motion.tween_property(leaf, "scale:x", 0.04, 0.39).set_trans(Tween.TRANS_SINE)
	await motion.finished
	leaf.queue_free()
	if is_instance_valid(service_aperture):
		service_aperture.queue_free()
	if is_instance_valid(service_aperture_shadow):
		service_aperture_shadow.queue_free()
	GameState.opening_flags.maintenance_unlocked = true
	checkpoint()
	work_in_progress = false
	player.controls_enabled = true
	hud.notify("铁门敞开了。右侧是唐楼后院。")

func wrong_bed_choice() -> void:
	show_text("再看一看", "褪色不会改变床脚的位置。结合拖痕和旧照片，再检查一次。")

func answer_room_phone() -> void:
	if GameState.opening_flags.room_phone_answered or work_in_progress:
		return
	close_dialog(false)
	work_in_progress = true
	player.controls_enabled = false
	player.clear_motion()
	AudioManager.stop_all()
	GameState.opening_flags.room_phone_answered = true
	checkpoint()
	AudioManager.play_world_effect("hall_wail")
	hud.notify("听筒里：两下，一下……压低的哭喊，没有回答。")
	await get_tree().create_timer(0.82, false).timeout
	if not is_inside_tree():
		return
	room_lit_layer.hide()
	room_dark_layer.show()
	player.set_appearance("flashlight")
	hud.resources.show_flashlight = true
	room_ambient.color = Color("4f5c59")
	AudioManager.play_at(self, "power_failure", Vector2(258, 132))
	await get_tree().create_timer(0.36, false).timeout
	if not is_inside_tree():
		return
	AudioManager.play_at(self, "door_approach", Vector2(320, 304))
	await get_tree().create_timer(0.72, false).timeout
	if not is_inside_tree():
		return
	AudioManager.play_at(self, "hall_wail", Vector2(341, 304))
	work_in_progress = false
	player.controls_enabled = true
	hud.notify("门外的脚步停了。左边有一只衣柜。")
	update_objective()

func enter_room_wardrobe() -> void:
	if hiding:
		return
	hiding = true
	hiding_return = player.position
	player.hidden_in_wardrobe = true
	player.clear_motion()
	player.sprite.hide()
	wardrobe_view = CanvasLayer.new()
	wardrobe_view.layer = 1
	hud.layer = 2
	add_child(wardrobe_view)
	for bounds: Rect2 in [Rect2(0, 0, 640, 139), Rect2(0, 285, 640, 75)]:
		var occlusion := ColorRect.new()
		occlusion.position = bounds.position
		occlusion.size = bounds.size
		occlusion.color = Color(0.021, 0.017, 0.013, 0.97)
		occlusion.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wardrobe_view.add_child(occlusion)
	AudioManager.play_world_effect("wardrobe_close")
	GameState.opening_flags.wardrobe_tutorial_done = true
	checkpoint()
	hud.notify("衣柜已关上。按 E 离开；现在先熟悉藏身处。")
	if not GameState.opening_flags.shadow_passed and not shadow_event_running:
		begin_shadow_passage()

func exit_room_wardrobe() -> void:
	if shadow_event_running:
		hud.notify("先别开门，脚步还在屋里。")
		return
	hiding = false
	player.hidden_in_wardrobe = false
	if is_instance_valid(wardrobe_view):
		wardrobe_view.queue_free()
	player.position = hiding_return
	player.reset_physics_interpolation()
	player.sprite.show()
	AudioManager.play_world_effect("wardrobe_open")
	if not GameState.opening_flags.wet_tag_left:
		GameState.opening_flags.wet_tag_left = true
		checkpoint()
		await get_tree().create_timer(0.35, false).timeout
		if not is_inside_tree():
			return
		AudioManager.play_at(self, "photo_knock", Vector2(320, 305))
		hud.notify("门外又敲了一次，随后没了声音。去走廊看看。")
	else:
		hud.notify("离开衣柜。")

func begin_shadow_passage() -> void:
	shadow_event_running = true
	var delay := Timer.new()
	delay.wait_time = 0.6
	delay.one_shot = true
	add_child(delay)
	delay.start()
	await delay.timeout
	if not is_inside_tree():
		if is_instance_valid(delay):
			delay.queue_free()
		return
	delay.queue_free()
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	body.position = Vector2(480, 285)
	body.z_index = 285
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 7
	collision.shape = shape
	body.add_child(collision)
	var figure := AnimatedSprite2D.new()
	var sprite_frames := SpriteFrames.new()
	sprite_frames.add_animation("walk")
	sprite_frames.set_animation_speed("walk", 7.0)
	var sheet: Texture2D = load("res://assets/characters/tanglau_stalker_026.png")
	for i in range(6):
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(i * 362, 0, 362, 724)
		sprite_frames.add_frame("walk", frame)
	figure.sprite_frames = sprite_frames
	figure.position = Vector2(0, -47)
	figure.scale = Vector2.ONE * (94.0 / 724.0)
	figure.modulate = Color(0.86, 0.90, 0.89, 0.98)
	var matte := Shader.new()
	matte.code = "shader_type canvas_item; varying vec4 tint; void vertex(){tint=COLOR;} void fragment(){vec4 c=texture(TEXTURE,UV);float white=max(max(c.r,c.g),c.b);c.a *= 1.0-smoothstep(0.49,0.68,white);COLOR=c*tint;}"
	var matte_material := ShaderMaterial.new()
	matte_material.shader = matte
	figure.material = matte_material
	body.add_child(figure)
	add_child(body)
	figure.play("walk")
	var steps := AudioStreamPlayer2D.new()
	steps.bus = "SFX"
	steps.max_distance = 480
	steps.volume_db = -4
	steps.stream = load("res://assets/audio/recorded/shadow_step.ogg")
	body.add_child(steps)
	var step_timer := Timer.new()
	step_timer.wait_time = 0.62
	body.add_child(step_timer)
	step_timer.timeout.connect(func():
		if DisplayServer.get_name() != "headless" and "Dummy" not in OS.get_cmdline_args():
			steps.play()
	)
	step_timer.start()
	hud.notify("外面的脚步近了……")
	var tween := create_tween()
	tween.tween_property(body, "position", Vector2(220, 285), 4.0)
	await tween.finished
	if not is_inside_tree():
		if is_instance_valid(body):
			body.queue_free()
		return
	body.queue_free()
	shadow_event_running = false
	GameState.opening_flags.shadow_passed = true
	checkpoint()
	hud.notify("脚步声远去了。")

func start_yard_chase() -> void:
	if GameState.opening_flags.yard_escaped or yard_chase_active:
		return
	yard_chase_active = true
	var delay := Timer.new()
	delay.wait_time = 2.0
	delay.one_shot = true
	add_child(delay)
	delay.start()
	await delay.timeout
	if not is_inside_tree():
		if is_instance_valid(delay):
			delay.queue_free()
		return
	delay.queue_free()
	if not yard_chase_active:
		return
	AudioManager.start_chase_music()
	yard_shadow = preload("res://entities/shadow_chaser.gd").new()
	yard_shadow.target = player
	yard_shadow.position = Vector2(72, 295)
	yard_shadow.caught.connect(yard_caught)
	add_child(yard_shadow)
	hud.notify("黑影追来了！按住 Shift 狂奔往右侧拱门跑！")

func yard_caught() -> void:
	yard_chase_active = false
	AudioManager.stop_chase_music()
	_capture_cut("res://assets/characters/priest_lunge_026.png", "被黑影扑倒", "退回后院入口，再试一次。按住 Shift 奔跑朝右侧拱门跑，靠近后按 E。", retry_yard)

func retry_yard() -> void:
	AudioManager.stop_chase_music()
	capture_locked = false
	close_dialog(false)
	get_tree().call_deferred("reload_current_scene")

func escape_yard() -> void:
	AudioManager.stop_chase_music()
	if GameState.opening_flags.yard_escaped:
		change_opening_room("ch0_exit_lane", "from_yard")
		return
	yard_chase_active = false
	if is_instance_valid(yard_shadow):
		yard_shadow.queue_free()
	GameState.opening_flags.yard_escaped = true
	checkpoint()
	room_lit_layer.hide()
	room_dark_layer.show()
	AudioManager.play_world_effect("lock_mechanism")
	player.controls_enabled = false
	player.clear_motion()
	var timer := Timer.new()
	timer.wait_time = 0.7
	timer.one_shot = true
	add_child(timer)
	timer.start()
	await timer.timeout
	if not is_inside_tree():
		if is_instance_valid(timer):
			timer.queue_free()
		return
	timer.queue_free()
	change_opening_room("ch0_exit_lane", "from_yard")

func call_public_phone() -> void:
	if work_in_progress:
		return
	work_in_progress = true
	player.controls_enabled = false
	player.clear_motion()
	player.sprite.hide()
	room_lit_layer.hide()
	room_dark_layer.show()
	var pose := Sprite2D.new()
	pose.texture = load("res://assets/characters/dawen_payphone_012.png")
	pose.scale = Vector2(70, 92) / pose.texture.get_size()
	pose.position = player.position + Vector2(0, -45)
	pose.z_index = int(player.position.y)
	add_child(pose)
	AudioManager.play_world_effect("phone_busy")
	var timer := Timer.new()
	timer.wait_time = 1.8
	timer.one_shot = true
	add_child(timer)
	timer.start()
	await timer.timeout
	if not is_inside_tree():
		if is_instance_valid(timer):
			timer.queue_free()
		return
	timer.queue_free()
	AudioManager.stop_all()
	pose.queue_free()
	room_dark_layer.hide()
	room_lit_layer.show()
	GameState.opening_flags.help_attempted = true
	checkpoint()
	work_in_progress = false
	player.sprite.show()
	player.controls_enabled = true
	show_text("公用电话", "投了两枚澳门币硬币进电话亭，听筒里只有刺耳的忙音。石阶栏杆上勾着嘉敏衣角的碎布，她往大三巴牌坊地宫方向去了。")
	update_objective()

func move_room_bed() -> void:
	if player.position.x < 490 or player.position.y < 245:
		show_text("移动铁床", "先走到床尾右侧，从安全的位置向左推。")
		return
	close_dialog(false)
	work_in_progress = true
	player.controls_enabled = false
	player.clear_motion()
	player.sprite.hide()
	var pose := Sprite2D.new()
	pose.texture = load("res://assets/characters/dawen_push_011.png")
	pose.flip_h = true
	pose.scale = Vector2(86,86) / pose.texture.get_size()
	pose.position = player.position + Vector2(0,-40)
	pose.z_index = int(player.position.y)
	add_child(pose)
	AudioManager.play_world_effect("bed_scrape")
	var tween := create_tween()
	tween.tween_property(room_bed, "position", Vector2(-145,10), 1.1)
	tween.parallel().tween_property(room_bed_shadow, "position", Vector2(-145,10), 1.1)
	await tween.finished
	if not is_inside_tree():
		if is_instance_valid(pose):
			pose.queue_free()
		return
	pose.queue_free()
	GameState.opening_flags.room_bed_moved = true
	room_vent.show()
	checkpoint()
	work_in_progress = false
	player.sprite.show()
	player.controls_enabled = true
	show_text("床后的墙", "铁床移开了。照片中的木门已被封住，门下那块旧百叶还在。百叶边有一道新鲜的布料擦痕。")

func remove_room_cover() -> void:
	if work_in_progress or GameState.opening_flags.room_cover_open:
		return
	close_dialog(false)
	work_in_progress = true
	player.controls_enabled = false
	player.clear_motion()
	var approach_distance := 0.0
	# Walk to a reachable work position using the body collision, not a visual
	# teleport. The interaction can start from either side of the hatch.
	while player.position.distance_to(VENT_WORK_POSITION) > 1.5:
		await get_tree().physics_frame
		if not is_inside_tree():
			return
		if get_tree().paused:
			continue
		var step := player.position.direction_to(VENT_WORK_POSITION) * minf(2.0, player.position.distance_to(VENT_WORK_POSITION))
		if player.move_and_collide(step) != null:
			work_in_progress = false
			player.controls_enabled = true
			hud.notify("先绕到检修盖左前方，再用工具钳拆盖。")
			return
		approach_distance += step.length()
		player.look_dir = step.normalized()
		player.facing = posmod(roundi(player.look_dir.angle() / (PI / 4.0)), 8)
		player.pivot.rotation = player.look_dir.angle()
		player.sprite.animation = str(player.facing)
		player.sprite.frame = posmod(floori(approach_distance / GameState.RULES.walk_stride * 3.0), 6)
		player._sync_pose_landmarks()
	player.sprite.hide()
	player.lamp.enabled = false
	vent_work_pose = Sprite2D.new()
	vent_work_pose.centered = false
	vent_work_pose.scale = Vector2.ONE * VENT_WORK_SCALE
	vent_work_pose.z_index = int(player.position.y)
	add_child(vent_work_pose)
	_set_vent_work_frame(0.0)
	AudioManager.play_world_effect("metal_cover")
	var action := create_tween()
	action.tween_method(_set_vent_work_frame, 0.0, 5.99, 1.05)
	action.parallel().tween_property(room_vent, "position", room_vent.position + Vector2(14, 9), 0.32).set_delay(0.70)
	action.parallel().tween_property(room_vent, "rotation", 0.27, 0.32).set_delay(0.70)
	await action.finished
	if not is_inside_tree():
		if is_instance_valid(vent_work_pose):
			vent_work_pose.queue_free()
		return
	vent_work_pose.queue_free()
	player.sprite.show()
	player.lamp.enabled = player.flashlight_on and player.allow_flashlight and GameState.flashlight_battery > 0
	show_room_vent_open()
	GameState.opening_flags.room_cover_open = true
	checkpoint()
	work_in_progress = false
	player.controls_enabled = true
	show_text("检修口", "盖板后有一段狭窄的维护通道。新划痕的内侧挂着一小缕红线，和嘉敏拍照时的相机绳一样。\n\n她确实找到了旧照里的门。大文要沿着这段通道去看门后通往哪里。", [], Callable(), "陈大文", _vent_thread_detail())

func _vent_thread_detail() -> Texture2D:
	# Reuse the actual hatch art: a closer look at the right-hand rim and thread.
	var detail := AtlasTexture.new()
	detail.atlas = load("res://assets/props/room304_hatch_open_100.png")
	detail.region = Rect2(1115, 180, 350, 240)
	return detail

func _set_vent_work_frame(value: float) -> void:
	var index := clampi(int(value), 0, 5)
	var frame := AtlasTexture.new()
	frame.atlas = VENT_WORK_SHEET
	frame.region = Rect2((index % 3) * 512, floori(index / 3.0) * 512, 512, 512)
	vent_work_pose.texture = frame
	vent_work_pose.position = player.position - VENT_WORK_FEET[index] * VENT_WORK_SCALE

func show_room_vent_open() -> void:
	room_hatch.show()
	room_vent.hide()
	if is_instance_valid(room_aperture):
		room_aperture.queue_free()
	if is_instance_valid(room_aperture_shadow):
		room_aperture_shadow.queue_free()

func crawl_into_maintenance() -> void:
	close_dialog(false)
	work_in_progress = true
	player.controls_enabled = false
	player.clear_motion()
	player.sprite.hide()
	player.lamp.enabled = false
	var pose := Sprite2D.new()
	pose.texture = load("res://assets/characters/dawen_crawl_012.png")
	pose.scale = Vector2(94, 64) / pose.texture.get_size()
	pose.position = player.position + Vector2(0, -24)
	pose.z_index = int(player.position.y)
	add_child(pose)
	var timer := Timer.new()
	timer.wait_time = 0.8
	timer.one_shot = true
	add_child(timer)
	timer.start()
	await timer.timeout
	if not is_inside_tree():
		if is_instance_valid(timer):
			timer.queue_free()
		if is_instance_valid(pose):
			pose.queue_free()
		return
	timer.queue_free()
	pose.queue_free()
	work_in_progress = false
	change_opening_room("ch0_maintenance", "from_room304")

func pickup_phone() -> void:
	if work_in_progress or GameState.opening_flags.jiamin_phone_found:
		return
	work_in_progress = true
	player.controls_enabled = false
	player.clear_motion()
	player.sprite.hide()
	var pose := Sprite2D.new()
	pose.texture = load("res://assets/characters/dawen_pickup_011.png")
	pose.scale = Vector2(81, 81) / pose.texture.get_size()
	pose.position = player.position + Vector2(0, -35)
	pose.z_index = int(player.position.y)
	add_child(pose)
	var timer := Timer.new()
	timer.wait_time = 0.7
	timer.one_shot = true
	add_child(timer)
	timer.start()
	await timer.timeout
	if not is_inside_tree():
		if is_instance_valid(timer):
			timer.queue_free()
		if is_instance_valid(pose):
			pose.queue_free()
		return
	timer.queue_free()
	pose.queue_free()
	if is_instance_valid(phone_body):
		phone_body.queue_free()
	if is_instance_valid(phone_occluder):
		phone_occluder.queue_free()
	if is_instance_valid(phone_sprite):
		phone_sprite.queue_free()
	GameState.opening_flags.jiamin_phone_found = true
	GameState.take_demo_item("jiamin_phone")
	player.phone_defense.prepare_chapter()
	if not GameState.has_demo_item("old_304_photo"):
		GameState.take_demo_item("old_304_photo")
	hud.set_phone_keytip(true)
	checkpoint()
	work_in_progress = false
	player.sprite.show()
	player.controls_enabled = true
	show_text("嘉敏的手机", "嘉敏的手机落在 304 门边地面。屏幕亮着，停留在一封未发出的备忘草稿：\n\n「照片里铁床后那扇门刚刚开了。有人敲两下，再一下。我进去看一眼。」", [{"text":"打开手机资料 [ Q / Tab ]", "callback":show_phone_notes},{"text":"先查看房间", "callback":close_dialog}])
	update_objective()

func show_line(id: String, choices: Array = [], after: Callable = Callable(), photo: Texture2D = null) -> void:
	var line: Dictionary = dialogues[id]
	show_text("福荣旧影", line.subtitle, choices, after, line.speaker, photo)

func show_text(title: String, body: String, choices: Array = [], after: Callable = Callable(), speaker: String = "陈大文", photo: Texture2D = null) -> void:
	after_dialog = after
	player.controls_enabled = false
	player.clear_motion()
	hud.open_panel(title, body, choices, photo != null, speaker, girl_portrait if speaker == "黄嘉敏" else null, photo)
	get_tree().paused = true

func close_dialog(run_after: bool = true) -> void:
	if capture_locked and run_after:
		return
	var callback := after_dialog
	after_dialog = Callable()
	hud.close_panel()
	get_tree().paused = false
	player.controls_enabled = not camera_active and not work_in_progress
	player.clear_motion()
	if run_after and callback.is_valid():
		callback.call()
	update_objective()

func update_objective() -> void:
	if camera_active:
		return
	var hint_steps := _investigation_steps()
	var completed_clues := 0
	if not hint_steps.is_empty():
		completed_clues = GameState.opening_items.size()
		for flag in ["meter_cover_open", "old_photo_seen", "room_bed_moved", "crypt_photo_seen", "crypt_plan_seen", "crypt_doodle_seen", "crypt_aligned", "crypt_clip_removed", "bunker_gate_examined", "bunker_oil_found", "bunker_lock_oiled", "bunker_lock_open"]:
			completed_clues += int(GameState.opening_flags[flag])
	hud.set_investigation_hints(player, hint_steps, completed_clues)
	if stage_kind == "bunker_ammo":
		hud.objective.text = "绕开坑口，从南侧门撤回机房" if GameState.demo_pursuit == "ammo" else "走横向石道，去右边寻找嘉敏的录音机"
	elif stage_kind == "bunker_hall":
		if GameState.opening_flags.ammo_chase_cleared:
			hud.objective.text = "穿过机房南侧通道，沿楼梯走回铁门外"
		elif GameState.demo_pursuit == "hall":
			hud.objective.text = "从右侧小拱门下深层楼梯"
		else:
			hud.objective.text = "核对机房白记，再进右侧子弹房找录音"
	elif stage_kind == "bunker_descent":
		hud.objective.text = "沿楼梯向下，小心右侧深坑"
	elif stage_kind == "hill_shelter":
		if GameState.opening_flags.ammo_chase_cleared:
			hud.objective.text = "门外复听录音，查清旧电话的声音" if not GameState.opening_flags.demo_case_closed else "按嘉敏的便签去大关斜巷，寻找她留下的新痕迹"
		else:
			hud.objective.text = "进入防空洞" if GameState.opening_flags.bunker_gate_unlocked else ("找油壶、钥匙与换锁工单" if GameState.opening_flags.bunker_gate_examined else "检查入口的铁链与挂锁")
	elif stage_kind == "hill_base":
		if GameState.opening_flags.bunker_gate_examined and not GameState.opening_flags.bunker_gate_unlocked:
			hud.objective.text = "寻找山脚的维修箱，查看钥匙上的刻痕"
		else:
			hud.objective.text = "查看山脚石碑，了解上山规则" if not GameState.opening_flags.hill_stele_seen else ("在安全区试着把观察方向转向身后" if not GameState.opening_flags.hill_warning_seen else "准备沿石阶上山")
	elif stage_kind == "crypt_archive":
		hud.objective.text = "寻找嘉敏调查链中的采访索引" if not GameState.opening_flags.interview_index_copied else "查看资料室出口"
	elif stage_kind == "crypt_hall":
		hud.objective.text = "照住黑衣人，绕过他到右侧门口" if not GameState.opening_flags.priest_escaped else "调查走廊尽头"
	elif stage_kind == "crypt":
		hud.objective.text = "调查地宫的照片、图纸和石壁"
	elif stage_kind == "exit_lane":
		hud.objective.text = "沿石阶调查牌坊方向" if GameState.opening_flags.help_attempted else "尝试用公用电话求助"
	elif stage_kind == "yard":
		hud.objective.text = "走向右侧拱门 · Shift 奔跑 · E 穿过" if not GameState.opening_flags.yard_escaped else "暂时脱离危险"
	elif stage_kind == "maintenance":
		hud.objective.text = "调查检修通道，寻找嘉敏的去向"
	elif stage_kind == "room304":
		hud.objective.text = "先熟悉衣柜藏身处" if GameState.opening_flags.room_phone_answered and not GameState.opening_flags.wardrobe_tutorial_done else "调查 304 房间，寻找嘉敏的线索"
	elif stage_kind == "corridor":
		hud.objective.text = "进入 304 寻找嘉敏" if GameState.opening_flags.jiamin_phone_found else "寻找 304 房门，查看地上的物件"
	elif stage_kind == "foyer":
		hud.objective.text = "到楼梯口，准备上三零四" if GameState.opening_flags.floor3_power else ("查测试表、找备件，恢复梯灯与三楼门扣" if GameState.opening_flags.meter_cover_open else "检查一楼墙边的电表箱")
	elif not GameState.opening_flags.photo_taken:
		hud.objective.text = "C 举起手机，为嘉敏拍一张旅行照"
	elif not GameState.opening_flags.pastry_shared:
		hud.objective.text = "走近嘉敏，接过她递来的葡挞"
	elif not GameState.opening_flags.knock_agreed:
		hud.objective.text = "和嘉敏约好走散时的敲门暗号"
	else:
		hud.objective.text = "沿街走到右侧唐楼门口"

func _investigation_steps() -> PackedStringArray:
	var flags: Dictionary = GameState.opening_flags
	if stage_kind == "foyer" and not flags.floor3_power:
		return PackedStringArray([
			"先找到一楼电表箱和恢复三楼供电所需的备件。",
			"对照值班工单、测试表和楼层支路。水泵舱必须继续隔离。",
			"用钳拆盖，装好街口和值班台的备件，再接通三楼梯灯和门扣支路。"
		])
	if stage_kind == "room304" and not flags.room_cover_open and not shadow_event_running:
		if not flags.room_bed_moved:
			return PackedStringArray([
				"找到 304 旧照拍到的位置，再辨认床后是什么。",
				"旧照里的四瓣花砖与床脚拖痕要放在一起看。",
				"查看书桌上的旧照，再靠近右边铁床调查床脚并推床。"
			])
		return PackedStringArray([
			"床后的检修口露出来了，先检查盖板。",
			"对照旧照中的木门位置和盖板边的新划痕。",
			"绕到盖板左前方按 E，在盖板选项里用工具钳拆盖。"
		])
	if stage_kind == "crypt" and not flags.crypt_door_open:
		return PackedStringArray([
			"辨认现在的石壁和旧图之间改动了什么。",
			"把巡查照、测绘描图和孩子的涂鸦放在一起，对照三斜痕和侧门框。",
			"资料齐后，在资料桌旋转、拖动描图，使三斜痕和侧门对齐，再到右侧门框检查卡扣。"
		])
	if stage_kind == "hill_shelter" and not flags.bunker_gate_unlocked:
		return PackedStringArray([
			"先查清洞门的链条和挂锁为什么卡住。",
			"对照山脚的换锁工单、锁面的两道磨槽和维修箱里的钥匙。",
			"找油壶处理锈锁，再比对方肩双槽钥匙与锁面，按机关提示卸力。"
		])
	return PackedStringArray()

func pause_menu() -> void:
	show_text("暂停", "WASD 移动　E 交谈／翻页\nC 举起手机　鼠标取景／左键拍照\nQ / Tab 手机　B 背包　M 地图　J 手札\nH 查看当前谜题提示", [{"text":"继续", "callback":close_dialog}, {"text":"重玩开场", "callback":confirm_restart_opening}, {"text":"退出", "callback":func():get_tree().quit(), "width":100}])

func confirm_restart_opening() -> void:
	show_text("重玩开场", "将先备份当前存档与照片，再从香港序章开始。确认后，继续游戏会读取新进度。", [
		{"text":"备份并重玩", "callback":restart_opening},
		{"text":"取消，返回暂停菜单", "callback":pause_menu}
	])

func restart_opening() -> void:
	close_dialog(false)
	if not GameState.start_new_opening():
		show_text("未能备份当前进度", "当前进度已保留。请检查存储空间与权限，再尝试重玩开场。")
		return
	if not GameState.request_room_change("ch0_hk_work", "arrival"):
		show_text("暂时无法返回开场", "新进度已保存，但香港序章暂时无法载入。请重新启动游戏后继续。")

func remove_meter_cover() -> void:
	if work_in_progress or GameState.opening_flags.meter_cover_open:
		return
	close_dialog(false)
	work_in_progress=true
	player.clear_motion()
	player.controls_enabled=false
	player.sprite.hide()
	work_pose.position=player.position
	work_pose.z_index=int(player.position.y)
	work_pose.show()
	hud.notify("用工具钳拆下检修盖……")
	AudioManager.play_world_effect("metal_cover")
	var timer:=Timer.new()
	timer.wait_time=.7
	timer.one_shot=true
	add_child(timer)
	timer.start()
	await timer.timeout
	if not is_inside_tree():
		if is_instance_valid(timer):
			timer.queue_free()
		return
	timer.queue_free()
	GameState.opening_flags.meter_cover_open=true
	checkpoint()
	work_in_progress=false
	work_pose.hide()
	player.sprite.show()
	player.controls_enabled=true
	show_power_puzzle()
	update_objective()

func show_power_puzzle() -> void:
	var diagram = preload("res://ui/power_service_panel.gd").new()
	diagram.name = "WiringPuzzle"
	diagram.completed.connect(func():
		if not GameState.opening_flags.floor3_power:
			choose_power_branch(power_puzzle.success_branch)
	)
	open_demo_widget(diagram)

func choose_power_branch(branch_id: String) -> void:
	if not GameState.opening_switches.has(branch_id):
		return
	GameState.opening_switches[branch_id]=not GameState.opening_switches[branch_id]
	GameState.opening_flags.floor3_power=GameState.opening_switches[power_puzzle.success_branch]
	checkpoint()
	stair_light.enabled=GameState.opening_flags.floor3_power
	AudioManager.play_world_effect("power_switch")
	if GameState.opening_flags.floor3_power:
		show_text("三楼支路亮了", "三楼指示灯亮了，楼梯口透出暖光。\n「修好了，赶紧上 304 找嘉敏和阿豪！」")
	else:
		var floor_id: String=""
		for branch in power_puzzle.branches:
			if branch.id==branch_id:
				floor_id=branch.floor
		show_text("再对照线路图", power_puzzle.wrong_feedback % floor_id,[{"text":"重新对照","callback":show_power_puzzle},{"text":"先离开","callback":close_dialog}])
	update_objective()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud):
		if camera_active:
			stop_camera()
		if not hud.panel_open:
			pause_menu()
