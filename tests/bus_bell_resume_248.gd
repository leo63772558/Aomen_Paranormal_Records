extends Node

var scene
var checks := 0
var failures := 0
const DRAWN_ANOMALIES := ["driver_mirror", "blood_coinbox", "window_hands", "mannequin_turn"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func frames(count := 4) -> void:
	for _i in range(count): await get_tree().process_frame

func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures += 1

func tap_interact() -> void:
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventAction.new()
	event.action = "interact"
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)

func run() -> void:
	if GameState.profile != "test" or not GameState.opening_checkpoint_enabled():
		push_error("isolated persistent profile required")
		get_tree().quit(1)
		return
	var read_mode := "--read" in OS.get_cmdline_user_args()
	if read_mode:
		GameState.prepare_opening_resume()
		check(GameState.bus_loop_state.anomaly == "window_hands" and GameState.bus_loop_state.bell_pulled and GameState.bus_loop_state.successes == 2, "fresh process loads same anomaly, bell and progress")
	else:
		GameState.reset_opening()
		GameState.opening_resume_checked = true
		GameState.current_room_id = "ch4_bus_loop"
		GameState.pending_entry_id = "loop_start"
	scene = load("res://levels/ch4_bus/bus_loop.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await frames(12)
	if scene.hud.panel_open: scene._on_hud_close()
	if read_mode:
		check(scene.current_anomaly == "window_hands" and scene.bell_pulled and scene.success_counter == 2, "bus restores exact round without reroll")
		check(scene.seen_anomalies == DRAWN_ANOMALIES, "fresh process restores the used cards in the current draw")
		scene.player.position = Vector2(90, 283)
		scene.player.clear_motion()
		await frames(8)
		check("后门" in scene.hud.prompt.text, "rear door can be selected after restore")
		await tap_interact()
		check(scene.success_counter == 3 and scene.next_cycle_pending, "real E at rear door commits exactly one correct judgment")
		await get_tree().create_timer(1.3, true).timeout
		if scene.current_anomaly.is_empty():
			scene.trigger_action("front_door")
			await get_tree().create_timer(1.3, true).timeout
		check(scene.current_anomaly == "stop_screen", "the next anomalous round uses the one remaining card")
		scene._restart_loop()
		check(scene.seen_anomalies.is_empty() and scene.current_anomaly.is_empty(), "manual chapter restart clears the draw and starts with a normal reference")
	else:
		scene.force_cycle("window_hands")
		scene.success_counter = 2
		scene.seen_anomalies.assign(DRAWN_ANOMALIES)
		scene.player.position = Vector2(222, 282)
		scene.player.clear_motion()
		await frames(8)
		check("停车铃" in scene.hud.prompt.text, "bell can be selected")
		await tap_interact()
		check(scene.bell_pulled and scene.success_counter == 2, "real E pulls bell without counting the round")
		var saved := OpeningCheckpoint.load_state(GameState.get_profile_path(), GameState.opening_scope())
		check(saved.ok and saved.data.bus_loop_state.bell_pulled and saved.data.bus_loop_state.anomaly == "window_hands", "bell and anomaly are written to disk")
		if saved.ok:
			var older: Dictionary = saved.data.duplicate(true)
			older.bus_loop_state.erase("seen_anomalies")
			var migrated := OpeningCheckpoint.decode(JSON.stringify(older), GameState.opening_scope())
			check(not migrated.is_empty() and migrated.bus_loop_state.seen_anomalies == ["window_hands"], "old saves reconstruct the current draw entry")
			older.bus_loop_state.seen_anomalies = ["window_hands", "window_hands"]
			check(OpeningCheckpoint.decode(JSON.stringify(older), GameState.opening_scope()).is_empty(), "checkpoint rejects duplicate draw history")
		scene._on_hud_pause()
		var return_button: Button
		for button in scene.hud.choice_buttons:
			if button.text == "保存进度并返回标题":
				return_button = button
		check(is_instance_valid(return_button), "pause provides a save-and-return action")
		if is_instance_valid(return_button):
			GameState.opening_flags.photo_taken = true
			return_button.pressed.emit()
			check(get_tree().paused and scene.hud.panel_body.visible and "暂时无法保存" in scene.hud.panel_body.text, "failed save keeps the bus paused with a readable error")
			GameState.opening_flags.photo_taken = false
			for button in scene.hud.choice_buttons:
				if button.text == "保存进度并返回标题":
					button.pressed.emit()
					break
			await frames(8)
			check(not get_tree().paused and get_tree().current_scene.scene_file_path == "res://ui/main_menu.tscn", "retry saves and returns to the title")
	print("BUS BELL RESUME checks=%d failures=%d" % [checks, failures])
	get_tree().paused = false
	if is_instance_valid(scene):
		scene.queue_free()
	await frames(8)
	OS.delay_msec(100)
	get_tree().quit(1 if failures else 0)
