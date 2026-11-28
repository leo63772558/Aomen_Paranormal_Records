extends Node

var checks: int = 0
var failures: int = 0
var scene
var player: PlayerController

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame

func event_action(name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	Input.parse_input_event(event)

func tap(name: String) -> void:
	event_action(name, true)
	await frames(2)
	event_action(name, false)
	await frames(2)

func close_panel_pages() -> void:
	var attempts := 0
	while is_instance_valid(scene) and scene.hud.panel_open and attempts < 8:
		await tap("pause")
		attempts += 1
	check(not scene.hud.panel_open, "modal pages fully dismissed")

func walk_to(point: Vector2) -> void:
	var count: int = 0
	while player.position.distance_to(point) > 2 and count < 500:
		var difference: Vector2 = point-player.position
		var action: String
		if absf(difference.x)>2:
			action = "move_right" if difference.x>0 else "move_left"
		else:
			action = "move_down" if difference.y>0 else "move_up"
		event_action(action,true)
		await frames(1)
		event_action(action,false)
		count+=1
	await frames(6)
	check(player.position.distance_to(point)<4, "input route " + str(point))

func walk_while_aiming(point: Vector2, threat: CharacterBody2D, sprint := true) -> void:
	var count := 0
	event_action("sprint", sprint)
	var direction := point-player.position
	var action := ("move_right" if direction.x>0 else "move_left") if absf(direction.x)>2 else ("move_down" if direction.y>0 else "move_up")
	event_action(action,true)
	while player.position.distance_to(point) > 2 and count < 600:
		if is_instance_valid(threat):
			player.look_dir = (threat.global_position + Vector2(0,-45) - player.get_flashlight_origin()).normalized()
		var difference: Vector2 = point-player.position
		var next_action: String = ("move_right" if difference.x>0 else "move_left") if absf(difference.x)>2 else ("move_down" if difference.y>0 else "move_up")
		if next_action != action:
			event_action(action,false)
			action = next_action
			event_action(action,true)
		await frames(1)
		count += 1
	event_action(action,false)
	event_action("sprint", false)
	player.clear_motion()
	await frames(6)
	check(player.position.distance_to(point)<4, "escape route while aiming %s, actual %s" % [point, player.position])

func use(id: String, point: Vector2) -> void:
	player.look_dir = (point-player.position).normalized()
	await frames(3)
	check(scene.selected_id==id, "interaction target: " + id)
	await tap("interact")

func press_choice(text: String) -> void:
	var found: bool = false
	for child in scene.hud.panel_content.get_children():
		if child is Button and child.text==text:
			found = true
			check(not child.get_global_rect().intersects(scene.hud.page_hint.get_global_rect()), "choice has separate footer: " + text)
			child.pressed.emit()
			break
	check(found, "visible choice: " + text)
	await frames(4)

func panel_click(panel: Control, at: Vector2, button_index := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = true
	event.position = at
	panel._gui_input(event)
	event.pressed = false
	panel._gui_input(event)
	await frames(2)

func panel_drag(panel: Control, from: Vector2, to: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = from
	panel._gui_input(down)
	var motion := InputEventMouseMotion.new()
	motion.position = to
	panel._gui_input(motion)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = to
	panel._gui_input(up)
	await frames(2)

func run() -> void:
	await frames(6)
	scene=get_tree().current_scene
	player=scene.player
	player.aim_override=true
	check(GameState.profile=="test", "opening uses isolated test profile")
	check(not player.allow_flashlight and not player.flashlight_on, "daytime opening uses unarmed character, no hidden held-torch beam")
	if scene.hud.panel_open:
		await tap("pause")
	var battery: float = GameState.flashlight_battery
	await tap("camera_mode")
	check(scene.camera_active and scene.camera_pose.visible and not player.sprite.visible, "C raises the actual phone action sprite")
	await tap("photo_capture")
	check(not GameState.opening_flags.photo_taken and scene.camera_active, "bad framing can retry without granting a photo")
	var motion:=InputEventMouseMotion.new()
	motion.position=Vector2(405,201)
	Input.parse_input_event(motion)
	await frames(2)
	check(scene.photo_is_valid(), "mouse framing contains Jiamin and valid shooting distance")
	await tap("photo_capture")
	check(GameState.opening_flags.photo_taken and scene.hud.panel_open, "normal shutter input grants photo progress")
	check(AudioManager.last_world_effect=="camera_shutter" and GameState.flashlight_battery==battery, "camera plays its own shutter and consumes no flashlight/defence resource")
	await tap("pause")
	await walk_to(Vector2(370,258))
	await walk_to(Vector2(370,226))
	event_action("move_right",true)
	await frames(30)
	event_action("move_right",false)
	await frames(6)
	check(player.position.x<=391.5 and player.position.x>385, "NPC has physical body collision")
	await use("jiamin",Vector2(405,226))
	await press_choice("接过葡挞")
	check(GameState.opening_flags.pastry_shared and scene.pastry_pose.visible and not player.sprite.visible, "receiving pastry displays dedicated held-item pose")
	await frames(26)
	await tap("pause")
	check(not scene.pastry_pose.visible and player.sprite.visible, "finishing dialogue restores normal walking pose")
	await use("jiamin",Vector2(405,226))
	await tap("pause")
	check(GameState.opening_flags.knock_agreed, "story establishes new knock agreement")
	await walk_to(Vector2(370,226))
	await walk_to(Vector2(370,260))
	await walk_to(Vector2(391,260))
	await walk_to(Vector2(487,260))
	await walk_to(Vector2(487,179))
	await walk_to(Vector2(200,179))
	await use("insulated_bridge",Vector2(167,193))
	await tap("pause")
	await walk_to(Vector2(487,179))
	await use("entry",Vector2(487,159))
	await tap("pause")
	await frames(6)
	scene=get_tree().current_scene
	player=scene.player
	player.aim_override=true
	check(scene.stage_kind=="foyer" and GameState.opening_flags.entered_foyer, "door enters a real hall scene")
	await tap("pause")
	var prior_scene = scene
	check(not GameState.request_room_change("not_a_room","bad") and get_tree().current_scene==prior_scene, "invalid room change preserves current scene")
	await walk_to(Vector2(304,185))
	await use("power_record",Vector2(304,165))
	await tap("pause")
	await walk_to(Vector2(124,190))
	await use("ceramic_fuse",Vector2(124,170))
	await tap("pause")
	await walk_to(Vector2(210,278))
	await walk_to(Vector2(210,157))
	await use("meter",Vector2(210,139))
	check(scene.hud.panel_open, "wall-mounted meter can be examined from safe walkable floor")
	await press_choice("用工具钳拆盖")
	check(scene.work_in_progress and scene.work_pose.visible and not player.controls_enabled, "meter cover shows dedicated tool action before opening diagram")
	await tap("pause")
	await frames(60)
	check(scene.work_in_progress and not GameState.opening_flags.meter_cover_open, "pause freezes the timed maintenance action")
	await tap("pause")
	await frames(50)
	check(GameState.opening_flags.meter_cover_open and scene.hud.panel_open, "completed tool action reveals the floor diagram")
	var wiring: Control = scene.hud.panel_content.get_node("WiringPuzzle")
	await panel_click(wiring,Vector2(144,234))
	await panel_click(wiring,Vector2(309,234))
	await panel_drag(wiring,Vector2(217,283),Vector2(144,165))
	await panel_click(wiring,Vector2(106,300))
	await frames(24)
	check(not GameState.opening_flags.floor3_power, "wrong circuit layout does not power the third floor")
	await panel_click(wiring,Vector2(144,165),MOUSE_BUTTON_RIGHT)
	await panel_drag(wiring,Vector2(303,283),Vector2(144,165))
	await panel_drag(wiring,Vector2(217,283),Vector2(309,165))
	await panel_click(wiring,Vector2(106,300))
	await frames(30)
	check(GameState.opening_flags.floor3_power and scene.stair_light.enabled, "correct branch changes the actual stairwell light")
	await tap("pause")
	await walk_to(Vector2(520,157))
	# The separately tested Ah Hao sequence has completed before this continuation.
	GameState.opening_flags.ah_hao_breaker_done = true
	GameState.opening_flags.ah_hao_escaped = true
	GameState.opening_flags.ah_hao_dead = true
	GameState.opening_items["ahhao_camera"] = 1
	await use("stairs",Vector2(520,139))
	await frames(6)
	scene=get_tree().current_scene
	player=scene.player
	player.aim_override=true
	check(scene.stage_kind=="corridor" and GameState.opening_flags.floor3_power, "stairs enter the third-floor corridor")
	await walk_to(Vector2(442,260))
	await use("fallen_phone",Vector2(442,236))
	check(scene.work_in_progress and not GameState.opening_flags.jiamin_phone_found, "phone pickup displays a timed action")
	await frames(50)
	check(GameState.opening_flags.jiamin_phone_found and scene.hud.panel_open, "phone collected and dialogue opens")
	await tap("pause")
	await tap("phone")
	check(scene.hud.panel_open, "Q opens phone notes after pickup")
	await tap("pause")
	await walk_to(Vector2(483,230))
	await use("door304",Vector2(483,207))
	await frames(6)
	scene=get_tree().current_scene
	player=scene.player
	player.aim_override=true
	check(scene.stage_kind=="room304", "304 door enters a separate room")
	await walk_to(Vector2(300,230))
	await use("desk304",Vector2(300,208))
	check(scene.hud.panel_open, "desk is reachable and can be investigated")
	await press_choice("接听电话")
	check(GameState.opening_flags.room_phone_answered, "answering the phone triggers outage")
	await close_panel_pages()
	await walk_to(Vector2(370,230))
	await walk_to(Vector2(370,275))
	await walk_to(Vector2(145,275))
	await walk_to(Vector2(145,220))
	await use("wardrobe304",Vector2(145,190))
	check(scene.hiding and GameState.opening_flags.wardrobe_tutorial_done, "wardrobe teaches safe hiding")
	await frames(300)
	check(GameState.opening_flags.shadow_passed and not scene.shadow_event_running, "shadow patrol completes while the player hides")
	await tap("interact")
	check(not scene.hiding, "E exits wardrobe")
	await walk_to(Vector2(145,275))
	await walk_to(Vector2(370,275))
	await walk_to(Vector2(370,230))
	await walk_to(Vector2(300,230))
	await use("desk304",Vector2(300,208))
	check(GameState.opening_flags.old_photo_seen, "old photo is available after the call")
	await tap("pause")
	await walk_to(Vector2(370,230))
	await walk_to(Vector2(370,275))
	await walk_to(Vector2(265,275))
	await walk_to(Vector2(265,230))
	await use("service_grip",Vector2(265,230))
	check(GameState.has_demo_item("service_grip"), "maintenance handle is collected from the 304 room")
	await tap("pause")
	await walk_to(Vector2(370,230))
	await walk_to(Vector2(370,275))
	await walk_to(Vector2(512,275))
	await walk_to(Vector2(512,260))
	await use("bed304",Vector2(500,240))
	check(scene.hud.panel_open, "bed is reachable and can be investigated")
	await press_choice("推开铁床")
	await frames(80)
	check(GameState.opening_flags.room_bed_moved and scene.room_vent.visible and scene.room_bed.position.distance_to(Vector2(-145,10)) < 1, "bed moves with its collision and reveals cover")
	await tap("pause")
	await walk_to(Vector2(512,200))
	await use("vent304",Vector2(520,176))
	await press_choice("用工具钳拆盖")
	await frames(72)
	check(GameState.opening_flags.room_cover_open and scene.room_hatch.visible and not scene.room_vent.visible and not is_instance_valid(scene.room_aperture), "cover opens with matching visual and collision changes")
	await tap("pause")
	await use("vent304",Vector2(520,176))
	await press_choice("爬进通道")
	check(scene.work_in_progress, "entering hatch shows crawl pose")
	await frames(90)
	scene=get_tree().current_scene
	player=scene.player
	player.aim_override=true
	check(scene.stage_kind=="maintenance" and player.allow_flashlight, "hatch opens a real maintenance area")
	await walk_to(Vector2(418,223))
	await use("service_spindle",Vector2(418,223))
	check(GameState.has_demo_item("service_spindle"), "square spindle is collected from beneath the pipes")
	await tap("pause")
	await tap("inventory")
	var bag = scene.hud.panel_content.get_child(0)
	check(bag.assemble.visible, "inventory offers assembly when both handle parts are present")
	bag.assemble.pressed.emit()
	check(GameState.has_demo_item("service_handle"), "inventory assembles the real service handle")
	await tap("pause")
	await walk_to(Vector2(267,225))
	await use("notice",Vector2(267,195))
	check(scene.hud.panel_open, "maintenance notice is inspectable")
	await tap("pause")
	await walk_to(Vector2(550,225))
	await use("steel_door",Vector2(550,195))
	var lock = scene.hud.panel_content.get_node("MaintenanceLock")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(300,280)
	lock._gui_input(click)
	check(not GameState.opening_flags.maintenance_unlocked, "a stray click cannot release the physical latch")
	await panel_drag(lock,Vector2(91,272),Vector2(309,170))
	check(lock.attached, "assembled handle seats into the square socket")
	await panel_click(lock,Vector2(450,240))
	check(lock.relieved, "pressing the door plate unloads the latch")
	await panel_drag(lock,Vector2(309,170),Vector2(367,170))
	check(lock.rotated, "handle rotation moves the eccentric cam")
	await panel_drag(lock,Vector2(520,153),Vector2(470,153))
	await frames(50)
	check(GameState.opening_flags.maintenance_unlocked and not scene.hud.panel_open and not is_instance_valid(scene.service_aperture), "sliding the bolt opens the door and updates collision")
	if scene.hud.panel_open:
		await tap("pause")
	await use("steel_door",Vector2(550,195))
	await frames(6)
	scene=get_tree().current_scene
	player=scene.player
	player.aim_override=true
	check(scene.stage_kind=="yard" and scene.hud.panel_open, "unlocked door enters yard and explains escape")
	await tap("pause")
	await frames(270)
	check(scene.hud.panel_open and not scene.yard_chase_active, "standing still allows the shadow to catch the player")
	await press_choice("重新尝试")
	await frames(6)
	scene=get_tree().current_scene
	player=scene.player
	player.aim_override=true
	check(scene.stage_kind=="yard" and scene.hud.panel_open and not GameState.opening_flags.yard_escaped, "retry restores yard start and keeps escape unfinished")
	await tap("pause")
	await walk_to(Vector2(550,205))
	await use("yard_exit",Vector2(550,170))
	check(GameState.opening_flags.yard_escaped and not scene.yard_chase_active, "reaching the gate ends chase and saves progress")
	await frames(60)
	scene=get_tree().current_scene
	player=scene.player
	player.aim_override=true
	check(scene.stage_kind=="exit_lane", "open gate leads to an exterior street")
	await walk_to(Vector2(145,300))
	await walk_to(Vector2(125,300))
	await use("public_phone",Vector2(115,285))
	check(scene.work_in_progress, "calling for help shows phone pose")
	await frames(26)
	await tap("pause")
	check(GameState.opening_flags.help_attempted and scene.hud.panel_open, "help attempt completes and is saved")
	await tap("pause")
	await walk_to(Vector2(500,255))
	await use("city_stairs",Vector2(500,225))
	await press_choice("前往牌坊")
	await frames(6)
	scene=get_tree().current_scene
	player=scene.player
	player.aim_override=true
	check(scene.stage_kind=="crypt" and GameState.current_chapter_id=="ch1_stpaul_crypt", "stone stairs lead into first chapter")
	await walk_to(Vector2(390,182))
	await use("crypt_old_photo",Vector2(393,163))
	check(GameState.opening_flags.crypt_photo_seen, "inspection photo is gathered from the side plinth")
	await tap("pause")
	await walk_to(Vector2(249,171))
	await use("crypt_niche",Vector2(250,145))
	check(GameState.opening_flags.crypt_doodle_seen, "child's drawing is gathered from the marked niche")
	await tap("pause")
	await walk_to(Vector2(249,220))
	await walk_to(Vector2(120,220))
	await walk_to(Vector2(120,187))
	await use("crypt_desk",Vector2(120,166))
	await press_choice("查看测绘描图")
	check(GameState.opening_flags.crypt_plan_seen, "survey tracing is gathered from the evidence desk")
	await tap("pause")
	await use("crypt_desk",Vector2(120,166))
	await press_choice("摆开三份证据")
	var compare = scene.hud.panel_content.get_node_or_null("CryptComparison")
	if not is_instance_valid(compare):
		check(false, "survey comparison opens after collecting all three clues")
		get_tree().quit(1)
		return
	await panel_click(compare,Vector2(20,80))
	check(not compare.fitted and not GameState.opening_flags.crypt_aligned, "blank click cannot align the evidence")
	for _turn in range(4):
		await panel_click(compare,Vector2(511,102),MOUSE_BUTTON_RIGHT)
	await panel_drag(compare,Vector2(511,102),Vector2(208,164))
	check(compare.fitted, "rotated survey tracing aligns its marks with the doorway")
	await panel_click(compare,Vector2(159,96))
	check(not compare.done, "visible side niches do not complete the comparison")
	await panel_click(compare,Vector2(208,94))
	await frames(5)
	check(GameState.opening_flags.crypt_aligned, "marks align and missing niche is identified")
	await tap("pause")
	await walk_to(Vector2(120,220))
	await walk_to(Vector2(249,220))
	await walk_to(Vector2(249,171))
	await use("crypt_niche",Vector2(250,145))
	check(scene.hud.panel_open, "crypt wall can be investigated")
	await tap("pause")
	await walk_to(Vector2(249,220))
	await walk_to(Vector2(546,220))
	await walk_to(Vector2(546,177))
	await use("crypt_door",Vector2(545,145))
	await press_choice("用钳松开门框卡扣")
	var clip = scene.hud.panel_content.get_node_or_null("CryptClip")
	if not is_instance_valid(clip):
		check(false, "crypt clip opens after verifying the comparison")
		get_tree().quit(1)
		return
	click.position = Vector2(179,162)
	clip._gui_input(click)
	check(clip.loose[0] and not clip.loose[1] and not GameState.opening_flags.crypt_clip_removed, "first screw must be removed before clip releases")
	click.position = Vector2(409,162)
	clip._gui_input(click)
	await frames(120)
	check(GameState.opening_flags.crypt_clip_removed, "tool action removes identified clip")
	if scene.hud.panel_open:
		await tap("pause")
	await use("crypt_door",Vector2(545,145))
	await frames(60)
	scene=get_tree().current_scene
	player=scene.player
	player.aim_override=true
	check(scene.stage_kind=="crypt_hall" and scene.hud.panel_open, "opened side door leads to priest encounter")
	await tap("pause")
	await frames(100)
	var priest = scene.priest
	priest.position = Vector2(300,220)
	player.look_dir = (priest.global_position + Vector2(0,-45) - player.get_flashlight_origin()).normalized()
	await frames(20)
	check(priest.frozen, "sustained unobstructed flashlight freezes priest")
	player.look_dir = Vector2.LEFT
	await frames(5)
	check(not priest.frozen, "turning the beam away releases priest")
	priest.position = Vector2(300,220)
	var wall = LevelGeometry.wall(scene,Rect2(200,190,8,70))
	var wall_shadow = scene.get_child(scene.get_child_count()-1)
	player.look_dir = (priest.global_position + Vector2(0,-45) - player.get_flashlight_origin()).normalized()
	await frames(20)
	check(not priest.frozen, "wall prevents flashlight freezing priest")
	wall.queue_free()
	wall_shadow.queue_free()
	player.look_dir = Vector2.LEFT
	await frames(300)
	check(scene.hud.panel_open and not priest.active, "unlit priest can catch the player")
	await press_choice("重新尝试")
	await frames(6)
	scene=get_tree().current_scene
	player=scene.player
	player.aim_override=true
	check(scene.stage_kind=="crypt_hall" and scene.hud.panel_open, "priest encounter retries at its entrance")
	await tap("pause")
	priest = scene.priest
	await walk_while_aiming(Vector2(108,265),priest)
	await walk_while_aiming(Vector2(550,265),priest)
	await walk_while_aiming(Vector2(550,219),priest,false)
	await use("hall_exit",Vector2(550,185))
	check(GameState.opening_flags.priest_escaped, "player escapes the priest through the far door")
	await frames(60)
	scene=get_tree().current_scene
	player=scene.player
	player.aim_override=true
	check(scene.stage_kind=="crypt_archive", "opened far door leads into the archive")
	await walk_to(Vector2(125,250))
	await use("archive_index",Vector2(125,230))
	check(scene.work_in_progress, "index capture uses phone action")
	await frames(50)
	check(GameState.opening_flags.interview_index_copied and scene.hud.panel_open, "interview index is captured")
	await tap("pause")
	await walk_to(Vector2(545,240))
	await use("archive_exit",Vector2(545,205))
	await press_choice("前往松山")
	await frames(60)
	scene=get_tree().current_scene
	player=scene.player
	player.aim_override=true
	check(scene.stage_kind=="hill_base" and GameState.current_chapter_id=="ch2_guia_tunnel", "archive opens to the second chapter hill base")
	await tap("pause")
	await walk_to(Vector2(330,245))
	await use("hill_stele",Vector2(330,218))
	check(GameState.opening_flags.hill_stele_seen, "hill inscription can be read")
	await tap("pause")
	player.look_dir = Vector2.DOWN
	await frames(40)
	check(GameState.opening_flags.hill_warning_seen, "turning observation backward shows a safe warning")
	var result := {"build":"v5_opening_062","type":"opening_to_hill_base_regression","checks":checks,"failures":failures,"scope":"Formal opening through Chapter 1 hill-base clue","limits":"Headless skips rendered photo bytes; visual capture and listening are separate."}
	var file:=FileAccess.open("res://docs/build_reports/opening_062_regression.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	AudioManager.stop_all()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures==0 else 1)
