extends Node

var scene: Node
var checks := 0
var failures := 0
var world_cues: Array[String] = []
var response_beat_labels: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS " + label)
	else:
		failures += 1
		push_error("FAIL " + label)


func wait_frames(count := 4) -> void:
	for _index in range(count):
		await get_tree().process_frame


func event_action(name: String, pressed: bool) -> void:
	if pressed:
		Input.action_press(name, 1.0)
	else:
		Input.action_release(name)
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


func walk_to(point: Vector2) -> void:
	var current_action := ""
	var elapsed := 0
	while scene.player.position.distance_to(point) > 3.0 and elapsed < 1200:
		var difference: Vector2 = point - scene.player.position
		var next_action := "move_right" if difference.x > 2.0 else ("move_left" if difference.x < -2.0 else ("move_down" if difference.y > 2.0 else "move_up"))
		if next_action != current_action:
			if not current_action.is_empty():
				event_action(current_action, false)
			current_action = next_action
			event_action(current_action, true)
		await get_tree().physics_frame
		elapsed += 1
	if not current_action.is_empty():
		event_action(current_action, false)
	await wait_frames(3)
	check(scene.player.position.distance_to(point) <= 5.0, "player can walk to " + str(point))


func interact_by_input(id: String, target: Vector2) -> void:
	scene.player.look_dir = (target - scene.player.position).normalized()
	await wait_frames(4)
	check(scene.selected_id == id, "E prompt selects " + id)
	event_action("interact", true)
	await wait_frames(1)
	event_action("interact", false)
	await wait_frames(3)


func tap_space() -> void:
	var press_event := InputEventKey.new()
	press_event.keycode = KEY_SPACE
	press_event.physical_keycode = KEY_SPACE
	press_event.pressed = true
	Input.parse_input_event(press_event)
	await wait_frames(1)
	var release_event := InputEventKey.new()
	release_event.keycode = KEY_SPACE
	release_event.physical_keycode = KEY_SPACE
	release_event.pressed = false
	Input.parse_input_event(release_event)
	await wait_frames(1)


func wait_for_signal_response() -> void:
	for _frame in range(240):
		if not scene.signal_response_active:
			break
		await get_tree().process_frame
	await wait_frames(2)


func enter_signal(interval_frames: Array[int], wait_for_response := true) -> void:
	await tap_space()
	for interval in interval_frames:
		OS.delay_msec(roundi(float(interval) * 1000.0 / 60.0))
		await tap_space()
	if interval_frames.size() == 2:
		OS.delay_msec(950)
		await get_tree().process_frame
		check(not scene.listening_target.is_empty(), "three taps leave time for another knock or an explicit finish")
		event_action("ui_accept", true)
		await get_tree().process_frame
		event_action("ui_accept", false)
	else:
		OS.delay_msec(1300)
	await get_tree().process_frame
	if wait_for_response:
		await wait_for_signal_response()


func close_panel() -> void:
	if is_instance_valid(scene) and is_instance_valid(scene.hud) and scene.hud.panel_open:
		scene._close_panel()
	await wait_frames(2)


func _prepare_state() -> void:
	if "--profile=playtest" not in OS.get_cmdline_user_args():
		GameState.profile = "test"
	if GameState.profile == "test" and GameState.run_id == "sample_room":
		GameState.run_id = "ch6_rescue_061"
	GameState.opening_resume_checked = true
	GameState.opening_flags = OpeningCheckpoint.default_flags()
	GameState.opening_switches = OpeningCheckpoint.SWITCHES.duplicate(true)
	for key in GameState.opening_flags:
		GameState.opening_flags[key] = false
	for flag in [
		"photo_taken", "pastry_shared", "knock_agreed", "entered_foyer", "meter_cover_open", "floor3_power",
		"jiamin_phone_found", "old_photo_seen", "room_bed_moved", "room_cover_open", "room_phone_answered",
		"wardrobe_tutorial_done", "shadow_passed", "maintenance_unlocked", "yard_escaped", "help_attempted",
		"intro_job_done", "intro_invited", "intro_photo_seen", "intro_plan_seen", "intro_boarded", "phone_taught",
		"wet_tag_left", "pit_stone_thrown", "pit_bones_seen", "bunker_chain_relieved", "ammo_chase_cleared", "demo_case_closed",
		"crypt_photo_seen", "crypt_plan_seen", "crypt_doodle_seen", "crypt_aligned", "crypt_clip_removed", "crypt_door_open",
		"priest_escaped", "interview_index_copied", "hill_stele_seen", "hill_warning_seen", "hill_steps_completed",
		"bunker_gate_unlocked", "bunker_red_seen", "bunker_gate_examined", "bunker_oil_found", "bunker_lock_oiled", "bunker_lock_open",
		"bunker_key_1", "bunker_key_2", "bunker_key_3", "ah_hao_breaker_done", "ah_hao_escaped", "ah_hao_dead", "dawen_304_escape_done",
		"ch3_intro_seen", "ch3_photo_seen", "ch3_register_seen", "ch3_delivery_seen", "ch3_visitor_log_seen", "ch3_guest_inferred",
		"ch3_cold_door_seen", "ch3_cold_door_open", "ch3_balance_rule_seen", "ch3_balance_solved", "ch3_key_found", "ch3_ticket_found",
		"bus_taught", "bus_reflection_cleared", "bus_voice_cleared", "bus_arrived",
		"beach_intro_seen", "beach_sole_seen", "beach_trace_a_seen", "beach_wrack_seen", "beach_trace_b_seen", "beach_footprints_solved",
		"beach_key_box_open", "beach_cabinet_key_found", "beach_cabinet_open", "beach_plan_found", "beach_circuit_matched",
		"coastal_intro_seen", "coastal_drain_seen", "coastal_arrow_seen", "coastal_thread_seen", "coastal_ladder_seen", "coastal_route_verified",
		"coastal_landing_seen", "coastal_lower_drain_seen", "coastal_shutter_seen", "coastal_crawlway_seen", "coastal_chamber_intro_seen",
		"coastal_chamber_tide_seen", "coastal_chamber_grate_seen", "coastal_chamber_hatch_seen", "coastal_chamber_west_seen", "coastal_chamber_route_verified",
		"coastal_silt_intro_seen", "coastal_silt_map_seen", "coastal_silt_sluice_seen", "coastal_silt_collapse_seen", "coastal_silt_grate_seen", "coastal_silt_arch_seen", "coastal_silt_route_verified",
		"coastal_pressure_intro_seen", "coastal_pressure_diagram_seen", "coastal_pressure_gauge_seen", "coastal_pressure_drain_seen",
		"coastal_pressure_inlet_closed", "coastal_pressure_bypass_open", "coastal_pressure_bleeder_open", "coastal_works_record_found", "coastal_pressure_route_verified"
	]:
		GameState.opening_flags[flag] = true
	GameState.opening_flags.beach_headlights_on = false
	GameState.opening_flags.beach_parking_lights_on = false
	for flag in ["photo_taken", "pastry_shared", "knock_agreed", "entered_foyer", "meter_cover_open", "floor3_power"]:
		GameState.opening_flags[flag] = false
	GameState.opening_flags.ch6_intro_seen = true
	GameState.opening_switches = {"A":false, "B":false, "C":false}
	GameState.opening_items = {
		"multitool_pliers":1, "trip_map":1, "old_304_photo":1, "bunker_recording":1, "jiamin_phone":1,
		"gate_work_order":1, "ahhao_camera":1
	}
	GameState.bus_loop_state = {"successes":5, "anomaly":"", "cycle":5, "bell_pulled":false, "initialized":true, "next_cycle_pending":false}
	GameState.role_resources = {
		"dawen":{"stamina":100.0,"flashlight_battery":100.0},
		"ah_hao":{"stamina":100.0,"flashlight_battery":100.0},
		"jiamin":{"stamina":25.0,"flashlight_battery":0.0}
	}
	GameState.current_role = "dawen"
	GameState.current_room_id = "ch6_abandoned_vip"
	GameState.current_chapter_id = "ch6_abandoned_vip"
	GameState.pending_entry_id = "from_pressure_gallery"
	GameState.stamina = 100.0
	GameState.flashlight_battery = 100.0
	GameState.demo_pursuit = ""


func _checkpoint_payload() -> Dictionary:
	GameState.role_resources[GameState.current_role] = {"stamina":GameState.stamina,"flashlight_battery":GameState.flashlight_battery}
	return {
		"schema_version":OpeningCheckpoint.SCHEMA_VERSION, "rules_version":1,
		"profile":GameState.profile, "run_id":GameState.run_id,
		"current_chapter_id":GameState.current_chapter_id, "room_id":GameState.current_room_id,
		"entry_id":GameState.pending_entry_id, "flags":GameState.opening_flags.duplicate(true),
		"switches":GameState.opening_switches.duplicate(true), "items":GameState.opening_items.duplicate(true),
		"resources":{"stamina":GameState.stamina,"flashlight_battery":GameState.flashlight_battery},
		"active_role":GameState.current_role, "role_resources":GameState.role_resources.duplicate(true),
		"photo_file":"", "bus_loop_state":GameState.bus_loop_state.duplicate(true)
	}


func finish_ending_write(ending_flag: String) -> void:
	var main := OpeningCheckpoint.load_state(GameState.get_profile_path(), GameState.opening_scope())
	var before := OpeningCheckpoint.load_state(GameState.get_profile_path(), GameState.opening_scope(), "pre_ending_checkpoint")
	check(GameState.opening_flags.get(ending_flag, false), "selected ending is recorded in memory")
	check(main.ok and main.data.flags.get(ending_flag, false), "selected ending is saved as the main checkpoint")
	check(before.ok and not before.data.flags.ending_missing and not before.data.flags.ending_escape and not before.data.flags.ending_truth, "separate checkpoint keeps the state before the ending")
	print("ENDING WRITE %s checks=%d failures=%d" % [ending_flag, checks, failures])
	get_tree().paused = false
	get_tree().quit(0 if failures == 0 else 1)


func run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_prepare_state()
	GameState.opening_flags.ch6_intro_seen = false
	if "--reduced-flash" in OS.get_cmdline_user_args():
		GameState.set_reduced_flash(true)
	AudioManager.world_effect_requested.connect(func(effect_id: String):
		world_cues.append(effect_id)
		if effect_id == "metal_cover" and is_instance_valid(scene) and scene.signal_response_active:
			response_beat_labels.append(scene.hud.state_text.text)
	)
	for sound_id in ["metal_cover", "power_switch", "gate_iron"]:
		var stream := load(AudioManager.WORLD_SOUNDS[sound_id]) as AudioStream
		check(stream != null and stream.get_length() > 0.0, "finale world sound decodes: " + sound_id)
	var packed := load("res://levels/ch6_abandoned_vip/abandoned_vip_rescue_061.tscn") as PackedScene
	check(packed != null, "final rescue scene loads from the room registry")
	scene = packed.instantiate()
	add_child(scene)
	await wait_frames(3)
	if "--save-failure" in OS.get_cmdline_user_args():
		check(GameState.opening_checkpoint_enabled(), "persistent test profile enabled")
		GameState.opening_flags.photo_taken = true
		GameState.opening_photo = null
		GameState.opening_photo_file = ""
		scene.checkpoint()
		check("保存失败" in scene.hud.defense_notice.text, "failed checkpoint reports error")
		get_tree().paused = false
		get_tree().quit(1 if failures else 0)
		return
	scene.player.aim_override = true
	var opening_speaker := scene.hud.panel_content.get_child(0) as Label
	var opening_portrait := scene.hud.panel_content.get_child(2) as TextureRect
	var portrait_atlas := opening_portrait.texture as AtlasTexture
	check(opening_speaker.text == "黄嘉敏", "Jiamin speaks in her own opening scene")
	check(portrait_atlas != null and portrait_atlas.atlas.resource_path.ends_with("jiamin_006.png"), "Jiamin opening scene shows her own portrait")
	# The fade lasts 0.65 seconds; frame count varies with renderer and load.
	await get_tree().create_timer(0.9, true).timeout
	await wait_frames(2)
	check(scene.hud.panel_open and get_tree().paused, "opening dialogue remains paused while the room fades in")
	check(scene.get_node_or_null("RescueRoomFadeLayer") == null, "fade completes without hiding the opening dialogue")
	await close_panel()
	check(scene.player.appearance == "jiamin", "chapter starts by controlling Jiamin")
	var phone_event := InputEventAction.new()
	phone_event.action = "phone"
	phone_event.pressed = true
	Input.parse_input_event(phone_event)
	await wait_frames(3)
	check(not scene.hud.panel_open, "Jiamin cannot access the phone left behind in 304")
	check(scene.player.sprite.sprite_frames.get_frame_count("0") == 6 and scene.player.sprite.sprite_frames.get_frame_count("7") == 6, "Jiamin walk atlas loads all eight six-frame directions")
	check(not scene.player.allow_flashlight and not scene.player.flashlight_on, "Jiamin has no usable flashlight")
	event_action("move_left", true)
	for _frame in range(240):
		await get_tree().physics_frame
	event_action("move_left", false)
	await wait_frames(3)
	check(scene.player.position.x >= 18.0 and scene.player.position.x < 80.0, "Jiamin moves to the visible left boundary without crossing it")

	await walk_to(Vector2(220, 620))
	await walk_to(Vector2(220, 510))
	await walk_to(Vector2(224, 510))
	await interact_by_input("pipe_item", Vector2(224, 510))
	check(GameState.opening_flags.ch6_jiamin_pipe_found, "E picks up the steel pipe in the device bay")
	await close_panel()
	await walk_to(Vector2(250, 248))
	await interact_by_input("jiamin_signal_pipe", Vector2(250, 248))
	await wait_frames(20)
	check(is_instance_valid(scene.pipe_action) and not GameState.opening_flags.ch6_signal_sent, "approaching the pipe leaves the three knocks to the player")
	for _strike in range(3):
		await tap_space()
		await wait_frames(18)
	check(GameState.opening_flags.ch6_signal_sent and GameState.opening_flags.ch6_pipe_route_verified and GameState.opening_flags.ch6_live_signal_received and GameState.current_role == "dawen", "Jiamin's 3 knocks immediately verify her signal and hand control to Daven")
	check(scene.player.appearance == "flashlight", "Daven receives his correct walking appearance after the role swap")
	await close_panel()
	Input.parse_input_event(phone_event.duplicate())
	await wait_frames(3)
	check(scene.hud.panel_open and scene.hud.default_phone_widget != null and get_tree().paused, "Daven can open the recovered phone in the finale")
	Input.parse_input_event(phone_event.duplicate())
	await wait_frames(3)
	check(not scene.hud.panel_open and not get_tree().paused and scene.player.controls_enabled, "closing the finale phone restores world controls")

	check(not scene._target_available("branch_a") and not scene._target_available("branch_b"), "fake-echo branches A and B are removed from interaction")
	check(scene._target_available("illusion_door"), "bleeding illusion door is available before rescuing Jiamin")
	await walk_to(Vector2(365, 620))
	await walk_to(Vector2(365, 525))
	await interact_by_input("illusion_door", Vector2(342, 525))
	check(GameState.opening_flags.ch6_failed_echo_seen and scene.hud.panel_open, "inspecting the illusion door records the temptation event and opens its choice dialogue")
	if "--ending-write=missing" in OS.get_cmdline_user_args():
		scene._select_missing_ending()
		finish_ending_write("ending_missing")
		return
	await close_panel()

	await walk_to(Vector2(742, 620))
	await walk_to(Vector2(742, 415))
	await interact_by_input("route_diagram", Vector2(742, 388))
	check(GameState.opening_flags.ch6_route_diagram_seen, "pipe diagram and chalk evidence are recorded")
	await close_panel()

	GameState.opening_items.erase("ahhao_camera")
	check(not scene._archive_rows()[0].found, "Ah Hao's death flag alone cannot replace his personal record")
	GameState.opening_items["ahhao_camera"] = 1
	check(not scene._archive_rows()[1].found, "ordinary gate work order and bunker recording are not the underground works register")
	scene._read_venue_record()
	scene._read_bunker_register()
	check(GameState.opening_flags.ch6_bunker_register_found, "fictional underground works register is collected from the archive pouch")
	await close_panel()
	scene._read_venue_record()
	scene._read_stopwork_record()
	check(GameState.opening_flags.ch6_venue_stopwork_found, "fictional venue stop-work record is collected separately")
	await close_panel()
	scene._confirm_circuit_isolation()
	check(GameState.opening_flags.ch6_circuit_isolated, "old echo feed is isolated before induction")
	await close_panel()
	await walk_to(Vector2(1024, 405))
	await interact_by_input("lure_switch", Vector2(1024, 392))
	check(GameState.opening_flags.ch6_entity_lured and is_instance_valid(scene.shadow), "verified branch starts the animated lure sequence")
	await close_panel()
	check(scene.shadow.get_node("Figure").is_playing(), "lured shadow uses its moving animation")
	check(scene.shadow.target == scene.player, "the isolated test uses the same player chase as the normal game")
	scene._lock_entity()
	check(not GameState.opening_flags.ch6_entity_bound, "the lever rejects a pull while the wraith is outside the drawn grate")
	for _frame in range(150):
		if scene.boss_in_trap_zone:
			break
		await get_tree().physics_frame
	check(scene.boss_in_trap_zone, "standing beyond the grate draws the chasing wraith onto it")
	await walk_to(Vector2(976, 446))
	await interact_by_input("lock_lever", Vector2(936, 488))
	await wait_frames(4)
	check(GameState.opening_flags.ch6_entity_bound and scene.scene_action_active, "mechanical lock begins only inside the coil zone")
	var shadow_scale: Vector2 = scene.shadow.scale
	scene._pause_menu()
	await wait_frames(35)
	check(scene.scene_action_active and is_instance_valid(scene.shadow) and scene.shadow.scale.is_equal_approx(shadow_scale), "pause freezes the shadow capture animation")
	await close_panel()
	check(not scene.player.controls_enabled, "movement stays locked while capture resumes")
	await wait_frames(35)
	check(not scene.scene_action_active and not is_instance_valid(scene.shadow) and scene.player.controls_enabled and "锁住了" in scene.hud.defense_notice.text, "shadow capture restores control and gives short feedback")
	await close_panel()
	check(is_instance_valid(scene.locked_door_body) and is_instance_valid(scene.locked_door_occluder), "closed rescue door has collision and a matching light occluder")
	if "--rescue-interrupted-write" in OS.get_cmdline_user_args():
		scene._open_rescue_door()
		await wait_frames(2)
		var interrupted := OpeningCheckpoint.load_state(GameState.get_profile_path(), GameState.opening_scope())
		check(interrupted.ok and interrupted.data.flags.ch6_rescue_door_open and not interrupted.data.flags.ch6_jiamin_rescued, "checkpoint captures interruption after the door opens and before the rescue")
		print("RESCUE INTERRUPTED WRITE checks=%d failures=%d" % [checks, failures])
		get_tree().paused = false
		get_tree().quit(0 if failures == 0 else 1)
		return
	await scene._open_rescue_door()
	check(GameState.opening_flags.ch6_rescue_door_open and GameState.opening_flags.ch6_jiamin_rescued, "door opening completes the physical rescue")
	check(not is_instance_valid(scene.locked_door_body) and not is_instance_valid(scene.locked_door_occluder), "opened rescue door removes both collision and light occlusion")
	check(GameState.opening_flags.pre_ending_checkpoint and is_instance_valid(scene.rescued_jiamin), "rescue creates the pre-ending checkpoint and Jiamin actor")
	check(not scene._target_available("illusion_door"), "bleeding illusion door is no longer available after rescuing Jiamin")
	await close_panel()
	await get_tree().create_timer(0.82, true).timeout
	await close_panel()
	check(scene._all_archives_verified(), "five story archives are recognized without blocking rescue")
	GameState.opening_flags.ch6_bunker_register_found = false
	GameState.opening_flags.ch6_venue_stopwork_found = false
	scene.interact_target("venue_archive")
	check(scene.hud.panel_open and scene.hud.choice_buttons.size() == 3 and scene.hud.choice_buttons[0].text == "决定如何撤离", "rescue archive offers departure even with both local files unread")
	if scene.hud.choice_buttons.size() > 0:
		scene.hud.choice_buttons[0].pressed.emit()
	check(scene.hud.panel_open and scene.hud.choice_buttons.size() > 0 and scene.hud.choice_buttons[0].text == "现在带嘉敏撤离", "ordinary escape remains selectable through the real archive interaction")
	await close_panel()
	GameState.opening_flags.ch6_bunker_register_found = true
	GameState.opening_flags.ch6_venue_stopwork_found = true

	var payload := _checkpoint_payload()
	var decoded := OpeningCheckpoint.decode(JSON.stringify(payload), GameState.opening_scope())
	if decoded.is_empty():
		print("CHECKPOINT_DIAGNOSTIC scope=%s chapter=%s room=%s entry=%s role=%s flags=%s items=%s" % [str(GameState.opening_scope()), str(payload.current_chapter_id), str(payload.room_id), str(payload.entry_id), str(payload.active_role), str(payload.flags), str(payload.items)])
	check(not decoded.is_empty() and decoded.room_id == "ch6_abandoned_vip" and decoded.entry_id == "from_pre_ending", "pre-ending checkpoint round-trips with its entry ID")
	var test_base := "res://.godot/ch6_test_saves/%d/" % Time.get_ticks_usec()
	var saved_to_disk := OpeningCheckpoint.save_state(test_base, payload, GameState.opening_scope())
	var disk_result := OpeningCheckpoint.load_state(test_base, GameState.opening_scope())
	check(saved_to_disk and disk_result.ok and disk_result.data.entry_id == "from_pre_ending", "checkpoint writes and reloads from the isolated test directory")
	var absolute_test_base := ProjectSettings.globalize_path(test_base)
	for filename in ["opening_checkpoint.json", "opening_checkpoint.tmp.json", "opening_checkpoint.bak.json"]:
		var absolute_file: String = absolute_test_base.path_join(filename)
		if FileAccess.file_exists(absolute_file):
			DirAccess.remove_absolute(absolute_file)
	if DirAccess.dir_exists_absolute(absolute_test_base):
		DirAccess.remove_absolute(absolute_test_base)
	var invalid_truth_payload: Dictionary = payload.duplicate(true)
	invalid_truth_payload.flags.ending_truth = true
	invalid_truth_payload.flags.ch6_venue_stopwork_found = false
	check(OpeningCheckpoint.decode(JSON.stringify(invalid_truth_payload), GameState.opening_scope()).is_empty(), "checkpoint codec rejects a truth ending with a missing story archive")
	GameState.pending_entry_id = "from_pre_ending"
	payload = _checkpoint_payload()
	decoded = OpeningCheckpoint.decode(JSON.stringify(payload), GameState.opening_scope())
	check(not decoded.is_empty() and decoded.entry_id == "from_pre_ending", "pre-ending checkpoint entry is accepted")

	scene._open_ending_choices()
	check(scene.hud.panel_open, "ending choices open only after the rescue checkpoint")
	await close_panel()
	if "--ending-write=escape" in OS.get_cmdline_user_args():
		await scene._select_escape_ending()
		finish_ending_write("ending_escape")
		return
	if "--ending-write=truth" in OS.get_cmdline_user_args():
		await scene._select_truth_ending()
		finish_ending_write("ending_truth")
		return
	GameState.opening_flags.ending_missing = true
	scene._show_ending("ending_missing")
	check(GameState.opening_flags.ending_missing and scene.hud.panel_open, "missing ending has its own explicit ending card")
	await close_panel()
	GameState.opening_flags.ending_missing = false
	await scene._select_escape_ending()
	check(GameState.opening_flags.ending_escape, "ordinary rescue ending remains available without archive completion")
	await close_panel()
	GameState.opening_flags.ending_escape = false
	await scene._select_truth_ending()
	check(GameState.opening_flags.ending_truth, "truth ending requires and accepts all five verified story archives")
	await close_panel()
	if "--checkpoint-profile-write" in OS.get_cmdline_user_args():
		if "--checkpoint-profile-photo" in OS.get_cmdline_user_args():
			var profile_image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
			profile_image.fill(Color("714f38"))
			GameState.opening_flags.photo_taken = true
			GameState.opening_photo = ImageTexture.create_from_image(profile_image)
			GameState.opening_photo_file = ""
		check(GameState.save_opening_checkpoint(), "valid chapter six checkpoint writes through the selected profile path")

	print("CH6_RESCUE_061 checks=%d failures=%d" % [checks, failures])
	get_tree().paused = false
	get_tree().quit(0 if failures == 0 else 1)
