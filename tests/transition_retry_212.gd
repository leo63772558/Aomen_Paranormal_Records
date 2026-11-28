extends Node

var checks := 0
var failures := 0

func _enter_tree() -> void:
	if DisplayServer.get_name() != "headless":
		get_window().set_flag(Window.FLAG_NO_FOCUS, true)
		get_window().position = Vector2i(-32000, -32000)

func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func frames(count := 4) -> void:
	for _i in range(count):
		await get_tree().process_frame

func wait_for_progress(reached: Callable, frame_limit: int) -> bool:
	for _i in range(frame_limit):
		if reached.call():
			return true
		await get_tree().physics_frame
	return reached.call()

func aim_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = Vector2(0, -50)
	get_viewport().push_input(motion, true)

func interact() -> void:
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	Input.parse_input_event(press)
	await frames(2)
	var release := InputEventAction.new()
	release.action = "interact"
	Input.parse_input_event(release)
	await frames(4)

func walk_stair_retry(hall: Node) -> void:
	check("小拱门" in hall.hud.objective.text, "retry points toward the stairs with the recorder already in the bag")
	Input.action_press("move_right")
	var at_arch: bool = await wait_for_progress(func(): return hall.player.position.x >= 456.0, 130)
	Input.action_release("move_right")
	check(at_arch, "walk from the retry spawn to the open arch")
	aim_at(Vector2(460, 106))
	await frames(18)
	check(hall.selected_id == "bunker_deep", "the stair entrance offers its real interaction prompt")
	await interact()
	check(GameState.current_room_id == "ch2_hill_steps", "interact at the arch to restart the stairs")
	if GameState.current_room_id != "ch2_hill_steps":
		return
	var stairs = get_tree().current_scene
	var screen_feet: Vector2 = stairs.player.get_global_transform_with_canvas().origin
	# One mouse movement sets aim. Both traversal directions use the same stationary cursor.
	aim_at(screen_feet + Vector2(0, -116))
	Input.action_press("move_up")
	Input.action_press("sprint")
	var reached_mark: bool = await wait_for_progress(func(): return stairs.steps_reached >= 89 or stairs.phase == stairs.Phase.LOST, 1400)
	Input.action_release("sprint")
	Input.action_release("move_up")
	check(reached_mark and stairs.phase == stairs.Phase.DOWN and stairs.haunt_stage >= 3, "walk through all apparitions to the marked step without turning around")
	if stairs.phase != stairs.Phase.DOWN:
		return
	await interact()
	check(stairs.stair_art.marked, "mark the repeated missing corner through the E prompt")
	Input.action_press("move_up")
	var reached_loop: bool = await wait_for_progress(func(): return stairs.phase != stairs.Phase.DOWN, 170)
	Input.action_release("move_up")
	check(reached_loop and stairs.phase == stairs.Phase.LOOP, "reach the dead-end after marked step 89")
	if stairs.phase != stairs.Phase.LOOP:
		return
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://docs/build_reports/stairs_loop_live_251.png") == OK, "real stair rollback view renders")
	Input.action_press("move_down")
	Input.action_press("sprint")
	var passed_loop: bool = await wait_for_progress(func(): return stairs.phase != stairs.Phase.LOOP, 220)
	check(passed_loop and stairs.phase == stairs.Phase.RETURN and stairs.player.look_dir.dot(Vector2.UP) > 0.9, "stationary cursor keeps the flashlight forward while S breaks the loop")
	check(stairs.family.size() == 1 and stairs.family[0].active, "the live stair wraith pursues the return")
	var reached_door: bool = await wait_for_progress(func(): return stairs._at_machine_room() or stairs.phase == stairs.Phase.LOST, 1410)
	Input.action_release("sprint")
	Input.action_release("move_down")
	await frames(2)
	check(reached_door and stairs._at_machine_room() and stairs.reverse_time == 0.0, "keep the same cursor position all the way to the safe door")
	if not stairs._at_machine_room():
		return
	check("机房门" in stairs.hud.prompt.text, "the machine-room prompt appears in reach")
	Input.action_press("move_up")
	var left_door: bool = await wait_for_progress(func(): return not stairs._at_machine_room(), 70)
	Input.action_release("move_up")
	await frames(2)
	check(left_door and stairs.hud.prompt.text.is_empty(), "the exit prompt disappears out of reach")
	Input.action_press("move_down")
	await wait_for_progress(func(): return stairs._at_machine_room(), 90)
	Input.action_release("move_down")
	await interact()
	check(GameState.current_room_id == "ch2_bunker_hall" and GameState.opening_flags.hill_steps_completed and GameState.has_demo_item("bunker_recording"), "leave by the normal door with the recorder and pursuit completion saved")

func run() -> void:
	check(GameState.profile == "test", "isolated test profile")
	GameState.reset_opening()
	GameState.opening_resume_checked = true
	GameState.current_room_id = "ch0_ah_kin"
	GameState.pending_entry_id = "from_foyer"
	var sequence = load("res://levels/ch0_tanglau/ahhao_sequence_v5.tscn").instantiate()
	get_tree().root.add_child(sequence)
	get_tree().current_scene = sequence
	await frames()
	sequence._close_panel()
	GameState.opening_flags.dawen_304_escape_done = true
	var before_room: String = GameState.current_room_id
	var before_entry: String = GameState.pending_entry_id
	sequence._continue_main("missing_room", "invalid")
	check(GameState.current_room_id == before_room and GameState.pending_entry_id == before_entry, "failed 304 transition keeps room and entry")
	check(sequence.hud.panel_open and get_tree().paused and not sequence.player.controls_enabled, "failed 304 transition presents a retry dialogue")
	check(sequence.after_panel.is_valid() and sequence.after_panel.get_method() == "_continue_main", "304 dialogue retries the normal destination")
	sequence._close_panel()
	await frames(8)
	check(GameState.current_room_id == "ch0_room304" and get_tree().current_scene != sequence, "acknowledging the retry dialogue enters 304 when available")
	get_tree().paused = false
	get_tree().current_scene.queue_free()
	await frames(4)
	GameState.current_room_id = "ch2_bunker_shaft"
	GameState.pending_entry_id = "from_hall"
	GameState.current_chapter_id = "ch2_guia_tunnel"
	GameState.opening_flags.ch2_shaft_demo_seen = true
	var shaft = load("res://levels/ch2_guia/bunker_shaft_084.tscn").instantiate()
	get_tree().root.add_child(shaft)
	get_tree().current_scene = shaft
	await frames()
	shaft.phase = shaft.Phase.LOST
	GameState.demo_pursuit = "shaft_fixture"
	shaft.retry("missing_room", "invalid")
	check(GameState.current_room_id == "ch2_bunker_shaft" and GameState.demo_pursuit == "shaft_fixture", "failed shaft retry keeps room and pursuit state")
	check(shaft.hud.panel_open and get_tree().paused and not shaft.player.controls_enabled, "failed shaft retry presents a paused retry choice")
	check(shaft.hud.choice_buttons.size() == 1 and shaft.hud.choice_buttons[0].text == "再次重试", "shaft retry choice remains available")
	shaft.hud.choice_buttons[0].pressed.emit()
	await frames(8)
	check(GameState.current_room_id == "ch2_bunker_shaft" and GameState.demo_pursuit == "" and get_tree().current_scene != shaft, "retry button reloads the shaft when available")
	get_tree().paused = false
	get_tree().current_scene.queue_free()
	await frames()
	GameState.current_room_id = "ch2_hill_steps"
	GameState.current_chapter_id = "ch2_guia_tunnel"
	GameState.pending_entry_id = "from_hall"
	GameState.demo_pursuit = "steps"
	GameState.take_demo_item("bunker_recording")
	var steps = load("res://levels/ch2_guia/hill_steps_014.tscn").instantiate()
	get_tree().root.add_child(steps)
	get_tree().current_scene = steps
	await frames()
	steps.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(get_tree().paused and steps.hud.panel_open and not steps.player.controls_enabled, "focus loss pauses stair pursuit")
	steps.close_panel()
	check(not get_tree().paused and steps.player.controls_enabled, "stair pursuit resumes after focus pause")
	steps.player.aim_override = true
	steps.player.look_dir = Vector2.UP
	steps.player.position.y = steps.STAIRS.y_at(99) - 2.0
	steps.player.reset_physics_interpolation()
	await frames()
	check(steps.phase == steps.Phase.LOOP and "按住 S" in steps.hud.objective.text and "0 / 10" in steps.hud.state_text.text, "stair loop displays the requested input and rollback progress")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://docs/build_reports/stairs_loop_feedback_251.png") == OK, "stair instructions rendered")
	steps.phase = steps.Phase.LOST
	steps.retry("missing_room")
	check(GameState.current_room_id == "ch2_hill_steps" and GameState.demo_pursuit == "steps", "failed stair retry preserves pursuit state")
	check(get_tree().paused and steps.hud.panel_open and steps.hud.choice_buttons.size() == 1, "failed stair retry offers another attempt")
	steps.hud.choice_buttons[0].pressed.emit()
	await frames(8)
	check(GameState.current_room_id == "ch2_bunker_hall" and GameState.demo_pursuit == "steps", "stair retry returns to the machine room and preserves the recorder route")
	if GameState.current_room_id == "ch2_bunker_hall":
		await walk_stair_retry(get_tree().current_scene)
	get_tree().paused = false
	get_tree().current_scene.queue_free()
	await frames()
	print("TRANSITION RETRY checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
