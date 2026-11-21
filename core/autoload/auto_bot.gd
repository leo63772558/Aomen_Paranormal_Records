extends Node

# Scripted regression is opt-in; it never runs in ordinary play.
func _ready() -> void:
	if "--autobot" in OS.get_cmdline_user_args() and GameState.launch_valid:
		call_deferred("_start_regression")

func _start_regression() -> void:
	var opening: bool = "--suite=opening" in OS.get_cmdline_user_args()
	var scene_path := "res://levels/ch0_tanglau/sample_room.tscn"
	var scene = get_tree().current_scene
	if opening:
		GameState.reset_opening()
		GameState.opening_resume_checked = true
		if not GameState.request_room_change("ch0_street", "arrival"):
			push_error("Opening test could not enter the Macau street fixture.")
			get_tree().quit(1)
			return
		await get_tree().process_frame
		await get_tree().process_frame
	elif scene == null or scene.scene_file_path != scene_path:
		get_tree().change_scene_to_file(scene_path)
		await get_tree().process_frame
		await get_tree().process_frame
	var runner = load("res://tests/opening_regression.gd" if opening else "res://tests/sample_regression.gd").new()
	add_child(runner)
