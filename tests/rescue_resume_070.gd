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
	for _index in range(count):
		await get_tree().process_frame


func run() -> void:
	var args := OS.get_cmdline_user_args()
	GameState.prepare_opening_resume()
	check(GameState.profile == "test" and GameState.opening_checkpoint_enabled(), "test checkpoint is isolated and enabled")
	check(GameState.current_room_id == "ch6_abandoned_vip" and GameState.opening_flags.ch6_rescue_door_open, "open rescue door survives process restart")
	get_tree().current_scene = null
	reparent(GameState)
	var changed := GameState.request_room_change(GameState.current_room_id, GameState.pending_entry_id)
	await frames(12)
	var scene = get_tree().current_scene
	check(changed and is_instance_valid(scene), "final room reloads from the saved entry")
	if changed and is_instance_valid(scene):
		check(not is_instance_valid(scene.locked_door_body) and not is_instance_valid(scene.locked_door_occluder), "reloaded open door has neither blocking collision nor light occlusion")
		if "--resume-door" in args:
			check(not GameState.opening_flags.ch6_jiamin_rescued, "interrupted save is still before rescue")
			await scene._open_rescue_door()
			check(GameState.opening_flags.ch6_jiamin_rescued and is_instance_valid(scene.rescued_jiamin), "opening the saved door completes the rescue")
			check(scene.hud.panel_open and not GameState.opening_flags.ch6_reunion_seen, "reunion appears before being marked read")
		else:
			check(GameState.opening_flags.ch6_jiamin_rescued and not GameState.opening_flags.ch6_reunion_seen, "saved rescue keeps the unread reunion")
			check(scene.hud.panel_open and scene.hud.panel_body.text == "阿豪呢？", "restarting shows the missed reunion dialogue")
			scene.hud.advance()
			await get_tree().create_timer(0.9, true).timeout
			if scene.hud.choice_buttons.size() == 1:
				scene.hud.choice_buttons[0].pressed.emit()
			check(GameState.opening_flags.ch6_reunion_seen, "continuing after the reunion records the dialogue")
			var saved := OpeningCheckpoint.load_state(GameState.get_profile_path(), GameState.opening_scope())
			check(saved.ok and saved.data.flags.ch6_reunion_seen, "the read reunion state is saved")
	print("RESCUE RESUME checks=%d failures=%d" % [checks, failures])
	get_tree().paused = false
	get_tree().quit(0 if failures == 0 else 1)
