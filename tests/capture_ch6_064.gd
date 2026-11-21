extends SceneTree


func _initialize() -> void:
	root.set_visible(false)
	call_deferred("capture")


func settle(frames: int = 48) -> void:
	for _index in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw


func shot(name: String) -> void:
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Hidden renderer returned no pixels for " + name)
		return
	var result := image.save_png("res://docs/build_reports/" + name + ".png")
	print("CAPTURE ", name, " ", result, " size=", image.get_size())


func capture() -> void:
	var state := root.get_node("GameState")
	state.profile = "test"
	state.run_id = "ch6_capture_064"
	state.opening_resume_checked = true
	state.opening_flags = OpeningCheckpoint.default_flags()
	state.opening_flags.coastal_pressure_route_verified = true
	state.opening_flags.ch6_intro_seen = true
	state.current_room_id = "ch6_abandoned_vip"
	state.current_chapter_id = "ch6_abandoned_vip"
	state.pending_entry_id = "from_pressure_gallery"
	state.role_resources = {
		"dawen": {"stamina": 100.0, "flashlight_battery": 100.0},
		"ah_hao": {"stamina": 100.0, "flashlight_battery": 100.0},
		"jiamin": {"stamina": 25.0, "flashlight_battery": 0.0}
	}
	state.current_role = "dawen"
	state.stamina = 100.0
	state.flashlight_battery = 100.0
	var packed := load("res://levels/ch6_abandoned_vip/abandoned_vip_rescue_061.tscn") as PackedScene
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await settle()
	shot("ch6_rescue_064_start_dialogue")
	if scene.hud.panel_open:
		scene._close_panel()
	await settle()
	scene.player.position = Vector2(224, 540)
	scene.player.look_dir = Vector2.UP
	scene.player.reset_physics_interpolation()
	await settle()
	shot("ch6_rescue_064_jiamin_gameplay")
	state.opening_flags.ch6_signal_sent = true
	state.enter_role("dawen")
	scene.player.position = Vector2(650, 620)
	scene.player.set_appearance("flashlight")
	scene.player.controls_enabled = true
	scene.player.aim_override = true
	scene.player.reset_physics_interpolation()
	await settle()
	shot("ch6_rescue_064_dawen_gameplay")
	scene.interact_target("route_diagram")
	await settle()
	shot("ch6_rescue_064_route_dialogue")
	root.get_node("AudioManager").stop_all()
	paused = false
	current_scene = null
	scene.queue_free()
	await settle(3)
	quit()
