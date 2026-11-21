extends Node

func _enter_tree() -> void:
	get_window().set_flag(Window.FLAG_NO_FOCUS, true)
	get_window().position = Vector2i(-32000,-32000)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func frames(count: int) -> void:
	for _i in range(count): await get_tree().process_frame

func shot(name: String) -> void:
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	var pixels := get_viewport().get_texture().get_image()
	var result := pixels.save_png("res://docs/build_reports/" + name + ".png")
	print("CAPTURE ",name," result=",result)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(2)
		return
	GameState.reset_opening()
	GameState.current_room_id = "ch2_bunker_shaft"
	GameState.current_chapter_id = "ch2_guia_tunnel"
	GameState.pending_entry_id = "from_hall"
	GameState.opening_flags.ch2_shaft_demo_seen = true
	GameState.take_demo_item("bunker_recording")
	var scene := preload("res://levels/ch2_guia/bunker_shaft_084.tscn").instantiate()
	add_child(scene)
	await frames(5)
	scene.ranger.active = false
	scene.player.aim_override = true
	scene.player.look_dir = Vector2.UP
	if "--noise-meter" in OS.get_cmdline_user_args():
		GameState.opening_flags.jiamin_phone_found = true
		GameState.take_demo_item("jiamin_phone")
		for radius in [16.0, 48.0, 140.0]:
			EventBus.noise_emitted.emit(scene.player.global_position, radius, "footstep")
		scene.show_phone()
		var phone: Control = scene.hud.panel_content.get_child(0)
		(phone.get_node("NoiseMeter") as Button).pressed.emit()
		await frames(4)
		await shot("shaft_phone_noise_meter")
		get_tree().paused = false
		get_tree().quit()
		return
	await shot("shaft_084_arrival")
	scene.player.position = Vector2(545,320)
	scene.player.look_dir = Vector2.LEFT
	scene.player.reset_physics_interpolation()
	scene.ranger.position = Vector2(294,269)
	scene.ranger.active = true
	scene.ranger.begin_lure(scene.BUCKET,Vector2(294,269))
	await frames(4)
	get_tree().paused = true
	await shot("shaft_084_windup")
	get_tree().paused = false
	scene.ranger.retire()
	scene.player.position = Vector2(545,296)
	scene.player.reset_physics_interpolation()
	scene.ranger.active = true
	scene.ranger.charge_stage = ""
	scene.pull_rope()
	await frames(6)
	get_tree().paused = true
	await shot("shaft_084_rope_action")
	for frame in range(6):
		scene._set_rope_frame(float(frame))
		await shot("shaft_096_rope_frame_%d" % frame)
	get_tree().paused = false
	await frames(60)
	scene.ranger.retire()
	scene.player.position = Vector2(650,435)
	scene.player.reset_physics_interpolation()
	scene.ranger.position = Vector2(185,222)
	scene.phase = scene.Phase.ACTIVE
	scene.close_bypass()
	for frame in range(6):
		for _i in range(45):
			if scene.door_frame >= frame: break
			await frames(1)
		get_tree().paused = true
		await shot("shaft_114_hinge_frame_%d" % frame)
		get_tree().paused = false
	for _i in range(20):
		if not scene.action_busy: break
		await frames(1)
	await shot("shaft_084_door_closed")
	scene.inspect_note()
	await frames(4)
	await shot("shaft_084_note")
	get_tree().paused = false
	get_tree().quit()
