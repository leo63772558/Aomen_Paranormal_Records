extends Node2D

const ANOMALIES := GameRules.BUS_ANOMALIES

const REAR_DOOR_NOTICE := "有异象：先拉红色停车铃，再退回后门。\n无异象：直接从前门下车。\n连续五次判断正确才能驶出浓雾。\n\n正常车厢参照\n后视镜里的司机面朝前方。\n投币箱干净，感应屏亮绿灯。\n报站屏显示下一站是黑沙海滩。\n靠窗乘客低头坐着。\n侧窗外只有灯影和雾。"
const MISSED_ANOMALIES := {
	"driver_mirror": "司机在后视镜里没有五官，倒影倒悬在车顶。",
	"blood_coinbox": "前门投币箱的缝隙正在渗血。",
	"stop_screen": "报站屏把黑沙海滩换成了「枉死坡」。",
	"mannequin_turn": "靠窗乘客把颈部转向过道，倒影没有跟着变。",
	"window_hands": "车行过道中段时，有惨白的手拍上侧窗。",
	"aisle_blood_seep": "中段过道地胶接缝渗出一大片暗红血渍。",
	"ceiling_shadow": "车顶顶棚倒贴着一具像蜘蛛一样四肢扒住顶板的垂发女鬼。",
	"empty_seat_shoes": "后排原本空着的座位上多了一具浑身滴着黑海水的惨白乘客。",
	"fog_runner": "侧窗外浓雾中有一道白衣人影与高速行驶的巴士并排狂奔。",
	"hanging_straps": "过道扶手吊环下凭空站着一具抓握吊环的红衣鬼影。",
	"rear_door_peeker": "后门台阶处笔直站着一具浑身湿透的长发黑影正死死盯着过道。",
	"window_fog_writing": "左侧车窗冰冷雨雾处被人用湿淋淋的手指划出了清晰的「不要下车」。",
	"driver_neck_twist": "前门驾驶室旁站着一具头颅百八十度拧转过来的高大黑影。",
	"aisle_wet_footprints": "车厢过道正中一步步渗出黑海水渍，一道湿淋淋的白影正顺着水迹逼近。"
}
const ANOMALY_LOCATIONS := {
	"driver_mirror": "Mirror",
	"blood_coinbox": "Coinbox",
	"stop_screen": "StopScreen",
	"mannequin_turn": "Mannequin",
	"window_hands": "SideGlass",
	"aisle_blood_seep": "AisleFloor",
	"ceiling_shadow": "CeilingRail",
	"empty_seat_shoes": "RearSeat",
	"fog_runner": "SideGlass",
	"hanging_straps": "CeilingRail",
	"rear_door_peeker": "RearDoor",
	"window_fog_writing": "SideGlass",
	"driver_neck_twist": "Mirror",
	"aisle_wet_footprints": "AisleFloor"
}

var player: PlayerController
var hud
var camera: Camera2D

var success_counter: int = 0
const TARGET_SUCCESSES: int = 5
const BUS_WORLD_SIZE := Vector2(1400.0, 360.0)
const BUS_AISLE_TOP := 254.0
const BUS_AISLE_BOTTOM := 320.0
const REAR_DOOR_X := 90.0
const FRONT_DOOR_X := 1172.0
const BELL_TEXTURE := preload("res://assets/props/bus_stop_bell_251.png")
const BELL_POLES := [212.0, 515.0, 882.0, 1119.0]

var current_anomaly: String = ""
var cycle_index: int = 0
var is_transitioning: bool = false
var in_cinematic: bool = false

var mannequin_triggered: bool = false
var hands_triggered: bool = false
var sound_caption_time := 0.0
var handrail_pa_timer := 6.0
var bell_pulled := false
var lunge_rig: Control
var formal_front_door: Node2D
var formal_rear_door: Node2D
var bell_visuals: Array[Sprite2D] = []
var bell_motion: Tween
var cycle_generation := 0
var next_cycle_pending := false
var pause_panel_active := false
var crash_curtain: ColorRect
var crash_view: TextureRect
var crash_motion: Tween
var crash_generation := 0

var shake_intensity: float = 0.0
var interaction_sensors: Dictionary = {}
var bell_sensors: Array[Area2D] = []

# Visual nodes
var bus_base: Sprite2D
var mirror_sprite: Sprite2D
var coinbox_sprite: Sprite2D
var blood_particles: CPUParticles2D
var mannequin_sprite: Node2D
var hands_sprite: AnimatedSprite2D
var aisle_blood_node: Node2D
var ceiling_crawler_node: Node2D
var rear_shoes_node: Node2D
var fog_runner_node: Sprite2D
var straps_anomaly_node: Node2D
var rear_peeker_node: Node2D
var rear_peeker_canvas: Control
var fog_writing_node: Node2D
var fog_writing_canvas: Control
var driver_twist_node: Node2D
var aisle_footprints_node: Node2D
var aisle_footprint_sprites: Array[Sprite2D] = []
var anomaly_anim_time: float = 0.0
var peeker_rise: float = 0.0
var peeker_eye_x: float = 0.0
var driver_twitch_x: float = 0.0
var driver_twitch_rot: float = 0.0
var seen_anomalies: Array[String] = []
var bus_props_sheet: Texture2D
var mirror_normal_texture: AtlasTexture
var mirror_anomaly_texture: AtlasTexture
var coinbox_normal_texture: AtlasTexture
var coinbox_anomaly_texture: AtlasTexture
var led_label: Label
var led_panel: PanelContainer

# Audio nodes
var bgm_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var stinger_player: AudioStreamPlayer

# Screamer overlay
var glitch_overlay: CanvasLayer
var glitch_rect: ColorRect
var jumpscare_sprite: AnimatedSprite2D
var glitch_timer: float = 0.0

# Inspection / Dialogue helper
var after_panel: Callable

func _ready() -> void:
	var entered_from_w17_ticket := GameState.pending_entry_id == "from_w17_ticket"
	var resumed_cycle: bool = GameState.bus_loop_state.initialized
	GameState.current_chapter_id = "ch4_bus33_loop"
	GameState.current_room_id = "ch4_bus_loop"
	
	_setup_audio()
	_setup_environment()
	_setup_props()
	_setup_collision()
	_setup_player()
	_setup_hud()
	hud.journal_note = REAR_DOOR_NOTICE
	_setup_screamer_overlay()
	_build_formal_doors()
	
	if GameState.bus_loop_state.initialized:
		success_counter = mini(int(GameState.bus_loop_state.successes), TARGET_SUCCESSES)
		cycle_index = int(GameState.bus_loop_state.cycle)
		current_anomaly = GameState.bus_loop_state.anomaly
		var initial_history: Array = [current_anomaly] if current_anomaly in ANOMALIES else []
		seen_anomalies.assign(GameState.bus_loop_state.get("seen_anomalies", initial_history))
		bell_pulled = GameState.bus_loop_state.bell_pulled
		next_cycle_pending = GameState.bus_loop_state.get("next_cycle_pending", false)
		_apply_anomaly_visuals()
		_update_hud_status()
		if success_counter >= TARGET_SUCCESSES: call_deferred("_trigger_hac_sa_crash")
		elif next_cycle_pending:
			if success_counter == 0:
				_show_wrong_judgment(false)
			else:
				_start_new_cycle(false)
	else:
		_start_new_cycle(true)
	if entered_from_w17_ticket and not resumed_cycle:
		call_deferred("_show_w17_arrival")

func _show_w17_arrival() -> void:
	_say("亚马喇前地 · 33 路末班车", "从大关斜巷逃出后，大文按时刻表背面的留言赶到亚马喇前地——深更半夜，竟真停着唯一亮灯的 33 路，车头牌写着往黑沙海滩。\n\n带上嘉敏留下的证物，先从车尾走到前门认一遍正常车厢。后门的旧告示已记入背包线索，按 B 或 J 可随时再看。", "陈大文")

func _build_formal_doors() -> void:
	for x in [REAR_DOOR_X, FRONT_DOOR_X]:
		var door := preload("res://core/components/folding_bus_door.gd").new()
		door.position = Vector2(x, 267)
		door.scale = Vector2(1.92 if x == REAR_DOOR_X else 1.18, 1.24)
		door.z_index = 7
		add_child(door)
		if x == REAR_DOOR_X: formal_rear_door = door
		else: formal_front_door = door

func _setup_audio() -> void:
	AudioManager.set_scene_ambience("night_bus")
	
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Ambience"
	bgm_player.volume_db = -3.0
	var bgm_stream = load("res://assets/audio/demo/bridge_bus_ambience.wav")
	add_child(bgm_player)
	if bgm_stream != null:
		if bgm_stream is AudioStreamWAV:
			AudioManager._enable_wav_loop(bgm_stream)
		bgm_player.stream = bgm_stream
		if not AudioManager.silent_run:
			bgm_player.play()
	
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "SFX"
	add_child(sfx_player)
	
	stinger_player = AudioStreamPlayer.new()
	stinger_player.bus = "SFX"
	add_child(stinger_player)
	
func _setup_environment() -> void:
	# Moody midnight horror lighting
	var ambient := CanvasModulate.new()
	ambient.color = Color(0.78, 0.82, 0.87, 1.0)
	add_child(ambient)
	
	# Moving Bridge & Sea Fog parallax layers behind windows
	
	# Bus interior base
	bus_base = Sprite2D.new()
	bus_base.texture = load("res://assets/tilesets/bus_interior_reworked_026.png")
	bus_base.centered = false
	var fit_scale: float = BUS_WORLD_SIZE.x / bus_base.texture.get_width()
	bus_base.scale = Vector2.ONE * fit_scale
	bus_base.position = Vector2(0.0, (BUS_WORLD_SIZE.y - bus_base.texture.get_height() * fit_scale) * 0.5)
	add_child(bus_base)

func _atlas_cell(sheet: Texture2D, column: int, row: int, columns := 2, rows := 2) -> AtlasTexture:
	var cell := AtlasTexture.new()
	cell.atlas = sheet
	var cell_size := Vector2(float(sheet.get_width()) / columns, float(sheet.get_height()) / rows)
	cell.region = Rect2(Vector2(column, row) * cell_size, cell_size)
	cell.filter_clip = true
	return cell

func _setup_props() -> void:
	bus_props_sheet = load("res://assets/props/bus_props_027.png") as Texture2D
	mirror_normal_texture = _atlas_cell(bus_props_sheet, 0, 0)
	mirror_anomaly_texture = _atlas_cell(bus_props_sheet, 1, 0)
	var tall_normal := load("res://assets/props/bus_coinbox_tall_v5.png") as Texture2D
	var tall_blood := load("res://assets/props/bus_coinbox_blood_v5.png") as Texture2D
	if tall_normal != null and tall_blood != null:
		coinbox_normal_texture = AtlasTexture.new()
		coinbox_normal_texture.atlas = tall_normal
		coinbox_normal_texture.region = Rect2(Vector2.ZERO, tall_normal.get_size())
		coinbox_anomaly_texture = AtlasTexture.new()
		coinbox_anomaly_texture.atlas = tall_blood
		coinbox_anomaly_texture.region = Rect2(Vector2.ZERO, tall_blood.get_size())
	else:
		coinbox_normal_texture = _atlas_cell(bus_props_sheet, 0, 1)
		coinbox_anomaly_texture = _atlas_cell(bus_props_sheet, 1, 1)

	# Rearview mirror mounted cleanly at driver's upper windshield ceiling (NEVER sitting on passenger seats!)
	mirror_sprite = Sprite2D.new()
	mirror_sprite.texture = mirror_normal_texture
	mirror_sprite.position = Vector2(1142, 74)
	mirror_sprite.scale = Vector2(0.092, 0.092)
	mirror_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mirror_sprite.z_index = 8
	add_child(mirror_sprite)
	
	# Tall realistic waist-height stainless Macau bus fare coinbox beside the front door
	coinbox_sprite = Sprite2D.new()
	coinbox_sprite.texture = coinbox_normal_texture
	coinbox_sprite.position = Vector2(1082, 214)
	coinbox_sprite.scale = Vector2(0.30, 0.34) if tall_normal != null else Vector2(0.10, 0.10)
	coinbox_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	coinbox_sprite.z_index = 10
	add_child(coinbox_sprite)
	
	# Organic expanding dark-crimson blood puddle beneath coin box (replaces blocky flying red squares)
	blood_particles = CPUParticles2D.new()
	blood_particles.position = coinbox_sprite.position + Vector2(0, 14)
	blood_particles.amount = 10
	blood_particles.lifetime = 1.6
	blood_particles.direction = Vector2(0, 1)
	blood_particles.spread = 32.0
	blood_particles.gravity = Vector2(0, 48)
	blood_particles.initial_velocity_min = 4.0
	blood_particles.initial_velocity_max = 12.0
	blood_particles.color = Color(0.48, 0.04, 0.05, 0.72)
	blood_particles.scale_amount_min = 1.2
	blood_particles.scale_amount_max = 2.4
	blood_particles.emitting = false
	blood_particles.z_index = 9
	add_child(blood_particles)
	
	# Same passenger identity as the continuous close-up lunge.
	mannequin_sprite = preload("res://entities/bus_seated_passenger.gd").new()
	mannequin_sprite.position = Vector2(620, 251)
	mannequin_sprite.scale = Vector2.ONE * 0.72
	mannequin_sprite.z_index = 9
	add_child(mannequin_sprite)
	var reflection := Sprite2D.new()
	reflection.texture = mannequin_sprite.mesh.texture
	reflection.region_enabled = true
	reflection.region_rect = Rect2(145, 0, 360, 320)
	reflection.position = Vector2(632, 111)
	reflection.scale = Vector2.ONE * 0.17
	reflection.flip_h = true
	reflection.modulate = Color(0.48, 0.72, 0.74, 0.30)
	reflection.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	reflection.z_index = 8
	var reflection_fade := Shader.new()
	reflection_fade.code = """
shader_type canvas_item;
varying float pane_height;
void vertex() {
	pane_height = VERTEX.y;
}
void fragment() {
	COLOR.a *= 1.0 - smoothstep(10.0, 155.0, pane_height);
}
"""
	var glass_material := ShaderMaterial.new()
	glass_material.shader = reflection_fade
	reflection.material = glass_material
	add_child(reflection)

	# Waterlogged hands slap the glass in a four-frame animation.
	var hands_sheet := load("res://assets/props/bus_window_hands_027.png") as Texture2D
	var hands_frames := SpriteFrames.new()
	hands_frames.add_animation("slap")
	hands_frames.set_animation_loop("slap", false)
	hands_frames.set_animation_speed("slap", 18.0)
	for cell_index in range(4):
		hands_frames.add_frame("slap", _atlas_cell(hands_sheet, cell_index % 2, cell_index / 2))
	hands_sprite = AnimatedSprite2D.new()
	hands_sprite.sprite_frames = hands_frames
	hands_sprite.animation = "slap"
	hands_sprite.position = Vector2(460, 88)
	hands_sprite.scale = Vector2(0.15, 0.15)
	hands_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	hands_sprite.z_index = 12
	hands_sprite.visible = false
	add_child(hands_sprite)
	
	# Electronic LED stop announcer screen hung at ceiling (X=960, Y=70)
	led_panel = PanelContainer.new()
	led_panel.position = Vector2(920, 36)
	led_panel.size = Vector2(190, 24)
	led_panel.z_index = 15
	var led_style := StyleBoxFlat.new()
	led_style.bg_color = Color(0.04, 0.07, 0.06, 0.92)
	led_style.border_color = Color(0.2, 0.3, 0.25, 1.0)
	led_style.set_border_width_all(1)
	led_panel.add_theme_stylebox_override("panel", led_style)
	add_child(led_panel)
	
	led_label = Label.new()
	var font := UiFont.song()
	led_label.add_theme_font_override("font", font)
	led_label.add_theme_font_size_override("font_size", 12)
	led_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.45, 1.0))
	led_label.text = "[33] 下一站：黑沙海滩"
	led_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	led_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	led_panel.add_child(led_label)

	for pole_x: float in BELL_POLES:
		var bell := Sprite2D.new()
		bell.texture = BELL_TEXTURE
		bell.scale = Vector2.ONE * 27.0 / BELL_TEXTURE.get_height()
		bell.position = Vector2(pole_x + 10.0, 170)
		bell.offset.y = BELL_TEXTURE.get_height() * 0.31
		bell.z_index = 12
		add_child(bell)
		bell_visuals.append(bell)
		bell_sensors.append(_add_interaction_sensor("Bell_%d" % int(pole_x), Vector2(pole_x + 10.0, 280), 25.0))
	_add_interaction_sensor("Mirror", Vector2(1030, 258), 24.0)
	_add_interaction_sensor("Coinbox", Vector2(1080, 266), 24.0)
	_add_interaction_sensor("Mannequin", Vector2(620, 266), 27.0)
	_add_interaction_sensor("SideGlass", Vector2(460, 254), 27.0)
	_add_interaction_sensor("StopScreen", Vector2(945, 267), 24.0)
	_add_interaction_sensor("AisleFloor", Vector2(760, 286), 28.0)
	_add_interaction_sensor("CeilingRail", Vector2(730, 260), 28.0)
	_add_interaction_sensor("RearSeat", Vector2(355, 262), 28.0)
	_add_interaction_sensor("FrontDoor", Vector2(FRONT_DOOR_X, 281), 28.0)
	_add_interaction_sensor("RearDoor", Vector2(REAR_DOOR_X, 281), 34.0)

func _setup_legacy_anomaly_props() -> void:
	# Extra subtle anomaly 6: Realistic painted glossy dark-crimson blood puddle seeping along mid-aisle floor seam
	aisle_blood_node = Node2D.new()
	aisle_blood_node.name = "AisleBloodSeep"
	aisle_blood_node.position = Vector2(760, 290)
	aisle_blood_node.z_index = 6
	aisle_blood_node.visible = false
	var blood_sp := Sprite2D.new()
	blood_sp.texture = load("res://assets/props/bus_aisle_blood_v10.png")
	blood_sp.scale = Vector2(0.46, 0.44)
	blood_sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	aisle_blood_node.add_child(blood_sp)
	add_child(aisle_blood_node)

	# Extra subtle anomaly 7: Full-body ghost flipped upside-down clinging like a spider flat against the bus ceiling roof!
	ceiling_crawler_node = Node2D.new()
	ceiling_crawler_node.name = "CeilingShadowCrawler"
	ceiling_crawler_node.position = Vector2(730, 52)
	ceiling_crawler_node.z_index = 14
	ceiling_crawler_node.visible = false
	var crawler_sprite := Sprite2D.new()
	crawler_sprite.name = "SpiderGhostSprite"
	crawler_sprite.texture = load("res://assets/characters/bus_ceiling_spider_ghost_v11.png")
	crawler_sprite.scale = Vector2(0.46, 0.44)
	crawler_sprite.modulate = Color(0.82, 0.88, 0.90, 0.94)
	ceiling_crawler_node.add_child(crawler_sprite)
	add_child(ceiling_crawler_node)

	# Extra subtle anomaly 8: Full-body drowned ghost passenger sitting/hunched at the rear empty seat with dark seawater pooling beneath
	rear_shoes_node = Node2D.new()
	rear_shoes_node.name = "RearSeatWetShoes"
	rear_shoes_node.position = Vector2(355, 224)
	rear_shoes_node.z_index = 9
	rear_shoes_node.visible = false
	var puddle_sp := Sprite2D.new()
	puddle_sp.texture = load("res://assets/props/bus_aisle_blood_v10.png")
	puddle_sp.position = Vector2(0, 38)
	puddle_sp.scale = Vector2(0.34, 0.28)
	puddle_sp.modulate = Color(0.10, 0.18, 0.22, 0.88)
	rear_shoes_node.add_child(puddle_sp)
	var rear_ghost_sp := Sprite2D.new()
	rear_ghost_sp.name = "RearSeatFullGhost"
	rear_ghost_sp.texture = load("res://assets/characters/drowned_ghost_v3.png")
	rear_ghost_sp.scale = Vector2(0.18, 0.18)
	rear_ghost_sp.modulate = Color(0.76, 0.86, 0.90, 0.92)
	rear_shoes_node.add_child(rear_ghost_sp)
	add_child(rear_shoes_node)

	# Extra anomaly 9: Pale white figure running alongside bus outside foggy window
	fog_runner_node = Sprite2D.new()
	fog_runner_node.name = "FogWindowRunner"
	fog_runner_node.texture = load("res://assets/characters/drowned_ghost_v3.png")
	fog_runner_node.position = Vector2(465, 118)
	fog_runner_node.scale = Vector2(0.15, 0.15)
	fog_runner_node.modulate = Color(0.82, 0.88, 0.90, 0.62)
	fog_runner_node.z_index = 6
	fog_runner_node.visible = false
	add_child(fog_runner_node)

	# Extra anomaly 10: Full-body red-coated ghost standing in the aisle gripping the existing painted ceiling strap (ZERO duplicate overlapping straps!)
	straps_anomaly_node = Node2D.new()
	straps_anomaly_node.name = "TiltedHangingStraps"
	straps_anomaly_node.position = Vector2(732, 212)
	straps_anomaly_node.z_index = 14
	straps_anomaly_node.visible = false
	var red_sheet := load("res://assets/characters/bunker_red_walker_022.png") as Texture2D
	if red_sheet != null:
		var red_sp := Sprite2D.new()
		red_sp.name = "StrapRedGhost"
		var r_at := AtlasTexture.new()
		r_at.atlas = red_sheet
		r_at.region = Rect2(0, 0, red_sheet.get_width() / 3.0, red_sheet.get_height())
		r_at.filter_clip = true
		red_sp.texture = r_at
		red_sp.scale = Vector2(0.18, 0.18)
		red_sp.modulate = Color(0.92, 0.78, 0.76, 0.92)
		straps_anomaly_node.add_child(red_sp)
	add_child(straps_anomaly_node)

	# Extra anomaly 11: Full-body long-haired dark wraith standing inside the rear door stairwell (NOT just a floating head!)
	rear_peeker_node = Node2D.new()
	rear_peeker_node.name = "RearDoorPeeker"
	rear_peeker_node.position = Vector2(REAR_DOOR_X + 34.0, 214)
	rear_peeker_node.z_index = 9
	rear_peeker_node.visible = false
	rear_peeker_canvas = Control.new()
	rear_peeker_canvas.position = Vector2(-45, -90)
	rear_peeker_canvas.size = Vector2(90, 180)
	rear_peeker_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var peeker_sp := Sprite2D.new()
	peeker_sp.name = "PeekerFace"
	var wraith_sheet := load("res://assets/characters/wardrobe_stalker_v5.png") as Texture2D
	if wraith_sheet != null:
		var w_at := AtlasTexture.new()
		w_at.atlas = wraith_sheet
		w_at.region = Rect2(0, 0, wraith_sheet.get_width() * 0.5, wraith_sheet.get_height() * 0.5)
		w_at.filter_clip = true
		peeker_sp.texture = w_at
	peeker_sp.scale = Vector2(0.24, 0.24)
	peeker_sp.position = Vector2(45, 92)
	peeker_sp.modulate = Color(0.82, 0.88, 0.90, 0.92)
	rear_peeker_canvas.add_child(peeker_sp)
	rear_peeker_node.add_child(rear_peeker_canvas)
	add_child(rear_peeker_node)

	# Extra anomaly 12: Authentic painted frosted rain condensation with crisp finger-traced "不要下车"
	fog_writing_node = Node2D.new()
	fog_writing_node.name = "WindowFogWriting"
	fog_writing_node.position = Vector2(360, 66)
	fog_writing_node.z_index = 11
	fog_writing_node.visible = false
	var fog_sp := Sprite2D.new()
	fog_sp.texture = load("res://assets/props/bus_fog_writing_v10.png")
	fog_sp.centered = false
	fog_sp.scale = Vector2(0.49, 0.49)
	fog_sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fog_writing_node.add_child(fog_sp)
	fog_writing_canvas = Control.new()
	fog_writing_canvas.size = Vector2(158, 92)
	fog_writing_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog_writing_node.add_child(fog_writing_canvas)
	add_child(fog_writing_node)

	# Extra anomaly 13: Full-body twisted dark figure standing by the driver's cab & front stairwell (NOT a floating head!)
	driver_twist_node = Node2D.new()
	driver_twist_node.name = "DriverNeckTwist"
	driver_twist_node.position = Vector2(1218, 198)
	driver_twist_node.z_index = 11
	driver_twist_node.visible = false
	var drv_sp := Sprite2D.new()
	drv_sp.name = "DriverBust"
	if wraith_sheet != null:
		var d_at := AtlasTexture.new()
		d_at.atlas = wraith_sheet
		d_at.region = Rect2(wraith_sheet.get_width() * 0.5, 0, wraith_sheet.get_width() * 0.5, wraith_sheet.get_height() * 0.5)
		d_at.filter_clip = true
		drv_sp.texture = d_at
	drv_sp.scale = Vector2(0.25, 0.25)
	drv_sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	driver_twist_node.add_child(drv_sp)
	add_child(driver_twist_node)

	# Extra anomaly 14: Realistic dark seawater puddle trail & flickering full-body drowned wraith advancing down the aisle
	aisle_footprints_node = Node2D.new()
	aisle_footprints_node.name = "AisleWetFootprints"
	aisle_footprints_node.z_index = 6
	aisle_footprints_node.visible = false
	aisle_footprints_node.draw.connect(_draw_aisle_footprint_puddles)
	aisle_footprint_sprites.clear()
	var seep_tex := load("res://assets/props/bus_aisle_blood_v10.png") as Texture2D
	var fp_xs: Array[float] = [965.0, 902.0, 840.0, 778.0, 716.0, 654.0, 592.0, 530.0]
	for fp_i in range(fp_xs.size()):
		var fp := Sprite2D.new()
		fp.texture = seep_tex
		fp.position = Vector2(fp_xs[fp_i], 272.0 if (fp_i % 2 == 0) else 286.0)
		fp.rotation = 0.15 if (fp_i % 2 == 0) else -0.15
		fp.scale = Vector2(0.14, 0.11)
		fp.modulate = Color(0.08, 0.15, 0.18, 0.0)
		aisle_footprints_node.add_child(fp)
		aisle_footprint_sprites.append(fp)
	add_child(aisle_footprints_node)

func _add_interaction_sensor(id: String, at: Vector2, radius: float) -> Area2D:
	var area := Area2D.new()
	area.name = id
	area.position = at
	area.collision_layer = 8
	area.collision_mask = 2
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	interaction_sensors[id] = area
	return area

func _sensor_overlaps(id: String) -> bool:
	var sensor := interaction_sensors.get(id) as Area2D
	if not is_instance_valid(player) or not is_instance_valid(sensor):
		return false
	if sensor.overlaps_body(player):
		return true
	# Area2D overlap lists refresh on physics ticks; keep E prompts reliable in
	# the same frame the player reaches a sensor, including hidden test windows.
	var sensor_shape := sensor.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var player_shape := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if sensor_shape == null or player_shape == null or not (sensor_shape.shape is CircleShape2D) or not (player_shape.shape is CircleShape2D):
		return false
	var reach: float = (sensor_shape.shape as CircleShape2D).radius + (player_shape.shape as CircleShape2D).radius
	return sensor.global_position.distance_to(player.global_position) <= reach

func _setup_collision() -> void:
	# The seat rows frame one continuous, walkable passenger aisle.
	LevelGeometry.wall(self, Rect2(158, 0, 969, BUS_AISLE_TOP))
	LevelGeometry.wall(self, Rect2(0, 0, BUS_WORLD_SIZE.x, 220))
	LevelGeometry.wall(self, Rect2(161, BUS_AISLE_BOTTOM, 1000, BUS_WORLD_SIZE.y - BUS_AISLE_BOTTOM))
	LevelGeometry.wall(self, Rect2(0, 345, BUS_WORLD_SIZE.x, 15))
	# The standing coin box occupies a narrow section beside the front door.
	LevelGeometry.wall(self, Rect2(1063.0, 222.0, 34.0, 40.0))
	# Rear back wall
	LevelGeometry.wall(self, Rect2(0, 0, 24, 360))
	# Driver cabin partition protects the steering area.
	LevelGeometry.wall(self, Rect2(1214, 0, 186, 360))

func _setup_player() -> void:
	player = preload("res://entities/player/player.tscn").instantiate()
	player.position = Vector2(240, 283)
	player.visual_size_multiplier = 3.1
	player.allow_flashlight = true
	player.flashlight_on = true
	player.z_index = 20
	add_child(player)
	
	camera = player.get_node("Camera2D") as Camera2D
	if is_instance_valid(camera):
		camera.enabled = true
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = int(BUS_WORLD_SIZE.x)
		camera.limit_bottom = int(BUS_WORLD_SIZE.y)
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 7.0

func _setup_hud() -> void:
	hud = preload("res://ui/quiet_hud.gd").new()
	add_child(hud)
	hud.show_resources(false)
	hud.close_requested.connect(_on_hud_close)
	hud.pause_requested.connect(_on_hud_pause)
	var scene_stamp: Label = hud.label("跨海雾路 · 33路末班车", Vector2(20, 16), Vector2(300, 28), 14, Color("e6d6ac"))
	hud.root.move_child(scene_stamp, 0)
	_update_hud_status()

func _setup_screamer_overlay() -> void:
	glitch_overlay = CanvasLayer.new()
	glitch_overlay.layer = 100
	add_child(glitch_overlay)
	
	glitch_rect = ColorRect.new()
	glitch_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glitch_rect.color = Color(0.85, 0.05, 0.05, 0.0)
	glitch_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glitch_rect.z_index = 0
	glitch_overlay.add_child(glitch_rect)


func _process(delta: float) -> void:
	sound_caption_time = maxf(sound_caption_time - delta, 0.0)
	if is_transitioning:
		hud.state_text.text = ""
	elif sound_caption_time <= 0.0:
		hud.state_text.text = "[ 报站屏 ] " + led_label.text.substr(5) if absf(player.position.x - led_panel.position.x) <= 135.0 else ""
	if not is_transitioning and not in_cinematic and not get_tree().paused:
		handrail_pa_timer -= delta
		if handrail_pa_timer <= 0.0:
			handrail_pa_timer = 24.0
			AudioManager.play_bus_pa("bus_handrail_4lang", -7.5)
	_update_glitch(delta)
	_update_camera_shake(delta)
	_update_new_anomalies(delta)
	_check_player_triggers()
	_update_interaction_prompts()

func _update_new_anomalies(delta: float) -> void:
	if current_anomaly.is_empty():
		return
	anomaly_anim_time += delta
	match current_anomaly:
		"ceiling_shadow":
			if is_instance_valid(ceiling_crawler_node) and ceiling_crawler_node.visible:
				# Twitchy spider-like crawling along the bus ceiling roof
				ceiling_crawler_node.position.x = 730.0 + sin(anomaly_anim_time * 2.4) * 28.0 + sin(anomaly_anim_time * 17.0) * 1.8
				ceiling_crawler_node.position.y = 52.0 + cos(anomaly_anim_time * 4.2) * 2.2
				var sp_g := ceiling_crawler_node.get_node_or_null("SpiderGhostSprite") as Sprite2D
				if is_instance_valid(sp_g):
					sp_g.scale.x = 0.46 + sin(anomaly_anim_time * 9.0) * 0.025
					sp_g.scale.y = 0.44 - sin(anomaly_anim_time * 9.0) * 0.022
		"rear_door_peeker":
			if is_instance_valid(rear_peeker_node) and rear_peeker_node.visible:
				peeker_rise = clampf(0.32 + anomaly_anim_time * 0.19, 0.32, 1.0)
				if is_instance_valid(formal_rear_door):
					rear_peeker_node.modulate.a = clampf(1.0 - formal_rear_door.openness * 3.5, 0.0, 1.0)
				var face_sp := rear_peeker_canvas.get_node_or_null("PeekerFace") as Sprite2D if is_instance_valid(rear_peeker_canvas) else null
				if is_instance_valid(face_sp):
					face_sp.position.y = 92.0 + sin(anomaly_anim_time * 2.4) * 2.2
					face_sp.scale.y = 0.24 * (1.0 + sin(anomaly_anim_time * 3.1) * 0.025)
		"driver_neck_twist":
			if is_instance_valid(driver_twist_node) and driver_twist_node.visible:
				var pulse: float = sin(anomaly_anim_time * 13.0) * sin(anomaly_anim_time * 3.7)
				var drv_sp := driver_twist_node.get_node_or_null("DriverBust") as Sprite2D
				if is_instance_valid(drv_sp):
					if not GameState.reduced_flash and absf(pulse) > 0.86:
						drv_sp.position.x = sin(anomaly_anim_time * 47.0) * 1.6
						drv_sp.rotation = cos(anomaly_anim_time * 39.0) * 0.08
					else:
						drv_sp.position.x = 0.0
						drv_sp.rotation = sin(anomaly_anim_time * 1.6) * 0.025
		"aisle_wet_footprints":
			if is_instance_valid(aisle_footprints_node) and aisle_footprints_node.visible:
				for i in range(aisle_footprint_sprites.size()):
					var sp: Sprite2D = aisle_footprint_sprites[i]
					if not is_instance_valid(sp):
						continue
					var appear_at: float = 0.0 if i < 2 else float(i - 1) * 0.62
					var target_a: float = clampf((anomaly_anim_time - appear_at) * 2.2, 0.0, 0.90)
					sp.modulate.a = target_a
				aisle_footprints_node.queue_redraw()

func _draw_rear_peeker() -> void:
	var c: Control = rear_peeker_canvas
	var sz: Vector2 = c.size
	# Wet translucent rain-glass sheen overlay framing the painted peeker face behind rear door glass
	c.draw_rect(Rect2(5.0, 2.0, sz.x - 10.0, sz.y - 4.0), Color(0.08, 0.16, 0.18, 0.24), true)
	c.draw_line(Vector2(7.0, 4.0), Vector2(7.0, sz.y - 4.0), Color(0.55, 0.70, 0.72, 0.28), 1.0)
	c.draw_line(Vector2(sz.x - 7.0, 4.0), Vector2(sz.x - 7.0, sz.y - 4.0), Color(0.55, 0.70, 0.72, 0.22), 1.0)

func _draw_aisle_footprint_puddles() -> void:
	for sp in aisle_footprint_sprites:
		if not is_instance_valid(sp) or sp.modulate.a <= 0.02:
			continue
		var a: float = sp.modulate.a
		var p: Vector2 = sp.position
		# Dark glistening wet black-sand moisture ring around each materialized shoe print
		var oval := PackedVector2Array()
		for k in range(14):
			var ang: float = float(k) * TAU / 14.0
			oval.append(p + Vector2(cos(ang) * 14.5, sin(ang) * 7.2))
		aisle_footprints_node.draw_colored_polygon(oval, Color(0.04, 0.06, 0.08, 0.42 * a))
		aisle_footprints_node.draw_arc(p, 9.5, 0.0, TAU, 14, Color(0.28, 0.36, 0.39, 0.24 * a), 1.0, true)

func _refresh_broadcast_display() -> void:
	var wrong_stop := current_anomaly == "stop_screen"
	led_label.text = "[33] 下一站  枉死坡" if wrong_stop else "[33] 下一站  黑沙海滩"
	led_label.add_theme_color_override("font_color", Color("ff6a68") if wrong_stop else Color("4df273"))

func _update_glitch(delta: float) -> void:
	if glitch_timer > 0.0:
		glitch_timer -= delta
		var alpha := clampf(glitch_timer / 0.8, 0.0, 0.85)
		if GameState.reduced_flash:
			alpha = minf(alpha, 0.15)
		glitch_rect.color = Color(0.85, 0.05, 0.05, alpha)
		# Screen jitter glitch
		if glitch_timer > 0.1 and not GameState.reduced_flash:
			glitch_rect.position = Vector2(randf_range(-8, 8), randf_range(-6, 6))
			if is_instance_valid(jumpscare_sprite) and jumpscare_sprite.visible:
				jumpscare_sprite.position = Vector2(320 + randf_range(-11, 11), 180 + randf_range(-8, 8))
		else:
			glitch_rect.position = Vector2.ZERO
			if is_instance_valid(jumpscare_sprite):
				jumpscare_sprite.position = Vector2(320, 180)

func _update_camera_shake(delta: float) -> void:
	if shake_intensity > 0.0:
		shake_intensity = maxf(0.0, shake_intensity - delta * 18.0)
		if is_instance_valid(camera):
			var visible_shake := shake_intensity * (0.2 if GameState.reduced_flash else 1.0)
			camera.offset = Vector2(randf_range(-visible_shake, visible_shake), randf_range(-visible_shake, visible_shake))
	elif is_instance_valid(camera):
		camera.offset = Vector2.ZERO

func _check_player_triggers() -> void:
	if not is_instance_valid(player) or is_transitioning or in_cinematic:
		return
	
	var px := player.position.x
	
	# Mannequin jump trigger: when player passes X=580 eastward
	if current_anomaly == "mannequin_turn" and not mannequin_triggered and px >= 560:
		mannequin_triggered = true
		mannequin_sprite.turn()
		_play_sfx("res://assets/audio/demo/mannequin_snap.wav")
		shake_intensity = 6.0
		if not GameState.reduced_flash and is_instance_valid(bus_base):
			bus_base.modulate = Color(0.42, 0.26, 0.28)
			var flicker_tw := create_tween()
			flicker_tw.tween_property(bus_base, "modulate", Color.WHITE, 0.35)
		hud.state_text.text = "【旁座传来一声脆响】"
		sound_caption_time = 1.35
	
	# Window hands jump trigger: when player walks past mid-aisle (X >= 430)
	if current_anomaly == "window_hands" and not hands_triggered and px >= 430:
		hands_triggered = true
		hands_sprite.visible = true
		hands_sprite.position = Vector2(520, 88)
		hands_sprite.scale = Vector2(0.10, 0.10)
		hands_sprite.frame = 0
		hands_sprite.play("slap")
		var hands_tween := create_tween()
		hands_tween.set_parallel(true)
		hands_tween.tween_property(hands_sprite, "position", Vector2(460, 88), 0.19).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		hands_tween.tween_property(hands_sprite, "scale", Vector2(0.15, 0.15), 0.19).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_play_sfx("res://assets/audio/demo/window_slap.wav")
		shake_intensity = 10.0
		hud.state_text.text = "【侧窗传来一声拍击】"
		sound_caption_time = 1.35
	
	# Doorways show a prompt; E is required to submit a judgment.

func _update_interaction_prompts() -> void:
	if not is_instance_valid(player) or is_transitioning or in_cinematic or hud.panel_open:
		return
	
	hud.prompt.text = ""
	
	# Inspectable objects take priority over nearby pull cords.
	
	# Rearview mirror inspection (near driver cabin)
	if _sensor_overlaps("Mirror"):
		hud.prompt.text = "[ E ] 观察后视镜里的司机"
		return
	
	# Coin box inspection
	if _sensor_overlaps("Coinbox"):
		hud.prompt.text = "[ E ] 检查投币箱"
		return
	
	# Seated Mannequin passenger inspection
	if _sensor_overlaps("Mannequin"):
		hud.prompt.text = "[ E ] 查看身旁的乘客"
		return

	# Side window inspection
	if _sensor_overlaps("SideGlass"):
		hud.prompt.text = "[ E ] 观察侧窗"
		return
	
	# LED Announcer board
	if _sensor_overlaps("StopScreen"):
		hud.prompt.text = "[ E ] 抬头看电子报站屏"
		return
	if current_anomaly == "aisle_blood_seep" and _sensor_overlaps("AisleFloor"):
		hud.prompt.text = "[ E ] 查看过道地胶"
		return
	if current_anomaly == "aisle_wet_footprints" and _sensor_overlaps("AisleFloor"):
		hud.prompt.text = "[ E ] 查看过道上的湿鞋印"
		return
	if current_anomaly == "ceiling_shadow" and _sensor_overlaps("CeilingRail"):
		hud.prompt.text = "[ E ] 抬头看车顶行李架"
		return
	if current_anomaly == "hanging_straps" and _sensor_overlaps("CeilingRail"):
		hud.prompt.text = "[ E ] 观察歪斜僵直的车顶吊环"
		return
	if current_anomaly == "empty_seat_shoes" and _sensor_overlaps("RearSeat"):
		hud.prompt.text = "[ E ] 查看后排空座下方"
		return
	
	# Front door prompt
	if _sensor_overlaps("FrontDoor"):
		hud.prompt.text = "[ E ] 从前门通过 (确认正常通行)"
		return
	
	# Rear door prompt
	if _sensor_overlaps("RearDoor"):
		hud.prompt.text = "[ E ] 从后门折返 · 提交异常判断" if bell_pulled else "[ E ] 检查后门 · 先拉红色停车铃"
		return
	for bell_area: Area2D in bell_sensors:
		if _sensor_overlaps(bell_area.name):
			hud.prompt.text = "停车铃已响 · 从后门提交异常判断" if bell_pulled else "[ E ] 拉红色停车铃 · 登记异常"
			return

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(player) or is_transitioning or in_cinematic or hud.panel_open or event.is_echo():
		return
	
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_handle_interaction()
	elif event.is_action_pressed("journal"):
		get_viewport().set_input_as_handled()
		_say("后门旧告示", REAR_DOOR_NOTICE)

func _handle_interaction() -> void:
	# Props take priority when sensor areas touch, so no nearby bell can mask an inspection.
	
	# 2. Mirror inspection
	if _sensor_overlaps("Mirror"):
		if current_anomaly == "driver_mirror":
			_say("驾驶座后视镜", "镜中的脸没有五官。那个人影倒悬在镜里。")
		elif current_anomaly == "driver_neck_twist":
			_say("驾驶座方向", "司机身子还直挺挺地扶着方向盘，头颅却以不可能的角度整整拧转了一百八十度，正死死盯着整条过道望向我！", "陈大文")
		else:
			_say("驾驶座后视镜", "镜里那张脸正望着桥面，跟刚上车时一样。")
		return
	
	# 3. Coinbox inspection
	if _sensor_overlaps("Coinbox"):
		if current_anomaly == "blood_coinbox":
			_say("前门投币箱", "血从投币口冒出来，一滴一滴落在脚边。")
		else:
			_say("前门投币箱", "投币口里有几枚硬币。感应屏还亮着绿灯。")
		return
	
	# 4. Seated passenger inspection
	if _sensor_overlaps("Mannequin"):
		if current_anomaly == "mannequin_turn" or mannequin_triggered:
			_say("靠窗的乘客", "那人扭着头看我，窗里的倒影却还望着前方。")
		else:
			_say("靠窗的乘客", "他低着头，双手搭在膝上。窗里也一样。")
		return
	
	# 5. LED board inspection
	if _sensor_overlaps("StopScreen"):
		if current_anomaly == "stop_screen":
			AudioManager.play_bus_pa("bus_anomaly_pa", -2.5)
			_say("电子报站屏", "下一站，枉死坡。33 路什么时候有过这一站？")
		else:
			AudioManager.play_bus_pa("bus_normal_pa", -2.5)
			_say("电子报站屏", "下一站，黑沙海滩。")
		return

	# 6. Side glass inspection
	if _sensor_overlaps("SideGlass"):
		if current_anomaly == "window_hands" and hands_sprite.visible:
			_say("巴士侧窗", "两只泡白的手还贴在玻璃外面。水正顺着指缝往下淌。")
		elif current_anomaly == "window_hands":
			_say("巴士侧窗", "窗外只有漆黑的海面和浓雾，但窗沿隐约渗出一股刺鼻的溺水海腥味……", "陈大文")
		elif current_anomaly == "window_fog_writing":
			_say("巴士侧窗", "冰冷的雨雾蒙满玻璃，有人用湿淋淋的手指划出了清晰的四个字——「不要下车」，水痕正顺着笔画往下滴落！", "陈大文")
		elif current_anomaly == "fog_runner":
			_say("巴士侧窗", "友谊大桥外浓雾滚滚，一道泡得惨白的长发身影竟然与飞驰的巴士保持同等速度，死死贴在车窗外并排狂奔！", "陈大文")
		else:
			_say("巴士侧窗", "透过侧窗只能看见友谊大桥两侧昏黄的灯柱在浓雾里倒退，外面一片死寂。", "陈大文")
		return

	if current_anomaly == "aisle_blood_seep" and _sensor_overlaps("AisleFloor"):
		_say("中段过道地胶", "车厢过道接缝里不知何时渗出一大摊暗红血渍，鞋底踩过发出湿冷的粘腻声——刚才绝对没有这滩血！", "陈大文")
		return
	if current_anomaly == "aisle_wet_footprints" and _sensor_overlaps("AisleFloor"):
		_say("中段过道地胶", "空荡荡的过道中央，一串沾满湿黑沙的鞋印正无声地一步接一步浮现出来，脚尖全都冲着我的方向走近……", "陈大文")
		return
	if current_anomaly == "ceiling_shadow" and _sensor_overlaps("CeilingRail"):
		_say("车顶行李架", "手电光无意间扫到车顶——行李架阴暗的夹缝里竟贴着一道僵直的人影，几缕湿发垂在扶手上方轻轻晃动！", "陈大文")
		return
	if current_anomaly == "hanging_straps" and _sensor_overlaps("CeilingRail"):
		_say("车顶扶手吊环", "车厢行驶平稳，所有扶手吊环却像是被看不见的狂风或手臂拉扯，整排僵直地斜向车尾纹丝不动！", "陈大文")
		return
	if current_anomaly == "empty_seat_shoes" and _sensor_overlaps("RearSeat"):
		_say("后排空座下方", "座位上明明空无一人，椅子底下却静静摆着一双灌满黑沙与海水的湿鞋，脚尖正对着过道……", "陈大文")
		return
	
	# 7. Front door
	if _sensor_overlaps("FrontDoor"):
		resolve_judgment("front_door")
		return
	if _sensor_overlaps("RearDoor"):
		resolve_judgment("rear_door")
		return
	for index in range(bell_sensors.size()):
		if _sensor_overlaps(bell_sensors[index].name):
			if not bell_pulled:
				_animate_bell(bell_visuals[index])
			resolve_judgment("bell_cord")
			return

func _animate_bell(bell: Sprite2D) -> void:
	bell_motion = create_tween()
	bell_motion.tween_property(bell, "rotation", -0.19, 0.09)
	bell_motion.tween_property(bell, "rotation", 0.11, 0.10)
	bell_motion.tween_property(bell, "rotation", 0.0, 0.15)

func resolve_judgment(action: String) -> void:
	if is_transitioning or in_cinematic:
		return
	if action == "bell_cord":
		if not bell_pulled:
			bell_pulled = true
			_store_cycle()
			_play_sfx("res://assets/audio/demo/bus_bell_chime.wav")
			hud.show_resource_feedback("铃响了，后门可以打开。")
		return
	if action == "rear_door" and not bell_pulled:
		hud.show_resource_feedback("后门锁着。看见异象时，先拉停车铃。")
		return
	
	is_transitioning = true
	hud.prompt.text = ""
	hud.state_text.text = ""
	var has_anomaly := not current_anomaly.is_empty()
	var is_correct := false
	
	if action == "front_door":
		# Walk through front door -> Player judges NORMAL
		is_correct = not has_anomaly
	elif action == "rear_door":
		# Exit rear or pull bell cord -> Player judges ANOMALY
		is_correct = has_anomaly
	
	if is_correct:
		_on_judgment_correct(action)
	else:
		_on_judgment_wrong()

func _on_judgment_correct(action: String) -> void:
	player.controls_enabled = false
	player.clear_motion()
	var door := formal_front_door if action == "front_door" else formal_rear_door
	if is_instance_valid(door): door.set_open(true)
	success_counter += 1
	next_cycle_pending = true
	_store_cycle()
	_update_hud_status()
	
	if success_counter >= TARGET_SUCCESSES:
		_trigger_hac_sa_crash()
	else:
		_fade_to_next_cycle()

func _on_judgment_wrong() -> void:
	success_counter = 0
	next_cycle_pending = true
	_store_cycle()
	_update_hud_status()
	_trigger_screamer()

func _show_wrong_judgment(show_location := true) -> void:
	var title := "误报异常" if current_anomaly.is_empty() else "漏看异象"
	if show_location and ANOMALY_LOCATIONS.has(current_anomaly):
		var generation := cycle_generation
		var subject: Area2D = interaction_sensors[ANOMALY_LOCATIONS[current_anomaly]]
		camera.position.x = subject.position.x - player.position.x
		camera.reset_smoothing()
		camera.force_update_scroll()
		if current_anomaly == "mannequin_turn" and not mannequin_triggered:
			mannequin_sprite.turn()
		elif current_anomaly == "window_hands" and not hands_triggered:
			hands_sprite.position = Vector2(460, 88)
			hands_sprite.scale = Vector2.ONE * 0.15
			hands_sprite.show()
			hands_sprite.play("slap")
		elif current_anomaly == "rear_door_peeker" and is_instance_valid(rear_peeker_node):
			peeker_rise = 1.0
			rear_peeker_node.modulate.a = 1.0
			rear_peeker_node.show()
			if is_instance_valid(rear_peeker_canvas):
				rear_peeker_canvas.queue_redraw()
		elif current_anomaly == "aisle_wet_footprints" and is_instance_valid(aisle_footprints_node):
			aisle_footprints_node.show()
			for fp in aisle_footprint_sprites:
				if is_instance_valid(fp):
					fp.modulate.a = 0.90
			aisle_footprints_node.queue_redraw()
		await get_tree().create_timer(0.43, false).timeout
		if not is_inside_tree() or generation != cycle_generation:
			return
	var reason: String = MISSED_ANOMALIES.get(current_anomaly, "刚才五处参照都没有变化。正常车厢应从前门下车。")
	_say(title, reason + "\n车又回到了起点。连对次数归零。", "陈大文", _start_new_cycle.bind(false))

func _trigger_screamer() -> void:
	glitch_timer = 1.35
	shake_intensity = 3.0
	player.controls_enabled = false
	player.clear_motion()
	if is_instance_valid(lunge_rig): lunge_rig.queue_free()
	lunge_rig = preload("res://ui/bus_lunge_rig.gd").new()
	glitch_overlay.add_child(lunge_rig)
	lunge_rig.finished.connect(func():
		lunge_rig.queue_free()
		_show_wrong_judgment()
	)

func _hide_jumpscare_after(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree(): return
	if is_instance_valid(jumpscare_sprite):
		jumpscare_sprite.stop()
		jumpscare_sprite.visible = false

func _fade_to_next_cycle() -> void:
	var generation := cycle_generation
	# Walk player visibly toward the open exit door + bold centered counter popup "突围进度 · X / 5"
	if is_instance_valid(player) and DisplayServer.get_name() != "headless":
		var banner_layer := CanvasLayer.new()
		banner_layer.layer = 60
		add_child(banner_layer)
		var veil := ColorRect.new()
		veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		veil.color = Color(0.02, 0.03, 0.03, 0.0)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banner_layer.add_child(veil)
		var counter := Label.new()
		var font := UiFont.title()
		counter.add_theme_font_override("font", font)
		counter.add_theme_font_size_override("font_size", 32)
		counter.add_theme_color_override("font_color", Color("f2db99"))
		counter.text = "突围进度  ·  %d / %d" % [success_counter, TARGET_SUCCESSES]
		counter.position = Vector2(0, 152)
		counter.size = Vector2(640, 48)
		counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		counter.modulate.a = 0.0
		banner_layer.add_child(counter)
		var tw := banner_layer.create_tween()
		tw.tween_property(veil, "color:a", 0.88, 0.35)
		tw.parallel().tween_property(counter, "modulate:a", 1.0, 0.28)
		tw.tween_interval(0.45)
		tw.tween_property(veil, "color:a", 0.0, 0.32)
		tw.parallel().tween_property(counter, "modulate:a", 0.0, 0.28)
		tw.tween_callback(banner_layer.queue_free)
	await get_tree().create_timer(1.2, false).timeout
	if not is_inside_tree() or in_cinematic or generation != cycle_generation:
		return
	_start_new_cycle(false)

func _start_new_cycle(is_initial: bool) -> void:
	next_cycle_pending = false
	cycle_generation += 1
	cycle_index += 1
	for door in [formal_front_door, formal_rear_door]:
		if is_instance_valid(door): door.set_open(false, false)
	if is_instance_valid(bell_motion):
		bell_motion.kill()
	for bell in bell_visuals:
		bell.rotation = 0.0
	bell_pulled = false
	mannequin_triggered = false
	hands_triggered = false
	
	if is_initial:
		seen_anomalies.clear()
		current_anomaly = ""
	elif not current_anomaly.is_empty() and randf() < 0.36:
		current_anomaly = ""
	else:
		var candidates: Array = []
		for a in ANOMALIES:
			if a not in seen_anomalies and a != current_anomaly:
				candidates.append(a)
		if candidates.is_empty():
			seen_anomalies.clear()
			candidates = ANOMALIES.duplicate()
			candidates.erase(current_anomaly)
		current_anomaly = candidates.pick_random()
		seen_anomalies.append(current_anomaly)
	
	_apply_anomaly_visuals()
	
	# Reset player position to rear of bus
	if is_instance_valid(player):
		player.position = Vector2(240, 283)
		player.reset_physics_interpolation()
		camera.position = Vector2.ZERO
		camera.reset_smoothing()
	
	is_transitioning = false
	player.controls_enabled = true
	_store_cycle()
	_update_hud_status()

func _store_cycle() -> void:
	GameState.bus_loop_state = {
		"successes": success_counter,
		"anomaly": current_anomaly,
		"cycle": cycle_index,
		"bell_pulled": bell_pulled,
		"initialized": true,
		"next_cycle_pending": next_cycle_pending,
		"seen_anomalies": seen_anomalies.duplicate(),
	}
	if not GameState.save_opening_checkpoint() and is_instance_valid(hud):
		hud.show_resource_feedback("巴士进度保存失败，当前仍可继续。请检查存储空间后重试。")

func _apply_anomaly_visuals() -> void:
	if not current_anomaly.is_empty() and current_anomaly not in ANOMALIES and not is_instance_valid(aisle_blood_node):
		_setup_legacy_anomaly_props()
	# Reset all props to normal first (NEVER call restart() after emitting=false — restart() turns emitting ON!)
	mirror_sprite.texture = mirror_normal_texture
	coinbox_sprite.texture = coinbox_normal_texture
	blood_particles.emitting = false
	blood_particles.visible = false
	shake_intensity = 0.0
	glitch_timer = 0.0
	sound_caption_time = 0.0
	mannequin_sprite.reset_pose()
	hands_sprite.visible = false
	hands_sprite.stop()
	hands_sprite.animation = "slap"
	hands_sprite.frame = 0
	hands_sprite.position = Vector2(460, 88)
	hands_sprite.scale = Vector2(0.15, 0.15)
	if is_instance_valid(aisle_blood_node): aisle_blood_node.visible = false
	if is_instance_valid(ceiling_crawler_node): ceiling_crawler_node.visible = false
	if is_instance_valid(rear_shoes_node): rear_shoes_node.visible = false
	if is_instance_valid(fog_runner_node): fog_runner_node.visible = false
	if is_instance_valid(straps_anomaly_node): straps_anomaly_node.visible = false
	anomaly_anim_time = 0.0
	peeker_rise = 0.32
	peeker_eye_x = 0.0
	driver_twitch_x = 0.0
	driver_twitch_rot = 0.0
	if is_instance_valid(rear_peeker_node):
		rear_peeker_node.visible = false
		rear_peeker_node.modulate.a = 1.0
	if is_instance_valid(fog_writing_node):
		fog_writing_node.visible = false
	if is_instance_valid(driver_twist_node):
		driver_twist_node.visible = false
	if is_instance_valid(aisle_footprints_node):
		aisle_footprints_node.visible = false
		for fp in aisle_footprint_sprites:
			if is_instance_valid(fp):
				fp.modulate.a = 0.0
	
	# Apply specific anomaly
	match current_anomaly:
		"driver_mirror":
			mirror_sprite.texture = mirror_anomaly_texture
		"blood_coinbox":
			coinbox_sprite.texture = coinbox_anomaly_texture
			blood_particles.visible = true
			blood_particles.restart()
			blood_particles.emitting = true
			_play_sfx("res://assets/audio/demo/blood_boil.wav")
		"stop_screen":
			_play_stinger("res://assets/audio/demo/power_failure_026.wav")
		"mannequin_turn":
			# Will trigger when player passes
			pass
		"window_hands":
			# Will trigger when player passes
			pass
		"aisle_blood_seep":
			if is_instance_valid(aisle_blood_node): aisle_blood_node.visible = true
			_play_sfx("res://assets/audio/demo/blood_boil.wav")
		"ceiling_shadow":
			if is_instance_valid(ceiling_crawler_node): ceiling_crawler_node.visible = true
			_play_stinger("res://assets/audio/demo/scare_whisper_ear.wav")
		"empty_seat_shoes":
			if is_instance_valid(rear_shoes_node): rear_shoes_node.visible = true
		"fog_runner":
			if is_instance_valid(fog_runner_node): fog_runner_node.visible = true
			_play_stinger("res://assets/audio/demo/ghost_taunt_whisper.wav")
		"hanging_straps":
			if is_instance_valid(straps_anomaly_node): straps_anomaly_node.visible = true
			_play_stinger("res://assets/audio/demo/scare_pipe_scrape.wav")
		"rear_door_peeker":
			if is_instance_valid(rear_peeker_node):
				rear_peeker_node.visible = true
				if is_instance_valid(rear_peeker_canvas):
					rear_peeker_canvas.queue_redraw()
			_play_stinger("res://assets/audio/demo/scare_whisper_ear.wav")
		"window_fog_writing":
			if is_instance_valid(fog_writing_node):
				fog_writing_node.visible = true
				if is_instance_valid(fog_writing_canvas):
					fog_writing_canvas.queue_redraw()
			_play_sfx("res://assets/audio/demo/oil_drops_026.wav")
		"driver_neck_twist":
			if is_instance_valid(driver_twist_node):
				driver_twist_node.visible = true
				driver_twist_node.queue_redraw()
			_play_stinger("res://assets/audio/demo/mannequin_snap.wav")
		"aisle_wet_footprints":
			if is_instance_valid(aisle_footprints_node):
				aisle_footprints_node.visible = true
				for idx in range(mini(2, aisle_footprint_sprites.size())):
					if is_instance_valid(aisle_footprint_sprites[idx]):
						aisle_footprint_sprites[idx].modulate.a = 0.55
				aisle_footprints_node.queue_redraw()
			_play_sfx("res://assets/audio/demo/scare_extra_step.wav")
	
	_refresh_broadcast_display()

func _trigger_hac_sa_crash() -> void:
	crash_generation += 1
	var generation := crash_generation
	GameState.opening_flags.bus_arrived = true
	_store_cycle()
	in_cinematic = true
	is_transitioning = true
	
	if is_instance_valid(player):
		player.clear_motion()
		player.controls_enabled = false
	
	shake_intensity = 24.0
	_play_stinger("res://assets/audio/demo/bus_crash_cinematic.wav")
	
	crash_curtain = ColorRect.new()
	crash_curtain.color = Color.BLACK
	crash_curtain.modulate.a = 0.0
	crash_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crash_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glitch_overlay.add_child(crash_curtain)
	crash_motion = create_tween()
	crash_motion.tween_property(camera, "rotation", -0.045, 0.22).set_trans(Tween.TRANS_SINE)
	crash_motion.tween_property(camera, "rotation", 0.16, 0.28).set_trans(Tween.TRANS_CUBIC)
	crash_motion.parallel().tween_property(player, "rotation", -0.18, 0.28)
	crash_motion.tween_property(camera, "rotation", 0.65, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	crash_motion.parallel().tween_property(player, "rotation", -0.70, 0.38)
	crash_motion.parallel().tween_property(crash_curtain, "modulate:a", 1.0, 0.34)
	crash_motion.tween_interval(0.34)
	crash_motion.tween_callback(func():
		camera.rotation = 0.0
		player.rotation = 0.0
		crash_view = TextureRect.new()
		crash_view.texture = preload("res://assets/props/bus_crash_beach.png")
		crash_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		crash_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		crash_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.root.add_child(crash_view)
		crash_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hud.root.move_child(crash_view, 0)
	)
	crash_motion.tween_property(crash_curtain, "modulate:a", 0.0, 0.40)
	
	await crash_motion.finished
	if not is_inside_tree() or generation != crash_generation or not in_cinematic:
		return
	
	_say(
		"第四章 · 诡夜末班",
		"车停了。桥不见了，裂开的挡风玻璃外是一片黑沙。\n嘉敏提过这里。出去找找她有没有留下记号。"
	)
	hud.apply_ending_letterbox_layout()
	hud.modal.position.y -= 7.0
	hud.page_hint.hide()

func _update_hud_status() -> void:
	if is_instance_valid(hud):
		hud.objective.text = "连续正确  %d/%d    ·    [ J ] 后门告示" % [success_counter, TARGET_SUCCESSES]

func _play_sfx(path: String) -> void:
	if AudioManager.silent_run:
		return
	var stream = load(path)
	if stream != null and is_instance_valid(sfx_player):
		sfx_player.stream = stream
		sfx_player.play()

func _play_stinger(path: String) -> void:
	if AudioManager.silent_run:
		return
	var stream = load(path)
	if stream != null and is_instance_valid(stinger_player):
		stinger_player.stream = stream
		stinger_player.play()

func _say(title: String, body: String, speaker := "陈大文", next := Callable(), photo_tex: Texture2D = null) -> void:
	if is_instance_valid(player):
		player.clear_motion()
		player.controls_enabled = false
	after_panel = next
	
	var choices: Array = []
	if in_cinematic and success_counter >= TARGET_SUCCESSES:
		choices = [
			{"text": "前往黑沙海滩", "callback": _on_cinematic_proceed},
			{"text": "重新挑战本章循环", "callback": _restart_loop}
		]
	
	hud.open_panel(title, body, choices, photo_tex != null, speaker, null, photo_tex)
	get_tree().paused = true

func _on_cinematic_proceed() -> void:
	AudioManager.stop_bus_pa()
	AudioManager.stop_voice()
	get_tree().paused = false
	hud.close_panel()
	if GameState.request_room_change("ch5_hacsa_beach", "from_bus_crash"):
		GameState.save_transition_checkpoint()
	else:
		_say("暂时无法进入黑沙", "车门外的路线暂时无法载入。当前仍在巴士结算画面，请稍后重试。")

func _restart_loop() -> void:
	AudioManager.stop_bus_pa()
	AudioManager.stop_voice()
	pause_panel_active = false
	crash_generation += 1
	if is_instance_valid(crash_motion):
		crash_motion.kill()
		crash_motion = null
	if is_instance_valid(crash_curtain):
		crash_curtain.queue_free()
		crash_curtain = null
	if is_instance_valid(crash_view):
		crash_view.queue_free()
		crash_view = null
	if is_instance_valid(camera):
		camera.rotation = 0.0
		camera.offset = Vector2.ZERO
	if is_instance_valid(player): player.rotation = 0.0
	shake_intensity = 0.0
	glitch_timer = 0.0
	if is_instance_valid(glitch_rect):
		glitch_rect.color.a = 0.0
		glitch_rect.position = Vector2.ZERO
	if is_instance_valid(jumpscare_sprite):
		jumpscare_sprite.stop()
		jumpscare_sprite.hide()
	if is_instance_valid(stinger_player): stinger_player.stop()
	if is_instance_valid(lunge_rig): lunge_rig.queue_free()
	GameState.opening_flags.bus_arrived = false
	get_tree().paused = false
	hud.close_panel()
	in_cinematic = false
	success_counter = 0
	if is_instance_valid(player):
		player.controls_enabled = true
	_start_new_cycle(true)

func _on_hud_close() -> void:
	if pause_panel_active:
		pause_panel_active = false
		hud.close_panel()
		get_tree().paused = false
		if is_instance_valid(player):
			player.controls_enabled = not in_cinematic and not is_transitioning
			player.clear_motion()
		return
	if in_cinematic and success_counter >= TARGET_SUCCESSES:
		return
	hud.close_panel()
	if is_instance_valid(player):
		player.controls_enabled = not in_cinematic and not is_transitioning
		player.clear_motion()
	get_tree().paused = false
	var next := after_panel
	after_panel = Callable()
	if next.is_valid():
		next.call()

func _on_hud_pause(message := "") -> void:
	pause_panel_active = true
	if is_instance_valid(player):
		player.clear_motion()
		player.controls_enabled = false
	var status := "友谊大桥 · 33 路末班车\n连续正确 %d/%d" % [success_counter, TARGET_SUCCESSES]
	if not message.is_empty():
		status += "\n" + message
	var title := "暂停" if message.is_empty() else "暂时无法返回标题"
	hud.open_panel(title, status, [
		{"text": "继续", "callback": _on_hud_close},
		{"text": "重新开始本章", "callback": _restart_loop},
		{"text": "保存进度并返回标题", "callback": _return_to_title}
	])
	get_tree().paused = true

func _return_to_title() -> void:
	if not GameState.save_opening_checkpoint():
		_on_hud_pause("暂时无法保存。请检查存储空间后重试。")
		return
	var tree := get_tree()
	if tree.change_scene_to_file("res://ui/main_menu.tscn") == OK:
		tree.paused = false
	else:
		_on_hud_pause("标题暂时无法载入，请重试。")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud) and is_instance_valid(player) and not hud.panel_open and not get_tree().paused:
		_on_hud_pause()

# ========================================================
# Test & Autobot Support APIs
# ========================================================
func force_cycle(anomaly_name: String) -> void:
	cycle_generation += 1
	camera.position = Vector2.ZERO
	camera.reset_smoothing()
	bell_pulled = false
	current_anomaly = anomaly_name
	mannequin_triggered = false
	hands_triggered = false
	is_transitioning = false
	if is_instance_valid(player):
		player.position = Vector2(240, 283)
		player.reset_physics_interpolation()
	_apply_anomaly_visuals()

func trigger_action(action_name: String) -> void:
	resolve_judgment(action_name)

func get_success_counter() -> int:
	return success_counter

func get_current_anomaly() -> String:
	return current_anomaly

func _exit_tree() -> void:
	AudioManager.stop_bus_pa()
	AudioManager.stop_voice()
	for audio in [bgm_player, sfx_player, stinger_player]:
		if is_instance_valid(audio):
			audio.stop()
			audio.stream = null
