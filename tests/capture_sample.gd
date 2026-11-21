extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene = load("res://levels/ch0_tanglau/sample_room.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.player.aim_override = true
	scene.player.look_dir = Vector2(1, -0.25).normalized()
	for i in range(8):
		await process_frame
	for mode in range(3):
		scene.set_light_mode(mode)
		scene.hud.toast_time = 0
		for i in range(12):
			await process_frame
		print("UI_STATE ", mode, " paused=", paused, " panel=", scene.hud.panel_open, " title=", scene.hud.title_mark.visible)
		await RenderingServer.frame_post_draw
		var result := root.get_texture().get_image().save_png("res://docs/build_reports/tanglau_005_mode_%d.png" % mode)
		print("CAPTURE ", mode, " ", result)
	var poses := Image.create(384, 256, false, Image.FORMAT_RGBA8)
	scene.set_light_mode(1)
	scene.hud.toast_time = 0
	for direction in range(8):
		scene.player.look_dir = Vector2.from_angle(direction * PI / 4.0)
		for i in range(8):
			await process_frame
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		poses.blit_rect(shot, Rect2i(366, 348, 96, 128), Vector2i((direction % 4) * 96, (direction / 4) * 128))
	poses.resize(768, 512, Image.INTERPOLATE_NEAREST)
	poses.save_png("res://docs/build_reports/flashlight_005_eight_facings.png")
	scene.player.look_dir = Vector2(1, -0.25).normalized()
	scene.interact("desk")
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/build_reports/tanglau_005_photo.png")
	scene.close_modal()
	scene.open_journal()
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/build_reports/tanglau_005_clues.png")
	scene.close_modal()
	scene.interact("bed")
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/build_reports/tanglau_005_bed_choices.png")
	scene.close_modal()
	scene.show_pause()
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/build_reports/tanglau_005_pause_choices.png")
	scene.close_modal()
	root.get_node("AudioManager").stop_all()
	current_scene = null
	scene.queue_free()
	for i in range(3):
		await process_frame
	call_deferred("quit")
