extends Node2D

const ROOM_ID := "ch5_coastal_silt_tunnel"
const WORLD_SIZE := Vector2(1280, 720)
const TARGETS := {
	"map": Vector2(708, 215),
	"sluice": Vector2(1052, 270),
	"collapse": Vector2(212, 300),
	"grate": Vector2(344, 444),
	"arch": Vector2(346, 274),
	"spare_battery": Vector2(692, 615),
	"return": Vector2(592, 552)
}
const NAMES := {
	"map": "查看墙上的工事示意图",
	"sluice": "检查右侧封闭闸门",
	"collapse": "检查左侧坍塌支路",
	"grate": "查看地栅与淤泥",
	"arch": "沿小拱门进入调压廊",
	"spare_battery": "更换备用电池",
	"return": "退回闸室"
}
const FLAGS := {
	"map": "coastal_silt_map_seen",
	"sluice": "coastal_silt_sluice_seen",
	"collapse": "coastal_silt_collapse_seen",
	"grate": "coastal_silt_grate_seen"
}

var player: PlayerController
var hud
var selected_id := ""
var after_panel := Callable()
var widget: Control
var hotspots: Dictionary = {}
var route_mark: Line2D
var spare_battery
var transition_active := false

func _ready() -> void:
	GameState.prepare_opening_resume()
	if GameState.current_room_id != ROOM_ID:
		push_error("The silt tunnel must be entered through the room registry.")
		return
	if not GameState.opening_flags.coastal_chamber_route_verified:
		push_error("The silt tunnel requires the evidence-verified chamber route.")
		return
	AudioManager.set_scene_ambience("crypt")
	_build_background()
	_build_geometry()
	if not GameState.opening_flags.silt_spare_battery_taken:
		spare_battery = preload("res://core/components/spare_battery.gd").new()
		spare_battery.taken_flag = "silt_spare_battery_taken"
		spare_battery.position = TARGETS.spare_battery
		add_child(spare_battery)
	_build_route_mark()
	_build_hotspots()
	preload("res://ui/coastal_route_panel.gd").marker(self, "工事图", Vector2(708, 211))
	player = preload("res://entities/player/player.tscn").instantiate()
	player.visual_size_multiplier = 1.85
	match GameState.pending_entry_id:
		"from_chamber":
			player.position = Vector2(590, 662)
			player.look_dir = Vector2.UP
		"from_pressure_gallery":
			player.position = Vector2(346, 338)
			player.look_dir = Vector2.DOWN
		_:
			player.position = Vector2(590, 552)
			player.look_dir = Vector2.UP
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
	if not GameState.opening_flags.coastal_silt_intro_seen:
		GameState.opening_flags.coastal_silt_intro_seen = true
		checkpoint()
		hud.notify("墙上有张工事图。")
	else:
		_update_objective()

func _build_background() -> void:
	var background := Sprite2D.new()
	background.name = "CoastalSiltTunnelBackground"
	background.texture = preload("res://assets/tilesets/coastal_works_silt_tunnel_059.png")
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
	# The painted room is reachable from the south service passage.
	_wall(Rect2(0, 0, 1280, 198))
	_wall(Rect2(0, 18, 18, 492))
	_wall(Rect2(1262, 18, 18, 492))
	_wall(Rect2(18, 505, 437, 18))
	_wall(Rect2(735, 505, 527, 18))
	_wall(Rect2(455, 505, 18, 215))
	_wall(Rect2(717, 505, 18, 215))
	_wall(Rect2(0, 702, 1280, 18))

	# The collapsed west branch, upper brick wall, closed gate, and flooded sill are solid.
	_wall(Rect2(0, 0, 236, 405))
	_wall(Rect2(236, 198, 378, 45))
	_wall(Rect2(807, 198, 473, 40))
	_wall(Rect2(1038, 92, 207, 249))
	_wall(Rect2(792, 348, 446, 18))
	_wall(Rect2(792, 366, 18, 132))
	_wall(Rect2(614, 86, 193, 116))
	_wall(Rect2(296, 414, 101, 62))

func _build_route_mark() -> void:
	route_mark = Line2D.new()
	route_mark.name = "VerifiedDryRoute"
	route_mark.points = PackedVector2Array([
		Vector2(592, 555), Vector2(520, 492), Vector2(476, 420),
		Vector2(428, 354), Vector2(386, 309), Vector2(347, 278)
	])
	route_mark.width = 2.4
	route_mark.default_color = Color("c5b995", 0.72)
	route_mark.antialiased = true
	route_mark.z_index = -3
	route_mark.visible = GameState.opening_flags.coastal_silt_route_verified
	add_child(route_mark)

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
		shape.radius = 32
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
		if id == "spare_battery" and not is_instance_valid(spare_battery):
			continue
		var offset: Vector2 = TARGETS[id] - player.position
		var distance := offset.length()
		var alignment := player.look_dir.dot(offset.normalized()) if distance > 0.1 else 1.0
		var interaction_range := 70.0
		if id in ["sluice", "grate", "map", "collapse"]:
			interaction_range = 88.0
		elif id == "spare_battery":
			interaction_range = 48.0
		elif id == "return":
			interaction_range = 76.0
		if distance > interaction_range or alignment < -0.1:
			continue
		var score := distance + (1.0 - alignment) * 45.0
		if score < best:
			selected_id = id
			best = score
	var prompt_name: String = NAMES.get(selected_id, "")
	if selected_id == "arch":
		if GameState.opening_flags.coastal_silt_route_verified:
			prompt_name = "沿已核实的干路继续"
		else:
			prompt_name = "沿小拱门进入调压廊"
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
	if id == "spare_battery" and is_instance_valid(spare_battery):
		hud.show_resource_feedback(spare_battery.collect(player))
	elif id == "return":
		_return_to_chamber()
	elif id == "arch":
		if not GameState.opening_flags.coastal_silt_route_verified:
			_confirm_arch()
		_enter_pressure_gallery()
	elif FLAGS.has(id):
		_inspect(id)

func _inspect(id: String) -> void:
	var flag_id: String = FLAGS[id]
	var newly_seen: bool = not bool(GameState.opening_flags[flag_id])
	if newly_seen:
		GameState.opening_flags[flag_id] = true
		checkpoint()
	match id:
		"map":
			_open_widget(preload("res://ui/coastal_route_panel.gd").new().setup("silt"))
		"sluice":
			hud.show_resource_feedback("积水顶着锈门，手轮拧不动。")
		"collapse":
			hud.show_resource_feedback("左边已被落石堵住。")
		"grate":
			hud.show_resource_feedback("水从地栅往低处倒灌。")

func _all_evidence_seen() -> bool:
	for flag_id in FLAGS.values():
		if not GameState.opening_flags[flag_id]:
			return false
	return true

func _confirm_arch() -> void:
	GameState.opening_flags.coastal_silt_arch_seen = true
	GameState.opening_flags.coastal_silt_route_verified = true
	route_mark.visible = true
	checkpoint()

func _open_record() -> void:
	_say("手札 · 淤泥岔口", _journal_text())

func _journal_text() -> String:
	var lines: Array[String] = ["沿海工事 · 淤泥岔口记录", ""]
	for id in ["map", "sluice", "collapse", "grate"]:
		var flag_id: String = FLAGS[id]
		lines.append(("✓ " if GameState.opening_flags[flag_id] else "□ ") + NAMES[id])
	if GameState.opening_flags.coastal_silt_route_verified:
		lines.append("\n中央拱道与旧示意图的红线相符；图纸未标明后续地点。")
	elif _all_evidence_seen():
		lines.append("\n线索已齐。到中央拱口核对图线与地面擦痕。")
	else:
		lines.append("\n结合图线、闸门锈封、坍塌状态和水流淤积，排除不可通行的支路。")
	return "\n".join(lines)

func _update_objective() -> void:
	if not is_instance_valid(hud):
		return
	hud.state_text.text = "淤泥岔口     [ J ] 手札"
	if GameState.opening_flags.coastal_silt_route_verified:
		hud.objective.text = "中央干路已核实。走入拱道继续，或返回闸室。"
	elif _all_evidence_seen():
		hud.objective.text = "到中央拱口，核对红线与地面擦痕。"
	else:
		hud.objective.text = "往墙上图框走可查看旧图，或沿粉笔箭头穿过左边的小拱门。"

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
	hud.open_panel("暂停", "淤泥岔口调查已暂停。", [
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

func _return_to_chamber() -> void:
	if transition_active:
		return
	transition_active = true
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
	if GameState.request_room_change("ch5_coastal_chamber", "from_silt_tunnel"):
		GameState.save_transition_checkpoint()
	else:
		layer.queue_free()
		transition_active = false
		if is_instance_valid(player):
			player.controls_enabled = true
		_say("暂时无法返回", "闸室入口没有通过登记核验。大文仍留在岔口，没有被送到未登记的地点。")

func _enter_pressure_gallery() -> void:
	if transition_active:
		return
	if not GameState.opening_flags.coastal_silt_route_verified:
		_say("路线尚未核实", "先检查图纸、闸门、坍塌和地栅，再到中央拱道确认地面痕迹。")
		return
	transition_active = true
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
	if GameState.request_room_change("ch5_coastal_pressure_gallery", "from_silt_tunnel"):
		GameState.save_transition_checkpoint()
	else:
		layer.queue_free()
		transition_active = false
		if is_instance_valid(player):
			player.controls_enabled = true
		_say("暂时无法继续", "调压廊入口没有通过登记核验。大文仍留在淤泥岔口，没有被送到未登记的地点。")

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
