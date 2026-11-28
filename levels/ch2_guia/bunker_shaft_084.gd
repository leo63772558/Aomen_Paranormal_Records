extends Node2D

const RANGER := preload("res://entities/shaft_ranger_084.gd")
const NAV := preload("res://levels/ch2_guia/bunker_ammo_layout.gd")
const MAP := Vector2(780, 528)
const PIT := Rect2(328, 228, 146, 87)
const PIT_INNER := Rect2(341, 240, 120, 63)
const ROPE := Vector2(545, 277)
const BUCKET := Vector2(498, 269)
const DOOR := Rect2(616, 388, 68, 12)
const ALCOVE := Rect2(604, 408, 124, 88)
const ENTRY := Vector2(390, 470)
const NOTE := Vector2(690, 458)
const BUCKET_FOOT := Rect2(480,272,24,9)
const ROPE_SHEET := preload("res://assets/characters/dawen_rope_pull_096.png")
const DOOR_SHEET := preload("res://assets/props/bunker_gate_swing_114.png")
const ROPE_SCALE := 0.168
# Opaque bounds in each 512px atlas cell; align the hinge side and sill across poses.
const DOOR_FRAME_BOUNDS := [
	Rect2(183, 12, 72, 489), Rect2(163, 13, 156, 487), Rect2(137, 15, 212, 482),
	Rect2(148, 18, 233, 476), Rect2(131, 22, 245, 470), Rect2(127, 34, 255, 449)
]
# Local sheet coordinates, keeping each pose planted at the player's feet.
const ROPE_POSES := [
	{"left":120,"feet":350,"hand":Vector2(145,146)},
	{"left":120,"feet":327,"hand":Vector2(150,155)},
	{"left":180,"feet":298,"hand":Vector2(206,160)},
	{"left":235,"feet":275,"hand":Vector2(270,160)},
	{"left":170,"feet":286,"hand":Vector2(201,162)},
	{"left":145,"feet":325,"hand":Vector2(181,158)}
]
const WALLS := [
	Rect2(32, 0, 716, 130), Rect2(32, 130, 20, 398), Rect2(728, 130, 20, 398),
	Rect2(52, 500, 696, 28), Rect2(590, 388, 26, 12), Rect2(684, 388, 44, 12),
	Rect2(590, 388, 14, 112)
]
enum Phase { PREVIEW, ACTIVE, CLEARED, LOST, LEAVING }
var phase := Phase.PREVIEW
var player: PlayerController
var ranger
var hud
var selected := ""
var edge_warning := false
var action_busy := false
var preview_explanation_ready := false
var focus_pause_during_fall := false
var rope_time := 0.0
var rope_action := false
var rope_frame := 0
var bucket_motion := 0.0
var door_progress := 0.0
var door_body: StaticBody2D
var door_shadow: LightOccluder2D
var door_sprite: Sprite2D
var door_frame := -1
var actor_pose: Sprite2D
var preview_can: Sprite2D
var fall_time := 0.0
var floor_art := preload("res://assets/tilesets/ammo_floor_026.png")
var pit_art := preload("res://assets/tilesets/bunker_ammo_pits_2d_022.png")
var detail_art := preload("res://assets/tilesets/bunker_lowerroom_routes_023.png")
var stone_wall_art := preload("res://assets/tilesets/bunker_stair_2d_019.png")
var shelter_room_art := preload("res://assets/tilesets/bunker_shelter_room_v9.png")
var trail_art := preload("res://assets/props/jiamin_trail_props_044.png")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	AudioManager.set_bunker_ambience(true)
	GameState.demo_pursuit = ""
	for rect: Rect2 in WALLS:
		LevelGeometry.wall(self, rect)
	LevelGeometry.wall(self, BUCKET_FOOT)
	LevelGeometry.wall(self, Rect2(DOOR.position.x,DOOR.position.y,24,DOOR.size.y))
	LevelGeometry.wall(self, Rect2(DOOR.end.x - 8,DOOR.position.y,8,DOOR.size.y))
	door_body = LevelGeometry.wall(self, DOOR)
	door_shadow = get_child(get_child_count() - 1) as LightOccluder2D
	_set_door_blocked(false)
	_build_door()
	player = preload("res://entities/player/player.tscn").instantiate()
	player.appearance = "flashlight"
	player.visual_size_multiplier = 1.65
	player.position = ENTRY
	add_child(player)
	var camera := player.get_node("Camera2D") as Camera2D
	camera.enabled = true
	camera.position_smoothing_enabled = false
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(MAP.x)
	camera.limit_bottom = int(MAP.y)
	player.look_dir = Vector2.UP
	player.reset_physics_interpolation()
	var ambient := CanvasModulate.new()
	ambient.color = Color("8f9a8e")
	add_child(ambient)
	# Real warm recessed bunker lamp illuminating the lower-right shelter room (no flat yellow circles!)
	var alcove_lamp := PointLight2D.new()
	alcove_lamp.position = NOTE + Vector2(-10, -16)
	alcove_lamp.texture = preload("res://assets/lighting/soft_light.png")
	alcove_lamp.texture_scale = 0.42
	alcove_lamp.color = Color("e8bf74")
	alcove_lamp.energy = 0.65
	add_child(alcove_lamp)
	hud = preload("res://ui/quiet_hud.gd").new()
	add_child(hud)
	hud.close_requested.connect(close_panel)
	hud.pause_requested.connect(pause_menu)
	hud.phone_requested.connect(show_phone)
	ranger = RANGER.new()
	ranger.position = Vector2(185, 222)
	ranger.target = player
	ranger.pit = PIT_INNER
	var navigation_blocks: Array = WALLS.duplicate()
	navigation_blocks.append(PIT.grow(2))
	navigation_blocks.append(BUCKET_FOOT)
	ranger.grid = NAV.navigation(Rect2(52, 130, 676, 370), navigation_blocks)
	add_child(ranger)
	ranger.caught.connect(func(): fail_route("巡山人的脚步赶到了你身边。"))
	ranger.charge_warned.connect(func(): hud.notify("它在西岸抬起身体，脚跟刮响。离开直线！"))
	ranger.fell.connect(_ranger_fell)
	_build_actor_pose()
	_build_hazard()
	if _resolved():
		phase = Phase.CLEARED
		ranger.retire()
		ranger.hide()
		ranger.collision_layer = 0
		if GameState.opening_flags.get("ch2_shaft_bypass_closed", false):
			door_progress = 1.0
			_update_door_visual()
			_set_door_blocked(true)
			player.position = Vector2(650, 457)
		hud.notify("已脱离巡山人。侧廊便签和深层梯道仍在原处。")
	else:
		_checkpoint()
		if GameState.opening_flags.get("ch2_shaft_demo_seen", false):
			phase = Phase.ACTIVE
			ranger.activate()
			hud.notify("罐声能引它靠近；东岸桶绳和右下侧廊都可脱身。")
		else:
			call_deferred("_safe_preview")
	_update_objective()

func _build_door() -> void:
	# The source is a closed iron door with a frame. Keep the frame in place
	# while the leaf turns; shrinking the entire image also shrank the frame.
	var atlas := preload("res://assets/props/bunker_gate_candidate_015.png")
	var origin := Vector2(DOOR.position.x, DOOR.position.y - 73)
	var unit := Vector2(68.0 / 838.0, 85.0 / 1395.0)
	for part: Rect2 in [Rect2(125,28,838,82), Rect2(125,110,98,1253), Rect2(869,110,94,1253), Rect2(125,1363,838,60)]:
		var frame_piece := Sprite2D.new()
		var frame_region := AtlasTexture.new()
		frame_region.atlas = atlas
		frame_region.region = part
		frame_piece.texture = frame_region
		frame_piece.centered = false
		frame_piece.position = origin + (part.position - Vector2(125,28)) * unit
		frame_piece.scale = unit
		frame_piece.z_index = int(DOOR.end.y)
		add_child(frame_piece)
	door_sprite = Sprite2D.new()
	door_sprite.centered = false
	door_sprite.z_index = int(DOOR.end.y)
	add_child(door_sprite)
	_update_door_visual()

func _build_actor_pose() -> void:
	actor_pose = Sprite2D.new()
	actor_pose.texture = preload("res://assets/characters/dawen_push_011.png")
	actor_pose.scale = Vector2.ONE * (77.0 / 1254.0)
	actor_pose.offset = Vector2(-540, -610)
	actor_pose.light_mask = 2
	actor_pose.hide()
	add_child(actor_pose)

func _build_hazard() -> void:
	var area := Area2D.new()
	area.name = "ShaftInnerFallZone"
	area.collision_layer = 16
	area.collision_mask = 2
	var collision := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = PIT_INNER.size
	collision.shape = rect
	collision.position = PIT_INNER.get_center()
	area.add_child(collision)
	add_child(area)

func _safe_preview() -> void:
	player.controls_enabled = false
	player.clear_motion()
	hud.notify("铁罐从断链上滑落。西边的人影停下，转向了声音。")
	preview_can = Sprite2D.new()
	var region := AtlasTexture.new()
	region.atlas = detail_art
	region.region = Rect2(706, 566, 45, 63)
	preview_can.texture = region
	preview_can.position = Vector2(235, 191)
	preview_can.scale = Vector2.ONE * 0.35
	preview_can.z_index = 223
	add_child(preview_can)
	var tween := create_tween()
	tween.tween_property(preview_can, "position", Vector2(258, 223), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(preview_can, "rotation", 1.5, 0.45)
	await tween.finished
	if not is_inside_tree(): return
	AudioManager.play_at(self, "gate_chain", Vector2(258, 223), -12)
	ranger.activate()
	ranger.last_seen = Vector2(258, 223)
	ranger._set_state(ranger.State.INVESTIGATE)
	await get_tree().create_timer(0.75, false).timeout
	if not is_inside_tree() or phase != Phase.PREVIEW:
		return
	ranger.retire()
	GameState.opening_flags.ch2_shaft_demo_seen = true
	_checkpoint()
	preview_explanation_ready = true
	show_panel("竖井前厅 · 守卫暗室与九十九级梯道入口", "铁罐滚落地面，西岸那个黑衣巡山人怨灵立刻循声僵硬转头——这里正是通往【九十九级深层梯道】的战时排风竖井前厅，右下角的守卫铁门内藏着直下梯道的暗梯！\n\n地面白线内是深不见底的垂直通风竖井。拉响东岸滑轮铁桶即可诱它直线坠井，也可绕进右下角守卫暗室把铁门从内侧闩死，再沿便签指引下梯道。", [{"text":"看清路线，开始行动", "callback":_start_active}])

func _start_active() -> void:
	phase = Phase.ACTIVE
	close_panel()
	ranger.activate()
	hud.notify("白线外可以走。既可引它冲向桶声，也可绕到侧廊关门。")
	_update_objective()

func _physics_process(delta: float) -> void:
	if phase == Phase.LOST or phase == Phase.LEAVING:
		return
	rope_time = maxf(0.0, rope_time - delta)
	bucket_motion = move_toward(bucket_motion, 0.0, delta * 2.0)
	if phase in [Phase.ACTIVE, Phase.CLEARED] and not action_busy:
		if PIT_INNER.has_point(player.position):
			fall_player()
			return
		if PIT.grow(13).has_point(player.position) and not PIT_INNER.has_point(player.position):
			if not edge_warning:
				edge_warning = true
				hud.notify("鞋下石屑滚进深处。白线以内没有完整地面。")
		else:
			edge_warning = false
	_update_selection()
	queue_redraw()

func _update_selection() -> void:
	selected = ""
	if hud.panel_open or action_busy:
		hud.prompt.text = ""
		return
	var targets := {"rope":ROPE, "door":Vector2(650, 430), "note":NOTE, "return":ENTRY}
	var best := 50.0
	for id: String in targets:
		var point: Vector2 = targets[id]
		var distance := player.position.distance_to(point)
		if distance < best:
			best = distance
			selected = id
	var door_label := "查看铁门（已从内侧闩牢）" if (phase == Phase.CLEARED or GameState.opening_flags.ch2_shaft_bypass_closed) else "从内侧闩上铁门"
	var labels := {"rope":"拉动桶绳", "door":door_label, "note":"查看嘉敏便签与侧廊出口", "return":"返回机房"}
	hud.prompt.text = "[ E ] " + str(labels.get(selected,"")) if not selected.is_empty() else ""

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or hud.panel_open or action_busy or phase in [Phase.PREVIEW, Phase.LOST, Phase.LEAVING]:
		return
	if event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		player.controls_enabled = false
		player.clear_motion()
		hud.open_widget(preload("res://ui/demo_bag.gd").new())
		get_tree().paused = true
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		match selected:
			"rope": pull_rope()
			"door": close_bypass()
			"note": inspect_note()
			"return": return_hall()

func pull_rope() -> void:
	if phase != Phase.ACTIVE or action_busy or rope_time > 0:
		return
	if player.position.distance_to(ROPE) > 50:
		return
	if ranger.flash_receiver.is_stunned() or not ranger.charge_stage.is_empty():
		hud.notify("桶还在回荡。等它重新辨认声源，再拉一次。")
		return
	action_busy = true
	rope_action = true
	player.controls_enabled = false
	player.clear_motion()
	rope_time = 1.2
	actor_pose.centered = false
	actor_pose.offset = Vector2.ZERO
	actor_pose.scale = Vector2.ONE * ROPE_SCALE
	actor_pose.flip_h = false
	actor_pose.z_index = int(player.position.y)
	_set_rope_frame(0.0)
	actor_pose.show()
	player.sprite.hide()
	player.lamp.enabled = false
	var tween := create_tween()
	tween.tween_method(_set_rope_frame, 0.0, 5.99, 0.72)
	await tween.finished
	if not is_inside_tree():
		return
	# The ranger can catch the player during the reaching animation.  Do not
	# complete the lure or re-enable control after that interruption.
	if phase != Phase.ACTIVE:
		rope_action = false
		_restore_actor()
		action_busy = false
		return
	GameState.opening_flags.ch2_shaft_rope_used = true
	bucket_motion = 1.0
	AudioManager.play_at(self, "gate_chain", BUCKET, -8)
	EventBus.noise_emitted.emit(BUCKET, 650.0, "shaft_bucket_084")
	rope_action = false
	_restore_actor()
	action_busy = false
	hud.notify("绳子绷紧，铁桶敲向石沿。西岸脚步转了方向。")

func _set_rope_frame(value: float) -> void:
	rope_frame = clampi(int(value), 0, ROPE_POSES.size() - 1)
	var pose: Dictionary = ROPE_POSES[rope_frame]
	var left := int(pose.left)
	var atlas := AtlasTexture.new()
	atlas.atlas = ROPE_SHEET
	atlas.region = Rect2((rope_frame % 3) * 512 + left, (rope_frame / 3) * 512, 512 - left, 512)
	actor_pose.texture = atlas
	actor_pose.position = player.position - Vector2((float(pose.feet) - left) * ROPE_SCALE, 486.0 * ROPE_SCALE)
	queue_redraw()

func close_bypass() -> void:
	if phase == Phase.CLEARED or GameState.opening_flags.ch2_shaft_bypass_closed:
		hud.notify("铁门已从内侧闩牢，通道安全隔断。")
		return
	if phase != Phase.ACTIVE or action_busy:
		return
	if not Rect2(604, 408, 124, 88).has_point(player.position):
		hud.notify("门闩在里面。沿井南侧绕进右下侧廊，再把门关上。")
		return
	if ranger.position.y > 340 or ranger.position.distance_to(player.position) < 100:
		hud.notify("它已经追到门边，不能迎着它关门。先绕开，或用桶声引走它。")
		return
	action_busy = true
	player.controls_enabled = false
	player.clear_motion()
	actor_pose.texture = preload("res://assets/characters/dawen_push_011.png")
	actor_pose.centered = true
	actor_pose.scale = Vector2.ONE * (77.0 / 1254.0)
	actor_pose.offset = Vector2(-540, -610)
	actor_pose.flip_h = false
	actor_pose.position = player.position
	actor_pose.z_index = int(player.position.y)
	actor_pose.show()
	player.sprite.hide()
	player.lamp.enabled = false
	AudioManager.play_at(self, "gate_iron", DOOR.get_center(), -9)
	var tween := create_tween()
	tween.tween_method(func(value: float): door_progress = value; _update_door_visual(), 0.0, 1.0, 0.55)
	await tween.finished
	if not is_instance_valid(player) or not is_instance_valid(hud): return
	_set_door_blocked(true)
	ranger.retire()
	GameState.opening_flags.ch2_shaft_bypass_closed = true
	phase = Phase.CLEARED
	_restore_actor()
	action_busy = false
	_checkpoint()
	hud.notify("门闩落槽。脚步被留在外面，侧廊后方可以继续下行。")
	_update_objective()

func _restore_actor() -> void:
	actor_pose.hide()
	player.sprite.show()
	player.controls_enabled = phase in [Phase.ACTIVE, Phase.CLEARED] and not hud.panel_open
	player.clear_motion()
	player.lamp.enabled = player.flashlight_on and GameState.flashlight_battery > 0

func _set_door_blocked(blocked: bool) -> void:
	door_body.collision_layer = 1 if blocked else 0
	door_body.collision_mask = 6 if blocked else 0
	door_shadow.visible = blocked

func _update_door_visual() -> void:
	if not is_instance_valid(door_sprite):
		return
	var next_frame := clampi(roundi(door_progress * 5.0), 0, 5)
	var bounds: Rect2 = DOOR_FRAME_BOUNDS[next_frame]
	var closed_bounds: Rect2 = DOOR_FRAME_BOUNDS[5]
	var scale_x := 52.4 / closed_bounds.size.x
	var scale_y := 76.4 / bounds.size.y
	if next_frame != door_frame:
		var leaf := AtlasTexture.new()
		leaf.atlas = DOOR_SHEET
		leaf.region = Rect2(Vector2(next_frame % 3, floori(next_frame / 3.0)) * 512.0, Vector2.ONE * 512.0)
		door_sprite.texture = leaf
		door_frame = next_frame
	door_sprite.scale = Vector2(scale_x, scale_y)
	var hinge := Vector2(DOOR.position.x + 8.0, DOOR.end.y - 4.0)
	door_sprite.position = hinge - Vector2(bounds.position.x, bounds.end.y) * door_sprite.scale
	var projected_width := DOOR.size.x * bounds.size.x / closed_bounds.size.x
	var collision := door_body.get_child(0) as CollisionShape2D
	var shape := collision.shape as RectangleShape2D
	shape.size = Vector2(projected_width, DOOR.size.y)
	collision.position = Vector2(DOOR.position.x + projected_width * 0.5, DOOR.get_center().y)
	# The light blocker follows the same visible projection as the physical leaf.
	door_shadow.occluder.polygon = PackedVector2Array([
		DOOR.position,
		Vector2(DOOR.position.x + projected_width, DOOR.position.y),
		Vector2(DOOR.position.x + projected_width, DOOR.end.y),
		Vector2(DOOR.position.x, DOOR.end.y)
	])
	var blocks_passage := door_progress > 0.02
	door_body.collision_layer = 1 if blocks_passage else 0
	door_body.collision_mask = 6 if blocks_passage else 0
	door_shadow.visible = blocks_passage

func _ranger_fell() -> void:
	GameState.opening_flags.ch2_ranger_fallen = true
	phase = Phase.CLEARED
	AudioManager.play_at(self, "pit_drop", PIT_INNER.get_center(), -7)
	_checkpoint()
	hud.notify("碎石和脚步一起坠下。桶声还在，巡山人没有再绕回来。")
	_update_objective()

func _resolved() -> bool:
	return GameState.opening_flags.get("ch2_ranger_fallen",false) or GameState.opening_flags.get("ch2_shaft_bypass_closed",false)

func inspect_note() -> void:
	GameState.opening_flags.ch2_shaft_note_seen = true
	if _resolved():
		_checkpoint()
		show_panel("竖井便签", "纸条压在侧廊干燥的石缝里，是嘉敏匆忙写下的字迹：\n「阿豪、大文：正门被外面铁链锁死了。那一家三口的红影在追我，我只能从排风井边绕出去，顺山坡去大关斜巷找人。千万别跟着井里的声音！」", [{"text":"沿侧廊进入深层梯道", "callback":continue_steps}])
	else:
		show_panel("竖井边的纸", "侧廊石缝压着嘉敏的便签。上面提到排风井、大关斜巷，还有井里的声音。\n\n外面的脚步正在绕来。先关上侧廊门，或在东岸用桶绳把它引向井口，再读清纸上的字。")

func continue_steps() -> void:
	if not _resolved() or not GameState.has_demo_item("bunker_recording"):
		return
	close_panel()
	if GameState.request_room_change("ch2_hill_steps", "from_hall"):
		phase = Phase.LEAVING
		GameState.demo_pursuit = "steps"
	else:
		hud.notify("深层门暂未打开。回侧廊再试一次。")

func return_hall() -> void:
	if phase == Phase.ACTIVE and ranger.position.distance_to(player.position) < 80:
		hud.notify("先摆脱身后的脚步，才能拉开机房门。")
		return
	if GameState.request_room_change("ch2_bunker_hall", "from_shaft"):
		phase = Phase.LEAVING
		GameState.save_transition_checkpoint()
	else:
		hud.notify("机房入口暂时无法打开，请稍后重试。")

func _checkpoint() -> void:
	if not GameState.save_opening_checkpoint():
		hud.show_resource_feedback("进度保存失败，仍可继续。请检查存储空间和文件夹权限后重试。")

func _update_objective() -> void:
	hud.objective.text = "读侧廊便签 · 继续深层梯道" if _resolved() else "绕井脱身 · 桶绳或侧廊铁门"

func fall_player() -> void:
	if phase not in [Phase.ACTIVE, Phase.CLEARED] or action_busy:
		return
	phase = Phase.LOST
	ranger.retire()
	player.controls_enabled = false
	player.clear_motion()
	player.allow_phone_defense = false
	AudioManager.play_at(self, "pit_drop", player.position, -8)
	var tween := create_tween()
	tween.tween_property(player.sprite, "scale", player.sprite.scale * 0.15, 0.7)
	tween.parallel().tween_property(player.sprite, "modulate:a", 0.0, 0.7)
	await tween.finished
	if not is_inside_tree():
		return
	show_panel("脚下没有落脚处", "你越过了断链和白线，踩进了竖井内侧。井口边缘可以调查，内侧没有地面。", [{"text":"从竖井入口重试", "callback":retry}])

func fail_route(reason: String) -> void:
	if phase in [Phase.LOST, Phase.LEAVING]:
		return
	phase = Phase.LOST
	ranger.retire()
	player.controls_enabled = false
	player.clear_motion()
	get_tree().paused = true
	await DemoCaptureAnimation.play_on(self, DemoCaptureAnimation.RANGER_PATH)
	if not is_inside_tree():
		return
	show_panel("没能脱身", reason + "\n\n可用井对岸桶声调开它，或从右下侧廊关门。", [{"text":"从竖井入口重试", "callback":retry}])

func retry(room_id := "ch2_bunker_shaft", entry_id := "from_hall") -> void:
	get_tree().paused = false
	if GameState.request_room_change(room_id, entry_id):
		GameState.demo_pursuit = ""
	else:
		show_panel("暂时无法重试", "竖井暂时没有载入成功，进度仍然保留。可以再次尝试。", [{"text":"再次重试", "callback":retry}])

func show_panel(title: String, body: String, choices: Array = []) -> void:
	player.controls_enabled = false
	player.clear_motion()
	hud.open_panel(title, body, choices)
	get_tree().paused = true

func close_panel() -> void:
	if focus_pause_during_fall:
		focus_pause_during_fall = false
		hud.close_panel()
		get_tree().paused = false
		player.controls_enabled = false
		player.clear_motion()
		return
	if phase == Phase.LOST:
		return
	if phase == Phase.PREVIEW and preview_explanation_ready:
		phase = Phase.ACTIVE
		ranger.activate()
	hud.close_panel()
	get_tree().paused = false
	player.controls_enabled = not action_busy and phase != Phase.PREVIEW
	player.clear_motion()

func pause_menu() -> void:
	if phase == Phase.LOST:
		return
	show_panel("暂停", "松山防空洞 · 排风竖井", [{"text":"继续", "callback":close_panel}, {"text":"退出游戏", "callback":func(): get_tree().quit()}])

func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT or not is_instance_valid(hud) or not is_instance_valid(player) or hud.panel_open or get_tree().paused:
		return
	if phase == Phase.LOST:
		focus_pause_during_fall = true
		show_panel("暂停", "窗口失焦，坠落演出已暂停。", [{"text":"继续", "callback":close_panel}])
	else:
		pause_menu()

func show_phone() -> void:
	if hud.panel_open or action_busy:
		return
	player.controls_enabled = false
	player.clear_motion()
	hud.open_archive_page("phone")
	get_tree().paused = true

func _draw() -> void:
	draw_texture_rect(floor_art, Rect2(Vector2.ZERO, MAP), false)
	# Crumbling concrete pit rim + deep shadowed abyss + broken rusted iron stanchions (no bare dashed lines)
	draw_rect(PIT.grow(10), Color(0.11, 0.12, 0.10, 0.72))
	draw_texture_rect_region(pit_art, PIT.grow(4), Rect2(190, 279, 246, 73))
	draw_rect(PIT_INNER, Color(0.02, 0.03, 0.03, 0.86))
	draw_rect(PIT_INNER.grow(-6), Color(0.0, 0.0, 0.0, 0.94))
	# Weathered concrete rim coping & rusted guardrail posts with sagging iron chain
	draw_rect(PIT.grow(6), Color("4f4b40"), false, 3.0)
	draw_rect(PIT.grow(2), Color("24221d"), false, 2.0)
	var posts := [
		Vector2(322, 222), Vector2(368, 222), Vector2(422, 222), Vector2(476, 222),
		Vector2(322, 322), Vector2(368, 322), Vector2(422, 322), Vector2(476, 322)
	]
	for i in range(3):
		var a: Vector2 = posts[i]
		var b: Vector2 = posts[i + 1]
		draw_line(a, a.lerp(b, 0.5) + Vector2(0, 5), Color("3c3329"), 2.0)
		draw_line(a.lerp(b, 0.5) + Vector2(0, 5), b, Color("3c3329"), 2.0)
		var c: Vector2 = posts[i + 4]
		var d: Vector2 = posts[i + 5]
		draw_line(c, c.lerp(d, 0.5) + Vector2(0, 5), Color("3c3329"), 2.0)
		draw_line(c.lerp(d, 0.5) + Vector2(0, 5), d, Color("3c3329"), 2.0)
	for post: Vector2 in posts:
		draw_rect(Rect2(post - Vector2(3, 10), Vector2(6, 12)), Color("3f372e"))
		draw_rect(Rect2(post - Vector2(2, 10), Vector2(2, 11)), Color("6d5d4b"))
	# Real architectural lower-right wartime concrete guardroom interior (replaces bare wall patch & floating note!)
	draw_texture_rect(shelter_room_art, Rect2(586, 366, 148, 138), false)
	# Southern tunnel entrance framing around ENTRY
	draw_rect(Rect2(352, 488, 76, 38), Color(0.03, 0.04, 0.04, 0.82))
	draw_rect(Rect2(348, 484, 84, 6), Color("4a453b"))
	draw_texture_rect_region(detail_art, Rect2(475,237,32,44), Rect2(708,568,47,63))
	var sway := sin(bucket_motion * 12.0) * bucket_motion * 4
	var rope_hand := ROPE + Vector2(0,-20)
	if rope_action:
		var pose: Dictionary = ROPE_POSES[rope_frame]
		rope_hand = player.position + (pose.hand - Vector2(float(pose.feet),486)) * ROPE_SCALE
	var bucket_handle := BUCKET + Vector2(sway,-25)
	draw_line(rope_hand + Vector2(0,1), bucket_handle + Vector2(0,1), Color("302a19"), 3)
	draw_line(rope_hand, bucket_handle, Color("938360"), 1)
	for i in range(5):
		var at := rope_hand.lerp(bucket_handle,float(i)/5.0)
		draw_line(at + Vector2(-1,-1), at + Vector2(1,1), Color("b2a07b"), 1)
