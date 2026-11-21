extends Node

var scene: Node
var checks := 0
var failures := 0
var held := {"move_left": false, "move_right": false, "move_up": false, "move_down": false, "sprint": false}

func _enter_tree() -> void:
	if DisplayServer.get_name() != "headless":
		get_window().set_flag(Window.FLAG_NO_FOCUS, true)
		get_window().position = Vector2i(-32000, -32000)

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

func resume_hidden_focus_pause() -> bool:
	if "--hidden-resume" not in OS.get_cmdline_user_args() or not get_tree().paused or not is_instance_valid(scene) or not is_instance_valid(scene.hud) or not scene.hud.panel_open:
		return false
	for label in scene.hud.panel_content.find_children("*", "Label", true, false):
		if label.text == "暂停":
			print("Hidden QA: resume focus-loss pause through room handler")
			scene._close_panel()
			return true
	return false

func walk_to(point: Vector2, max_frames := 1400) -> void:
	var player: PlayerController = scene.player
	player.aim_override = true
	for _i in range(max_frames):
		resume_hidden_focus_pause()
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
	if player.position.distance_to(point) >= 17.0:
		print("WALK DIAGNOSTIC paused=", get_tree().paused, " panel=", scene.hud.panel_open, " controls=", player.controls_enabled, " position=", player.position)
	check(player.position.distance_to(point) < 17.0, "player reaches safe investigation point " + str(point) + " actual=" + str(player.position))

func walk_via(points: Array[Vector2]) -> void:
	for point in points:
		await walk_to(point)

func close_panels() -> void:
	for _i in range(3):
		if not is_instance_valid(scene) or not is_instance_valid(scene.hud) or not scene.hud.panel_open:
			break
		scene._close_panel()
		await frames(3)

func interact(id: String, standing_point: Vector2) -> void:
	await walk_to(standing_point)
	var target: Vector2 = scene.TARGETS[id]
	scene.player.look_dir = (target - scene.player.position).normalized() if scene.player.position.distance_to(target) > 0.1 else Vector2.LEFT
	await frames(3)
	if resume_hidden_focus_pause():
		await frames(3)
	check(scene.selected_id == id, "front-facing target selection " + id + " selected=" + scene.selected_id)
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
	await close_panels()

func seed_chamber() -> void:
	GameState.opening_resume_checked = true
	GameState.bus_loop_state = {"successes": 5, "anomaly": "", "cycle": 5, "bell_pulled": false, "initialized": true, "next_cycle_pending": false}
	GameState.opening_items = {"multitool_pliers": 1}
	var flags: Dictionary = GameState.opening_flags
	for key in [
		"beach_key_box_open", "beach_cabinet_key_found", "beach_cabinet_open", "beach_plan_found",
		"beach_circuit_matched", "coastal_intro_seen", "coastal_drain_seen", "coastal_arrow_seen",
		"coastal_thread_seen", "coastal_ladder_seen", "coastal_route_verified", "coastal_landing_seen",
		"coastal_lower_drain_seen", "coastal_shutter_seen", "coastal_crawlway_seen",
		"coastal_chamber_intro_seen", "coastal_chamber_tide_seen", "coastal_chamber_grate_seen",
		"coastal_chamber_hatch_seen", "coastal_chamber_west_seen", "coastal_chamber_route_verified"
	]:
		flags[key] = true
	flags.bus_arrived = true
	GameState.current_room_id = "ch5_coastal_chamber"
	GameState.current_chapter_id = "ch5_hacsa_beach"
	GameState.pending_entry_id = "from_landing"

func test_payload() -> Dictionary:
	var role_resource_snapshot: Dictionary = GameState.role_resources.duplicate(true)
	role_resource_snapshot[GameState.current_role] = {"stamina": GameState.stamina, "flashlight_battery": GameState.flashlight_battery}
	return {
		"schema_version": OpeningCheckpoint.SCHEMA_VERSION,
		"build_id": "coastal_silt_tunnel_059",
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
		"role_resources": role_resource_snapshot,
		"bus_loop_state": GameState.bus_loop_state.duplicate(true)
	}

func run() -> void:
	if GameState.profile != "test":
		push_error("FAIL silt tunnel regression requires --profile=test")
		get_tree().quit(1)
		return
	seed_chamber()
	check(GameState.profile == "test", "isolated test profile")
	scene = load("res://levels/ch5_hacsa_beach/coastal_chamber.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await frames(12)
	check(scene.ROOM_ID == "ch5_coastal_chamber" and not scene.hud.panel_open, "verified chamber fixture is ready")
	await walk_via([
		Vector2(1150, 487), Vector2(1000, 487), Vector2(1000, 410),
		Vector2(520, 410), Vector2(240, 410), Vector2(118, 365)
	])
	await interact("next", Vector2(118, 365))
	for _i in range(180):
		var current := get_tree().current_scene
		if GameState.current_room_id == "ch5_coastal_silt_tunnel" and is_instance_valid(current) and current.get("ROOM_ID") == "ch5_coastal_silt_tunnel": break
		resume_hidden_focus_pause()
		await frames(1)
	scene = get_tree().current_scene
	var entered: bool = GameState.current_room_id == "ch5_coastal_silt_tunnel" and is_instance_valid(scene) and scene.get("ROOM_ID") == "ch5_coastal_silt_tunnel"
	check(entered, "verified left arch enters registered silt tunnel")
	if not entered:
		get_tree().paused = false
		get_tree().quit(1)
		return
	check(GameState.opening_flags.coastal_silt_intro_seen, "first entry records its intro state")
	await frames(40)
	await close_panels()
	if "--hidden-resume" in OS.get_cmdline_user_args():
		scene.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(get_tree().paused and scene.hud.panel_open, "focus loss opens an actual pause panel")
		check(resume_hidden_focus_pause() and not get_tree().paused and scene.player.controls_enabled, "hidden QA resumes through the room pause handler")
	await walk_to(Vector2(666, 631))
	scene.player.look_dir = scene.player.position.direction_to(scene.TARGETS.spare_battery)
	await frames(3)
	check(scene.selected_id == "spare_battery", "the side of the entry passage gives access to the backup battery")
	if "--capture-battery" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var screenshot := get_viewport().get_texture().get_image()
		check(screenshot.save_png("res://docs/build_reports/silt_spare_battery.png") == OK, "the coastal battery renders in the entry passage")
	scene.player.flashlight_on = false
	GameState.flashlight_battery = 83.0
	var interact_event := InputEventAction.new()
	interact_event.action = "interact"
	interact_event.pressed = true
	Input.parse_input_event(interact_event)
	await frames(4)
	check(GameState.opening_flags.silt_spare_battery_taken and GameState.flashlight_battery == 100.0 and not is_instance_valid(scene.spare_battery), "the coastal reserve caps charge at 100 and clears its world footprint")
	GameState.opening_flags.jiamin_phone_found = true
	GameState.take_demo_item("jiamin_phone")
	var journal_event := InputEventAction.new()
	journal_event.action = "journal"
	journal_event.pressed = true
	Input.parse_input_event(journal_event)
	await frames(4)
	check(scene.hud.archive_page == "journal" and "淤泥岔口记录" in scene.hud.default_phone_widget.detail.text, "the phone journal preserves the current room's evidence checklist")
	Input.parse_input_event(journal_event.duplicate())
	await frames(4)
	scene._pause_menu()
	await frames(3)
	var frozen_position: Vector2 = scene.player.position
	for _i in range(6):
		event_action("move_right", true)
		await get_tree().physics_frame
	event_action("move_right", false)
	check(scene.hud.panel_open and scene.player.position.distance_to(frozen_position) < 1.0, "pause panel freezes tunnel movement")
	await close_panels()

	await interact("map", Vector2(708, 225))
	# Go below the wall-mounted map before crossing its solid cabinet corner.
	await walk_to(Vector2(708, 305))
	await walk_to(Vector2(900, 305))
	await interact("sluice", Vector2(980, 270))
	await interact("collapse", Vector2(250, 300))
	for _i in range(24):
		event_action("move_left", true)
		await get_tree().physics_frame
	event_action("move_left", false)
	await frames(3)
	check(scene.player.position.x > 232.0, "collapsed branch blocks passage")
	await interact("grate", Vector2(344, 396))
	for _i in range(24):
		event_action("move_down", true)
		await get_tree().physics_frame
	event_action("move_down", false)
	await frames(3)
	check(scene.player.position.y < 407.0, "flush floor grate blocks entry into the opening")
	check(scene._all_evidence_seen(), "four separate physical observations are recorded")
	check(not GameState.opening_flags.coastal_silt_route_verified, "evidence alone does not skip the arch verification")
	check(not OpeningCheckpoint.decode(JSON.stringify(test_payload()), GameState.opening_scope()).is_empty(), "silt tunnel checkpoint payload passes validation")

	await walk_to(Vector2(972, 300))
	for _i in range(24):
		event_action("move_right", true)
		await get_tree().physics_frame
	event_action("move_right", false)
	await frames(3)
	check(scene.player.position.x < 1035.0, "closed sluice blocks passage")

	await walk_to(Vector2(900, 332))
	for _i in range(24):
		event_action("move_down", true)
		await get_tree().physics_frame
	event_action("move_down", false)
	await frames(3)
	check(scene.player.position.y < 347.0, "raised wet sill blocks entry into the flooded pool")

	await interact("return", Vector2(592, 610))
	check(scene.transition_active and not scene.player.controls_enabled, "silt return transition locks controls")
	scene.interact_target("arch")
	check(GameState.current_room_id == "ch5_coastal_silt_tunnel" and scene.transition_active, "repeated interaction cannot interrupt silt return")
	scene.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(8)
	check(get_tree().paused and scene.hud.panel_open, "focus loss pauses silt return")
	scene._close_panel()
	check(not get_tree().paused and not scene.player.controls_enabled and scene.transition_active, "silt return stays locked after resume")
	await frames(80)
	scene = get_tree().current_scene
	check(GameState.current_room_id == "ch5_coastal_chamber" and scene.ROOM_ID == "ch5_coastal_chamber", "south passage returns to the registered chamber")
	check(GameState.pending_entry_id == "from_silt_tunnel", "return uses the correct room entry")
	check(scene.player.position.distance_to(Vector2(140, 356)) < 5.0, "return spawn stays clear of the next-scene trigger")
	check(not OpeningCheckpoint.decode(JSON.stringify(test_payload()), GameState.opening_scope()).is_empty(), "new route flags pass checkpoint validation")

	print("COASTAL SILT TUNNEL 059 checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
