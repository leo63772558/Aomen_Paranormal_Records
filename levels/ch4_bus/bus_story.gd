extends "res://levels/ch4_bus/bus_loop.gd"

# The random prototype remains in bus_loop.tscn. This scene owns the authored
# observation sequence; visual changes never reroll a state already inspected.
const STAGE_FLAGS := ["bus_taught", "bus_reflection_cleared", "bus_voice_cleared", "bus_arrived"]
const REQUIRED := [
	["seat", "glass", "mirror", "display", "sign"],
	["seat", "glass", "notebook"],
	["display", "sign", "door", "notebook", "recording_matched"],
	["seat", "glass", "mirror", "display", "sign"]
]
const INSPECTIONS := {
	"seat": ["Mannequin", "核对后排座位"],
	"glass": ["SideGlass", "观察侧窗倒影"],
	"mirror": ["Mirror", "核对后视镜"],
	"display": ["StopScreen", "查看报站屏与旧语音"],
	"sign": ["RoadSign", "核对窗外站牌"],
	"door": ["FrontDoor", "检查前门与停车位置"]
}
var stage := 0
var observed: Dictionary = {}
var selected_story := ""
var safe_wait := 0.0
var bell_requested := false
var premature_bell_warned := false
var story_widget: Control
var passenger: Sprite2D
var reflection: Sprite2D
var passenger_body: StaticBody2D
var story_tween: Tween
var story_clock := 0.0
var outside_sign: Label
var safe_grip: Sprite2D
var last_failure := ""
var feedback_clock := 0.0
var scare_rig: Control
var standing_pose: Sprite2D
var walking_passenger: Node2D
var front_door: Node2D
var passenger_shadow: LightOccluder2D
var roadside_sign: Sprite2D
var departure_ready := false

func _ready() -> void:
	GameState.prepare_opening_resume()
	GameState.current_chapter_id = "ch4_bus33_loop"
	GameState.current_room_id = "ch4_bus_loop"
	_setup_audio()
	_setup_environment()
	_setup_props()
	_setup_collision()
	_setup_player()
	# The bus background contains tall seat backs; scale against their floor line,
	# then let PlayerController recalculate every pose and torch lens landmark.
	player.visual_size_multiplier = 3.1
	player.set_appearance("flashlight")
	_setup_hud()
	_setup_screamer_overlay()
	mannequin_sprite.hide()
	stage = 0
	for flag_id in STAGE_FLAGS:
		if GameState.opening_flags.get(flag_id, false):
			stage += 1
	stage = mini(stage, 3)
	_build_story_objects()
	_apply_story_stage()
	GameState.save_opening_checkpoint()
	if GameState.pending_entry_id == "from_w17_ticket" and stage == 0:
		call_deferred("_show_w17_arrival")

func _setup_hud() -> void:
	hud = preload("res://ui/quiet_hud.gd").new()
	add_child(hud)
	hud.show_resources(true)
	hud.close_requested.connect(_on_hud_close)
	hud.pause_requested.connect(_on_hud_pause)
	var stamp: Label = hud.label("33 路 · 异常末班车", Vector2(65, 76), Vector2(300, 20), 12, Color("c6b78f"))
	hud.root.move_child(stamp, 0)

func _show_w17_arrival() -> void:
	_say("独立机关样板", "此入口用于试玩车窗倒影、乘客下车、旧录音对齐与折叠门交互。\n\n样板有四个固定观察阶段，与正式主线的随机五连判断分开保存。后排坐着一名穿棕夹克的男人，先核对眼前座位和玻璃里的倒影。")

func _cell(index: int) -> AtlasTexture:
	var sheet := load("res://assets/characters/bus_passenger_034.png") as Texture2D
	return _atlas_cell(sheet, index % 2, index / 2)

func _build_story_objects() -> void:
	_add_interaction_sensor("SideGlass", Vector2(688, 229), 26)
	_add_interaction_sensor("RoadSign", Vector2(828, 229), 28)
	passenger = Sprite2D.new()
	passenger.name = "OrdinaryPassenger"
	passenger.texture = _cell(0)
	passenger.position = Vector2(620, 190)
	passenger.scale = Vector2.ONE * (120.0 / passenger.texture.get_height())
	passenger.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	passenger.z_index = 190
	add_child(passenger)
	reflection = Sprite2D.new()
	reflection.name = "WindowPassengerReflection"
	reflection.texture = _cell(2)
	reflection.position = Vector2(41, 83)
	reflection.scale = Vector2.ONE * (102.0 / reflection.texture.get_height())
	reflection.modulate = Color(0.53, 0.68, 0.66, 0.48)
	var window_clip := Control.new()
	window_clip.name = "GlassReflectionClip"
	window_clip.position = Vector2(647, 42)
	window_clip.size = Vector2(86, 105)
	window_clip.clip_contents = true
	window_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window_clip.z_index = 18
	add_child(window_clip)
	window_clip.add_child(reflection)
	# A reflected figure never has physical collision. The real seated body lies
	# inside the already solid seat row; only its shoes protrude towards the aisle.
	passenger_body = LevelGeometry.wall(self, Rect2(596, 233, 48, 16))
	passenger_body.name = "PassengerShoesCollision"
	passenger_shadow = get_child(get_child_count() - 1) as LightOccluder2D
	standing_pose = Sprite2D.new()
	standing_pose.texture = _cell(1)
	standing_pose.position = Vector2(620, 173)
	standing_pose.scale = Vector2.ONE * (170.0 / standing_pose.texture.get_height())
	standing_pose.z_index = 245
	standing_pose.modulate.a = 0.0
	add_child(standing_pose)
	walking_passenger = preload("res://entities/bus_passenger_walk.gd").new()
	walking_passenger.position = Vector2(620, 258)
	walking_passenger.modulate.a = 0.0
	walking_passenger.z_index = 275
	add_child(walking_passenger)
	var walking_body := AnimatableBody2D.new()
	walking_body.collision_layer = 1
	walking_body.collision_mask = 2
	var foot := CollisionShape2D.new()
	var foot_shape := CircleShape2D.new()
	foot_shape.radius = 10.0
	foot.shape = foot_shape
	foot.disabled = true
	walking_body.add_child(foot)
	walking_passenger.add_child(walking_body)
	front_door = preload("res://core/components/folding_bus_door.gd").new()
	front_door.name = "FoldingFrontDoor"
	front_door.position = Vector2(1133, 240)
	front_door.z_index = 205
	add_child(front_door)
	interaction_sensors.FrontDoor.position = Vector2(1133, 260)
	roadside_sign = Sprite2D.new()
	roadside_sign.texture = preload("res://core/components/folding_bus_door.gd").part(Rect2(835, 654, 213, 581))
	roadside_sign.position = Vector2(35, 67)
	roadside_sign.scale = Vector2.ONE * 0.22
	var roadside_clip := Control.new()
	roadside_clip.position = Vector2(803, 55)
	roadside_clip.size = Vector2(83, 90)
	roadside_clip.clip_contents = true
	roadside_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	roadside_clip.z_index = 16
	add_child(roadside_clip)
	roadside_clip.add_child(roadside_sign)
	outside_sign = Label.new()
	outside_sign.name = "PhysicalStopName"
	outside_sign.position = Vector2(817, 66)
	outside_sign.size = Vector2(43, 18)
	outside_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outside_sign.add_theme_font_size_override("font_size", 8)
	outside_sign.add_theme_color_override("font_color", Color("292d27"))
	outside_sign.add_theme_color_override("font_outline_color", Color("172522"))
	outside_sign.add_theme_constant_override("outline_size", 0)
	outside_sign.z_index = 17
	add_child(outside_sign)
	# Reuse a painted hand strap from this exact bus, rather than a flat marker.
	var grip_texture := AtlasTexture.new()
	grip_texture.atlas = bus_base.texture
	grip_texture.region = Rect2(1050, 124, 70, 74)
	grip_texture.filter_clip = true
	safe_grip = Sprite2D.new()
	safe_grip.texture = grip_texture
	safe_grip.position = Vector2(866, 204)
	safe_grip.scale = Vector2.ONE * 0.32
	safe_grip.z_index = 200
	add_child(safe_grip)

func _apply_story_stage() -> void:
	observed.clear()
	safe_wait = 0.0
	bell_requested = false
	premature_bell_warned = false
	current_anomaly = ""
	mannequin_sprite.hide()
	hands_sprite.hide()
	blood_particles.emitting = false
	passenger.visible = stage == 0
	passenger.position = Vector2(620, 190)
	passenger.texture = _cell(0)
	standing_pose.modulate.a = 0.0
	walking_passenger.modulate.a = 0.0
	walking_passenger.walking = false
	passenger_shadow.visible = stage == 0
	(passenger_body.get_child(0) as CollisionShape2D).set_deferred("disabled", stage != 0)
	reflection.visible = stage <= 1
	reflection.texture = _cell(2)
	reflection.modulate.a = 0.48
	outside_sign.text = "黑沙海滩" if stage == 3 else "旧站 · W-17"
	led_label.text = "[33] 黑沙海滩" if stage in [0, 3] else ("[33] 下一站……" if stage == 1 else "[33] 黑沙海滩")
	safe_grip.visible = stage == 1
	is_transitioning = false
	player.controls_enabled = true
	_update_hud_status()

func _process(delta: float) -> void:
	story_clock += delta
	if not is_instance_valid(hud):
		return
	if feedback_clock > 0.0:
		feedback_clock = maxf(0.0, feedback_clock - delta)
	_update_glitch(delta)
	_update_camera_shake(delta)
	if is_instance_valid(reflection):
		reflection.rotation = sin(story_clock * 0.65) * (0.018 if stage == 1 else 0.003)
	if is_instance_valid(safe_grip):
		safe_grip.rotation = sin(story_clock * 1.7) * 0.065
	if hud.panel_open or is_transitioning or in_cinematic:
		return
	if departure_ready and player.position.x >= 1113 and player.position.x <= 1153 and player.position.y <= 224:
		_finish_arrival()
		return
	if stage == 1 and _evidence_ready() and player.position.x >= 835 and player.position.x <= 900 and player.position.y >= 230 and player.position.y <= 287:
		safe_wait += delta
		if safe_wait >= 2.0:
			_advance_stage()
			return
	else:
		safe_wait = 0.0
	_update_interaction_prompts()
	_update_hud_status()

func _update_interaction_prompts() -> void:
	selected_story = ""
	var best := INF
	for id in INSPECTIONS:
		var sensor_id: String = INSPECTIONS[id][0]
		if not _sensor_overlaps(sensor_id):
			continue
		var distance := player.position.distance_to(interaction_sensors[sensor_id].position)
		if distance < best:
			best = distance
			selected_story = id
	if selected_story.is_empty():
		for bell_area: Area2D in bell_sensors:
			if _sensor_overlaps(bell_area.name):
				selected_story = "bell"
				break
	hud.prompt.text = "[ E ] " + ("按下停车铃" if selected_story == "bell" else String(INSPECTIONS[selected_story][1])) if not selected_story.is_empty() else ""

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or hud.panel_open or is_transitioning or in_cinematic:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if selected_story == "bell":
			resolve_judgment("bell_cord")
		elif not selected_story.is_empty():
			inspect_story(selected_story)
	elif event.is_action_pressed("journal") or event.is_action_pressed("phone"):
		get_viewport().set_input_as_handled()
		inspect_story("notebook")
	elif event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		story_widget = preload("res://ui/demo_bag.gd").new()
		hud.open_widget(story_widget)
		player.controls_enabled = false
		player.clear_motion()
		get_tree().paused = true

func inspect_story(id: String) -> void:
	if hud.panel_open or is_transitioning or in_cinematic:
		return
	if id == "door" and stage == 3 and bell_requested:
		if front_door.moving:
			return
		_say("打开的前门", "站牌就在门外，前门对齐路沿。折叠门已完全打开，门槛碰撞随门扇收起。")
		return
	observed[id] = true
	story_widget = preload("res://ui/bus_observation.gd").new()
	story_widget.configure(self, id)
	story_widget.close_requested.connect(_on_hud_close)
	story_widget.decision_requested.connect(resolve_judgment)
	hud.open_widget(story_widget)
	player.clear_motion()
	player.controls_enabled = false
	get_tree().paused = true

func _evidence_ready() -> bool:
	for id in REQUIRED[stage]:
		if not observed.has(id):
			return false
	return true

func evidence_text(id: String) -> String:
	match id:
		"seat": return "后排男人的棕夹克下摆压在座椅上，鞋底落在地板。" if stage == 0 else "同一张座椅已经空了。座垫上没有人，过道里也没有人刚刚走过。"
		"glass": return "侧窗映出那件棕夹克，位置与后排座位一致。" if stage == 0 else ("座位空着，玻璃里却仍坐着那个男人。倒影的头缓缓转向过道，动作没有对应的实体。" if stage == 1 else "侧窗只有空座与过道的映像，没有多出的人。")
		"mirror": return "镜中有司机和后排一个棕夹克乘客，与车内相符。" if stage == 0 else ("镜中没有多出的乘客。司机朝向前方；前门旁的站台边沿已经停稳。" if stage == 3 else "司机仍朝向前方。后排空座在镜中没有新的乘客。")
		"display": return "屏幕显示黑沙。扬声器里传来熟悉的敲击和哭声。重放手机旧附件后，两段电流断口与敲击间隔完全重合。\n\n这不是此刻有人回答大文；先核对窗外站牌和车门位置。" if stage == 2 else ("屏幕显示黑沙；广播报黑沙海滩，没有夹入旧采访的哭声。" if stage == 3 else "屏幕显示目的地黑沙。车仍在开；目的地不等于已经到站。")
		"sign": return "站牌写着黑沙海滩。路沿停止移动，前门正对站台。" if stage == 3 else "窗外仍是同一块 W-17 旧站牌，门缝正对的也不是下车站台。屏幕报黑沙不能代替核对窗外。"
		"door": return "前门对齐黑沙站台，但还没有开。确认人数、倒影、站牌和广播后，先按停车铃，再走到前门。" if stage == 3 else "门缝外的站牌仍是 W-17。司机没有停车开门；熟悉的声音不是现在能下车的证据。"
		"notebook": return "嘉敏手札边注：‘倒影独坐，离开末排。’\n\n旧采访附件记录在失踪之前。要判断现在是否到站，核对站牌、车门位置和广播，不能仅凭熟悉的声音。\n\n前部有一只独立扶手，站在它下面等车身稳下来。"
	return ""

func resolve_judgment(action: String) -> void:
	if is_transitioning or in_cinematic:
		return
	if hud.panel_open:
		_on_hud_close()
	if not _evidence_ready():
		premature_bell_warned = true
		_say("司机隔着玻璃", "“还没到站，看清楚再按。”\n\n还缺现场核对。先观察座位、倒影、报站和站牌，必要时翻手札。")
		return
	if (stage == 0 or stage == 2) and action == "continue":
		_advance_stage()
	elif stage == 3 and action == "bell_cord":
		bell_requested = true
		_play_sfx("res://assets/audio/demo/bus_bell_chime.wav")
		_open_arrival_door()
	else:
		_fail_story("玻璃里仍有独坐的倒影，不能在末排按铃。离开末排，在前部扶手下等待。" if stage == 1 else "广播和实际停车位置不相符。旧录音不能证明嘉敏就在车外；本轮重新核对。")

func _advance_stage() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	player.clear_motion()
	player.controls_enabled = false
	if stage == 0:
		# Rise, step into the aisle and leave; the glass image deliberately lags.
		story_tween = create_tween()
		story_tween.tween_property(player, "position:y", 299.0, 0.35).set_trans(Tween.TRANS_SINE)
		story_tween.tween_property(passenger, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_SINE)
		story_tween.parallel().tween_property(standing_pose, "modulate:a", 1.0, 0.55)
		story_tween.tween_property(standing_pose, "modulate:a", 0.0, 0.25)
		story_tween.parallel().tween_property(walking_passenger, "modulate:a", 1.0, 0.25)
		await story_tween.finished
		if not is_inside_tree(): return
		walking_passenger.walking = true
		front_door.set_open(true)
		var foot: CollisionShape2D = walking_passenger.get_child(1).get_child(0)
		foot.set_deferred("disabled", false)
		story_tween = create_tween()
		story_tween.tween_property(walking_passenger, "position", Vector2(620, 278), 0.3)
		story_tween.tween_property(walking_passenger, "position", Vector2(1133, 278), 4.4)
		story_tween.tween_property(walking_passenger, "position", Vector2(1133, 210), 0.6)
		story_tween.tween_property(walking_passenger, "modulate:a", 0.0, 0.3)
		await story_tween.finished
		if not is_inside_tree(): return
		foot.set_deferred("disabled", true)
		walking_passenger.walking = false
		front_door.set_open(false)
		await front_door.motion_finished
		if not is_inside_tree(): return
	else:
		story_tween = create_tween()
		story_tween.tween_property(reflection, "modulate:a", 0.0, 0.85)
		await story_tween.finished
		if not is_inside_tree(): return
	GameState.opening_flags[STAGE_FLAGS[stage]] = true
	stage = mini(stage + 1, 3)
	passenger.modulate.a = 1.0
	_apply_story_stage()
	GameState.save_opening_checkpoint()

func _open_arrival_door() -> void:
	is_transitioning = true
	player.clear_motion()
	player.controls_enabled = false
	front_door.set_open(true)
	await front_door.motion_finished
	if not is_instance_valid(player) or not is_instance_valid(hud): return
	departure_ready = true
	is_transitioning = false
	player.controls_enabled = true
	hud.notify("前门已开。核对黑沙站牌后，走到前门下车。")

func _setup_collision() -> void:
	# The front doorway is a real passage through the seat/cabin boundary.
	LevelGeometry.wall(self, Rect2(0, 0, 1100, BUS_AISLE_TOP))
	LevelGeometry.wall(self, Rect2(1170, 0, 230, BUS_AISLE_TOP))
	LevelGeometry.wall(self, Rect2(0, BUS_AISLE_BOTTOM, 1400, 50))
	LevelGeometry.wall(self, Rect2(1063, 222, 34, 40))
	LevelGeometry.wall(self, Rect2(0, 0, 130, 360))
	LevelGeometry.wall(self, Rect2(1170, 0, 28, 360))

func _fail_story(reason: String) -> void:
	last_failure = reason
	is_transitioning = true
	player.clear_motion()
	player.controls_enabled = false
	_trigger_screamer()
	await scare_rig.finished
	scare_rig.queue_free()
	scare_rig = null
	is_transitioning = false
	safe_wait = 0.0
	bell_requested = false
	# Keep this round's observed evidence and all previous completed rounds.
	_say("这一轮还没有结束", reason)

func _trigger_screamer() -> void:
	# Keep the apparition's identity consistent with the passenger, with independent
	# head and reaching-arm bones driven by continuous 60 Hz keyframes.
	scare_rig = preload("res://ui/bus_lunge_rig.gd").new()
	glitch_overlay.add_child(scare_rig)

func _finish_arrival() -> void:
	departure_ready = false
	player.clear_motion()
	GameState.opening_flags.bus_arrived = true
	GameState.save_opening_checkpoint()
	_say("独立机关样板结束", "前门外，站牌、路沿与广播终于一致。空座在玻璃里仍是空座。\n\n本样板完成到下车；Esc 打开暂停菜单可回标题。正式剧情进度保留在进入样板之前。")

func _on_hud_close() -> void:
	if is_instance_valid(story_widget):
		story_widget.queue_free()
		story_widget = null
	super._on_hud_close()
	if is_transitioning or in_cinematic:
		player.controls_enabled = false

func _on_hud_pause() -> void:
	player.controls_enabled = false
	player.clear_motion()
	hud.open_panel("暂停", "车厢、倒影与等待计时均已暂停。", [
		{"text":"继续调查", "callback":_on_hud_close},
		{"text":"保存并回到标题", "callback":_return_story_title}
	])
	get_tree().paused = true

func _return_story_title() -> void:
	_on_hud_close()
	if not GameState.save_opening_checkpoint():
		_say("保存失败", "当前进度未能保存，仍留在车厢。请检查存储空间和文件夹权限后重试。")
		return
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")

func _update_hud_status() -> void:
	if not is_instance_valid(hud):
		return
	var objectives := ["核对车厢与玻璃中的同一名乘客，再决定是否继续观察。", "查清空座与倒影的矛盾，翻手札，再决定站在哪里。", "核对旧语音、窗外站牌与前门位置，决定是否继续。", "核对人数、倒影、广播和站牌，再按铃走向前门。"]
	hud.objective.text = objectives[stage]
	var checked := 0
	for id in REQUIRED[stage]:
		if observed.has(id): checked += 1
	hud.state_text.text = "现场核对 %d/%d     [ J / Q ] 手札" % [checked, REQUIRED[stage].size()]

