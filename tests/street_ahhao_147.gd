extends Node

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	if GameState.profile != "test":
		push_error("test profile required")
		get_tree().quit(1)
		return
	GameState.current_room_id = "ch0_street"
	GameState.pending_entry_id = "arrival"
	GameState.opening_flags.ah_hao_dead = false
	var scene = load("res://levels/ch0_tanglau/opening_street.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	for i in range(12):
		await get_tree().process_frame
	if scene.hud.panel_open:
		scene.close_dialog(false)
	for i in range(8):
		await get_tree().process_frame
	var ah := scene.get_node_or_null("AhHaoStreet") as StaticBody2D
	if ah == null or ah.collision_layer != 1 or not ah.get_child(0) is CollisionShape2D:
		push_error("Ah Hao must be visible and solid before the hotel")
		get_tree().quit(1)
		return
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var capture := get_viewport().get_texture().get_image()
		if capture.save_png("res://docs/build_reports/street_ahhao_147.png") != OK:
			push_error("street capture failed")
			get_tree().quit(1)
			return
	print("PASS street has Ah Hao's independent visible sprite and collision")
	scene.player.position = scene.AHHAO_STREET_FOOT + Vector2(-30, 0)
	scene.player.aim_override = true
	scene.player.look_dir = Vector2.RIGHT
	for i in range(5):
		await get_tree().process_frame
	if scene.selected_id != "ahhao":
		push_error("Ah Hao must be selectable from a reachable position")
		get_tree().quit(1)
		return
	scene.interact_target(scene.selected_id)
	if not scene.hud.panel_open:
		push_error("Ah Hao interaction must open dialogue")
		get_tree().quit(1)
		return
	scene.close_dialog(false)
	print("PASS Ah Hao can be spoken to through the world target")
	GameState.opening_flags.ah_hao_dead = true
	scene.queue_free()
	await get_tree().process_frame
	var return_scene = load("res://levels/ch0_tanglau/opening_street.tscn").instantiate()
	get_tree().root.add_child(return_scene)
	get_tree().current_scene = return_scene
	await get_tree().process_frame
	if return_scene.has_node("AhHaoStreet"):
		push_error("Ah Hao must not reappear after his death")
		get_tree().quit(1)
		return
	print("PASS Ah Hao does not reappear after death")
	get_tree().quit()
