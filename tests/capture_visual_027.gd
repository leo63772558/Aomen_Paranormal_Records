extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("capture")

func settle(count: int = 15) -> void:
	for _i in range(count):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

func shot(name: String) -> void:
	var image := get_tree().root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("The hidden renderer did not return a viewport image for " + name)
		return
	var result := image.save_png("res://docs/build_reports/" + name + ".png")
	print("CAPTURE ", name, " ", result)

func capture() -> void:
	var home: Node = load("res://levels/ch0_tanglau/hk_home_026.tscn").instantiate()
	get_tree().root.add_child(home)
	get_tree().current_scene = home
	await settle()
	var photo: Sprite2D = home.get_node_or_null("OldPhotoUnderLamp")
	if photo != null and photo.texture != null:
		var ratio: float = float(photo.texture.get_width()) / float(photo.texture.get_height())
		print("CHECK old-photo aspect ratio ", ratio)
	else:
		print("FAIL old-photo overlay missing")
	shot("opening_027_home_photo")
	home.call("_say_sequence", [
		{"title": "下班以后", "speaker": "黄嘉敏", "body": "听日陪我去澳门两日，好唔好？阿豪摄影社正做民俗采风，找到福荣旧酒店304房失踪案的旧档。"},
		{"title": "旧楼资料", "speaker": "陈大文", "body": "新图上没有那扇门，旧楼电气线路和门锁我熟。我陪你们去确认它是不是被封死，也看看还有没有人进过。"}
	])
	await settle(5)
	shot("opening_027_jiamin_dialogue")
	home.call("_close")
	await settle(5)
	shot("opening_027_dawen_dialogue")
	get_tree().paused = false
	home.queue_free()
	await settle(3)

	var bus: Node = load("res://levels/ch4_bus/bus_loop.tscn").instantiate()
	get_tree().root.add_child(bus)
	get_tree().current_scene = bus
	var bus_camera: Camera2D = bus.get("camera")
	bus_camera.position_smoothing_enabled = false
	bus.call("force_cycle", "mannequin_turn")
	await settle(8)
	shot("bus_027_reworked_interior")
	var bus_player: PlayerController = bus.get("player")
	bus_player.position.x = 590
	await get_tree().create_timer(0.45).timeout
	await settle(5)
	shot("bus_027_passenger_turn")

	bus.call("force_cycle", "window_hands")
	bus_player.position = Vector2(460, 258)
	await get_tree().create_timer(0.50).timeout
	await settle(5)
	shot("bus_027_window_hands")

	bus.call("force_cycle", "driver_mirror")
	bus_player.position = Vector2(1020, 258)
	await settle(12)
	shot("bus_027_driver_mirror")
	bus.call("force_cycle", "blood_coinbox")
	bus_player.position = Vector2(1050, 282)
	await settle(12)
	shot("bus_027_coinbox")

	bus.call("force_cycle", "")
	bus.call("trigger_action", "bell_cord")
	await settle(7)
	shot("bus_027_animated_lunge")
	get_tree().quit()
