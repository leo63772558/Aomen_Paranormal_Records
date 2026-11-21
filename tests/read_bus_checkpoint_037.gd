extends SceneTree

var checks := 0
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	failed = failed or not value

func frames(count := 5) -> void:
	for _i in range(count): await process_frame

func run() -> void:
	var state = root.get_node("GameState")
	check(state.profile == "test" and state.opening_checkpoint_enabled(), "explicit_isolated_checkpoint_qa")
	state.prepare_opening_resume()
	check(state.current_room_id == "ch4_bus_loop" and state.current_chapter_id == "ch4_bus33_loop", "independent_process_restores_bus_room")
	for flag in OpeningCheckpoint.BUS_FLAGS:
		check(state.opening_flags[flag], "restored_" + flag)
	for item in ["jiamin_phone", "archive_spare_key", "w17_bus_ticket", "laochen_handoff_note"]:
		check(state.has_demo_item(item), "restored_" + item)
	check(state.opening_photo != null, "natural_start_trip_photo_restores")
	check(state.request_room_change("ch4_bus_loop", state.pending_entry_id), "restored_room_instantiates_through_registry")
	await frames(18)
	var bus = current_scene
	check(bus.stage == 3 and not bus.passenger.visible and not bus.reflection.visible, "resumed_last_round_has_consistent_people_and_reflections")
	check(not bus.hud.panel_open, "resume_does_not_replay_incompatible_first_arrival_intro")
	var data := OpeningCheckpoint.read_valid(state.get_profile_path().path_join("opening_checkpoint.json"), state.opening_scope())
	var invalid := data.duplicate(true)
	invalid.flags.bus_reflection_cleared = false
	check(OpeningCheckpoint.decode(JSON.stringify(invalid), state.opening_scope()).is_empty(), "checkpoint_rejects_skipped_bus_rounds")
	paused = false
	bus.queue_free()
	await frames()
	print("BUS_RESTART_RESULT checks=%d failed=%s" % [checks, str(failed)])
	quit(1 if failed else 0)
