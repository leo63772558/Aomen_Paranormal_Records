extends Node

var viewport: SubViewport
var scene: Node


func _enter_tree() -> void:
	get_window().set_flag(Window.FLAG_NO_FOCUS, true)
	get_window().position = Vector2i(-32000, -32000)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")


func frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame


func shot(label: String) -> void:
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	var pixels := viewport.get_texture().get_image()
	var result := pixels.save_png("res://docs/build_reports/" + label + ".png")
	print("CAPTURE ", label, " result=", result, " size=", pixels.get_size())


func run() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(2)
		return
	var fixture := preload("res://tests/ch6_rescue_061.gd").new()
	fixture._prepare_state()
	fixture.free()
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_2d = World2D.new()
	add_child(viewport)
	scene = preload("res://levels/ch6_abandoned_vip/abandoned_vip_rescue_061.tscn").instantiate()
	viewport.add_child(scene)
	await frames(45)
	scene._close_panel()
	scene.player.aim_override = true
	scene.player.position = Vector2(224, 312)
	scene.player.reset_physics_interpolation()
	(scene.player.get_node("Camera2D") as Camera2D).reset_smoothing()
	GameState.opening_flags.ch6_jiamin_pipe_found = true
	await frames(10)
	await shot("finale_086_jiamin_before")
	scene._send_jiamin_signal()
	await frames(18)
	scene._strike_jiamin_pipe()
	for _i in range(50):
		await frames(1)
		if is_instance_valid(scene.pipe_action) and scene.pipe_action.displayed_frame == 3:
			break
	get_tree().paused = true
	await shot("finale_086_jiamin_pipe_contact")
	get_tree().paused = false
	await frames(18)
	for _strike in range(2):
		await scene._strike_jiamin_pipe()
	await frames(132)
	scene.player.position = Vector2(400, 525)
	scene.player.look_dir = Vector2.LEFT
	scene.player.reset_physics_interpolation()
	(scene.player.get_node("Camera2D") as Camera2D).reset_smoothing()
	await frames(12)
	await shot("finale_v6_illusion_door")
	# Reachable rescue states require the diagram to have been inspected before
	# the signal route can be verified; keep the visual fixture consistent.
	GameState.opening_flags.ch6_route_diagram_seen = true
	GameState.opening_flags.ch6_pipe_route_verified = true
	GameState.opening_flags.ch6_live_signal_received = true
	GameState.opening_flags.ch6_circuit_isolated = true
	GameState.opening_flags.ch6_entity_lured = true
	GameState.opening_flags.ch6_entity_bound = true
	scene.player.position = Vector2(1118, 490)
	scene.player.controls_enabled = false
	scene.player.look_dir = Vector2.RIGHT
	scene.player.set_appearance("flashlight")
	scene.player.reset_physics_interpolation()
	var camera := scene.player.get_node("Camera2D") as Camera2D
	camera.position = Vector2(0, -90)
	camera.reset_smoothing()
	await frames(12)
	await shot("finale_086_hatch_closed")
	scene._open_rescue_door()
	await frames(30)
	get_tree().paused = true
	await shot("finale_086_hatch_middle")
	get_tree().paused = false
	await frames(55)
	get_tree().paused = true
	await shot("finale_096_approach")
	get_tree().paused = false
	for _i in range(130):
		await frames(1)
		if is_instance_valid(scene.rescue_support) and scene.rescue_support.displayed_frame >= 2:
			break
	get_tree().paused = true
	await shot("finale_095_support")
	get_tree().paused = false
	for _i in range(240):
		if GameState.opening_flags.ch6_jiamin_rescued and not GameState.opening_flags.ch6_ahhao_camera_handed and is_instance_valid(scene.rescue_support) and scene.rescue_support.displayed_frame >= 2:
			break
		await frames(1)
	get_tree().paused = true
	await shot("finale_108_camera_handoff")
	get_tree().paused = false
	for _i in range(180):
		if GameState.opening_flags.ch6_ahhao_camera_handed and scene.hud.panel_open and not scene.scene_action_active:
			break
		await frames(1)
	await shot("finale_108_camera_reunion")
	if "嘉敏已获救" not in scene.hud.objective.text:
		push_error("Rescue visual fixture shows an outdated objective")
		get_tree().quit(1)
		return
	scene._close_panel()
	await frames(58)
	await shot("finale_reunion_answer_repair")
	scene._close_panel()
	scene._play_assisted_departure()
	await frames(30)
	await shot("finale_108_assisted_departure")
	for _i in range(240):
		if not scene.scene_action_active:
			break
		await frames(1)
	scene._record_final_ending("ending_escape")
	await frames(44)
	await shot("finale_ending_escape_repair")
	var photo_fixture := "res://docs/build_reports/opening_006_actual_photo.png"
	if FileAccess.file_exists(photo_fixture):
		GameState.opening_photo = ImageTexture.create_from_image(Image.load_from_file(photo_fixture))
	for ending_id in ["ending_truth", "ending_missing"]:
		scene._show_ending(ending_id)
		await frames(44)
		await shot("finale_" + ending_id)
	print("VISUAL ACTION STATE camera_handed=", GameState.opening_flags.ch6_ahhao_camera_handed, " departure_finished=", not scene.scene_action_active)
	AudioManager.stop_all()
	get_tree().paused = false
	get_tree().quit()
