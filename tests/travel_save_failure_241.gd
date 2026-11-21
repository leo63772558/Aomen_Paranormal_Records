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
	var scene = load("res://levels/ch0_tanglau/hk_work_026.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	var saved := GameState.save_opening_checkpoint()
	var path := GameState.get_profile_path().path_join("opening_checkpoint.json")
	var old := FileAccess.get_file_as_bytes(path)
	GameState.opening_flags.photo_taken = true
	GameState.opening_photo = null
	GameState.opening_photo_file = ""
	scene.interact_intro("bench")
	var ok: bool = saved and not old.is_empty() and GameState.opening_flags.intro_job_done and "保存失败" in scene.hud.defense_notice.text and FileAccess.get_file_as_bytes(path) == old
	scene._close()
	ok = ok and scene.player.controls_enabled and not get_tree().paused
	print("TRAVEL SAVE FAILURE " + ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
