extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")


func check(value: bool, label: String) -> void:
	checks += 1
	if value:
		print("PASS " + label)
	else:
		failures += 1
		push_error("FAIL " + label)


func frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame


func run() -> void:
	GameState.prepare_opening_resume()
	var isolated := GameState.profile == "test" and GameState.opening_checkpoint_enabled()
	check(isolated, "new game check uses an isolated persisted test profile")
	if not isolated:
		get_tree().quit(1)
		return
	if "--empty-profile" in OS.get_cmdline_user_args():
		check(GameState.start_new_opening(), "new game works when there is no existing save directory")
		var empty_start := OpeningCheckpoint.load_state(GameState.get_profile_path(), GameState.opening_scope())
		check(empty_start.ok and empty_start.data.room_id == "ch0_hk_work", "first-time player gets a valid opening checkpoint")
		print("NEW GAME EMPTY checks=%d failures=%d" % [checks, failures])
		get_tree().quit(0 if failures == 0 else 1)
		return
	if "--verify-new" in OS.get_cmdline_user_args():
		check(GameState.current_room_id == "ch0_hk_work" and not GameState.opening_flags.ending_truth, "a fresh process resumes the new opening")
		check(not GameState.has_pre_ending_checkpoint(), "a fresh process cannot restore the previous playthrough's decision point")
		check(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(GameState.get_profile_path().path_join("history"))), "previous-save history remains available after restart")
		print("NEW GAME RESTART checks=%d failures=%d" % [checks, failures])
		get_tree().quit(0 if failures == 0 else 1)
		return
	var has_ending_fixture: bool = GameState.opening_flags.ending_truth and GameState.opening_photo != null and GameState.has_pre_ending_checkpoint()
	check(has_ending_fixture, "existing ending, photo and pre-ending checkpoint are loaded")
	if not has_ending_fixture:
		get_tree().quit(1)
		return
	var base: String = GameState.get_profile_path()
	var original := FileAccess.get_file_as_string(base.path_join("opening_checkpoint.json"))
	get_tree().current_scene = null
	reparent(GameState)
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
	await frames(8)
	var menu = get_tree().current_scene
	check(menu.menu.get_child_count() == 4, "menu exposes start, new game, settings and exit")
	if "--capture-new" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var menu_image := get_viewport().get_texture().get_image()
		check(menu_image != null and not menu_image.is_empty() and menu_image.save_png("res://docs/build_reports/main_menu_079.png") == OK, "hidden renderer captures the updated main menu")
	menu.new_button.pressed.emit()
	await frames(3)
	check(is_instance_valid(menu.notice_panel), "new game asks for in-game confirmation")
	if "--capture-new" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var confirmation := get_viewport().get_texture().get_image()
		check(confirmation != null and not confirmation.is_empty() and confirmation.save_png("res://docs/build_reports/new_game_confirmation_079.png") == OK, "hidden renderer captures the backup confirmation")
	menu._cancel_notice()
	await frames(3)
	check(GameState.opening_flags.ending_truth and FileAccess.get_file_as_string(base.path_join("opening_checkpoint.json")) == original, "cancelling leaves the existing save untouched")
	menu.new_button.pressed.emit()
	await frames(3)
	var confirm: Button
	for button in menu.notice_panel.find_children("*", "Button", true, false):
		if button.text == "备份并开始":
			confirm = button
			break
	check(is_instance_valid(confirm), "backup and start button is available")
	if is_instance_valid(confirm):
		confirm.pressed.emit()
		await frames(12)
	check(GameState.current_room_id == "ch0_hk_work" and not GameState.opening_flags.ending_truth, "confirmation starts the Hong Kong opening with cleared ending flags")
	check(not GameState.has_pre_ending_checkpoint(), "new opening cannot restore the previous playthrough's decision point")
	var fresh := OpeningCheckpoint.load_state(base, GameState.opening_scope())
	check(fresh.ok and fresh.data.room_id == "ch0_hk_work" and not fresh.data.flags.photo_taken, "new opening is the active checkpoint")
	var history := DirAccess.open(base.path_join("history"))
	var archived := false
	if history != null:
		history.list_dir_begin()
		var entry := history.get_next()
		while not entry.is_empty():
			if history.current_is_dir() and entry.begins_with("before_new_"):
				var archived_base := base.path_join("history").path_join(entry)
				var saved := OpeningCheckpoint.read_valid(archived_base.path_join("opening_checkpoint.json"), GameState.opening_scope())
				if not saved.is_empty() and saved.flags.ending_truth and saved.flags.photo_taken:
					archived = FileAccess.file_exists(archived_base.path_join("pre_ending_checkpoint.json"))
			entry = history.get_next()
		history.list_dir_end()
	check(archived, "previous ending, photo and pre-ending checkpoint remain together in history")
	print("NEW GAME BACKUP checks=%d failures=%d" % [checks, failures])
	get_tree().paused = false
	get_tree().quit(0 if failures == 0 else 1)
