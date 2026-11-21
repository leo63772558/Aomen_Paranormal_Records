extends Node

var scene
var failed := false
var checks := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	print(("PASS " if condition else "FAIL ") + message)
	failed = failed or not condition

func frames(count := 5) -> void:
	for i in range(count):
		await get_tree().process_frame

func walk(target: Vector2) -> void:
	var actor = scene.player
	actor.aim_override = true
	for i in range(1000):
		var d: Vector2 = target - actor.position
		if d.length() < 4.0:
			break
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_release("move_up")
		Input.action_release("move_down")
		if d.x < -3: Input.action_press("move_left")
		if d.x > 3: Input.action_press("move_right")
		if d.y < -3: Input.action_press("move_up")
		if d.y > 3: Input.action_press("move_down")
		await get_tree().physics_frame
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	actor.clear_motion()
	check(actor.position.distance_to(target) < 8.0, "walk reaches " + str(target))

func tap(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await frames(3)

func run() -> void:
	if GameState.profile != "test" or not GameState.opening_checkpoint_enabled():
		push_error("isolated persistent profile required")
		get_tree().quit(1)
		return
	if "--resume" in OS.get_cmdline_user_args():
		GameState.prepare_opening_resume()
		check(GameState.current_room_id == "ch3_quiet_passage" and GameState.pending_entry_id == "from_archive", "independent process restores passage and entry")
		if not failed:
			scene = load("res://levels/ch3_amparo_alley/quiet_passage.tscn").instantiate()
			get_tree().root.add_child(scene)
			get_tree().current_scene = scene
			await frames(8)
			check(scene.player.position.distance_to(Vector2(105, 220)) < 1.0 and scene.player.controls_enabled, "restored passage starts in a safe controllable place")
		print("QUIET PASSAGE RESUME checks=%d failed=%s" % [checks, failed])
		get_tree().quit(1 if failed else 0)
		return
	GameState.reset_opening()
	GameState.opening_resume_checked = true
	GameState.current_room_id = "ch3_quiet_passage"
	GameState.current_chapter_id = "ch3_amparo_alley"
	GameState.pending_entry_id = "from_archive"
	for flag in ["jiamin_phone_found", "ammo_chase_cleared", "demo_case_closed", "ch3_intro_seen", "ch3_balance_rule_seen", "ch3_cold_door_seen", "ch3_balance_solved", "ch3_key_found", "ch3_ticket_found", "ch3_cold_door_open"]:
		GameState.opening_flags[flag] = true
	for item in ["jiamin_phone", "bunker_recording", "archive_spare_key", "w17_bus_ticket", "laochen_handoff_note"]:
		GameState.opening_items[item] = 1
	scene = load("res://levels/ch3_amparo_alley/quiet_passage.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await frames(10)
	var saved := OpeningCheckpoint.load_state(GameState.get_profile_path(), GameState.opening_scope())
	check(saved.ok and saved.data.room_id == "ch3_quiet_passage", "passage entry saves a valid isolated checkpoint")
	if "--entry-failure" in OS.get_cmdline_user_args():
		var checkpoint_path := GameState.get_profile_path().path_join("opening_checkpoint.json")
		var previous_checkpoint := FileAccess.get_file_as_bytes(checkpoint_path)
		GameState.opening_flags.photo_taken = true
		GameState.opening_photo = null
		GameState.opening_photo_file = ""
		scene.queue_free()
		await frames(2)
		scene = load("res://levels/ch3_amparo_alley/quiet_passage.tscn").instantiate()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		await frames(5)
		check("保存失败" in scene.hud.defense_notice.text, "entry save failure is visible")
		check(scene.player.controls_enabled, "entry save failure does not block movement")
		check(FileAccess.get_file_as_bytes(checkpoint_path) == previous_checkpoint, "entry save failure preserves previous checkpoint")
		print("QUIET PASSAGE ENTRY FAILURE checks=%d failed=%s" % [checks, failed])
		get_tree().quit(1 if failed else 0)
		return
	if "--write-only" in OS.get_cmdline_user_args():
		print("QUIET PASSAGE WRITE checks=%d failed=%s" % [checks, failed])
		get_tree().quit(1 if failed else 0)
		return
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		check(image.save_png("res://docs/build_reports/quiet_passage_169.png") == OK, "passage rendered")
	check(scene.find_children("*", "StaticBody2D", true, false).size() >= 7, "walls and painted solid objects have collision")
	var actor_position: Vector2 = scene.player.global_position
	EventBus.noise_emitted.emit(actor_position + Vector2(300, 0), 650.0, "shaft_bucket_084")
	check(scene.hud.recent_noise.is_empty(), "meter ignores distant world sounds")
	EventBus.noise_emitted.emit(actor_position, 16.0, "footstep")
	await tap("phone")
	check(scene.hud.panel_open and scene.hud.default_phone_widget != null and get_tree().paused and not scene.player.controls_enabled, "phone key opens offline phone and pauses passage")
	if is_instance_valid(scene.hud.default_phone_widget):
		var phone: Control = scene.hud.default_phone_widget
		(phone.get_node("NoiseMeter") as Button).pressed.emit()
		check(is_instance_valid(phone.meter_cover) and phone.recent_noise == PackedStringArray(["脚步　1 / 5"]), "phone meter shows the latest nearby event")
		EventBus.noise_emitted.emit(actor_position, 140.0, "footstep")
		check(scene.hud.recent_noise == phone.recent_noise, "open meter freezes sound history with the world")
		var toggle := phone.meter_cover.find_child("LiveNoise", true, false) as CheckButton
		toggle.button_pressed = true
		await tap("phone")
		check(scene.hud.panel_open and get_tree().paused and not is_instance_valid(phone.meter_cover), "first phone key returns from meter to offline phone")
		scene.hud.default_phone_widget._show_shoe_photo()
		await tap("pause")
		check(scene.hud.panel_open and get_tree().paused and not is_instance_valid(scene.hud.default_phone_widget.photo_cover), "first return closes the photo while keeping the phone open")
		scene.hud.default_phone_widget.map_requested.emit()
		await frames()
		check(scene.hud.panel_open and get_tree().paused and scene.hud.default_phone_widget.get_script() == preload("res://ui/demo_travel_map.gd"), "phone map opens in a single paused widget")
		await tap("phone")
		check(not scene.hud.panel_open and not get_tree().paused, "return from phone map resumes the passage")
		await tap("phone")
		scene.hud.default_phone_widget.bag_requested.emit()
		await frames()
		check(scene.hud.default_phone_widget is Control and get_tree().paused, "phone bag button opens a single paused widget")
	await tap("phone")
	check(not scene.hud.panel_open and not get_tree().paused and scene.player.controls_enabled, "phone key closes widget without opening world interaction")
	await walk(Vector2(150, 210))
	check(scene.hud.live_noise_notice.visible and "脚步" in scene.hud.live_noise_notice.text, "actual player movement triggers the enabled field meter")
	await tap("phone")
	var reopened_phone: Control = scene.hud.default_phone_widget
	(reopened_phone.get_node("NoiseMeter") as Button).pressed.emit()
	var meter_toggle := reopened_phone.meter_cover.find_child("LiveNoise", true, false) as CheckButton
	check(meter_toggle.button_pressed and reopened_phone.recent_noise.size() <= 4, "reopened meter retains its toggle and a bounded recent history")
	meter_toggle.button_pressed = false
	await tap("pause")
	await tap("phone")
	check(not scene.hud.live_noise_notice.visible and not scene.hud.live_noise_enabled, "turning off the meter removes its world readout")
	Input.action_press("move_up")
	for i in range(40):
		await get_tree().physics_frame
	Input.action_release("move_up")
	check(scene.player.position.y >= 165.0, "painted bins and baskets block the player")
	await tap("inventory")
	check(scene.hud.panel_open and get_tree().paused and not scene.player.controls_enabled, "inventory pauses movement in the passage")
	await tap("pause")
	check(not scene.hud.panel_open and not get_tree().paused and scene.player.controls_enabled, "closing inventory restores movement without world interaction")
	await walk(Vector2(105, 205))
	scene.player.look_dir = (scene.TARGETS.archive - scene.player.position).normalized()
	await frames()
	check(scene.selected_id == "archive", "return doorway is approachable and selectable")
	var checkpoint_path := GameState.get_profile_path().path_join("opening_checkpoint.json")
	var previous_checkpoint := FileAccess.get_file_as_bytes(checkpoint_path)
	var old_photo_flag: bool = GameState.opening_flags.photo_taken
	var old_photo = GameState.opening_photo
	var old_photo_file: String = GameState.opening_photo_file
	GameState.opening_flags.photo_taken = true
	GameState.opening_photo = null
	GameState.opening_photo_file = ""
	await tap("interact")
	await frames(12)
	check(GameState.current_room_id == "ch3_amparo_archive" and GameState.pending_entry_id == "from_passage", "returns to archive with a safe entry")
	scene = get_tree().current_scene
	await frames(10)
	check("保存失败" in scene.hud.defense_notice.text, "failed passage transition is reported in the archive")
	check(FileAccess.get_file_as_bytes(checkpoint_path) == previous_checkpoint, "failed passage transition preserves previous checkpoint")
	GameState.opening_flags.photo_taken = old_photo_flag
	GameState.opening_photo = old_photo
	GameState.opening_photo_file = old_photo_file
	check(scene.player.position.y > 36.0 and not scene.departing_to_bus, "return spawn does not immediately retrigger departure")
	Input.action_press("move_up")
	for i in range(100):
		if scene.hud.panel_open: break
		await get_tree().physics_frame
	Input.action_release("move_up")
	check(scene.hud.panel_open, "ordinary movement reopens the archive departure")
	scene.close_dialog()
	await frames(12)
	scene = get_tree().current_scene
	check(GameState.current_room_id == "ch3_quiet_passage", "archive leads back to passage")
	await walk(Vector2(565, 205))
	scene.player.look_dir = (scene.TARGETS.street - scene.player.position).normalized()
	await frames()
	check(scene.selected_id == "street", "street exit is approachable and selectable")
	await tap("interact")
	check(scene.hud.panel_open and scene.hud.choice_buttons.size() == 2, "street exit provides departure and stay choices")
	scene._close_panel()
	check(not get_tree().paused and scene.player.controls_enabled, "stay restores movement")
	await tap("interact")
	scene._enter_bus()
	await frames(5)
	check(scene.leaving and not scene.player.controls_enabled and GameState.current_room_id == "ch3_quiet_passage", "station transition runs before loading the bus and locks interaction")
	scene.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(8)
	check(get_tree().paused and scene.hud.panel_open and scene.leaving, "focus loss pauses the station transition")
	scene._close_panel()
	check(not get_tree().paused and not scene.player.controls_enabled and scene.leaving, "resumed station transition keeps movement locked")
	await frames(60)
	check(GameState.current_room_id == "ch4_bus_loop", "street route reaches the formal bus")
	print("QUIET PASSAGE checks=%d failed=%s" % [checks, failed])
	get_tree().paused = false
	get_tree().quit(1 if failed else 0)
