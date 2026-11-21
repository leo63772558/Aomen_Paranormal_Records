extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var scene = load("res://levels/ch2_guia/hill_steps_014.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.player.aim_override = true
	scene.close_panel()
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/build_reports/hill_014_start.png")
	scene.player.position = Vector2(320,300)
	scene.player.reset_physics_interpolation()
	for i in range(12):
		await process_frame
	if scene.hud.panel_open:
		scene.close_panel()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/build_reports/hill_014_99.png")
	scene.queue_free()
	await process_frame
	quit()
