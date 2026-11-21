extends Node

var scene
var failures := 0
var checks := 0

func _enter_tree() -> void:
	if DisplayServer.get_name() != "headless":
		get_window().set_flag(Window.FLAG_NO_FOCUS, true)
		get_window().position = Vector2i(-32000, -32000)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + message)
	if not value: failures += 1

func frames(count := 4) -> void:
	for _i in range(count): await get_tree().process_frame

func tap_interact() -> void:
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	Input.parse_input_event(press)
	await frames(2)
	var release := InputEventAction.new()
	release.action = "interact"
	release.pressed = false
	Input.parse_input_event(release)
	await frames(2)

func run() -> void:
	if GameState.profile != "test" or not GameState.opening_checkpoint_enabled():
		push_error("isolated persistent profile required")
		get_tree().quit(1)
		return
	GameState.reset_opening()
	GameState.opening_resume_checked = true
	GameState.current_room_id = "ch4_bus_loop"
	GameState.pending_entry_id = "loop_start"
	scene = load("res://levels/ch4_bus/bus_loop.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await frames(12)
	if scene.hud.panel_open: scene._on_hud_close()
	for anomaly in scene.ANOMALIES:
		scene.force_cycle(anomaly)
		scene.success_counter = 3
		scene.player.position = Vector2(1172, 283)
		scene.player.clear_motion()
		await frames(8)
		check("前门" in scene.hud.prompt.text, anomaly + " front door is selectable")
		await tap_interact()
		check(scene.is_transitioning and scene.success_counter == 0 and scene.next_cycle_pending, anomaly + " missed anomaly resets progress once")
		await get_tree().create_timer(1.8, true).timeout
		check(scene.hud.panel_open and scene.MISSED_ANOMALIES[anomaly] in scene.hud.panel_body.text, anomaly + " shows its specific explanation")
		scene._on_hud_close()
		await frames(5)
		check(not scene.is_transitioning and scene.player.controls_enabled, anomaly + " explanation resumes play")
	scene.force_cycle("driver_mirror")
	scene.trigger_action("front_door")
	await frames(8)
	scene._on_hud_pause()
	scene._restart_loop()
	await frames(4)
	check(scene.glitch_timer <= 0.0 and scene.glitch_rect.color.a == 0.0 and scene.camera.offset == Vector2.ZERO, "restart during scare clears old overlay and camera shake")
	if "--capture-restart" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://docs/build_reports/bus_scare_restart_248.png") == OK, "scare restart renders")
	await frames(120)
	check(not scene.hud.panel_open and not scene.is_transitioning and scene.player.controls_enabled, "old scare cannot reopen its feedback after restart")
	print("BUS WRONG ANOMALIES checks=%d failures=%d" % [checks, failures])
	get_tree().paused = false
	scene.queue_free()
	await frames(8)
	OS.delay_msec(100)
	await frames(3)
	get_tree().quit(1 if failures else 0)
