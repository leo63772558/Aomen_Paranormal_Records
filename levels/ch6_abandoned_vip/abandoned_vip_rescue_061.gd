extends Node2D

const ROOM_ID := "ch6_abandoned_vip"
const WORLD_SIZE := Vector2(1280, 720)
const PLAYER_SCENE := preload("res://entities/player/player.tscn")
const SHADOW_SCRIPT := preload("res://entities/shadow_chaser.gd")
const PIPE_ACTION_SCRIPT := preload("res://levels/ch6_abandoned_vip/jiamin_pipe_action_086.gd")
const RESCUE_SUPPORT_SCRIPT := preload("res://levels/ch6_abandoned_vip/rescue_support_095.gd")
const RESCUE_HANDOFF_SCRIPT := preload("res://levels/ch6_abandoned_vip/rescue_camera_handoff_108.gd")
const RESCUE_DEPARTURE_SCRIPT := preload("res://levels/ch6_abandoned_vip/rescue_departure_108.gd")
const HATCH_SCRIPT := preload("res://levels/ch6_abandoned_vip/rescue_hatch_086.gd")
const ROUTE_PANEL := preload("res://ui/coastal_route_panel.gd")
const BRANCH_VISUAL_POS := {
	"branch_a": Vector2(520, 190),
	"branch_b": Vector2(518, 294),
	"branch_c": Vector2(530, 375)
}
const TARGETS := {
	"pipe_item": Vector2(224, 510),
	"jiamin_signal_pipe": Vector2(250, 248),
	"route_diagram": Vector2(742, 251),
	"branch_a": Vector2(390, 395),
	"branch_b": Vector2(460, 395),
	"branch_c": Vector2(530, 395),
	"electrical_cabinet": Vector2(855, 325),
	"venue_archive": Vector2(944, 258),
	"lure_switch": Vector2(1010, 380),
	"lock_lever": Vector2(936, 468),
	"rescue_door": Vector2(1180, 390),
	"return_arch": Vector2(640, 668)
}
const TARGET_NAMES := {
	"pipe_item": "拾取地上的短钢管",
	"jiamin_signal_pipe": "用钢管敲击检修管",
	"route_diagram": "查看三路管线图与粉笔记号",
	"branch_a": "检查上方支管",
	"branch_b": "检查中间支管",
	"branch_c": "检查下方支管",
	"electrical_cabinet": "检查配电柜与隔离开关",
	"venue_archive": "查阅停工公文 / 整理证据",
	"lure_switch": "启动已核验的诱导电流",
	"lock_lever": "操作机械锁止杆",
	"rescue_door": "打开维护舱隔离门",
	"return_arch": "返回沿海压力廊"
}
const BRANCH_IDS := ["branch_a", "branch_b", "branch_c"]
const BASELINE_INTERVALS := [0.14, 0.62]

var diagram_marker: Label
var player: PlayerController
var hud
var selected_id := ""
var hotspots: Dictionary = {}
var branch_lights: Dictionary = {}
var panel_lights: Dictionary = {}
var locked_door_body: StaticBody2D
var locked_door_occluder: LightOccluder2D
var rescue_hatch: Node2D
var pipe_action: Node2D
var jiamin_knocks := 0
var pipe_item_sprite: Sprite2D
var rescue_support: Node2D
var chalk_link: Line2D
var shadow
var lure_anchor: CharacterBody2D
var coil_mark: Line2D
var rescued_jiamin: PlayerController
var listening_target := ""
var signal_taps: Array[float] = []
var signal_last_tap := 0.0
var signal_response_active := false
var scene_action_active := false
var selected_branch := ""
var lure_ready := false
var after_panel := Callable()
var world_tween: Tween


func _ready() -> void:
	GameState.prepare_opening_resume()
	if GameState.current_room_id != ROOM_ID:
		push_error("The final rescue room must be entered through the room registry.")
		return
	if not GameState.opening_flags.coastal_pressure_route_verified:
		push_error("The final chapter requires the verified coastal-works route.")
		return
	AudioManager.set_scene_ambience("crypt")
	_build_background()
	_build_vip_casino_decor()
	_build_geometry()
	_build_rescue_hatch()
	_build_mechanical_indicators()
	_build_ground_pipe()
	_build_hotspots()
	_build_diagram_marker()
	_build_player()
	hud = preload("res://ui/quiet_hud.gd").new()
	add_child(hud)
	hud.close_requested.connect(_on_close_requested)
	hud.pause_requested.connect(_pause_menu)
	_update_objective()
	_fade_in()
	if GameState.opening_flags.ending_missing or GameState.opening_flags.ending_escape or GameState.opening_flags.ending_truth:
		_show_recorded_ending()
		return
	if GameState.opening_flags.ch6_jiamin_rescued:
		_spawn_rescued_jiamin()
		if not GameState.opening_flags.ch6_reunion_seen:
			await _show_rescue_reunion()
			if not is_inside_tree(): return
	if not GameState.opening_flags.ch6_intro_seen:
		GameState.opening_flags.ch6_intro_seen = true
		checkpoint()
		if GameState.current_role == "jiamin":
			_say("稍早 · 石屎封墙夹层", "这片旧娱乐场贵宾厅后勤区竟然像百利新邨传闻一样砌了堵死墙……外面的东西还没走，我得找截铁管敲暗号给大文！")
		else:
			hud.show_resource_feedback("两短一长的敲击是从隔墙传过来的。")


func _build_background() -> void:
	var background := Sprite2D.new()
	background.name = "AbandonedVipRescueBackground061"
	background.texture = preload("res://assets/tilesets/abandoned_vip_rescue_061.png")
	background.centered = false
	background.scale = WORLD_SIZE / background.texture.get_size()
	background.z_index = -10
	add_child(background)
	var ambient := CanvasModulate.new()
	ambient.color = Color("858178")
	add_child(ambient)


func _build_vip_casino_decor() -> void:
	# 1. Abandoned Macau Casino VIP Hall crimson-and-gold damask carpet runner on the main floor
	var carpet := Node2D.new()
	carpet.name = "AbandonedVipCasinoCarpet"
	carpet.z_index = -5
	var carpet_script := GDScript.new()
	carpet_script.source_code = """extends Node2D
func _draw() -> void:
	var font := ThemeDB.fallback_font
	# Torn dark-crimson VIP lounge carpet runner
	var rect := Rect2(355, 425, 690, 195)
	draw_rect(rect, Color(0.26, 0.06, 0.07, 0.58))
	draw_rect(rect.grow(-6), Color(0.58, 0.45, 0.22, 0.48), false, 2.0)
	draw_rect(rect.grow(-12), Color(0.45, 0.34, 0.16, 0.32), false, 1.0)
	# Diamond Macau VIP medallion motif in center of carpet
	var c := rect.get_center()
	var diamond := PackedVector2Array([c + Vector2(0, -42), c + Vector2(68, 0), c + Vector2(0, 42), c + Vector2(-68, 0), c + Vector2(0, -42)])
	draw_polyline(diamond, Color(0.66, 0.52, 0.25, 0.45), 1.8)
	draw_string(font, c + Vector2(-56, 5), "VIP · 貴賓廳後勤區", HORIZONTAL_ALIGNMENT_CENTER, 112, 13, Color(0.75, 0.60, 0.30, 0.45))

	# 2. 2011 Baoli New Village homage: "Newly troweled bleeding concrete seal wall (渗血石屎封墙)" along x=284..306
	draw_rect(Rect2(283, 180, 22, 470), Color(0.32, 0.33, 0.31, 0.72))
	for y in [220, 295, 365, 445, 520, 585]:
		draw_line(Vector2(285, y), Vector2(304, y + 14), Color(0.46, 0.08, 0.08, 0.78), 2.2)
		draw_line(Vector2(298, y + 6), Vector2(298, y + 28), Color(0.38, 0.05, 0.06, 0.65), 1.6)
	draw_string(font, Vector2(308, 448), "← 违建石屎封墙（夹层传来敲击）", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.82, 0.68, 0.52, 0.72))

	# 3. 4-Channel black-and-white CCTV security monitor rack above the archive desk (x=915, y=135)
	var cctv := Rect2(912, 128, 76, 48)
	draw_rect(cctv, Color(0.07, 0.09, 0.08, 0.94))
	draw_rect(cctv, Color(0.38, 0.42, 0.38, 0.90), false, 1.5)
	for mx in [916, 952]:
		for my in [132, 154]:
			draw_rect(Rect2(mx, my, 32, 18), Color(0.12, 0.19, 0.16, 0.92))
			draw_line(Vector2(mx + 3, my + 9), Vector2(mx + 29, my + 9), Color(0.35, 0.55, 0.45, 0.45), 1.0)
	draw_string(font, Vector2(914, 124), "VIP CCTV 监控", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.72, 0.78, 0.70, 0.75))

	# 4. Broken flickering VIP neon sign plaque on upper bulkhead
	draw_rect(Rect2(582, 58, 128, 28), Color(0.10, 0.05, 0.06, 0.88))
	draw_rect(Rect2(582, 58, 128, 28), Color(0.85, 0.24, 0.22, 0.75), false, 1.4)
	draw_string(font, Vector2(592, 77), "金濠貴賓廳 VIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.96, 0.42, 0.35, 0.88))
"""
	carpet_script.reload()
	carpet.set_script(carpet_script)
	add_child(carpet)

	# Kickable physical non-gambling commemorative clay chips scattered on the VIP carpet
	for pt in [Vector2(475, 495), Vector2(615, 535), Vector2(760, 485), Vector2(885, 555)]:
		preload("res://core/components/physics_prop.gd").spawn(self, "casino_chip", pt, Rect2(340, 410, 720, 240))


func _wall(rect: Rect2) -> StaticBody2D:
	return LevelGeometry.wall(self, rect)


func _build_geometry() -> void:
	# The bottom-center arch returns to the pressure gallery.
	_wall(Rect2(0, 0, WORLD_SIZE.x, 18))
	_wall(Rect2(0, 18, 62, 684))
	_wall(Rect2(0, 18, 284, 196))
	_wall(Rect2(302, 18, 960, 136))
	_wall(Rect2(812, 18, 450, 269))
	_wall(Rect2(1135, 18, 145, 231))
	_wall(Rect2(1135, 517, 145, 185))
	_wall(Rect2(1262, 18, 18, 684))
	_wall(Rect2(18, 700, 520, 20))
	_wall(Rect2(742, 700, 520, 20))
	_wall(Rect2(520, 18, 18, 124))
	_wall(Rect2(742, 18, 18, 124))

	# The partition follows the reinforced steel bulkhead, completely sealing the left equipment lane from Dawen's rescue chamber.
	_wall(Rect2(284, 18, 18, 682))

	# Machine bases and the entire vertical pipe wall block the same visible footprints as the background.
	_wall(Rect2(26, 290, 94, 290))
	_wall(Rect2(133, 348, 52, 170))
	_wall(Rect2(302, 18, 475, 363))
	_wall(Rect2(812, 204, 80, 98))
	_wall(Rect2(902, 197, 54, 90))
	locked_door_body = _wall(HATCH_SCRIPT.BLOCKING_RECT)
	locked_door_occluder = get_child(get_child_count() - 1) as LightOccluder2D

	# A non-colliding anchor gives the animated shadow a physical-looking lure point.
	lure_anchor = CharacterBody2D.new()
	lure_anchor.name = "InductionCoilLureAnchor"
	lure_anchor.collision_layer = 0
	lure_anchor.collision_mask = 0
	lure_anchor.position = Vector2(1060, 365)
	add_child(lure_anchor)


func _build_mechanical_indicators() -> void:
	for id in BRANCH_IDS:
		var visual_pos: Vector2 = BRANCH_VISUAL_POS[id]
		var indicator := Line2D.new()
		indicator.name = "BranchIndicator_" + id
		indicator.points = PackedVector2Array([Vector2(-15, 0), Vector2(15, 0)])
		indicator.position = visual_pos
		indicator.width = 4.0
		indicator.default_color = Color("8c8770", 0.85)
		indicator.z_index = 7
		add_child(indicator)
		branch_lights[id] = indicator
		var pulse := Polygon2D.new()
		pulse.name = "ResponsePulse_" + id
		var points := PackedVector2Array()
		for step in range(16):
			var angle := TAU * step / 16.0
			points.append(Vector2(cos(angle), sin(angle)) * 8.0)
		pulse.polygon = points
		pulse.position = visual_pos + Vector2(31, 0)
		pulse.color = Color("d2bd83", 0.0)
		pulse.z_index = 8
		add_child(pulse)
		panel_lights[id] = pulse

	# The lower pipe already has three chalk slashes painted into the room.
	var joint_marks := [Vector2(593, 179), Vector2(595, 274)]
	for index in range(joint_marks.size()):
		var mark := ROUTE_PANEL.pipe_symbol(index, Color("c1ae83", 0.85), 1.7)
		mark.position = joint_marks[index]
		mark.z_index = 3
		add_child(mark)

	coil_mark = Line2D.new()
	coil_mark.position = lure_anchor.position
	for index in range(33):
		coil_mark.add_point(Vector2.from_angle(TAU * index / 32.0) * 52.0)
	coil_mark.default_color = Color("bdad88", 0.35)
	coil_mark.width = 1.9
	coil_mark.antialiased = true
	coil_mark.visible = GameState.opening_flags.ch6_entity_lured and not GameState.opening_flags.ch6_entity_bound
	add_child(coil_mark)

	chalk_link = Line2D.new()
	chalk_link.name = "ChalkTraceToClamp"
	chalk_link.points = PackedVector2Array([Vector2(273, 396), Vector2(304, 396), Vector2(314, 388)])
	chalk_link.width = 2.0
	chalk_link.default_color = Color("d2c7a2", 0.7)
	chalk_link.visible = GameState.opening_flags.ch6_route_diagram_seen
	add_child(chalk_link)


func _build_rescue_hatch() -> void:
	rescue_hatch = HATCH_SCRIPT.new()
	add_child(rescue_hatch)
	if GameState.opening_flags.ch6_rescue_door_open:
		rescue_hatch.set_open_progress(1.0)


func _build_ground_pipe() -> void:
	if GameState.opening_flags.ch6_jiamin_pipe_found:
		return
	pipe_item_sprite = Sprite2D.new()
	pipe_item_sprite.name = "GroundPipeItem"
	pipe_item_sprite.position = TARGETS["pipe_item"]
	pipe_item_sprite.texture = preload("res://assets/props/short_pipe_086.png")
	pipe_item_sprite.light_mask = 2
	pipe_item_sprite.z_index = 2
	add_child(pipe_item_sprite)


func _build_hotspots() -> void:
	for id in TARGETS:
		var area := Area2D.new()
		area.name = "Interact_" + id
		area.set_meta("interactable_id", id)
		area.position = TARGETS[id]
		area.collision_layer = 8
		area.collision_mask = 2
		var collision := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 34
		collision.shape = shape
		area.add_child(collision)
		add_child(area)
		hotspots[id] = area


func _build_player() -> void:
	if not GameState.opening_flags.ch6_signal_sent:
		GameState.enter_role("jiamin")
	else:
		GameState.enter_role("dawen")
	player = PLAYER_SCENE.instantiate() as PlayerController
	player.visual_size_multiplier = 1.85
	if GameState.current_role == "jiamin":
		player.position = Vector2(164, 628)
		player.look_dir = Vector2.RIGHT
	elif GameState.opening_flags.ch6_jiamin_rescued:
		player.position = Vector2(1115, 535)
		player.look_dir = Vector2.LEFT
	else:
		player.position = Vector2(650, 620)
		player.look_dir = Vector2.UP
	add_child(player)
	player.set_appearance("jiamin" if GameState.current_role == "jiamin" else "flashlight")
	var camera := player.get_node("Camera2D") as Camera2D
	camera.enabled = true
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	if GameState.opening_flags.ch6_circuit_isolated and GameState.opening_flags.ch6_entity_lured and not GameState.opening_flags.ch6_entity_bound:
		_spawn_shadow()
	if GameState.opening_flags.ch6_rescue_door_open:
		_clear_rescue_door_blocking()
		var marker := branch_lights.get("branch_c") as Line2D
		if marker != null:
			marker.default_color = Color("d6c388", 0.95)


func _process(_delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(hud):
		return
	if is_instance_valid(diagram_marker):
		diagram_marker.visible = GameState.current_role == "dawen" and not GameState.opening_flags.ch6_route_diagram_seen
	if scene_action_active:
		hud.prompt.text = "[ 空格 ] 敲管   %d / 3" % jiamin_knocks if is_instance_valid(pipe_action) else ""
		return
	if signal_response_active:
		return
	if not listening_target.is_empty():
		var now := float(Time.get_ticks_msec()) / 1000.0
		var pattern := "·".repeat(signal_taps.size())
		hud.prompt.text = "[ Space ] 敲 3 至 6 下　[%s]　[ Esc ] 取消" % pattern
		if signal_taps.size() >= 6 or (signal_taps.size() >= 3 and now - signal_last_tap >= 0.82):
			_finish_signal_test()
		return
	selected_id = ""
	var best := INF
	for id in TARGETS:
		if not _target_available(id):
			continue
		var offset: Vector2 = TARGETS[id] - player.position
		var distance := offset.length()
		var alignment := player.look_dir.dot(offset.normalized()) if distance > 0.1 else 1.0
		var range_value := 90.0
		if id in ["route_diagram", "electrical_cabinet", "venue_archive", "rescue_door"]:
			range_value = 118.0
		elif id in BRANCH_IDS or id == "lure_switch" or id == "lock_lever":
			range_value = 112.0
		if distance <= range_value and alignment >= -0.05 and distance < best:
			best = distance
			selected_id = id
	if selected_id.is_empty():
		hud.prompt.text = ""
	else:
		var target_name: String = TARGET_NAMES[selected_id]
		if selected_id == "rescue_door" and GameState.opening_flags.ch6_rescue_door_open:
			target_name = "决定如何撤离" if GameState.opening_flags.ch6_jiamin_rescued else "接应嘉敏出来"
		elif selected_id == "return_arch" and GameState.opening_flags.ch6_jiamin_rescued:
			target_name = "带嘉敏撤离"
		hud.prompt.text = "[ E ] " + target_name
	if is_instance_valid(shadow) and not GameState.opening_flags.ch6_entity_bound:
		if shadow.global_position.distance_to(lure_anchor.global_position) < 52.0:
			lure_ready = true
			coil_mark.default_color = Color("d8bc72", 0.8)
			hud.state_text.text = "影子已进入诱导线圈范围　[ E ] 操作锁止杆"


func _target_available(id: String) -> bool:
	if id == "pipe_item":
		return GameState.current_role == "jiamin" and not GameState.opening_flags.ch6_jiamin_pipe_found
	if id == "jiamin_signal_pipe":
		return GameState.current_role == "jiamin" and GameState.opening_flags.ch6_jiamin_pipe_found and not GameState.opening_flags.ch6_signal_sent
	if id in BRANCH_IDS or id == "route_diagram" or id == "electrical_cabinet" or id == "venue_archive" or id == "lure_switch" or id == "lock_lever" or id == "rescue_door":
		return GameState.current_role == "dawen" and not GameState.opening_flags.ending_missing and not GameState.opening_flags.ending_escape and not GameState.opening_flags.ending_truth
	if id == "return_arch":
		return GameState.current_role == "dawen" and not GameState.opening_flags.ending_missing and not GameState.opening_flags.ending_escape and not GameState.opening_flags.ending_truth
	return false


func _unhandled_input(event: InputEvent) -> void:
	if hud == null or hud.panel_open:
		return
	if _ending_recorded():
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
			_show_recorded_ending()
			get_viewport().set_input_as_handled()
		return
	if signal_response_active:
		if event.is_action_pressed("ui_cancel"):
			_pause_menu()
			get_viewport().set_input_as_handled()
		return
	if scene_action_active:
		if is_instance_valid(pipe_action) and _is_knock_input(event):
			_strike_jiamin_pipe()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_cancel"):
			_pause_menu()
			get_viewport().set_input_as_handled()
		return
	if not listening_target.is_empty():
		if _is_knock_input(event):
			_record_signal_tap()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_cancel"):
			_cancel_signal_test()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and not selected_id.is_empty():
		interact_target(selected_id)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_pause_menu()
		get_viewport().set_input_as_handled()


func interact_target(id: String) -> void:
	if scene_action_active or signal_response_active or not listening_target.is_empty():
		return
	if id == "pipe_item":
		GameState.opening_flags.ch6_jiamin_pipe_found = true
		if is_instance_valid(pipe_item_sprite):
			pipe_item_sprite.queue_free()
			pipe_item_sprite = null
		AudioManager.play_world_effect("metal_cover")
		checkpoint()
		_update_objective()
		hud.show_resource_feedback("拾起短钢管。沿右侧检修管往前。")
	elif id == "jiamin_signal_pipe":
		_send_jiamin_signal()
	elif id == "route_diagram":
		GameState.opening_flags.ch6_route_diagram_seen = true
		if is_instance_valid(chalk_link):
			chalk_link.visible = true
		checkpoint()
		hud.open_widget(ROUTE_PANEL.new().setup("rescue"))
		player.controls_enabled = false
		player.clear_motion()
		get_tree().paused = true
	elif id in BRANCH_IDS:
		_begin_signal_test(id)
	elif id == "electrical_cabinet":
		_operate_cabinet()
	elif id == "venue_archive":
		if GameState.opening_flags.ch6_jiamin_rescued:
			_open_rescue_archive_options()
		else:
			_read_venue_record()
	elif id == "lure_switch":
		_activate_lure()
	elif id == "lock_lever":
		_lock_entity()
	elif id == "rescue_door":
		await _open_rescue_door()
	elif id == "return_arch":
		await _return_to_pressure_gallery()


func _send_jiamin_signal() -> void:
	if scene_action_active or GameState.current_role != "jiamin" or GameState.opening_flags.ch6_signal_sent:
		return
	if not GameState.opening_flags.ch6_jiamin_pipe_found:
		_say("还没有钢管", "地上那截短钢管可以让敲击声沿管线传出去。")
		return
	player.controls_enabled = false
	player.clear_motion()
	scene_action_active = true
	jiamin_knocks = 0
	world_tween = create_tween()
	world_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	world_tween.tween_method(_rescue_approach_step.bind(player, player.position, Vector2(224, 312)), 0.0, 1.0, 0.24).set_trans(Tween.TRANS_SINE)
	await world_tween.finished
	if not is_inside_tree() or not is_instance_valid(player): return
	player.look_dir = Vector2.RIGHT
	pipe_action = PIPE_ACTION_SCRIPT.new()
	add_child(pipe_action)
	pipe_action.contact.connect(func():
		jiamin_knocks += 1
		AudioManager.play_at(self, "metal_cover", TARGETS["jiamin_signal_pipe"])
	)
	pipe_action.hold(player)
	hud.objective.text = ""
	hud.state_text.text = ""


func _is_knock_input(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE


func _strike_jiamin_pipe() -> void:
	if pipe_action.striking:
		return
	await pipe_action.strike()
	if not is_inside_tree() or not is_instance_valid(player): return
	if jiamin_knocks < 3:
		return
	pipe_action.release(player)
	pipe_action = null
	GameState.opening_flags.ch6_signal_sent = true
	GameState.enter_role("dawen")
	player.set_appearance("flashlight")
	player.position = Vector2(650, 620)
	player.reset_physics_interpolation()
	player.look_dir = Vector2.UP
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if is_instance_valid(camera):
		camera.reset_smoothing()

	# Smooth visual vignette transition to Dawen
	var fade_overlay := CanvasLayer.new()
	var fade_rect := ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0.7)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_overlay.add_child(fade_rect)
	add_child(fade_overlay)

	var fade_in := create_tween()
	fade_in.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	fade_in.tween_property(fade_rect, "color:a", 0.0, 0.20)
	fade_in.tween_callback(fade_overlay.queue_free)

	scene_action_active = false
	player.controls_enabled = true
	checkpoint()
	_update_objective()
	hud.show_resource_feedback("大文听见了同样的三下。")


func _begin_signal_test(branch_id: String) -> void:
	if not GameState.opening_flags.ch6_route_diagram_seen:
		hud.show_resource_feedback("右端那块图板上标着每根管通去哪里。")
		return
	if GameState.opening_flags.ch6_pipe_route_verified:
		_say("管路已核验", "下方支管逐拍回应了大文刚输入的新节奏，粉笔线也接回设备夹层。这条是目前唯一取得新回应的实际声路。")
		return
	selected_branch = branch_id
	listening_target = branch_id
	signal_taps.clear()
	signal_last_tap = float(Time.get_ticks_msec()) / 1000.0
	player.controls_enabled = false
	player.clear_motion()
	hud.state_text.text = "管道测试中：%s　已输入 0 次" % TARGET_NAMES[branch_id]


func _record_signal_tap() -> void:
	var now := float(Time.get_ticks_msec()) / 1000.0
	signal_taps.append(now)
	signal_last_tap = now
	AudioManager.play_world_effect("metal_cover", true)
	hud.state_text.text = "管道测试中：%s　已输入 %d 次" % [TARGET_NAMES[selected_branch], signal_taps.size()]
	if signal_taps.size() >= 6:
		_finish_signal_test()


func _cancel_signal_test() -> void:
	listening_target = ""
	signal_taps.clear()
	selected_branch = ""
	player.controls_enabled = true
	player.clear_motion()
	hud.state_text.text = ""
	hud.prompt.text = ""


func _is_novel_signal() -> bool:
	if signal_taps.size() < 3:
		return false
	var intervals := _signal_intervals()
	if intervals.size() != BASELINE_INTERVALS.size():
		return true
	for index in range(intervals.size()):
		if absf(intervals[index] - BASELINE_INTERVALS[index]) > 0.13:
			return true
	return false


func _signal_intervals() -> Array[float]:
	var intervals: Array[float] = []
	for index in range(1, signal_taps.size()):
		intervals.append(signal_taps[index] - signal_taps[index - 1])
	return intervals


func _finish_signal_test() -> void:
	if listening_target.is_empty():
		return
	var branch_id := selected_branch
	var tap_count := signal_taps.size()
	var intervals := _signal_intervals()
	var novel := _is_novel_signal()
	listening_target = ""
	player.controls_enabled = true
	player.clear_motion()
	if tap_count < 3:
		_say("节奏太短", "刚才只记到 %d 次敲击。至少敲三下，让回声有足够的节拍可供比较。" % tap_count)
		return
	# The player hears and sees the response before the explanatory dialogue.
	# Other branches replay the fixed old rhythm; only the live branch follows
	# the intervals the player just entered.
	var response_intervals: Array[float] = []
	if branch_id == "branch_c" and novel:
		response_intervals.assign(intervals)
	else:
		response_intervals.assign(BASELINE_INTERVALS)
	await _play_signal_response(branch_id, response_intervals)
	if not is_inside_tree() or not is_instance_valid(player): return
	if branch_id != "branch_c":
		GameState.opening_flags.ch6_failed_echo_seen = true
		checkpoint()
		var light := panel_lights[branch_id] as Polygon2D
		light.color = Color("c18372", 0.9)
		var indicator := branch_lights[branch_id] as Line2D
		indicator.default_color = Color("b16e62", 0.95)
		_update_objective()
		hud.show_resource_feedback("它只回了三下。换根管试试。")
		return
	if not novel:
		hud.show_resource_feedback("再敲一次，试试四下。")
		return
	if branch_id == "branch_c":
		GameState.opening_flags.ch6_live_signal_received = true
		GameState.opening_flags.ch6_pipe_route_verified = true
		var indicator := branch_lights[branch_id] as Line2D
		indicator.default_color = Color("e2ca89", 0.95)
		checkpoint()
		_update_objective()
		_say("隔墙", "大文？是我！隔离门在右手边，快小心外面那个穿西装的怪物！", [], "黄嘉敏")


func _play_signal_response(branch_id: String, intervals: Array[float]) -> void:
	signal_response_active = true
	player.controls_enabled = false
	player.clear_motion()
	hud.prompt.text = ""
	hud.state_text.text = "正在等待管道回应……"
	var light := panel_lights[branch_id] as Polygon2D
	var reduced_flash := GameState.reduced_flash
	light.color = Color("eed194", 0.26 if reduced_flash else 0.0)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.tween_interval(0.24)
	for index in range(intervals.size() + 1):
		if index > 0:
			tween.tween_interval(maxf(0.0, intervals[index - 1] - 0.08))
		tween.tween_callback(_show_response_beat.bind(index + 1))
		if reduced_flash:
			tween.tween_interval(0.08)
		else:
			tween.tween_property(light, "color:a", 0.95, 0.035)
			tween.tween_property(light, "color:a", 0.12, 0.045)
	tween.tween_interval(0.5)
	await tween.finished
	if not is_inside_tree(): return
	light.color.a = 0.0
	signal_response_active = false
	if is_instance_valid(player):
		player.controls_enabled = true
	if is_instance_valid(hud):
		hud.state_text.text = ""


func _show_response_beat(beat_count: int) -> void:
	var beats := PackedStringArray()
	for beat in range(1, beat_count + 1):
		beats.append(str(beat))
	hud.state_text.text = "管道回应  " + " · ".join(beats)
	AudioManager.play_world_effect("metal_cover", true)


func _operate_cabinet() -> void:
	if GameState.opening_flags.ch6_circuit_isolated:
		hud.show_resource_feedback("旧回声支路已断开。诱导开关在右边。")
		return
	if not GameState.opening_flags.ch6_pipe_route_verified:
		if GameState.opening_flags.ch6_failed_echo_seen:
			_say("支路未核验", "刚才的管道只回了旧暗号。贸然送电可能困在回廊里。", [
				{"text":"仍向未核验支路送电", "callback":_confirm_missing_ending},
				{"text":"返回管线图重新核对", "callback":_close_panel}
			])
		else:
			hud.show_resource_feedback("先敲管，确认哪一路传来嘉敏的回应。")
		return
	_say("配电柜", "旧回声还接在线圈上。先断开这一路。", [
		{"text":"拉下旧回声旁路隔离闸", "callback":_confirm_circuit_isolation},
		{"text":"先返回检查管线", "callback":_close_panel}
	])


func _confirm_circuit_isolation() -> void:
	_close_panel()
	GameState.opening_flags.ch6_circuit_isolated = true
	AudioManager.play_world_effect("power_switch")
	var lid := branch_lights["branch_a"] as Line2D
	lid.default_color = Color("52564e", 0.8)
	checkpoint()
	_update_objective()
	hud.show_resource_feedback("旧线熄了。下管沿墙接到右侧线圈。")


func _activate_lure() -> void:
	if not GameState.opening_flags.ch6_pipe_route_verified or not GameState.opening_flags.ch6_circuit_isolated:
		hud.show_resource_feedback("先核验管道并切断旧回声支路。")
		return
	if GameState.opening_flags.ch6_entity_lured:
		hud.show_resource_feedback("等石屎怨煞踏入高压感应圈，立刻拉下锁止杆放电！")
		return
	GameState.opening_flags.ch6_entity_lured = true
	coil_mark.show()
	_spawn_shadow()
	AudioManager.play_world_effect("power_switch")
	AudioManager.start_chase_music()
	checkpoint()
	_update_objective()
	hud.show_resource_feedback("【BOSS 现身】石屎怨煞从舱门旁破墙逼近！等它踏入高压线圈立刻拉杆反杀！")


func _spawn_shadow() -> void:
	if is_instance_valid(shadow) or GameState.opening_flags.ch6_entity_bound:
		return
	shadow = SHADOW_SCRIPT.new()
	shadow.name = "BoundedServiceShadow"
	shadow.position = Vector2(1110, 505)
	shadow.speed = 27.0
	shadow.target = lure_anchor
	shadow.scale = Vector2.ONE * 0.92
	add_child(shadow)
	# Upgrade visual to the towering Concrete Wraith Final Boss ("石屎怨煞") while keeping Figure playing for tests
	var base_fig := shadow.get_node_or_null("Figure") as CanvasItem
	if base_fig != null:
		base_fig.modulate.a = 0.25
	var boss_tex := load("res://assets/characters/boss_concrete_wraith_252.png") as Texture2D
	if boss_tex != null:
		var boss_sprite := Sprite2D.new()
		boss_sprite.name = "ConcreteWraithBossSprite"
		boss_sprite.texture = boss_tex
		boss_sprite.position = Vector2(0, -56)
		boss_sprite.scale = Vector2.ONE * (118.0 / float(boss_tex.get_height()))
		shadow.add_child(boss_sprite)
		var boss_tag := Label.new()
		boss_tag.text = "【石屎怨煞】"
		boss_tag.position = Vector2(-36, -124)
		boss_tag.add_theme_font_size_override("font_size", 11)
		boss_tag.add_theme_color_override("font_color", Color("f26b5e"))
		shadow.add_child(boss_tag)


func _lock_entity() -> void:
	if not GameState.opening_flags.ch6_entity_lured:
		hud.show_resource_feedback("线圈没有通电。")
		return
	if not GameState.opening_flags.ch6_entity_bound:
		if not is_instance_valid(shadow) or shadow.global_position.distance_to(lure_anchor.global_position) > 52.0:
			hud.show_resource_feedback("石屎怨煞还在高压线圈外，再等它靠近半步！")
			return
		GameState.opening_flags.ch6_entity_bound = true
		lure_ready = false
		scene_action_active = true
		player.controls_enabled = false
		player.clear_motion()
		AudioManager.stop_chase_music()
		AudioManager.play_at(self, "gate_iron", TARGETS["lock_lever"])
		_spawn_high_voltage_arc_burst()
		if is_instance_valid(shadow):
			shadow.active = false
			var tween := create_tween()
			tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
			tween.tween_property(shadow, "scale", Vector2.ZERO, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tween.tween_callback(shadow.queue_free)
			await tween.finished
			if not is_inside_tree(): return
		for id in BRANCH_IDS:
			(branch_lights[id] as Line2D).default_color = Color("6f7868", 0.9)
		scene_action_active = false
		player.controls_enabled = true
		coil_mark.hide()
		checkpoint()
		_update_objective()
		hud.show_resource_feedback("高压电弧将石屎怨煞彻底锁住了。用右边的手轮开门救嘉敏！")
		return
	hud.show_resource_feedback("锁住了。隔离门可以打开。")


func _spawn_high_voltage_arc_burst() -> void:
	if GameState.reduced_flash:
		return
	var fx := Node2D.new()
	fx.z_index = 95
	add_child(fx)
	var origins: Array[Vector2] = [Vector2(875, 325), Vector2(1010, 380), Vector2(936, 468)]
	var center: Vector2 = lure_anchor.position + Vector2(0, -36)
	for orig: Vector2 in origins:
		var bolt := Line2D.new()
		var pts := PackedVector2Array([orig])
		for step in range(1, 5):
			var p: Vector2 = orig.lerp(center, float(step) / 5.0) + Vector2(randf_range(-16, 16), randf_range(-16, 16))
			pts.append(p)
		pts.append(center)
		bolt.points = pts
		bolt.width = 2.6
		bolt.default_color = Color(0.65, 0.92, 1.0, 0.95)
		fx.add_child(bolt)
	var tw := fx.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tw.tween_property(fx, "modulate:a", 0.0, 0.40)
	tw.tween_callback(fx.queue_free)


func _open_rescue_door() -> void:
	if scene_action_active:
		return
	if not GameState.opening_flags.ch6_entity_bound:
		hud.show_resource_feedback("影子贴在舱门上。先把它引开。")
		return
	if GameState.opening_flags.ch6_rescue_door_open:
		if not GameState.opening_flags.ch6_jiamin_rescued:
			player.controls_enabled = false
			player.clear_motion()
			await _complete_rescue()
		else:
			_say("隔离门", "嘉敏已经安全出来，可以撤离了。", [
				{"text":"决定如何撤离", "callback":_open_ending_choices},
				{"text":"再在现场检查一下", "callback":_close_panel}
			])
		return
	GameState.opening_flags.ch6_rescue_door_open = true
	scene_action_active = true
	AudioManager.play_at(self, "gate_iron", TARGETS["rescue_door"])
	checkpoint()
	_update_objective()
	player.controls_enabled = false
	player.clear_motion()
	var door_light := branch_lights["branch_c"] as Line2D
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.tween_method(_set_rescue_hatch_progress, 0.0, 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(door_light, "default_color", Color("f1d7a0", 1.0), 1.0)
	await tween.finished
	if not is_inside_tree(): return
	_clear_rescue_door_blocking()
	await _complete_rescue()


func _set_rescue_hatch_progress(value: float) -> void:
	rescue_hatch.set_open_progress(value)
	rescue_hatch.sync_blocking(locked_door_body, locked_door_occluder)


func _clear_rescue_door_blocking() -> void:
	if is_instance_valid(locked_door_body):
		locked_door_body.collision_layer = 0
		locked_door_body.queue_free()
	if is_instance_valid(locked_door_occluder):
		locked_door_occluder.visible = false
		locked_door_occluder.queue_free()


func _complete_rescue() -> void:
	if GameState.opening_flags.ch6_jiamin_rescued:
		return
	scene_action_active = true
	player.controls_enabled = false
	player.clear_motion()
	_spawn_rescued_jiamin(true)
	var jiamin_start := rescued_jiamin.position
	var dawen_start := player.position
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.tween_method(_rescue_approach_step.bind(rescued_jiamin, jiamin_start, Vector2(1080, 535)), 0.0, 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_method(_rescue_approach_step.bind(player, dawen_start, Vector2(1115, 535)), 0.0, 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	if not is_inside_tree() or not is_instance_valid(player) or not is_instance_valid(rescued_jiamin): return
	rescue_support = RESCUE_SUPPORT_SCRIPT.new()
	add_child(rescue_support)
	await rescue_support.perform(player, rescued_jiamin)
	if not is_inside_tree() or not is_instance_valid(player) or not is_instance_valid(rescued_jiamin): return
	GameState.opening_flags.ch6_jiamin_rescued = true
	GameState.opening_flags.pre_ending_checkpoint = true
	GameState.pending_entry_id = "from_pre_ending"
	GameState.enter_role("dawen")
	_update_objective()
	checkpoint()
	scene_action_active = false
	await _show_rescue_reunion()


func _rescue_approach_step(progress: float, actor: PlayerController, start: Vector2, destination: Vector2) -> void:
	var displacement := destination - start
	actor.position = start.lerp(destination, progress)
	if displacement.length_squared() > 0.01:
		actor.look_dir = displacement.normalized()
		actor.facing = posmod(roundi(actor.look_dir.angle() / (PI / 4.0)), 8)
		actor.pivot.rotation = actor.look_dir.angle()
	actor.sprite.stop()
	actor.sprite.animation = str(actor.facing)
	actor.sprite.frame = 0 if progress >= 1.0 else posmod(floori(displacement.length() * progress / GameState.RULES.walk_stride * 3.0), 6)
	actor._sync_pose_landmarks()
	actor.z_index = int(actor.position.y)


func _show_rescue_reunion() -> void:
	if GameState.has_demo_item("ahhao_camera") and not GameState.opening_flags.ch6_ahhao_camera_handed:
		scene_action_active = true
		rescue_support = RESCUE_HANDOFF_SCRIPT.new()
		add_child(rescue_support)
		await rescue_support.perform(player, rescued_jiamin)
		if not is_inside_tree() or not is_instance_valid(player): return
		GameState.opening_flags.ch6_ahhao_camera_handed = true
		checkpoint()
		scene_action_active = false
	after_panel = _answer_about_ahhao
	_say("嘉敏获救", "阿豪呢？", [], "黄嘉敏")


func _answer_about_ahhao() -> void:
	scene_action_active = true
	player.controls_enabled = false
	await get_tree().create_timer(0.75, false).timeout
	if not is_inside_tree():
		return
	scene_action_active = false
	_say("楼梯口", "他挡在唐楼楼梯口，推我进屋叫我先走。嘉敏……对不起，我没能把阿豪带出来。", [
		{"text":"准备撤离", "callback":_finish_rescue_reunion}
	])


func _play_assisted_departure() -> void:
	if not is_instance_valid(rescued_jiamin) or scene_action_active:
		return
	scene_action_active = true
	player.controls_enabled = false
	player.clear_motion()
	var departure := RESCUE_DEPARTURE_SCRIPT.new()
	add_child(departure)
	await departure.perform(player, rescued_jiamin, GameState.has_demo_item("ahhao_camera"))
	if not is_inside_tree(): return
	scene_action_active = false


func _finish_rescue_reunion() -> void:
	GameState.opening_flags.ch6_reunion_seen = true
	checkpoint()
	_open_ending_choices()


func _spawn_rescued_jiamin(entering := false) -> void:
	if is_instance_valid(rescued_jiamin):
		return
	rescued_jiamin = PLAYER_SCENE.instantiate() as PlayerController
	rescued_jiamin.name = "RescuedJiamin"
	rescued_jiamin.appearance = "jiamin"
	rescued_jiamin.visual_size_multiplier = 1.85
	rescued_jiamin.position = Vector2(1192, 511) if entering else Vector2(1080, 535)
	rescued_jiamin.controls_enabled = false
	# She is a physical person at the doorway, with the same foot collision
	# as her playable segment; the broad floor still leaves room to pass her.
	rescued_jiamin.collision_layer = 1
	rescued_jiamin.collision_mask = 0
	rescued_jiamin.look_dir = Vector2.LEFT
	add_child(rescued_jiamin)
	rescued_jiamin.set_appearance("jiamin")
	(rescued_jiamin.get_node("Camera2D") as Camera2D).enabled = false


func _open_rescue_archive_options() -> void:
	_say("撤离前的文件袋", "嘉敏已经获救。你可以直接带她撤离，也可以先整理文件袋中的两份资料。", [
		{"text":"决定如何撤离", "callback":_open_ending_choices},
		{"text":"查看文件袋", "callback":_read_venue_record},
		{"text":"回到房间", "callback":_close_panel}
	])


func _read_venue_record() -> void:
	var choices: Array[Dictionary] = []
	var reg_prefix := "（已读）" if GameState.opening_flags.ch6_bunker_register_found else ""
	var stop_prefix := "（已读）" if GameState.opening_flags.ch6_venue_stopwork_found else ""
	choices.append({"text": reg_prefix + "展开地宫工事名册", "callback": _read_bunker_register})
	choices.append({"text": stop_prefix + "展开娱乐场停工公文", "callback": _read_stopwork_record})
	choices.append({"text": "收好文件袋", "callback": _close_panel})
	_say("贵宾厅档案袋与年份泥码", "桌上散落着 1961、1985、2005、2011 四枚旧泥码，压着两份揭开这处旧娱乐场贵宾厅与石屎封墙秘密的工程档案。", choices)


func _read_bunker_register() -> void:
	GameState.opening_flags.ch6_bunker_register_found = true
	checkpoint()
	_update_objective()
	_say("地宫工事名册 · 虚构档案", "名册最后一页写着改线日期。回廊的支路编号后来被人改过。", [
		{"text":"继续核对另一份档案", "callback":_read_venue_record},
		{"text":"收好文件袋", "callback":_close_panel}
	])


func _read_stopwork_record() -> void:
	GameState.opening_flags.ch6_venue_stopwork_found = true
	checkpoint()
	_update_objective()
	_say("停工公文 · 虚构案卷", "停工日期在改线之后。正本要求封闭回廊，附图仍保留了舱门旁的维修通路。", [
		{"text":"继续核对另一份档案", "callback":_read_venue_record},
		{"text":"收好文件袋", "callback":_close_panel}
	])


func _local_archives_verified() -> bool:
	return GameState.opening_flags.ch6_bunker_register_found and GameState.opening_flags.ch6_venue_stopwork_found


func _archive_rows() -> Array[Dictionary]:
	return [
		{"name":"阿豪的随身遗物／记录", "found":GameState.has_demo_item("ahhao_camera")},
		{"name":"地宫工事名册", "found":GameState.opening_flags.ch6_bunker_register_found},
		{"name":"旧肉铺账册", "found":GameState.opening_flags.ch3_register_seen and GameState.opening_flags.ch3_balance_solved},
		{"name":"沿海工事记录", "found":GameState.opening_flags.coastal_works_record_found},
		{"name":"娱乐场停工公文", "found":GameState.opening_flags.ch6_venue_stopwork_found}
	]


func _all_archives_verified() -> bool:
	for row in _archive_rows():
		if not bool(row.found):
			return false
	return true


func _open_ending_choices() -> void:
	if not GameState.opening_flags.ch6_jiamin_rescued:
		_say("证据整理袋尚未封口", "先打开隔离舱门并确定嘉敏已安全离开，再决定是否带着档案撤出。")
		return
	GameState.opening_flags.pre_ending_checkpoint = true
	GameState.pending_entry_id = "from_pre_ending"
	checkpoint()
	var found := PackedStringArray()
	var missing := PackedStringArray()
	for row in _archive_rows():
		if row.found:
			found.append(String(row.name))
		else:
			missing.append(String(row.name))
	var lines: Array[String] = ["救援完成，现在就可以撤离。"]
	if not found.is_empty():
		lines.append("已核对　" + "、".join(found))
	if not missing.is_empty():
		lines.append("待核对　" + "、".join(missing))
	var choices: Array[Dictionary] = [
		{"text":"现在带嘉敏撤离", "callback":_select_escape_ending}
	]
	if _all_archives_verified():
		choices.append({"text":"核对五组档案，带阿豪遗物返港", "callback":_confirm_truth_ending})
	choices.append({"text":"回到房间再检查", "callback":_close_panel})
	_say("撤离前 · 档案核对", "\n".join(lines), choices)


func _select_escape_ending() -> void:
	_close_panel()
	if not GameState.opening_flags.ch6_jiamin_rescued:
		_say("还没有完成救援", "先打开隔离舱门，确认嘉敏已安全离开，再作出撤离选择。")
		return
	if not _save_final_decision():
		return
	await _play_assisted_departure()
	if not is_inside_tree(): return
	_record_final_ending("ending_escape")


func _confirm_truth_ending() -> void:
	_close_panel()
	var body := "五组档案已齐。带阿豪的遗物和档案返港，公开这桩旧案。"
	_say("确认真结局", body, [
		{"text":"确认并带走五组档案", "callback":_select_truth_ending},
		{"text":"返回证据核对", "callback":_open_ending_choices}
	])


func _select_truth_ending() -> void:
	_close_panel()
	if not GameState.opening_flags.ch6_jiamin_rescued or not _all_archives_verified():
		_say("档案待核对", "还有档案没核对。你可以先带嘉敏撤离。")
		return
	if not _save_final_decision():
		return
	await _play_assisted_departure()
	if not is_inside_tree(): return
	_record_final_ending("ending_truth")


func _confirm_missing_ending() -> void:
	_close_panel()
	_say("危险的送电选择", "刚才测过的管道只会重播旧暗号。向它送电可能会永远困在回廊里。", [
		{"text":"仍然确认向假支路送电", "callback":_select_missing_ending},
		{"text":"取消，返回检查管线", "callback":_close_panel}
	])


func _select_missing_ending() -> void:
	_close_panel()
	if not GameState.opening_flags.ch6_failed_echo_seen or GameState.opening_flags.ch6_pipe_route_verified:
		_say("危险支路尚未核实", "只有已听过假回声、仍未核验正确支路时，才会出现这项不可逆选择。")
		return
	if not _save_final_decision():
		return
	_record_final_ending("ending_missing")


func _save_final_decision() -> bool:
	# Preview and isolated regressions can run with persistence deliberately off.
	if not GameState.opening_checkpoint_enabled():
		return true
	if GameState.save_pre_ending_checkpoint():
		return true
	_say("无法保存结局前进度", "请检查存储空间和文件夹权限，然后重试。")
	return false


func _record_final_ending(ending_id: String) -> void:
	GameState.opening_flags[ending_id] = true
	if GameState.opening_checkpoint_enabled() and not GameState.save_opening_checkpoint():
		GameState.opening_flags[ending_id] = false
		_say("结局尚未保存", "结局前进度已保存。请检查存储空间和文件夹权限，再重新选择。")
		return
	_update_objective()
	_show_ending(ending_id)


func _show_ending(ending_id: String) -> void:
	var title := ""
	var body := ""
	match ending_id:
		"ending_missing":
			title = "迷失闭环"
			body = "红灯熄灭。大文每转过一道弯，都会回到同一扇铁门前。管道深处仍回荡着那三下冰冷死板的旧敲击声。"
		"ending_escape":
			title = "残缺生还"
			body = "两人相互搀扶走出亮灯的路环街口。海风吹散了夜雾，嘉敏坐在路边石阶上，握紧阿豪留下的相机，终于颤声问起唐楼楼梯口发生了什么。"
		"ending_truth":
			title = "破晓真章"
			body = "嘉敏带着五组旧档案返港，将这桩埋在旧娱乐场地基下的旧案公之于世。天亮破晓，港澳码头海面泛起金光；她翻开阿豪的相机，最后一张照片，是三人刚到澳门大三巴石仔路时笑着拍的。"
	var choices: Array[Dictionary] = []
	if GameState.has_pre_ending_checkpoint() or GameState.recover_old_ending_checkpoint():
		choices.append({"text":"回到结局前继续调查", "callback":_retry_pre_ending})
	choices.append({"text":"返回标题画面", "callback":_return_to_title})
	_say("结局", "本次故事已结束。\n\n" + body, choices, title)
	hud.objective.hide()
	if hud.pages.size() == 1:
		hud.page_hint.hide()


func _ending_recorded() -> bool:
	var flags := GameState.opening_flags
	return flags.ending_missing or flags.ending_escape or flags.ending_truth


func _on_close_requested() -> void:
	if not _ending_recorded():
		_close_panel()


func _retry_pre_ending() -> void:
	_close_panel()
	if not GameState.restore_pre_ending_checkpoint():
		_say("暂时无法恢复进度", "结局前的存档无法读取或写回。请检查存储空间后再试。", [
			{"text":"返回结局", "callback":_show_recorded_ending}
		])
		return
	if not GameState.request_room_change(GameState.current_room_id, GameState.pending_entry_id):
		_say("暂时无法返回房间", "结局前进度已恢复。返回标题后可以继续游戏。", [
			{"text":"返回标题画面", "callback":_return_to_title}
		])


func _show_recorded_ending() -> void:
	var ending_id := "ending_missing" if GameState.opening_flags.ending_missing else ("ending_truth" if GameState.opening_flags.ending_truth else "ending_escape")
	_show_ending(ending_id)


func _update_objective() -> void:
	if not is_instance_valid(hud):
		return
	if _ending_recorded():
		hud.objective.text = "本次故事已结束。"
	elif GameState.current_role == "jiamin":
		hud.objective.text = "嘉敏 · 沿右边的空地走到管道接头。" if GameState.opening_flags.ch6_jiamin_pipe_found else "嘉敏 · 拾起地上的短钢管。"
	elif not GameState.opening_flags.ch6_route_diagram_seen:
		hud.objective.text = "大文 · 沿中间走到三根管道右端，靠近「管线图」按 E。"
	elif not GameState.opening_flags.ch6_pipe_route_verified:
		hud.objective.text = "大文：选一支支管，按 Space 敲 3 至 6 下并改变节奏；真声路会逐拍回应。"
	elif not GameState.opening_flags.ch6_circuit_isolated:
		hud.objective.text = "大文：在配电柜隔离旧回声旁路。"
	elif not GameState.opening_flags.ch6_entity_lured:
		hud.objective.text = "大文：接通已核验的下方声路，把影子引向线圈。"
	elif not GameState.opening_flags.ch6_entity_bound:
		hud.objective.text = "大文：等影子进入地面的线圈标记，再拉下机械锁止杆。"
	elif GameState.opening_flags.ch6_rescue_door_open and not GameState.opening_flags.ch6_jiamin_rescued:
		hud.objective.text = "隔离门已打开：靠近舱门按 E，接应嘉敏出来。"
	elif not GameState.opening_flags.ch6_jiamin_rescued:
		hud.objective.text = "大文：用手轮打开维护舱门，把嘉敏带出来。"
	else:
		hud.objective.text = "嘉敏已获救。沿来路撤离，或回配电柜旁查档案。"
	hud.state_text.text = ""


func _say(title: String, body: String, choices: Array = [], speaker := "") -> void:
	if speaker.is_empty():
		speaker = "黄嘉敏" if GameState.current_role == "jiamin" else "陈大文"
	hud.open_panel(title, body, choices, false, speaker)
	player.controls_enabled = false
	player.clear_motion()
	get_tree().paused = true


func _close_panel() -> void:
	hud.close_panel()
	get_tree().paused = false
	if is_instance_valid(player) and listening_target.is_empty() and not signal_response_active and not scene_action_active and not _ending_recorded():
		player.controls_enabled = true
		player.clear_motion()
	var callback := after_panel
	after_panel = Callable()
	if callback.is_valid():
		callback.call()


func _pause_menu() -> void:
	_say("暂停", "救援室的影子、电力与角色移动均已暂停。", [
		{"text":"继续调查", "callback":_close_panel},
		{"text":"保存进度并返回标题", "callback":_return_to_title}
	])


func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT or not is_instance_valid(hud) or not is_instance_valid(player):
		return
	if hud.panel_open or get_tree().paused:
		return
	if not listening_target.is_empty():
		_cancel_signal_test()
		_say("窗口失焦，已暂停", "刚才的敲击已取消。继续后可以重试。", [
			{"text":"继续调查", "callback":_close_panel},
			{"text":"保存进度并返回标题", "callback":_return_to_title}
		])
	else:
		_pause_menu()


func _return_to_title() -> void:
	_close_panel()
	if not GameState.save_opening_checkpoint():
		_say("保存失败", "目前进度未能保存。请检查存储空间和文件夹权限后重试。")
		return
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _return_to_pressure_gallery() -> void:
	if GameState.opening_flags.ch6_jiamin_rescued:
		_say("准备带嘉敏撤离", "大文与嘉敏已经会合。确定要从这条沿海通道撤离吗？", [
			{"text":"进行撤离与档案核对", "callback":_open_ending_choices},
			{"text":"再在现场检查一下", "callback":_close_panel}
		])
		return
	if GameState.request_room_change("ch5_coastal_pressure_gallery", "from_ch6"):
		return
	_say("通道暂时不能返回", "稍后再试。")


func _fade_in() -> void:
	var overlay := ColorRect.new()
	overlay.name = "RescueRoomFade"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 1)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer := CanvasLayer.new()
	layer.name = "RescueRoomFadeLayer"
	layer.layer = 20
	add_child(layer)
	layer.add_child(overlay)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(overlay, "color:a", 0.0, 0.65)
	tween.tween_callback(layer.queue_free)


func checkpoint() -> void:
	if not GameState.save_opening_checkpoint() and is_instance_valid(hud):
		hud.show_resource_feedback("进度保存失败，仍可继续。请检查存储空间和文件夹权限后重试。")

func _build_diagram_marker() -> void:
	var board := ROUTE_PANEL.rescue_plate()
	board.name = "MountedPipeSchematic"
	board.position = TARGETS.route_diagram + Vector2(-38, 7)
	board.scale = Vector2(76, 43) / ROUTE_PANEL.PLATE_SIZE
	board.z_index = 5
	add_child(board)
	diagram_marker = ROUTE_PANEL.marker(self, "管线图", TARGETS.route_diagram + Vector2(0, 51))
	diagram_marker.hide()
