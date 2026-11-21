extends SceneTree

var checks := 0
var failed := false

func _initialize() -> void:
	call_deferred("run")

func frames(n := 5) -> void:
	for _i in range(n): await process_frame

func check(value: bool, label: String) -> void:
	checks += 1
	failed = failed or not value
	print(("PASS " if value else "FAIL ") + label)

func run() -> void:
	var state = root.get_node("GameState")
	check(state.profile == "test" and state.opening_checkpoint_enabled(), "explicit_isolated_read")
	state.prepare_opening_resume()
	check(state.current_room_id == "ch5_hacsa_beach", "independent_process_restores_beach")
	check(state.current_role == "dawen" and state.opening_flags.ah_hao_dead and state.opening_flags.dawen_304_escape_done, "role_and_ahhao_history_restored")
	check(state.bus_loop_state.successes == 5 and state.opening_flags.bus_arrived, "random_loop_completion_restored")
	check(state.opening_flags.beach_footprints_solved and state.has_demo_item("shoe_repair_photo"), "overlap_inference_and_original_shoe_photo_restored")
	for item in ["jiamin_phone", "archive_spare_key", "w17_bus_ticket", "laochen_handoff_note"]:
		check(state.has_demo_item(item), "evidence_" + item)
	check(state.opening_photo != null, "actual_trip_photo_restored")
	var data := OpeningCheckpoint.read_valid(state.get_profile_path().path_join("opening_checkpoint.json"), state.opening_scope())
	check(not data.is_empty(), "checkpoint_decodes")
	var invalid := data.duplicate(true)
	invalid.bus_loop_state.successes = 4
	check(OpeningCheckpoint.decode(JSON.stringify(invalid), state.opening_scope()).is_empty(), "beach_cannot_skip_fifth_bus_judgment")
	invalid = data.duplicate(true)
	invalid.role_resources.dawen.stamina += 1.0
	check(OpeningCheckpoint.decode(JSON.stringify(invalid), state.opening_scope()).is_empty(), "active_role_resources_must_match")
	invalid = data.duplicate(true)
	invalid.flags.ah_hao_escaped = false
	check(OpeningCheckpoint.decode(JSON.stringify(invalid), state.opening_scope()).is_empty(), "death_history_cannot_skip_first_escape")
	var before: Dictionary = state.opening_flags.duplicate(true)
	var battery: float = state.flashlight_battery
	state.begin_preview()
	check(not state.opening_checkpoint_enabled() and not state.opening_flags.ah_hao_dead, "preview_isolated_and_not_writing_formal_save")
	state.enter_role("ah_hao")
	state.flashlight_battery = 11.0
	state.end_preview()
	check(state.current_role == "dawen" and state.current_room_id == "ch5_hacsa_beach" and state.opening_flags == before and state.flashlight_battery == battery, "return_from_preview_restores_formal_state")
	check(state.request_room_change(state.current_room_id, state.pending_entry_id), "resumed_room_loads_through_registry")
	await frames(16)
	check(not current_scene.hud.panel_open, "resume_does_not_replay_initial_crash")
	paused = false
	current_scene.queue_free()
	await frames(8)
	OS.delay_msec(100)
	await frames(3)
	print("STORY V5 RESTART %d checks failed=%s" % [checks, failed])
	quit(1 if failed else 0)
