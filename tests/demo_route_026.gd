extends SceneTree
# This uses known coordinates and answers, standard scene transitions and real
# movement. It does not grant puzzle state, spawn a finished save, or teleport.

var state: Node
var scene: Node
var checks := 0
var failed := false
var held_actions := [false, false, false, false, false]
const MOVEMENT := ["move_left", "move_right", "move_up", "move_down", "sprint"]

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> bool:
	checks += 1
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		failed = true
		quit(1)
	return condition

func frames(count := 3) -> void:
	for i in range(count):
		await process_frame

func time_wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout

func action(id: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = id
	event.pressed = pressed
	Input.parse_input_event(event)

func tap(id: String) -> void:
	action(id, true)
	await frames()
	action(id, false)
	await frames()

func stop() -> void:
	for i in range(MOVEMENT.size()):
		if held_actions[i]:
			Input.action_release(MOVEMENT[i])
			held_actions[i] = false

func walk(at: Vector2, run := false, aim_target: Node2D = null) -> void:
	var player = scene.player
	player.aim_override = true
	for i in range(2100):
		if failed or not is_instance_valid(player) or paused:
			break
		if is_instance_valid(aim_target):
			player.look_dir = (aim_target.global_position + Vector2(0, -45) - player.get_flashlight_origin()).normalized()
		var d: Vector2 = at - player.position
		if d.length() < 3.2:
			break
		var next := [d.x < -2.0, d.x > 2.0, d.y < -2.0, d.y > 2.0, run]
		for j in range(MOVEMENT.size()):
			if held_actions[j] != next[j]:
				if next[j]:
					Input.action_press(MOVEMENT[j])
				else:
					Input.action_release(MOVEMENT[j])
				held_actions[j] = next[j]
		await physics_frame
	stop()
	if is_instance_valid(player):
		player.clear_motion()
	await frames()
	if not check(is_instance_valid(player) and player.position.distance_to(at) < 6.5, "实际移动到 %s，实际 %s" % [str(at), str(player.position) if is_instance_valid(player) else "已切换场景"]):
		return

func use(id: String, at: Vector2 = Vector2.ZERO) -> void:
	if failed:
		return
	if at != Vector2.ZERO:
		scene.player.look_dir = (at - scene.player.position).normalized()
	await frames()
	var selected: String = scene.selected_story if scene.has_method("inspect_story") else (scene.active_target if scene.has_method("interact_intro") else (scene.selected if scene.has_method("continue_steps") else scene.selected_id))
	if check(selected == id, "实体交互 %s，实际 %s" % [id, selected]):
		await tap("interact")

func next_room(room: String) -> void:
	for _frame in range(120):
		if state.current_room_id == room:
			break
		await process_frame
	await frames(8)
	scene = current_scene
	if not check(state.current_room_id == room and is_instance_valid(scene), "进入 " + room):
		return

func dismiss() -> void:
	for i in range(10):
		if not is_instance_valid(scene) or not scene.hud.panel_open:
			return
		await tap("pause")

func choice(prefix: String) -> void:
	for i in range(8):
		for node in scene.hud.panel_content.get_children():
			if node is Button and node.visible and node.text.begins_with(prefix):
				node.pressed.emit()
				await frames(5)
				return
		await tap("interact")
	check(false, "找不到选项 " + prefix)

func board() -> Control:
	for node in scene.hud.panel_content.get_children():
		if node is Control and node.get_script() != null:
			return node
	return null

func mouse(control: Control, at: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	event.pressed = pressed
	control._gui_input(event)

func click(control: Control, at: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	mouse(control, at, button, true)
	mouse(control, at, button, false)

func drag(control: Control, start: Vector2, finish: Vector2) -> void:
	mouse(control, start, MOUSE_BUTTON_LEFT, true)
	var event := InputEventMouseMotion.new()
	event.position = finish
	event.relative = finish - start
	control._gui_input(event)
	mouse(control, finish, MOUSE_BUTTON_LEFT, false)

func _run() -> void:
	state = root.get_node("GameState")
	if not check(state.profile == "test", "仅使用 test 隔离配置"):
		return
	change_scene_to_file("res://ui/main_menu.tscn")
	await frames(10)
	scene = current_scene
	var capture_script := load("res://ui/demo_capture_animation.gd") as GDScript
	if not check(capture_script != null, "抓获演出脚本在主菜单载入后可用"):
		return
	for atlas_path in [
		"res://assets/characters/priest_lunge_026.png",
		"res://assets/characters/bunker_family_lunge_026.png"
	]:
		var capture_atlas := capture_script.call("_preloaded_atlas", atlas_path) as Texture2D
		check(capture_atlas != null and capture_atlas.resource_path == atlas_path, "抓获演出图集已预载：" + atlas_path.get_file())
	check(scene.menu.get_child_count() == 4, "标题只列新游戏、继续、设置和退出")
	scene.new_button.pressed.emit()
	await next_room("ch0_hk_work")
	scene.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(paused and scene.hud.panel_open and not scene.player.controls_enabled, "香港工作间失焦暂停")
	scene._close()
	check(not paused and scene.player.controls_enabled, "香港工作间恢复后可以继续操作")
	await use("bench")
	await dismiss()
	await walk(Vector2(442, 237))
	var touched_jiamin := false
	var minimum_gap := INF
	Input.action_press("move_up")
	for _frame in range(24):
		await physics_frame
		minimum_gap = minf(minimum_gap, scene.player.position.distance_to(scene.girl.position))
		for collision_index in range(scene.player.get_slide_collision_count()):
			if scene.player.get_slide_collision(collision_index).get_collider() == scene.girl:
				touched_jiamin = true
	Input.action_release("move_up")
	scene.player.clear_motion()
	check(touched_jiamin and minimum_gap > 15.0, "实际向嘉敏走时，角色足部碰撞阻挡穿越")
	await walk(Vector2(442, 237))
	await use("invite")
	await dismiss()
	await walk(Vector2(525, 193))
	await use("exit")
	await next_room("ch0_hk_home")
	await walk(Vector2(211, 231))
	await walk(Vector2(191, 187))
	await use("photo")
	check(state.has_demo_item("old_304_photo"), "家中获取同一张 304 旧照")
	await dismiss()
	await walk(Vector2(344, 187))
	await use("map")
	check(state.has_demo_item("trip_map"), "两日攻略进背包")
	await dismiss()
	await walk(Vector2(351, 231))
	await walk(Vector2(506, 229))
	await walk(Vector2(544, 184))
	await use("exit")
	await dismiss()
	await next_room("ch0_bridge_bus")
	await tap("interact")
	await next_room("ch0_street")
	await dismiss()
	await tap("camera_mode")
	var camera_motion := InputEventMouseMotion.new()
	camera_motion.position = Vector2(405, 201)
	Input.parse_input_event(camera_motion)
	await frames()
	check(scene.photo_is_valid(), "澳门旅行照有有效取景")
	await tap("photo_capture")
	await dismiss()
	await walk(Vector2(168, 213))
	await use("insulated_bridge", Vector2(167, 193))
	await dismiss()
	await walk(Vector2(370, 258))
	await walk(Vector2(370, 226))
	await use("jiamin", Vector2(405, 226))
	await choice("接过葡挞")
	await dismiss()
	await use("jiamin", Vector2(405, 226))
	await dismiss()
	await walk(Vector2(490, 258))
	await walk(Vector2(487, 178))
	await use("entry", Vector2(487, 159))
	await dismiss()
	await next_room("ch0_foyer")
	await dismiss()
	await walk(Vector2(124, 186))
	await use("ceramic_fuse", Vector2(124, 170))
	await dismiss()
	await walk(Vector2(304, 181))
	await use("power_record", Vector2(304, 165))
	await dismiss()
	await walk(Vector2(210, 162))
	await use("meter", Vector2(210, 139))
	await choice("用工具钳拆盖")
	await time_wait(0.83)
	var electric = board()
	if not check(is_instance_valid(electric), "检修实物面板打开"):
		return
	click(electric, electric.LEVER_POS[0])
	click(electric, electric.TEST.get_center())
	await frames(10)
	check(electric.needle_levels.is_zero_approx(), "梯灯缺桥片时即使合闸，测试表仍显示断路")
	await time_wait(0.45)
	click(electric, electric.LEVER_POS[0])
	drag(electric, electric.TRAY_POS.ceramic_fuse, electric.SLOT_POS[1])
	drag(electric, electric.TRAY_POS.insulated_bridge, electric.SLOT_POS[0])
	for position: Vector2 in electric.LEVER_POS:
		click(electric, position)
	click(electric, electric.TEST.get_center())
	await frames(10)
	check(electric.needle_levels.z > electric.needle_levels.y and electric.needle_levels.y > electric.needle_levels.x and electric.needle_levels.z < 1.0, "各支路表针连续扫过不同读数，水泵冲到最高")
	await time_wait(0.45)
	check(not state.opening_flags.floor3_power, "进水支路接通时试运行失败")
	click(electric, electric.LEVER_POS[2])
	click(electric, electric.TEST.get_center())
	await time_wait(0.45)
	check(state.opening_flags.floor3_power, "安装两件备件并隔离水泵后通电")
	await dismiss()
	await walk(Vector2(520, 156))
	await use("stairs", Vector2(520, 139))
	await next_room("ch0_ah_kin")
	await dismiss()
	await walk(Vector2(520, 260))
	await tap("interact")
	await time_wait(1.05)
	check(scene.phase == "ah_chase", "阿豪合闸后开始实际追逐")
	if "--stop-at-ah-breaker" in OS.get_cmdline_user_args():
		check(state.save_opening_checkpoint(), "阿豪追逐前角色状态可保存")
		print("AHHO MID ROUTE %d checks" % checks)
		quit(1 if failed else 0)
		return
	await walk(Vector2(100, 260), true)
	await tap("interact")
	await time_wait(0.75)
	check(scene.phase == "reunion", "阿豪实际奔跑甩开追逐")
	await dismiss()
	await time_wait(2.35)
	check(state.opening_flags.ah_hao_dead and state.current_role == "dawen", "目睹遇害后切回大文")
	await dismiss()
	await walk(Vector2(478, 292), true)
	await walk(Vector2(478, 269), true)
	await tap("interact")
	await dismiss()
	await time_wait(0.84)
	await next_room("ch0_room304")
	await walk(Vector2(320, 278))
	await use("fallen_phone", Vector2(345, 280))
	await time_wait(0.84)
	check(state.has_demo_item("jiamin_phone") and scene.hud.phone_keytip_enabled, "手机已拾取并保留 Q 按键提示")
	await tap("phone")
	check(state.opening_flags.phone_taught and is_instance_valid(board()), "按 Q 可从拾取页面打开手机")
	await dismiss()
	await walk(Vector2(302, 225))
	await use("desk304", Vector2(300, 208))
	await choice("接听电话")
	await time_wait(2.05)
	check(state.opening_flags.room_phone_answered and scene.room_dark_layer.visible, "接电话后灯灭，进入衣柜段")
	await walk(Vector2(302, 243))
	await walk(Vector2(147, 243))
	await walk(Vector2(147, 208))
	await use("wardrobe304", Vector2(145, 190))
	await time_wait(5.0)
	await tap("interact")
	await time_wait(0.5)
	check(state.opening_flags.wet_tag_left, "出衣柜触发走廊遗留物")
	await walk(Vector2(266, 246))
	await use("service_grip", Vector2(265, 230))
	await dismiss()
	await walk(Vector2(320, 280))
	await use("leave304", Vector2(320, 300))
	await next_room("ch0_corridor")
	await walk(Vector2(483, 255))
	await use("wet_tag", Vector2(484, 241))
	check(state.has_demo_item("wet_tag"), "湿检修签可拾取")
	await dismiss()
	await walk(Vector2(483, 219))
	await use("door304", Vector2(483, 207))
	await next_room("ch0_room304")
	await walk(Vector2(302, 225))
	await use("desk304", Vector2(300, 208))
	await time_wait(1.1)
	await dismiss()
	await walk(Vector2(500, 264))
	await use("bed304", Vector2(500, 240))
	await choice("推开铁床")
	await time_wait(1.3)
	check(state.opening_flags.room_bed_moved, "推动铁床改变位置")
	await dismiss()
	await walk(Vector2(520, 211))
	await use("vent304", Vector2(520, 176))
	await choice("用工具钳拆盖")
	var cover_wait := 0
	while not state.opening_flags.room_cover_open and cover_wait < 240:
		await frames(1)
		cover_wait += 1
	check(state.opening_flags.room_cover_open, "拆盖动作完成后打开检修口")
	await dismiss()
	await use("vent304", Vector2(520, 176))
	await choice("爬进通道")
	await time_wait(0.93)
	await next_room("ch0_maintenance")
	await walk(Vector2(418, 239))
	await use("service_spindle", Vector2(418, 223))
	await dismiss()
	await tap("inventory")
	var bag = board()
	bag.assemble.pressed.emit()
	check(state.has_demo_item("service_handle"), "背包组装握柄与方轴")
	await dismiss()
	await walk(Vector2(550, 217))
	await use("steel_door", Vector2(550, 195))
	var service = board()
	drag(service, service.TRAY.get_center(), service.CENTER)
	drag(service, service.CENTER, service.CENTER + Vector2(61, 0))
	check(not service.rotated, "未卸力的门栓无法转动")
	click(service, service.PLATE.get_center())
	drag(service, service.CENTER, service.CENTER + Vector2(61, 0))
	drag(service, service.SLIDE.get_center(), service.SLIDE.get_center() - Vector2(58, 0))
	await time_wait(0.90)
	check(state.opening_flags.maintenance_unlocked, "装柄、顶门、旋转与回拉后开门")
	await dismiss()
	await use("steel_door", Vector2(550, 195))
	await next_room("ch0_yard")
	await dismiss()
	await walk(Vector2(530, 209), true)
	await use("yard_exit", Vector2(550, 170))
	await time_wait(0.9)
	await next_room("ch0_exit_lane")
	await dismiss()
	await walk(Vector2(153, 284))
	await use("public_phone", Vector2(115, 285))
	await time_wait(1.95)
	await dismiss()
	await walk(Vector2(498, 241))
	await use("city_stairs", Vector2(500, 225))
	await choice("前往牌坊")
	await next_room("ch1_crypt_entry")
	await walk(Vector2(390, 182))
	await use("crypt_old_photo", Vector2(393, 163))
	await dismiss()
	await walk(Vector2(249, 171))
	await use("crypt_niche", Vector2(250, 145))
	await dismiss()
	await walk(Vector2(120, 187))
	await use("crypt_desk", Vector2(120, 166))
	await choice("查看测绘描图")
	await dismiss()
	await use("crypt_desk", Vector2(120, 166))
	await choice("摆开三份证据")
	var survey = board()
	drag(survey, survey.PLAN_TRAY.get_center(), survey.GUIDE_ORIGIN)
	check(not survey.fitted, "倒置的描图无法对上刻痕")
	var one_mark: Vector2 = survey.EVIDENCE[0] - survey.MARK.rotated(survey.sheet_angle)
	drag(survey, survey.GUIDE_ORIGIN, one_mark)
	check(not survey.fitted and "只重合了一处" in survey.status, "只对上一处痕迹时不能提交")
	click(survey, one_mark, MOUSE_BUTTON_RIGHT)
	await frames(4)
	check(survey.drawn_angle > PI and survey.drawn_angle < survey.sheet_angle, "描图旋转以连续插值经过中间角度")
	for _turn in range(3):
		click(survey, survey.GUIDE_ORIGIN, MOUSE_BUTTON_RIGHT)
	drag(survey, one_mark, survey.GUIDE_ORIGIN)
	click(survey, survey.BAY_POINTS[1])
	await frames(6)
	check(state.opening_flags.crypt_aligned, "对齐两标记并找出封闭壁龛")
	await dismiss()
	await walk(Vector2(120, 220))
	await walk(Vector2(546, 220))
	await walk(Vector2(546, 177))
	await use("crypt_door", Vector2(545, 145))
	await choice("用钳松开")
	var clip = board()
	click(clip, Vector2(179, 160))
	click(clip, Vector2(440, 160))
	await time_wait(2.05)
	check(state.opening_flags.crypt_door_open, "拆同一扇门框的卡扣后实际开门")
	await dismiss()
	await use("crypt_door", Vector2(545, 145))
	await next_room("ch1_crypt_hall")
	await dismiss()
	var impact_events: Array[String] = []
	var sound := root.get_node("AudioManager")
	var on_sound := func(id: String):
		if id in ["capture_rush", "capture_hit"]:
			impact_events.append(id)
	sound.world_effect_requested.connect(on_sound)
	await tap("flashlight")
	await time_wait(6.6)
	check(scene.capture_locked and scene.hud.panel_open and impact_events == ["capture_rush", "capture_hit"], "黑衣老人实际追上后播放动作和撞击，再显示重试")
	sound.world_effect_requested.disconnect(on_sound)
	await choice("重新尝试")
	await next_room("ch1_crypt_hall")
	await dismiss()
	await time_wait(0.15)
	await walk(Vector2(108, 265), false, scene.priest)
	await walk(Vector2(550, 265), true, scene.priest)
	await walk(Vector2(550, 219), false, scene.priest)
	await use("hall_exit", Vector2(550, 185))
	await time_wait(0.89)
	await next_room("ch1_archive")
	await dismiss()
	await walk(Vector2(129, 247))
	await use("archive_index", Vector2(125, 230))
	await time_wait(0.85)
	await dismiss()
	await walk(Vector2(530, 222))
	await use("archive_exit", Vector2(545, 205))
	await choice("前往松山")
	await time_wait(0.80)
	await next_room("ch2_hill_base")
	await dismiss()
	await walk(Vector2(294, 285))
	await use("gate_work_order", Vector2(293, 266))
	await dismiss()
	await walk(Vector2(237, 237))
	await use("bunker_toolbox", Vector2(240, 250))
	var toolbox = board()
	click(toolbox, Vector2(305, 180))
	await time_wait(0.8)
	for i in range(3):
		click(toolbox, toolbox.key_rect(i).get_center())
	await dismiss()
	await walk(Vector2(500, 240))
	await use("hill_steps", Vector2(500, 218))
	await next_room("ch2_shelter")
	await walk(Vector2(199, 232))
	await use("bunker_oil", Vector2(200, 250))
	await dismiss()
	await walk(Vector2(374, 235))
	await use("shelter_door", Vector2(374, 213))
	var gate = board()
	drag(gate, gate.OIL_TRAY, gate.KEYHOLE)
	await time_wait(0.84)
	drag(gate, gate.KEY_TRAYS[1], gate.KEYHOLE)
	check(not state.opening_flags.bunker_lock_open, "铁链未卸力，正确钥匙也卡住")
	drag(gate, gate.CHAIN_ZONE.get_center(), gate.HOOK)
	await time_wait(0.44)
	drag(gate, gate.KEY_TRAYS[0], gate.KEYHOLE)
	check(not state.opening_flags.bunker_lock_open, "不同磨槽的钥匙无法开锁")
	drag(gate, gate.KEY_TRAYS[1], gate.KEYHOLE)
	await time_wait(0.58)
	drag(gate, gate.CHAIN_ZONE.get_center(), Vector2(565, 95))
	await time_wait(1.18)
	check(state.opening_flags.bunker_gate_unlocked, "上油、托链、匹配钥匙和移链后门打开")
	await use("shelter_door", Vector2(374, 213))
	await next_room("ch2_bunker_descent")
	await walk(Vector2(320, 241))
	await walk(Vector2(418, 262))
	await use("loose_stone", Vector2(418, 247))
	await dismiss()
	await walk(Vector2(465, 235))
	scene.player.look_dir = (scene.pit_bones.position - scene.player.get_flashlight_origin()).normalized()
	await time_wait(0.52)
	check(state.opening_flags.pit_bones_seen, "从安全边缘照见坑内白骨")
	await use("descent_pit", Vector2(465, 215))
	await choice("把碎石抛进坑里")
	await time_wait(0.95)
	check(state.opening_flags.pit_stone_thrown and not state.has_demo_item("loose_stone"), "抛石结束后一次性结算")
	await walk(Vector2(319, 283))
	await use("descent_hall", Vector2(320, 300))
	await next_room("ch2_bunker_hall")
	await walk(Vector2(321, 199))
	await use("bunker_graffiti", Vector2(320, 180))
	await dismiss()
	await walk(Vector2(550, 209))
	await use("bunker_door", Vector2(550, 178))
	await next_room("ch2_bunker_ammo")
	await walk(Vector2(199, 461))
	await walk(Vector2(199, 376))
	await walk(Vector2(693, 376))
	await walk(Vector2(692, 207))
	await use("bunker_recording", Vector2(692, 190))
	await dismiss()
	check(state.demo_pursuit == "ammo" and scene.family.size() == 3, "取录音触发三名独立追逐者")
	await walk(Vector2(693, 243), true)
	await walk(Vector2(558, 244), true)
	await walk(Vector2(558, 453), true)
	await walk(Vector2(390, 471), true)
	await use("ammo_exit", Vector2(390, 489))
	await next_room("ch2_bunker_hall")
	await walk(Vector2(459, 204), true)
	await use("bunker_deep", Vector2(460, 175))
	await next_room("ch2_bunker_shaft")
	await time_wait(1.5)
	check(scene.hud.panel_open and state.opening_flags.ch2_shaft_demo_seen, "罐声安全示范在巡山人追逐前完成")
	await tap("pause")
	check(scene.phase == scene.Phase.ACTIVE and scene.player.controls_enabled, "Esc关闭教学后能够继续行动")
	await walk(Vector2(550, 420), true)
	await walk(Vector2(650, 365), true)
	await walk(Vector2(650, 435), true)
	await use("door", Vector2(650, 430))
	await time_wait(0.75)
	check(state.opening_flags.ch2_shaft_bypass_closed and not state.opening_flags.ch2_ranger_fallen, "不使用强闪，从井边绕行并闩上侧廊门")
	await walk(Vector2(690, 458))
	await use("note", scene.NOTE)
	await choice("沿侧廊进入深层梯道")
	await next_room("ch2_hill_steps")
	var hero = scene.player
	hero.aim_override = true
	hero.look_dir = Vector2.UP
	await walk(Vector2(320, scene.STAIRS.y_at(89) - 2))
	await tap("interact")
	check(scene.stair_art.marked, "89 级可在实体墙边留记")
	await walk(Vector2(320, scene.STAIRS.y_at(99) - 2))
	check(scene.loop_ready, "第 99 级见到重复的 89 级标志")
	await walk(Vector2(320, scene.STAIRS.y_at(97) + 3))
	check(scene.phase == scene.Phase.LOOP, "退两级无法完成")
	await walk(Vector2(320, scene.STAIRS.y_at(88) - 3))
	check(scene.phase == scene.Phase.RETURN, "面向深处退过全部异常台阶，解除追逐")
	await walk(Vector2(320, scene.START_Y + 4))
	await tap("interact")
	await next_room("ch2_bunker_hall")
	await walk(Vector2(320, 278))
	await use("bunker_return", Vector2(320, 300))
	await next_room("ch2_bunker_descent")
	await walk(Vector2(320, 92))
	await use("descent_return", Vector2(320, 69))
	await next_room("ch2_shelter")
	await walk(Vector2(340, 268))
	await use("review_tape", Vector2(340, 246))
	var tape = board()
	tape._play(0)
	tape._play(1)
	tape.dismiss.pressed.emit()
	check(not state.opening_flags.demo_case_closed, "误判实时求救不会结案")
	tape.classify.pressed.emit()
	check(state.opening_flags.demo_case_closed and state.has_demo_item("bunker_recording"), "洞外复听后完成调查")
	check(state.save_opening_checkpoint(), "完成态检查点可以写入 test 目录")
	if "--through-bus" in OS.get_cmdline_user_args():
		await through_archive_and_bus()
		paused = false
		if is_instance_valid(current_scene): current_scene.queue_free()
		await frames(5)
		# Fixed-FPS headless simulation outruns the audio mixer's real clock.
		# Give queued stop/free commands one mixer interval before engine shutdown.
		OS.delay_msec(100)
		await frames(3)
	print("DEMO ROUTE %d checks" % checks)
	quit(1 if failed else 0)

func widget_choice(prefix: String) -> void:
	var widget := board()
	if widget != null:
		for child in widget.get_children():
			if child is Button and child.visible and child.text.begins_with(prefix):
				child.pressed.emit()
				await frames(4)
				return
	check(false, "找不到实物界面按钮 " + prefix)

func through_archive_and_bus() -> void:
	await choice("前往大关斜巷")
	await next_room("ch3_amparo_archive")
	await dismiss()
	await walk(Vector2(510, 200))
	await use("lens_cap", Vector2(513, 166))
	check(state.has_demo_item("jiamin_lens_cap"), "现场镜头盖提供嘉敏经过的物证")
	await dismiss()
	await walk(Vector2(390, 182))
	await use("photo", Vector2(367, 92))
	await dismiss()
	for entry in [["resident_register", 254], ["delivery_letter", 310], ["visitor_log", 333]]:
		await walk(Vector2(entry[1], 182))
		await use(entry[0], Vector2(entry[1], 108))
		if entry[0] != "visitor_log": await dismiss()
	await tap("pause")
	await choice("先列作临时送药访客")
	await dismiss()
	await walk(Vector2(548, 188))
	await use("cold_door", Vector2(548, 145))
	await dismiss()
	await walk(Vector2(278, 182))
	await use("balance_rule", Vector2(278, 108))
	await dismiss()
	await walk(Vector2(440, 182))
	await use("balance", Vector2(420, 91))
	var balance := board()
	for index in [0, 1, 2]:
		balance.cards[index].pressed.emit()
		await frames(3)
	balance.submit_weight()
	await time_wait(0.9)
	await dismiss()
	await walk(Vector2(386, 182))
	await use("archive_key", Vector2(386, 117))
	await dismiss()
	await walk(Vector2(426, 182))
	await use("w17_ticket", Vector2(426, 117))
	var flip := scene.hud.panel_content.find_child("FlipTimetable", true, false) as Button
	if not check(is_instance_valid(flip), "时刻表可翻到背面"):
		return
	flip.pressed.emit()
	await time_wait(0.4)
	await dismiss()
	check(state.has_demo_item("laochen_handoff_note"), "正常路线取得嘉敏时刻表背面的求生留言")
	await walk(Vector2(548, 188))
	await use("cold_door", Vector2(548, 145))
	await time_wait(0.5)
	await dismiss()
	await walk(Vector2(548, 90))
	await dismiss()
	await next_room("ch3_quiet_passage")
	await walk(Vector2(565, 205))
	await use("street", Vector2(565, 160))
	await choice("前往亚马喇前地")
	await next_room("ch4_bus_loop")
	await dismiss()
	check(not scene.has_method("inspect_story") and scene.TARGET_SUCCESSES == 5, "主线进入随机五连判断巴士")
	for round_index in range(5):
		await walk(Vector2(620, 274))
		await tap("interact")
		await dismiss()
		await walk(Vector2(910, 271))
		await tap("interact")
		await dismiss()
		await walk(Vector2(1030, 268))
		await tap("interact")
		await dismiss()
		await walk(Vector2(1040, 285))
		await walk(Vector2(1080, 283))
		await tap("interact")
		await dismiss()
		if scene.current_anomaly.is_empty():
			await walk(Vector2(1172, 283))
			await tap("interact")
		else:
			await walk(Vector2(1040, 283))
			await walk(Vector2(1040, 276))
			await walk(Vector2(222, 282))
			await tap("interact")
			check(scene.bell_pulled and scene.success_counter == round_index, "实际拉铃不单独计分")
			await walk(Vector2(90, 283))
			await tap("interact")
		await time_wait(1.35)
		check(scene.success_counter == round_index + 1, "正常按键完成随机第%d轮" % (round_index + 1))
	await time_wait(0.7)
	await choice("前往黑沙海滩")
	await next_room("ch5_hacsa_beach")
	check(state.opening_flags.bus_arrived, "实际跨场景进入黑沙调查")
	await dismiss()
	await walk(Vector2(324, 221))
	await use("car", Vector2(400, 211))
	var switches := board()
	click(switches, Vector2(340, 269))
	check(state.opening_flags.beach_headlights_on, "黑沙起点按新引导走到救援车并直接开启远光")
	await dismiss()
	await walk(Vector2(190, 221))
	await walk(Vector2(190, 330))
	await walk(Vector2(630, 333))
	await walk(Vector2(640, 423))
	await use("trace_a", Vector2(660,456))
	await dismiss()
	await walk(Vector2(665, 482))
	await use("wrack", Vector2(686,510))
	await dismiss()
	await walk(Vector2(665, 333))
	await walk(Vector2(870, 336))
	await use("trace_b", Vector2(880,370))
	await dismiss()
	await tap("journal")
	var footprint = board()
	check(footprint.choice_buttons.size() == 4, "鞋痕对照界面显示四个选择按钮")
	footprint.choice_buttons[0].pressed.emit()
	footprint.choice_buttons[1].pressed.emit()
	for child in footprint.get_children():
		if child is Button and child.text == "确认判断":
			child.pressed.emit()
			break
	check(state.opening_flags.beach_footprints_solved, "正常移动调查三处鞋痕后可作覆盖顺序判断")
	await dismiss()
	check(state.save_opening_checkpoint(), "主线黑沙进度可保存")
	await walk(Vector2(925, 336))
	await walk(Vector2(925, 191))
	await use("key_box", Vector2(937, 171))
	var key_box := board()
	mouse(key_box, Vector2(300, 160), MOUSE_BUTTON_LEFT, true)
	var lift := InputEventMouseMotion.new()
	lift.position = Vector2(300, 137)
	key_box._gui_input(lift)
	lift.position = Vector2(440, 137)
	key_box._gui_input(lift)
	mouse(key_box, Vector2(440, 137), MOUSE_BUTTON_LEFT, false)
	click(key_box, Vector2(255, 171))
	check(state.has_demo_item("beach_cabinet_key"), "正常路线抬盖侧拉并拾取钥匙")
	await dismiss()
	await walk(Vector2(925, 230))
	await walk(Vector2(1110, 230))
	await use("cabinet", Vector2(1110, 191))
	await time_wait(0.8)
	await use("cabinet", Vector2(1110, 191))
	var plan := board()
	mouse(plan, plan.ROUTE[0], MOUSE_BUTTON_LEFT, true)
	for point in plan.ROUTE.slice(1):
		var follow := InputEventMouseMotion.new()
		follow.position = point
		plan._gui_input(follow)
	mouse(plan, plan.ROUTE[-1], MOUSE_BUTTON_LEFT, false)
	check(state.opening_flags.beach_plan_found and state.opening_flags.beach_circuit_matched, "正常路线开柜取得真实工事图并核对通路")
	await dismiss()
	await time_wait(1.2)
	check(state.save_opening_checkpoint(), "鞋痕、钥匙、开柜与图纸结果可保存")
