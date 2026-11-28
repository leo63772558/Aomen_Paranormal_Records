extends Node2D

const ROOM_ID := "ch5_coastal_pressure_gallery"
const WORLD_SIZE := Vector2(1280, 720)
const GAUGE_VISUAL_POS := Vector2(1008, 105)
const BLEED_VISUAL_POS := Vector2(1030, 168)
const TARGETS := {
	"schematic": Vector2(394, 352),
	"gauge": Vector2(1008, 338),
	"drain": Vector2(1142, 500),
	"inlet": Vector2(315, 352),
	"bypass": Vector2(968, 338),
	"bleed": Vector2(1045, 338),
	"cabinet": Vector2(156, 440),
	"exit": Vector2(640, 145),
	"return": Vector2(640, 662)
}
const NAMES := {
	"schematic": "查看墙上的管线示意图",
	"gauge": "检查压力表",
	"drain": "观察侧沟的淤泥流向",
	"inlet": "操作左侧进水轮",
	"bypass": "操作右侧旁通轮",
	"bleed": "打开表下泄压阀",
	"cabinet": "检查左侧检修柜",
	"exit": "进入上方拱道",
	"return": "退回淤泥岔口"
}
const EVIDENCE_FLAGS := {
	"schematic": "coastal_pressure_diagram_seen",
	"gauge": "coastal_pressure_gauge_seen",
	"drain": "coastal_pressure_drain_seen"
}
const VALVE_FLAGS := {
	"inlet": "coastal_pressure_inlet_closed",
	"bypass": "coastal_pressure_bypass_open",
	"bleed": "coastal_pressure_bleeder_open"
}
const VALVE_SEQUENCE := ["inlet", "bypass", "bleed"]
const GAUGE_ROTATION := [0.0, 0.37, 0.76, 1.2]
const PRESSURE_PANEL := preload("res://ui/coastal_pressure_console.gd")

var player: PlayerController
var hud
var selected_id := ""
var after_panel := Callable()
var widget: Control
var hotspots: Dictionary = {}
var valve_handles: Dictionary = {}
var gauge_needle: Line2D
var control_marker: Label
var verified_route_mark: Line2D
var cabinet_visual: Node2D
var cabinet_door: Polygon2D
var cabinet_paper: Polygon2D
var scene_action_active := false
var leaving := false
var valve_motion: Tween
var arch_water: Polygon2D
var drain_water: Polygon2D
var water_time := 0.0


func _ready() -> void:
	GameState.prepare_opening_resume()
	if GameState.current_room_id != ROOM_ID:
		push_error("The pressure gallery must be entered through the room registry.")
		return
	if not GameState.opening_flags.coastal_silt_route_verified:
		push_error("The pressure gallery requires the verified silt-tunnel route.")
		return
	AudioManager.set_scene_ambience("coastal")
	_build_background()
	_build_geometry()
	_build_mechanical_indicators()
	_build_water_effects()
	_build_cabinet_visual()
	_build_route_mark()
	_build_hotspots()
	control_marker = preload("res://ui/coastal_route_panel.gd").marker(self, "调压台", Vector2(396, 185))
	player = preload("res://entities/player/player.tscn").instantiate()
	player.visual_size_multiplier = 1.85
	if GameState.pending_entry_id == "from_silt_tunnel":
		player.position = Vector2(640, 660)
		player.look_dir = Vector2.UP
	else:
		player.position = Vector2(640, 224)
		player.look_dir = Vector2.DOWN
	add_child(player)
	var camera := player.get_node("Camera2D") as Camera2D
	camera.enabled = true
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	hud = preload("res://ui/quiet_hud.gd").new()
	add_child(hud)
	hud.journal_note_provider = _journal_text
	hud.close_requested.connect(_close_panel)
	hud.pause_requested.connect(_pause_menu)
	_update_objective()
	_fade_in()
	if not GameState.opening_flags.coastal_pressure_intro_seen:
		GameState.opening_flags.coastal_pressure_intro_seen = true
		GameState.unlock_macau_guide("coastal_pressure_room", false)
		checkpoint()
		hud.notify("水压锁住了检修柜。靠近墙图或任一手轮，按 E 打开调压台。")


func _build_background() -> void:
	var background := Sprite2D.new()
	background.name = "CoastalPressureGalleryBackground"
	background.texture = preload("res://assets/tilesets/coastal_pressure_gallery_060.png")
	background.centered = false
	background.scale = WORLD_SIZE / background.texture.get_size()
	background.z_index = -10
	add_child(background)
	var ambient := CanvasModulate.new()
	ambient.color = Color("858980")
	add_child(ambient)


func _wall(rect: Rect2) -> void:
	LevelGeometry.wall(self, rect)


func _build_geometry() -> void:
	# The top arch is the forward edge of the map; the south arch returns to the silt tunnel.
	# Seal the entire back brick wall on both sides of the central arch down to the floor line.
	_wall(Rect2(0, 0, 558, 325))
	_wall(Rect2(740, 0, 540, 325))
	_wall(Rect2(0, 18, 58, 684))
	_wall(Rect2(1262, 18, 18, 684))
	_wall(Rect2(18, 700, 542, 20))
	_wall(Rect2(720, 700, 542, 20))

	# Wall returns around each arch keep the visible brick and the walkable corridor aligned.
	_wall(Rect2(540, 18, 18, 206))
	_wall(Rect2(740, 18, 18, 206))
	_wall(Rect2(560, 682, 18, 38))
	_wall(Rect2(702, 682, 18, 38))

	# Visible machinery, cabinet, and drainage channel have solid footprints.
	_wall(Rect2(58, 292, 92, 295))
	_wall(Rect2(205, 225, 211, 121))
	_wall(Rect2(875, 202, 244, 133))
	_wall(Rect2(1148, 274, 132, 426))


func _build_mechanical_indicators() -> void:
	valve_handles["inlet"] = _make_wheel_indicator("InletWheelIndicator", TARGETS.inlet)
	valve_handles["bypass"] = _make_wheel_indicator("BypassWheelIndicator", TARGETS.bypass)
	valve_handles["bleed"] = _make_wheel_indicator("BleedCockIndicator", BLEED_VISUAL_POS)

	gauge_needle = Line2D.new()
	gauge_needle.name = "PressureGaugeNeedle"
	gauge_needle.points = PackedVector2Array([Vector2.ZERO, Vector2(13, -7)])
	gauge_needle.position = GAUGE_VISUAL_POS
	gauge_needle.width = 3.0
	gauge_needle.default_color = Color("e0d0a3")
	gauge_needle.z_index = 5
	add_child(gauge_needle)
	gauge_needle.rotation = GAUGE_ROTATION[pressure_stage()]
	for id in VALVE_SEQUENCE:
		if GameState.opening_flags[VALVE_FLAGS[id]]:
			valve_handles[id].rotation = PI / 2.0


func _build_water_effects() -> void:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float elapsed;
varying vec2 surface;
void vertex() {
	surface = VERTEX;
}
void fragment() {
	float band = sin(surface.y * 0.36 - elapsed * 7.0 + sin(surface.x * 0.19) * 1.4);
	float ripple = smoothstep(0.38, 0.92, band);
	COLOR = vec4(mix(vec3(0.12, 0.26, 0.24), vec3(0.57, 0.66, 0.57), ripple), COLOR.a * (0.41 + ripple * 0.25));
}"""
	arch_water = _water_surface(shader, PackedVector2Array([
		Vector2(581, 136), Vector2(700, 136), Vector2(706, 220), Vector2(577, 220)
	]))
	drain_water = _water_surface(shader, PackedVector2Array([
		Vector2(1120, 294), Vector2(1175, 292), Vector2(1222, 549), Vector2(1168, 549)
	]))
	arch_water.modulate.a = 0.0 if pressure_stage() == 3 else 0.34
	drain_water.modulate.a = 0.08


func _water_surface(shader: Shader, points: PackedVector2Array) -> Polygon2D:
	var surface := Polygon2D.new()
	var material := ShaderMaterial.new()
	material.shader = shader
	surface.material = material
	surface.polygon = points
	surface.z_index = -4
	add_child(surface)
	return surface


func _make_wheel_indicator(node_name: String, at: Vector2) -> Node2D:
	# Clean logical pivot without ugly programmer-art white circles over the painted valves
	var wheel := Node2D.new()
	wheel.name = node_name
	wheel.position = at
	wheel.z_index = 5
	add_child(wheel)
	return wheel


func _build_cabinet_visual() -> void:
	# Clean logical container with subtle warm glint when unlocked (no floating gray rectangles)
	cabinet_visual = Node2D.new()
	cabinet_visual.name = "OpenedCabinetVisual"
	cabinet_visual.position = TARGETS.cabinet
	cabinet_visual.z_index = 3
	cabinet_paper = Polygon2D.new()
	cabinet_paper.visible = false
	cabinet_visual.add_child(cabinet_paper)
	cabinet_door = Polygon2D.new()
	cabinet_door.visible = false
	cabinet_visual.add_child(cabinet_door)
	var opened: bool = GameState.opening_flags.coastal_works_record_found
	_update_cabinet_visual_state(opened)
	add_child(cabinet_visual)


func _update_cabinet_visual_state(opened: bool) -> void:
	if not is_instance_valid(cabinet_door) or not is_instance_valid(cabinet_paper):
		return
	cabinet_paper.visible = opened


func _build_route_mark() -> void:
	verified_route_mark = Line2D.new()
	verified_route_mark.name = "VerifiedPressureRoute"
	verified_route_mark.visible = false
	add_child(verified_route_mark)


func _build_hotspots() -> void:
	for id in TARGETS:
		var area := Area2D.new()
		area.name = "Inspect_" + id
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


func _process(delta: float) -> void:
	water_time += delta
	for surface in [arch_water, drain_water]:
		if is_instance_valid(surface):
			surface.material.set_shader_parameter("elapsed", water_time)
	if not is_instance_valid(player) or not is_instance_valid(hud) or hud.panel_open or scene_action_active:
		return
	selected_id = ""
	var best := INF
	for id in TARGETS:
		var offset: Vector2 = TARGETS[id] - player.position
		var distance := offset.length()
		var alignment := player.look_dir.dot(offset.normalized()) if distance > 0.1 else 1.0
		var interaction_range := 82.0
		if id in ["schematic", "gauge", "drain", "cabinet"]:
			interaction_range = 106.0
		elif id in ["inlet", "bypass", "bleed"]:
			interaction_range = 138.0
		elif id == "exit":
			interaction_range = 112.0
		elif id == "return":
			interaction_range = 82.0
		if distance > interaction_range or alignment < -0.1:
			continue
		var score := distance + (1.0 - alignment) * 45.0
		if score < best:
			selected_id = id
			best = score
	var prompt_name: String = NAMES.get(selected_id, "")
	if selected_id in ["inlet", "bypass", "bleed"] and GameState.opening_flags[VALVE_FLAGS[selected_id]]:
		prompt_name = "确认阀门状态 · " + prompt_name
	elif selected_id == "cabinet" and GameState.opening_flags.coastal_pressure_bleeder_open:
		prompt_name = "打开检修柜并读取记录"
	elif selected_id == "exit" and GameState.opening_flags.coastal_pressure_route_verified:
		prompt_name = "进入百利新邨旧地基"
	if selected_id == "return" and not GameState.uses_legacy_coastal_rooms():
		prompt_name = "退回沿海闸室"
	hud.prompt.text = "[ E ] " + prompt_name if not selected_id.is_empty() else ""
	_update_objective()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not is_instance_valid(hud) or hud.panel_open or scene_action_active:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		await interact_target(selected_id)
	elif event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		_open_widget(preload("res://ui/demo_bag.gd").new())
	elif event.is_action_pressed("journal"):
		get_viewport().set_input_as_handled()
		_open_record()


func interact_target(id: String) -> void:
	if scene_action_active:
		return
	if id == "return":
		await _return_to_silt_tunnel()
	elif id == "exit":
		await _attempt_forward_route()
	elif EVIDENCE_FLAGS.has(id):
		_inspect_evidence(id)
	elif VALVE_FLAGS.has(id):
		_open_pressure_console()
	elif id == "cabinet":
		_open_maintenance_record()


func _inspect_evidence(id: String) -> void:
	GameState.opening_flags[EVIDENCE_FLAGS[id]] = true
	checkpoint()
	if id == "drain":
		hud.show_resource_feedback("压力表下的细管接到这条侧沟。")
	else:
		_open_pressure_console()


func _open_pressure_console() -> void:
	_open_widget(PRESSURE_PANEL.new().setup(self))


func pressure_stage() -> int:
	var stage := 0
	for id in VALVE_SEQUENCE:
		if not GameState.opening_flags[VALVE_FLAGS[id]]:
			break
		stage += 1
	return stage


func _operate_valve(id: String) -> void:
	if scene_action_active:
		return
	var index := VALVE_SEQUENCE.find(id)
	var stage := pressure_stage()
	if index < stage:
		return
	var accepted := index == stage
	var handle: Node2D = valve_handles[id]
	var panel := widget as PRESSURE_PANEL
	scene_action_active = true
	player.controls_enabled = false
	player.clear_motion()
	hud.prompt.text = ""
	AudioManager.play_world_effect("valve_turn_heavy" if accepted else "valve_resist_clank", true)
	if is_instance_valid(panel):
		panel.begin_turn(id, accepted)
	valve_motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	valve_motion.tween_method(func(progress: float):
		var kick := sin(progress * PI)
		handle.rotation = PI / 2.0 * progress if accepted else 0.37 * kick
		if accepted:
			gauge_needle.rotation = lerpf(GAUGE_ROTATION[stage], GAUGE_ROTATION[stage + 1], progress)
			if id == "bleed":
				arch_water.modulate.a = 0.34 * (1.0 - progress)
				drain_water.modulate.a = 0.08 + 0.52 * kick
		else:
			gauge_needle.rotation = GAUGE_ROTATION[stage] - 0.14 * kick
		if is_instance_valid(widget) and not widget.is_queued_for_deletion() and widget is PRESSURE_PANEL:
			widget.animate_turn(progress)
	, 0.0, 1.0, 0.65 if accepted else 0.48).set_trans(Tween.TRANS_SINE)
	await valve_motion.finished
	if not is_inside_tree() or not is_instance_valid(player):
		return
	valve_motion = null
	if accepted:
		GameState.opening_flags[VALVE_FLAGS[id]] = true
		checkpoint()
	scene_action_active = false
	player.controls_enabled = not hud.panel_open
	var line: String
	if accepted:
		line = ["进水停了，表针仍在余压区。", "水从旁通走了，主路压力下降。", "侧沟泄完了。左边柜锁弹开，上方拱道退水。"][index]
		if id == "bleed":
			AudioManager.play_world_effect("lock_mechanism", true)
	else:
		line = "水顶回了手轮。来水还在流。" if id == "bypass" else "侧沟反冲，小阀弹了回来。"
	if is_instance_valid(panel) and not panel.is_queued_for_deletion():
		panel.finish_turn(line)
	else:
		hud.show_resource_feedback(line)
	_update_objective()


func _open_maintenance_record() -> void:
	if not GameState.opening_flags.coastal_pressure_bleeder_open:
		_say("检修柜仍受压", "柜门锁片压得很紧。先按墙图、表针和水痕判断阀门次序，确认管线泄压后再动柜门。")
		return
	if not GameState.opening_items.has("multitool_pliers"):
		_say("缺少检修工具", "锁片已经松开，但还需要大文随身的多功能钳才能夹开卡住的柜扣。")
		return
	var newly_found: bool = not GameState.opening_flags.coastal_works_record_found
	GameState.opening_flags.coastal_works_record_found = true
	_update_cabinet_visual_state(true)
	if is_instance_valid(cabinet_visual):
		cabinet_visual.visible = true
	if newly_found:
		AudioManager.play_world_effect("lock_mechanism")
		AudioManager.play_world_effect("archive_ticket_pickup")
		checkpoint()
	hud.show_resource_feedback("记录收好。沿上方退水的拱道走。")


func _attempt_forward_route() -> void:
	if leaving:
		return
	if not GameState.opening_flags.coastal_pressure_bleeder_open:
		hud.show_resource_feedback("拱道还在回水。先让压力归零。")
		return
	if not GameState.opening_flags.coastal_works_record_found:
		hud.show_resource_feedback("左侧检修柜里有路线，先取出来。")
		return
	leaving = true
	scene_action_active = true
	player.controls_enabled = false
	player.clear_motion()
	GameState.opening_flags.coastal_pressure_route_verified = true
	verified_route_mark.visible = true
	checkpoint()
	var card := ChapterLandmarkTransition.play(
		self,
		"最终章 · 石屎筹局",
		"离开黑沙沿海泄压暗渠 → 沿废弃排水管廊潜入百利新邨夹层",
		"暗渠尽头通往路氹旧楼「百利新邨」被连夜封死的渗血石屎夹层……",
		"稍早之前 · 夹层另一侧……",
		"gate_iron",
		"res://assets/ui/map_landmarks/stop_8_bleeding_wall.png"
	)
	await card.completed
	if not is_inside_tree():
		return
	if GameState.request_room_change("ch6_abandoned_vip", "from_pressure_gallery"):
		GameState.save_transition_checkpoint()
	else:
		if is_instance_valid(card):
			card.dismiss()
		leaving = false
		scene_action_active = false
		player.controls_enabled = true
		hud.show_resource_feedback("入口暂时无法打开，请再试一次。")


func _open_record() -> void:
	_say("现场线索 · 调压廊", _journal_text())

func _journal_text() -> String:
	var lines: Array[String] = ["沿海工事 · 调压廊记录", ""]
	for id in ["schematic", "gauge", "drain"]:
		var flag_id: String = EVIDENCE_FLAGS[id]
		lines.append(("✓ " if GameState.opening_flags[flag_id] else "□ ") + NAMES[id])
	lines.append("\n阀门操作：")
	for id in ["inlet", "bypass", "bleed"]:
		lines.append(("✓ " if GameState.opening_flags[VALVE_FLAGS[id]] else "□ ") + NAMES[id])
	lines.append("\n沿海工事运行记录：" + ("已收录" if GameState.opening_flags.coastal_works_record_found else "尚未读取"))
	lines.append("前路核验：" + ("已完成" if GameState.opening_flags.coastal_pressure_route_verified else "尚未完成"))
	if GameState.opening_flags.coastal_pressure_route_verified:
		lines.append("\n拱道干燥，旧记录支持检修线继续向深处延伸；不能据此确定嘉敏的位置。")
	else:
		lines.append("\n将墙图、压力表与侧沟的证据合起来，按安全顺序操作阀门，再读检修柜里的运行记录。")
	return "\n".join(lines)


func _update_objective() -> void:
	if not is_instance_valid(hud):
		return
	var flags := GameState.opening_flags
	control_marker.visible = not flags.coastal_pressure_bleeder_open
	hud.state_text.text = "调压廊"
	if flags.coastal_works_record_found:
		hud.objective.text = "走到上方拱门，按 E 进入百利新邨渗血石屎地基。"
		hud.set_investigation_hints(player, PackedStringArray())
	elif flags.coastal_pressure_bleeder_open:
		hud.objective.text = "到左边检修柜，按 E 取出路线。"
		hud.set_investigation_hints(player, PackedStringArray([
			"水压已归零，去左侧检修柜取出路线记录。"
		]), 10)
	else:
		hud.objective.text = "靠近墙图或任一手轮按 E，操作调压台。"
		var progress := int(flags.coastal_pressure_diagram_seen) + int(flags.coastal_pressure_gauge_seen) + int(flags.coastal_pressure_drain_seen) + pressure_stage()
		hud.set_investigation_hints(player, PackedStringArray([
			"水压持续给管线加压，先摸清调压台的流向与阀门。",
			"对照墙图、压力表与侧沟水痕，判断先断哪路、再走哪路。",
			"在调压台先关闭来水轮，再接通旁通分流，最后打开泄压阀。"
		]), progress)


func _open_widget(control: Control) -> void:
	if scene_action_active:
		control.queue_free()
		return
	if is_instance_valid(widget) and widget != control:
		widget.queue_free()
	widget = control
	hud.open_widget(control)
	player.controls_enabled = false
	player.clear_motion()
	get_tree().paused = true


func _say(title: String, body: String) -> void:
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
	if valve_motion and valve_motion.is_valid():
		valve_motion.play()
	player.controls_enabled = not scene_action_active
	player.clear_motion()
	var callback := after_panel
	after_panel = Callable()
	if callback.is_valid():
		callback.call()


func _pause_menu() -> void:
	if valve_motion and valve_motion.is_valid():
		valve_motion.pause()
	hud.open_panel("暂停", "调压廊调查已暂停。", [
		{"text": "继续调查", "callback": _close_panel},
		{"text": "保存并回到标题", "callback": _return_to_title}
	])
	player.controls_enabled = false
	player.clear_motion()
	get_tree().paused = true

func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT or not is_instance_valid(hud) or not is_instance_valid(player):
		return
	if not hud.panel_open or (valve_motion and valve_motion.is_valid() and is_instance_valid(widget)):
		_pause_menu()


func _return_to_title() -> void:
	_close_panel()
	if not GameState.save_opening_checkpoint():
		_say("保存失败", "当前进度未能保存，仍留在现场。请检查存储空间和文件夹权限后重试。")
		return
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")



func _return_to_silt_tunnel() -> void:
	if scene_action_active:
		return
	scene_action_active = true
	player.controls_enabled = false
	player.clear_motion()
	var layer := CanvasLayer.new()
	layer.layer = 20
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	add_child(layer)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.55)
	await tween.finished
	if not is_inside_tree(): return
	var legacy_route := GameState.uses_legacy_coastal_rooms()
	var dest_room := "ch5_coastal_silt_tunnel" if legacy_route else "ch5_coastal_chamber"
	var dest_entry := "from_pressure_gallery" if legacy_route else "from_silt_tunnel"
	if GameState.request_room_change(dest_room, dest_entry):
		GameState.save_transition_checkpoint()
	else:
		layer.queue_free()
		scene_action_active = false
		if is_instance_valid(player):
			player.controls_enabled = true
		_say("南侧拱道暂时无法通行", "还在调压廊。稍后可以在拱道旁再按 E 试一次。")


func _fade_in() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	add_child(layer)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(fade, "color:a", 0.0, 0.55)
	await tween.finished
	if is_instance_valid(layer):
		layer.queue_free()


func checkpoint() -> void:
	if not GameState.save_opening_checkpoint() and is_instance_valid(hud):
		hud.show_resource_feedback("进度保存失败，当前仍可继续。请检查存储空间后重试。")
