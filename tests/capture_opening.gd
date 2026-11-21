extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func settle(count: int = 12) -> void:
	for i in range(count):
		await process_frame
	await RenderingServer.frame_post_draw

func shot(name: String) -> void:
	var result := root.get_texture().get_image().save_png("res://docs/build_reports/"+name+".png")
	print("CAPTURE ",name," ",result)

func capture() -> void:
	var scene=load("res://levels/ch0_tanglau/opening_street.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.player.aim_override=true
	await settle()
	shot("opening_006_street")
	scene.start_camera()
	scene.camera_view.center=Vector2(405,201)
	scene.camera_view.queue_redraw()
	await settle()
	shot("opening_006_camera_pose")
	await scene.take_photo()
	await settle()
	shot("opening_006_photo_dialogue")
	if root.get_node("GameState").opening_photo!=null:
		root.get_node("GameState").opening_photo.get_image().save_png("res://docs/build_reports/opening_006_actual_photo.png")
	scene.close_dialog()
	scene.player.position=Vector2(375,246)
	scene.player.reset_physics_interpolation()
	scene.interact_target("jiamin")
	await settle()
	shot("opening_006_offer_pastry")
	scene.accept_pastry()
	await settle()
	shot("opening_006_receive_pastry")
	scene.close_dialog()
	root.get_node("GameState").request_room_change("ch0_foyer","from_street")
	await settle()
	scene=current_scene
	scene.close_dialog()
	await settle()
	shot("opening_006_foyer")
	scene.show_power_puzzle()
	await settle()
	shot("opening_007_wiring")
	scene.close_dialog()
	root.get_node("GameState").request_room_change("ch0_corridor","from_foyer")
	await settle()
	scene=current_scene
	shot("opening_010_corridor")
	root.get_node("GameState").opening_flags.jiamin_phone_found=true
	scene.show_phone_notes()
	await settle()
	shot("opening_011_phone_notes")
	scene.close_dialog()
	root.get_node("GameState").request_room_change("ch0_room304","from_corridor")
	await settle()
	scene=current_scene
	shot("opening_011_room304")
	scene.answer_room_phone()
	await settle()
	scene.close_dialog()
	await settle()
	shot("opening_011_outage")
	scene.enter_room_wardrobe()
	await create_timer(1.8).timeout
	await settle()
	shot("opening_011_shadow")
	await create_timer(4.0).timeout
	scene.exit_room_wardrobe()
	scene.show_old_photo()
	await settle()
	shot("opening_011_old_photo")
	scene.close_dialog()
	root.get_node("GameState").opening_flags.room_bed_moved = true
	scene.room_bed.position = Vector2(-145,10)
	scene.room_bed_shadow.position = scene.room_bed.position
	scene.room_vent.show()
	await settle()
	shot("opening_011_bed_moved")
	root.get_node("GameState").opening_flags.room_cover_open = true
	root.get_node("GameState").request_room_change("ch0_maintenance","from_room304")
	await settle()
	scene=current_scene
	shot("opening_012_maintenance")
	scene.show_maintenance_lock()
	await settle()
	shot("opening_012_lock")
	scene.close_dialog()
	root.get_node("GameState").opening_flags.maintenance_unlocked = true
	root.get_node("GameState").request_room_change("ch0_yard","from_maintenance")
	await settle()
	scene=current_scene
	scene.close_dialog()
	await create_timer(2.4).timeout
	await settle()
	shot("opening_012_yard_chase")
	root.get_node("GameState").opening_flags.yard_escaped = true
	root.get_node("GameState").request_room_change("ch0_exit_lane","from_yard")
	await settle()
	scene=current_scene
	shot("opening_012_exit_lane")
	scene.player.position=Vector2(125,300)
	scene.player.reset_physics_interpolation()
	scene.call_public_phone()
	await create_timer(0.5).timeout
	await settle()
	shot("opening_012_phone_call")
	await create_timer(2.0).timeout
	await settle()
	scene.close_dialog()
	root.get_node("GameState").request_room_change("ch1_crypt_entry","from_lane")
	await settle()
	scene=current_scene
	shot("opening_013_crypt")
	for key in ["crypt_photo_seen", "crypt_plan_seen", "crypt_doodle_seen"]:
		root.get_node("GameState").opening_flags[key]=true
	scene.show_crypt_comparison()
	await settle()
	shot("opening_013_comparison")
	scene.close_dialog()
	root.get_node("GameState").opening_flags.crypt_aligned=true
	root.get_node("GameState").opening_flags.crypt_clip_removed=true
	root.get_node("GameState").opening_flags.crypt_door_open=true
	root.get_node("GameState").request_room_change("ch1_crypt_hall","from_entry")
	await settle()
	scene=current_scene
	scene.close_dialog()
	await create_timer(1.8).timeout
	await settle()
	shot("opening_013_priest")
	root.get_node("GameState").opening_flags.priest_escaped=true
	root.get_node("GameState").request_room_change("ch1_archive","from_hall")
	await settle()
	scene=current_scene
	shot("opening_013_archive")
	root.get_node("GameState").request_room_change("ch0_sample","sample")
	await settle()
	scene=current_scene
	root.get_node("GameState").try_add_clue("old_photo")
	root.get_node("GameState").try_add_clue("floor_marks")
	scene.try_move_bed()
	scene.player.position=Vector2(438,142)
	scene.player.aim_override=true
	scene.player.look_dir=Vector2.UP
	scene.player.reset_physics_interpolation()
	scene.set_light_mode(0)
	scene.hud.toast_time=0
	await settle()
	shot("sample_006_metal_cover")
	scene.interact("vent")
	await settle()
	shot("sample_006_cover_open")
	scene.close_modal()
	root.get_node("AudioManager").stop_all()
	current_scene=null
	scene.queue_free()
	await settle(3)
	call_deferred("quit")
