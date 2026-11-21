extends Node

var failures := 0
var checks := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")


func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1


func frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame


func run() -> void:
	var writing := "--write-support" in OS.get_cmdline_user_args()
	if writing:
		var fixture := preload("res://tests/ch6_rescue_061.gd").new()
		fixture._prepare_state()
		fixture.free()
		for flag in ["ch6_jiamin_pipe_found", "ch6_signal_sent", "ch6_route_diagram_seen", "ch6_live_signal_received", "ch6_pipe_route_verified", "ch6_circuit_isolated", "ch6_entity_lured", "ch6_entity_bound"]:
			GameState.opening_flags[flag] = true
	else:
		GameState.prepare_opening_resume()
		check(GameState.opening_flags.ch6_rescue_door_open and not GameState.opening_flags.ch6_jiamin_rescued, "fresh process restores the open hatch before the interrupted rescue")
	var scene := preload("res://levels/ch6_abandoned_vip/abandoned_vip_rescue_061.tscn").instantiate()
	add_child(scene)
	await frames(5)
	if scene.hud.panel_open:
		scene._close_panel()
	scene.player.position = Vector2(1112, 335)
	scene._open_rescue_door()
	for _i in range(200):
		await frames(1)
		if is_instance_valid(scene.rescue_support):
			break
	check(is_instance_valid(scene.rescue_support) and scene.scene_action_active, "actual support action starts")
	if writing:
		scene._pause_menu()
		scene.checkpoint()
		var saved := OpeningCheckpoint.load_state(GameState.get_profile_path(), GameState.opening_scope())
		check(saved.ok and saved.data.flags.ch6_rescue_door_open and not saved.data.flags.ch6_jiamin_rescued and not saved.data.flags.pre_ending_checkpoint, "saving during paused support persists only the completed open hatch")
	else:
		# The camera handoff now follows the support animation before reunion.
		# Wait for the player-visible result with a bounded timeout.
		for _i in range(360):
			if scene.hud.panel_open and GameState.opening_flags.ch6_jiamin_rescued:
				break
			await frames(1)
		check(GameState.opening_flags.ch6_jiamin_rescued and GameState.opening_flags.pre_ending_checkpoint and scene.hud.panel_open, "resuming support completes rescue and shows reunion")
		check(not GameState.has_demo_item("ahhao_camera") or GameState.opening_flags.ch6_ahhao_camera_handed, "camera handoff completes before the reunion dialogue")
		var saved := OpeningCheckpoint.load_state(GameState.get_profile_path(), GameState.opening_scope())
		check(saved.ok and saved.data.flags.ch6_jiamin_rescued and saved.data.flags.pre_ending_checkpoint, "completed support is persisted")
	print("RESCUE_SUPPORT_RESUME_095 checks=%d failures=%d" % [checks, failures])
	get_tree().paused = false
	get_tree().quit(0 if failures == 0 else 1)
