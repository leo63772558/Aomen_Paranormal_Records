extends Node

var checks := 0
var failures := 0

func _enter_tree() -> void:
	if DisplayServer.get_name() != "headless":
		get_window().set_flag(Window.FLAG_NO_FOCUS, true)
		get_window().position = Vector2i(-32000, -32000)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame

func check(value: bool, message: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + message)
	if not value:
		failures += 1

func run() -> void:
	check(GameState.profile == "test", "isolated bus crash test")
	GameState.reset_opening()
	GameState.opening_resume_checked = true
	GameState.current_room_id = "ch4_bus_loop"
	GameState.pending_entry_id = "loop_start"
	var bus = preload("res://levels/ch4_bus/bus_loop.tscn").instantiate()
	bus.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(bus)
	await frames(8)
	if bus.hud.panel_open:
		bus._on_hud_close()
	bus.success_counter = bus.TARGET_SUCCESSES
	bus._trigger_hac_sa_crash()
	await frames(12)
	check(bus.in_cinematic and bus.is_transitioning and not bus.player.controls_enabled, "actual crash animation has started")
	bus.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var rotation: float = bus.camera.rotation
	var curtain: float = bus.crash_curtain.modulate.a
	await frames(35)
	check(get_tree().paused and is_equal_approx(bus.camera.rotation, rotation) and is_equal_approx(bus.crash_curtain.modulate.a, curtain), "focus loss pauses crash rotation and blackout")
	bus._on_hud_close()
	check(not get_tree().paused and bus.in_cinematic and bus.is_transitioning and not bus.player.controls_enabled and GameState.current_room_id == "ch4_bus_loop", "resume continues crash without loading the beach")
	await frames(120)
	check(bus.hud.panel_open and bus.in_cinematic and bus.hud.choice_buttons.size() == 2, "completed crash presents the chapter transition choices")
	check(GameState.current_room_id == "ch4_bus_loop", "beach is not entered before a choice")
	bus._restart_loop()
	bus.success_counter = bus.TARGET_SUCCESSES
	bus._trigger_hac_sa_crash()
	await frames(12)
	bus._on_hud_pause()
	bus._restart_loop()
	await frames(150)
	check(not bus.in_cinematic and not bus.is_transitioning and not bus.hud.panel_open and bus.player.controls_enabled, "restart during crash cannot reopen old crash results")
	check(is_zero_approx(bus.camera.rotation) and is_zero_approx(bus.player.rotation), "restart during crash restores actor and camera rotation")
	check(not is_instance_valid(bus.crash_curtain), "restart removes the old blackout overlay")
	if "--capture-restart" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://docs/build_reports/bus_restart_248.png") == OK, "restart scene renders")
	bus.success_counter = bus.TARGET_SUCCESSES
	bus._trigger_hac_sa_crash()
	await frames(120)
	check(bus.in_cinematic and bus.hud.panel_open and bus.hud.choice_buttons.size() == 2, "a new crash still reaches its own choices after restart")
	get_tree().paused = false
	bus.queue_free()
	await frames(2)
	print("BUS CRASH PAUSE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
