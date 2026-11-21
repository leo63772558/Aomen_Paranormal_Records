extends Node

var failures := 0

func _enter_tree() -> void:
	get_window().set_flag(Window.FLAG_NO_FOCUS, true)
	get_window().position = Vector2i(-32000, -32000)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures += 1

func frames(count: int) -> void:
	for i in range(count): await get_tree().process_frame

func run() -> void:
	if "--verify-photo" in OS.get_cmdline_user_args():
		GameState.prepare_opening_resume()
		check(GameState.opening_flags.photo_taken and GameState.opening_photo != null, "a new process restores the captured photo")
		check(not GameState.opening_photo_file.is_empty() and FileAccess.file_exists(GameState.get_profile_path().path_join(GameState.opening_photo_file)), "captured image exists in the isolated save")
		if GameState.opening_photo != null:
			check(GameState.opening_photo.get_width() > 16 and GameState.opening_photo.get_height() > 16, "restored photo contains rendered pixels")
		print("PHOTO RELOAD failures=", failures)
		get_tree().quit(0 if failures == 0 else 1)
		return
	if DisplayServer.get_name() == "headless":
		get_tree().quit(2)
		return
	GameState.reset_opening()
	GameState.opening_resume_checked = true
	GameState.current_room_id = "ch0_street"
	GameState.pending_entry_id = "arrival"
	var scene = preload("res://levels/ch0_tanglau/opening_street.tscn").instantiate()
	add_child(scene)
	await frames(10)
	if scene.hud.panel_open: scene.close_dialog(false)
	scene.start_camera()
	scene.camera_view.center = Vector2(405, 201)
	await frames(4)
	check(scene.photo_is_valid(), "photo framing is valid")
	scene.take_photo()
	scene.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(8)
	check(not GameState.opening_flags.photo_taken, "focus loss cancels pending exposure")
	check(scene.hud.root.visible and scene.hud.panel_open and get_tree().paused, "focus loss leaves a visible paused menu")
	scene.close_dialog(false)
	scene.start_camera()
	scene.camera_view.center = Vector2(405, 201)
	scene.take_photo()
	scene.stop_camera()
	scene.start_camera()
	scene.camera_view.center = Vector2(405, 201)
	await frames(4)
	check(not GameState.opening_flags.photo_taken and scene.camera_active, "cancelled exposure cannot complete after the camera reopens")
	scene.take_photo()
	await frames(8)
	check(GameState.opening_flags.photo_taken and GameState.opening_photo != null, "normal capture works after resume")
	if GameState.opening_checkpoint_enabled():
		check(not GameState.opening_photo_file.is_empty() and FileAccess.file_exists(GameState.get_profile_path().path_join(GameState.opening_photo_file)), "normal capture writes an actual isolated photo file")
	print("PHOTO FOCUS failures=", failures)
	get_tree().paused = false
	get_tree().quit(0 if failures == 0 else 1)
