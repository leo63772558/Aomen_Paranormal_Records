extends Node

var checks := 0
var failures := 0
var scene

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if value:
		print("PASS " + label)
	else:
		failures += 1
		push_error("FAIL " + label)

func frames(count: int) -> void:
	for _i in range(count):
		await get_tree().physics_frame

func clear_scene() -> void:
	get_tree().paused = false
	for action in ["move_left","move_right","move_up","move_down","sprint"]:
		Input.action_release(action)
	if is_instance_valid(scene):
		scene.queue_free()
		await frames(3)

func fixture(demo_seen := true) -> void:
	await clear_scene()
	GameState.reset_opening()
	GameState.opening_resume_checked = true
	GameState.current_room_id = "ch2_bunker_shaft"
	GameState.pending_entry_id = "from_hall"
	GameState.current_chapter_id = "ch2_guia_tunnel"
	GameState.take_demo_item("bunker_recording")
	GameState.take_demo_item("jiamin_phone")
	for prerequisite in ["jiamin_phone_found","old_photo_seen","room_bed_moved","room_cover_open","maintenance_unlocked","yard_escaped","crypt_photo_seen","crypt_plan_seen","crypt_doodle_seen","crypt_aligned","crypt_clip_removed","crypt_door_open","priest_escaped","interview_index_copied"]:
		GameState.opening_flags[prerequisite] = true
	GameState.opening_flags.ch2_shaft_demo_seen = demo_seen
	GameState.phone_battery = 0
	GameState.phone_flash_charges = 0
	scene = preload("res://levels/ch2_guia/bunker_shaft_084.tscn").instantiate()
	add_child(scene)
	await frames(6)
	scene.player.aim_override = true

func walk(point: Vector2) -> void:
	Input.action_press("sprint")
	var count := 0
	while scene.player.position.distance_to(point) > 6 and count < 500:
		var direction: Vector2 = point - scene.player.position
		for pair in [["move_left",direction.x < -3],["move_right",direction.x > 3],["move_up",direction.y < -3],["move_down",direction.y > 3]]:
			if pair[1]: Input.action_press(pair[0])
			else: Input.action_release(pair[0])
		await frames(1)
		count += 1
	for action in ["move_left","move_right","move_up","move_down","sprint"]:
		Input.action_release(action)
	await frames(2)
	check(scene.player.position.distance_to(point) < 10,"input walk reaches " + str(point))

func tap_interact() -> void:
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	scene._unhandled_input(event)
	await frames(2)

func run() -> void:
	check(GameState.profile == "test", "shaft regression uses test isolation")
	if "--save-failure" in OS.get_cmdline_user_args():
		check(GameState.opening_checkpoint_enabled(), "persistent isolated checkpoint is enabled")
		await fixture()
		var checkpoint_path := GameState.get_profile_path().path_join("opening_checkpoint.json")
		var previous_checkpoint := FileAccess.get_file_as_bytes(checkpoint_path)
		check(not previous_checkpoint.is_empty(), "shaft entry created a checkpoint")
		GameState.opening_flags.photo_taken = true
		GameState.opening_photo = null
		GameState.opening_photo_file = ""
		scene._ranger_fell()
		check("保存失败" in scene.hud.defense_notice.text, "shaft save failure is visible")
		check(scene.phase == scene.Phase.CLEARED, "shaft remains playable after save failure")
		check(FileAccess.get_file_as_bytes(checkpoint_path) == previous_checkpoint, "shaft failure preserves the previous checkpoint")
		print("SHAFT SAVE FAILURE checks=%d failures=%d" % [checks, failures])
		get_tree().quit(1 if failures else 0)
		return
	await fixture(false)
	var preview_pause := InputEventAction.new()
	preview_pause.action = "pause"
	preview_pause.pressed = true
	Input.parse_input_event(preview_pause)
	await frames(2)
	var preview_can_before: Vector2 = scene.preview_can.position
	await frames(20)
	check(get_tree().paused and scene.preview_can.position == preview_can_before,"Esc during demonstration freezes can animation")
	Input.parse_input_event(preview_pause.duplicate())
	await frames(2)
	check(not get_tree().paused and not scene.player.controls_enabled,"resuming demonstration retains its input lock until explanation")
	await frames(100)
	check(GameState.opening_flags.ch2_shaft_demo_seen and scene.hud.panel_open,"safe can demonstration precedes live pursuit")
	check(not scene.ranger.active and not scene.player.controls_enabled,"safe explanation cannot advance attacker")
	var escape := InputEventAction.new()
	escape.action = "pause"
	escape.pressed = true
	Input.parse_input_event(escape)
	await frames(2)
	check(scene.player.controls_enabled and scene.ranger.active,"preview dismissal enables world controls")
	check(scene.phase == scene.Phase.ACTIVE and not scene.hud.panel_open,"Esc safely dismisses one-choice preview without soft lock")
	scene.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var focus_ranger_position: Vector2 = scene.ranger.position
	await frames(15)
	check(get_tree().paused and scene.hud.panel_open and scene.ranger.position == focus_ranger_position, "focus loss pauses active shaft pursuit")
	scene.close_panel()
	check(not get_tree().paused and scene.player.controls_enabled and scene.ranger.active, "shaft pursuit resumes after focus pause")
	check(not GameState.opening_flags.ch2_shaft_rope_used,"demonstration does not mark rope as used")
	var phone_event := InputEventAction.new()
	phone_event.action = "phone"
	phone_event.pressed = true
	Input.parse_input_event(phone_event)
	await frames(3)
	var ranger_before_phone: Vector2 = scene.ranger.position
	await frames(20)
	check(scene.hud.panel_open and get_tree().paused and scene.ranger.position == ranger_before_phone, "phone opens through the shaft handler and freezes the ranger")
	var phone: Control
	for child in scene.hud.panel_content.get_children():
		if child.has_method("_show_shoe_photo"):
			phone = child
			break
	if is_instance_valid(phone):
		phone._show_shoe_photo()
		Input.parse_input_event(phone_event.duplicate())
		await frames(3)
		check(scene.hud.panel_open and get_tree().paused and not is_instance_valid(phone.photo_cover), "first Q closes the phone photo without resuming the chase")
		phone.map_requested.emit()
		await frames(3)
		check(get_tree().paused and scene.hud.panel_content.get_child(0).get_script() == preload("res://ui/demo_travel_map.gd") and scene.ranger.position == ranger_before_phone, "opening the shaft phone map keeps the ranger frozen")
	else:
		check(false, "shaft phone widget is present")
	Input.parse_input_event(phone_event.duplicate())
	await frames(3)
	check(not scene.hud.panel_open and not get_tree().paused and scene.player.controls_enabled, "closing shaft phone resumes controls without a world action")

	await fixture()
	scene.ranger.active = false
	scene.player.position = Vector2(scene.PIT.position.x - 7,scene.PIT.get_center().y)
	scene.player.reset_physics_interpolation()
	await frames(3)
	check(scene.phase == scene.Phase.ACTIVE and scene.edge_warning,"safe rim warns without killing")
	var grid: AStarGrid2D = scene.ranger.grid
	var route := grid.get_point_path(scene.ranger._nearest_walkable(Vector2(210,270)),scene.ranger._nearest_walkable(Vector2(540,270)))
	check(route.size() > 2,"normal patrol has a route around shaft")
	var safe_path := true
	for point: Vector2 in route:
		if scene.PIT.grow(6).has_point(point): safe_path = false
	check(safe_path,"normal navigation never routes through the pit")
	check(scene.door_body.collision_layer == 0 and not scene.door_shadow.visible,"open bypass has no invisible collision or shadow")
	check(scene.get_node("ShaftInnerFallZone").collision_layer == 16,"pit is a hazard trigger rather than a wall")

	await fixture()
	scene.player.position = Vector2(545,350)
	scene.ranger.position = Vector2(294,269)
	scene.ranger.begin_lure(scene.BUCKET,Vector2(294,269))
	await frames(3)
	check(scene.ranger.charge_stage == "windup" and not scene.ranger.fallen,"lure first gives visible windup")
	var timer: float = scene.ranger.charge_remaining
	var position_before: Vector2 = scene.ranger.position
	get_tree().paused = true
	await frames(45)
	check(is_equal_approx(timer,scene.ranger.charge_remaining) and scene.ranger.position == position_before,"pause freezes windup and movement")
	get_tree().paused = false
	GameState.opening_flags.ch2_shaft_rope_used = true
	await frames(130)
	check(scene.ranger.fallen and GameState.opening_flags.ch2_ranger_fallen,"warned straight charge falls into shaft")
	check(scene.phase == scene.Phase.CLEARED and not scene.ranger.active,"fall ends pursuit exactly once")
	check(scene.ranger.collision_layer == 0,"fallen enemy cannot block passage")
	check(GameState.save_opening_checkpoint(),"fallen outcome checkpoint writes")
	var stored := OpeningCheckpoint.load_state(GameState.get_profile_path(),GameState.opening_scope())
	check(stored.ok and stored.data.flags.ch2_ranger_fallen,"fallen outcome survives disk decode")
	scene.queue_free()
	await frames(4)
	scene = preload("res://levels/ch2_guia/bunker_shaft_084.tscn").instantiate()
	add_child(scene)
	await frames(5)
	check(scene.phase == scene.Phase.CLEARED and not scene.ranger.active and not scene.ranger.visible,"reentering completed shaft does not respawn enemy")
	check(scene.ranger.collision_layer == 0,"completed hidden enemy leaves no invisible body")

	await fixture()
	scene.player.position = Vector2(320,269)
	scene.ranger.position = Vector2(294,269)
	scene.ranger.begin_lure(scene.BUCKET,Vector2(294,269))
	await frames(100)
	check(scene.phase == scene.Phase.LOST,"a player standing in the warned charge path can be caught")
	check(not scene.ranger.fallen and not GameState.opening_flags.ch2_ranger_fallen,"catch before the pit does not register an enemy fall")

	await fixture()
	scene.player.position = Vector2(545,350)
	scene.ranger.position = Vector2(294,269)
	scene.ranger.begin_lure(scene.BUCKET,Vector2(294,269))
	await frames(3)
	EventBus.camera_flash_fired.emit(Vector2(245,221),Vector2.RIGHT)
	await frames(2)
	check(scene.ranger.flash_receiver.is_stunned() and scene.ranger.charge_stage.is_empty(),"strong flash cancels windup and old charge target")
	check(scene.ranger.velocity == Vector2.ZERO and scene.ranger.charge_dir == Vector2.ZERO,"stunned charger has no residual killing movement")
	var stun: float = scene.ranger.flash_receiver.stun_remaining
	get_tree().paused = true
	await frames(35)
	check(is_equal_approx(stun,scene.ranger.flash_receiver.stun_remaining),"pause freezes ranger stun timer")
	get_tree().paused = false
	await frames(160)
	check(not scene.ranger.fallen and scene.ranger.charge_stage.is_empty(),"recovery searches rather than resuming cancelled charge")

	await fixture()
	scene.player.position = Vector2(545,296)
	scene.pull_rope()
	await frames(3)
	scene.fail_route("测试拉绳时被抓")
	await frames(73)
	check(scene.phase == scene.Phase.LOST and not scene.player.controls_enabled,"capture during rope animation never restores player control")
	check(not GameState.opening_flags.ch2_shaft_rope_used,"interrupted reach does not commit the bucket lure")
	check(scene.hud.panel_open,"capture during rope animation still offers retry")

	await fixture()
	scene.player.position = Vector2(545,296)
	scene.ranger.retire()
	scene.pull_rope()
	await frames(8)
	var held_frame: int = scene.rope_frame
	get_tree().paused = true
	await frames(30)
	check(scene.rope_frame == held_frame and not GameState.opening_flags.ch2_shaft_rope_used,"pause freezes rope pose and delays lure commitment")
	get_tree().paused = false
	await frames(50)
	check(GameState.opening_flags.ch2_shaft_rope_used and not scene.rope_action,"resuming finishes rope action and commits its result")
	check("水桶响动　5 / 5" in scene.hud.recent_noise, "meter records the real bucket noise while the rope action still locks movement")

	await fixture()
	await walk(Vector2(545,340))
	await walk(Vector2(545,296))
	await tap_interact()
	await frames(550)
	check(GameState.opening_flags.ch2_shaft_rope_used and GameState.opening_flags.ch2_ranger_fallen,"ordinary input reaches rope and completes lure without flashes")
	check(scene.phase == scene.Phase.CLEARED,"lure route remains playable without direct enemy repositioning")

	await fixture()
	await walk(Vector2(550,420))
	await walk(Vector2(650,365))
	await walk(Vector2(650,435))
	await tap_interact()
	await frames(10)
	var door_progress: float = scene.door_progress
	var moving_leaf_collision := scene.door_body.get_child(0) as CollisionShape2D
	var moving_leaf_width: float = (moving_leaf_collision.shape as RectangleShape2D).size.x
	var moving_leaf_shadow_width: float = scene.door_shadow.occluder.polygon[1].x - scene.door_shadow.occluder.polygon[0].x
	check(door_progress > 0.0 and door_progress < 1.0 and scene.door_frame > 0, "hinged door advances through a painted perspective frame")
	check(scene.door_body.collision_layer == 1 and is_equal_approx(moving_leaf_width, moving_leaf_shadow_width), "door collision and light occlusion grow with the same projected leaf width")
	var paused_door_frame: int = scene.door_frame
	get_tree().paused = true
	for _i in range(20): await get_tree().process_frame
	check(is_equal_approx(scene.door_progress, door_progress) and scene.door_frame == paused_door_frame and is_equal_approx((moving_leaf_collision.shape as RectangleShape2D).size.x, moving_leaf_width), "pause freezes the door pose, collision and light occlusion")
	get_tree().paused = false
	await frames(35)
	check(GameState.opening_flags.ch2_shaft_bypass_closed and scene.phase == scene.Phase.CLEARED,"input route closes bypass without any flash")
	check(GameState.phone_battery == 0 and GameState.phone_flash_charges == 0,"no-flash escape works from exhausted phone")
	check(scene.door_body.collision_layer == 1 and scene.door_shadow.visible,"closed metal door updates collision and occlusion")
	check(scene.door_frame == 5 and is_equal_approx((moving_leaf_collision.shape as RectangleShape2D).size.x, scene.DOOR.size.x), "the final door frame closes across its physical and light-blocking span")
	check(not scene.ranger.active and scene.player.controls_enabled,"closing door ends pursuit and restores controls")
	check(not GameState.opening_flags.ch2_ranger_fallen,"bypass escape does not pretend enemy fell")
	await walk(Vector2(690,458))
	await tap_interact()
	check(scene.hud.panel_open and GameState.opening_flags.ch2_shaft_note_seen,"note is readable through ordinary nearby interaction")
	check(GameState.save_opening_checkpoint(),"bypass and note checkpoint writes")
	stored = OpeningCheckpoint.load_state(GameState.get_profile_path(),GameState.opening_scope())
	check(stored.ok and stored.data.flags.ch2_shaft_bypass_closed and stored.data.flags.ch2_shaft_note_seen,"bypass state and note survive disk decode")
	scene.close_panel()

	await fixture()
	scene.ranger.active = false
	scene.player.position = scene.PIT_INNER.get_center()
	scene.player.reset_physics_interpolation()
	await frames(3)
	check(scene.phase == scene.Phase.LOST and not scene.player.controls_enabled,"entering inner shaft triggers player fall")
	check(not GameState.opening_flags.ch2_ranger_fallen,"player fall never marks monster defeated")
	scene.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var focus_fall_scale: Vector2 = scene.player.sprite.scale
	await frames(15)
	check(get_tree().paused and scene.hud.panel_open and scene.player.sprite.scale == focus_fall_scale, "focus loss pauses fall animation")
	scene.close_panel()
	check(not get_tree().paused and not scene.player.controls_enabled and scene.phase == scene.Phase.LOST, "fall resumes without unlocking player")
	await frames(50)
	check(scene.hud.panel_open,"player fall leads to retry panel")
	check(not GameState.opening_flags.ending_missing,"ordinary pit death is not a story ending")
	await clear_scene()
	print("SHAFT 084 checks=%d failures=%d" % [checks,failures])
	get_tree().quit(0 if failures == 0 else 1)
