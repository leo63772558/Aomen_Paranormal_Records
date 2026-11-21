extends Node

func _enter_tree() -> void:
	get_window().set_flag(Window.FLAG_NO_FOCUS, true)
	get_window().position = Vector2i(-32000, -32000)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame

func shot(name: String) -> void:
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png("res://docs/build_reports/" + name + ".png")
	print("CAPTURE ",name," result=",result)

func run() -> void:
	if DisplayServer.get_name() == "headless" or GameState.profile != "test":
		get_tree().quit(2)
		return
	GameState.reset_opening()
	GameState.opening_resume_checked = true
	GameState.current_chapter_id = "ch0_tanglau"
	GameState.current_room_id = "ch0_room304"
	GameState.pending_entry_id = "from_corridor"
	GameState.opening_flags.room_phone_answered = true
	GameState.opening_flags.jiamin_phone_found = true
	GameState.opening_flags.room_bed_moved = true
	var scene := preload("res://levels/ch0_tanglau/room304.tscn").instantiate()
	scene.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(scene)
	await frames(8)
	scene.player.position = Vector2(520,205)
	scene.player.look_dir = Vector2.UP
	scene.player.aim_override = true
	scene.player.reset_physics_interpolation()
	await frames(5)
	print("BEFORE cover=",scene.room_vent.visible," collision=",is_instance_valid(scene.room_aperture)," occluder=",is_instance_valid(scene.room_aperture_shadow))
	await shot("room304_cover_098_before")
	scene.player.position = Vector2(460,220)
	scene.player.reset_physics_interpolation()
	await frames(3)
	await shot("room304_cover_098_before_clear")
	scene.player.position = Vector2(520,205)
	Input.action_press("move_up")
	await frames(65)
	Input.action_release("move_up")
	print("PHYSICAL BEFORE player_y=",scene.player.position.y)
	scene.player.position = Vector2(520,205)
	scene.player.clear_motion()
	scene.player.reset_physics_interpolation()
	await frames(3)
	scene.remove_room_cover()
	await frames(25)
	await shot("room304_cover_098_pliers")
	get_tree().paused = true
	for frame in range(6):
		scene._set_vent_work_frame(float(frame))
		await shot("room304_cover_101_frame_%d" % frame)
	get_tree().paused = false
	await frames(30)
	await shot("room304_cover_098_lift")
	await frames(50)
	await shot("room304_cover_101_clue")
	scene.close_dialog()
	await frames(3)
	print("AFTER opening=",scene.room_hatch.visible," cover=",scene.room_vent.visible," collision=",is_instance_valid(scene.room_aperture)," occluder=",is_instance_valid(scene.room_aperture_shadow))
	await shot("room304_cover_098_after")
	scene.player.position = Vector2(460,220)
	scene.player.reset_physics_interpolation()
	await frames(3)
	await shot("room304_cover_098_after_clear")
	scene.player.position = Vector2(520,205)
	scene.player.clear_motion()
	Input.action_press("move_up")
	await frames(65)
	Input.action_release("move_up")
	print("PHYSICAL AFTER player_y=",scene.player.position.y)
	get_tree().quit()
