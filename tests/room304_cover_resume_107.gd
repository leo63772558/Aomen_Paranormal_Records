extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for _i in range(count):
		await get_tree().physics_frame


func tap(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(2)
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(2)


func run() -> void:
	var action_phase := "--action-phase" in OS.get_cmdline_user_args()
	GameState.reset_opening()
	GameState.opening_resume_checked = true
	GameState.current_chapter_id = "ch0_tanglau"
	GameState.current_room_id = "ch0_room304"
	GameState.pending_entry_id = "from_corridor"
	for flag in ["photo_taken", "pastry_shared", "knock_agreed", "entered_foyer", "meter_cover_open", "floor3_power", "jiamin_phone_found", "old_photo_seen", "room_bed_moved", "room_phone_answered"]:
		GameState.opening_flags[flag] = true
	GameState.opening_switches.B = true
	GameState.opening_photo = ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	GameState.take_demo_item("jiamin_phone")
	check(GameState.profile == "test" and GameState.save_opening_checkpoint(), "fixture writes to an isolated test save")
	var scene := preload("res://levels/ch0_tanglau/room304.tscn").instantiate()
	scene.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(scene)
	await frames(5)
	scene.player.aim_override = true
	scene.player.position = Vector2(520, 211)
	scene.player.look_dir = Vector2.UP
	await frames(5)
	check(scene.selected_id == "vent304", "ordinary facing selects the actual vent interaction")
	await tap("interact")
	check(scene.hud.panel_open, "interact opens the cover choices")
	var choice: Button
	for node in scene.hud.panel_content.get_children():
		if node is Button and node.visible and node.text.begins_with("用工具钳拆盖"):
			choice = node
	check(is_instance_valid(choice), "the normal tool choice is available")
	if not is_instance_valid(choice):
		get_tree().paused = false
		get_tree().quit(1)
		return
	choice.pressed.emit()
	await frames(30 if action_phase else 2)
	check(scene.work_in_progress and is_instance_valid(scene.vent_work_pose) == action_phase, "the requested approach or tool-action phase is active")
	await tap("pause")
	var frozen_position: Vector2 = scene.player.position
	var frozen_texture: Texture2D = scene.vent_work_pose.texture if action_phase and is_instance_valid(scene.vent_work_pose) else null
	await frames(35)
	check(get_tree().paused and scene.player.position.is_equal_approx(frozen_position) and not GameState.opening_flags.room_cover_open, "Esc freezes the action without prematurely committing")
	check(not action_phase or (is_instance_valid(scene.vent_work_pose) and scene.vent_work_pose.texture == frozen_texture), "tool pose stays frozen during pause")
	await tap("pause")
	check(not get_tree().paused and scene.work_in_progress and not scene.player.controls_enabled, "Esc resumes the same action while player input remains locked")
	for _i in range(180):
		if GameState.opening_flags.room_cover_open:
			break
		await frames(1)
	await frames(3)
	check(GameState.opening_flags.room_cover_open and scene.hud.panel_open and not scene.work_in_progress, "the resumed action completes and shows the result panel")
	check(scene.room_hatch.visible and not scene.room_vent.visible and not is_instance_valid(scene.room_aperture) and not is_instance_valid(scene.room_aperture_shadow), "completed opening removes both collision and light blocker")
	var saved := OpeningCheckpoint.load_state(GameState.get_profile_path(), GameState.opening_scope())
	check(saved.ok and saved.data.flags.room_cover_open, "completed opening is saved to the test profile")
	await tap("pause")
	check(not scene.hud.panel_open and scene.player.controls_enabled, "closing the result restores player control")
	scene.player.position = Vector2(520, 205)
	scene.player.clear_motion()
	Input.action_press("move_up")
	await frames(60)
	Input.action_release("move_up")
	scene.player.clear_motion()
	check(scene.player.position.y < 175.0, "actual movement passes the former cover collision")
	print("COVER_RESUME_107 phase=%s checks=%d failures=%d" % ["action" if action_phase else "approach", checks, failures])
	get_tree().paused = false
	get_tree().quit(0 if failures == 0 else 1)
