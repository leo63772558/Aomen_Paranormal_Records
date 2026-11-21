extends Node

var checks := 0
var failed := false
var scene

func _ready() -> void:
	get_tree().create_timer(45.0, true).timeout.connect(func(): get_tree().quit(2))
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	failed = failed or not value
	print(("PASS " if value else "FAIL ") + label)

func frames(count := 4) -> void:
	for _i in range(count): await get_tree().process_frame

func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames()
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png("res://docs/build_reports/" + label + ".png") == OK, label)

func run() -> void:
	check(GameState.profile == "test", "isolated_profile")
	GameState.reset_opening()
	GameState.opening_resume_checked = true
	GameState.current_room_id = "ch0_ah_kin"
	GameState.pending_entry_id = "from_foyer"
	GameState.opening_flags.entered_foyer = true
	GameState.opening_flags.floor3_power = true
	GameState.stamina = 61.0
	scene = load("res://levels/ch0_tanglau/ahhao_sequence_v5.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await frames(10)
	if "--save-failure" in OS.get_cmdline_user_args():
		check(GameState.opening_checkpoint_enabled(), "persistent test profile enabled")
		GameState.opening_flags.photo_taken = true
		GameState.opening_photo = null
		GameState.opening_photo_file = ""
		scene.checkpoint()
		check("保存失败" in scene.hud.defense_notice.text, "failed checkpoint reports error")
		get_tree().paused = false
		get_tree().quit(1 if failed else 0)
		return
	check(GameState.current_role == "ah_hao" and GameState.stamina == 100.0, "role_changes_without_consuming_dawen_stamina")
	check(scene.player.appearance == "ah_hao" and scene.hud.panel_open, "distinct_ahhao_sprite_and_intro")
	await shot("ahhao_intro_043")
	scene._close_panel()
	await frames()
	scene.player.position = Vector2(520, 260)
	await shot("ahhao_breaker_043")
	scene._throw_breaker()
	await get_tree().create_timer(1.2, true).timeout
	check(scene.phase == "ah_chase" and GameState.opening_flags.ah_hao_breaker_done, "animated_switch_starts_chase")
	scene.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var focused_out_monster_position: Vector2 = scene.monster.position
	await frames(15)
	check(get_tree().paused and scene.hud.panel_open and scene.monster.position == focused_out_monster_position, "focus_loss_pauses_active_chase")
	scene._close_panel()
	check(not get_tree().paused and scene.player.controls_enabled and scene.phase == "ah_chase", "resuming_focus_pause_restores_chase")
	var switch_rotation: float = scene.switch_arm.rotation
	scene._pause()
	var monster_position: Vector2 = scene.monster.position
	await frames(15)
	check(scene.monster.position == monster_position and scene.switch_arm.rotation == switch_rotation, "pause_freezes_chase_and_hardware")
	scene._close_panel()
	scene.player.position = Vector2(98, 260)
	scene._escape_ah()
	await get_tree().create_timer(0.8, true).timeout
	check(scene.phase == "reunion" and GameState.opening_flags.ah_hao_escaped, "first_escape_reaches_reunion")
	await shot("ahhao_reunion_043")
	scene._close_panel()
	await get_tree().create_timer(2.4, true).timeout
	check(GameState.opening_flags.ah_hao_dead and GameState.current_role == "dawen", "ambush_commits_role_change")
	check(GameState.has_demo_item("ahhao_camera"), "visible_retrieval_retains_ahhao_camera")
	check(is_equal_approx(GameState.stamina, 61.0), "dawen_stamina_restored")
	await shot("ahhao_fallen_043")
	scene._close_panel()
	await frames()
	check(scene.phase == "dawen_flee" and scene.player.appearance == "flashlight", "dawen_is_playable_after_loss")
	check(scene.get_node_or_null("AhHaoFallenBodyCollision") != null, "fallen_body_has_collision")
	await shot("dawen_escape_043")
	scene.player.position = Vector2(478, 270)
	scene._finish()
	check(GameState.opening_flags.dawen_304_escape_done and not GameState.opening_flags.jiamin_phone_found, "door_reached_without_silent_phone_grant")
	# Leave the transition to a separate natural-route test; preserve this fixture root.
	scene.after_panel = Callable()
	scene._close_panel()
	scene.queue_free()
	await frames(8)
	OS.delay_msec(100)
	await frames(3)
	print("AHHAO V5: %d checks, failed=%s" % [checks, failed])
	get_tree().quit(1 if failed else 0)
