extends Node

var checks := 0
var failed := false
var bus: Node2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(40.0, true).timeout.connect(func():
		push_error("Bus story regression timed out.")
		get_tree().quit(2)
	)
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	failed = failed or not value

func frames(count := 4) -> void:
	for _i in range(count):
		await get_tree().process_frame

func close() -> void:
	bus._on_hud_close()

func inspect(id: String) -> void:
	bus.inspect_story(id)
	await frames()
	check(bus.observed.has(id) and bus.hud.panel_open, "inspect_" + id)
	close()

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(3)
	await RenderingServer.frame_post_draw
	var screenshot := get_tree().root.get_texture().get_image()
	check(screenshot.save_png("res://docs/build_reports/" + name + ".png") == OK, "capture_" + name)

func run() -> void:
	check(GameState.profile == "test", "test_profile")
	GameState.reset_opening()
	GameState.opening_resume_checked = true
	bus = load("res://levels/ch4_bus/bus_story.tscn").instantiate()
	get_tree().root.add_child(bus)
	get_tree().current_scene = bus
	await frames(12)
	check(bus.stage == 0 and bus.passenger.visible and bus.reflection.visible, "teaching_has_real_passenger_and_reflection")
	check(bus.player.visual_size_multiplier == 3.1, "adult_player_scale_matches_bus_seat_backs")
	bus.player.position = Vector2(550, 258)
	await frames(12)
	await shot("bus_passenger_scale_035")
	bus.resolve_judgment("bell_cord")
	check(bus.stage == 0 and bus.premature_bell_warned, "premature_bell_warns_without_failure")
	close()
	for id in ["seat", "glass", "mirror", "display", "sign"]:
		await inspect(id)
	bus.inspect_story("glass")
	await shot("bus_teaching_glass_034")
	close()
	bus.resolve_judgment("continue")
	check(bus.is_transitioning and not bus.player.controls_enabled, "passenger_departure_locks_input")
	await get_tree().create_timer(2.1, true).timeout
	check(bus.walking_passenger.walking and bus.walking_passenger.mesh.polygon != bus.walking_passenger.rest_vertices, "passenger_walk_deforms_leg_mesh_continuously")
	await shot("bus_passenger_walking_037")
	await get_tree().create_timer(6.0, true).timeout
	check(bus.stage == 1 and GameState.opening_flags.bus_taught, "teaching_advances_after_visible_departure")
	check(not bus.passenger.visible and bus.reflection.visible, "reflection_persists_after_seat_empties")
	for id in ["seat", "glass", "notebook"]:
		await inspect(id)
	bus.inspect_story("glass")
	await shot("bus_empty_seat_reflection_034")
	close()
	bus.resolve_judgment("bell_cord")
	await get_tree().create_timer(0.32, true).timeout
	var rig: Control = bus.scare_rig
	check(rig != null and rig.rig.get_bone_count() == 3, "lunge_uses_independent_head_and_arm_bones")
	var collar_bottom: Vector2 = rig.normal_face.to_global(Vector2(0, 320))
	check(collar_bottom.y > rig.get_viewport_rect().end.y, "passenger_collar_continues_below_anticipation_frame")
	var animation_position: float = rig.animation_player.current_animation_position
	get_tree().paused = true
	await get_tree().create_timer(0.25, true).timeout
	check(is_equal_approx(animation_position, rig.animation_player.current_animation_position), "pause_freezes_lunge_and_impact_clock")
	get_tree().paused = false
	await shot("bus_lunge_anticipation_035")
	await get_tree().create_timer(0.26, true).timeout
	await shot("bus_lunge_reach_035")
	await get_tree().create_timer(1.5, true).timeout
	check(bus.stage == 1 and bus.observed.size() >= 3, "wrong_round_keeps_progress_and_evidence")
	close()
	bus.player.position = Vector2(866, 258)
	await get_tree().create_timer(3.1, true).timeout
	check(bus.stage == 2 and GameState.opening_flags.bus_reflection_cleared, "front_grip_wait_advances_reflection_round")
	for id in ["display", "sign", "door", "notebook"]:
		await inspect(id)
	bus.inspect_story("display")
	await frames(3)
	var comparison: Control = bus.story_widget.find_child("*", true, false)
	for child in bus.story_widget.get_children():
		for nested in child.get_children():
			if nested.get_script() == preload("res://ui/tape_comparison_view.gd"):
				comparison = nested
	check(comparison.get_script() == preload("res://ui/tape_comparison_view.gd") and comparison.samples.size() == 128, "comparison_waveform_comes_from_decoded_audio")
	comparison.play_track(0)
	check(comparison.active_track == 0 and comparison.sound.stream.get_length() > 1.0, "old_attachment_plays_in_reading_modal")
	comparison.play_track(1)
	check(comparison.active_track == 1, "current_bus_recording_can_be_compared")
	comparison.confirm_match()
	check(not bus.observed.has("recording_matched"), "unaligned_recordings_cannot_be_confirmed")
	comparison.trim_slider.value = 0.22
	comparison.confirm_match()
	check(comparison.confirmed and bus.observed.has("recording_matched"), "aligning_audio_breaks_records_old_playback_evidence")
	await shot("bus_old_voice_comparison_034")
	close()
	bus.resolve_judgment("continue")
	await get_tree().create_timer(1.0, true).timeout
	check(bus.stage == 3 and GameState.opening_flags.bus_voice_cleared, "old_voice_round_uses_current_sign_and_door")
	for id in ["seat", "glass", "mirror", "display", "sign"]:
		await inspect(id)
	bus.resolve_judgment("bell_cord")
	await get_tree().create_timer(0.3, true).timeout
	var opening_progress: float = bus.front_door.openness
	bus._on_hud_pause()
	await get_tree().create_timer(0.25, true).timeout
	check(is_equal_approx(opening_progress, bus.front_door.openness) and not bus.front_door.audio.can_process(), "pause_freezes_folding_door_and_pneumatic_audio")
	close()
	check(not bus.player.controls_enabled, "closing_pause_does_not_unlock_player_during_door_motion")
	await get_tree().create_timer(0.7, true).timeout
	check(bus.bell_requested and not GameState.opening_flags.bus_arrived, "bell_alone_does_not_complete_arrival")
	check(bus.departure_ready and bus.front_door.collision.disabled and not bus.front_door.occluder.visible, "opened_folding_door_has_clear_physical_passage")
	bus.player.position = Vector2(1133, 272)
	await frames(12)
	await shot("bus_open_folding_door_037")
	bus.player.position = Vector2(1133, 220)
	await frames(3)
	check(GameState.opening_flags.bus_arrived and bus.hud.panel_open, "door_after_verified_bell_completes_arrival")
	await shot("bus_verified_arrival_034")
	get_tree().paused = false
	bus.queue_free()
	await frames(5)
	OS.delay_msec(100)
	await frames(3)
	print("BUS_STORY_RESULT checks=%d failed=%s" % [checks, str(failed)])
	get_tree().quit(1 if failed else 0)
