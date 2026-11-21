extends Node2D

const ANOMALIES := [
	"driver_mirror",
	"blood_coinbox",
	"stop_screen",
	"mannequin_turn",
	"window_hands"
]

const NORMAL_BROADCASTS := [
	"下一站：黑沙海滩（临时终点站）",
	"Próxima paragem: Praia de Hác-Sá (Terminal Provisório)",
	"下一站：黑沙海滩（临时终点站）",
	"Next stop: Hac Sa Beach (Temporary Terminal)"
]

const ANOMALY_BROADCASTS := [
	"下一站：枉死坡……（此站不停车）",
	"Próxima paragem: Encosta da Morte Injusta",
	"下一站：枉死坡……（此站不停车）",
	"Next stop: Wrong Death Slope (Do not alight)"
]
const REAR_DOOR_NOTICE := "如见异状，先拉停车铃，再从后门折返。无异状，从前门下车。连续五次，方可抵达。\n\n正常车厢的五处参照\n后视镜：司机面朝前方，倒影保持正向。\n投币箱：金属表面干净，感应屏亮绿灯。\n报站屏：下一站是黑沙海滩。\n靠窗乘客：低头坐着，倒影与动作一致。\n侧窗：只见桥灯、雾和反光。"
const MISSED_ANOMALIES := {
	"driver_mirror": "司机在后视镜里没有五官，倒影倒悬在车顶。",
	"blood_coinbox": "前门投币箱的缝隙正在渗血。",
	"stop_screen": "报站屏把黑沙海滩换成了「枉死坡」。",
	"mannequin_turn": "靠窗乘客把颈部转向过道，倒影没有跟着变。",
	"window_hands": "车行过道中段时，有惨白的手拍上侧窗。"
}
const ANOMALY_LOCATIONS := {
	"driver_mirror": "Mirror",
	"blood_coinbox": "Coinbox",
	"stop_screen": "StopScreen",
	"mannequin_turn": "Mannequin",
	"window_hands": "SideGlass"
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
var crash_motion: Tween
var crash_generation := 0

var broadcast_index: int = 0
var broadcast_timer: float = 0.0

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
var chime_player: AudioStreamPlayer

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
		success_counter = int(GameState.bus_loop_state.successes)
		cycle_index = int(GameState.bus_loop_state.cycle)
		current_anomaly = GameState.bus_loop_state.anomaly
		bell_pulled = GameState.bus_loop_state.bell_pulled
		next_cycle_pending = GameState.bus_loop_state.get("next_cycle_pending", false)
		_apply_anomaly_visuals()
		_update_hud_status()
		if success_counter == 5: call_deferred("_trigger_hac_sa_crash")
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
	_say("33 路末班车", "嘉敏说坐 33 路去路环报警。明明过了末班点，这辆车却还亮着惨绿的灯……想起手札里写的「33 路后排无声乘客与跨海雾桥白衣影」，背脊一阵发凉。\n\n先走一遍车厢记住正常的样子。见异象就拉红铃走后门，无异象走前门。按 J 可看车尾示意图。", "陈大文")

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
	AudioManager.set_scene_ambience("")
	
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Ambience"
	bgm_player.volume_db = -3.0
	var bgm_stream = load("res://assets/audio/demo/bridge_bus_ambience.wav")
	add_child(bgm_player)
	if bgm_stream != null:
		if bgm_stream is AudioStreamWAV:
			bgm_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		bgm_player.stream = bgm_stream
		if not AudioManager.silent_run:
			bgm_player.play()
	
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "SFX"
	add_child(sfx_player)
	
	stinger_player = AudioStreamPlayer.new()
	stinger_player.bus = "SFX"
	add_child(stinger_player)
	
	chime_player = AudioStreamPlayer.new()
	chime_player.bus = "SFX"
	var chime_stream = load("res://assets/audio/demo/bus_bell_chime.wav")
	if chime_stream != null:
		chime_player.stream = chime_stream
	add_child(chime_player)

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
	coinbox_normal_texture = _atlas_cell(bus_props_sheet, 0, 1)
	coinbox_anomaly_texture = _atlas_cell(bus_props_sheet, 1, 1)

	# Rearview mirror: matched to the driver's ceiling position and scale.
	mirror_sprite = Sprite2D.new()
	mirror_sprite.texture = mirror_normal_texture
	mirror_sprite.position = Vector2(1030, 174)
	mirror_sprite.scale = Vector2(0.10, 0.10)
	mirror_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mirror_sprite.z_index = 8
	add_child(mirror_sprite)
	
	# Coin box stands beside the front door; its collider is added with the bus geometry.
	coinbox_sprite = Sprite2D.new()
	coinbox_sprite.texture = coinbox_normal_texture
	coinbox_sprite.position = Vector2(1080, 232)
	coinbox_sprite.scale = Vector2(0.10, 0.10)
	coinbox_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	coinbox_sprite.z_index = 10
	add_child(coinbox_sprite)
	
	# Boiling blood particles for coin box
	blood_particles = CPUParticles2D.new()
	blood_particles.position = coinbox_sprite.position + Vector2(0, -10)
	blood_particles.amount = 24
	blood_particles.lifetime = 1.2
	blood_particles.direction = Vector2(0, -1)
	blood_particles.spread = 45.0
	blood_particles.gravity = Vector2(0, 98)
	blood_particles.initial_velocity_min = 25.0
	blood_particles.initial_velocity_max = 55.0
	blood_particles.color = Color(0.85, 0.08, 0.08, 0.95)
	blood_particles.scale_amount_min = 2.0
	blood_particles.scale_amount_max = 4.5
	blood_particles.emitting = false
	blood_particles.z_index = 11
	add_child(blood_particles)
	
	# Same passenger identity as the continuous close-up lunge.
	mannequin_sprite = preload("res://entities/bus_seated_passenger.gd").new()
	mannequin_sprite.position = Vector2(620, 251)
	mannequin_sprite.scale = Vector2.ONE * 0.72
	mannequin_sprite.z_index = 9
	add_child(mannequin_sprite)

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
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["SimSun", "Noto Serif CJK SC"])
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
	_add_interaction_sensor("Coinbox", Vector2(1080, 250), 24.0)
	_add_interaction_sensor("Mannequin", Vector2(620, 251), 27.0)
	_add_interaction_sensor("SideGlass", Vector2(460, 254), 27.0)
	_add_interaction_sensor("StopScreen", Vector2(910, 250), 24.0)
	_add_interaction_sensor("FrontDoor", Vector2(FRONT_DOOR_X, 281), 28.0)
	_add_interaction_sensor("RearDoor", Vector2(REAR_DOOR_X, 281), 34.0)

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
	_update_broadcast(delta)
	_update_glitch(delta)
	_update_camera_shake(delta)
	_check_player_triggers()
	_update_interaction_prompts()

func _update_broadcast(delta: float) -> void:
	broadcast_timer += delta
	if broadcast_timer >= 3.5:
		broadcast_timer = 0.0
		broadcast_index = (broadcast_index + 1) % 4
		_refresh_broadcast_display()
		if not AudioManager.silent_run and is_instance_valid(chime_player) and not is_transitioning and not in_cinematic:
			chime_player.play()

func _refresh_broadcast_display() -> void:
	var list: Array = ANOMALY_BROADCASTS if current_anomaly == "stop_screen" else NORMAL_BROADCASTS
	var text: String = list[broadcast_index]
	
	if current_anomaly == "stop_screen":
		led_label.text = "⚠ " + text + " ⚠"
		led_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15, 1.0))
		var flicker := GameState.reduced_flash or randf() > 0.3
		led_panel.visible = flicker
	else:
		led_label.text = "[33] " + text
		led_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.45, 1.0))
		led_panel.visible = true
	
	if is_instance_valid(hud) and not hud.panel_open:
		hud.state_text.text = "[车载报站] " + text

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
			_flash_schoolgirl_reflection(Vector2(695, 92))
		hud.notify("车顶灯管咔嚓闪灭了一瞬——靠窗乘客的脖子折向过道死死盯住你，玻璃倒影却一动不动！")
	
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
		if not GameState.reduced_flash:
			_flash_schoolgirl_reflection(Vector2(495, 92))
		hud.notify("车窗外突然贴上两只泡得发白的手！五指一节节弯曲，接着猛地拍向玻璃！")

func _flash_schoolgirl_reflection(at: Vector2) -> void:
	# 2004 33路校服女鬼暗窗倒影闪现（不阻挡碰撞与交互）
	var ghost := Node2D.new()
	ghost.position = at
	ghost.z_index = 11
	add_child(ghost)
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([Vector2(-9, -22), Vector2(9, -22), Vector2(11, -5), Vector2(0, 1), Vector2(-11, -5)])
	head.color = Color(0.86, 0.92, 0.94, 0.42)
	ghost.add_child(head)
	var hair := Polygon2D.new()
	hair.polygon = PackedVector2Array([Vector2(-12, -25), Vector2(12, -25), Vector2(14, 14), Vector2(8, 14), Vector2(8, -14), Vector2(-8, -14), Vector2(-8, 14), Vector2(-14, 14)])
	hair.color = Color(0.04, 0.06, 0.08, 0.56)
	ghost.add_child(hair)
	var collar := Polygon2D.new()
	collar.polygon = PackedVector2Array([Vector2(-15, 2), Vector2(15, 2), Vector2(20, 26), Vector2(-20, 26)])
	collar.color = Color(0.76, 0.84, 0.90, 0.36)
	ghost.add_child(collar)
	for ex in [-4.0, 4.0]:
		var eye := Polygon2D.new()
		eye.polygon = PackedVector2Array([Vector2(ex - 2.0, -13), Vector2(ex + 2.0, -13), Vector2(ex + 2.0, -10), Vector2(ex - 2.0, -10)])
		eye.color = Color(0.05, 0.05, 0.08, 0.82)
		ghost.add_child(eye)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.95, 0.07)
	tw.tween_interval(0.32)
	tw.tween_property(ghost, "modulate:a", 0.0, 0.42)
	tw.tween_callback(ghost.queue_free)
	
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
			_say("驾驶座后视镜", "后视镜里……司机的脸孔平滑一片，没有任何五官！倒影里的人影竟然倒悬在车顶上，正无声地晃荡着……", "陈大文")
		else:
			_say("驾驶座后视镜", "司机戴着新福利制服帽，双眼专注地盯着前方友谊大桥浓密的夜雾。", "陈大文")
		return
	
	# 3. Coinbox inspection
	if _sensor_overlaps("Coinbox"):
		if current_anomaly == "blood_coinbox":
			_say("前门投币箱", "投币箱的缝隙里不断翻涌出温热粘稠的鲜血……汩汩冒泡，已经浸透了整个地面！", "陈大文")
		else:
			_say("前门投币箱", "不锈钢投币箱里躺着几枚六元澳门币硬币，第一代澳门通感应屏亮着正常的绿光。", "陈大文")
		return
	
	# 4. Seated passenger inspection
	if _sensor_overlaps("Mannequin"):
		if current_anomaly == "mannequin_turn" or mannequin_triggered:
			_say("靠窗的乘客", "身体明明还朝前坐着，脖子却折出不可能的角度死死盯向过道！车窗玻璃里的倒影却还是低头不动，跟 2004 年末班车鬼影传闻一模一样！", "陈大文")
		else:
			_say("靠窗的乘客", "靠窗乘客低头坐着，车身随大桥海风颠簸，车窗玻璃里的倒影动作与他完全一致。", "陈大文")
		return
	
	# 5. LED board inspection
	if _sensor_overlaps("StopScreen"):
		if current_anomaly == "stop_screen":
			_say("电子报站屏", "报站屏不断闪烁着刺目的血红大字：『下一站：枉死坡』……33 路根本没有这一站！", "陈大文")
		else:
			_say("电子报站屏", "绿色点阵屏滚动显示着中葡双语：『下一站：黑沙海滩（临时终点站） / Praia de Hác-Sá』。", "陈大文")
		return

	# 6. Side glass inspection
	if _sensor_overlaps("SideGlass"):
		if current_anomaly == "window_hands" and hands_sprite.visible:
			_say("巴士侧窗", "就像路氹公路招手女鬼的传闻一样——雾外突然扑上两只泡得惨白的手印，黑海水正顺着玻璃往下淌！", "陈大文")
		elif current_anomaly == "window_hands":
			_say("巴士侧窗", "窗外只有漆黑的海面和浓雾，但窗沿隐约渗出一股刺鼻的溺水海腥味……", "陈大文")
		else:
			_say("巴士侧窗", "透过侧窗只能看见友谊大桥两侧昏黄的灯柱在浓雾里倒退，外面一片死寂。", "陈大文")
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
		await get_tree().create_timer(0.43, false).timeout
		if not is_inside_tree() or generation != cycle_generation:
			return
	var reason: String = MISSED_ANOMALIES.get(current_anomaly, "刚才五处参照都没有变化。正常车厢应从前门下车。")
	_say(title, reason + "\n连对次数归零。", "陈大文", _start_new_cycle.bind(false))

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
	
	if is_initial or randf() < 0.45:
		current_anomaly = ""
	else:
		var candidates: Array = ANOMALIES.duplicate()
		candidates.erase(current_anomaly)
		current_anomaly = candidates.pick_random()
	
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
	GameState.bus_loop_state = {"successes":success_counter, "anomaly":current_anomaly, "cycle":cycle_index, "bell_pulled":bell_pulled, "initialized":true, "next_cycle_pending":next_cycle_pending}
	if not GameState.save_opening_checkpoint() and is_instance_valid(hud):
		hud.show_resource_feedback("巴士进度保存失败，当前仍可继续。请检查存储空间后重试。")

func _apply_anomaly_visuals() -> void:
	# Reset all props to normal first
	mirror_sprite.texture = mirror_normal_texture
	coinbox_sprite.texture = coinbox_normal_texture
	blood_particles.emitting = false
	blood_particles.restart()
	shake_intensity = 0.0
	glitch_timer = 0.0
	mannequin_sprite.reset_pose()
	hands_sprite.visible = false
	hands_sprite.stop()
	hands_sprite.animation = "slap"
	hands_sprite.frame = 0
	hands_sprite.position = Vector2(460, 88)
	hands_sprite.scale = Vector2(0.15, 0.15)
	
	# Apply specific anomaly
	match current_anomaly:
		"driver_mirror":
			mirror_sprite.texture = mirror_anomaly_texture
		"blood_coinbox":
			coinbox_sprite.texture = coinbox_anomaly_texture
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
	
	# The rendered carriage rolls with the camera before blackout; the crash
	# illustration afterward is supplementary evidence, not the whole action.
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
	)
	crash_motion.tween_property(crash_curtain, "modulate:a", 0.0, 0.40)
	
	hud.notify("【突破循环】巴士撞碎了友谊大桥上的浓雾幻象！")
	
	await crash_motion.finished
	if not is_inside_tree() or generation != crash_generation or not in_cinematic:
		return
	
	# Open cinematic panel with crash art
	var crash_art = load("res://assets/props/bus_crash_beach.png")
	_say(
		"第四章 · 诡夜末班 【突破循环】",
		"刺耳的急刹与金属爆裂声撕裂了友谊大桥无尽的雾海幻象！\n33路末班车冲破扭曲的护栏，在狂风中颠簸翻滚，最终重重砸落在冰冷潮湿的黑沙之中……\n\n海浪拍打着车厢残骸，大文推开变形的车门跌出车外——眼前是一望无际的深夜沙滩：路环黑沙海滩。\n嘉敏可能从这里经过。沙滩上的压痕、粉笔与沿海旧工事，需要逐一核对，不能只跟着哭声往海里走……",
		"陈大文",
		Callable(),
		crash_art
	)

func _update_hud_status() -> void:
	if is_instance_valid(hud):
		hud.objective.text = "友谊大桥 · 新福利33路 (循环: %d/%d) · [ J ] 查阅后门告示" % [success_counter, TARGET_SUCCESSES]

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
			{"text": "前往黑沙海滩 (进入第五章：黑沙溯潮)", "callback": _on_cinematic_proceed},
			{"text": "重新挑战本章循环", "callback": _restart_loop}
		]
	
	hud.open_panel(title, body, choices, photo_tex != null, speaker, null, photo_tex)
	get_tree().paused = true

func _on_cinematic_proceed() -> void:
	get_tree().paused = false
	hud.close_panel()
	if GameState.request_room_change("ch5_hacsa_beach", "from_bus_crash"):
		GameState.save_transition_checkpoint()
	else:
		_say("暂时无法进入黑沙", "车门外的路线暂时无法载入。当前仍在巴士结算画面，请稍后重试。")

func _restart_loop() -> void:
	pause_panel_active = false
	crash_generation += 1
	if is_instance_valid(crash_motion):
		crash_motion.kill()
		crash_motion = null
	if is_instance_valid(crash_curtain):
		crash_curtain.queue_free()
		crash_curtain = null
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
		_on_cinematic_proceed()
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

func _on_hud_pause() -> void:
	pause_panel_active = true
	if is_instance_valid(player):
		player.clear_motion()
		player.controls_enabled = false
	hud.open_panel("暂停", "友谊大桥 · 新福利33路 (循环进度: %d/%d)" % [success_counter, TARGET_SUCCESSES], [
		{"text": "继续", "callback": _on_hud_close},
		{"text": "重新开始本章", "callback": _restart_loop},
		{"text": "退出游戏", "callback": func(): get_tree().quit()}
	])
	get_tree().paused = true

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
	for audio in [bgm_player, sfx_player, stinger_player, chime_player]:
		if is_instance_valid(audio):
			audio.stop()
			audio.stream = null
