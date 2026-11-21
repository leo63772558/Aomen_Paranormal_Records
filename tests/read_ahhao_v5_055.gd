extends SceneTree
var checks := 0
var failed := false
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	failed = failed or not value
	print(("PASS " if value else "FAIL ") + label)
func run() -> void:
	var state = root.get_node("GameState")
	state.prepare_opening_resume()
	check(state.profile == "test" and state.current_room_id == "ch0_ah_kin", "independent_process_restores_ahhao_room")
	check(state.current_role == "ah_hao" and state.opening_flags.ah_hao_breaker_done and not state.opening_flags.ah_hao_escaped, "mid_chase_role_and_breaker_saved")
	check(state.role_resources.has("dawen") and state.role_resources.has("ah_hao"), "separate_role_resources_present")
	check(state.request_room_change(state.current_room_id, state.pending_entry_id), "role_scene_loads_through_registry")
	for _i in range(15): await process_frame
	check(current_scene.hud.panel_open and paused and not current_scene.player.controls_enabled, "resume_paused_at_safe_prepare_panel")
	check(current_scene.player.appearance == "ah_hao" and not is_instance_valid(current_scene.monster), "correct_actor_without_unprepared_attack")
	paused = false
	current_scene.queue_free()
	for _i in range(8): await process_frame
	OS.delay_msec(100)
	print("AHHAO RESTART %d checks failed=%s" % [checks, failed])
	quit(1 if failed else 0)
