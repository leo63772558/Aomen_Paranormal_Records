extends Node2D

const ROOM_ID := "ch5_coastal_chamber"
const WORLD_SIZE := Vector2(1280, 720)
const TARGETS := {
	"tide": Vector2(620, 325),
	"grate": Vector2(715, 425),
	"hatch": Vector2(990, 365),
	"west": Vector2(188, 386),
	"next": Vector2(72, 356),
	"return": Vector2(1160, 270)
}
const NAMES := {
	"tide": "检查墙上的盐线",
	"grate": "查看中央地栅的沉积",
	"hatch": "检查梯子和高处检修盖",
	"west": "查看左拱道的粉笔续痕",
	"next": "沿左拱道前进",
	"return": "退回井下维护平台"
}
const FLAGS := {
	"tide": "coastal_chamber_tide_seen",
	"grate": "coastal_chamber_grate_seen",
	"hatch": "coastal_chamber_hatch_seen",
	"west": "coastal_chamber_west_seen"
}

var player: PlayerController
var drain_scare_played := false
var hud
var selected_id := ""
var after_panel := Callable()
var widget: Control
var hotspots: Dictionary = {}
var chalk_arrow: Line2D
var transition_active := false

func _ready() -> void:
	GameState.prepare_opening_resume()
	if GameState.current_room_id != ROOM_ID:
		push_error("The coastal chamber must be entered through the room registry.")
		return
	if not GameState.opening_flags.coastal_route_verified or not GameState.opening_flags.coastal_crawlway_seen:
		push_error("The coastal chamber requires the evidence-verified crawlway route.")
		return
	AudioManager.set_scene_ambience("crypt")
	_build_background()
	_build_geometry()
	_build_markings()
	_build_hotspots()
	player = preload("res://entities/player/player.tscn").instantiate()
	player.visual_size_multiplier = 1.85
	player.position = Vector2(140, 356) if GameState.pending_entry_id == "from_silt_tunnel" else Vector2(1150, 276)
	player.look_dir = Vector2.RIGHT if GameState.pending_entry_id == "from_silt_tunnel" else Vector2.LEFT
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
	if not GameState.opening_flags.coastal_chamber_intro_seen:
		GameState.opening_flags.coastal_chamber_intro_seen = true
		checkpoint()
		hud.notify("左边拱门还有粉笔记号。")
	else:
		_update_objective()

func _build_background() -> void:
	var background := Sprite2D.new()
	background.name = "CoastalChamberBackground"
	background.texture = preload("res://assets/tilesets/coastal_works_chamber_058.png")
	background.centered = false
	background.scale = WORLD_SIZE / background.texture.get_size()
	background.z_index = -10
	add_child(background)
	var ambient := CanvasModulate.new()
	ambient.color = Color("858980")
	add_child(ambient)

func _build_geometry() -> void:
	# Trace the floor-contact edges of the wall, ladder and arch piers.
	LevelGeometry.polygon_wall(self, PackedVector2Array([
		Vector2(-16, -16), Vector2(1124, -16), Vector2(1124, 197),
		Vector2(1099, 233), Vector2(1107, 400), Vector2(1098, 467),
		Vector2(1074, 467), Vector2(1065, 363), Vector2(1024, 363),
		Vector2(1024, 378), Vector2(966, 378), Vector2(966, 357),
		Vector2(893, 357), Vector2(890, 384), Vector2(826, 384),
		Vector2(826, 354), Vector2(339, 354), Vector2(334, 381),
		Vector2(257, 381), Vector2(257, 353), Vector2(148, 353),
		Vector2(148, 279), Vector2(40, 279), Vector2(28, 352), Vector2(-16, 352)
	]))
	LevelGeometry.polygon_wall(self, PackedVector2Array([
		Vector2(1124, -16), Vector2(1296, -16), Vector2(1296, 736),
		Vector2(530, 736), Vector2(530, 622), Vector2(1174, 622),
		Vector2(1167, 565), Vector2(1180, 521), Vector2(1226, 508),
		Vector2(1249, 461), Vector2(1261, 371), Vector2(1261, 271),
		Vector2(1242, 229), Vector2(1200, 201), Vector2(1164, 207),
		Vector2(1124, 234)
	]))
	# The flush grate and the paving outside the low pool remain walkable.
	LevelGeometry.polygon_wall(self, PackedVector2Array([
		Vector2(-16, 352), Vector2(28, 352), Vector2(66, 405),
		Vector2(61, 433), Vector2(167, 434), Vector2(215, 446),
		Vector2(328, 470), Vector2(365, 484), Vector2(512, 483),
		Vector2(529, 519), Vector2(546, 602), Vector2(552, 736),
		Vector2(-16, 736)
	]), false)

func _build_markings() -> void:
	# A thin, scuffed chalk arrow is an inspectable clue, never a collision surface.
	chalk_arrow = Line2D.new()
	chalk_arrow.name = "ChalkRouteMark"
	chalk_arrow.points = PackedVector2Array([
		Vector2(252, 409), Vector2(213, 409), Vector2(184, 409),
		Vector2(203, 397), Vector2(184, 409), Vector2(203, 422)
	])
	chalk_arrow.width = 2.4
	chalk_arrow.default_color = Color("a29a82")
	chalk_arrow.antialiased = true
	chalk_arrow.z_index = -3
	add_child(chalk_arrow)

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
		shape.radius = 30 if id != "hatch" else 34
		collision.shape = shape
		area.add_child(collision)
		add_child(area)
		hotspots[id] = area

func _process(_delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(hud) or hud.panel_open:
		return
	if not drain_scare_played and player.position.x < 740.0 and player.position.y < 540.0:
		drain_scare_played = true
		_play_drain_scare()
	selected_id = ""
	var best := INF
	for id in TARGETS:
		var offset: Vector2 = TARGETS[id] - player.position
		var distance := offset.length()
		var alignment := player.look_dir.dot(offset.normalized()) if distance > 0.1 else 1.0
		var interaction_range: float = 76.0 if id == "return" else (78.0 if id == "next" else (88.0 if id == "hatch" else 62.0))
		if distance > interaction_range or alignment < -0.1:
			continue
		var score := distance + (1.0 - alignment) * 45.0
		if score < best:
			selected_id = id
			best = score
	var prompt_name: String = NAMES.get(selected_id, "")
	if selected_id == "west" and GameState.opening_flags.coastal_chamber_route_verified:
		prompt_name = "复查左拱道的粉笔痕"
	elif selected_id == "next" and not GameState.opening_flags.coastal_chamber_route_verified:
		prompt_name = "沿粉笔记号进入左拱道"
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
	if id == "return":
		_return_to_landing()
	elif id == "next":
		GameState.opening_flags.coastal_chamber_west_seen = true
		GameState.opening_flags.coastal_chamber_route_verified = true
		checkpoint()
		_enter_silt_tunnel()
	elif FLAGS.has(id):
		_inspect(id)

func _inspect(id: String) -> void:
	var flag_id: String = FLAGS[id]
	var already_seen := bool(GameState.opening_flags[flag_id])
	if not already_seen:
		GameState.opening_flags[flag_id] = true
		checkpoint()
	if _all_route_evidence_seen() and not GameState.opening_flags.coastal_chamber_route_verified:
		GameState.opening_flags.coastal_chamber_route_verified = true
		chalk_arrow.default_color = Color("d9cba3")
		checkpoint()
		hud.show_resource_feedback("左拱道是干的。粉笔指向里面。")
		return
	match id:
		"tide":
			hud.show_resource_feedback("盐线高过地栅。涨潮会淹没低处。")
		"grate":
			hud.show_resource_feedback("水流向铁栏后的低池。")
		"hatch":
			hud.show_resource_feedback("梯脚的锈还在。这里没人爬过。")
		"west":
			hud.show_resource_feedback("粉笔箭头通向左拱道。")

func _all_route_evidence_seen() -> bool:
	for flag_id in FLAGS.values():
		if not GameState.opening_flags[flag_id]:
			return false
	return true

func _open_record() -> void:
	_say("手札 · 沿海闸室", _journal_text())

func _journal_text() -> String:
	var lines: Array[String] = ["沿海闸室 · 现场记录", ""]
	for id in ["tide", "grate", "hatch", "west"]:
		var flag_id: String = FLAGS[id]
		lines.append(("✓ " if GameState.opening_flags[flag_id] else "□ ") + NAMES[id])
	if GameState.opening_flags.coastal_chamber_route_verified:
		lines.append("\n低池与旧梯路已排除，左拱道的干燥门槛和粉笔痕相互印证。前方位置仍未知。")
	else:
		lines.append("\n把潮线、地栅沉积、梯脚锈层和左拱痕迹放在一起判断。")
	return "\n".join(lines)

func _update_objective() -> void:
	if not is_instance_valid(hud):
		return
	hud.state_text.text = "沿海闸室     [ J ] 手札"
	if GameState.opening_flags.coastal_chamber_route_verified:
		hud.objective.text = "路线已核验。沿左拱道进入岔口，或从右侧窄道返回平台。"
	else:
		hud.objective.text = "沿干地去左边拱道。别靠近铁栏后的水。"

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
	hud.open_panel("暂停", "沿海闸室已暂停。", [
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

func _use_three_room_coastal() -> bool:
	for tag in ["057", "058", "059", "060", "225", "works", "silt", "press"]:
		if tag in GameState.run_id:
			return false
	return true

func _return_to_landing() -> void:
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
	var dest_room := "ch5_coastal_works" if _use_three_room_coastal() else "ch5_coastal_landing"
	var dest_entry := "from_landing" if _use_three_room_coastal() else "from_crawlway"
	if GameState.request_room_change(dest_room, dest_entry):
		GameState.save_transition_checkpoint()
	else:
		layer.queue_free()
		transition_active = false
		if is_instance_valid(player):
			player.controls_enabled = true
		_say("窄道暂时无法返回", "入口位置未能确认。大文留在闸室，没有被送到未核验的地点。")

func _enter_silt_tunnel() -> void:
	if transition_active:
		return
	if not GameState.opening_flags.coastal_chamber_route_verified:
		_say("路线还没核实", "先把盐线、地栅沉积、检修盖和左拱粉笔痕放在一起看。大文不会只凭一条箭头就贸然深入。")
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
	if _use_three_room_coastal():
		for f in ["coastal_chamber_tide_seen", "coastal_chamber_grate_seen", "coastal_chamber_hatch_seen", "coastal_chamber_west_seen", "coastal_chamber_route_verified", "coastal_silt_intro_seen", "coastal_silt_map_seen", "coastal_silt_sluice_seen", "coastal_silt_collapse_seen", "coastal_silt_grate_seen", "coastal_silt_arch_seen", "coastal_silt_route_verified"]:
			GameState.opening_flags[f] = true
	var dest_room := "ch5_coastal_pressure_gallery" if _use_three_room_coastal() else "ch5_coastal_silt_tunnel"
	var dest_entry := "from_silt_tunnel" if _use_three_room_coastal() else "from_chamber"
	if GameState.request_room_change(dest_room, dest_entry):
		GameState.save_transition_checkpoint()
	else:
		layer.queue_free()
		transition_active = false
		if is_instance_valid(player):
			player.controls_enabled = true
		_say("岔口暂时无法进入", "场景入口没有通过登记核验。大文仍留在闸室，没有被送到未登记的地点。")

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

func _play_drain_scare() -> void:
	var sheet := preload("res://assets/characters/shadow_walk_011.png")
	var figure := Sprite2D.new()
	var crop := AtlasTexture.new()
	crop.atlas = sheet
	crop.region = Rect2(362, 0, 362, 724)
	figure.texture = crop
	figure.position = Vector2(274, 625)
	figure.scale = Vector2.ONE * 0.16
	figure.modulate = Color(0.68, 0.78, 0.74, 0.0)
	figure.z_index = 6
	add_child(figure)
	var ripple := Polygon2D.new()
	ripple.polygon = PackedVector2Array([Vector2(180, 560), Vector2(460, 560), Vector2(475, 650), Vector2(165, 650)])
	ripple.color = Color(0.55, 0.72, 0.68, 0.0)
	ripple.z_index = 5
	add_child(ripple)
	AudioManager.play_at(self, "gate_chain", figure.position)
	AudioManager.play_world_effect("hall_wail")
	if is_instance_valid(hud):
		hud.show_resource_feedback("铁栏后面的黑水猛地翻涌——有东西攀在铁栏后死死盯着你！")
	var animation := create_tween()
	animation.tween_property(ripple, "color:a", 0.32, 0.12)
	animation.parallel().tween_property(figure, "modulate:a", 0.92, 0.12)
	animation.parallel().tween_property(figure, "position:y", 548.0, 0.18)
	animation.tween_callback(func():
		crop.region = Rect2(724, 0, 362, 724)
		AudioManager.play_world_effect("gate_iron")
	)
	animation.tween_property(figure, "scale", Vector2.ONE * 0.21, 0.14)
	animation.parallel().tween_property(figure, "position", Vector2(312, 522), 0.14)
	animation.tween_callback(func():
		crop.region = Rect2(1086, 0, 362, 724)
	)
	animation.tween_property(figure, "position", Vector2(398, 585), 0.32)
	animation.parallel().tween_property(figure, "modulate:a", 0.0, 0.32)
	animation.parallel().tween_property(ripple, "color:a", 0.0, 0.32)
	animation.tween_callback(func():
		figure.queue_free()
		ripple.queue_free()
	)
