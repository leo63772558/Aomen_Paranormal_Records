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


func wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


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


func walk_to(point: Vector2, max_frames := 1800) -> void:
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
	check(player.position.distance_to(point) < 18.0, "player reaches safe point " + str(point) + " actual=" + str(player.position))


func walk_via(points: Array[Vector2]) -> void:
	for point in points:
		await walk_to(point)


func close_panels() -> void:
	for _i in range(4):
		if not is_instance_valid(scene) or not is_instance_valid(scene.hud) or not scene.hud.panel_open:
			break
		scene._close_panel()
		await frames(3)


func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await frames(2)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	check(image != null and not image.is_empty() and image.save_png("res://docs/build_reports/" + label + ".png") == OK, "capture " + label)


func interact(id: String, standing_point: Vector2, turn := false) -> void:
	await walk_to(standing_point)
	await interact_here(id, turn)


func interact_via(id: String, route: Array[Vector2], standing_point: Vector2) -> void:
	await walk_via(route)
	await walk_to(standing_point)
	await interact_here(id)


func interact_here(id: String, turn := false) -> void:
	var target: Vector2 = scene.TARGETS[id]
	scene.player.look_dir = (target - scene.player.position).normalized() if scene.player.position.distance_to(target) > 0.1 else Vector2.LEFT
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
	if id == "schematic":
		await shot("coastal_pressure_schematic_dialogue_060")
	if turn:
		await frames(3)
		var panel = scene.widget
		if is_instance_valid(panel):
			panel.captions[scene.VALVE_SEQUENCE.find(id)].pressed.emit()
		else:
			check(false, "selecting a valve opens the pressure console")
	await wait_seconds(0.8)
	await close_panels()


func seed_state() -> void:
	GameState.opening_resume_checked = true
	GameState.bus_loop_state = {"successes": 5, "anomaly": "", "cycle": 5, "bell_pulled": false, "initialized": true, "next_cycle_pending": false}
	GameState.opening_items = {"multitool_pliers": 1}
	GameState.opening_flags = OpeningCheckpoint.default_flags()
	var flags: Dictionary = GameState.opening_flags
	for key in [
		"beach_key_box_open", "beach_cabinet_key_found", "beach_cabinet_open", "beach_plan_found",
		"beach_circuit_matched", "coastal_intro_seen", "coastal_drain_seen", "coastal_arrow_seen",
		"coastal_thread_seen", "coastal_ladder_seen", "coastal_route_verified", "coastal_landing_seen",
		"coastal_lower_drain_seen", "coastal_shutter_seen", "coastal_crawlway_seen",
		"coastal_chamber_intro_seen", "coastal_chamber_tide_seen", "coastal_chamber_grate_seen",
		"coastal_chamber_hatch_seen", "coastal_chamber_west_seen", "coastal_chamber_route_verified",
		"coastal_silt_intro_seen", "coastal_silt_map_seen", "coastal_silt_sluice_seen",
		"coastal_silt_collapse_seen", "coastal_silt_grate_seen", "coastal_silt_arch_seen",
		"coastal_silt_route_verified"
	]:
		flags[key] = true
	flags.bus_arrived = true
	GameState.current_room_id = "ch5_coastal_silt_tunnel"
	GameState.current_chapter_id = "ch5_hacsa_beach"
	GameState.pending_entry_id = "from_chamber"


func payload() -> Dictionary:
	var role_resource_snapshot: Dictionary = GameState.role_resources.duplicate(true)
	role_resource_snapshot[GameState.current_role] = {"stamina": GameState.stamina, "flashlight_battery": GameState.flashlight_battery}
	return {
		"schema_version": OpeningCheckpoint.SCHEMA_VERSION,
		"build_id": "coastal_pressure_gallery_060",
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
	if GameState.profile != "test" or not GameState.opening_checkpoint_enabled():
		push_error("FAIL pressure gallery regression requires --profile=test and --checkpoint-qa")
		get_tree().quit(1)
		return
	if "--verify-interrupt" in OS.get_cmdline_user_args():
		GameState.prepare_opening_resume()
		check(GameState.current_room_id == "ch5_coastal_pressure_gallery" and not GameState.opening_flags.coastal_pressure_inlet_closed, "new process restores uncommitted valve checkpoint")
		scene = load("res://levels/ch5_hacsa_beach/coastal_pressure_gallery_060.tscn").instantiate()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		await frames(15)
		check(not scene.scene_action_active and is_zero_approx(scene.valve_handles.inlet.rotation) and scene.player.controls_enabled, "new process restores initial valve pose and player control")
		await interact("inlet", Vector2(315, 370), true)
		check(GameState.opening_flags.coastal_pressure_inlet_closed, "restored valve can be operated")
		print("PRESSURE VALVE RESTART checks=%d failures=%d" % [checks, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
	seed_state()
	check(GameState.profile == "test", "isolated test profile")
	scene = load("res://levels/ch5_hacsa_beach/coastal_silt_tunnel.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await wait_seconds(1.0)
	await close_panels()
	await scene.interact_target("arch")
	await wait_seconds(1.0)
	scene = get_tree().current_scene
	check(GameState.current_room_id == "ch5_coastal_pressure_gallery" and scene.ROOM_ID == "ch5_coastal_pressure_gallery", "verified dry arch enters registered pressure gallery")
	check(scene.player.position.distance_to(Vector2(640, 660)) < 5.0, "gallery entry uses south arch spawn")
	check(GameState.opening_flags.coastal_pressure_intro_seen, "gallery entry records intro and checkpoint")
	await close_panels()
	await shot("coastal_pressure_gallery_entry_060")

	await interact_via("inlet", [Vector2(640, 440)], Vector2(315, 370))
	check(not GameState.opening_flags.coastal_pressure_inlet_closed, "opening the console alone doesn't turn the inlet")
	await interact("cabinet", Vector2(164, 440))
	check(not GameState.opening_flags.coastal_works_record_found, "record cabinet remains pressure-locked")

	await interact_via("schematic", [Vector2(640, 370)], Vector2(394, 370))
	await interact_via("gauge", [Vector2(640, 370)], Vector2(1008, 360))
	await interact_via("drain", [Vector2(1120, 370)], Vector2(1120, 500))
	check(GameState.opening_flags.coastal_pressure_diagram_seen and GameState.opening_flags.coastal_pressure_gauge_seen and GameState.opening_flags.coastal_pressure_drain_seen, "diagram, gauge, and drainage evidence are all recorded")
	await interact("bypass", Vector2(968, 370), true)
	check(not GameState.opening_flags.coastal_pressure_bypass_open, "bypass cannot open before isolating the inlet")

	await walk_to(Vector2(315, 370))
	scene.player.look_dir = scene.player.position.direction_to(scene.TARGETS.inlet)
	await frames(3)
	check(scene.selected_id == "inlet", "inlet can be selected before the action")
	var inlet_press := InputEventAction.new()
	inlet_press.action = "interact"
	inlet_press.pressed = true
	Input.parse_input_event(inlet_press)
	await frames(4)
	var inlet_release := InputEventAction.new()
	inlet_release.action = "interact"
	inlet_release.pressed = false
	Input.parse_input_event(inlet_release)
	var valve_panel = scene.widget
	if not is_instance_valid(valve_panel):
		check(false, "E opens the real console from the inlet stand")
		get_tree().quit(1)
		return
	valve_panel.captions[0].pressed.emit()
	await frames(4)
	check(scene.scene_action_active and not GameState.opening_flags.coastal_pressure_inlet_closed, "turning the wheel begins an uncommitted action")
	if "--valve-interrupt" in OS.get_cmdline_user_args():
		scene.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(get_tree().paused and scene.hud.panel_open, "in-progress valve can be paused before exit")
		scene._return_to_title()
		await frames(12)
		var saved := OpeningCheckpoint.load_state(GameState.get_profile_path(), GameState.opening_scope())
		check(saved.ok and not saved.data.flags.coastal_pressure_inlet_closed, "mid-animation exit saves the uncommitted valve state")
		if "--interrupt-write" in OS.get_cmdline_user_args():
			print("PRESSURE VALVE WRITE checks=%d failures=%d" % [checks, failures])
			get_tree().quit(1 if failures > 0 else 0)
			return
		check(GameState.request_room_change("ch5_coastal_pressure_gallery", GameState.pending_entry_id), "gallery can be re-entered after interrupted action")
		await frames(15)
		scene = get_tree().current_scene
		check(is_instance_valid(scene) and not scene.scene_action_active and not GameState.opening_flags.coastal_pressure_inlet_closed and is_zero_approx(scene.valve_handles.inlet.rotation), "reloaded valve returns to the initial pose and is not locked")
		await interact("inlet", Vector2(315, 370), true)
		check(GameState.opening_flags.coastal_pressure_inlet_closed, "valve can be operated after interrupted save and reload")
		print("PRESSURE VALVE INTERRUPT checks=%d failures=%d" % [checks, failures])
		get_tree().quit(1 if failures > 0 else 0)
		return
	scene.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var stopped_angle: float = scene.valve_handles.inlet.rotation
	await frames(20)
	check(get_tree().paused and scene.hud.panel_open and is_equal_approx(scene.valve_handles.inlet.rotation, stopped_angle) and not GameState.opening_flags.coastal_pressure_inlet_closed, "focus loss freezes the inlet without committing it")
	scene._close_panel()
	check(not get_tree().paused and not scene.player.controls_enabled and scene.scene_action_active, "resuming the valve keeps world controls locked")
	await wait_seconds(0.8)
	await close_panels()
	check(GameState.opening_flags.coastal_pressure_inlet_closed, "first valve isolates the active feed")
	await walk_via([Vector2(840, 370)])
	await interact("bleed", Vector2(1045, 360), true)
	check(not GameState.opening_flags.coastal_pressure_bleeder_open, "bleeder stays closed until bypass carries flow")
	await interact("bypass", Vector2(968, 370), true)
	check(GameState.opening_flags.coastal_pressure_bypass_open, "second valve routes flow through bypass")
	await interact("bleed", Vector2(1045, 360), true)
	check(GameState.opening_flags.coastal_pressure_bleeder_open and scene.gauge_needle.rotation > 0.5, "third valve bleeds pressure and moves the gauge needle")

	await interact_via("cabinet", [Vector2(840, 370)], Vector2(164, 440))
	check(GameState.opening_flags.coastal_works_record_found, "depressurized cabinet yields coastal works record")
	check(is_zero_approx(scene.arch_water.modulate.a), "zero pressure reveals the dry approach")
	check(not OpeningCheckpoint.decode(JSON.stringify(payload()), GameState.opening_scope()).is_empty(), "060 checkpoint payload passes validation")

	await walk_via([Vector2(640, 380), Vector2(315, 380)])
	for _i in range(22):
		event_action("move_up", true)
		await get_tree().physics_frame
		event_action("move_up", false)
	await frames(3)
	check(scene.player.position.y > 344.0, "left valve assembly blocks entry through its solid footprint")
	await walk_via([Vector2(315, 400), Vector2(1120, 400), Vector2(1120, 500)])
	for _i in range(22):
		event_action("move_right", true)
		await get_tree().physics_frame
		event_action("move_right", false)
	await frames(3)
	check(scene.player.position.x < 1148.0, "drain trench blocks movement into the channel")

	scene._pause_menu()
	await frames(3)
	var frozen_position: Vector2 = scene.player.position
	for _i in range(6):
		event_action("move_right", true)
		await get_tree().physics_frame
		event_action("move_right", false)
	check(scene.hud.panel_open and scene.player.position.distance_to(frozen_position) < 1.0, "pause panel freezes gallery movement")
	await close_panels()
	# Simulate a missing required photograph: the checkpoint must fail before
	# replacing any existing save, leaving the player in the current room.
	var old_photo_flag: bool = GameState.opening_flags.photo_taken
	var old_photo = GameState.opening_photo
	var old_photo_file: String = GameState.opening_photo_file
	var checkpoint_path := GameState.get_profile_path().path_join("opening_checkpoint.json")
	var previous_checkpoint := FileAccess.get_file_as_bytes(checkpoint_path)
	GameState.opening_flags.photo_taken = true
	GameState.opening_photo = null
	GameState.opening_photo_file = ""
	scene.checkpoint()
	check("保存失败" in scene.hud.defense_notice.text and not get_tree().paused, "automatic checkpoint failure is visible without interrupting play")
	check(FileAccess.get_file_as_bytes(checkpoint_path) == previous_checkpoint, "failed automatic checkpoint preserves existing bytes")
	scene._pause_menu()
	scene._return_to_title()
	await frames(3)
	check(get_tree().current_scene == scene and scene.hud.panel_open and get_tree().paused, "failed save keeps the player in the gallery with a paused error panel")
	check(FileAccess.file_exists(checkpoint_path) and FileAccess.get_file_as_bytes(checkpoint_path) == previous_checkpoint, "failed save preserves the previous checkpoint bytes")
	await close_panels()

	await interact("return", Vector2(640, 620))
	await wait_seconds(1.0)
	scene = get_tree().current_scene
	check(GameState.current_room_id == "ch5_coastal_silt_tunnel" and scene.ROOM_ID == "ch5_coastal_silt_tunnel", "south arch returns to registered silt tunnel")
	check(GameState.pending_entry_id == "from_pressure_gallery", "return uses the pressure-gallery entry ID")
	check(scene.player.position.distance_to(Vector2(346, 338)) < 5.0, "return spawn is safe beside the verified arch")
	check("保存失败" in scene.hud.defense_notice.text, "failed transition checkpoint is reported in the destination")
	check(FileAccess.get_file_as_bytes(checkpoint_path) == previous_checkpoint, "failed transition keeps the previous checkpoint")
	GameState.opening_flags.photo_taken = old_photo_flag
	GameState.opening_photo = old_photo
	GameState.opening_photo_file = old_photo_file
	check(not OpeningCheckpoint.decode(JSON.stringify(payload()), GameState.opening_scope()).is_empty(), "new route flags remain valid after return")
	scene._pause_menu()
	scene._return_to_title()
	await frames(10)
	check(get_tree().current_scene != scene and GameState.current_room_id == "ch5_coastal_silt_tunnel", "successful save returns to title while retaining the saved room")

	print("COASTAL PRESSURE GALLERY 060 checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
