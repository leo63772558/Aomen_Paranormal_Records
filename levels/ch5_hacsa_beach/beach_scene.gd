extends Node2D

const ROOM_ID := "ch5_hacsa_beach"
const WORLD_SIZE := Vector2(1280, 720)
const TARGETS := {
	"car":Vector2(400, 211),
	"key_box":Vector2(937, 171), "cabinet":Vector2(1110, 191),
	"trace_a":Vector2(660, 456),
	"wrack":Vector2(686, 510), "trace_b":Vector2(880, 370),
	"road_exit":Vector2(78, 100),
	"macau_pavilion":Vector2(218, 192),
	"macau_tinhau":Vector2(575, 220),
	"macau_fishlamp":Vector2(825, 206)
}
const NAMES := {
	"car":"检查救援车灯开关", "key_box":"检查高地钥匙箱", "cabinet":"查看蓝门旁资料柜",
	"sole":"查看手机原有鞋底照片", "trace_a":"调查向海边延伸的鞋印", "wrack":"查看覆在脚印上的潮线",
	"trace_b":"查看另一枚新鲜脚印", "road_exit":"进入沿海工事维护通道",
	"macau_pavilion":"查看凉亭长椅上的1985旧报剪报", "macau_tinhau":"查看石墙妈祖小龛", "macau_fishlamp":"查看路环防风旧渔灯"
}
const CAR_ORIGIN := Vector2(548, 201)
const CAR_DIRECTION := Vector2(0.921, 0.389)
const CAR_RANGE := 690.0
const CAR_HALF_ANGLE := 0.72

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
var cabinet_interior: Sprite2D
var cabinet_plan: Sprite2D
var service_action_active := false
var plan_preview_pending := false
var key_box_overlay: Sprite2D
var ghost: Node2D
var last_safe_anchor := Vector2(190, 221)
var tall_blockers: Array[CollisionObject2D] = []
var next_marker: Label
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
	hud.journal_page_factory = _make_footprints.bind("sole")
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
		checkpoint()
		_say("黑沙 · 翻车之后", "海浪里那个呼唤声……听着像嘉敏！但手札里提过黑沙海滩夜里常见怕车灯的白衣溺水影，1985 年八仙饭店案最初也是在这片黑沙滩发现残迹。先去上方救援车打开远光灯照清海面！")

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
	# Roadside shelter, rescue vehicle and hut match the background's footprints.
	_solid(Rect2(148, 78, 161, 105), true)
	_solid(Rect2(355, 85, 207, 125))
	_solid(Rect2(940, 0, 340, 219), true)
	# The seawall leaves both flights of stairs open. The dry sand beside its
	# base is another permanent refuge, so tide never seals every escape route.
	for rect in [Rect2(0, 240, 146, 74), Rect2(251, 240, 644, 74), Rect2(991, 240, 289, 74)]:
		_solid(rect)
	for x in [20, 74, 345, 602, 813, 1218]:
		_solid(Rect2(x - 7, 210, 14, 24))
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
	add_child(next_marker)

func _build_car_lights() -> void:
	for offset in [Vector2(-8, -7), Vector2(8, 7)]:
		var lamp := PointLight2D.new()
		lamp.position = CAR_ORIGIN + offset
		lamp.rotation = CAR_DIRECTION.angle()
		lamp.texture = preload("res://assets/lighting/flashlight_cone.png")
		lamp.scale = Vector2(2.7, 4.1)
		lamp.energy = 0.58 if GameState.opening_flags.beach_headlights_on else 0.0
		lamp.color = Color("d9dfd1")
		lamp.range_item_cull_mask = 5
		lamp.shadow_item_cull_mask = 4
		lamp.shadow_enabled = true
		add_child(lamp)
		car_lights.append(lamp)

func _build_cabinet() -> void:
	cabinet_interior = Sprite2D.new()
	cabinet_interior.name = "DocumentCabinetInterior"
	var interior := AtlasTexture.new()
	interior.atlas = preload("res://assets/props/beach_mechanism_clean_040b.png")
	interior.region = Rect2(179, 275, 286, 222)
	cabinet_interior.texture = interior
	cabinet_interior.position = Vector2(1122, 156)
	cabinet_interior.scale = Vector2(40, 49) / interior.region.size
	cabinet_interior.modulate = Color("947d61")
	cabinet_interior.z_index = 223
	add_child(cabinet_interior)

	cabinet_plan = Sprite2D.new()
	cabinet_plan.name = "FoldedMaintenancePlan"
	cabinet_plan.texture = DemoItems.texture("hotel_maintenance_plan")
	cabinet_plan.position = Vector2(1124, 160)
	cabinet_plan.scale = Vector2(26, 36) / cabinet_plan.texture.get_size()
	cabinet_plan.rotation = -0.12
	cabinet_plan.z_index = 224
	add_child(cabinet_plan)

	cabinet_lid = Sprite2D.new()
	cabinet_lid.name = "DocumentCabinetLid"
	var crop := AtlasTexture.new()
	crop.atlas = preload("res://assets/tilesets/hacsa_beach_038.png")
	crop.region = Rect2(1433, 163, 66, 82)
	crop.filter_clip = true
	cabinet_lid.texture = crop
	cabinet_lid.centered = false
	cabinet_lid.position = Vector2(1097, 125)
	cabinet_lid.scale = Vector2(1280.0 / 1672.0, 720.0 / 941.0)
	cabinet_lid.z_index = 225
	add_child(cabinet_lid)
	key_box_overlay = Sprite2D.new()
	key_box_overlay.texture = _mechanism_cell(0, GameState.opening_flags.beach_cabinet_key_found)
	key_box_overlay.position = Vector2(945, 143)
	key_box_overlay.scale = Vector2.ONE * 0.045
	key_box_overlay.visible = GameState.opening_flags.beach_key_box_open
	key_box_overlay.z_index = 225
	add_child(key_box_overlay)
	if GameState.opening_flags.beach_cabinet_open:
		cabinet_lid.skew = -0.32
		cabinet_lid.scale.x *= 0.16
	cabinet_interior.visible = GameState.opening_flags.beach_cabinet_open
	cabinet_plan.visible = cabinet_interior.visible and not GameState.opening_flags.beach_plan_found

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
	for index in range(8):
		var print_sprite := Sprite2D.new()
		var texture := footprint_cell(3 if index == 7 else (1 if index < 4 else 2))
		print_sprite.texture = texture
		print_sprite.position = Vector2(880, 370) if index == 7 else Vector2(644 + index * 8, 416 + index * 23)
		print_sprite.rotation = -0.12 if index % 2 == 0 else 0.08
		print_sprite.scale = Vector2(16.0, 25.0) / texture.region.size
		var shader := Shader.new()
		shader.code = "shader_type canvas_item; uniform vec4 crop_uv; void fragment(){vec4 c=texture(TEXTURE,UV); vec2 p=(UV-crop_uv.xy)/crop_uv.zw; vec2 e=smoothstep(vec2(0.0),vec2(0.16),p)*smoothstep(vec2(0.0),vec2(0.16),vec2(1.0)-p); COLOR=c*vec4(vec3(0.85),e.x*e.y*0.90);}"
		var material := ShaderMaterial.new()
		material.shader = shader
		var image_size := texture.atlas.get_size()
		material.set_shader_parameter("crop_uv", Vector4(texture.region.position.x / image_size.x, texture.region.position.y / image_size.y, texture.region.size.x / image_size.x, texture.region.size.y / image_size.y))
		print_sprite.material = material
		add_child(print_sprite)

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
	elif event.is_action_pressed("journal") or event.is_action_pressed("phone"):
		get_viewport().set_input_as_handled()
		_open_footprints()

func interact_target(id: String) -> void:
	if service_action_active:
		return
	match id:
		"sole", "trace_a", "wrack", "trace_b":
			var flag_id: String = {"sole":"beach_sole_seen", "trace_a":"beach_trace_a_seen", "wrack":"beach_wrack_seen", "trace_b":"beach_trace_b_seen"}[id]
			GameState.opening_flags[flag_id] = true
			checkpoint()
			_open_footprints(id)
		"car": _open_service("car")
		"key_box": _open_service("key_box")
		"cabinet": _inspect_cabinet()
		"road_exit": _leave_beach()
		"macau_pavilion": _say("1985 八仙饭店旧案剪报 · 辟谣档案", "凉亭长椅上压着嘉敏手札掉出的一页泛黄剪报：1985 年 8 月，路环黑沙海滩首次冲上残肢，揭开八仙饭店灭门惨案。\n\n旁边贴着 2019 年澳门《正报》资深记者访谈批注：当年坊间疯传的「人肉叉烧包」纯属小报猎奇杜撰，并非警方查证事实。嘉敏在页脚写着：「记住历史真相，不要消费逝者，也别被海里的假哭声骗下水。」")
		"macau_tinhau": hud.show_resource_feedback("石墙边的路环妈祖小神龛，红香脚已经被咸湿海风吹冷了。")
		"macau_fishlamp": hud.show_resource_feedback("路环老渔民挂在岸边的防风铁皮渔灯，玻璃罩结满了一层海盐霜。")

func _open_footprints(focus := "sole") -> void:
	_open_widget(_make_footprints(focus))

func _make_footprints(focus: String) -> Control:
	if not GameState.has_demo_item("shoe_repair_photo") or not GameState.opening_flags.beach_sole_seen:
		GameState.take_demo_item("shoe_repair_photo")
		GameState.opening_flags.beach_sole_seen = true
		checkpoint()
	var board := preload("res://ui/beach_footprints.gd").new()
	board.configure(self, focus)
	board.solved.connect(func():
		GameState.opening_flags.beach_footprints_solved = true
		checkpoint()
		_update_objective()
		hud.show_resource_feedback("这一串脚印早于潮水。嘉敏也许已经上了高地。")
	)
	return board

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
	_say("退到灯下", "抓过来的手没碰到石阶。大文撑住栏杆，退回高地。\n\n白影避开的是车头远光，位置灯挡不住它；干带和石阶一直可以退回。已经收起的证据仍在包里。")

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
		cabinet_interior.show()
		cabinet_plan.show()
		var tween := create_tween()
		tween.tween_property(cabinet_lid, "scale:x", 1280.0 / 1672.0 * 0.16, 0.65).set_trans(Tween.TRANS_CUBIC)
		tween.parallel().tween_property(cabinet_lid, "skew", -0.32, 0.65)
		AudioManager.play_world_effect("entrance_door")
		await tween.finished
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
		_say("不能只凭鞋印", "如果这是嘉敏刚刚留下的，我不能掉头离开。先对照原有鞋底维修照、鞋印和潮线，判断这是不是刚刚留下的痕迹。")
	elif not GameState.opening_flags.beach_circuit_matched:
		_say("沿海工事维护图", "图上有不止一条通道。排水口已经在潮线内；先沿纸上的维护线路核对上层侧井，不能把通海排水口当入口。")
	else:
		if GameState.request_room_change("ch5_coastal_works", "from_beach"):
			GameState.save_transition_checkpoint()
		else:
			_say("沿海工事维护通道", "图纸指向高于潮线的侧井。入口的粉笔箭头仍在，但这条通道暂时无法进入。")

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
		AudioManager.play_world_effect("oil_drops")
		if is_instance_valid(hud):
			hud.notify("浪声变近，低地开始回水。靠墙的干带与两处石阶都能退回高地。")

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
			hud.objective.text = "去救援车旁开远光灯，照亮黑沙滩。"
		elif not (flags.beach_trace_a_seen and flags.beach_wrack_seen and flags.beach_trace_b_seen):
			if player.position.y < 312.0:
				hud.objective.text = "下石阶到干沙区，调查海边的鞋印。"
			target = "trace_a" if not flags.beach_trace_a_seen else ("wrack" if not flags.beach_wrack_seen else "trace_b")
			if player.position.y >= 312.0:
				hud.objective.text = "潮水正在上涨，先退回干沙等退潮。" if tide.is_wet(TARGETS[target]) else "靠近金色标记按 E 查看鞋印。"
		else:
			hud.objective.text = "按 J 打开手札，将鞋底照拖到沙印上比对。"
	elif not GameState.opening_flags.beach_plan_found:
		target = "cabinet" if flags.beach_cabinet_key_found else "key_box"
		if flags.beach_cabinet_open:
			hud.objective.text = "资料柜打开了。按 E 取里面的折叠图。"
		else:
			hud.objective.text = "到救生站蓝门旁打开资料柜。" if target == "cabinet" else "上到右侧高地，在蓝门左边的保管箱取钥匙。"
	elif not GameState.opening_flags.beach_circuit_matched:
		target = "cabinet"
		hud.objective.text = "在资料柜重看图纸，找一条高于潮线的路。"
	else:
		target = "road_exit"
		hud.objective.text = "沿高处步道向左，找到和图纸一样的井梯标记。"
	next_marker.visible = not target.is_empty()
	if next_marker.visible:
		var caption: String = {"trace_a":"A · 鞋印", "wrack":"A · 潮线", "trace_b":"B · 新印", "car":"救援车", "key_box":"保管箱", "cabinet":"资料柜", "road_exit":"维护入口"}[target]
		next_marker.text = caption + "  ↓"
		next_marker.size = Vector2(124, 20)
		next_marker.position = TARGETS[target] - Vector2(62, 31)

func checkpoint() -> void:
	if not GameState.save_opening_checkpoint() and is_instance_valid(hud):
		hud.show_resource_feedback("进度保存失败，当前仍可继续。请检查存储空间后重试。")
