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
	var args := OS.get_cmdline_user_args()
	var ending := ""
	for arg in args:
		if arg.begins_with("--ending-check="):
			ending = arg.trim_prefix("--ending-check=")
	GameState.prepare_opening_resume()
	var fixture_valid := GameState.profile == "test" and GameState.opening_checkpoint_enabled() and GameState.current_room_id == "ch6_abandoned_vip" and ending in ["truth", "escape", "missing"]
	check(fixture_valid, "uses an isolated final-room save and a valid ending argument")
	if not fixture_valid:
		get_tree().quit(1)
		return
	if GameState.opening_flags.photo_taken:
		check(GameState.opening_photo != null and FileAccess.file_exists(GameState.get_profile_path().path_join(GameState.opening_photo_file)), "saved photo is loaded from the active profile")
	if "--verify-restored" in args:
		check(not GameState.opening_flags.ending_missing and not GameState.opening_flags.ending_escape and not GameState.opening_flags.ending_truth, "a new process resumes the restored decision point")
		check(GameState.opening_flags.ch6_jiamin_rescued == (ending != "missing"), "rescue state matches the chosen decision point")
	else:
		var correct_ending: bool = GameState.opening_flags.get("ending_" + ending, false)
		check(correct_ending, "a new process resumes the selected ending")
		if not correct_ending:
			get_tree().quit(1)
			return
		if "--legacy-ending" in args:
			check(not GameState.has_pre_ending_checkpoint(), "old ending starts without a separate checkpoint")
		else:
			check(GameState.has_pre_ending_checkpoint(), "separate pre-ending checkpoint exists")
		get_tree().current_scene = null
		reparent(GameState)
		var changed := GameState.request_room_change(GameState.current_room_id, GameState.pending_entry_id)
		await frames(8)
		var final_scene = get_tree().current_scene
		check(changed and is_instance_valid(final_scene) and final_scene.hud.panel_open, "final scene displays the recorded ending")
		if changed and is_instance_valid(final_scene) and final_scene.hud.panel_open:
			check(GameState.has_pre_ending_checkpoint(), "ending screen offers a valid pre-ending checkpoint")
			final_scene._close_panel()
			var reopen := InputEventAction.new()
			reopen.action = "interact"
			reopen.pressed = true
			Input.parse_input_event(reopen)
			await frames(2)
			check(final_scene.hud.panel_open, "interact reopens the ending if its panel was closed")
			if not final_scene.hud.panel_open:
				get_tree().quit(1)
				return
			while final_scene.hud.page_index < final_scene.hud.pages.size() - 1:
				final_scene.hud.advance()
			await frames(3)
			var buttons_clear := true
			var viewport_rect := get_viewport().get_visible_rect()
			var body_rect: Rect2 = final_scene.hud.panel_body.get_global_rect()
			var footer_rect: Rect2 = final_scene.hud.page_hint.get_global_rect()
			for button in final_scene.hud.choice_buttons:
				var button_rect: Rect2 = button.get_global_rect()
				buttons_clear = buttons_clear and button.visible and viewport_rect.encloses(button_rect) and not button_rect.intersects(body_rect) and not button_rect.intersects(footer_rect)
			check(buttons_clear, "ending choices fit the screen without overlapping body or footer")
			if "--capture-ending" in args:
				await frames(60)
				await RenderingServer.frame_post_draw
				var capture := get_viewport().get_texture().get_image()
				check(capture != null and not capture.is_empty() and capture.save_png("res://docs/build_reports/ending_choices_072_%s.png" % ending) == OK, "hidden render captures the ending choice layout")
			final_scene._retry_pre_ending()
			await frames(8)
			check(not GameState.opening_flags.ending_missing and not GameState.opening_flags.ending_escape and not GameState.opening_flags.ending_truth, "retry clears the ending and returns to the decision state")
			check(GameState.opening_flags.ch6_jiamin_rescued == (ending != "missing"), "retry restores the correct pre-rescue or post-rescue state")
			if GameState.opening_flags.photo_taken:
				check(GameState.opening_photo != null and FileAccess.file_exists(GameState.get_profile_path().path_join(GameState.opening_photo_file)), "saved photo survives retry")
			var stored := OpeningCheckpoint.load_state(GameState.get_profile_path(), GameState.opening_scope())
			check(stored.ok and not stored.data.flags.ending_missing and not stored.data.flags.ending_escape and not stored.data.flags.ending_truth, "retry persists the restored state as the main save")
	print("ENDING RETRY %s checks=%d failures=%d" % [ending, checks, failures])
	get_tree().paused = false
	get_tree().quit(0 if failures == 0 else 1)
