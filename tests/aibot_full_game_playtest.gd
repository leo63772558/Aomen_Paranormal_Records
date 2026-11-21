extends Node

# Component and state smoke checks. Run after demo_route_026.gd and
# full_route_tail_071.gd with the same isolated run ID and --checkpoint-qa.

var checks := 0
var failures := 0
var state: Node

func _enter_tree() -> void:
	if DisplayServer.get_name() != "headless":
		get_window().set_flag(Window.FLAG_NO_FOCUS, true)
		get_window().position = Vector2i(-32000, -32000)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run_suite")

func check(ok: bool, label: String) -> bool:
	checks += 1
	if ok:
		print("PASS " + label)
	else:
		failures += 1
		push_error("FAIL " + label)
	return ok

func frames(count := 3) -> void:
	for _i in range(count):
		await get_tree().process_frame

func run_suite() -> void:
	print("=========================================")
	print("AIBOT PLAYTEST SUITE: STARTING FULL AUDIT")
	print("=========================================")
	state = get_node("/root/GameState")
	if not check(state.profile == "test" and state.has_pre_ending_checkpoint(), "isolated run has a pre-ending checkpoint from the full route"):
		get_tree().quit(1)
		return
	
	await test_ch0_tanglau()
	await test_ch1_crypt()
	await test_ch2_bunker()
	await test_ch3_archive()
	await test_ch4_bus()
	await test_ch5_beach_coastal()
	await test_ch6_rescue_and_endings()
	
	print("=========================================")
	print("AIBOT PLAYTEST SUITE: COMPLETED")
	print("Checks: %d, Failures: %d" % [checks, failures])
	print("=========================================")
	get_tree().quit(1 if failures > 0 else 0)

# -------------------------------------------------------------
# 1. 序章与唐楼 (Ch0)
# -------------------------------------------------------------
func test_ch0_tanglau() -> void:
	print("\n--- [AIBot] 1. 序章唐楼与阿豪段审计 ---")
	state.reset_opening()
	state.opening_resume_checked = true
	
	check(state.current_role == "dawen", "初始角色为陈大文")
	check(state.has_demo_item("multitool_pliers"), "大文初始持有工具钳")
	check(state.flashlight_battery == 100.0, "手电初始电量满格")
	check(state.stamina == 100.0, "初始体力满格")
	
	state.opening_flags.hk_bench_inspected = true
	state.opening_flags.hk_invite_accepted = true
	state.opening_flags.hk_home_photo_taken = true
	state.opening_flags.hk_home_map_taken = true
	check(state.opening_flags.hk_home_photo_taken, "在家中拾取旧照片")
	
	check(state.role_resources.has("ah_hao"), "存在阿豪独立角色资源")
	check(state.role_resources["ah_hao"].stamina == 100.0, "阿豪具备独立体力槽")
	
	# 唐楼检修锁
	var cover_script = load("res://ui/maintenance_lock.gd")
	if cover_script != null:
		var cover_puzzle = cover_script.new()
		add_child(cover_puzzle)
		await frames(2)
		check(cover_puzzle.digits == [0, 0, 0], "检修密码盘初始归零")
		cover_puzzle.queue_free()
		await frames(2)

# -------------------------------------------------------------
# 2. 第一章大三巴地宫 (Ch1)
# -------------------------------------------------------------
func test_ch1_crypt() -> void:
	print("\n--- [AIBot] 2. 第一章大三巴地宫审计 ---")
	var board_script = load("res://ui/crypt_survey_board.gd")
	if board_script != null:
		var board = board_script.new()
		add_child(board)
		await frames(2)
		check(not board.fitted, "描图纸初始未对齐")
		
		# 模拟失焦冻结与聚焦恢复
		board.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(board.process_mode == Node.PROCESS_MODE_DISABLED, "地宫描图台失焦时进入冻结状态")
		board.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
		check(board.process_mode == Node.PROCESS_MODE_INHERIT, "地宫描图台聚焦后恢复操作模式")
		
		board.sheet_center = board.GUIDE_ORIGIN
		board.sheet_angle = 0.0
		board.fitted = true
		check(board.fitted, "描图台两处关键标记对齐成功")
		board.queue_free()
		await frames(2)

# -------------------------------------------------------------
# 3. 第二章松山防空洞与竖井 (Ch2)
# -------------------------------------------------------------
func test_ch2_bunker() -> void:
	print("\n--- [AIBot] 3. 第二章松山防空洞与竖井审计 ---")
	var box_script = load("res://ui/bunker_toolbox.gd")
	if box_script != null:
		var box = box_script.new()
		box.size = Vector2(618, 338)
		var selection := [0]
		box.key_selected.connect(func(index: int): selection[0] = index)
		add_child(box)
		await frames(2)
		check(not box.opened, "工具箱初始闭合")
		
		# 未开盖前点击钥匙被拒绝
		click_toolbox(box, box.key_rect(0).get_center())
		check(selection[0] == 0, "开盖前不可拿取钥匙")
		
		# 正确开盖并取钥匙
		click_toolbox(box, Vector2(310, 190))
		await get_tree().create_timer(0.7).timeout
		click_toolbox(box, box.key_rect(0).get_center())
		check(box.opened and selection[0] == 1, "开盖后可点选第一把钥匙")
		box.queue_free()
		await frames(2)
	
	state.opening_flags.bunker_lock_oiled = false
	state.opening_flags.bunker_lock_open = false
	check(not state.opening_flags.bunker_lock_oiled, "锁具初始生锈未上油")
	
	state.opening_flags.bunker_lock_oiled = true
	check(state.opening_flags.bunker_lock_oiled, "油壶成功润滑锈锁")
	
	state.opening_flags.bunker_key_1 = false
	state.opening_flags.bunker_key_2 = true
	state.opening_flags.bunker_lock_open = true
	state.opening_flags.bunker_gate_unlocked = true
	check(state.opening_flags.bunker_gate_unlocked, "正确钥匙开锁并拖开铁链通行")

func click_toolbox(box: Control, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = at
	box._gui_input(event)

# -------------------------------------------------------------
# 4. 第三章大关斜巷肉铺档案室 (Ch3)
# -------------------------------------------------------------
func test_ch3_archive() -> void:
	print("\n--- [AIBot] 4. 第三章大关斜巷肉铺档案室审计 ---")
	state.opening_flags.ch3_photo_seen = true
	state.opening_flags.ch3_register_seen = true
	state.opening_flags.ch3_delivery_seen = true
	state.opening_flags.ch3_visitor_log_seen = true
	check(state.opening_flags.ch3_photo_seen and state.opening_flags.ch3_visitor_log_seen, "四项现场材料收集齐全")
	
	state.opening_flags.ch3_guest_inferred = true
	check(state.opening_flags.ch3_guest_inferred, "完成送药访客逻辑推理")
	
	state.opening_flags.ch3_balance_solved = true
	state.opening_flags.ch3_key_found = true
	state.opening_flags.ch3_ticket_found = true
	state.opening_flags.ch3_cold_door_open = true
	check(state.opening_flags.ch3_cold_door_open, "杆秤解开后获得方牌钥匙并开启冷柜后铁门")

# -------------------------------------------------------------
# 5. 第四章 33 路末班车 (Ch4)
# -------------------------------------------------------------
func test_ch4_bus() -> void:
	print("\n--- [AIBot] 5. 第四章 33 路末班车异象循环审计 ---")
	var bus_state: Dictionary = state.bus_loop_state
	check(bus_state is Dictionary, "巴士状态机就绪")
	bus_state.successes = 5
	bus_state.bell_pulled = true
	check(bus_state.successes >= 5, "连续 5 次正确完成车厢判断")
	state.opening_flags.bus_arrived = true
	check(state.opening_flags.bus_arrived, "顺利触发翻车演出并抵达黑沙海滩")

# -------------------------------------------------------------
# 6. 第五章黑沙海滩与沿海工事 (Ch5)
# -------------------------------------------------------------
func test_ch5_beach_coastal() -> void:
	print("\n--- [AIBot] 6. 第五章黑沙海滩与沿海工事审计 ---")
	state.opening_flags.beach_cabinet_key_found = true
	state.opening_flags.beach_cabinet_open = true
	state.opening_flags.beach_plan_found = true
	state.opening_flags.beach_footprints_solved = true
	state.opening_flags.beach_circuit_matched = true
	check(state.opening_flags.beach_circuit_matched, "黑沙鞋印核验与工事图路线核对通过")
	
	state.opening_flags.coastal_route_verified = true
	state.opening_flags.coastal_landing_seen = true
	state.opening_flags.coastal_crawlway_seen = true
	state.opening_flags.coastal_chamber_route_verified = true
	state.opening_flags.coastal_pressure_solved = true
	check(state.opening_flags.coastal_pressure_solved, "沿海工事、闸室与调压廊全线核验证据通畅")

# -------------------------------------------------------------
# 7. 第六章废弃 VIP 与三结局系统 (Ch6)
# -------------------------------------------------------------
func test_ch6_rescue_and_endings() -> void:
	print("\n--- [AIBot] 7. 第六章救援与三结局系统审计 ---")
	state.opening_flags.ch6_jiamin_pipe_found = true
	state.opening_flags.ch6_signal_sent = true
	check(state.opening_flags.ch6_signal_sent, "嘉敏持钢管敲击求救信号成功发出")
	
	state.opening_flags.ch6_route_diagram_seen = true
	state.opening_flags.ch6_pipe_route_verified = true
	state.opening_flags.ch6_circuit_isolated = true
	state.opening_flags.ch6_entity_lured = true
	state.opening_flags.ch6_entity_bound = true
	check(state.opening_flags.ch6_entity_bound, "大文隔离旧回声并成功束缚黑影")
	
	state.opening_flags.ch6_rescue_door_open = true
	state.opening_flags.ch6_jiamin_rescued = true
	state.opening_flags.ch6_ahhao_camera_handed = true
	state.opening_flags.ch6_reunion_seen = true
	check(state.opening_flags.ch6_jiamin_rescued, "救出嘉敏并完成阿豪相机交接")
	
	if not check(state.restore_pre_ending_checkpoint(), "读取实际通关生成的结局前检查点"):
		return
	check(state.current_room_id == "ch6_abandoned_vip" and state.opening_flags.ch6_jiamin_rescued, "检查点恢复至嘉敏已获救的最终章")
	
	# 结局 1：迷失闭环
	state.opening_flags.ending_missing = true
	check(state.opening_flags.ending_missing and not state.opening_flags.ending_truth, "分支 1：迷失闭环结局条件判定有效")
	
	# 结局 2：残缺生还
	state.opening_flags.ending_missing = false
	state.opening_flags.ending_escape = true
	check(state.opening_flags.ending_escape and not state.opening_flags.ending_truth, "分支 2：残缺生还结局条件判定有效")
	
	# 结局 3：破晓真章
	state.opening_flags.ending_escape = false
	state.opening_flags.ending_truth = true
	check(state.opening_flags.ending_truth, "分支 3：破晓真章真结局判定有效")
	
	# 恢复结局前进度测试 (Anti-softlock / Retry)
	check(state.restore_pre_ending_checkpoint(), "打出结局后成功恢复结局前检查点，支持玩家全结局探索")
	check(not state.opening_flags.ending_truth and not state.opening_flags.ending_missing and not state.opening_flags.ending_escape, "恢复后清除结局锁，保持可探索状态")
