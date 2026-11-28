extends Node

var failures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout

func _place(scene: Node, point: Vector2, facing: Vector2) -> void:
	scene.player.position = point
	scene.player.aim_override = true
	scene.player.look_dir = facing
	await _wait(0.08)

func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await _wait(0.05)
	event = InputEventAction.new()
	event.action = action
	Input.parse_input_event(event)

func _click(button: Button) -> void:
	if DisplayServer.get_name() != "headless":
		button.pressed.emit()
		await _wait(0.72)
		return
	var point := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await _wait(0.04)
	await _wait(0.7)

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_check(image.save_png("res://docs/build_reports/" + label + ".png") == OK, "capture " + label)

func _run() -> void:
	if GameState.profile != "test" or not GameState.opening_checkpoint_enabled():
		push_error("isolated checkpoint profile required")
		get_tree().quit(1)
		return
	var fixture := preload("res://tests/ch6_rescue_061.gd").new()
	fixture._prepare_state()
	fixture.free()
	for flag in ["coastal_drain_seen", "coastal_arrow_seen", "coastal_thread_seen",
		"coastal_lower_drain_seen", "coastal_shutter_seen", "coastal_chamber_tide_seen",
		"coastal_chamber_grate_seen", "coastal_chamber_hatch_seen", "coastal_silt_map_seen",
		"coastal_silt_sluice_seen", "coastal_silt_collapse_seen", "coastal_silt_grate_seen",
		"coastal_pressure_intro_seen", "coastal_pressure_diagram_seen", "coastal_pressure_gauge_seen",
		"coastal_pressure_drain_seen", "coastal_pressure_inlet_closed", "coastal_pressure_bypass_open",
		"coastal_pressure_bleeder_open", "coastal_works_record_found", "coastal_pressure_route_verified", "ch6_intro_seen"]:
		GameState.opening_flags[flag] = false
	GameState.current_room_id = "ch5_coastal_landing"
	GameState.current_chapter_id = "ch5_hacsa_beach"
	GameState.pending_entry_id = "from_shaft"
	var landing = preload("res://levels/ch5_hacsa_beach/coastal_landing.tscn").instantiate()
	add_child(landing)
	await _wait(0.55)
	if landing.hud.panel_open:
		landing._close_panel()
	await _place(landing, Vector2(784, 391), Vector2.DOWN)
	_check(landing.selected_id == "drain", "iron grille inspection is reachable from dry floor")
	Input.action_press("move_down")
	await _wait(0.8)
	Input.action_release("move_down")
	_check(landing.player.position.y < 428.0, "iron grille blocks entry into water")
	landing.queue_free()
	await _wait(0.05)

	var route_flags: Dictionary = GameState.opening_flags.duplicate(true)
	for flag in ["coastal_landing_seen", "coastal_crawlway_seen", "coastal_chamber_intro_seen",
		"coastal_chamber_west_seen", "coastal_chamber_route_verified", "coastal_silt_intro_seen",
		"coastal_silt_arch_seen", "coastal_silt_route_verified"]:
		GameState.opening_flags[flag] = false
	_check(GameState.save_opening_checkpoint(), "legacy landing checkpoint can precede its first inspection")
	GameState.opening_resume_checked = false
	GameState.prepare_opening_resume()
	_check(GameState.current_room_id == "ch5_coastal_chamber" and GameState.pending_entry_id == "from_landing", "legacy landing resumes at the chamber's safe entrance")
	var chamber := preload("res://levels/ch5_hacsa_beach/coastal_chamber.tscn").instantiate()
	add_child(chamber)
	await _wait(0.6)
	var chamber_save := OpeningCheckpoint.load_state(GameState.get_profile_path(), GameState.opening_scope())
	_check(chamber_save.ok and chamber_save.data.room_id == "ch5_coastal_chamber" and not chamber_save.data.flags.coastal_chamber_west_seen, "migrated chamber saves without marking unseen footprints")
	chamber.queue_free()
	await _wait(0.05)

	GameState.opening_flags = route_flags
	GameState.current_room_id = "ch5_coastal_silt_tunnel"
	GameState.pending_entry_id = "from_chamber"
	GameState.opening_flags.coastal_silt_arch_seen = false
	GameState.opening_flags.coastal_silt_route_verified = false
	_check(GameState.save_opening_checkpoint(), "legacy silt checkpoint can precede arch verification")
	GameState.opening_resume_checked = false
	GameState.prepare_opening_resume()
	_check(GameState.current_room_id == "ch5_coastal_pressure_gallery" and GameState.pending_entry_id == "from_silt_tunnel", "legacy silt checkpoint resumes at the pressure gallery's safe entrance")
	var gallery = preload("res://levels/ch5_hacsa_beach/coastal_pressure_gallery_060.tscn").instantiate()
	add_child(gallery)
	await _wait(0.55)
	var gallery_save := OpeningCheckpoint.load_state(GameState.get_profile_path(), GameState.opening_scope())
	_check(gallery_save.ok and gallery_save.data.room_id == "ch5_coastal_pressure_gallery" and gallery_save.data.flags.coastal_silt_arch_seen and not gallery_save.data.flags.coastal_silt_map_seen, "migrated gallery writes valid progress without marking the skipped map as read")
	await _place(gallery, Vector2(640, 614), Vector2.DOWN)
	_check("闸室" in gallery.hud.prompt.text, "gallery points back to the chamber on the three-room route")
	await _capture("coastal_gallery_return_to_chamber")
	await _place(gallery, Vector2(315, 370), Vector2.UP)
	_check(gallery.selected_id == "inlet", "inlet reachable from the central floor")
	await _press("interact")
	_check(is_instance_valid(gallery.widget) and get_tree().paused, "E opens the pressure console")
	var panel = gallery.widget
	if not is_instance_valid(panel):
		get_tree().quit(1)
		return
	await _capture("coastal_pressure_console")
	await _click(panel.captions[1])
	_check(not GameState.opening_flags.coastal_pressure_bypass_open and is_zero_approx(panel.wheels[1].rotation) and "顶回" in panel.message.text, "failed attempt shows backflow and the wheel springs back")
	await _click(panel.captions[0])
	await _click(panel.captions[1])
	await _click(panel.captions[2])
	_check(GameState.opening_flags.coastal_pressure_bleeder_open and is_equal_approx(gallery.gauge_needle.rotation, 1.2), "three console clicks depressurize the gallery")
	_check(is_zero_approx(gallery.arch_water.modulate.a) and "零压" in panel.gauge_value.text, "relief clears the approach and shows zero pressure")
	await _capture("coastal_pressure_solved")
	gallery._close_panel()
	await _place(gallery, Vector2(164, 440), Vector2.LEFT)
	await _press("interact")
	_check(GameState.opening_flags.coastal_works_record_found, "E collects the unlocked cabinet record")
	var saved := OpeningCheckpoint.load_state(GameState.get_profile_path(), GameState.opening_scope())
	_check(saved.ok and saved.data.flags.coastal_pressure_bleeder_open and not saved.data.flags.coastal_pressure_drain_seen, "skipping optional clues leaves a loadable checkpoint")
	gallery.queue_free()
	await _wait(0.05)

	var finale_seed := preload("res://tests/ch6_rescue_061.gd").new()
	finale_seed._prepare_state()
	finale_seed.free()
	var rescue = preload("res://levels/ch6_abandoned_vip/abandoned_vip_rescue_061.tscn").instantiate()
	add_child(rescue)
	await _wait(0.55)
	if rescue.hud.panel_open:
		rescue._close_panel()
	GameState.enter_role("dawen")
	GameState.opening_flags.ch6_signal_sent = true
	rescue._update_objective()
	await _place(rescue, Vector2(795, 254), Vector2.LEFT)
	_check(rescue.diagram_marker.visible and rescue.selected_id == "route_diagram", "map is marked and selectable from the central aisle")
	await _capture("coastal_rescue_map_world")
	await _press("interact")
	_check(GameState.opening_flags.ch6_route_diagram_seen and rescue.hud.panel_open, "map interaction opens the three-branch diagram")
	await _capture("coastal_rescue_map_panel")
	rescue._close_panel()
	_check(rescue.player.controls_enabled and not get_tree().paused, "closing the diagram restores movement")
	get_tree().quit(1 if failures else 0)
