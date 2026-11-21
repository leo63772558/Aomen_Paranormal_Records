extends SceneTree

var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state = root.get_node("GameState")
	state.opening_resume_checked = true
	var paths := ["res://levels/ch2_guia/hill_base_014.tscn", "res://levels/ch2_guia/hill_shelter_014.tscn", "res://levels/ch2_guia/bunker_descent_020.tscn", "res://levels/ch2_guia/bunker_hall_015.tscn", "res://levels/ch2_guia/bunker_ammo_022.tscn", "res://levels/ch2_guia/hill_steps_014.tscn"]
	for path in paths:
		var scene = load(path).instantiate()
		root.add_child(scene)
		await process_frame
		await physics_frame
		check(scene.get("player") != null, "加载 " + path)
		if scene.get("player") == null:
			push_error("Legacy bunker fixture could not initialize %s; use the current route regression instead." % path)
			quit(1)
			return
		if path.contains("hill_base"):
			check_target(scene, Vector2(240, 230), Vector2.DOWN, "bunker_toolbox")
			scene.show_bunker_toolbox()
			var box = scene.hud.panel_content.get_child(scene.hud.panel_content.get_child_count() - 1)
			click_at(box, Vector2(310, 190))
			check(box.opened, "用工具打开维修箱")
			click_at(box, box.key_rect(0).get_center())
			check(state.opening_flags.bunker_key_1, "拾取并记录第一把钥匙")
			scene.close_dialog()
		elif path.contains("hill_shelter"):
			check_target(scene, Vector2(320, 240), Vector2.UP, "shelter_door")
			check_target(scene, Vector2(200, 230), Vector2.DOWN, "bunker_oil")
			scene.show_bunker_lock()
			var puzzle = scene.hud.panel_content.get_child(scene.hud.panel_content.get_child_count() - 1)
			drag_item(puzzle, Vector2(500, 280), Vector2(310, 200))
			check(not state.opening_flags.bunker_lock_open, "锈锁未处理时不能转动钥匙")
			scene.close_dialog()
			scene.interact_target("bunker_oil")
			check(state.opening_flags.bunker_oil_found, "拾取独立油壶")
			scene.close_dialog()
			scene.show_bunker_lock()
			puzzle = scene.hud.panel_content.get_child(scene.hud.panel_content.get_child_count() - 1)
			drag_item(puzzle, Vector2(85, 280), Vector2(310, 200))
			check(state.opening_flags.bunker_lock_oiled, "润滑油处理锈锁")
			drag_item(puzzle, Vector2(500, 280), Vector2(310, 200))
			check(not state.opening_flags.bunker_lock_open, "错误钥匙不能打开锁")
			scene.close_dialog()
			scene.show_bunker_toolbox()
			var box = scene.hud.panel_content.get_child(scene.hud.panel_content.get_child_count() - 1)
			click_at(box, Vector2(310, 190))
			click_at(box, box.key_rect(1).get_center())
			check(state.opening_flags.bunker_key_2 and not state.opening_flags.bunker_key_1, "能换取匹配刻痕的钥匙")
			scene.close_dialog()
			scene.show_bunker_lock()
			puzzle = scene.hud.panel_content.get_child(scene.hud.panel_content.get_child_count() - 1)
			drag_item(puzzle, Vector2(500, 280), Vector2(310, 200))
			check(state.opening_flags.bunker_lock_open, "正确钥匙打开锁梁")
			drag_item(puzzle, Vector2(200, 120), Vector2(90, 120))
			await process_frame
			check(state.opening_flags.bunker_gate_unlocked, "拖开铁链并记录通行状态")
		elif path.contains("bunker_descent"):
			check_target(scene, Vector2(320, 275), Vector2.DOWN, "descent_hall")
			check_target(scene, Vector2(465, 245), Vector2.UP, "descent_pit")
			var stair_query := PhysicsPointQueryParameters2D.new()
			stair_query.collision_mask = 1
			stair_query.position = Vector2(320, 120)
			check(scene.get_world_2d().direct_space_state.intersect_point(stair_query).is_empty(), "下行楼梯可通行")
			stair_query.position = Vector2(465, 120)
			check(not scene.get_world_2d().direct_space_state.intersect_point(stair_query).is_empty(), "右侧深坑受到阻挡")
		elif path.contains("bunker_hall"):
			check_target(scene, Vector2(230, 232), Vector2.LEFT, "bunker_bed")
			check_target(scene, Vector2(320, 210), Vector2.UP, "bunker_graffiti")
			check_target(scene, Vector2(460, 215), Vector2.UP, "bunker_deep")
		elif path.contains("bunker_ammo"):
			check_target(scene, Vector2(225, 295), Vector2.UP, "ammo_pits")
			var query := PhysicsPointQueryParameters2D.new()
			query.position = Vector2(115, 121)
			query.collision_mask = 1
			check(not scene.get_world_2d().direct_space_state.intersect_point(query).is_empty(), "坑位具备碰撞")
			scene.interact_target("ammo_pits")
			scene.close_dialog()
			check(scene.work_in_progress, "红衣人影事件开始")
			await create_timer(3.4, false).timeout
			check(state.opening_flags.bunker_red_seen and not scene.work_in_progress, "红衣人影事件结束并保存状态")
		paused = false
		root.remove_child(scene)
		scene.queue_free()
		await process_frame
	var flags: Dictionary = state.opening_flags.duplicate(true)
	for key in flags:
		flags[key] = true
	flags.hill_steps_completed = false
	var saved := {"schema_version":1, "rules_version":1, "profile":"test", "run_id":"bunker020", "room_id":"ch2_bunker_hall", "entry_id":"from_descent", "current_chapter_id":"ch2_guia_tunnel", "flags":flags, "switches":{"A":false,"B":true,"C":false}, "resources":{"stamina":100,"flashlight_battery":100}, "photo_file":"photo_123.png"}
	var scope := {"profile":"test", "run_id":"bunker020"}
	check(not OpeningCheckpoint.decode(JSON.stringify(saved), scope).is_empty(), "未走完深层楼梯也能保存机房进度")
	flags.erase("bunker_gate_unlocked")
	for name in ["bunker_gate_examined", "bunker_oil_found", "bunker_lock_oiled", "bunker_lock_open", "bunker_key_1", "bunker_key_2", "bunker_key_3"]:
		flags.erase(name)
	flags.hill_steps_completed = true
	saved.entry_id = "from_steps"
	var migrated := OpeningCheckpoint.decode(JSON.stringify(saved), scope)
	check(not migrated.is_empty() and migrated.flags.bunker_gate_unlocked, "旧机房存档迁移保留进度")
	check(not migrated.is_empty() and not migrated.flags.bunker_oil_found and not migrated.flags.bunker_key_2, "旧存档缺失新物品字段时安全补齐")
	var gate = load(paths[1]).instantiate()
	root.add_child(gate)
	current_scene = gate
	await process_frame
	gate.interact_target("shelter_door")
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.stage_kind == "bunker_descent", "铁门通向下行区")
	current_scene.interact_target("descent_hall")
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.stage_kind == "bunker_hall", "下行区通向机房")
	current_scene.interact_target("bunker_door")
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.stage_kind == "bunker_ammo", "机房通向子弹房")
	current_scene.interact_target("ammo_exit")
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.stage_kind == "bunker_hall", "子弹房返回机房")
	current_scene.interact_target("bunker_deep")
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.has_method("return_base"), "机房通向深层楼梯")
	current_scene.close_panel()
	current_scene.player.look_dir = Vector2.UP
	current_scene.player.position.y = current_scene.START_Y - 89 * current_scene.STEP_DISTANCE
	current_scene._physics_process(0.01)
	check(current_scene.eighty_nine_shown, "八十九级触发异常提示")
	current_scene.player.position.y = current_scene.START_Y - 99 * current_scene.STEP_DISTANCE
	current_scene._physics_process(0.01)
	check(current_scene.choice_shown, "九十九级触发传闻事件")
	current_scene.show_step_hint()
	check(current_scene.hud.panel_open and current_scene.hud.pages.size() > 0, "九十九级可主动查看操作提示")
	current_scene.close_panel()
	check(current_scene.player.aim_override and current_scene.player.look_dir == Vector2.UP, "关闭提示时暂时锁定朝前避免误回头")
	current_scene.player.position.y = current_scene.START_Y - 98 * current_scene.STEP_DISTANCE
	current_scene._physics_process(0.01)
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.stage_kind == "bunker_hall" and state.opening_flags.hill_steps_completed, "依据线索后退解除循环并返回机房")
	quit(1 if failures else 0)

func check_target(scene: Node, position: Vector2, direction: Vector2, expected: String) -> void:
	scene.player.position = position
	scene.player.look_dir = direction
	scene._process(0.0)
	check(scene.selected_id == expected, "交互位置 " + expected + "，实际 " + scene.selected_id)

func click_at(control: Control, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = at
	control._gui_input(event)

func drag_item(control: Control, from: Vector2, to: Vector2) -> void:
	click_at(control, from)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = to
	control._gui_input(event)
