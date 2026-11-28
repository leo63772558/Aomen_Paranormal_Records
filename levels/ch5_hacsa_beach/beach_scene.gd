extends Node2D

const ROOM_ID := "ch5_hacsa_beach"
const WORLD_SIZE := Vector2(1280, 720)
const TARGETS := {
	"car":Vector2(400, 206),
	"key_box":Vector2(937, 171), "cabinet":Vector2(1110, 224),
	"trace_a":Vector2(645, 430),
	"wrack":Vector2(745, 575), "trace_b":Vector2(895, 365),
	"road_exit":Vector2(78, 100),
	"macau_pavilion":Vector2(218, 192),
	"macau_tinhau":Vector2(575, 220),
	"macau_fishlamp":Vector2(825, 206)
}
const NAMES := {
	"car":"检查救援车灯开关", "key_box":"检查高地钥匙箱", "cabinet":"查看蓝门旁资料柜",
	"trace_a":"查看被海浪冲上岸的破油布与残骸", "wrack":"查看浪边邮袋与沾血油纸",
	"trace_b":"查看碎石旁遗落的发卡与刮痕", "road_exit":"进入沿海工事维护通道",
	"macau_pavilion":"查看凉亭长椅上的1985旧报剪报", "macau_tinhau":"查看石墙妈祖小龛", "macau_fishlamp":"查看路环防风旧渔灯"
}
const CAR_ORIGIN := Vector2(548, 201)
const CAR_DIRECTION := Vector2(0.682, 0.731)
const CAR_RANGE := 690.0
const CAR_HALF_ANGLE := 0.48
const CABINET_HINGE_POS := Vector2(1097, 125)
const CABINET_BASE_SCALE := Vector2(1280.0 / 1672.0, 720.0 / 941.0)
const CABINET_DOOR_SIZE := Vector2(66.0 * (1280.0 / 1672.0), 82.0 * (720.0 / 941.0))

var player: PlayerController
var hud
var tide: Node2D
var widget: Control
var after_panel := Callable()
var selected_id := ""
var hotspots: Dictionary = {}
var car_lights: Array[PointLight2D] = []
var light_tween: Tween
var wet_clock := 0.0
var recovering := false
var cabinet_lid: Sprite2D
var cabinet_interior: Node2D
var cabinet_plan: Sprite2D
var cabinet_door_shadow: Polygon2D
var cabinet_door_edge: Polygon2D
var cabinet_interior_glow: PointLight2D
var service_action_active := false
var plan_preview_pending := false
var key_box_overlay: Sprite2D
var ghost: Node2D
var last_safe_anchor := Vector2(190, 221)
var tall_blockers: Array[CollisionObject2D] = []
var next_marker: Label
var target_glint: Sprite2D
var shaft_mark: Node2D

func _ready() -> void:
	GameState.prepare_opening_resume()
	if GameState.current_room_id != ROOM_ID:
		push_error("Black-sand beach must be entered through the room registry.")
		return
	AudioManager.set_scene_ambience("beach")
	_build_background()
	_build_geometry()
	_build_hotspots()
	_build_car_lights()
	_build_cabinet()
	_build_macau_props()
	_build_shaft_mark()
	_build_footprints()
	tide = preload("res://levels/ch5_hacsa_beach/tidal_water.gd").new()
	tide.phase_changed.connect(_tide_phase_changed)
	add_child(tide)
	player = preload("res://entities/player/player.tscn").instantiate()
	player.visual_size_multiplier = 1.9
	player.position = last_safe_anchor
	add_child(player)
	var camera := player.get_node("Camera2D") as Camera2D
	camera.enabled = true
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 1280
	camera.limit_bottom = 720
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	hud = preload("res://ui/quiet_hud.gd").new()
	add_child(hud)
	hud.journal_note_provider = _beach_journal_note
	hud.close_requested.connect(_close_panel)
	hud.pause_requested.connect(_pause_menu)
	ghost = preload("res://entities/beach_apparition.gd").new()
	ghost.beach = self
	ghost.player = player
	ghost.position = Vector2(860, 570)
	ghost.caught.connect(_ghost_caught)
	add_child(ghost)
	_update_objective()
	if not GameState.opening_flags.beach_intro_seen:
		GameState.opening_flags.beach_intro_seen = true
		GameState.unlock_macau_guide("hacsa_beach")
		checkpoint()
		_say("黑沙 · 翻车之后", "浓雾散开一点了。沙滩远处晃着个拎砍刀拖麻袋的鬼影……先去救援车开远光灯，再去浪边查清被海浪冲上来的残骸是不是嘉敏！")

func _build_background() -> void:
	var background := Sprite2D.new()
	background.name = "BeachBackground"
	background.texture = preload("res://assets/tilesets/hacsa_beach_038.png")
	background.centered = false
	background.scale = WORLD_SIZE / background.texture.get_size()
	background.light_mask = 5
	add_child(background)
	var ambient := CanvasModulate.new()
	ambient.color = Color("738079")
	add_child(ambient)
	for at in [Vector2(140, 59), Vector2(779, 59), Vector2(1041, 101)]:
		var lamp := PointLight2D.new()
		lamp.position = at
		lamp.texture = preload("res://assets/lighting/soft_light.png")
		lamp.texture_scale = 1.5
		lamp.color = Color("dfac62")
		lamp.energy = 0.45
		lamp.range_item_cull_mask = 7
		add_child(lamp)

func _solid(rect: Rect2, tall := false) -> void:
	var body := LevelGeometry.wall(self, rect)
	body.set_meta("low_barrier", not tall)
	var shadow := get_child(get_child_count() - 1) as LightOccluder2D
	if tall:
		shadow.occluder_light_mask = 5
		tall_blockers.append(body)

func _build_geometry() -> void:
	_solid(Rect2(-24, 0, 24, 760), true)
	_solid(Rect2(1280, 0, 24, 760), true)
	_solid(Rect2(0, -24, 1280, 24), true)
	# Forest trees behind the promenade and deep ocean surf at the bottom are non-walkable.
	_solid(Rect2(145, 0, 795, 112), true)
	_solid(Rect2(0, 625, 1280, 120), false)
	# Roadside shelter, rescue vehicle and hut match the background's footprints, leaving clear promenade room past the vehicle.
	_solid(Rect2(148, 78, 161, 105), true)
	_solid(Rect2(358, 86, 200, 108))
	_solid(Rect2(940, 0, 340, 219), true)
	# The seawall leaves both flights of stairs open. The dry sand beside its
	# base is another permanent refuge, so tide never seals every escape route.
	for rect in [Rect2(0, 240, 146, 74), Rect2(251, 240, 644, 74), Rect2(991, 240, 289, 74)]:
		_solid(rect)
	for x in [20, 74, 602, 813, 1218]:
		_solid(Rect2(x - 7, 214, 14, 20))
	_solid(Rect2(0, 440, 43, 148))

func _build_hotspots() -> void:
	for id in TARGETS:
		var area := Area2D.new()
		area.name = "Inspect_" + id
		area.position = TARGETS[id]
		area.collision_layer = 8
		area.collision_mask = 2
		var collision := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 25
		collision.shape = shape
		area.add_child(collision)
		add_child(area)
		hotspots[id] = area
	next_marker = Label.new()
	next_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_marker.add_theme_font_size_override("font_size", 12)
	next_marker.add_theme_color_override("font_color", Color("efdc9e"))
	next_marker.add_theme_color_override("font_outline_color", Color("0d1715"))
	next_marker.add_theme_constant_override("outline_size", 5)
	next_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_marker.z_index = 245
	next_marker.visible = false
	add_child(next_marker)
	# Subtle grounded warm moonlight glint on the current clue/device (replaces ugly floating yellow "救援车 ↓" world tag!)
	target_glint = Sprite2D.new()
	target_glint.name = "ObjectiveGlint"
	target_glint.texture = preload("res://assets/lighting/soft_light.png")
	target_glint.scale = Vector2.ONE * 0.14
	target_glint.modulate = Color(0.95, 0.85, 0.56, 0.45)
	target_glint.z_index = 235
	target_glint.visible = false
	add_child(target_glint)

func _build_car_lights() -> void:
	for offset in [Vector2(-8, -7), Vector2(8, 7)]:
		var lamp := PointLight2D.new()
		lamp.position = CAR_ORIGIN + offset
		lamp.rotation = CAR_DIRECTION.angle()
		lamp.texture = preload("res://assets/lighting/flashlight_cone.png")
		lamp.scale = Vector2(2.7, 2.75)
		lamp.energy = 0.62 if GameState.opening_flags.beach_headlights_on else 0.0
		lamp.color = Color("d9dfd1")
		lamp.range_item_cull_mask = 5
		lamp.shadow_item_cull_mask = 4
		lamp.shadow_enabled = true
		add_child(lamp)
		car_lights.append(lamp)

func _build_cabinet() -> void:
	# Proper dark recessed steel filing cabinet shelves matching the lifeguard hut exterior (no mismatched keybox crop!)
	cabinet_interior = Node2D.new()
	cabinet_interior.name = "DocumentCabinetInterior"
	cabinet_interior.position = CABINET_HINGE_POS
	cabinet_interior.z_index = 223
	var back_box := Polygon2D.new()
	var cw := CABINET_DOOR_SIZE.x - 2.0
	var ch := CABINET_DOOR_SIZE.y - 2.0
	back_box.polygon = PackedVector2Array([Vector2(1, 1), Vector2(cw, 1), Vector2(cw, ch), Vector2(1, ch)])
	back_box.color = Color(0.07, 0.085, 0.08, 0.98)
	cabinet_interior.add_child(back_box)
	# Two weathered metal shelves & archived manila folders inside cabinet
	for sy in [22.0, 44.0]:
		var shelf := Polygon2D.new()
		shelf.polygon = PackedVector2Array([Vector2(2, sy), Vector2(cw - 1, sy), Vector2(cw - 1, sy + 2.5), Vector2(2, sy + 2.5)])
		shelf.color = Color(0.24, 0.27, 0.25, 0.95)
		cabinet_interior.add_child(shelf)
	for f_idx in range(4):
		var fx := 5.0 + float(f_idx) * 7.5
		var folder := Polygon2D.new()
		folder.polygon = PackedVector2Array([Vector2(fx, 6.0), Vector2(fx + 5.5, 6.0), Vector2(fx + 5.5, 21.5), Vector2(fx, 21.5)])
		folder.color = Color(0.45 - f_idx * 0.04, 0.39 - f_idx * 0.03, 0.29 - f_idx * 0.02, 0.92)
		cabinet_interior.add_child(folder)
	add_child(cabinet_interior)

	cabinet_plan = Sprite2D.new()
	cabinet_plan.name = "FoldedMaintenancePlan"
	cabinet_plan.texture = DemoItems.texture("hotel_maintenance_plan")
	cabinet_plan.position = CABINET_HINGE_POS + Vector2(cw * 0.54, 34.0)
	cabinet_plan.scale = Vector2(18, 24) / cabinet_plan.texture.get_size()
	cabinet_plan.rotation = -0.08
	cabinet_plan.modulate = Color(0.62, 0.54, 0.38, 0.94)
	cabinet_plan.z_index = 224
	add_child(cabinet_plan)

	cabinet_door_shadow = Polygon2D.new()
	cabinet_door_shadow.name = "DocumentCabinetDoorShadow"
	cabinet_door_shadow.color = Color(0.02, 0.03, 0.03, 0.56)
	cabinet_door_shadow.z_index = 224
	cabinet_door_shadow.visible = false
	add_child(cabinet_door_shadow)

	cabinet_lid = Sprite2D.new()
	cabinet_lid.name = "DocumentCabinetLid"
	var crop := AtlasTexture.new()
	crop.atlas = preload("res://assets/tilesets/hacsa_beach_038.png")
	crop.region = Rect2(1438, 168, 56, 74)
	crop.filter_clip = true
	cabinet_lid.texture = crop
	cabinet_lid.centered = false
	cabinet_lid.position = CABINET_HINGE_POS
	cabinet_lid.scale = CABINET_BASE_SCALE
	cabinet_lid.z_index = 225
	add_child(cabinet_lid)

	cabinet_door_edge = Polygon2D.new()
	cabinet_door_edge.name = "DocumentCabinetDoorEdge"
	cabinet_door_edge.color = Color("7b7667")
	cabinet_door_edge.z_index = 226
	cabinet_door_edge.visible = false
	add_child(cabinet_door_edge)

	cabinet_interior_glow = PointLight2D.new()
	cabinet_interior_glow.name = "DocumentCabinetInteriorGlow"
	cabinet_interior_glow.position = CABINET_HINGE_POS + Vector2(cw * 0.5, ch * 0.5)
	cabinet_interior_glow.texture = preload("res://assets/lighting/soft_light.png")
	cabinet_interior_glow.texture_scale = 0.24
	cabinet_interior_glow.color = Color("f6d592")
	cabinet_interior_glow.energy = 0.0
	cabinet_interior_glow.range_item_cull_mask = 7
	add_child(cabinet_interior_glow)

	key_box_overlay = Sprite2D.new()
	key_box_overlay.texture = _mechanism_cell(0, GameState.opening_flags.beach_cabinet_key_found)
	key_box_overlay.position = Vector2(945, 143)
	key_box_overlay.scale = Vector2.ONE * 0.045
	key_box_overlay.visible = GameState.opening_flags.beach_key_box_open
	key_box_overlay.z_index = 225
	add_child(key_box_overlay)
	cabinet_interior.visible = GameState.opening_flags.beach_cabinet_open
	cabinet_plan.visible = cabinet_interior.visible and not GameState.opening_flags.beach_plan_found
	if GameState.opening_flags.beach_cabinet_open:
		_apply_cabinet_swing(1.0)

func _build_macau_props() -> void:
	# Tangible grounded Macau cultural objects on Hac Sa promenade (newspaper, Tin Hau incense shrine, Coloane fish lantern)
	# 1) 1985 yellowing Macau newspaper clipping resting on the pavilion bench
	var paper := Sprite2D.new()
	paper.name = "MacauPavilionPaper"
	paper.texture = DemoItems.texture("laochen_handoff_note")
	paper.position = TARGETS.macau_pavilion + Vector2(0, -10)
	paper.scale = Vector2.ONE * (20.0 / maxf(1.0, paper.texture.get_width()))
	paper.rotation = -0.18
	paper.modulate = Color(0.88, 0.84, 0.72, 0.92)
	paper.z_index = 185
	add_child(paper)
	# 2) Coloane stone-wall Tin Hau mini shrine with real curling incense smoke sprite & crimson ember glow
	var shrine_plume := Sprite2D.new()
	shrine_plume.name = "MacauTinHauShrine"
	shrine_plume.texture = preload("res://assets/props/incense_smoke_014.png")
	shrine_plume.position = TARGETS.macau_tinhau + Vector2(0, -20)
	shrine_plume.scale = Vector2(14.0, 36.0) / shrine_plume.texture.get_size()
	shrine_plume.modulate = Color(0.86, 0.78, 0.74, 0.58)
	shrine_plume.z_index = 215
	add_child(shrine_plume)
	var incense_glow := PointLight2D.new()
	incense_glow.position = TARGETS.macau_tinhau + Vector2(0, -14)
	incense_glow.texture = preload("res://assets/lighting/soft_light.png")
	incense_glow.texture_scale = 0.16
	incense_glow.color = Color("f05638")
	incense_glow.energy = 0.46
	add_child(incense_glow)
	# 3) Coloane windproof fishing lantern warm salt-haze glow on the seawall post (no flat grey polygon!)
	var fish_glow := PointLight2D.new()
	fish_glow.name = "MacauFishLantern"
	fish_glow.position = TARGETS.macau_fishlamp + Vector2(0, -18)
	fish_glow.texture = preload("res://assets/lighting/soft_light.png")
	fish_glow.texture_scale = 0.24
	fish_glow.color = Color("f2bd6b")
	fish_glow.energy = 0.54
	add_child(fish_glow)

func _apply_cabinet_swing(progress: float) -> void:
	var p := clampf(progress, 0.0, 1.0)
	# Realistic 3D left-hinge swing stopping cleanly at ~82 deg (1.43 rad) so door NEVER flips negatively across the blue hut door!
	var theta := p * 1.43
	var proj_x := maxf(0.14, cos(theta))
	var out_depth := sin(theta)
	var door_w := CABINET_DOOR_SIZE.x
	var door_h := CABINET_DOOR_SIZE.y
	var free_x := CABINET_HINGE_POS.x + door_w * proj_x
	var drop_y := out_depth * 4.5

	cabinet_lid.position = CABINET_HINGE_POS
	cabinet_lid.scale = Vector2(CABINET_BASE_SCALE.x * proj_x, CABINET_BASE_SCALE.y)
	cabinet_lid.skew = -0.18 * out_depth
	var shade := lerpf(1.0, 0.28, p)
	cabinet_lid.modulate = Color(shade * 0.85, shade * 0.88, shade * 0.86, 1.0)

	# Darkened inner cast shadow along the left interior wall behind the swinging door
	if is_instance_valid(cabinet_door_shadow):
		cabinet_door_shadow.visible = p > 0.02
		var sh_w := minf(door_w * 0.42, 5.0 + out_depth * 14.0)
		cabinet_door_shadow.polygon = PackedVector2Array([
			CABINET_HINGE_POS + Vector2(1.0, 2.0),
			CABINET_HINGE_POS + Vector2(sh_w, 4.0),
			CABINET_HINGE_POS + Vector2(sh_w, door_h - 2.0),
			CABINET_HINGE_POS + Vector2(1.0, door_h - 1.0)
		])
		cabinet_door_shadow.color.a = 0.56 * minf(1.0, p * 2.2)

	# Dark metallic door-edge thickness strip (never bright or white!)
	if is_instance_valid(cabinet_door_edge):
		cabinet_door_edge.visible = p > 0.04 and p < 0.85
		var edge_w := 1.6 + out_depth * 1.4
		cabinet_door_edge.polygon = PackedVector2Array([
			Vector2(free_x, CABINET_HINGE_POS.y + drop_y),
			Vector2(free_x + edge_w, CABINET_HINGE_POS.y + drop_y - 0.5),
			Vector2(free_x + edge_w, CABINET_HINGE_POS.y + door_h + drop_y - 0.5),
			Vector2(free_x, CABINET_HINGE_POS.y + door_h + drop_y)
		])
		cabinet_door_edge.color = Color(0.18, 0.20, 0.19, 0.90)

	if is_instance_valid(cabinet_interior_glow):
		cabinet_interior_glow.energy = 0.68 * p if not GameState.opening_flags.beach_plan_found else 0.32 * p

func _spawn_cabinet_dust() -> void:
	for k in range(7):
		var mote := Polygon2D.new()
		mote.polygon = PackedVector2Array([Vector2(-2.2, -1.6), Vector2(2.4, -1.2), Vector2(1.8, 2.2), Vector2(-2.0, 1.8)])
		mote.color = Color(0.84, 0.77, 0.62, 0.62)
		mote.position = CABINET_HINGE_POS + Vector2(CABINET_DOOR_SIZE.x - 4.0 + randf_range(-5.0, 4.0), randf_range(12.0, CABINET_DOOR_SIZE.y - 10.0))
		mote.z_index = 228
		add_child(mote)
		var tw := mote.create_tween()
		tw.tween_property(mote, "position", mote.position + Vector2(randf_range(-10.0, 14.0), randf_range(8.0, 22.0)), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(mote, "modulate:a", 0.0, 0.45)
		tw.tween_callback(mote.queue_free)

func _build_shaft_mark() -> void:
	var mark := preload("res://ui/beach_service_board.gd").shaft_mark()
	mark.position = TARGETS.road_exit + Vector2(1, 32)
	mark.scale = Vector2(1.32, 0.82)
	mark.modulate = Color("d7bf90", 0.84)
	mark.z_index = 3
	mark.visible = GameState.opening_flags.beach_circuit_matched
	add_child(mark)
	shaft_mark = mark

static func _mechanism_cell(index: int, clean := false) -> AtlasTexture:
	var sheet := load("res://assets/props/beach_mechanism_clean_040b.png" if clean else "res://assets/props/beach_mechanism_parts_040.png") as Texture2D
	var cell := sheet.get_size() / Vector2(2, 2)
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	texture.region = Rect2(Vector2(index % 2, index / 2) * cell, cell)
	texture.filter_clip = true
	return texture

static func footprint_cell(index: int) -> AtlasTexture:
	var sheet := preload("res://assets/props/footprint_evidence_039.png")
	var cell := sheet.get_size() / Vector2(2, 2)
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	texture.region = Rect2(Vector2(index % 2, index / 2) * cell + Vector2(24, 28), cell - Vector2(48, 56))
	texture.filter_clip = true
	return texture

func _build_footprints() -> void:
	# Washed-up postman remains & meat-shop dumping evidence + Jiamin's escape hairpin near the upper boulders
	# 1) trace_a: Torn olive-black tarpaulin & exposed postman uniform cuff + weathered remains washed ashore
	var shroud := Polygon2D.new()
	shroud.name = "PostmanRemainsWrap"
	shroud.position = TARGETS.trace_a
	shroud.z_index = 4
	shroud.polygon = PackedVector2Array([
		Vector2(-20, -6), Vector2(-4, -12), Vector2(18, -7), Vector2(22, 6), Vector2(4, 11), Vector2(-18, 7)
	])
	shroud.color = Color(0.11, 0.13, 0.12, 0.94)
	add_child(shroud)
	var sleeve := Polygon2D.new()
	sleeve.polygon = PackedVector2Array([Vector2(-15, -2), Vector2(-3, -6), Vector2(-1, 4), Vector2(-13, 6)])
	sleeve.color = Color(0.16, 0.36, 0.25, 0.96)
	shroud.add_child(sleeve)
	var stain := Polygon2D.new()
	stain.polygon = PackedVector2Array([Vector2(-8, 1), Vector2(12, -2), Vector2(17, 7), Vector2(-6, 9)])
	stain.color = Color(0.36, 0.04, 0.04, 0.85)
	shroud.add_child(stain)

	# 2) wrack: Torn green postal satchel, soaked envelopes & butcher's stamped greasepaper washed along tideline
	var sack := Polygon2D.new()
	sack.name = "PostmanSatchelClue"
	sack.position = TARGETS.wrack
	sack.z_index = 4
	sack.polygon = PackedVector2Array([Vector2(-14, -7), Vector2(11, -9), Vector2(16, 5), Vector2(-12, 8)])
	sack.color = Color(0.15, 0.30, 0.21, 0.92)
	add_child(sack)
	var wrap := Polygon2D.new()
	wrap.position = Vector2(12, 4)
	wrap.polygon = PackedVector2Array([Vector2(-7, -4), Vector2(8, -3), Vector2(7, 5), Vector2(-6, 6)])
	wrap.color = Color(0.68, 0.62, 0.50, 0.88)
	sack.add_child(wrap)

	# 3) trace_b: Jiamin's glinting silver hairpin & frantic climbing scuffs leading toward the upper coastal ledge
	var pin := Polygon2D.new()
	pin.name = "JiaminEscapeHairpin"
	pin.position = TARGETS.trace_b
	pin.z_index = 4
	pin.polygon = PackedVector2Array([Vector2(-7, -2), Vector2(7, -1), Vector2(7, 2), Vector2(-7, 1)])
	pin.rotation = -0.35
	pin.color = Color(0.86, 0.89, 0.92, 0.95)
	add_child(pin)
	for s_i in range(3):
		var scuff := Polygon2D.new()
		var base_p: Vector2 = TARGETS.trace_b + Vector2(-float(s_i + 1) * 14.0, -float(s_i) * 8.0)
		scuff.polygon = PackedVector2Array([base_p + Vector2(-8, -2), base_p + Vector2(8, -3), base_p + Vector2(9, 2), base_p + Vector2(-7, 3)])
		scuff.color = Color(0.12, 0.14, 0.15, 0.45)
		scuff.z_index = 2
		add_child(scuff)

const SAFE_DRY_REFUGES: Array[Vector2] = [
	Vector2(190, 221),
	Vector2(925, 224)
]

func get_nearest_safe_anchor(from_pos: Vector2) -> Vector2:
	var best_pos := SAFE_DRY_REFUGES[0]
	var best_dist := INF
	for anchor in SAFE_DRY_REFUGES:
		var d := from_pos.distance_to(anchor)
		if d < best_dist:
			best_dist = d
			best_pos = anchor
	return best_pos

func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(hud) or hud.panel_open or recovering or service_action_active:
		return
	last_safe_anchor = get_nearest_safe_anchor(player.position)
	if tide.is_wet(player.position):
		wet_clock += delta
		if wet_clock >= 2.5:
			_recover_from_water()
			return
	else:
		wet_clock = 0.0
	selected_id = ""
	var best := INF
	for id in TARGETS:
		var delta_to: Vector2 = TARGETS[id] - player.position
		var distance := delta_to.length()
		var alignment := player.look_dir.dot(delta_to.normalized()) if distance > 0.1 else 1.0
		var max_dist := 82.0 if id in ["car", "cabinet", "key_box"] else (42.0 if id.begins_with("macau_") else 60.0)
		if distance > max_dist or (distance > 30.0 and alignment < -0.1):
			continue
		var score := distance + (1.0 - alignment) * 45.0 + (35.0 if id.begins_with("macau_") else 0.0)
		if score < best:
			selected_id = id
			best = score
	hud.prompt.text = "[ E ] " + NAMES[selected_id] if not selected_id.is_empty() else ""
	if selected_id == "cabinet" and GameState.opening_flags.beach_cabinet_open:
		hud.prompt.text = "[ E ] 重看沿海工事图" if GameState.opening_flags.beach_plan_found else "[ E ] 取柜里的折叠图"
	hud.state_text.text = ["潮水退着；低地可观察", "浪声变近：先看好干地退路", "潮水上涨；离开湿沙", "低地被潮水覆盖；干地可等下一轮", "潮水回落；旧痕迹重新露出"][tide.phase]
	_update_objective()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not is_instance_valid(hud) or hud.panel_open or recovering or service_action_active:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		interact_target(selected_id)
	elif event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		_open_widget(preload("res://ui/demo_bag.gd").new())
	elif event.is_action_pressed("journal"):
		get_viewport().set_input_as_handled()
		var bag := preload("res://ui/demo_bag.gd").new()
		bag.journal_mode = true
		bag.journal_note = _beach_journal_note()
		_open_widget(bag)

func interact_target(id: String) -> void:
	if service_action_active:
		return
	match id:
		"trace_a":
			GameState.opening_flags.beach_sole_seen = true
			GameState.opening_flags.beach_trace_a_seen = true
			_check_beach_clues_complete()
			_say("海浪冲上来的残骸", "黑沙浪边卷上几截碎骨残肢和泡胀的碎肉，缠在破油布里。\n大文屏住呼吸翻开衣角——露出的不是女装，而是半截湿透的绿白条纹邮差制服。\n「怎么是大关斜巷肉铺里失踪的那名邮差……？！嘉敏没死在这里！」")
		"wrack":
			GameState.opening_flags.beach_wrack_seen = true
			_check_beach_clues_complete()
			_say("沾血邮袋与肉铺油纸", "烂帆布邮袋被海草缠在礁石下，袋口还黏着一张大关斜巷旧肉铺的印章油纸。\n「原来第三章那个屠夫一直趁涨潮把残肢运来黑沙抛尸……怪不得这片沙滩晚上封死。」")
		"trace_b":
			GameState.opening_flags.beach_trace_b_seen = true
			_check_beach_clues_complete()
			_say("碎石旁的发卡与攀爬痕", "滩涂边缘没有嘉敏的遗体，只在通往高地防浪堤的石阶缝里捡到她别惯了的那枚银发卡，旁边还有匆忙逃跑蹭掉的碎石刮痕。\n「她一定撞见屠夫抛尸、趁乱往沿海工事那边逃走了！我得尽快进工事找她！」")
		"car": _open_service("car")
		"key_box": _open_service("key_box")
		"cabinet": _inspect_cabinet()
		"road_exit": _leave_beach()
		"macau_pavilion": _say("凉亭长椅 · 旧案剪报", "风把嘉敏的剪报吹到长椅底下。那一页记的是 1985 年八仙饭店案传闻在路环海滩冲上残肢的新闻，她用红笔画了个圈：『不要把真实案情与无证怪谈混淆。』\n页脚另有一行仓促的新字：『有人拖着沉袋子下海，我先躲进前头维护暗门。』")
		"macau_tinhau": hud.show_resource_feedback("石墙边的路环妈祖小神龛，红香脚已经被咸湿海风吹冷了。")
		"macau_fishlamp": hud.show_resource_feedback("路环老渔民挂在岸边的防风铁皮渔灯，玻璃罩结满了一层海盐霜。")

func _check_beach_clues_complete() -> void:
	var f := GameState.opening_flags
	if f.beach_trace_a_seen and f.beach_wrack_seen and f.beach_trace_b_seen:
		if not f.beach_footprints_solved:
			f.beach_footprints_solved = true
			hud.notify("撞破抛尸现场！拎刀屠夫吼叫着从暗雾里追了过来——快去救生站开资料柜找沿海工事路线！")
	checkpoint()
	_update_objective()

func _beach_journal_note() -> String:
	var f := GameState.opening_flags
	return "黑沙海滩现场线索（%d / 3）\n\n%s 浪边油布残骸：%s\n%s 邮袋与肉铺油纸：%s\n%s 石阶旁发卡：%s\n\n%s" % [
		int(f.beach_trace_a_seen) + int(f.beach_wrack_seen) + int(f.beach_trace_b_seen),
		"✓" if f.beach_trace_a_seen else "□", "确认是第三章失踪邮差遗骸，不是嘉敏" if f.beach_trace_a_seen else "未查看",
		"✓" if f.beach_wrack_seen else "□", "证实大关斜巷屠夫在此趁涨潮抛尸" if f.beach_wrack_seen else "未查看",
		"✓" if f.beach_trace_b_seen else "□", "嘉敏未遇害，已逃往沿海工事通道" if f.beach_trace_b_seen else "未查看",
		"已确认嘉敏逃往沿海工事！先甩开追杀灭口的屠夫，开资料柜核对维护图。" if f.beach_footprints_solved else "借救援车远光灯调查浪边三处线索，确认嘉敏去向。"
	]

func _open_service(mode: String) -> void:
	var board := preload("res://ui/beach_service_board.gd").new()
	board.configure(self, mode)
	_open_widget(board)

func set_headlights(enabled: bool) -> void:
	set_light_mode(2 if enabled else 0)

func set_light_mode(mode: int) -> void:
	GameState.opening_flags.beach_headlights_on = mode == 2
	GameState.opening_flags.beach_parking_lights_on = mode == 1
	if is_instance_valid(light_tween): light_tween.kill()
	light_tween = create_tween().set_parallel(true)
	light_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for lamp in car_lights:
		light_tween.tween_property(lamp, "energy", [0.0, 0.09, 0.58][mode], 0.65).set_trans(Tween.TRANS_SINE)
	checkpoint()

func in_headlight(at: Vector2) -> bool:
	if not GameState.opening_flags.beach_headlights_on or car_lights[0].energy < 0.35:
		return false
	var offset := at - CAR_ORIGIN
	if offset.length() > CAR_RANGE or (offset.length() > 1 and CAR_DIRECTION.normalized().dot(offset.normalized()) < cos(CAR_HALF_ANGLE)):
		return false
	var query := PhysicsRayQueryParameters2D.create(CAR_ORIGIN, at, 1)
	var excludes: Array[RID] = []
	for candidate in get_children():
		if candidate is CollisionObject2D and candidate not in tall_blockers:
			excludes.append(candidate.get_rid())
	query.exclude = excludes
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _ghost_caught() -> void:
	if recovering: return
	recovering = true
	AudioManager.stop_chase_music()
	player.controls_enabled = false
	player.clear_motion()
	ghost.mesh.hide()
	hud.root.hide()
	var layer := CanvasLayer.new()
	layer.layer = 65
	add_child(layer)
	var lunge := preload("res://ui/beach_lunge.gd").new()
	layer.add_child(lunge)
	await lunge.finished
	if not is_inside_tree() or not is_instance_valid(player): return
	player.position = last_safe_anchor
	player.reset_physics_interpolation()
	ghost.position = Vector2(860, 570)
	ghost.active = true
	ghost.mesh.show()
	hud.root.show()
	layer.queue_free()
	recovering = false
	_say("险些被剁中", "「别想跑……」沉重的砍刀擦着石阶边缘劈空。\n大文趁机退回救援车远光灯范围——屠夫怕强光照射，暂不敢踏入灯光正中，干沙石阶仍可喘息。已经查明的线索都记在身上。")

func take_cabinet_key() -> void:
	if not GameState.opening_flags.beach_key_box_open:
		return
	GameState.take_demo_item("beach_cabinet_key")
	GameState.opening_flags.beach_cabinet_key_found = true
	key_box_overlay.texture = _mechanism_cell(0, true)
	checkpoint()

func _inspect_cabinet() -> void:
	if service_action_active:
		return
	if not GameState.has_demo_item("beach_cabinet_key"):
		hud.show_resource_feedback("柜门上锁。去蓝门左边的保管箱找钥匙。")
		return
	if not GameState.opening_flags.beach_cabinet_open:
		service_action_active = true
		player.controls_enabled = false
		player.clear_motion()
		hud.prompt.text = ""
		# Phase 1 (0.16s): key-turn metal latch click + subtle cabinet rattle + warm dust puff
		AudioManager.play_world_effect("metal_latch")
		_spawn_cabinet_dust()
		var rattle := create_tween()
		rattle.tween_property(cabinet_lid, "position", CABINET_HINGE_POS + Vector2(1.5, -0.5), 0.04)
		rattle.tween_property(cabinet_lid, "position", CABINET_HINGE_POS + Vector2(-1.5, 0.5), 0.04)
		rattle.tween_property(cabinet_lid, "position", CABINET_HINGE_POS + Vector2(1.0, 0.0), 0.04)
		rattle.tween_property(cabinet_lid, "position", CABINET_HINGE_POS, 0.04)
		await rattle.finished
		if not is_inside_tree():
			return
		# Phase 2 (0.54s): hinged door swings smoothly open around left hinge with inner shadow, door edge & interior glow
		cabinet_interior.show()
		cabinet_plan.show()
		AudioManager.play_world_effect("wood_door_open")
		var swing := create_tween()
		swing.tween_method(_apply_cabinet_swing, 0.0, 1.0, 0.54).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await swing.finished
		if not is_inside_tree():
			return
		GameState.opening_flags.beach_cabinet_open = true
		service_action_active = false
		player.controls_enabled = not hud.panel_open
		checkpoint()
		_update_objective()
		return
	if not GameState.opening_flags.beach_plan_found:
		GameState.take_demo_item("hotel_maintenance_plan")
		GameState.opening_flags.beach_plan_found = true
		cabinet_plan.hide()
		if is_instance_valid(cabinet_interior_glow):
			cabinet_interior_glow.energy = 0.35
		AudioManager.play_world_effect("archive_ticket_pickup")
		checkpoint()
	_open_service("plan")

func verify_maintenance_plan() -> void:
	if GameState.opening_flags.beach_circuit_matched:
		return
	GameState.opening_flags.beach_circuit_matched = true
	plan_preview_pending = true
	shaft_mark.show()
	checkpoint()
	_update_objective()

func _show_maintenance_entrance() -> void:
	plan_preview_pending = false
	service_action_active = true
	player.controls_enabled = false
	hud.prompt.text = ""
	var entrance_camera := Camera2D.new()
	entrance_camera.position = Vector2(320, 180)
	entrance_camera.limit_right = 1280
	entrance_camera.limit_bottom = 720
	entrance_camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(entrance_camera)
	entrance_camera.make_current()
	var caption := next_marker.duplicate() as Label
	next_marker.hide()
	caption.text = "高位检修道  ↓"
	caption.show()
	entrance_camera.add_child(caption)
	caption.global_position = shaft_mark.position - Vector2(62, 44)
	await get_tree().create_timer(1.05, false).timeout
	if not is_inside_tree():
		return
	var camera := player.get_node("Camera2D") as Camera2D
	camera.make_current()
	camera.reset_smoothing()
	entrance_camera.queue_free()
	service_action_active = false
	player.controls_enabled = not hud.panel_open
	_update_objective()

func _leave_beach() -> void:
	if not GameState.opening_flags.beach_plan_found:
		_say("沿海工事方向", "步道旧牌上的维护标记被划去了。救生站蓝门旁还留着资料柜，里面可能有这段岸线的旧图。")
	elif not GameState.opening_flags.beach_footprints_solved:
		_say("还没查清浪边残骸", "那只是一闪而过的砍刀影。先看清海浪冲上来的残骸与嘉敏踪迹，确定她没出事再找路离开。")
	elif not GameState.opening_flags.beach_circuit_matched:
		_say("沿海工事维护图", "图上有不止一条通道。排水口已经在潮线内；先沿纸上的维护线路核对上层侧井，不能把通海排水口当入口。")
	else:
		if GameState.request_room_change("ch5_coastal_works", "from_beach"):
			GameState.save_transition_checkpoint()
		else:
			_say("沿海工事维护通道", "图纸指向高于潮线的侧井。入口的刮痕仍在，但这条通道暂时无法进入。")

func _recover_from_water() -> void:
	recovering = true
	player.controls_enabled = false
	player.clear_motion()
	await get_tree().create_timer(0.45, false).timeout
	if not is_inside_tree() or not is_instance_valid(player): return
	player.position = last_safe_anchor
	player.reset_physics_interpolation()
	wet_clock = 0.0
	recovering = false
	_say("退回干地", "浪头推过脚踝，大文沿最近的干带退回了石阶上方。已经收好的纸本仍在包里；等下一轮退潮再走。")

func _tide_phase_changed(phase: int) -> void:
	if phase == 1:
		AudioManager.play_at(self, "hall_wail", Vector2(780, 620), -11.0)
		if is_instance_valid(hud):
			hud.notify("海浪翻涌变近，浪底传来幽咽回声！低地即将回水，及时退上干带或石阶。")

func _open_widget(control: Control) -> void:
	widget = control
	hud.open_widget(control)
	player.controls_enabled = false
	player.clear_motion()
	get_tree().paused = true

func _say(title: String, body: String, after := Callable()) -> void:
	after_panel = after
	hud.open_panel(title, body)
	player.controls_enabled = false
	player.clear_motion()
	get_tree().paused = true

func _close_panel() -> void:
	if is_instance_valid(widget):
		widget.queue_free()
		widget = null
	hud.close_panel()
	get_tree().paused = false
	player.controls_enabled = not recovering and not service_action_active
	player.clear_motion()
	var callback := after_panel
	after_panel = Callable()
	if callback.is_valid(): callback.call()
	if plan_preview_pending:
		_show_maintenance_entrance()

func _pause_menu() -> void:
	hud.open_panel("暂停", "潮水、灯光边界与危险已经暂停。", [
		{"text":"继续调查", "callback":_close_panel},
		{"text":"保存并回到标题", "callback":_return_to_title}
	])
	player.controls_enabled = false
	player.clear_motion()
	get_tree().paused = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud) and is_instance_valid(player) and not hud.panel_open and not get_tree().paused:
		_pause_menu()

func _return_to_title() -> void:
	_close_panel()
	if not GameState.save_opening_checkpoint():
		_say("保存失败", "当前进度未能保存，仍留在现场。请检查存储空间和文件夹权限后重试。")
		return
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")

func _update_objective() -> void:
	if not is_instance_valid(hud): return
	var flags := GameState.opening_flags
	var target := ""
	if not flags.beach_footprints_solved:
		if not flags.beach_headlights_on:
			target = "car"
			hud.objective.text = "打开救援车远光灯，借灯光看清浪边被冲上岸的残骸"
		else:
			target = "trace_a" if not flags.beach_trace_a_seen else ("wrack" if not flags.beach_wrack_seen else "trace_b")
			var collected := int(flags.beach_trace_a_seen) + int(flags.beach_wrack_seen) + int(flags.beach_trace_b_seen)
			if player.position.y < 312.0:
				hud.objective.text = "趁退潮下石阶，借车灯调查三处残骸与踪迹 %d / 3（防备屠夫灭口）" % collected
			else:
				hud.objective.text = "潮水淹过证据！先退回干沙等退潮" if tide.is_wet(TARGETS[target]) else "躲避拎刀屠夫，按 E 调查微光线索 %d / 3" % collected
	elif not GameState.opening_flags.beach_plan_found:
		target = "cabinet" if flags.beach_cabinet_key_found else "key_box"
		if flags.beach_cabinet_open:
			hud.objective.text = "资料柜已开！按 [ E ] 取出里面的【沿海工事维护图】"
		else:
			hud.objective.text = "那具是失踪邮差，嘉敏逃进了工事！去蓝门旁【资料柜】找路线" if target == "cabinet" else "确认嘉敏未死、屠夫想灭口！去右上救生站【蓝门左旁保管箱】取钥匙"
	elif not GameState.opening_flags.beach_circuit_matched:
		target = "cabinet"
		hud.objective.text = "在蓝门旁【资料柜】核对维护图，标出高于潮线的安全通道"
	else:
		target = "road_exit"
		hud.objective.text = "锁定高位侧井！沿上方海滨步道最左侧进入【沿海工事维护通道】"
	# Never float ugly yellow "救援车 ↓" world labels over the painted beach — use a subtle grounded moonlight pulse instead!
	next_marker.visible = false
	if is_instance_valid(target_glint):
		target_glint.visible = not target.is_empty()
		if target_glint.visible:
			var pulse := 0.30 + 0.24 * (0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.0045))
			target_glint.position = TARGETS[target] + Vector2(0, -4)
			target_glint.modulate = Color(0.95, 0.86, 0.58, pulse)

func checkpoint() -> void:
	if not GameState.save_opening_checkpoint() and is_instance_valid(hud):
		hud.show_resource_feedback("进度保存失败，当前仍可继续。请检查存储空间后重试。")
