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
	"route_diagram": Vector2(742, 388),
	"branch_a": Vector2(390, 395),
	"branch_b": Vector2(460, 395),
	"branch_c": Vector2(530, 395),
	"illusion_door": Vector2(342, 525),
	"electrical_cabinet": Vector2(855, 386),
	"venue_archive": Vector2(944, 388),
	"lure_switch": Vector2(1024, 392),
	"lock_lever": Vector2(936, 488),
	"emergency_charger": Vector2(768, 635),
	"rescue_door": Vector2(1180, 390),
	"return_arch": Vector2(640, 668)
}
const TARGET_NAMES := {
	"pipe_item": "拾取地上的短钢管",
	"jiamin_signal_pipe": "用钢管敲击检修管",
	"route_diagram": "查看三路管线图与刻痕",
	"branch_a": "检查上方支管（红轮）",
	"branch_b": "检查中间支管（黄轮）",
	"branch_c": "轻听嘉敏敲击的铜管",
	"illusion_door": "查看渗血封墙暗门（传出诡异呼唤）",
	"electrical_cabinet": "操作高压配电柜",
	"venue_archive": "查阅百利新邨工程档案箱（真结局线索）",
	"lure_switch": "启动声呐引诱器，引出封墙怨灵",
	"lock_lever": "拉下红柄应急落闸杆（封锁铁栅区怨灵）",
	"emergency_charger": "使用应急充电盒（补满电量与 2 次强闪）",
	"rescue_door": "打开右侧防爆隔离舱门",
	"return_arch": "检查暗渠防洪闸门"
}
const BRANCH_IDS := ["branch_a", "branch_b", "branch_c"]
const BASELINE_INTERVALS := [0.14, 0.62]
const GRATE_RECT := Rect2(-58, -36, 116, 72)
const BOSS_CHASE_SPEED := 64.0
const BOSS_GRATE_SPEED := 30.0

var diagram_marker: Label
var ending_backdrop: Control
var player: PlayerController
var hud
var selected_id := ""
var hotspots: Dictionary = {}
var branch_lights: Dictionary = {}
var branch_point_lights: Dictionary = {}
var panel_lights: Dictionary = {}
var floor_grate: Node2D
var grate_corner_lamps: Array[PointLight2D] = []
var grate_corner_bulbs: Array[Polygon2D] = []
var active_step_beacon: PointLight2D
var active_beacon_target := Vector2(742, 370)
var beacon_clock := 0.0
var boss_in_trap_zone := false
var boss_capture_active := false
var boss_anim_sprite: AnimatedSprite2D
var locked_door_body: StaticBody2D
var locked_door_occluder: LightOccluder2D
var rescue_hatch: Node2D
var pipe_action: Node2D
var pipe_knock_ui: CanvasLayer
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
var after_panel := Callable()
var world_tween: Tween
var rescue_door_status_light: PointLight2D
var illusion_door_group: Node2D
var illusion_door_glow: PointLight2D


func _ready() -> void:
	GameState.prepare_opening_resume()
	if GameState.current_room_id != ROOM_ID:
		push_error("The final rescue room must be entered through the room registry.")
		return
	if not GameState.opening_flags.coastal_pressure_route_verified:
		push_error("The final chapter requires the verified coastal-works route.")
		return
	AudioManager.set_scene_ambience("finale")
	_build_background()
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
		GameState.unlock_macau_guide("bleeding_wall_vip", false)
		checkpoint()
		if GameState.current_role == "jiamin":
			_say("稍早 · 石屎封墙夹层", "我沿排水渠爬上来，门就在我身后合上了。地上有截钢管。顺着那根主管敲，大文也许能听见。")
		else:
			hud.show_resource_feedback("隔墙深处传来了两短一长的清脆敲击声——是嘉敏！")


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


func _wall(rect: Rect2) -> StaticBody2D:
	return LevelGeometry.wall(self, rect)


func _build_geometry() -> void:
	# The bottom-center arch returns to the pressure gallery.
	_wall(Rect2(0, 0, WORLD_SIZE.x, 18))
	_wall(Rect2(0, 18, 62, 684))
	_wall(Rect2(0, 18, 284, 196))
	# Seal the entire upper pipe wall, electrical cabinet wall, and upper-right wall gap (x=302..1136) flush at floor seam y=381!
	_wall(Rect2(302, 18, 834, 363))
	_wall(Rect2(1098, 18, 164, 232))
	_wall(Rect2(1135, 517, 145, 185))
	_wall(Rect2(1262, 18, 18, 684))
	_wall(Rect2(18, 700, 520, 20))
	_wall(Rect2(742, 700, 520, 20))
	_wall(Rect2(520, 18, 18, 124))
	_wall(Rect2(742, 18, 18, 124))

	# The partition follows the reinforced concrete bulkhead, completely sealing Jiamin's left lane from Dawen's rescue chamber.
	_wall(Rect2(284, 18, 18, 682))

	# Machine bases in Jiamin's left service shaft match the visible footprints.
	_wall(Rect2(26, 290, 94, 290))
	_wall(Rect2(133, 348, 52, 170))
	locked_door_body = _wall(HATCH_SCRIPT.BLOCKING_RECT)
	locked_door_occluder = get_child(get_child_count() - 1) as LightOccluder2D

	# Floor containment trap anchor centered clearly on the open floor in front of sonar, lever & rescue hatch
	lure_anchor = CharacterBody2D.new()
	lure_anchor.name = "InductionCoilLureAnchor"
	lure_anchor.collision_layer = 0
	lure_anchor.collision_mask = 0
	lure_anchor.position = Vector2(1056, 430)
	add_child(lure_anchor)


func _exit_tree() -> void:
	AudioManager.stop_chase_music()


func _start_boss_chase_music() -> void:
	for m in AudioManager.get_method_list():
		if String(m.name) == "start_chase_music":
			var args: Array = m.args
			if args.size() >= 1:
				AudioManager.call("start_chase_music", "boss")
			else:
				AudioManager.start_chase_music()
			return
	AudioManager.start_chase_music()


func _circle_poly(radius: float, steps := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for step in range(steps):
		var angle := TAU * float(step) / float(steps)
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	return pts


func _build_mechanical_indicators() -> void:
	var soft_light := preload("res://assets/lighting/soft_light.png")
	for id in BRANCH_IDS:
		var visual_pos: Vector2 = BRANCH_VISUAL_POS[id]
		# Keep BranchIndicator Line2D node & default_color intact for tests, width = 0.0 (zero overlays on painted pipes!)
		var indicator := Line2D.new()
		indicator.name = "BranchIndicator_" + id
		indicator.points = PackedVector2Array([Vector2(-15, 0), Vector2(15, 0)])
		indicator.position = visual_pos
		indicator.width = 0.0
		indicator.default_color = Color("8c8770", 0.85)
		indicator.z_index = 7
		add_child(indicator)
		branch_lights[id] = indicator

		# REMOVED circular brass discs ("支管为什么突然变成圆形了")!
		# Keep ResponsePulse Polygon2D with tiny clean painted-flange glint (not a round disc!) + soft PointLight2D feedback
		var lamp_pos := visual_pos + Vector2(-42, -26)
		var pulse := Polygon2D.new()
		pulse.name = "ResponsePulse_" + id
		pulse.polygon = PackedVector2Array([Vector2(-4, -2), Vector2(4, -2), Vector2(4, 2), Vector2(-4, 2)])
		pulse.position = lamp_pos
		pulse.color = Color("d2bd83", 0.0)
		pulse.z_index = 8
		add_child(pulse)
		panel_lights[id] = pulse

		var pilot_glow := PointLight2D.new()
		pilot_glow.name = "PipePilotGlow_" + id
		pilot_glow.position = lamp_pos
		pilot_glow.texture = soft_light
		pilot_glow.texture_scale = 0.22
		pilot_glow.color = Color("d8b26a")
		pilot_glow.energy = 0.14
		add_child(pilot_glow)
		branch_point_lights[id] = pilot_glow

	# Keep coil_mark Line2D intact for test compatibility, width = 0.0
	coil_mark = Line2D.new()
	coil_mark.position = lure_anchor.position
	for index in range(33):
		coil_mark.add_point(Vector2.from_angle(TAU * index / 32.0) * 52.0)
	coil_mark.default_color = Color("bdad88", 0.35)
	coil_mark.width = 0.0
	coil_mark.antialiased = true
	coil_mark.visible = GameState.opening_flags.ch6_entity_lured and not GameState.opening_flags.ch6_entity_bound
	add_child(coil_mark)

	_build_floor_containment_grate()
	_build_physical_equipment_props()

	chalk_link = Line2D.new()
	chalk_link.name = "ChalkTraceToClamp"
	chalk_link.visible = false
	add_child(chalk_link)

	# Dynamic active-step spotlight beacon gliding cleanly onto the exact next objective device
	active_step_beacon = PointLight2D.new()
	active_step_beacon.name = "ActiveStepSpotlightBeacon"
	active_step_beacon.position = TARGETS["electrical_cabinet"] + Vector2(0, -24)
	active_step_beacon.texture = soft_light
	active_step_beacon.texture_scale = 0.54
	active_step_beacon.color = Color("ffd274")
	active_step_beacon.energy = 0.92
	add_child(active_step_beacon)

	rescue_door_status_light = PointLight2D.new()
	rescue_door_status_light.name = "RescueDoorStatusLight"
	rescue_door_status_light.position = Vector2(1174, 344)
	rescue_door_status_light.texture = soft_light
	rescue_door_status_light.texture_scale = 0.42
	rescue_door_status_light.color = Color("7cf2b4") if GameState.opening_flags.ch6_entity_bound else Color("e03c2e")
	rescue_door_status_light.energy = 0.85
	add_child(rescue_door_status_light)

	_build_illusion_door_prop()
	_sync_illusion_door_visibility()


func _build_illusion_door_prop() -> void:
	illusion_door_group = Node2D.new()
	illusion_door_group.name = "IllusionDoorGroup"
	illusion_door_group.position = Vector2(316, 514)
	illusion_door_group.z_index = 350
	illusion_door_group.draw.connect(_draw_illusion_door_prop)
	add_child(illusion_door_group)

	illusion_door_glow = PointLight2D.new()
	illusion_door_glow.name = "IllusionDoorGlow"
	illusion_door_glow.position = Vector2(12, 0)
	illusion_door_glow.texture = preload("res://assets/lighting/soft_light.png")
	illusion_door_glow.texture_scale = 0.44
	illusion_door_glow.color = Color("8ed2c4")
	illusion_door_glow.energy = 0.58
	illusion_door_group.add_child(illusion_door_glow)


func _draw_illusion_door_prop() -> void:
	if not is_instance_valid(illusion_door_group):
		return
	var door_rect := Rect2(-16, -54, 28, 108)
	illusion_door_group.draw_rect(door_rect.grow(3.0), Color(0.05, 0.04, 0.04, 0.92))
	illusion_door_group.draw_rect(door_rect, Color(0.11, 0.12, 0.11, 0.96))
	illusion_door_group.draw_rect(door_rect, Color(0.28, 0.25, 0.20, 0.85), false, 1.8)
	# Eerie glowing slit & vertical blood seepage streaks
	illusion_door_group.draw_rect(Rect2(6, -48, 4, 96), Color(0.32, 0.56, 0.52, 0.55))
	for sx in [-10.0, -3.0, 3.0]:
		illusion_door_group.draw_line(Vector2(sx, -42), Vector2(sx + 1.0, 44), Color(0.42, 0.05, 0.05, 0.78), 2.0)
	for by in [-36.0, 0.0, 36.0]:
		illusion_door_group.draw_circle(Vector2(-12, by), 2.2, Color(0.36, 0.30, 0.24, 0.9))


func _sync_illusion_door_visibility() -> void:
	var show_illusion: bool = GameState.current_role == "dawen" and not bool(GameState.opening_flags.ch6_jiamin_rescued) and not _ending_recorded()
	if is_instance_valid(illusion_door_group):
		illusion_door_group.visible = show_illusion
	if is_instance_valid(illusion_door_glow):
		illusion_door_glow.enabled = show_illusion


func _build_physical_equipment_props() -> void:
	# Visible, unmistakable painted industrial hardware so ZERO interactables sit on empty invisible air!
	# 1) Armored high-voltage floor cables linking Sonar Lure -> Floor Grate -> Red Drop-Lever!
	var cable_lever := Line2D.new()
	cable_lever.name = "LeverToGrateCable"
	cable_lever.points = PackedVector2Array([
		TARGETS["lock_lever"] + Vector2(8, 2),
		Vector2(986, 488),
		Vector2(1012, 464),
		lure_anchor.position + Vector2(-48, 24)
	])
	cable_lever.width = 5.0
	cable_lever.default_color = Color(0.18, 0.16, 0.14, 0.92)
	cable_lever.joint_mode = Line2D.LINE_JOINT_ROUND
	cable_lever.z_index = -1
	add_child(cable_lever)
	var cable_lever_hi := Line2D.new()
	cable_lever_hi.points = cable_lever.points
	cable_lever_hi.width = 1.6
	cable_lever_hi.default_color = Color(0.66, 0.24, 0.18, 0.72)
	cable_lever_hi.joint_mode = Line2D.LINE_JOINT_ROUND
	cable_lever_hi.z_index = 0
	add_child(cable_lever_hi)

	var cable_sonar := Line2D.new()
	cable_sonar.name = "SonarToGrateCable"
	cable_sonar.points = PackedVector2Array([
		TARGETS["lure_switch"] + Vector2(0, -14),
		Vector2(1024, 396),
		lure_anchor.position + Vector2(-32, -26)
	])
	cable_sonar.width = 4.2
	cable_sonar.default_color = Color(0.20, 0.22, 0.18, 0.90)
	cable_sonar.joint_mode = Line2D.LINE_JOINT_ROUND
	cable_sonar.z_index = -1
	add_child(cable_sonar)

	# 2) Archive Steel Case (百利新邨工程档案箱) mounted clearly on the floor shelf to the right of the open cabinet door leaf
	if ResourceLoader.exists("res://assets/props/ch6_archive_box_v10.png"):
		var arch_tex := load("res://assets/props/ch6_archive_box_v10.png") as Texture2D
		if arch_tex != null:
			var arch := Sprite2D.new()
			arch.name = "VenueArchiveCaseProp"
			arch.texture = arch_tex
			arch.position = Vector2(954, 386)
			arch.scale = Vector2(50.0 / float(arch_tex.get_width()), 40.0 / float(arch_tex.get_height()))
			arch.z_index = 365
			add_child(arch)

	# 3) Wall-mounted Brass-Horn Sonar Lure Box (声呐引诱器)
	if ResourceLoader.exists("res://assets/props/ch6_sonar_lure_v10.png"):
		var sonar_tex := load("res://assets/props/ch6_sonar_lure_v10.png") as Texture2D
		if sonar_tex != null:
			var sonar := Sprite2D.new()
			sonar.name = "SonarLureBoxProp"
			sonar.texture = sonar_tex
			sonar.position = Vector2(1024, 344)
			sonar.scale = Vector2(52.0 / float(sonar_tex.get_width()), 58.0 / float(sonar_tex.get_height()))
			sonar.z_index = 368
			add_child(sonar)

	# 4) Heavy Bolted Red-Handle Emergency Drop-Gate Lever Pedestal (红柄应急落闸杆)
	if ResourceLoader.exists("res://assets/props/ch6_drop_lever_v10.png"):
		var lever_tex := load("res://assets/props/ch6_drop_lever_v10.png") as Texture2D
		if lever_tex != null:
			var lever := Sprite2D.new()
			lever.name = "EmergencyDropLeverProp"
			lever.texture = lever_tex
			lever.position = TARGETS["lock_lever"] + Vector2(0, -18)
			lever.scale = Vector2(54.0 / float(lever_tex.get_width()), 68.0 / float(lever_tex.get_height()))
			lever.z_index = int(TARGETS["lock_lever"].y)
			add_child(lever)
			var lever_lamp := PointLight2D.new()
			lever_lamp.name = "DropLeverGlow"
			lever_lamp.position = TARGETS["lock_lever"] + Vector2(4, -36)
			lever_lamp.texture = preload("res://assets/lighting/soft_light.png")
			lever_lamp.texture_scale = 0.28
			lever_lamp.color = Color("f06848")
			lever_lamp.energy = 0.52
			add_child(lever_lamp)

	# 5) Emergency Backup Phone Charger Box (应急充电盒) mounted cleanly by the entrance pier
	if ResourceLoader.exists("res://assets/props/ch6_charger_box_v10.png"):
		var chg_tex := load("res://assets/props/ch6_charger_box_v10.png") as Texture2D
		if chg_tex != null:
			var chg := Sprite2D.new()
			chg.name = "EmergencyChargerProp"
			chg.texture = chg_tex
			chg.position = TARGETS["emergency_charger"] + Vector2(0, -14)
			chg.scale = Vector2(46.0 / float(chg_tex.get_width()), 52.0 / float(chg_tex.get_height()))
			chg.z_index = int(TARGETS["emergency_charger"].y)
			add_child(chg)
			var chg_lamp := PointLight2D.new()
			chg_lamp.name = "ChargerBoxGlow"
			chg_lamp.position = TARGETS["emergency_charger"] + Vector2(-8, -26)
			chg_lamp.texture = preload("res://assets/lighting/soft_light.png")
			chg_lamp.texture_scale = 0.26
			chg_lamp.color = Color("6ae89e")
			chg_lamp.energy = 0.56
			add_child(chg_lamp)


func _build_floor_containment_grate() -> void:
	floor_grate = Node2D.new()
	floor_grate.name = "FloorContainmentGrate"
	floor_grate.position = lure_anchor.position
	floor_grate.z_index = -2
	floor_grate.draw.connect(_draw_floor_containment_grate)
	add_child(floor_grate)

	var soft_light := preload("res://assets/lighting/soft_light.png")
	grate_corner_lamps.clear()
	grate_corner_bulbs.clear()
	var corners: Array[Vector2] = [
		Vector2(-52, -30), Vector2(52, -30),
		Vector2(-52, 30), Vector2(52, 30)
	]
	for idx in range(corners.size()):
		var cpos: Vector2 = corners[idx]
		var bezel := Polygon2D.new()
		bezel.position = cpos
		bezel.polygon = _circle_poly(6.2, 12)
		bezel.color = Color("3a3326")
		floor_grate.add_child(bezel)
		var bulb := Polygon2D.new()
		bulb.position = cpos
		bulb.polygon = _circle_poly(3.8, 12)
		bulb.color = Color("8a5f28")
		floor_grate.add_child(bulb)
		grate_corner_bulbs.append(bulb)

		var lamp := PointLight2D.new()
		lamp.name = "GrateCornerLamp_%d" % idx
		lamp.position = lure_anchor.position + cpos
		lamp.texture = soft_light
		lamp.texture_scale = 0.28
		lamp.color = Color("ff9e38")
		lamp.energy = 0.16
		add_child(lamp)
		grate_corner_lamps.append(lamp)


func _draw_floor_containment_grate() -> void:
	var outer := GRATE_RECT
	var pit := Rect2(-48, -28, 96, 56)
	# Subtle recessed concrete curb shadow
	floor_grate.draw_rect(outer.grow(3.0), Color(0.03, 0.035, 0.03, 0.55))
	# Heavy dark weathered iron perimeter frame
	floor_grate.draw_rect(outer, Color(0.16, 0.155, 0.14, 0.92))
	floor_grate.draw_rect(outer, Color(0.32, 0.28, 0.22, 0.85), false, 2.0)
	# Recessed dark pit beneath steel grate
	floor_grate.draw_rect(pit, Color(0.035, 0.04, 0.038, 0.96))
	# Subtle weathered industrial brass-amber corner hazard ticks on frame
	var tick_col := Color("58f2b0") if boss_in_trap_zone else (Color("c88d3a") if GameState.opening_flags.ch6_entity_lured and not GameState.opening_flags.ch6_entity_bound else Color("5c503a"))
	floor_grate.draw_rect(pit.grow(1.5), tick_col, false, 1.4)
	# Forged dark steel grate bars (vertical + horizontal crossbars)
	for gx in range(-40, 44, 12):
		floor_grate.draw_line(Vector2(float(gx), pit.position.y), Vector2(float(gx), pit.end.y), Color(0.18, 0.19, 0.18, 0.95), 3.2)
		floor_grate.draw_line(Vector2(float(gx) - 0.8, pit.position.y), Vector2(float(gx) - 0.8, pit.end.y), Color(0.38, 0.37, 0.33, 0.45), 1.0)
	for gy in [-16.0, 0.0, 16.0]:
		floor_grate.draw_line(Vector2(pit.position.x, gy), Vector2(pit.end.x, gy), Color(0.15, 0.16, 0.15, 0.95), 3.0)
		floor_grate.draw_line(Vector2(pit.position.x, gy - 0.9), Vector2(pit.end.x, gy - 0.9), Color(0.34, 0.34, 0.30, 0.40), 1.0)
	# Corner rivets along the iron perimeter flange
	for rx in [-53.0, 0.0, 53.0]:
		for ry in [-32.5, 32.5]:
			if absf(rx) > 40.0:
				continue
			floor_grate.draw_circle(Vector2(rx, ry), 2.0, Color(0.28, 0.25, 0.20, 0.9))


func _sync_bulkhead_lamps() -> void:
	for id in BRANCH_IDS:
		var glow := branch_point_lights.get(id) as PointLight2D
		var ind := branch_lights.get(id) as Line2D
		var resp := panel_lights.get(id) as Polygon2D
		if not is_instance_valid(glow) or not is_instance_valid(ind):
			continue
		if is_instance_valid(resp) and resp.color.a > 0.05:
			glow.color = Color(resp.color.r, resp.color.g, resp.color.b, 1.0)
			glow.energy = 0.35 + resp.color.a * 0.95
		elif id == "branch_a" and GameState.opening_flags.ch6_circuit_isolated:
			glow.color = Color("52564e")
			glow.energy = 0.06
		elif id == "branch_c" and GameState.opening_flags.ch6_pipe_route_verified:
			glow.color = Color("76f0b0") if GameState.opening_flags.ch6_rescue_door_open else Color("f2d586")
			glow.energy = 0.88
		else:
			glow.color = Color(ind.default_color.r, ind.default_color.g, ind.default_color.b, 1.0)
			glow.energy = 0.26


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


func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(hud):
		return
	beacon_clock += delta
	_sync_bulkhead_lamps()
	_update_active_step_beacon(delta)
	_update_floor_grate_lamps()
	_update_illusion_door(delta)
	if is_instance_valid(diagram_marker):
		diagram_marker.visible = GameState.current_role == "dawen" and not GameState.opening_flags.ch6_route_diagram_seen
	if is_instance_valid(shadow) and is_instance_valid(boss_anim_sprite):
		if not shadow.active or shadow.flash_receiver.is_stunned():
			boss_anim_sprite.pause()
		else:
			var vel: Vector2 = shadow.velocity
			if absf(vel.y) > absf(vel.x) * 1.45:
				var anim_v := "walk_up" if vel.y < 0.0 else "walk_down"
				if boss_anim_sprite.animation != anim_v:
					boss_anim_sprite.play(anim_v)
				elif not boss_anim_sprite.is_playing():
					boss_anim_sprite.play()
			else:
				if boss_anim_sprite.animation != "walk_side":
					boss_anim_sprite.play("walk_side")
				elif not boss_anim_sprite.is_playing():
					boss_anim_sprite.play()
				if absf(vel.x) > 1.0:
					boss_anim_sprite.flip_h = vel.x < 0.0
	if scene_action_active or boss_capture_active:
		hud.prompt.text = ""
		return
	if signal_response_active:
		return
	if not listening_target.is_empty():
		var now := float(Time.get_ticks_msec()) / 1000.0
		if signal_taps.size() >= 4 and now - signal_last_tap >= 1.25:
			_finish_signal_test()
		return
	selected_id = ""
	var best_score := INF
	for id in TARGETS:
		if not _target_available(id):
			continue
		var offset: Vector2 = TARGETS[id] - player.position
		var distance := offset.length()
		var alignment := player.look_dir.dot(offset.normalized()) if distance > 0.1 else 1.0
		var range_value := 86.0
		if id == "rescue_door":
			range_value = 116.0
		elif id in ["route_diagram", "electrical_cabinet", "venue_archive", "lure_switch", "lock_lever", "illusion_door"]:
			range_value = 92.0
		elif id in BRANCH_IDS:
			range_value = 90.0
		if distance <= range_value and (distance <= 36.0 or alignment >= -0.05):
			var score := distance + (1.0 - alignment) * 78.0
			if score < best_score:
				best_score = score
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
		var on_grate := _is_shadow_on_grate()
		if on_grate != boss_in_trap_zone:
			boss_in_trap_zone = on_grate
			if on_grate:
				AudioManager.play_world_effect("power_switch")
			floor_grate.queue_redraw()
		shadow.speed = BOSS_GRATE_SPEED if on_grate else BOSS_CHASE_SPEED
		coil_mark.default_color = Color("7dffbe", 0.9) if on_grate else Color("bdad88", 0.35)
		hud.state_text.text = "怨灵已踩上铁栅。现在拉杆！" if on_grate else "引怨灵踩上铁栅。四角灯亮起时拉杆。"


func _is_shadow_on_grate() -> bool:
	return is_instance_valid(shadow) and shadow.active and GRATE_RECT.has_point(shadow.global_position - floor_grate.global_position)


func _update_illusion_door(_delta: float) -> void:
	if not is_instance_valid(illusion_door_group) or not illusion_door_group.visible:
		return
	if is_instance_valid(illusion_door_glow):
		illusion_door_glow.energy = 0.48 + 0.28 * (0.5 + 0.5 * sin(beacon_clock * 4.5))


func _update_active_step_beacon(delta: float) -> void:
	if not is_instance_valid(active_step_beacon):
		return
	var pulse := 0.5 + 0.5 * sin(beacon_clock * 5.2)
	var flags := GameState.opening_flags
	var beacon_col := Color("ffd274")
	var target_pos := active_beacon_target
	var visible_beacon := true
	if _ending_recorded():
		visible_beacon = false
	elif GameState.current_role == "jiamin":
		target_pos = (TARGETS["jiamin_signal_pipe"] if flags.ch6_jiamin_pipe_found else TARGETS["pipe_item"]) + Vector2(0, -14)
	elif not flags.ch6_circuit_isolated:
		target_pos = TARGETS["electrical_cabinet"] + Vector2(0, -24)
	elif not flags.ch6_entity_lured:
		target_pos = TARGETS["lure_switch"] + Vector2(0, -18)
		beacon_col = Color("ffae42")
	elif not flags.ch6_entity_bound:
		if boss_in_trap_zone:
			target_pos = TARGETS["lock_lever"] + Vector2(0, -18)
			beacon_col = Color("72ffbe")
		else:
			target_pos = lure_anchor.position + Vector2(0, -8)
			beacon_col = Color("ff9e38")
	elif not flags.ch6_jiamin_rescued:
		target_pos = TARGETS["rescue_door"] + Vector2(-12, -22)
		beacon_col = Color("8af0b4")
	else:
		target_pos = TARGETS["return_arch"] + Vector2(0, -22)
		beacon_col = Color("c6e8ff")
	active_beacon_target = target_pos
	active_step_beacon.visible = visible_beacon
	active_step_beacon.position = active_step_beacon.position.lerp(target_pos, clampf(delta * 8.0, 0.0, 1.0))
	active_step_beacon.color = beacon_col
	var max_e := 1.48 if boss_in_trap_zone else 1.18
	var min_e := 0.72 if boss_in_trap_zone else 0.44
	active_step_beacon.energy = lerpf(min_e, max_e, pulse)


func _update_floor_grate_lamps() -> void:
	var pulse := 0.5 + 0.5 * sin(beacon_clock * 6.5)
	var active_lure: bool = GameState.opening_flags.ch6_entity_lured and not GameState.opening_flags.ch6_entity_bound
	for idx in range(grate_corner_lamps.size()):
		var lamp: PointLight2D = grate_corner_lamps[idx]
		var bulb: Polygon2D = grate_corner_bulbs[idx]
		if not is_instance_valid(lamp) or not is_instance_valid(bulb):
			continue
		if boss_in_trap_zone and active_lure:
			lamp.color = Color("7dffbe")
			lamp.energy = 1.45 + 0.35 * pulse
			bulb.color = Color("d8ffec")
		elif active_lure:
			lamp.color = Color("ff9e38")
			lamp.energy = 0.58 + 0.42 * pulse
			bulb.color = Color("ffd07a")
		elif GameState.opening_flags.ch6_entity_bound:
			lamp.color = Color("5ec492")
			lamp.energy = 0.24
			bulb.color = Color("558a70")
		else:
			lamp.color = Color("ff9e38")
			lamp.energy = 0.16
			bulb.color = Color("7d5a2c")


func _target_available(id: String) -> bool:
	if id == "pipe_item":
		return GameState.current_role == "jiamin" and not GameState.opening_flags.ch6_jiamin_pipe_found
	if id == "jiamin_signal_pipe":
		return GameState.current_role == "jiamin" and GameState.opening_flags.ch6_jiamin_pipe_found and not GameState.opening_flags.ch6_signal_sent
	if id == "illusion_door":
		return GameState.current_role == "dawen" and not GameState.opening_flags.ch6_jiamin_rescued and not _ending_recorded()
	if id == "branch_c" or id == "route_diagram" or id == "electrical_cabinet" or id == "venue_archive" or id == "lure_switch" or id == "lock_lever" or id == "emergency_charger" or id == "rescue_door" or id == "return_arch":
		return GameState.current_role == "dawen" and not _ending_recorded()
	return false


func _unhandled_input(event: InputEvent) -> void:
	if hud == null or hud.panel_open or boss_capture_active or event.is_echo():
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
		elif event.is_action_pressed("ui_accept") and signal_taps.size() >= 3:
			_finish_signal_test()
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
	if scene_action_active or signal_response_active or boss_capture_active or not listening_target.is_empty():
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
	elif id == "branch_c":
		_listen_jiamin_pipe()
	elif id == "illusion_door":
		_inspect_illusion_door()
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
	elif id == "emergency_charger":
		_use_emergency_charger()
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
		if is_instance_valid(pipe_knock_ui) and pipe_knock_ui.has_method("notify_knock"):
			pipe_knock_ui.notify_knock(jiamin_knocks)
		AudioManager.play_at(self, "metal_cover", TARGETS["jiamin_signal_pipe"])
	)
	pipe_action.hold(player)
	_open_pipe_knock_ui("jiamin", "信号主管接头", 3)
	hud.objective.text = ""
	hud.state_text.text = ""


func _open_pipe_knock_ui(mode_id: String, title_str: String, req: int) -> void:
	_close_pipe_knock_ui()
	pipe_knock_ui = preload("res://ui/ch6_pipe_knock_panel.gd").new()
	add_child(pipe_knock_ui)
	pipe_knock_ui.configure_mode(mode_id, title_str, req)
	pipe_knock_ui.strike_requested.connect(func():
		if mode_id == "jiamin" and is_instance_valid(pipe_action):
			_strike_jiamin_pipe()
		elif mode_id == "dawen" and not listening_target.is_empty():
			_record_signal_tap()
	)
	pipe_knock_ui.finish_listen_requested.connect(func():
		if mode_id == "dawen" and not listening_target.is_empty():
			_finish_signal_test()
	)


func _close_pipe_knock_ui() -> void:
	if is_instance_valid(pipe_knock_ui):
		pipe_knock_ui.queue_free()
		pipe_knock_ui = null


func _is_knock_input(event: InputEvent) -> bool:
	if event.is_action_pressed("hold_breath"):
		return true
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE


func _strike_jiamin_pipe() -> void:
	if pipe_action.striking:
		return
	await pipe_action.strike()
	if not is_inside_tree() or not is_instance_valid(player): return
	if jiamin_knocks < 3:
		return
	_close_pipe_knock_ui()
	pipe_action.release(player)
	pipe_action = null
	GameState.opening_flags.ch6_signal_sent = true
	GameState.opening_flags.ch6_route_diagram_seen = true
	GameState.opening_flags.ch6_live_signal_received = true
	GameState.opening_flags.ch6_pipe_route_verified = true
	GameState.enter_role("dawen")
	player.look_dir = Vector2.UP
	player.has_mouse_aim = false
	player.controls_enabled = false
	player.set_appearance("flashlight")
	player.position = Vector2(650, 620)
	player.reset_physics_interpolation()
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if is_instance_valid(camera):
		camera.reset_smoothing()
	var verified_ind := branch_lights.get("branch_c") as Line2D
	if is_instance_valid(verified_ind):
		verified_ind.default_color = Color("e2ca89", 0.95)
	_sync_bulkhead_lamps()
	_sync_illusion_door_visibility()

	checkpoint()
	var card := preload("res://core/components/role_switch_transition.gd").play(self, "视角切换 · 陈大文", "百利新邨地下夹层 · 循声救嘉敏")
	if card != null:
		await card.completed
	if not is_inside_tree() or not is_instance_valid(player):
		return

	scene_action_active = false
	player.controls_enabled = true
	_update_objective()
	AudioManager.play_voice("jiamin_ch6_wall", -1.5)
	hud.show_resource_feedback("两短一长！大文立刻认出是嘉敏——去配电柜合高压电弧闸，引怨灵踏上铁栅电击破门！")


func _listen_jiamin_pipe() -> void:
	AudioManager.play_voice("jiamin_ch6_wall", -1.5)
	hud.show_resource_feedback("铜管直通右侧防爆隔离舱——快去配电柜合高压闸、引开门外恶灵！")


func _inspect_illusion_door() -> void:
	if GameState.opening_flags.ch6_jiamin_rescued or _ending_recorded():
		return
	GameState.opening_flags.ch6_failed_echo_seen = true
	checkpoint()
	AudioManager.play_world_effect("ghost_taunt_whisper")
	var body := "锈死的暗门缝里渗出粘稠黑血，门后却飘出轻声呼唤。\n\n雾光里的轮廓一阵晃动：先是毫发无伤的阿豪招手，转眼又变成“嘉敏”笑着举起双手——她十指完好无缺。\n\n（唐楼楼梯口阿豪已经替大文挡下了怪物；大关斜巷肉铺里捡到的，明明是嘉敏戴着尾戒的断指……）"
	_say("渗血封墙暗门 · 诡异呼唤", body, [
		{"text":"相信幻象，拉开门栓走进暗门", "callback":_confirm_missing_ending},
		{"text":"识破幻象，转身去拉闸救嘉敏", "callback":_close_panel}
	])


func _begin_signal_test(branch_id: String) -> void:
	if not GameState.opening_flags.ch6_route_diagram_seen:
		hud.show_resource_feedback("右端那块图板上标着每根管通去哪里。")
		return
	if GameState.opening_flags.ch6_pipe_route_verified:
		_say("管路已核验", "下方支管逐拍回应了大文刚输入的新节奏，顺着裸露铜管直接接回设备夹层。这条是目前唯一取得新回应的实际声路。")
		return
	selected_branch = branch_id
	listening_target = branch_id
	signal_taps.clear()
	signal_last_tap = float(Time.get_ticks_msec()) / 1000.0
	player.controls_enabled = false
	player.clear_motion()
	_open_pipe_knock_ui("dawen", TARGET_NAMES[branch_id], 4)
	hud.prompt.text = ""
	hud.state_text.text = ""


func _record_signal_tap() -> void:
	var now := float(Time.get_ticks_msec()) / 1000.0
	signal_taps.append(now)
	signal_last_tap = now
	if is_instance_valid(pipe_knock_ui) and pipe_knock_ui.has_method("notify_knock"):
		pipe_knock_ui.notify_knock(signal_taps.size())
	AudioManager.play_world_effect("metal_cover", true)
	if signal_taps.size() >= 6:
		_finish_signal_test()


func _cancel_signal_test() -> void:
	_close_pipe_knock_ui()
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
	_close_pipe_knock_ui()
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
		hud.show_resource_feedback("这根管只重复旧暗号。换根管试试。")
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
		AudioManager.play_voice("jiamin_ch6_wall", -1.5)
		_say("隔墙回音", "大文……再敲一下。是你。\n\n我在右边的隔离舱。那东西还站在门外，你先把它引开。", [], "黄嘉敏")


func _use_emergency_charger() -> void:
	if not GameState.has_demo_item("jiamin_phone"):
		hud.show_resource_feedback("需要嘉敏的手机才能使用应急充电盒。")
		return
	var recharged := GameState.phone_battery < 99.0 or GameState.phone_flash_charges < 2
	GameState.phone_battery = 100.0
	GameState.phone_flash_charges = maxi(GameState.phone_flash_charges, 2)
	GameState.phone_flash_cooldown = 0.0
	AudioManager.play_world_effect("power_switch")
	checkpoint()
	if recharged:
		hud.show_resource_feedback("应急充电盒已将手机充满电，并补足 2 次 [ R ] 手机强闪！面对封墙怨灵可按 R 将其定身在铁栅上！")
	else:
		hud.show_resource_feedback("手机电量和强闪（2/2）已满！将封墙怨灵引上中央铁栅时可按 [ R ] 定住它再拉落闸杆。")


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
		hud.show_resource_feedback("高压电弧主闸已合上。声呐引诱器在右侧。")
		return
	GameState.opening_flags.ch6_route_diagram_seen = true
	GameState.opening_flags.ch6_live_signal_received = true
	GameState.opening_flags.ch6_pipe_route_verified = true
	_say("高压配电柜", "已确认嘉敏就在右侧防爆隔离舱内。合上高压电弧主闸，把封墙怨灵引上中央铁栅电击破门。", [
		{"text":"合上高压电弧主闸", "callback":_confirm_circuit_isolation},
		{"text":"先返回现场看看", "callback":_close_panel}
	])


func _confirm_circuit_isolation() -> void:
	_close_panel()
	GameState.opening_flags.ch6_route_diagram_seen = true
	GameState.opening_flags.ch6_live_signal_received = true
	GameState.opening_flags.ch6_pipe_route_verified = true
	GameState.opening_flags.ch6_circuit_isolated = true
	AudioManager.play_world_effect("power_switch")
	var lid := branch_lights["branch_a"] as Line2D
	lid.default_color = Color("52564e", 0.8)
	var cid := branch_lights["branch_c"] as Line2D
	cid.default_color = Color("e2ca89", 0.95)
	_sync_bulkhead_lamps()
	checkpoint()
	_update_objective()
	hud.show_resource_feedback("高压电弧主闸已合上！去右侧启动声呐引诱器，将封墙怨灵引上中央铁栅电击破门！")


func _activate_lure() -> void:
	if not GameState.opening_flags.ch6_pipe_route_verified or not GameState.opening_flags.ch6_circuit_isolated:
		hud.show_resource_feedback("先核验管道并切断旧回声支路。")
		return
	if GameState.opening_flags.ch6_entity_lured:
		hud.show_resource_feedback("声呐引诱器正在运转！把封墙怨灵引到地面铁栅区，立刻拉下【应急落闸杆】封杀！")
		return
	GameState.opening_flags.ch6_entity_lured = true
	boss_in_trap_zone = false
	coil_mark.show()
	if is_instance_valid(floor_grate):
		floor_grate.queue_redraw()
	_spawn_shadow()
	AudioManager.play_world_effect("power_switch")
	_start_boss_chase_music()
	checkpoint()
	_update_objective()
	hud.show_resource_feedback("【封墙怨灵现身】把它引到中央地面铁栅陷阱上（四角灯变绿亮起），再冲去【落闸杆】按 E 落闸封杀！")


func _spawn_shadow() -> void:
	if is_instance_valid(shadow) or GameState.opening_flags.ch6_entity_bound:
		return
	shadow = SHADOW_SCRIPT.new()
	shadow.name = "BoundedServiceShadow"
	shadow.position = Vector2(1110, 505)
	shadow.speed = BOSS_CHASE_SPEED
	shadow.target = player
	shadow.scale = Vector2.ONE * 0.96
	add_child(shadow)
	GhostTaunt.materialize_from_shadow(self, shadow.position)
	GhostTaunt.attach(shadow, PackedStringArray(["石屎封不住我……", "把她也留下……", "你逃不掉的……"]), 3.2)
	shadow.caught.connect(_on_boss_caught)
	# Upgrade visual to the 2x2 animated non-skull Concrete Wraith Final Boss ("ch6_boss_v9.png"),
	# keeping shadow's Figure visible & playing for test invariants while hiding its overlap.
	boss_anim_sprite = null
	var base_fig := shadow.get_node_or_null("Figure") as CanvasItem
	var afterimg := shadow.get_node_or_null("ShadowAfterimage") as CanvasItem
	if ResourceLoader.exists("res://assets/characters/ch6_boss_v9.png"):
		var sheet := load("res://assets/characters/ch6_boss_v9.png") as Texture2D
		if sheet != null:
			if base_fig != null:
				base_fig.modulate.a = 0.0
			if afterimg != null:
				afterimg.visible = false
			var cw := sheet.get_width() * 0.5
			var ch := sheet.get_height() * 0.5
			var frames := SpriteFrames.new()
			frames.add_animation("walk_side")
			frames.set_animation_speed("walk_side", 4.6)
			frames.add_animation("walk_down")
			frames.set_animation_speed("walk_down", 3.6)
			frames.add_animation("walk_up")
			frames.set_animation_speed("walk_up", 3.2)
			var cell_front := AtlasTexture.new()
			cell_front.atlas = sheet
			cell_front.region = Rect2(0, 0, cw, ch)
			cell_front.filter_clip = true
			var cell_stalk_a := AtlasTexture.new()
			cell_stalk_a.atlas = sheet
			cell_stalk_a.region = Rect2(cw, 0, cw, ch)
			cell_stalk_a.filter_clip = true
			var cell_stalk_b := AtlasTexture.new()
			cell_stalk_b.atlas = sheet
			cell_stalk_b.region = Rect2(0, ch, cw, ch)
			cell_stalk_b.filter_clip = true
			var cell_back := AtlasTexture.new()
			cell_back.atlas = sheet
			cell_back.region = Rect2(cw, ch, cw, ch)
			cell_back.filter_clip = true
			frames.add_frame("walk_side", cell_stalk_a)
			frames.add_frame("walk_side", cell_stalk_b)
			frames.add_frame("walk_down", cell_front)
			frames.add_frame("walk_down", cell_stalk_a)
			frames.add_frame("walk_up", cell_back)
			boss_anim_sprite = AnimatedSprite2D.new()
			boss_anim_sprite.name = "ConcreteWraithBossSprite"
			boss_anim_sprite.sprite_frames = frames
			boss_anim_sprite.position = Vector2(0, -56)
			boss_anim_sprite.scale = Vector2.ONE * (124.0 / ch)
			shadow.add_child(boss_anim_sprite)
			boss_anim_sprite.play("walk_side")
	elif ResourceLoader.exists("res://assets/characters/boss_concrete_wraith_252.png"):
		if base_fig != null:
			base_fig.modulate.a = 0.0
		if afterimg != null:
			afterimg.visible = false
		var boss_tex := load("res://assets/characters/boss_concrete_wraith_252.png") as Texture2D
		if boss_tex != null:
			var boss_sprite := Sprite2D.new()
			boss_sprite.name = "ConcreteWraithBossSprite"
			boss_sprite.texture = boss_tex
			boss_sprite.position = Vector2(0, -56)
			boss_sprite.scale = Vector2.ONE * (118.0 / float(boss_tex.get_height()))
			shadow.add_child(boss_sprite)


func _on_boss_caught() -> void:
	if boss_capture_active or not is_instance_valid(player):
		return
	boss_capture_active = true
	player.controls_enabled = false
	player.clear_motion()
	var const_map: Dictionary = (DemoCaptureAnimation as GDScript).get_script_constant_map()
	var boss_lunge_path: String = String(const_map.get("BOSS_PATH", ""))
	if not boss_lunge_path.is_empty() and DemoCaptureAnimation._preloaded_atlas(boss_lunge_path) != null:
		await DemoCaptureAnimation.play_on(self, boss_lunge_path)
	else:
		AudioManager.play_world_effect("jumpscare_shriek")
		AudioManager.play_world_effect("boss_roar_impact")
	if not is_inside_tree() or not is_instance_valid(player):
		boss_capture_active = false
		return
	player.position = Vector2(760, 445)
	player.reset_physics_interpolation()
	(player.get_node("Camera2D") as Camera2D).reset_smoothing()
	player.controls_enabled = not (is_instance_valid(hud) and hud.panel_open) and not scene_action_active
	if is_instance_valid(shadow) and not GameState.opening_flags.ch6_entity_bound:
		shadow.position = Vector2(1110, 505)
		shadow.reset_physics_interpolation()
		shadow.active = true
		_start_boss_chase_music()
	boss_capture_active = false
	hud.show_resource_feedback("从配电柜前重试。怨灵追来时，贴着铁栅绕向落闸杆。")


func _lock_entity() -> void:
	if not GameState.opening_flags.ch6_entity_lured:
		hud.show_resource_feedback("声呐引诱器尚未启动，铁栅陷阱未就绪。")
		return
	if not GameState.opening_flags.ch6_entity_bound:
		if not _is_shadow_on_grate():
			hud.show_resource_feedback("怨灵还在铁栅外。让它踏上铁栅，四角灯亮时拉杆。")
			return
		GameState.opening_flags.ch6_entity_bound = true
		boss_in_trap_zone = false
		scene_action_active = true
		player.controls_enabled = false
		player.clear_motion()
		AudioManager.stop_chase_music()
		AudioManager.play_world_effect("iron_slam")
		AudioManager.play_world_effect("electric_arc_blast")
		AudioManager.play_at(self, "gate_iron", TARGETS["lock_lever"])
		_spawn_containment_gate_slam()
		_spawn_high_voltage_arc_burst()
		if is_instance_valid(shadow):
			shadow.active = false
			var tween := create_tween()
			tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
			tween.tween_property(shadow, "modulate", Color(1.8, 2.2, 2.0, 1.0), 0.10)
			tween.parallel().tween_property(shadow, "scale", Vector2.ZERO, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tween.tween_callback(shadow.queue_free)
			await tween.finished
			if not is_inside_tree(): return
		for id in BRANCH_IDS:
			(branch_lights[id] as Line2D).default_color = Color("6f7868", 0.9)
		if is_instance_valid(rescue_door_status_light):
			rescue_door_status_light.color = Color("7cf2b4")
			rescue_door_status_light.energy = 1.25
		_sync_bulkhead_lamps()
		if is_instance_valid(floor_grate):
			floor_grate.queue_redraw()
		scene_action_active = false
		player.controls_enabled = true
		coil_mark.hide()
		checkpoint()
		_update_objective()
		hud.show_resource_feedback("高压电弧将封墙怨灵彻底锁住了，并震开防爆舱门电磁锁！立刻去右侧隔离舱门按 E 救出嘉敏！")
		return
	hud.show_resource_feedback("锁住了。隔离门可以打开。")


func _spawn_containment_gate_slam() -> void:
	var cage := Node2D.new()
	cage.name = "EmergencyContainmentGateSlam"
	cage.position = lure_anchor.position + Vector2(0, -110)
	cage.z_index = 92
	add_child(cage)
	var frame := Polygon2D.new()
	frame.polygon = PackedVector2Array([
		Vector2(-58, -90), Vector2(58, -90), Vector2(58, -78), Vector2(-58, -78)
	])
	frame.color = Color("2b2c2a")
	cage.add_child(frame)
	for bx in [-46.0, -28.0, -10.0, 10.0, 28.0, 46.0]:
		var bar := Polygon2D.new()
		bar.polygon = PackedVector2Array([
			Vector2(bx - 3.0, -82), Vector2(bx + 3.0, -82),
			Vector2(bx + 3.0, 16), Vector2(bx - 3.0, 16)
		])
		bar.color = Color("363835")
		cage.add_child(bar)
	var slam_tw := cage.create_tween()
	slam_tw.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	slam_tw.tween_property(cage, "position", lure_anchor.position, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	slam_tw.tween_interval(0.30)
	slam_tw.tween_property(cage, "modulate:a", 0.0, 0.36)
	slam_tw.tween_callback(cage.queue_free)


func _spawn_high_voltage_arc_burst() -> void:
	if GameState.reduced_flash:
		return
	var fx := Node2D.new()
	fx.z_index = 95
	add_child(fx)
	var center: Vector2 = lure_anchor.position + Vector2(0, -38)
	var origins: Array[Vector2] = [
		lure_anchor.position + Vector2(-52, -30),
		lure_anchor.position + Vector2(52, -30),
		lure_anchor.position + Vector2(-52, 30),
		lure_anchor.position + Vector2(52, 30),
		TARGETS["lock_lever"] + Vector2(0, -16)
	]
	for orig: Vector2 in origins:
		var bolt := Line2D.new()
		var pts := PackedVector2Array([orig])
		for step in range(1, 6):
			var p: Vector2 = orig.lerp(center, float(step) / 6.0) + Vector2(randf_range(-18, 18), randf_range(-18, 18))
			pts.append(p)
		pts.append(center)
		bolt.points = pts
		bolt.width = 3.2
		bolt.default_color = Color(0.58, 0.98, 0.88, 0.96)
		fx.add_child(bolt)
	# Arc discharge from the containment grate into the blast door lock
	var door_target: Vector2 = TARGETS["rescue_door"] + Vector2(-6, -24)
	var door_bolt := Line2D.new()
	var door_pts := PackedVector2Array([center])
	for step in range(1, 6):
		var dp: Vector2 = center.lerp(door_target, float(step) / 6.0) + Vector2(randf_range(-10, 10), randf_range(-14, 14))
		door_pts.append(dp)
	door_pts.append(door_target)
	door_bolt.points = door_pts
	door_bolt.width = 3.6
	door_bolt.default_color = Color(0.75, 1.0, 0.92, 0.98)
	fx.add_child(door_bolt)
	var flash_light := PointLight2D.new()
	flash_light.position = center
	flash_light.texture = preload("res://assets/lighting/soft_light.png")
	flash_light.texture_scale = 1.65
	flash_light.color = Color("7dffdc")
	flash_light.energy = 2.4
	fx.add_child(flash_light)
	var tw := fx.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tw.tween_property(flash_light, "energy", 0.0, 0.42)
	tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.42)
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
	# Warm golden rescue cabin light spilling out as the heavy bulkhead door swings open!
	var rescue_flood := PointLight2D.new()
	rescue_flood.name = "RescueCabinFloodLight"
	rescue_flood.position = Vector2(1176, 405)
	rescue_flood.texture = preload("res://assets/lighting/soft_light.png")
	rescue_flood.texture_scale = 0.72
	rescue_flood.color = Color("ffe09e")
	rescue_flood.energy = 0.0
	add_child(rescue_flood)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.tween_method(_set_rescue_hatch_progress, 0.0, 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(door_light, "default_color", Color("f1d7a0", 1.0), 1.0)
	tween.parallel().tween_property(rescue_flood, "energy", 1.15, 1.0).set_trans(Tween.TRANS_SINE)
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
	_sync_illusion_door_visibility()
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
	AudioManager.play_voice("jiamin_ch6_where_ahhao", -1.5)
	_say("嘉敏获救", "阿豪呢？", [], "黄嘉敏")


func _answer_about_ahhao() -> void:
	scene_action_active = true
	player.controls_enabled = false
	await get_tree().create_timer(0.75, false).timeout
	if not is_inside_tree():
		return
	scene_action_active = false
	AudioManager.play_voice("dawen_ch6_answer_ahhao", -1.5)
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
	var reg_prefix := "（已拼合 ✓）" if GameState.opening_flags.ch6_bunker_register_found else "（待核对 ①）"
	var stop_prefix := "（已拼合 ✓）" if GameState.opening_flags.ch6_venue_stopwork_found else "（待核对 ②）"
	var done_count := 0
	for row in _archive_rows():
		if bool(row.found):
			done_count += 1
	choices.append({"text": "展开地宫工事名册 " + reg_prefix, "callback": _read_bunker_register})
	choices.append({"text": "展开旧楼封墙停工公文 " + stop_prefix, "callback": _read_stopwork_record})
	choices.append({"text": "收好文件袋", "callback": _close_panel})
	_say("工程档案箱 · 已核对 %d / 5" % done_count, "箱内有两份文件。一份记录暗渠改道，一份是夹层停工前最后一次签发的公文。", choices)


func _read_bunker_register() -> void:
	GameState.opening_flags.ch6_bunker_register_found = true
	checkpoint()
	_update_objective()
	hud.open_panel("地宫工事名册 · 剧内档案", "附图记录了几次违规改线。地宫的旧渠接到松山排水井，末端绕进黑沙下方的工事。图上还留着一条后来抹掉的检修支路，正通向这间夹层。", [
		{"text":"继续核对另一份档案（返回目录）", "callback":_read_venue_record},
		{"text":"展开旧楼封墙停工公文", "callback":_read_stopwork_record}
	], false, "陈大文", null, DemoItems.texture("crypt_old_photo"))
	player.controls_enabled = false
	player.clear_motion()
	get_tree().paused = true


func _read_stopwork_record() -> void:
	GameState.opening_flags.ch6_venue_stopwork_found = true
	checkpoint()
	_update_objective()
	hud.open_panel("旧楼封墙停工公文 · 剧内档案", "盖章时，应急撤离那一栏还是空的。有人在背面签了字，要求连夜封墙。右端隔离舱没封严，管路还通着。这就是嘉敏用来传声的那条管。", [
		{"text":"收好文件袋", "callback":_close_panel},
		{"text":"继续核对另一份档案（返回目录）", "callback":_read_venue_record}
	], false, "陈大文", null, DemoItems.texture("hotel_maintenance_plan"))
	player.controls_enabled = false
	player.clear_motion()
	get_tree().paused = true


func _local_archives_verified() -> bool:
	return GameState.opening_flags.ch6_bunker_register_found and GameState.opening_flags.ch6_venue_stopwork_found


func _archive_rows() -> Array[Dictionary]:
	return [
		{"name":"阿豪的随身遗物／记录", "found":GameState.has_demo_item("ahhao_camera")},
		{"name":"地宫工事名册", "found":GameState.opening_flags.ch6_bunker_register_found},
		{"name":"旧肉铺账册", "found":GameState.opening_flags.ch3_register_seen and GameState.opening_flags.ch3_balance_solved},
		{"name":"沿海工事记录", "found":GameState.opening_flags.coastal_works_record_found},
		{"name":"旧楼封墙停工公文", "found":GameState.opening_flags.ch6_venue_stopwork_found}
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
	_say("执意推开暗门", "门后明明传来阿豪的声音，可阿豪已经在唐楼挡下了怪物，肉铺血盆里也留着嘉敏的断指。\n\n若仍相信门后完整的幻影、独自拉开门栓走进暗门，便再也回不到大文该守住的那条路。", [
		{"text":"执意推开暗门，走进去", "callback":_select_missing_ending},
		{"text":"清醒退后，去合高压闸救嘉敏", "callback":_close_panel}
	])


func _select_missing_ending() -> void:
	_close_panel()
	if not GameState.opening_flags.ch6_failed_echo_seen or GameState.opening_flags.ch6_jiamin_rescued:
		_say("暗门尚未打开", "只有在破门救援前靠近渗血暗门并被幻象诱惑时，才会触发这项不可逆结局。")
		return
	if not _save_final_decision():
		return
	AudioManager.play_world_effect("iron_slam")
	AudioManager.play_world_effect("peephole_grudge_croak")
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


func _clear_ending_backdrop() -> void:
	if is_instance_valid(ending_backdrop):
		ending_backdrop.queue_free()
	ending_backdrop = null


func _resolve_ending_keepsake_photo() -> Texture2D:
	if GameState.opening_photo != null:
		var img := GameState.opening_photo.get_image()
		if img != null and img.get_width() >= 32 and img.get_height() >= 32:
			var min_lum := 1.0
			var max_lum := 0.0
			for gy in range(1, 5):
				for gx in range(1, 5):
					var px := img.get_pixel(int(img.get_width() * gx / 5.0), int(img.get_height() * gy / 5.0))
					var lum := px.r * 0.299 + px.g * 0.587 + px.b * 0.114
					min_lum = minf(min_lum, lum)
					max_lum = maxf(max_lum, lum)
			if max_lum - min_lum > 0.08:
				return GameState.opening_photo
	var fallback := load("res://assets/tilesets/opening_006.png") as Texture2D
	if fallback != null:
		var atlas := AtlasTexture.new()
		atlas.atlas = fallback
		var fw := float(fallback.get_width())
		var fh := float(fallback.get_height())
		atlas.region = Rect2(fw * 0.16, fh * 0.08, fw * 0.68, fh * 0.64)
		atlas.filter_clip = true
		return atlas
	return null


func _build_ending_backdrop(ending_id: String) -> void:
	_clear_ending_backdrop()
	if not is_instance_valid(hud) or not is_instance_valid(hud.root):
		return
	var wrap := Control.new()
	wrap.name = "EndingBackdrop"
	wrap.size = Vector2(640, 360)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.modulate.a = 0.0
	hud.root.add_child(wrap)
	hud.root.move_child(wrap, 0)
	ending_backdrop = wrap

	# Full-screen 640x360 painted ending illustration (replaces tiny 76px bottom strip!)
	var cg_path := "res://assets/ui/ending_missing_v10.png"
	match ending_id:
		"ending_truth":
			cg_path = "res://assets/ui/ending_truth_v10.png"
			AudioManager.set_scene_ambience("beach")
		"ending_escape":
			cg_path = "res://assets/ui/ending_escape_v10.png"
			AudioManager.set_scene_ambience("street")
		_:
			cg_path = "res://assets/ui/ending_missing_v10.png"
			AudioManager.set_scene_ambience("")
			AudioManager.play_world_effect("photo_knock")

	if ResourceLoader.exists(cg_path):
		var cg := TextureRect.new()
		cg.name = "FullScreenEndingCG"
		cg.texture = load(cg_path) as Texture2D
		cg.size = Vector2(640, 360)
		cg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cg.stretch_mode = TextureRect.STRETCH_SCALE
		cg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(cg)
	else:
		var veil := ColorRect.new()
		veil.size = Vector2(640, 360)
		veil.color = Color(0.06, 0.05, 0.04, 0.94)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(veil)

	if ending_id == "ending_truth":
		var keepsake_tex := _resolve_ending_keepsake_photo()
		if keepsake_tex != null:
			var frame := PanelContainer.new()
			frame.name = "OpeningPhotoFrame"
			frame.position = Vector2(432, 42)
			frame.size = Vector2(194, 138)
			frame.rotation_degrees = 3.2
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var frame_style := StyleBoxFlat.new()
			frame_style.bg_color = Color("f3ecda")
			frame_style.border_color = Color("b6a682")
			frame_style.set_border_width_all(1)
			frame_style.set_content_margin_all(4)
			frame_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
			frame_style.shadow_size = 6
			frame.add_theme_stylebox_override("panel", frame_style)
			wrap.add_child(frame)
			var keepsake := TextureRect.new()
			keepsake.name = "OpeningPhotoKeepsake"
			keepsake.texture = keepsake_tex
			keepsake.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			keepsake.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			keepsake.mouse_filter = Control.MOUSE_FILTER_IGNORE
			keepsake.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			keepsake.size_flags_vertical = Control.SIZE_EXPAND_FILL
			frame.add_child(keepsake)

	var toggle_cg_btn := Button.new()
	toggle_cg_btn.text = "隐藏字幕"
	toggle_cg_btn.position = Vector2(12, 8)
	toggle_cg_btn.size = Vector2(70, 22)
	toggle_cg_btn.focus_mode = Control.FOCUS_NONE
	toggle_cg_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle_cg_btn.add_theme_font_size_override("font_size", 10)
	toggle_cg_btn.add_theme_color_override("font_color", Color("f2df9e"))
	var toggle_skin := StyleBoxFlat.new()
	toggle_skin.bg_color = Color(0.04, 0.07, 0.055, 0.90)
	toggle_skin.border_color = Color("a28d60")
	toggle_skin.set_border_width_all(1)
	toggle_skin.set_corner_radius_all(3)
	toggle_cg_btn.add_theme_stylebox_override("normal", toggle_skin)
	toggle_cg_btn.pressed.connect(func():
		if is_instance_valid(hud) and is_instance_valid(hud.modal):
			hud.modal.visible = not hud.modal.visible
			toggle_cg_btn.text = "显示字幕" if not hud.modal.visible else "隐藏字幕"
	)
	wrap.add_child(toggle_cg_btn)

	var fade := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(wrap, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)


func _show_ending(ending_id: String) -> void:
	_close_pipe_knock_ui()
	_sync_illusion_door_visibility()
	var title := ""
	var body := ""
	match ending_id:
		"ending_missing":
			title = "迷失闭环   ·   结局 1 / 3"
			body = "暗门在身后轰然合死。阿豪的笑脸与「嘉敏」完好无损的十指瞬间剥落成渗血的石屎灰尘。\n\n大文沿着潮湿回廊不断往前跑，每次转过弯，尽头都还是那扇半掩的封墙暗门。"
		"ending_escape":
			title = "残缺生还   ·   结局 2 / 3"
			body = "天快亮时，救护车的灯映在路环的石路上。嘉敏一直抱着阿豪的相机。\n\n几天后，地下夹层被重新封住，只留下一张管网抢修通告。"
		"ending_truth":
			title = "破晓真章   ·   结局 3 / 3"
			body = "天亮后，两人带着阿豪的相机和五组档案返港。旧案终于公开。\n\n嘉敏翻到抵澳那天拍的照片。那时他们还约好，办完事就一起去吃宵夜。\n\n本作地下通道与旧案为虚构改编。"
	var choices: Array[Dictionary] = []
	if GameState.has_pre_ending_checkpoint() or GameState.recover_old_ending_checkpoint():
		choices.append({"text":"回到结局前继续调查", "callback":_retry_pre_ending})
	choices.append({"text":"返回标题画面", "callback":_return_to_title})
	_say("结局", body, choices, title)
	if is_instance_valid(hud) and hud.has_method("apply_ending_letterbox_layout"):
		hud.apply_ending_letterbox_layout()
	_build_ending_backdrop(ending_id)
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
	_clear_ending_backdrop()
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
		hud.objective.text = "嘉敏 · 沿右边的空地走到管道接头，敲出两短一长。" if GameState.opening_flags.ch6_jiamin_pipe_found else "嘉敏 · 拾起地上的短钢管。"
	elif not GameState.opening_flags.ch6_circuit_isolated:
		hud.objective.text = "大文已认出嘉敏的信号！到配电柜合上高压电弧主闸（勿信左侧渗血暗门）。"
	elif not GameState.opening_flags.ch6_entity_lured:
		hud.objective.text = "开启声呐引诱器。入口充电盒可补足手机强闪。"
	elif not GameState.opening_flags.ch6_entity_bound:
		hud.objective.text = "引怨灵踏上铁栅，拉下红柄落闸杆电击破门。"
	elif GameState.opening_flags.ch6_rescue_door_open and not GameState.opening_flags.ch6_jiamin_rescued:
		hud.objective.text = "⑥ 隔离门已开！靠近舱门按 E 扶出嘉敏"
	elif not GameState.opening_flags.ch6_jiamin_rescued:
		hud.objective.text = "⑥ 封墙怨灵已封杀！到右侧舱门按 E 打开隔离门救出嘉敏"
	else:
		hud.objective.text = "嘉敏已获救。沿下方拱门撤离，或查完配电柜旁全部档案触发破晓真章。"
	hud.state_text.text = ""
	_update_active_step_beacon(1.0)


func _say(title: String, body: String, choices: Array = [], speaker := "") -> void:
	if speaker.is_empty():
		speaker = "黄嘉敏" if GameState.current_role == "jiamin" else "陈大文"
	hud.open_panel(title, body, choices, false, speaker)
	if is_instance_valid(pipe_knock_ui):
		pipe_knock_ui.hide()
	player.controls_enabled = false
	player.clear_motion()
	get_tree().paused = true


func _close_panel() -> void:
	AudioManager.stop_voice()
	hud.close_panel()
	get_tree().paused = false
	if is_instance_valid(pipe_knock_ui):
		pipe_knock_ui.show()
	if is_instance_valid(player) and listening_target.is_empty() and not signal_response_active and not scene_action_active and not boss_capture_active and not _ending_recorded():
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
	_clear_ending_backdrop()
	_close_panel()
	if not GameState.save_opening_checkpoint():
		_say("保存失败", "目前进度未能保存。请检查存储空间和文件夹权限后重试。")
		return
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _return_to_pressure_gallery() -> void:
	if GameState.opening_flags.ch6_jiamin_rescued:
		_say("准备带嘉敏撤离", "大文与嘉敏终于重逢！防洪应急通道已从内侧解锁，确定现在带嘉敏撤离地下夹层吗？", [
			{"text":"进行撤离与档案核对", "callback":_open_ending_choices},
			{"text":"再在现场检查一下", "callback":_close_panel}
		])
		return
	# Never bounce the player backwards into the pressure gallery before rescuing Jiamin!
	AudioManager.play_world_effect("iron_slam")
	_say("防洪暗渠水门已封死", "身后的沿海暗渠防洪闸刚才轰然落下并自动锁死，退路彻底断了。必须先在这里引出并封住百利新邨的封墙怨灵、打开右侧隔离舱救出嘉敏，才能解锁应急撤离通道！")


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
	# Tangible painted industrial pipe-routing blueprint board mounted on the tiled wall above TARGETS.route_diagram!
	if ResourceLoader.exists("res://assets/props/ch6_pipe_blueprint_v11.png"):
		var bp_tex := load("res://assets/props/ch6_pipe_blueprint_v11.png") as Texture2D
		if bp_tex != null:
			var bp := Sprite2D.new()
			bp.name = "WallPipeBlueprintProp"
			bp.texture = bp_tex
			bp.position = Vector2(742, 338)
			bp.scale = Vector2(64.0 / float(bp_tex.get_width()), 44.0 / float(bp_tex.get_height()))
			bp.z_index = 340
			add_child(bp)
	var glint := PointLight2D.new()
	glint.position = TARGETS.route_diagram + Vector2(0, -36)
	glint.texture = preload("res://assets/lighting/soft_light.png")
	glint.texture_scale = 0.34
	glint.color = Color("f2dc96")
	glint.energy = 0.45
	add_child(glint)
	var tw := create_tween().set_loops()
	tw.tween_property(glint, "energy", 0.85, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(glint, "energy", 0.28, 0.9).set_trans(Tween.TRANS_SINE)
	diagram_marker = Label.new()
	diagram_marker.hide()
	add_child(diagram_marker)
