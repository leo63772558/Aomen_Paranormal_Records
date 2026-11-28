extends SceneTree
# Continues the actual checkpoint produced by demo_route_026.gd. It does not
# set story flags or move the player directly; route and answers are scripted.

var state: Node
var scene: Node
var checks := 0
var failed := false
var held := {"move_left": false, "move_right": false, "move_up": false, "move_down": false, "sprint": false}


func _initialize() -> void:
	call_deferred("run")

func capture_stage(label: String) -> void:
	if DisplayServer.get_name() == "headless" or not "--capture-route" in OS.get_cmdline_user_args():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image != null and image.save_png("res://docs/build_reports/%s_%s.png" % [state.run_id, label]) == OK, "hidden render: " + label)


func check(value: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failed = true
		quit(1)
	return value


func frames(count := 4) -> void:
	for _i in range(count):
		await process_frame


func tap(action_name: String) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventAction.new()
	event.action = action_name
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)


func walk(point: Vector2, max_frames := 1800) -> void:
	var actor = scene.player
	actor.aim_override = true
	for _i in range(max_frames):
		if not is_instance_valid(actor) or paused:
			break
		var delta: Vector2 = point - actor.position
		if delta.length() < 3.0:
			break
		actor.look_dir = delta.normalized()
		var desired := {"move_left":delta.x < -2.0, "move_right":delta.x > 2.0, "move_up":delta.y < -2.0, "move_down":delta.y > 2.0, "sprint":true}
		for action_name in held:
			if held[action_name] != desired[action_name]:
				if desired[action_name]: Input.action_press(action_name)
				else: Input.action_release(action_name)
				held[action_name] = desired[action_name]
		await physics_frame
	for action_name in held:
		Input.action_release(action_name)
		held[action_name] = false
	await frames(4)
	check(is_instance_valid(actor) and actor.position.distance_to(point) < 18.0, "walk to %s, actual %s" % [str(point), str(actor.position) if is_instance_valid(actor) else "scene changed"])


func via(points: Array[Vector2]) -> void:
	for point in points:
		await walk(point)


func dismiss() -> void:
	for _i in range(10):
		if not is_instance_valid(scene) or not scene.hud.panel_open:
			return
		await tap("pause")


func use_at(id: String, standing: Vector2, auto_dismiss := true) -> void:
	await walk(standing)
	var target: Vector2 = scene.TARGETS[id]
	scene.player.look_dir = (target - scene.player.position).normalized() if target.distance_to(scene.player.position) > 0.1 else Vector2.RIGHT
	await frames(4)
	if not check(scene.selected_id == id, "select %s via world prompt (actual %s)" % [id, scene.selected_id]):
		return
	await tap("interact")
	if id in ["branch_a", "branch_b", "branch_c", "jiamin_signal_pipe"]:
		return
	for _i in range(240):
		if not is_instance_valid(scene):
			return
		if scene.hud.panel_open:
			if not auto_dismiss:
				return
			await dismiss()
		if not is_instance_valid(scene) or scene.player.controls_enabled:
			break
		await process_frame


func choose(prefix: String) -> void:
	for _i in range(10):
		if not is_instance_valid(scene) or not scene.hud.panel_open:
			break
		for button in scene.hud.choice_buttons:
			if button.visible and (button.text.begins_with(prefix) or prefix in button.text):
				button.pressed.emit()
				await frames(4)
				return
		await tap("interact")
	check(false, "visible choice " + prefix)


func tap_signal() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	event = InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = false
	Input.parse_input_event(event)
	await frames(1)


func entered(room_id: String) -> void:
	for _i in range(120):
		if state.current_room_id == room_id and is_instance_valid(current_scene):
			break
		await process_frame
	scene = current_scene
	if check(state.current_room_id == room_id and is_instance_valid(scene), "entered " + room_id):
		await frames(6)
		await dismiss()


func run() -> void:
	state = root.get_node("GameState")
	state.prepare_opening_resume()
	if not check(state.profile == "test" and state.opening_checkpoint_enabled(), "isolated persisted test profile"):
		return
	if not check(state.current_room_id == "ch5_hacsa_beach" and state.opening_flags.beach_circuit_matched and not state.opening_flags.coastal_intro_seen, "continues the real black-sand checkpoint from the first route"):
		return
	if not check(state.opening_photo != null and state.has_demo_item("ahhao_camera"), "opening photo and Ah Hao's camera survive the route"):
		return
	state.request_room_change(state.current_room_id, state.pending_entry_id)
	await entered("ch5_hacsa_beach")
	await capture_stage("10_hacsa_beach")
	await via([Vector2(130, 215), Vector2(100, 145)])
	await use_at("road_exit", Vector2(90, 125))
	await entered("ch5_coastal_works")
	await use_at("arrow", Vector2(294, 468))
	await via([Vector2(520, 480), Vector2(558, 500)])
	await use_at("drain", Vector2(558, 625))
	await walk(Vector2(558, 280))
	await use_at("thread", Vector2(1054, 158))
	await use_at("ladder", Vector2(1095, 164))
	check(state.opening_flags.coastal_route_verified, "upper route is verified from actual evidence")
	await entered("ch5_coastal_chamber")
	await via([Vector2(1150, 487), Vector2(1000, 487), Vector2(1000, 410), Vector2(620, 410)])
	await use_at("tide", Vector2(620, 368))
	await use_at("grate", Vector2(715, 425))
	await use_at("hatch", Vector2(990, 407))
	await via([Vector2(990, 418), Vector2(188, 410)])
	await use_at("west", Vector2(188, 410))
	check(state.opening_flags.coastal_chamber_route_verified, "chamber route verified from four observations")
	await use_at("next", Vector2(118, 365))
	check(state.opening_flags.coastal_silt_route_verified, "compressed 3-room route advances directly to pressure gallery")
	await entered("ch5_coastal_pressure_gallery")
	check(not state.transition_save_failed and "保存失败" not in scene.hud.defense_notice.text, "first entry saves after marking the gallery visit")
	await via([Vector2(640, 424), Vector2(315, 424)])
	await use_at("inlet", Vector2(315, 370), false)
	var pressure_console = scene.widget
	await capture_stage("11_pressure_console")
	for button in pressure_console.captions:
		button.pressed.emit()
		await frames(47)
	await dismiss()
	await use_at("cabinet", Vector2(164, 440))
	await via([Vector2(640, 440)])
	await use_at("exit", Vector2(640, 220))
	check(state.opening_flags.coastal_pressure_route_verified, "pressure route and engineering record completed")
	await entered("ch6_abandoned_vip")
	check(state.current_role == "jiamin", "finale begins as Jiamin")
	await via([Vector2(220, 620), Vector2(220, 510)])
	await use_at("pipe_item", Vector2(224, 510))
	await use_at("jiamin_signal_pipe", Vector2(250, 248))
	await frames(20)
	await capture_stage("12_jiamin_pipe")
	for _strike in range(3):
		await tap_signal()
		await frames(18)
	for _frame in range(240):
		if scene.player.controls_enabled:
			break
		await process_frame
	check(state.opening_flags.ch6_signal_sent and state.opening_flags.ch6_pipe_route_verified and state.current_role == "dawen", "Jiamin's 3 knocks immediately verify her signal and hand control to Daven")
	check(scene.player.controls_enabled, "controls return once the role card is off screen")
	await via([Vector2(742, 620), Vector2(742, 415)])
	await use_at("route_diagram", Vector2(742, 388))
	await use_at("venue_archive", Vector2(944, 396), false)
	await choose("展开地宫工事名册")
	await choose("继续核对另一份档案")
	await choose("展开旧楼封墙停工公文")
	await choose("收好文件袋")
	check(state.opening_flags.ch6_bunker_register_found and state.opening_flags.ch6_venue_stopwork_found, "both story archives collected through their visible choices")
	await use_at("electrical_cabinet", Vector2(855, 396), false)
	await choose("合上高压电弧主闸")
	await dismiss()
	await use_at("lure_switch", Vector2(1024, 405))
	for _i in range(150):
		if scene.boss_in_trap_zone:
			break
		await physics_frame
	check(is_instance_valid(scene.shadow) and scene.boss_in_trap_zone, "chasing wraith steps onto the visible grate")
	await use_at("lock_lever", Vector2(976, 446))
	check(state.opening_flags.ch6_entity_bound, "physical lock traps the shadow")
	await use_at("rescue_door", Vector2(1118, 415), false)
	for _i in range(540):
		if state.opening_flags.ch6_jiamin_rescued and not scene.scene_action_active and scene.hud.panel_open:
			break
		await process_frame
	check(state.opening_flags.ch6_jiamin_rescued and scene.hud.panel_open, "rescue animation reaches the reunion dialogue")
	check(state.opening_flags.ch6_ahhao_camera_handed, "Ah Hao's camera handoff completes before the reunion dialogue")
	await capture_stage("13_reunion")
	await tap("interact")
	await frames(52)
	await choose("准备撤离")
	check(state.opening_flags.ch6_reunion_seen, "reunion dialogue is acknowledged")
	await choose("核对五组档案")
	await choose("确认并带走五组档案")
	for _i in range(400):
		if state.opening_flags.ending_truth: break
		await process_frame
	check(state.opening_flags.ending_truth and state.has_pre_ending_checkpoint(), "complete route reaches truth ending and preserves the decision checkpoint")
	check(state.opening_photo != null and state.has_demo_item("ahhao_camera"), "opening photo and camera remain in the ending save")
	if "--capture-route" in OS.get_cmdline_user_args():
		await frames(110)
		await capture_stage("14_truth_ending")
	print("FULL ROUTE TAIL THROUGH TRUTH ENDING checks=%d failed=%s" % [checks, failed])
	paused = false
	quit(1 if failed else 0)
