extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state = root.get_node("GameState")
	if state.profile != "test" or not state.opening_checkpoint_enabled():
		quit(2)
		return
	state.prepare_opening_resume()
	var restored: bool = state.current_room_id == "ch2_shelter" and state.pending_entry_id == "from_descent"
	restored = restored and state.opening_flags.demo_case_closed and state.opening_flags.ammo_chase_cleared
	restored = restored and state.opening_flags.bunker_gate_unlocked and state.demo_pursuit.is_empty()
	for id in ["trip_map", "old_304_photo", "jiamin_phone", "service_handle", "bunker_recording"]:
		restored = restored and state.has_demo_item(id)
	restored = restored and state.opening_photo != null
	print(("PASS" if restored else "FAIL") + " 独立进程恢复洞外结语、已开铁门、背包和旅行照")
	quit(0 if restored else 1)
