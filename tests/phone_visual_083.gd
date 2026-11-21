extends Node

func _enter_tree() -> void:
	get_window().set_flag(Window.FLAG_NO_FOCUS, true)
	get_window().position = Vector2i(-32000, -32000)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func settle(count: int) -> void:
	for _i in range(count): await get_tree().process_frame

func shot(name: String) -> void:
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	var pixels := get_viewport().get_texture().get_image()
	var result := pixels.save_png("res://docs/build_reports/" + name + ".png")
	print("CAPTURE ", name, " result=", result, " size=", pixels.get_size())

func run() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(2)
		return
	GameState.reset_opening()
	GameState.opening_resume_checked = true
	GameState.current_room_id = "ch1_crypt_entry"
	GameState.current_chapter_id = "ch1_stpaul_crypt"
	GameState.pending_entry_id = "from_lane"
	GameState.opening_flags.jiamin_phone_found = true
	GameState.take_demo_item("jiamin_phone")
	var scene := preload("res://levels/ch1_stpaul/crypt_entry_013.tscn").instantiate()
	add_child(scene)
	await settle(8)
	scene.player.aim_override = true
	scene.player.look_dir = Vector2.RIGHT
	scene.player.position = Vector2(300, 278)
	scene.player.reset_physics_interpolation()
	var enemy := preload("res://entities/shadow_chaser.gd").new()
	enemy.position = Vector2(395, 252)
	enemy.target = scene.player
	enemy.speed = 0
	scene.add_child(enemy)
	await settle(6)
	await shot("phone_083_before")
	scene.player.phone_defense.fire()
	await settle(3)
	await shot("phone_083_flash_pose")
	await settle(35)
	GameState.phone_battery = 0
	GameState.phone_flash_charges = 0
	scene.show_phone_notes()
	await settle(8)
	await shot("phone_083_offline_1280")
	get_window().size = Vector2i(960, 540)
	await settle(10)
	await shot("phone_083_offline_960")
	get_window().size = Vector2i(1920, 1080)
	await settle(10)
	await shot("phone_083_offline_1920")
	get_window().size = Vector2i(1280, 720)
	scene.close_dialog()
	var box := preload("res://ui/bunker_toolbox.gd").new()
	scene.open_demo_widget(box)
	await settle(8)
	await shot("toolbox_085_closed")
	box.open_progress = 0.5
	box.opening = true
	await settle(4)
	await shot("toolbox_085_hinge_middle")
	box.open_progress = 1.0
	box.opening = false
	box.opened = true
	await settle(4)
	await shot("toolbox_085_open")
	get_tree().paused = false
	get_tree().quit()
