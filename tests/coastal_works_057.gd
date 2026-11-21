extends Node

var scene: Node
var checks := 0
var failures := 0
var held := {"move_left": false, "move_right": false, "move_up": false, "move_down": false, "sprint": false}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS " + label)
	else:
		failures += 1
		push_error("FAIL " + label)

func frames(count := 4) -> void:
	for _i in range(count):
		await get_tree().process_frame

func event_action(action: String, pressed: bool) -> void:
	if pressed:
		Input.action_press(action, 1.0)
	else:
		Input.action_release(action)

func release_all() -> void:
	for action in held:
		if held[action]:
			event_action(action, false)
			held[action] = false

func walk_to(point: Vector2, max_frames := 1200) -> void:
	var player: PlayerController = scene.player
	player.aim_override = true
	for _i in range(max_frames):
		var delta: Vector2 = point - player.position
		if delta.length() < 2.5:
			break
		player.look_dir = delta.normalized()
		var desired := {
			"move_left": delta.x < -2.0,
			"move_right": delta.x > 2.0,
			"move_up": delta.y < -2.0,
			"move_down": delta.y > 2.0,
			"sprint": true
		}
		for action in held:
			if held[action] != desired[action]:
				event_action(action, desired[action])
				held[action] = desired[action]
		await get_tree().physics_frame
	release_all()
	await frames(3)
	check(player.position.distance_to(point) < 12.0, "walk reaches " + str(point) + " actual=" + str(player.position))

func push_toward(point: Vector2, frame_count := 36) -> void:
	var player: PlayerController = scene.player
	player.aim_override = true
	var delta: Vector2 = point - player.position
	var desired := {
		"move_left": delta.x < -2.0,
		"move_right": delta.x > 2.0,
		"move_up": delta.y < -2.0,
		"move_down": delta.y > 2.0,
		"sprint": true
	}
	for action in held:
		if held[action] != desired[action]:
			event_action(action, desired[action])
			held[action] = desired[action]
	for _i in range(frame_count):
		await get_tree().physics_frame
	release_all()
	await frames(3)

func close_panel() -> void:
	if is_instance_valid(scene) and is_instance_valid(scene.hud) and scene.hud.panel_open:
		scene._close_panel()
	await frames(3)

func interact(id: String, point: Vector2) -> void:
	await walk_to(point)
	var target: Vector2 = scene.TARGETS[id]
	scene.player.look_dir = (target - scene.player.position).normalized() if scene.player.position.distance_to(target) > 0.1 else Vector2.RIGHT
	await frames(3)
	check(scene.selected_id == id, "front-facing target selection " + id + " actual=" + scene.selected_id + " position=" + str(scene.player.position) + " look=" + str(scene.player.look_dir))
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	Input.parse_input_event(press)
	await frames(1)
	var release := InputEventAction.new()
	release.action = "interact"
	release.pressed = false
	Input.parse_input_event(release)
	await frames(3)
	if not is_instance_valid(scene):
		return
	if is_instance_valid(scene.hud) and scene.hud.panel_open:
		await close_panel()

func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await frames(2)
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png("res://docs/build_reports/" + label + ".png") == OK, "capture " + label)

func checkpoint_payload() -> Dictionary:
	GameState.role_resources[GameState.current_role] = {"stamina": GameState.stamina, "flashlight_battery": GameState.flashlight_battery}
	return {
		"schema_version": OpeningCheckpoint.SCHEMA_VERSION,
		"build_id": "story_v5_043",
		"rules_version": 1,
		"profile": GameState.profile,
		"run_id": GameState.run_id,
		"checkpoint_id": "opening_stage",
		"current_chapter_id": GameState.current_chapter_id,
		"room_id": GameState.current_room_id,
		"entry_id": GameState.pending_entry_id,
		"flags": GameState.opening_flags.duplicate(true),
		"switches": GameState.opening_switches.duplicate(true),
		"items": GameState.opening_items.duplicate(),
		"resources": {"stamina": GameState.stamina, "flashlight_battery": GameState.flashlight_battery},
		"photo_file": GameState.opening_photo_file,
		"active_role": GameState.current_role,
		"role_resources": GameState.role_resources.duplicate(true),
		"bus_loop_state": GameState.bus_loop_state.duplicate(true)
	}

func seed_beach_route() -> void:
	GameState.reset_opening()
	GameState.opening_resume_checked = true
	GameState.opening_flags.beach_intro_seen = true
	GameState.opening_flags.bus_arrived = true
	GameState.bus_loop_state.successes = 5
	GameState.opening_flags.beach_sole_seen = true
	GameState.opening_flags.beach_trace_a_seen = true
	GameState.opening_flags.beach_wrack_seen = true
	GameState.opening_flags.beach_trace_b_seen = true
	GameState.opening_flags.beach_footprints_solved = true
	GameState.opening_flags.beach_key_box_open = true
	GameState.opening_flags.beach_cabinet_key_found = true
	GameState.opening_flags.beach_cabinet_open = true
	GameState.opening_flags.beach_plan_found = true
	GameState.opening_flags.beach_circuit_matched = true
	GameState.opening_items["beach_cabinet_key"] = 1
	GameState.opening_items["hotel_maintenance_plan"] = 1
	GameState.current_room_id = "ch5_hacsa_beach"
	GameState.current_chapter_id = "ch5_hacsa_beach"
	GameState.pending_entry_id = "from_bus_crash"

func run() -> void:
	check(GameState.profile == "test", "isolated test profile")
	seed_beach_route()
	scene = load("res://levels/ch5_hacsa_beach/beach_scene.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await frames(10)
	check(scene.player != null and not scene.hud.panel_open, "black-sand entry fixture ready")
	scene._leave_beach()
	await frames(10)
	check(GameState.current_room_id == "ch5_coastal_works", "beach maintenance-plan route enters works")
	scene = get_tree().current_scene
	check(scene.ROOM_ID == "ch5_coastal_works" and scene.player != null, "upper works scene registered")
	if scene.hud.panel_open:
		await close_panel()
	await shot("coastal_works_upper_057")

	await interact("arrow", Vector2(294, 468))
	await walk_to(Vector2(520, 480))
	await walk_to(Vector2(558, 500))
	await interact("drain", Vector2(558, 625))
	await walk_to(Vector2(558, 280))
	await interact("thread", Vector2(1054, 158))
	check(scene.player.test_move(Transform2D(0, Vector2(1095, 164)), Vector2(70, 0)), "ladder opening collision keeps player on rim")
	await shot("coastal_works_route_057")
	await interact("ladder", Vector2(1095, 164))
	check(GameState.opening_flags.coastal_route_verified, "upper plan and four physical clues agree")
	check(scene.transition_active and not scene.player.controls_enabled, "ladder transition locks world controls")
	scene._descend_shaft()
	scene.interact_target("entry")
	check(scene.find_children("ShaftTransitionFade", "CanvasLayer", true, false).size() == 1 and GameState.current_room_id == "ch5_coastal_works", "repeated input cannot duplicate or redirect ladder transition")
	scene.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var transition_position: Vector2 = scene.player.position
	await frames(12)
	check(get_tree().paused and scene.player.position == transition_position, "focus loss pauses ladder descent")
	scene._close_panel()
	check(not get_tree().paused and not scene.player.controls_enabled and scene.transition_active, "resume keeps controls locked until descent completes")
	await get_tree().create_timer(1.2).timeout
	scene = get_tree().current_scene
	check(GameState.current_room_id == "ch5_coastal_landing" and scene.ROOM_ID == "ch5_coastal_landing", "verified ladder descends to registered landing")
	check(GameState.opening_flags.coastal_landing_seen, "landing checkpoint is recorded before exploration")
	check(scene.hud.toast_time > 0.0, "first descent shows a short landing cue")
	if scene.hud.panel_open:
		await close_panel()
	await shot("coastal_works_landing_057")

	var frozen_at: Vector2 = scene.player.position
	scene._pause_menu()
	await frames(24)
	check(scene.player.position == frozen_at and not scene.player.controls_enabled, "pause freezes lower-room movement")
	await close_panel()
	await walk_to(Vector2(300, 324))
	await walk_to(Vector2(590, 330))
	await walk_to(Vector2(650, 365))
	await walk_to(Vector2(750, 365))
	await walk_to(Vector2(750, 390))
	await interact("drain", Vector2(765, 405))
	await push_toward(Vector2(765, 500))
	check(scene.player.position.y < 420.0, "iron grille blocks entry into the flooded sump")
	await walk_to(Vector2(880, 269))
	await interact("shutter", Vector2(880, 269))
	var gate_position: Vector2 = scene.player.position
	await push_toward(Vector2(880, 200))
	check(scene.player.position.y >= 257.0 and scene.player.position.y < gate_position.y, "closed shutter blocks passage at the visible threshold")
	await walk_to(Vector2(1150, 281))
	check(GameState.opening_flags.coastal_lower_drain_seen and GameState.opening_flags.coastal_shutter_seen, "optional evidence is saved on the way to the passage")
	await shot("coastal_works_lower_evidence_057")
	var decoded := OpeningCheckpoint.decode(JSON.stringify(checkpoint_payload()), GameState.opening_scope())
	if decoded.is_empty():
		print("CHECKPOINT DEBUG room=%s chapter=%s entry=%s global_user=%s" % [GameState.current_room_id, GameState.current_chapter_id, GameState.pending_entry_id, ProjectSettings.globalize_path("user://")])
	check(not decoded.is_empty(), "checkpoint payload passes progression validation")
	check(GameState.save_opening_checkpoint(), "checkpoint save call succeeds")
	if GameState.opening_checkpoint_enabled():
		var saved := OpeningCheckpoint.read_valid(GameState.get_profile_path().path_join("opening_checkpoint.json"), GameState.opening_scope())
		check(saved.get("room_id") == "ch5_coastal_landing" and saved.flags.coastal_lower_drain_seen, "isolated checkpoint reloads lower evidence")

	await walk_to(Vector2(780, 279))
	await walk_to(Vector2(784, 367))
	await walk_to(Vector2(645, 365))
	await walk_to(Vector2(586, 329))
	await walk_to(Vector2(300, 325))
	await interact("ladder", Vector2(207, 316))
	await frames(10)
	scene = get_tree().current_scene
	check(GameState.current_room_id == "ch5_coastal_works" and scene.player.position.distance_to(Vector2(1093, 164)) < 2.0, "ladder returns to a safe upper-room entry")
	await walk_to(Vector2(558, 280))
	await walk_to(Vector2(520, 450))
	await walk_to(Vector2(294, 468))
	await walk_to(Vector2(45, 452))
	scene.interact_target("entry")
	await frames(10)
	scene = get_tree().current_scene
	check(GameState.current_room_id == "ch5_hacsa_beach" and scene.ROOM_ID == "ch5_hacsa_beach", "return route reaches black-sand safe path")
	check(GameState.opening_flags.coastal_route_verified and GameState.opening_flags.coastal_lower_drain_seen, "upper and lower evidence survive return transition")
	check(GameState.save_opening_checkpoint(), "final room checkpoint save call succeeds")
	print("COASTAL WORKS 057 checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
