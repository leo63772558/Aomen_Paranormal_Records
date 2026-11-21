extends Node2D

const ROOM_ID := "ch5_coastal_works"
const WORLD_SIZE := Vector2(1280, 720)
const TARGETS := {
	"entry": Vector2(45, 452),
	"arrow": Vector2(294, 468),
	"drain": Vector2(597, 624),
	"thread": Vector2(1054, 158),
	"ladder": Vector2(1160, 164)
}
const NAMES := {
	"entry": "沿楼梯返回救生站",
	"arrow": "查看干燥通道上的粉笔箭头",
	"drain": "检查排水口的潮线与铁栅",
	"thread": "查看圆井旁的布丝和金属擦痕",
	"ladder": "检查圆井里的梯级"
}
const EVIDENCE_FLAGS := {
	"arrow": "coastal_arrow_seen",
	"drain": "coastal_drain_seen",
	"thread": "coastal_thread_seen",
	"ladder": "coastal_ladder_seen"
}

var player: PlayerController
var hud
var widget: Control
var after_panel := Callable()
var selected_id := ""
var hotspots: Dictionary = {}
var transition_active := false
var drain_surge: Polygon2D
var surge_clock := 0.0

func _ready() -> void:
	GameState.prepare_opening_resume()
	if GameState.current_room_id != ROOM_ID:
		push_error("Coastal works must be entered through the room registry.")
		return
	if not GameState.opening_flags.beach_circuit_matched:
		push_error("The coastal works route requires the verified maintenance plan.")
		return
	AudioManager.set_scene_ambience("crypt")
	_build_background()
	_build_geometry()
	_build_hotspots()
	player = preload("res://entities/player/player.tscn").instantiate()
	player.visual_size_multiplier = 1.9
	player.position = Vector2(1093, 164) if GameState.pending_entry_id == "from_landing" else Vector2(54, 455)
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
	hud.journal_note_provider = _journal_text
	hud.close_requested.connect(_close_panel)
	hud.pause_requested.connect(_pause_menu)
	if not GameState.opening_flags.coastal_intro_seen:
		GameState.opening_flags.coastal_intro_seen = true
		checkpoint()
		hud.notify("墙上的粉笔箭头指向高处。")
	else:
		_update_objective()
		if GameState.opening_flags.coastal_route_verified and GameState.pending_entry_id != "from_landing":
			_say("回到井口", "井梯还在，沿梯可以继续下行。")

func _build_background() -> void:
	var background := Sprite2D.new()
	background.name = "CoastalWorksBackground"
	background.texture = preload("res://assets/tilesets/coastal_works_open_056.png")
	background.centered = false
	background.scale = WORLD_SIZE / background.texture.get_size()
	background.z_index = -10
	add_child(background)
	var ambient := CanvasModulate.new()
	ambient.color = Color("8b928a")
	add_child(ambient)
	drain_surge = Polygon2D.new()
	drain_surge.polygon = PackedVector2Array([
		Vector2(490, 520), Vector2(640, 520), Vector2(640, 680), Vector2(490, 680)
	])
	drain_surge.color = Color(0.18, 0.36, 0.34, 0.28)
	drain_surge.z_index = -2
	add_child(drain_surge)

func _wall(rect: Rect2) -> void:
	LevelGeometry.wall(self, rect)

func _build_geometry() -> void:
	# Main passage: entrance stair -> lower corridor -> north bend -> upper corridor.
	_wall(Rect2(-14, 0, 14, 720))
	_wall(Rect2(0, 0, 1280, 32))
	_wall(Rect2(0, 694, 1280, 26))
	_wall(Rect2(1264, 0, 16, 720))
	# Seal the entire top-left void and the lower corridor's upper brick wall.
	_wall(Rect2(0, 0, 484, 418))
	_wall(Rect2(0, 520, 475, 18))
	_wall(Rect2(574, 340, 14, 224))
	_wall(Rect2(578, 317, 18, 202))
	# Seal the upper corridor's back brick wall down to the floor line.
	_wall(Rect2(466, 0, 814, 130))
	_wall(Rect2(596, 309, 664, 18))
	_wall(Rect2(658, 327, 18, 367))

	# The plan's lower branch ends at a locked iron drain grille, above the tide line.
	_wall(Rect2(478, 520, 16, 141))
	_wall(Rect2(641, 520, 16, 141))
	_wall(Rect2(480, 636, 178, 84))

	# Keep the opening non-walkable while leaving its rim approachable.
	var shaft_blocker := StaticBody2D.new()
	shaft_blocker.collision_layer = 1
	shaft_blocker.collision_mask = 2
	var shaft_shape := CollisionShape2D.new()
	var shaft_circle := CircleShape2D.new()
	shaft_circle.radius = 53.0
	shaft_shape.shape = shaft_circle
	shaft_blocker.add_child(shaft_shape)
	shaft_blocker.position = TARGETS["ladder"]
	add_child(shaft_blocker)

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
		shape.radius = 26 if id != "ladder" else 34
		collision.shape = shape
		area.add_child(collision)
		add_child(area)
		hotspots[id] = area

func _process(delta: float) -> void:
	surge_clock += delta
	if is_instance_valid(drain_surge):
		var wave := 0.5 + 0.5 * sin(surge_clock * 2.4)
		drain_surge.color.a = lerpf(0.18, 0.52, wave)
		drain_surge.position.y = lerpf(0.0, -34.0, wave)
	if not is_instance_valid(player) or not is_instance_valid(hud) or hud.panel_open:
		return
	selected_id = ""
	var best := INF
	for id in TARGETS:
		var delta_to: Vector2 = TARGETS[id] - player.position
		var distance := delta_to.length()
		var alignment := player.look_dir.dot(delta_to.normalized()) if distance > 0.1 else 1.0
		if distance > (68.0 if id in ["entry", "ladder"] else (92.0 if id == "drain" else 55.0)) or alignment < -0.1:
			continue
		var score := distance + (1.0 - alignment) * 45.0
		if score < best:
			selected_id = id
			best = score
	var prompt_name: String = "沿梯下行" if selected_id == "ladder" and GameState.opening_flags.coastal_route_verified else NAMES.get(selected_id, "")
	hud.prompt.text = "[ E ] " + prompt_name if not selected_id.is_empty() else ""
	_update_objective()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not is_instance_valid(hud) or hud.panel_open:
		return
	if transition_active:
		if event.is_action_pressed("interact") or event.is_action_pressed("inventory") or event.is_action_pressed("journal"):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		interact_target(selected_id)
	elif event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		_open_widget(preload("res://ui/demo_bag.gd").new())
	elif event.is_action_pressed("journal"):
		get_viewport().set_input_as_handled()
		_open_route_record()

func interact_target(id: String) -> void:
	if transition_active:
		return
	match id:
		"entry": _return_to_beach()
		"arrow", "drain", "thread": _inspect_evidence(id)
		"ladder": _inspect_ladder()

func _inspect_evidence(id: String) -> void:
	var flag_id: String = EVIDENCE_FLAGS[id]
	var already_seen: bool = GameState.opening_flags[flag_id]
	if not already_seen:
		GameState.opening_flags[flag_id] = true
		checkpoint()
	if _all_route_evidence_seen() and not GameState.opening_flags.coastal_route_verified:
		GameState.opening_flags.coastal_route_verified = true
		checkpoint()
		hud.show_resource_feedback("红布和擦痕都指向井下。")
		return
	match id:
		"arrow":
			hud.show_resource_feedback("粉笔箭头指向上层的圆井。")
		"drain":
			hud.show_resource_feedback("低位铁栅锁着。这里只能排水。")
		"thread":
			hud.show_resource_feedback("螺栓上缠着嘉敏外套的红布。")

func _use_three_room_coastal() -> bool:
	for tag in ["057", "058", "059", "060", "225", "works", "silt", "press"]:
		if tag in GameState.run_id:
			return false
	return true

func _inspect_ladder() -> void:
	if not GameState.opening_flags.coastal_route_verified:
		GameState.opening_flags.coastal_ladder_seen = true
		GameState.opening_flags.coastal_route_verified = true
		checkpoint()
		hud.notify("井边卡着一缕红布，嘉敏是从这里下去的。")
	if _use_three_room_coastal():
		for f in ["coastal_arrow_seen", "coastal_drain_seen", "coastal_thread_seen", "coastal_ladder_seen", "coastal_route_verified", "coastal_landing_seen", "coastal_lower_drain_seen", "coastal_shutter_seen", "coastal_crawlway_seen"]:
			GameState.opening_flags[f] = true
		checkpoint()
		_descend_shaft("ch5_coastal_chamber", "from_landing")
	else:
		_descend_shaft()

func _descend_shaft(destination := "ch5_coastal_landing", entry_id := "from_shaft") -> void:
	if transition_active:
		return
	transition_active = true
	var safe_start := player.position
	player.controls_enabled = false
	player.clear_motion()
	player.look_dir = Vector2.DOWN
	var fade_layer := CanvasLayer.new()
	fade_layer.name = "ShaftTransitionFade"
	fade_layer.layer = 20
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade)
	add_child(fade_layer)
	var tween := create_tween()
	tween.tween_property(player, "position", TARGETS["ladder"] + Vector2(0, 18), 0.42)
	tween.parallel().tween_property(fade, "color:a", 1.0, 0.55)
	await tween.finished
	if not is_inside_tree(): return
	if GameState.request_room_change(destination, entry_id):
		# The destination marks and saves its first visit after it has loaded.
		pass
	else:
		fade_layer.queue_free()
		transition_active = false
		player.position = safe_start
		player.reset_physics_interpolation()
		player.controls_enabled = true
		_say("井梯暂时无法通行", "井口下方的铁梯已经核对，但当前无法进入。先回到现场重新检查通路。")

func _all_route_evidence_seen() -> bool:
	for flag_id in EVIDENCE_FLAGS.values():
		if not GameState.opening_flags[flag_id]:
			return false
	return true

func _open_route_record() -> void:
	_say("手札 · 沿海工事", _journal_text())

func _journal_text() -> String:
	var lines: Array[String] = ["沿海工事 · 现场记录", ""]
	for id in ["arrow", "drain", "thread", "ladder"]:
		var flag_id: String = EVIDENCE_FLAGS[id]
		lines.append(("✓ " if GameState.opening_flags[flag_id] else "□ ") + NAMES[id])
	if GameState.opening_flags.coastal_route_verified:
		lines.append("\n上层通道、潮线与梯井痕迹已核对。路线成立，嘉敏的当前位置仍未知。")
	else:
		lines.append("\n把纸上线路与现场方向、潮线和痕迹逐一对照。")
	return "\n".join(lines)

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
	player.controls_enabled = not transition_active
	player.clear_motion()
	var callback := after_panel
	after_panel = Callable()
	if callback.is_valid(): callback.call()

func _pause_menu() -> void:
	hud.open_panel("暂停", "沿海维护通道与现场痕迹已暂停。", [
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

func _return_to_beach() -> void:
	if GameState.request_room_change("ch5_hacsa_beach", "from_bus_crash"):
		GameState.save_transition_checkpoint()
	else:
		_say("暂时无法返回", "通往黑沙的入口暂时无法载入。大文仍留在维护通道，请稍后重试。")

func _update_objective() -> void:
	if not is_instance_valid(hud):
		return
	hud.state_text.text = "沿海工事     [ J ] 手札"
	if GameState.opening_flags.coastal_route_verified:
		hud.objective.text = "井梯线索已核对。靠近井口按 E 下行，继续追踪。"
	else:
		hud.objective.text = "跟着粉笔箭头上行，到圆井边按 E 下梯。"

func checkpoint() -> void:
	if not GameState.save_opening_checkpoint() and is_instance_valid(hud):
		hud.show_resource_feedback("进度保存失败，当前仍可继续。请检查存储空间后重试。")
