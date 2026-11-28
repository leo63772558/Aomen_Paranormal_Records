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

func walk_to(point: Vector2, max_frames := 1400) -> void:
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
	check(player.position.distance_to(point) < 16.0, "player reaches safe investigation point " + str(point) + " actual=" + str(player.position))

func walk_via(points: Array[Vector2]) -> void:
	for point in points:
		await walk_to(point)

func close_panel() -> void:
	if is_instance_valid(scene) and is_instance_valid(scene.hud) and scene.hud.panel_open:
		scene._close_panel()
	await frames(3)

func interact(id: String, standing_point: Vector2) -> void:
	await walk_to(standing_point)
	var target: Vector2 = scene.TARGETS[id]
	scene.player.look_dir = (target - scene.player.position).normalized() if scene.player.position.distance_to(target) > 0.1 else Vector2.LEFT
	await frames(3)
	check(scene.selected_id == id, "front-facing target selection " + id + " selected=" + scene.selected_id)
	scene.interact_target(id)
	await frames(3)
	if is_instance_valid(scene) and is_instance_valid(scene.hud) and scene.hud.panel_open:
		await close_panel()

func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await frames(2)
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png("res://docs/build_reports/" + label + ".png") == OK, "capture " + label)

func seed_landing() -> void:
	GameState.reset_opening()
	GameState.opening_resume_checked = true
	GameState.bus_loop_state = {"successes": 5, "anomaly": "", "cycle": 5, "bell_pulled": false, "initialized": true, "next_cycle_pending": false}
	var flags: Dictionary = GameState.opening_flags
	flags.beach_key_box_open = true
	flags.beach_cabinet_key_found = true
	flags.beach_cabinet_open = true
	flags.beach_plan_found = true
	flags.beach_circuit_matched = true
	flags.bus_arrived = true
	flags.coastal_intro_seen = true
	flags.coastal_drain_seen = true
	flags.coastal_arrow_seen = true
	flags.coastal_thread_seen = true
	flags.coastal_ladder_seen = true
	flags.coastal_route_verified = true
	flags.coastal_landing_seen = true
	flags.coastal_lower_drain_seen = true
	flags.coastal_shutter_seen = true
	GameState.current_room_id = "ch5_coastal_landing"
	GameState.current_chapter_id = "ch5_hacsa_beach"
	GameState.pending_entry_id = "from_shaft"

func run() -> void:
	check(GameState.profile == "test", "isolated test profile")
	GameState.legacy_coastal_qa = true
	seed_landing()
	scene = load("res://levels/ch5_hacsa_beach/coastal_landing.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await frames(12)
	check(is_instance_valid(scene.player) and not scene.hud.panel_open, "lower landing fixture ready")
	scene.interact_target("crawlway")
	await frames(3)
	check(GameState.opening_flags.coastal_crawlway_seen and scene.transition_active, "marked right passage starts the transition")
	check(scene.transition_active and not scene.player.controls_enabled, "crawlway transition locks controls")
	scene.interact_target("ladder")
	check(GameState.current_room_id == "ch5_coastal_landing", "repeated interaction cannot interrupt crawling")
	scene.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(8)
	check(get_tree().paused and scene.hud.panel_open, "focus loss pauses crawlway transition")
	scene._close_panel()
	check(not get_tree().paused and not scene.player.controls_enabled and scene.transition_active, "crawlway remains locked on resume")
	await get_tree().create_timer(1.0, true).timeout
	scene = get_tree().current_scene
	check(GameState.current_room_id == "ch5_coastal_chamber" and scene.ROOM_ID == "ch5_coastal_chamber", "verified passage enters registered chamber")
	check(GameState.opening_flags.coastal_chamber_intro_seen, "chamber entry checkpoint is recorded")
	if scene.hud.panel_open:
		await close_panel()
	await shot("coastal_chamber_entry_058")

	await walk_via([Vector2(1150, 487), Vector2(1000, 487), Vector2(1000, 410), Vector2(620, 410), Vector2(620, 368)])
	await interact("tide", Vector2(620, 368))
	await shot("coastal_chamber_tide_058")
	await interact("grate", Vector2(715, 425))
	await interact("hatch", Vector2(990, 407))
	await walk_via([Vector2(990, 420), Vector2(188, 410)])
	await interact("west", Vector2(188, 410))
	check(GameState.opening_flags.coastal_chamber_tide_seen and GameState.opening_flags.coastal_chamber_grate_seen and GameState.opening_flags.coastal_chamber_hatch_seen and GameState.opening_flags.coastal_chamber_west_seen, "four physical observations are recorded")
	check(GameState.opening_flags.coastal_chamber_route_verified, "contradictory water and age marks identify the dry route")
	check("左拱道" in scene.hud.objective.text and "鞋印" in scene.hud.defense_notice.text, "route verification points to the physical left arch and explains the evidence")
	await shot("coastal_chamber_route_058")

	await walk_to(Vector2(300, 430))
	var safe_edge: float = scene.player.position.y
	for _i in range(30):
		event_action("move_down", true)
		await get_tree().physics_frame
	event_action("move_down", false)
	await frames(3)
	check(scene.player.position.y < 474.0 and scene.player.position.y > maxf(safe_edge, 450.0), "feet reach the painted sloped sill without entering the pool")
	await walk_via([Vector2(300, 417), Vector2(525, 466), Vector2(569, 505), Vector2(569, 589)])
	await walk_via([Vector2(1050, 587), Vector2(1150, 488), Vector2(1150, 276)])
	await interact("return", Vector2(1150, 276))
	check(scene.transition_active and not scene.player.controls_enabled, "return transition locks controls")
	scene.interact_target("next")
	check(GameState.current_room_id == "ch5_coastal_chamber" and scene.transition_active, "repeated interaction cannot redirect the return transition")
	scene.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(8)
	check(get_tree().paused and scene.hud.panel_open, "focus loss pauses chamber transition")
	scene._close_panel()
	check(not get_tree().paused and not scene.player.controls_enabled and scene.transition_active, "chamber transition retains control lock after resume")
	await get_tree().create_timer(1.0, true).timeout
	scene = get_tree().current_scene
	check(GameState.current_room_id == "ch5_coastal_landing" and scene.ROOM_ID == "ch5_coastal_landing", "right passage returns to the lower platform")
	check(scene.player.position.distance_to(Vector2(1150, 276)) < 5.0, "return entry uses a safe tunnel-side spawn")
	var role_resource_snapshot: Dictionary = GameState.role_resources.duplicate(true)
	role_resource_snapshot[GameState.current_role] = {"stamina": GameState.stamina, "flashlight_battery": GameState.flashlight_battery}
	var payload := {
		"schema_version": OpeningCheckpoint.SCHEMA_VERSION,
		"build_id": "coastal_chamber_058",
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
	check(not OpeningCheckpoint.decode(JSON.stringify(payload), GameState.opening_scope()).is_empty(), "new chamber progression passes checkpoint validation")
	print("COASTAL CHAMBER 058 checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
