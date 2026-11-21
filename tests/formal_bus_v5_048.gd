extends Node

var scene
var checks := 0
var failed := false

func _enter_tree() -> void:
	if DisplayServer.get_name() != "headless":
		get_window().set_flag(Window.FLAG_NO_FOCUS, true)
		get_window().position = Vector2i(-32000, -32000)

func _ready() -> void:
	get_tree().create_timer(40, true).timeout.connect(func(): get_tree().quit(2))
	call_deferred("run")

func frames(n := 4) -> void:
	for _i in range(n): await get_tree().process_frame

func check(value: bool, label: String) -> void:
	checks += 1
	failed = failed or not value
	print(("PASS " if value else "FAIL ") + label)

func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames()
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png("res://docs/build_reports/" + label + ".png") == OK, label)

func run() -> void:
	check(GameState.profile == "test", "isolated_profile")
	GameState.reset_opening()
	GameState.opening_resume_checked = true
	GameState.current_room_id = "ch4_bus_loop"
	GameState.pending_entry_id = "loop_start"
	GameState.opening_flags.jiamin_phone_found = true
	GameState.opening_items["jiamin_phone"] = 1
	scene = load("res://levels/ch4_bus/bus_loop.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await frames(12)
	check(scene.player.visual_size_multiplier == 3.1 and scene.bell_sensors.size() == 4, "adult_scale_and_four_physically_mounted_bells")
	check(scene.current_anomaly.is_empty() and scene.success_counter == 0, "first visit provides a normal reference carriage before random rounds")
	if scene.hud.panel_open:
		scene._on_hud_close()
	var actor: PlayerController = scene.player
	check(actor.test_move(Transform2D(0, Vector2(400, 284)), Vector2(0, -85)), "painted northern seats block movement")
	check(actor.test_move(Transform2D(0, Vector2(400, 284)), Vector2(0, 77)), "painted southern seats block movement")
	var blocker := KinematicCollision2D.new()
	var aisle_blocked := actor.test_move(Transform2D(0, Vector2(302, 283)), Vector2(-213, 0), blocker)
	check(not aisle_blocked, "rear threshold is reachable through the aisle. Blocker: %s" % str(blocker.get_collider()))
	actor.position = Vector2(222, 283)
	scene.camera.reset_smoothing()
	await frames(6)
	await shot("formal_bus_rear_bell_251")
	scene._handle_interaction()
	await frames(5)
	check(scene.bell_pulled and not is_zero_approx(scene.bell_visuals[0].rotation), "the visible bell moves and registers the request when used")
	scene._start_new_cycle(true)
	GameState.opening_flags.photo_taken = true
	GameState.opening_photo = null
	GameState.opening_photo_file = ""
	scene._store_cycle()
	check("保存失败" in scene.hud.defense_notice.text and not get_tree().paused, "failed checkpoint displays feedback while keeping the bus playable")
	GameState.opening_flags.photo_taken = false
	scene.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(get_tree().paused and scene.hud.panel_open and not scene.player.controls_enabled, "focus_loss_pauses_normal_bus")
	scene._on_hud_close()
	check(not get_tree().paused and scene.player.controls_enabled, "resume_after_focus_restores_bus_control")
	scene.in_cinematic = true
	scene.is_transitioning = true
	scene.success_counter = scene.TARGET_SUCCESSES
	scene._on_hud_pause()
	check(get_tree().paused and scene.hud.panel_open, "crash_cinematic_can_be_paused")
	scene._on_hud_close()
	check(not get_tree().paused and scene.in_cinematic and scene.is_transitioning and not scene.player.controls_enabled and GameState.current_room_id == "ch4_bus_loop", "resuming_crash_does_not_skip_to_the_next_chapter")
	scene.in_cinematic = false
	scene.is_transitioning = false
	scene.success_counter = 0
	scene.player.controls_enabled = true
	var phone_event := InputEventAction.new()
	phone_event.action = "phone"
	phone_event.pressed = true
	Input.parse_input_event(phone_event)
	await frames(3)
	check(scene.hud.panel_open and scene.hud.default_phone_widget != null and get_tree().paused, "phone_key_opens_offline_phone_in_formal_bus")
	await shot("formal_bus_phone_176")
	phone_event = InputEventAction.new()
	phone_event.action = "phone"
	phone_event.pressed = true
	Input.parse_input_event(phone_event)
	await frames(3)
	check(not scene.hud.panel_open and not get_tree().paused and scene.player.controls_enabled, "phone_key_returns_to_bus_without_interaction")
	var journal_event := InputEventAction.new()
	journal_event.action = "journal"
	journal_event.pressed = true
	Input.parse_input_event(journal_event)
	await frames(3)
	check(scene.hud.archive_page == "journal" and "连续五次" in scene.hud.default_phone_widget.detail.text and get_tree().paused, "J keeps the bus notice in the evidence journal")
	await shot("formal_bus_journal")
	Input.parse_input_event(journal_event.duplicate())
	await frames(3)
	check(not get_tree().paused and scene.player.controls_enabled, "journal returns to the active pass")
	GameState.reduced_flash = true
	scene.force_cycle("stop_screen")
	for i in range(12):
		scene._refresh_broadcast_display()
		if not scene.led_panel.visible:
			check(false, "reduced_flash_keeps_anomalous_sign_visible")
			break
	if scene.led_panel.visible:
		check(true, "reduced_flash_keeps_anomalous_sign_visible")
	scene.glitch_timer = 1.0
	scene._update_glitch(0.01)
	check(scene.glitch_rect.color.a <= 0.151 and scene.glitch_rect.position == Vector2.ZERO, "reduced_flash_limits_overlay_and_jitter")
	await shot("formal_bus_reduced_flash_161")
	scene.glitch_timer = 0.0
	scene.glitch_rect.color.a = 0.0
	GameState.reduced_flash = false
	scene.force_cycle("mannequin_turn")
	scene.player.position = Vector2(590, 270)
	await get_tree().create_timer(0.42, true).timeout
	check(scene.mannequin_sprite.turn_amount > 0.12 and scene.mannequin_sprite.mesh.polygon != scene.mannequin_sprite.rest, "same_passenger_turn_deforms_continuously")
	await shot("formal_bus_passenger_048")
	scene.trigger_action("rear_door")
	check(scene.success_counter == 0 and not scene.bell_pulled and not scene.hud.panel_open and "后门锁着" in scene.hud.defense_notice.text, "rear door explains the bell requirement without consuming a round")
	scene.trigger_action("bell_cord")
	check(scene.bell_pulled and scene.success_counter == 0 and not scene.is_transitioning, "bell_alone_is_not_a_success")
	scene.player.position = Vector2(90, 283)
	scene.camera.reset_smoothing()
	scene.trigger_action("rear_door")
	check(scene.success_counter == 1 and scene.formal_rear_door.moving, "bell_then_rear_counts_once_and_moves_real_door")
	await get_tree().create_timer(0.95, true).timeout
	check(scene.formal_rear_door.collision.disabled and not scene.formal_rear_door.occluder.visible, "fully_open_door_updates_collision_and_occlusion")
	await shot("formal_bus_rear_open_048")
	var completed_cycle: int = scene.cycle_index
	check(GameState.bus_loop_state.next_cycle_pending, "door_transition_records_pending_advance")
	scene.queue_free()
	await frames(8)
	scene = load("res://levels/ch4_bus/bus_loop.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await frames(12)
	check(scene.success_counter == 1 and scene.cycle_index > completed_cycle and not scene.next_cycle_pending, "resume_during_door_motion_advances_without_recounting_old_round")
	scene.force_cycle("")
	scene.trigger_action("bell_cord")
	check(scene.success_counter == 1 and scene.bell_pulled and not scene.is_transitioning, "pulling the bell in a normal carriage does not submit an answer")
	if GameState.opening_checkpoint_enabled():
		var saved := OpeningCheckpoint.load_state(GameState.get_profile_path(), GameState.opening_scope())
		check(saved.ok and saved.data.bus_loop_state.bell_pulled and saved.data.bus_loop_state.anomaly.is_empty(), "normal-carriage bell state survives checkpoint validation")
	scene.trigger_action("rear_door")
	check(scene.success_counter == 0 and is_instance_valid(scene.lunge_rig) and scene.next_cycle_pending, "bell plus rear door submits the false alarm")
	await get_tree().create_timer(0.42, true).timeout
	var time: float = scene.lunge_rig.animation_player.current_animation_position
	scene._on_hud_pause()
	await frames(20)
	check(scene.lunge_rig.animation_player.current_animation_position == time, "pause_freezes_bone_lunge")
	scene._on_hud_close()
	await shot("formal_bus_lunge_048")
	await get_tree().create_timer(1.1, true).timeout
	check(scene.hud.panel_open and "正常车厢应从前门下车" in scene.hud.panel_body.text, "false alarm gives readable feedback after the scare")
	scene._on_hud_close()
	check(not scene.is_transitioning and scene.player.controls_enabled, "closing feedback starts the next round")
	scene.force_cycle("stop_screen")
	scene.trigger_action("front_door")
	scene.queue_free()
	await frames(8)
	scene = load("res://levels/ch4_bus/bus_loop.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await frames(8)
	check(scene.hud.panel_open and "枉死坡" in scene.hud.panel_body.text and scene.success_counter == 0, "re-entering after a missed anomaly preserves the exact failure feedback")
	scene._on_hud_close()
	for anomaly in ["driver_mirror", "blood_coinbox", "stop_screen", "window_hands", ""]:
		scene.force_cycle(anomaly)
		if anomaly.is_empty(): scene.trigger_action("front_door")
		else:
			scene.trigger_action("bell_cord")
			scene.trigger_action("rear_door")
		if scene.success_counter < 5: await get_tree().create_timer(1.3, true).timeout
	await get_tree().create_timer(2.0, true).timeout
	check(scene.success_counter == 5 and GameState.opening_flags.bus_arrived and scene.hud.panel_open, "five_consecutive_choices_reach_crash")
	check(GameState.bus_loop_state.successes == 5, "completed_loop_stored_for_resume")
	get_tree().paused = false
	scene.queue_free()
	await frames(8)
	OS.delay_msec(100)
	await frames(3)
	print("FORMAL BUS V5 %d checks failed=%s" % [checks, failed])
	get_tree().quit(1 if failed else 0)
