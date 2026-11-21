extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var scene = load("res://levels/ch2_guia/bunker_hall_015.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/build_reports/bunker_hall_015.png")
	quit()
