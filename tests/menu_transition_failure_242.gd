extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func run() -> void:
	if GameState.profile != "test" or not GameState.opening_checkpoint_enabled():
		push_error("isolated persistent profile required")
		get_tree().quit(1)
		return
	GameState.reset_opening()
	GameState.opening_resume_checked = true
	var path := GameState.get_profile_path().path_join("opening_checkpoint.json")
	var old := FileAccess.get_file_as_bytes(path)
	GameState.opening_flags.photo_taken = true
	GameState.opening_photo = null
	GameState.opening_photo_file = ""
	reparent(GameState)
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
	for i in range(5): await get_tree().process_frame
	var menu = get_tree().current_scene
	menu._proceed()
	for i in range(12): await get_tree().process_frame
	var room = get_tree().current_scene
	var ok: bool = GameState.current_room_id == "ch0_hk_work" and is_instance_valid(room.hud) and "保存失败" in room.hud.defense_notice.text and FileAccess.get_file_as_bytes(path) == old
	print("MENU TRANSITION SAVE FAILURE " + ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
