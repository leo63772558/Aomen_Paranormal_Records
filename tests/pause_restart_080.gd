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


func press_choice(scene: Node, prefix: String) -> bool:
	while scene.hud.page_index < scene.hud.pages.size() - 1:
		scene.hud.advance()
	for button in scene.hud.choice_buttons:
		if button.visible and button.text.begins_with(prefix):
			button.pressed.emit()
			return true
	return false


func run() -> void:
	GameState.prepare_opening_resume()
	var has_bunker_fixture := GameState.profile == "test" and GameState.opening_checkpoint_enabled() and GameState.current_room_id == "ch2_shelter" and GameState.opening_photo != null
	check(has_bunker_fixture, "loads an isolated bunker checkpoint with a photo")
	if not has_bunker_fixture:
		get_tree().quit(1)
		return
	var base: String = GameState.get_profile_path()
	var original := FileAccess.get_file_as_string(base.path_join("opening_checkpoint.json"))
	get_tree().current_scene = null
	reparent(GameState)
	var changed := GameState.request_room_change(GameState.current_room_id, GameState.pending_entry_id)
	await frames(12)
	var scene = get_tree().current_scene
	check(changed and is_instance_valid(scene) and is_instance_valid(scene.hud), "bunker room loads from its checkpoint")
	if changed and is_instance_valid(scene) and is_instance_valid(scene.hud):
		if scene.hud.panel_open:
			scene.close_dialog(false)
		scene.pause_menu()
		check(press_choice(scene, "重玩开场"), "pause menu opens the restart confirmation")
		check(scene.hud.panel_open and scene.hud.choice_buttons.size() == 2, "restart requires an explicit in-game choice")
		check(press_choice(scene, "取消"), "confirmation can be cancelled")
		check(GameState.current_room_id == "ch2_shelter" and FileAccess.get_file_as_string(base.path_join("opening_checkpoint.json")) == original, "cancelling keeps the current bunker save")
		check(press_choice(scene, "重玩开场"), "restart confirmation can be reopened")
		check(press_choice(scene, "备份并重玩"), "confirmed restart uses the backup path")
		await frames(12)
		check(GameState.current_room_id == "ch0_hk_work" and not GameState.opening_flags.bunker_key_2, "confirmed restart enters a fresh opening")
	var history := DirAccess.open(base.path_join("history"))
	var archived := false
	if history != null:
		history.list_dir_begin()
		var entry := history.get_next()
		while not entry.is_empty():
			if history.current_is_dir() and entry.begins_with("before_new_"):
				var old := OpeningCheckpoint.read_valid(base.path_join("history").path_join(entry).path_join("opening_checkpoint.json"), GameState.opening_scope())
				archived = archived or (not old.is_empty() and old.room_id == "ch2_shelter" and old.flags.bunker_key_2)
			entry = history.get_next()
		history.list_dir_end()
	check(archived, "previous bunker state and its photo are retained in history")
	print("PAUSE RESTART checks=%d failures=%d" % [checks, failures])
	get_tree().paused = false
	get_tree().quit(0 if failures == 0 else 1)
