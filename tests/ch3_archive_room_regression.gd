extends Node

var checks := 0
var failed := false

func _enter_tree() -> void:
	if DisplayServer.get_name() != "headless":
		get_window().set_flag(Window.FLAG_NO_FOCUS, true)
		get_window().position = Vector2i(-32000, -32000)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	print(("PASS " if condition else "FAIL ") + label)
	failed = failed or not condition

func _settle(frames: int = 4) -> void:
	for _i in range(frames):
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP hidden viewport capture in headless-only regression: " + name)
		return
	await _settle(3)
	var image := get_tree().root.get_texture().get_image()
	_check(image != null and not image.is_empty(), name + " hidden render exists")
	if image != null and not image.is_empty():
		_check(image.save_png("res://docs/build_reports/" + name + ".png") == OK, name + " screenshot saved")

func _check_checkpoint_migration() -> void:
	var flags := OpeningCheckpoint.default_flags()
	flags["demo_case_closed"] = true
	flags["ammo_chase_cleared"] = true
	for name in ["ch3_photo_seen", "ch3_register_seen", "ch3_delivery_seen", "ch3_visitor_log_seen"]:
		flags[name] = true
	flags["ch3_guest_inferred"] = true
	flags["ch3_cold_door_seen"] = true
	flags["ch3_balance_solved"] = true
	flags["ch3_key_found"] = true
	flags["ch3_ticket_found"] = true
	flags.erase("ch3_balance_rule_seen")
	var old_data := {
		"schema_version":2,
		"rules_version":1,
		"profile":"test",
		"run_id":"legacy_ch3",
		"current_chapter_id":"ch3_amparo_alley",
		"room_id":"ch3_amparo_archive",
		"entry_id":"from_bunker",
		"flags":flags,
		"switches":OpeningCheckpoint.SWITCHES.duplicate(true),
		"items":{"multitool_pliers":1, "bunker_recording":1},
		"resources":{"stamina":100.0, "flashlight_battery":100.0},
		"photo_file":""
	}
	var migrated := OpeningCheckpoint.decode(JSON.stringify(old_data), {"profile":"test", "run_id":"legacy_ch3"})
	_check(migrated.items.has("archive_spare_key") and migrated.items.has("w17_bus_ticket") and migrated.items.has("laochen_handoff_note"), "legacy_autocollected_items_and_note_migrate")
	_check(not migrated.is_empty() and migrated.flags.ch3_balance_rule_seen, "已解开的旧档迁移时保留秤账规则进度")

func _run() -> void:
	if GameState.profile != "test":
		push_error("Archive regression requires the test profile.")
		get_tree().quit(2)
		return
	if "--archive-resume-qa" in OS.get_cmdline_user_args():
		await _read_saved_archive()
		return
	_check_checkpoint_migration()
	GameState.reset_opening()
	# This branch deliberately builds a chapter fixture; the resume branch above
	# loads a real prior process instead. Do not reload the new-opening reset here.
	GameState.opening_resume_checked = true
	GameState.current_room_id = "ch3_amparo_archive"
	GameState.current_chapter_id = "ch3_amparo_alley"
	GameState.pending_entry_id = "from_bunker"
	GameState.opening_flags.demo_case_closed = true
	GameState.opening_flags.ammo_chase_cleared = true
	GameState.opening_items["bunker_recording"] = 1

	var packed := load("res://levels/ch3_amparo_alley/archive_room.tscn") as PackedScene
	_check(packed != null, "第三章资料室场景可加载")
	if packed == null:
		get_tree().quit(1)
		return
	var room := packed.instantiate()
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	await _settle(24)
	if "--save-failure" in OS.get_cmdline_user_args():
		_check(GameState.opening_checkpoint_enabled(), "persistent test profile enabled")
		GameState.opening_flags.photo_taken = true
		GameState.opening_photo = null
		GameState.opening_photo_file = ""
		room.checkpoint()
		_check("保存失败" in room.hud.defense_notice.text, "failed checkpoint reports error")
		get_tree().paused = false
		get_tree().quit(1 if failed else 0)
		return

	var player := room.get("player") as PlayerController
	var hud: CanvasLayer = room.get("hud")
	_check(player != null and hud != null, "玩家与 HUD 已创建")
	if player == null or hud == null:
		get_tree().quit(1)
		return
	_check(room.get_node_or_null("FourPersonArchivePhoto") is Sprite2D, "四人旧照已放入桌面相框")
	var photo := room.get_node("FourPersonArchivePhoto") as Sprite2D
	var photo_ratio := (photo.texture.get_width() * photo.scale.x) / (photo.texture.get_height() * photo.scale.y)
	_check(absf(photo_ratio - 1.5) < 0.001, "旧照显示保持 3:2 比例")
	_check(photo.position.distance_to(Vector2(367, 92)) < 0.01, "照片中心与可见相框位置一致")
	_check(is_equal_approx(room.get("warm_lamp").position.y, 34.0), "吊灯光源落在画面灯泡位置")
	_check((room.find_children("*", "StaticBody2D", true, false).size() >= 8), "房间边界、柜台、玻璃柜和冷柜门均有实体碰撞")
	var hotspots: Dictionary = room.get("hotspots")
	_check(not hotspots["archive_key"].visible and not hotspots["w17_ticket"].visible, "items_hidden_until_scale_solved")
	_check(DemoItems.texture("archive_spare_key") != null and DemoItems.texture("w17_bus_ticket") != null, "inventory_icons_load")
	var key_area := hotspots["archive_key"] as Area2D
	var key_collision_node := key_area.get_node_or_null("InteractionShape") as CollisionShape2D
	var key_collision := key_collision_node.shape as CircleShape2D if key_collision_node != null else null
	_check(key_area.collision_layer == 8 and key_area.collision_mask == 0 and key_collision != null and key_collision.radius >= 15.0, "pickup_interaction_area_is_reachable_and_nonblocking")
	_check(hotspots.size() == 10, "ten_interactions_include_jiamin_lens_cap")
	_check(hotspots.has("balance_rule") and hotspots["balance_rule"].position == Vector2(278, 108), "秤账背页有单独且可见的交互点")
	var weight_audio := load("res://assets/audio/recorded/ch3_balance_weight.wav") as AudioStreamWAV
	var settle_audio := load("res://assets/audio/recorded/ch3_balance_settle.wav") as AudioStreamWAV
	var key_pickup_audio := load("res://assets/audio/recorded/archive_key_pickup.wav") as AudioStreamWAV
	var ticket_pickup_audio := load("res://assets/audio/recorded/archive_ticket_pickup.wav") as AudioStreamWAV
	_check(key_pickup_audio != null and not key_pickup_audio.data.is_empty(), "key_pickup_audio_loads")
	_check(ticket_pickup_audio != null and not ticket_pickup_audio.data.is_empty(), "ticket_pickup_audio_loads")
	_check(weight_audio != null and not weight_audio.data.is_empty(), "砝码金属碰撞音频资源可解码")
	_check(settle_audio != null and not settle_audio.data.is_empty(), "秤梁与柜锁回落音频资源可解码")
	if hud.panel_open:
		room.call("close_dialog")
	await _settle()
	await _capture("ch3_archive_room_031")
	# Walk to the counter's front edge using ordinary input; its collision should stop passage.
	Input.action_press("move_up")
	for _i in range(110):
		await get_tree().physics_frame
	Input.action_release("move_up")
	_check(player.position.y >= 179.0 and player.position.y <= 200.0, "柜台碰撞阻止人物穿入台面")
	Input.action_press("move_right")
	for _i in range(46):
		await get_tree().physics_frame
	Input.action_release("move_right")
	player.aim_override = true
	player.look_dir = (Vector2(367, 92) - player.position).normalized()
	room.call("_process", 1.0 / 60.0)
	_check(room.get("selected_id") == "photo", "站在柜台前可面向并选中照片，不需穿过家具")
	_check(hud.prompt.text.contains("旧合照"), "实际交互提示对应照片对象")

	# A locked rule page before solving the resident record discrepancy cannot set progress.
	room.call("interact_target", "balance_rule")
	_check(GameState.opening_flags.ch3_balance_rule_seen, "秤账可合理调查，不强制完成旧住户历史推理")
	room.call("close_dialog")
	var evidence_flags := {
		"photo":"ch3_photo_seen",
		"resident_register":"ch3_register_seen",
		"delivery_letter":"ch3_delivery_seen",
		"visitor_log":"ch3_visitor_log_seen"
	}
	for target in ["photo", "resident_register", "delivery_letter", "visitor_log"]:
		room.call("interact_target", target)
		_check(GameState.opening_flags[evidence_flags[target]], target + " 留下调查记录")
		room.call("close_dialog")
		await _settle(2)
		if target == "resident_register":
			_check(GameState.has_demo_item("jiamin_severed_finger"), "检查血盆发现并收起嘉敏带尾戒断指")
			if hud.panel_open:
				room.call("close_dialog")
				await _settle(2)
	_check(not GameState.opening_flags.ch3_guest_inferred and hud.choice_buttons.size() == 3, "四份证据后显示竖排推理选项")
	if hud.choice_buttons.size() >= 3:
		var choices_clear := true
		for index in range(hud.choice_buttons.size() - 1):
			var upper: Button = hud.choice_buttons[index]
			var lower: Button = hud.choice_buttons[index + 1]
			choices_clear = choices_clear and upper.position.y + upper.size.y <= lower.position.y
		_check(choices_clear, "推理选项按钮彼此不重叠")
	room.call("_accept_guest_hypothesis")
	_check(GameState.opening_flags.ch3_guest_inferred, "正确推理只将第四人暂列为访客")
	room.call("close_dialog")
	room.call("close_dialog")
	room.call("interact_target", "cold_door")
	_check(GameState.opening_flags.ch3_cold_door_seen, "推理后可检查铜牌锁孔并记录位置线索")
	room.call("close_dialog")
	room.call("interact_target", "balance_rule")
	_check(GameState.opening_flags.ch3_balance_rule_seen, "秤账背页给出半斤、三枚和饥寒条件")
	room.call("close_dialog")
	room.call("interact_target", "balance")
	var board := room.get("balance_board") as Control
	_check(board != null and board.get_child_count() > 0, "实物杆秤谜题面板已打开")
	if board == null:
		get_tree().quit(1)
		return
	await _settle(8)
	await _capture("ch3_balance_board_031")
	var buttons: Array = board.get("cards")
	_check(buttons.size() == 4, "四枚不同砝码各自只有一个操作按钮")
	var left_pan := board.get("left_pan") as Node2D
	var right_pan := board.get("right_pan") as Node2D
	_check(left_pan.rotation == 0.0 and right_pan.rotation == 0.0 and right_pan.get_child_count() == 2, "两侧秤盘保持竖直，右盘显示实体定砣")
	for index in [1, 2, 3]:
		board.call("_toggle_weight", index)
	board.call("submit_weight")
	_check(String(board.get("status_label").text).contains("偏重"), "错误砝码使秤梁反馈实际偏重")
	_check(not GameState.opening_flags.ch3_balance_solved, "错误组合可取回重放且不结算")
	_check(AudioManager.last_world_effect == "balance_weight", "错误称量触发砝码金属声")
	_check(AudioManager.world_effects.process_mode == Node.PROCESS_MODE_ALWAYS, "谜题反馈音在暂停界面期间仍可完成播放")
	await _settle(12)
	_check(absf((board.get("beam_pivot") as Node2D).rotation) > 0.08, "偏重反馈通过秤梁动画清楚可见")
	board.call("clear_weights")
	for index in [0, 1, 2]:
		board.call("_toggle_weight", index)
	board.call("submit_weight")
	room.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await get_tree().create_timer(0.75, true).timeout
	_check(not GameState.opening_flags.ch3_balance_solved, "focus loss freezes uncommitted scale success")
	room.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	board.emit_signal("close_requested")
	_check(is_instance_valid(room.balance_board) and hud.panel_open and get_tree().paused, "正确称重后的动画期间返回不会取消开柜")
	await get_tree().create_timer(0.75, true).timeout
	await _settle()
	_check(GameState.opening_flags.ch3_balance_solved, "饥寒贪三枚八两的唯一组合开柜")
	_check(not GameState.opening_flags.ch3_key_found and not GameState.opening_flags.ch3_ticket_found, 'items_not_auto_collected')
	_check(hotspots['archive_key'].visible and hotspots['w17_ticket'].visible, 'physical_items_appear')
	var key_visual: Node2D = hotspots['archive_key'].get_node('ArchiveSpareKeyVisual')
	var ticket_visual: Node2D = hotspots['w17_ticket'].get_node('W17TicketVisual')
	_check(key_visual.get_node_or_null('SquareCopperTag') is Sprite2D and ticket_visual.get_node_or_null('TicketPaper') is Sprite2D, 'item_art_present')
	_check(String(ticket_visual.get_node('TicketW17Mark').text) == '33', 'timetable_has_route_33_mark')
	_check(AudioManager.last_world_effect == "balance_settle", "成功开柜触发独立秤梁回落音效")
	_check(not get_tree().paused and not hud.panel_open and player.controls_enabled, "开柜后直接交还操作")
	room.call("close_dialog")
	_check(not get_tree().paused, "收起谜题与结果面板后世界暂停状态恢复")
	room.call("interact_target", "balance")
	_check("方牌备用钥匙" in "".join(hud.pages) and "还放着" in "".join(hud.pages), "opened_cabinet_reports_uncollected_items")
	room.call("close_dialog")
	player.position = Vector2(386, 181)
	player.aim_override = true
	player.look_dir = (Vector2(386, 117) - player.position).normalized()
	room.call("_process", 1.0 / 60.0)
	_check(room.get("selected_id") == "archive_key" and hud.prompt.text.contains("方牌备用钥匙"), "reachable_key_prompt")
	room.call("interact_target", room.get("selected_id"))
	_check(GameState.opening_flags.ch3_key_found and GameState.has_demo_item("archive_spare_key"), "key_pickup_updates_flag_and_inventory")
	_check(not hotspots["archive_key"].visible and hotspots["w17_ticket"].visible, "only_key_hides_after_pickup")
	_check(AudioManager.last_world_effect == "archive_key_pickup", "metallic_key_pickup_cue")
	_check(AudioManager.world_effects.process_mode == Node.PROCESS_MODE_ALWAYS, "key_cue_finishes_under_reading_panel")
	room.call("close_dialog")
	room.call("interact_target", "cold_door")
	_check(room.work_in_progress and not player.controls_enabled, "door opening locks player before animation completes")
	_check(AudioManager.last_world_effect == "gate_iron", "maintenance_door_uses_iron_gate_sound")
	room.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var frozen_alpha: float = room.cold_door_overlay.modulate.a
	await _settle(12)
	_check(get_tree().paused and hud.panel_open and is_equal_approx(room.cold_door_overlay.modulate.a, frozen_alpha), "focus loss freezes opening door animation")
	room.close_dialog(false)
	_check(not get_tree().paused and room.work_in_progress and not player.controls_enabled, "door animation retains control lock after resuming")
	await _settle(24)
	_check(GameState.opening_flags.ch3_cold_door_open, "key_opens_maintenance_door")
	_check((room.get("cold_door_overlay") as Sprite2D).visible, "opened_door_art_appears")
	_check((room.get("cold_door_collision") as CollisionShape2D).disabled, "opened_door_collision_is_removed")
	_check(not (room.get("cold_door_occluder") as LightOccluder2D).visible, "opened_door_no_longer_blocks_light")
	_check(not (room.get("opened_leaf_collision") as CollisionShape2D).disabled and (room.get("opened_leaf_occluder") as LightOccluder2D).visible, "swung_iron_leaf_retains_collision_and_shadow")
	_check(player.test_move(Transform2D(0.0, Vector2(565, 100)), Vector2(35, 0)), "painted_swung_leaf_blocks_player")
	_check(player.test_move(Transform2D(0.0, Vector2(550, 98)), Vector2(0, -75)), "the wall above the rear doorway blocks travel onto the lintel")
	room.call("close_dialog")
	player.look_dir = (Vector2(426, 117) - player.position).normalized()
	room.call("_process", 1.0 / 60.0)
	_check(room.get("selected_id") == "w17_ticket" and hud.prompt.text.contains("33"), "reachable_ticket_prompt")
	room.call("interact_target", room.get("selected_id"))
	_check(not GameState.opening_flags.ch3_ticket_found and hud.panel_open, "looking at the front leaves the note to discover")
	var flip := hud.panel_content.find_child("FlipTimetable", true, false) as Button
	flip.pressed.emit()
	await _settle(22)
	var paper := hud.panel_content.find_child("TimetablePaper", true, false) as TextureRect
	_check(hud.panel_content.get_global_rect().encloses(paper.get_global_rect()) and not paper.get_global_rect().intersects(flip.get_global_rect()), "flipped paper fits inside the panel and clear of the button")
	await _capture("ch3_timetable_flipped_repair")
	_check(GameState.opening_flags.ch3_ticket_found and GameState.has_demo_item("w17_bus_ticket"), "ticket_pickup_updates_flag_and_inventory")
	_check(GameState.has_demo_item("laochen_handoff_note"), "ticket_contains_laochen_handoff_note")
	_check(not hotspots["w17_ticket"].visible and AudioManager.last_world_effect == "archive_ticket_pickup", "paper_cue_and_ticket_hidden")
	room.call("close_dialog")
	room.call("interact_target", "w17_ticket")
	_check(not hud.panel_open and GameState.opening_items.laochen_handoff_note == 1, "repeat_pickup_is_idempotent")
	var inventory_press := InputEventAction.new()
	inventory_press.action = "inventory"
	inventory_press.pressed = true
	Input.parse_input_event(inventory_press)
	await _settle(3)
	var bag: Control = room.get("inventory_panel")
	var item_ids: Array = bag.get("item_ids")
	_check(get_tree().paused and not player.controls_enabled, "archive_bag_pauses_world_and_motion")
	_check(item_ids.has("archive_spare_key") and item_ids.has("w17_bus_ticket") and item_ids.has("laochen_handoff_note"), "collected_archive_items_can_be_reinspected")
	bag.call("_inspect", item_ids.find("laochen_handoff_note"))
	bag.get("item_list").select(item_ids.find("laochen_handoff_note"))
	_check("亚马喇" in bag.get("detail").text and "阿豪" in bag.get("detail").text, "survival_note_preserves_intended_route_and_ahhao_timeline")
	await _capture("ch3_note_inventory_033")
	Input.parse_input_event(inventory_press)
	await _settle(3)
	_check(not get_tree().paused and player.controls_enabled, "closing_bag_restores_world")
	await _capture("ch3_open_door_items_033")
	if "--archive-save-only" in OS.get_cmdline_user_args():
		_check(GameState.opening_checkpoint_enabled() and GameState.save_opening_checkpoint(), "archive_checkpoint_saved_in_isolated_test_profile")
		print("CH3_ARCHIVE_SAVE_RESULT checks=%d failed=%s" % [checks, str(failed)])
		get_tree().quit(1 if failed else 0)
		return
	# Follow the front of the counter, then walk through the opening using movement input.
	Input.action_press("move_right")
	for _i in range(160):
		await get_tree().physics_frame
		if player.position.x >= 548.0:
			break
	Input.action_release("move_right")
	await _settle(4)
	_check(player.position.x >= 540.0 and player.position.x < 574.0, "walk_from_counter_to_open_maintenance_door")
	Input.action_press("move_up")
	for _i in range(180):
		await get_tree().physics_frame
		if hud.panel_open:
			break
	Input.action_release("move_up")
	_check(player.position.y >= 75.0 and player.position.y <= 94.0, "walk_through_door_reaches_departure_without_teleport")
	_check(room.get("departing_to_bus") and hud.panel_open, "dark_passage_requires_both_ticket_and_key")
	room.call("close_dialog")
	await _settle(12)
	_check(GameState.current_room_id == "ch3_quiet_passage" and get_tree().current_scene.name == "QuietPassage", "archive_exit_enters_quiet_passage")
	if GameState.current_room_id != "ch3_quiet_passage":
		get_tree().quit(1)
		return
	var passage = get_tree().current_scene
	passage.interact_target("street")
	await _settle(4)
	_check(passage.hud.panel_open and passage.hud.choice_buttons.size() == 2, "passage_offers_street_or_time_to_stay")
	passage._enter_bus()
	await _settle(65)
	_check(GameState.current_room_id == "ch4_bus_loop" and GameState.current_chapter_id == "ch4_bus33_loop", "w17_ticket_route_changes_to_chapter_four")
	_check(GameState.pending_entry_id == "from_w17_ticket", "chapter_four_receives_w17_entry_id")
	_check(get_tree().current_scene != null and get_tree().current_scene.name == "BusLoop", "bus_scene_takes_over_after_archive_exit")
	await _settle(8)
	var bus := get_tree().current_scene
	var bus_hud = bus.get("hud")
	var arrival_title_found := false
	if bus_hud != null:
		for child in bus_hud.panel_content.get_children():
			if child is Label and String(child.text).contains("33 路末班车"):
				arrival_title_found = true
	_check(bus_hud != null and bus_hud.panel_open and arrival_title_found, "w17_arrival_intro_is_shown")
	_check(GameState.has_demo_item("archive_spare_key") and GameState.has_demo_item("w17_bus_ticket"), "chapter_transition_preserves_physical_clues")
	print("CH3_ARCHIVE_RESULT checks=%d failed=%s" % [checks, str(failed)])
	get_tree().quit(1 if failed else 0)

func _read_saved_archive() -> void:
	_check(GameState.opening_checkpoint_enabled(), "resume_uses_explicit_checkpoint_qa")
	GameState.prepare_opening_resume()
	_check(GameState.current_room_id == "ch3_amparo_archive", "separate_process_restores_archive_room")
	_check(GameState.opening_flags.ch3_balance_solved and GameState.opening_flags.ch3_cold_door_open, "separate_process_restores_scale_and_door")
	for item_id in ["archive_spare_key", "w17_bus_ticket", "laochen_handoff_note"]:
		_check(GameState.has_demo_item(item_id), "separate_process_restores_" + item_id)
	var room := load("res://levels/ch3_amparo_alley/archive_room.tscn").instantiate() as Node2D
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	await _settle(12)
	_check(not room.get("hud").panel_open, "completed_intro_does_not_replay_on_resume")
	var hotspots: Dictionary = room.get("hotspots")
	_check(not hotspots.archive_key.visible and not hotspots.w17_ticket.visible, "picked_items_do_not_reappear_on_resume")
	_check(room.get("cold_door_collision").disabled and room.get("cold_door_overlay").visible, "resumed_door_art_and_passage_match")
	_check(not room.get("opened_leaf_collision").disabled and room.get("opened_leaf_occluder").visible, "resumed_swung_leaf_keeps_collision_and_shadow")
	room.call("_open_inventory")
	await _settle(3)
	var bag: Control = room.get("inventory_panel")
	_check("laochen_handoff_note" in bag.get("item_ids"), "note_remains_readable_after_restart")
	room.call("_close_active_ui")
	_check(not get_tree().paused and room.get("player").controls_enabled, "resume_inventory_closes_cleanly")
	print("CH3_ARCHIVE_RESTART_RESULT checks=%d failed=%s" % [checks, str(failed)])
	get_tree().quit(1 if failed else 0)
