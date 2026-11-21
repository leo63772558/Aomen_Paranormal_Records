extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func snapshot(path: String) -> void:
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	var state = root.get_node("GameState")
	state.opening_resume_checked = true
	state.opening_flags.bunker_oil_found = true
	state.opening_flags.bunker_key_2 = true
	var gate = load("res://levels/ch2_guia/hill_shelter_014.tscn").instantiate()
	root.add_child(gate)
	current_scene = gate
	await process_frame
	gate.show_bunker_lock()
	await snapshot("res://tools/recovery/bunker_gate_ui_025.png")
	state.opening_flags.bunker_lock_open = true
	gate.hud.panel_content.get_child(gate.hud.panel_content.get_child_count() - 1).queue_redraw()
	await snapshot("res://tools/recovery/bunker_gate_open_ui_025.png")
	state.opening_flags.bunker_lock_open = false
	gate.close_dialog()
	root.remove_child(gate)
	gate.queue_free()
	var hill = load("res://levels/ch2_guia/hill_base_014.tscn").instantiate()
	root.add_child(hill)
	current_scene = hill
	await process_frame
	hill.show_bunker_toolbox()
	var box = hill.hud.panel_content.get_child(hill.hud.panel_content.get_child_count() - 1)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(310, 190)
	box._gui_input(press)
	await snapshot("res://tools/recovery/bunker_toolbox_ui_025.png")
	hill.close_dialog()
	await snapshot("res://tools/recovery/bunker_hill_scene_025.png")
	root.remove_child(hill)
	hill.queue_free()
	await process_frame
	state.opening_flags.interview_index_copied = true
	var archive = load("res://levels/ch1_stpaul/crypt_archive_013.tscn").instantiate()
	root.add_child(archive)
	current_scene = archive
	await process_frame
	archive.copy_interview_index()
	await snapshot("res://tools/recovery/macau_index_ui_025.png")
	archive.close_dialog()
	root.remove_child(archive)
	archive.queue_free()
	await process_frame
	var crypt = load("res://levels/ch1_stpaul/crypt_entry_013.tscn").instantiate()
	root.add_child(crypt)
	current_scene = crypt
	await process_frame
	crypt.show_crypt_evidence_menu()
	await snapshot("res://tools/recovery/crypt_evidence_menu_025.png")
	crypt.show_crypt_witness()
	await snapshot("res://tools/recovery/crypt_witness_025.png")
	crypt.close_dialog()
	root.remove_child(crypt)
	crypt.queue_free()
	root.get_node("AudioManager").stop_all()
	await create_timer(0.4).timeout
	await process_frame
	quit()
