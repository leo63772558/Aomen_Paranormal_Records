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
	check(GameState.current_room_id == "ch2_bunker_ammo" and GameState.demo_pursuit == "", "stair retry returns to the correct safe room")
	get_tree().paused = false
	get_tree().current_scene.queue_free()
	await frames()
	print("TRANSITION RETRY checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
