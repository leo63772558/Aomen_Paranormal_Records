extends SceneTree

var state: Node

func _initialize() -> void:
	call_deferred("run")

func frames(count := 6) -> void:
	for i in range(count):
		await process_frame

func snapshot(id: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	var path := "res://tools/recovery/demo026_%s.png" % id
	var result := root.get_texture().get_image().save_png(path)
	print("CAPTURE %s %s" % [id, result])

func mount(path: String) -> Node:
	paused = false
	change_scene_to_file(path)
	await frames()
	return current_scene

func run() -> void:
	state = root.get_node("GameState")
	if state.profile != "test" or DisplayServer.get_name() == "headless":
		quit(2)
		return
	var scene = await mount("res://ui/main_menu.tscn")
	await snapshot("menu")
	scene = await mount("res://levels/ch0_tanglau/hk_home_026.tscn")
	await snapshot("home")
	scene.interact_intro("map")
	await snapshot("map")
	scene = await mount("res://levels/ch0_tanglau/bridge_bus_026.tscn")
	await snapshot("coach")
	state.take_demo_item("ceramic_fuse")
	state.take_demo_item("insulated_bridge")
	state.take_demo_item("power_record")
	scene = await mount("res://levels/ch0_tanglau/entrance_hall.tscn")
	scene.close_dialog(false)
	scene.show_power_puzzle()
	await snapshot("meter")
	state.opening_flags.bunker_oil_found = true
	for key_number in range(1, 4):
		state.take_demo_item("gate_key_%d" % key_number)
	scene = await mount("res://levels/ch2_guia/hill_shelter_014.tscn")
	scene.show_bunker_lock()
	await snapshot("gate")
	scene = await mount("res://levels/ch2_guia/bunker_ammo_022.tscn")
	scene.player.position = Vector2(386, 313)
	scene.player.look_dir = Vector2.UP
	scene.player.aim_override = true
	scene.player.reset_physics_interpolation()
	scene.player.get_node("Camera2D").reset_smoothing()
	scene.start_red_passage()
	await snapshot("ammo")
	state.demo_pursuit = ""
	scene = await mount("res://levels/ch2_guia/hill_steps_014.tscn")
	scene.player.position = Vector2(318, scene.STAIRS.y_at(89) - 3)
	scene.player.look_dir = Vector2.UP
	scene.player.aim_override = true
	scene.player.reset_physics_interpolation()
	scene.player.get_node("Camera2D").reset_smoothing()
	await snapshot("stairs")
	var layer := CanvasLayer.new()
	layer.layer = 42
	scene.add_child(layer)
	var animation = load("res://ui/demo_capture_animation.gd").new()
	layer.add_child(animation)
	animation.set_process(false)
	await snapshot("attack_1")
	animation.apply_pose(0.40)
	await snapshot("attack_4")
	animation.apply_pose(0.62)
	await snapshot("attack_6")
	change_scene_to_file("res://ui/main_menu.tscn")
	await create_timer(1.35, true).timeout
	quit.call_deferred()
