extends Node2D

const ROOM_ID := "ch5_coastal_landing"
const WORLD_SIZE := Vector2(1280, 720)
const TARGETS := {
	"ladder": Vector2(169, 312),
	"drain": Vector2(784, 423),
	"shutter": Vector2(880, 251),
	"crawlway": Vector2(1143, 241)
}
const NAMES := {
	"ladder": "沿井梯返回上层通道",
	"drain": "检查下层排水支路",
	"shutter": "检查锈死的检修闸门",
	"crawlway": "查看箭头指向的窄通道"
}
const FLAGS := {
	"drain": "coastal_lower_drain_seen",
	"shutter": "coastal_shutter_seen",
	"crawlway": "coastal_crawlway_seen"
}

var player: PlayerController
var hud
var selected_id := ""
var after_panel := Callable()
var widget: Control
var hotspots: Dictionary = {}
var transition_active := false

func _ready() -> void:
	GameState.prepare_opening_resume()
	if GameState.current_room_id != ROOM_ID or not GameState.opening_flags.coastal_route_verified:
		push_error("The lower coastal landing requires the verified shaft route.")
		return
	AudioManager.set_scene_ambience("coastal")
	_build_background()
	_build_geometry()
	_build_hotspots()
	player = preload("res://entities/player/player.tscn").instantiate()
	player.visual_size_multiplier = 1.9
	player.position = Vector2(1150, 276) if GameState.pending_entry_id == "from_crawlway" else Vector2(207, 316)
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
	_update_objective()
	_fade_in()
	if not GameState.opening_flags.coastal_landing_seen:
		GameState.opening_flags.coastal_landing_seen = true
		checkpoint()
		hud.notify("闸门锈死了。右侧窄口挂着一缕红布。")

func _build_background() -> void:
	var background := Sprite2D.new()
	background.name = "CoastalLandingBackground"
	background.texture = preload("res://assets/tilesets/coastal_works_lower_057.png")
	background.centered = false
	background.scale = WORLD_SIZE / background.texture.get_size()
	background.z_index = -10
	add_child(background)
	var ambient := CanvasModulate.new()
	ambient.color = Color("8b928a")
	add_child(ambient)

func _build_geometry() -> void:
	LevelGeometry.polygon_wall(self, PackedVector2Array([
		Vector2(-16, -16), Vector2(1296, -16), Vector2(1296, 318),
		Vector2(1236, 318), Vector2(1236, 165), Vector2(1140, 165),
		Vector2(1123, 254), Vector2(1099, 265), Vector2(1070, 251),
		Vector2(755, 251), Vector2(750, 270), Vector2(606, 286),
		Vector2(257, 286), Vector2(237, 267), Vector2(210, 252),
		Vector2(66, 246), Vector2(52, 276), Vector2(-16, 276)
	]))
	# Protect the painted pump and ladder hole while keeping the walkways open.
	LevelGeometry.polygon_wall(self, PackedVector2Array([
		Vector2(607, 280), Vector2(622, 240), Vector2(678, 237),
		Vector2(700, 250), Vector2(763, 255), Vector2(773, 303),
		Vector2(760, 326), Vector2(651, 326), Vector2(633, 308)
	]))
	LevelGeometry.polygon_wall(self, PackedVector2Array([
		Vector2(102, 239), Vector2(167, 244), Vector2(184, 293),
		Vector2(175, 325), Vector2(142, 338), Vector2(104, 326), Vector2(84, 300)
	]), false)
	# The north edge of the bars is the end of the dry approach.
	LevelGeometry.polygon_wall(self, PackedVector2Array([
		Vector2(-16, 276), Vector2(51, 276), Vector2(54, 333),
		Vector2(83, 368), Vector2(154, 389), Vector2(203, 379),
		Vector2(243, 350), Vector2(593, 350), Vector2(599, 393),
		Vector2(682, 393), Vector2(708, 425), Vector2(868, 425),
		Vector2(902, 393), Vector2(979, 393), Vector2(984, 345),
		Vector2(1135, 345), Vector2(1141, 324), Vector2(1236, 324),
		Vector2(1236, 318), Vector2(1296, 318), Vector2(1296, 736),
		Vector2(-16, 736)
	]), false)

func _build_hotspots() -> void:
	for id in TARGETS:
		var area := Area2D.new()
		area.name = "Inspect_" + id
		area.position = TARGETS[id]
		area.collision_layer = 8
		area.collision_mask = 2
		var collision := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 30
		collision.shape = shape
		area.add_child(collision)
		add_child(area)
		hotspots[id] = area

func _process(_delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(hud) or hud.panel_open:
		return
	selected_id = ""
	var best := INF
	for id in TARGETS:
		var offset: Vector2 = TARGETS[id] - player.position
		var distance := offset.length()
		var alignment := player.look_dir.dot(offset.normalized()) if distance > 0.1 else 1.0
		if distance > (68.0 if id == "ladder" else (92.0 if id == "drain" else 64.0)) or alignment < -0.1:
			continue
		var score := distance + (1.0 - alignment) * 45.0
		if score < best:
			selected_id = id
			best = score
	var prompt_name: String = "沿右侧窄道前进" if selected_id == "crawlway" else NAMES.get(selected_id, "")
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
		_open_record()

func interact_target(id: String) -> void:
	if transition_active:
		return
	if id == "ladder":
		_return_to_upper()
	elif id == "crawlway":
		GameState.opening_flags.coastal_crawlway_seen = true
		checkpoint()
		_enter_crawlway()
	elif FLAGS.has(id):
		_inspect(id)

func _inspect(id: String) -> void:
	var flag_id: String = FLAGS[id]
	var already_seen := bool(GameState.opening_flags[flag_id])
	if not already_seen:
		GameState.opening_flags[flag_id] = true
		checkpoint()
	match id:
		"drain":
			hud.show_resource_feedback("铁栏下的水还在涨。")
		"shutter":
			hud.show_resource_feedback("门锈住了。右边有她留下的红布。")

func _all_lower_evidence_seen() -> bool:
	for flag_id in FLAGS.values():
		if not GameState.opening_flags[flag_id]:
			return false
	return true

func _open_record() -> void:
	_say("现场线索 · 沿海工事", _journal_text())

func _journal_text() -> String:
	var lines: Array[String] = ["沿海工事 · 下层记录", ""]
	for id in ["drain", "shutter", "crawlway"]:
		var flag_id: String = FLAGS[id]
		lines.append(("✓ " if GameState.opening_flags[flag_id] else "□ ") + NAMES[id])
	if _all_lower_evidence_seen():
		lines.append("\n退路被潮线与封闭闸门排除；箭头和布丝指向右侧窄道。后续连通方向仍未核实。")
	else:
		lines.append("\n核对水线、闸门状态和红布方向，再判断嘉敏从哪里继续前进。")
	return "\n".join(lines)

func _update_objective() -> void:
	if not is_instance_valid(hud):
		return
	hud.state_text.text = "井下平台     [ B ] 线索"
	hud.objective.text = "三项现场痕迹已核对。沿右侧干燥窄道继续前进。" if _all_lower_evidence_seen() else "沿着红布线索走到右边窄口，按 E 钻过去。"

func _open_widget(control: Control) -> void:
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
	player.controls_enabled = not transition_active
	player.clear_motion()
	var callback := after_panel
	after_panel = Callable()
	if callback.is_valid():
		callback.call()

func _pause_menu() -> void:
	hud.open_panel("暂停", "沿海工事下层平台已暂停。", [
		{"text": "继续调查", "callback": _close_panel},
		{"text": "保存并回到标题", "callback": _return_to_title}
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

func _return_to_upper() -> void:
	if GameState.request_room_change("ch5_coastal_works", "from_landing"):
		GameState.save_transition_checkpoint()
	else:
		_say("暂时无法返回", "井梯上方的通道暂时无法载入。大文仍留在平台，请稍后重试。")

func _enter_crawlway(destination := "ch5_coastal_chamber") -> void:
	if transition_active:
		return
	if not GameState.opening_flags.coastal_crawlway_seen:
		return
	transition_active = true
	var safe_start := player.position
	player.controls_enabled = false
	player.clear_motion()
	player.crouching = true
	player.look_dir = Vector2.RIGHT
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 20
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade)
	add_child(fade_layer)
	var tween := create_tween()
	tween.tween_property(player, "position", TARGETS["crawlway"] + Vector2(38, 0), 0.52)
	tween.parallel().tween_property(fade, "color:a", 1.0, 0.72)
	await tween.finished
	if not is_inside_tree(): return
	if GameState.request_room_change(destination, "from_landing"):
		GameState.save_transition_checkpoint()
		return
	fade_layer.queue_free()
	transition_active = false
	player.position = safe_start
	player.reset_physics_interpolation()
	player.crouching = false
	player.controls_enabled = true
	_say("窄道暂时无法通行", "这段通道的现场痕迹已经核对，但前方暂时无法进入。大文退回平台，没有把未确认的去向记进线索。")

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
