extends SceneTree


func _initialize() -> void:
	call_deferred("verify_restart")


func verify_restart() -> void:
	var state := root.get_node("GameState")
	state.prepare_opening_resume()
	var result := OpeningCheckpoint.load_state(state.get_profile_path(), state.opening_scope())
	var data: Dictionary = result.get("data", {})
	var flags: Dictionary = data.get("flags", {})
	var passed: bool = result.get("ok", false) and data.get("room_id", "") == "ch6_abandoned_vip" and flags.get("ch6_jiamin_rescued", false) and flags.get("ending_truth", false)
	print("RESTART_VERIFY ok=", result.get("ok", false), " room=", data.get("room_id", ""), " rescued=", flags.get("ch6_jiamin_rescued", false), " truth=", flags.get("ending_truth", false), " pass=", passed)
	quit(0 if passed else 1)
