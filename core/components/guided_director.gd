extends CanvasLayer

# AI Guided Playtest Director (--guided-playtest)
# Lets the user sit back and watch AI smoothly play through every chapter,
# pause anytime with Space/F8 to inspect details, take over manually with F7,
# jump between chapters with F5/F6, or save timestamped issue screenshots with F10.

const CHAPTERS := [
	{"id": "ch0_hk_work", "entry": "arrival", "label": "序章① · 香港工作间→港珠澳大桥→新福利→澳门街口→唐楼"},
	{"id": "ch0_ah_kin", "entry": "from_foyer", "label": "序章② · 阿豪后廊遇害→304房间→后院追逐→电话亭"},
	{"id": "ch1_crypt_entry", "entry": "from_lane", "label": "第一章 · 大三巴地宫→白骨黑袍老伯追逐→资料室"},
	{"id": "ch2_hill_base", "entry": "from_archive", "label": "第二章 · 松山防空洞→99级台阶→子弹房→无底竖井"},
	{"id": "ch3_amparo_archive", "entry": "from_bunker", "label": "第三章 · 大关斜巷肉铺旧杆秤→暗巷"},
	{"id": "ch4_bus_loop", "entry": "from_w17_ticket", "label": "第四章 · 新福利33路午夜巴士循环→撞车黑沙"},
	{"id": "ch5_hacsa_beach", "entry": "from_bus_crash", "label": "第五章 · 黑沙海滩溺水女鬼→沿海工事→调压廊"},
	{"id": "ch6_abandoned_vip", "entry": "from_pressure_gallery", "label": "第六章 · 2011百利新邨渗血石屎封墙→破晓真章"}
]

const SPEED_OPTIONS := [1.0, 2.0, 4.0, 8.0]
const MAX_HISTORY := 40

var chapter_index := 0
var auto_enabled := true
var frozen := false
var manual_takeover := false
var busy_room := ""
var run_token := 0
var speed_index := 0
var holding_ff := false
var watch_clock := 0.0
var snapshot_accum := 0.0
var history_frames: Array[Dictionary] = []
var bar_status: Label
var bar_hint: Label
var btn_pause: Button
var btn_manual: Button
var btn_speed: Button
var btn_rewind: Button
var held_actions: Array[String] = []

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	call_deferred("_start_watch_session")

func _build_overlay() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(4, 2)
	panel.size = Vector2(632, 24)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.06, 0.05, 0.88)
	style.border_color = Color("bfa56a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	panel.add_child(row)

	bar_status = Label.new()
	bar_status.text = "▶ 1x"
	bar_status.add_theme_font_size_override("font_size", 10)
	bar_status.add_theme_color_override("font_color", Color("8ef0a8"))
	bar_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar_status)

	btn_rewind = _mini_btn("⏪ 回退(←)", _rewind_step)
	row.add_child(btn_rewind)
	btn_pause = _mini_btn("空格 暂停", _toggle_freeze)
	row.add_child(btn_pause)
	btn_speed = _mini_btn("⏩ 1x (按住→)", _cycle_speed)
	row.add_child(btn_speed)
	btn_manual = _mini_btn("F7 手动", _toggle_manual)
	row.add_child(btn_manual)
	row.add_child(_mini_btn("F5 上章", func(): _jump_chapter(chapter_index - 1)))
	row.add_child(_mini_btn("F6 下章", func(): _jump_chapter(chapter_index + 1)))
	row.add_child(_mini_btn("F10 截图", _capture_feedback_shot))

	bar_hint = Label.new()
	bar_hint.position = Vector2(8, 28)
	bar_hint.size = Vector2(620, 18)
	bar_hint.add_theme_font_size_override("font_size", 10)
	bar_hint.add_theme_color_override("font_color", Color("ffe7a0"))
	bar_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	bar_hint.add_theme_constant_override("shadow_offset_y", 1)
	bar_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_hint)

func _mini_btn(caption: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = caption
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_color_override("font_color", Color("efe7cf"))
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.11, 0.19, 0.16, 0.92)
	st.border_color = Color("7b6e4e")
	st.set_border_width_all(1)
	st.set_corner_radius_all(2)
	st.content_margin_left = 5
	st.content_margin_right = 5
	b.add_theme_stylebox_override("normal", st)
	var hv := st.duplicate() as StyleBoxFlat
	hv.bg_color = Color(0.20, 0.34, 0.27, 0.96)
	hv.border_color = Color("e8cf86")
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.pressed.connect(cb)
	return b

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if event.keycode == KEY_RIGHT and not manual_takeover:
		if event.pressed and not event.echo:
			holding_ff = true
			if frozen:
				frozen = false
				get_tree().paused = false
			_apply_time_scale()
			_refresh_bar()
			bar_hint.text = "⏩ 正在按住 → 快进播放 (%.0fx)..." % Engine.time_scale
		elif not event.pressed:
			holding_ff = false
			_apply_time_scale()
			_refresh_bar()
		get_viewport().set_input_as_handled()
		return
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_LEFT:
			if manual_takeover:
				return
			get_viewport().set_input_as_handled()
			_rewind_step()
		KEY_F8, KEY_SPACE:
			if event.keycode == KEY_SPACE and manual_takeover:
				return
			get_viewport().set_input_as_handled()
			_toggle_freeze()
		KEY_F7:
			get_viewport().set_input_as_handled()
			_toggle_manual()
		KEY_F5:
			get_viewport().set_input_as_handled()
			_jump_chapter(chapter_index - 1)
		KEY_F6:
			get_viewport().set_input_as_handled()
			_jump_chapter(chapter_index + 1)
		KEY_F10:
			get_viewport().set_input_as_handled()
			_capture_feedback_shot()

func _apply_time_scale() -> void:
	if frozen or manual_takeover:
		Engine.time_scale = 1.0
	elif holding_ff:
		Engine.time_scale = 8.0 if SPEED_OPTIONS[speed_index] >= 4.0 else 5.0
	else:
		Engine.time_scale = SPEED_OPTIONS[speed_index]

func _cycle_speed() -> void:
	speed_index = (speed_index + 1) % SPEED_OPTIONS.size()
	if frozen:
		frozen = false
		get_tree().paused = false
	_apply_time_scale()
	_refresh_bar()
	bar_hint.text = "⏩ 倍速已切换为 %.0fx（也可随时按住 → 临时高速快进，按 ← 回退）" % SPEED_OPTIONS[speed_index]

func _record_snapshot(force := false) -> void:
	var room := GameState.current_room_id
	if room.is_empty():
		return
	if not force and not history_frames.is_empty():
		var last: Dictionary = history_frames.back()
		if last.room_id == room and (watch_clock - float(last.watch_time)) < 2.2:
			return
	var scene := get_tree().current_scene
	var pos := Vector2.ZERO
	var ldir := Vector2.RIGHT
	if scene != null and ("player" in scene) and is_instance_valid(scene.player):
		pos = scene.player.position
		ldir = scene.player.look_dir
	history_frames.append({
		"room_id": room,
		"entry_id": GameState.pending_entry_id,
		"chapter_index": chapter_index,
		"player_pos": pos,
		"look_dir": ldir,
		"flags": GameState.opening_flags.duplicate(true),
		"items": GameState.opening_items.duplicate(true),
		"bus_loop_state": GameState.bus_loop_state.duplicate(true),
		"current_role": GameState.current_role,
		"stamina": GameState.stamina,
		"flashlight_battery": GameState.flashlight_battery,
		"phone_battery": GameState.phone_battery,
		"equipped_item_id": GameState.equipped_item_id,
		"watch_time": watch_clock
	})
	if history_frames.size() > MAX_HISTORY:
		history_frames.pop_front()

func _rewind_step() -> void:
	if history_frames.is_empty():
		bar_hint.text = "⏪ 已经在当前片段开头，可按 F5 切回上一章"
		return
	var snap: Dictionary = history_frames.pop_back()
	if not history_frames.is_empty() and snap.room_id == GameState.current_room_id and (watch_clock - float(snap.watch_time)) < 1.5:
		snap = history_frames.pop_back()
	run_token += 1
	var token := run_token
	_release_all_keys()
	holding_ff = false
	frozen = false
	get_tree().paused = false
	_apply_time_scale()
	chapter_index = int(snap.chapter_index)
	GameState.opening_flags = snap.flags.duplicate(true)
	GameState.opening_items = snap.items.duplicate(true)
	GameState.bus_loop_state = snap.bus_loop_state.duplicate(true)
	GameState.current_role = String(snap.current_role)
	GameState.stamina = float(snap.stamina)
	GameState.flashlight_battery = float(snap.flashlight_battery)
	GameState.phone_battery = float(snap.phone_battery)
	GameState.equipped_item_id = String(snap.equipped_item_id)
	watch_clock = float(snap.watch_time)
	busy_room = String(snap.room_id)
	GameState.request_room_change(String(snap.room_id), String(snap.entry_id))
	_refresh_bar()
	bar_hint.text = "⏪ 已回退到 %.1fs 处（%s）" % [watch_clock, snap.room_id]
	call_deferred("_finish_rewind", snap, token)

func _finish_rewind(snap: Dictionary, token: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or token != run_token:
		return
	var scene := get_tree().current_scene
	if scene != null and ("player" in scene) and is_instance_valid(scene.player) and snap.player_pos != Vector2.ZERO:
		scene.player.position = snap.player_pos
		scene.player.look_dir = snap.look_dir
		scene.player.reset_physics_interpolation()
	_drive_current_room(String(snap.room_id), token)

func _toggle_freeze() -> void:
	frozen = not frozen
	holding_ff = false
	_release_all_keys()
	get_tree().paused = frozen
	_apply_time_scale()
	_refresh_bar()
	bar_hint.text = "⏸ 画面已定格——按 ← 回退 / F10 截图 / 空格 继续" if frozen else "▶ 继续播放..."

func _toggle_manual() -> void:
	manual_takeover = not manual_takeover
	holding_ff = false
	_release_all_keys()
	if manual_takeover and frozen:
		frozen = false
		get_tree().paused = false
	_apply_time_scale()
	_refresh_bar()
	bar_hint.text = "🎮 已交给你手动控制！随时按 F7 交回 AI，或按 F6 跳下一章" if manual_takeover else "🤖 AI 重新接管当前关卡跑测"
	if not manual_takeover:
		busy_room = ""

func _refresh_bar() -> void:
	var room_name := GameState.current_room_id
	var spd := "%.0fx" % (8.0 if (holding_ff and SPEED_OPTIONS[speed_index] >= 4.0) else (5.0 if holding_ff else SPEED_OPTIONS[speed_index]))
	if is_instance_valid(btn_speed):
		btn_speed.text = ("⏩ %s快进中" % spd) if holding_ff else ("⏩ %.0fx(→)" % SPEED_OPTIONS[speed_index])
	if frozen:
		bar_status.text = "⏸ 暂停 · %s" % room_name
		bar_status.add_theme_color_override("font_color", Color("ffd078"))
		btn_pause.text = "空格 继续"
	elif manual_takeover:
		bar_status.text = "🎮 手动 · %s" % room_name
		bar_status.add_theme_color_override("font_color", Color("8cd8ff"))
		btn_pause.text = "空格 暂停"
		btn_manual.text = "F7 交回AI"
	else:
		bar_status.text = "%s %s · %s" % ["⏩" if (holding_ff or speed_index > 0) else "▶", spd, room_name]
		bar_status.add_theme_color_override("font_color", Color("ffd670") if holding_ff else Color("8ef0a8"))
		btn_pause.text = "空格 暂停"
		btn_manual.text = "F7 手动"

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _capture_feedback_shot() -> void:
	DirAccess.make_dir_recursive_absolute("d:/Aomen_Paranormal_Records/docs/playtest_feedback")
	var dt := Time.get_datetime_dict_from_system()
	var fname := "issue_%04d%02d%02d_%02d%02d%02d_%s.png" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second, GameState.current_room_id]
	var full := "d:/Aomen_Paranormal_Records/docs/playtest_feedback/" + fname
	var img := get_viewport().get_texture().get_image()
	if img != null and img.save_png(full) == OK:
		bar_hint.text = "📸 已保存问题截图：docs/playtest_feedback/%s" % fname
	else:
		bar_hint.text = "截图保存失败"

func _start_watch_session() -> void:
	await get_tree().create_timer(1.2, true).timeout
	_jump_chapter(0)

func _jump_chapter(idx: int) -> void:
	chapter_index = posmod(idx, CHAPTERS.size())
	run_token += 1
	busy_room = ""
	history_frames.clear()
	watch_clock = 0.0
	holding_ff = false
	_release_all_keys()
	frozen = false
	get_tree().paused = false
	_apply_time_scale()
	var ch: Dictionary = CHAPTERS[chapter_index]
	GameState.reset_opening()
	GameState.opening_resume_checked = true
	_prepare_state_for_chapter(chapter_index)
	bar_hint.text = "正在载入：%s" % ch.label
	GameState.request_room_change(ch.id, ch.entry)
	_refresh_bar()

func _prepare_state_for_chapter(idx: int) -> void:
	if idx >= 1:
		GameState.opening_flags.intro_job_done = true
		GameState.opening_flags.intro_invited = true
		GameState.opening_flags.intro_photo_seen = true
		GameState.opening_flags.intro_plan_seen = true
		GameState.opening_flags.intro_boarded = true
		GameState.opening_flags.photo_taken = true
		GameState.opening_flags.pastry_shared = true
		GameState.opening_flags.knock_agreed = true
		GameState.opening_flags.entered_foyer = true
		GameState.opening_flags.meter_cover_open = true
		GameState.opening_flags.floor3_power = true
		GameState.take_demo_item("old_304_photo")
		GameState.take_demo_item("trip_map")
		GameState.take_demo_item("insulated_bridge")
		GameState.take_demo_item("ceramic_fuse")
		GameState.take_demo_item("power_record")
	if idx >= 2:
		GameState.opening_flags.ah_hao_dead = true
		GameState.opening_flags.jiamin_phone_found = true
		GameState.opening_flags.room_phone_answered = true
		GameState.opening_flags.wardrobe_tutorial_done = true
		GameState.opening_flags.shadow_passed = true
		GameState.opening_flags.room_bed_moved = true
		GameState.opening_flags.room_cover_open = true
		GameState.opening_flags.maintenance_unlocked = true
		GameState.opening_flags.yard_escaped = true
		GameState.opening_flags.help_attempted = true
		GameState.take_demo_item("jiamin_phone")
		GameState.take_demo_item("ahhao_camera")
		GameState.take_demo_item("service_handle")
	if idx >= 3:
		GameState.opening_flags.crypt_photo_seen = true
		GameState.opening_flags.crypt_plan_seen = true
		GameState.opening_flags.crypt_doodle_seen = true
		GameState.opening_flags.crypt_aligned = true
		GameState.opening_flags.crypt_clip_removed = true
		GameState.opening_flags.crypt_door_open = true
		GameState.opening_flags.priest_escaped = true
		GameState.opening_flags.interview_index_copied = true
		GameState.take_demo_item("crypt_old_photo")
		GameState.take_demo_item("crypt_survey")
		GameState.take_demo_item("crypt_doodle")
		GameState.take_demo_item("interview_index")
	if idx >= 4:
		GameState.opening_flags.hill_stele_seen = true
		GameState.opening_flags.hill_warning_seen = true
		GameState.opening_flags.bunker_gate_unlocked = true
		GameState.opening_flags.ammo_chase_cleared = true
		GameState.opening_flags.hill_steps_completed = true
		GameState.opening_flags.demo_case_closed = true
		GameState.take_demo_item("bunker_recording")
	if idx >= 5:
		GameState.opening_flags.ch3_guest_inferred = true
		GameState.opening_flags.ch3_balance_rule_seen = true
		GameState.opening_flags.ch3_balance_solved = true
		GameState.opening_flags.ch3_cold_door_open = true
		GameState.take_demo_item("archive_spare_key")
		GameState.take_demo_item("w17_bus_ticket")
		GameState.take_demo_item("laochen_handoff_note")
		GameState.take_demo_item("jiamin_lens_cap")
	if idx >= 6:
		GameState.opening_flags.bus_arrived = true
		GameState.take_demo_item("shoe_repair_photo")
	if idx >= 7:
		GameState.opening_flags.beach_headlights_on = true
		GameState.opening_flags.beach_footprints_solved = true
		GameState.opening_flags.beach_key_box_open = true
		GameState.opening_flags.beach_cabinet_open = true
		GameState.opening_flags.beach_circuit_matched = true
		GameState.opening_flags.coastal_route_verified = true
		GameState.opening_flags.coastal_crawlway_seen = true
		GameState.opening_flags.coastal_chamber_route_verified = true
		GameState.opening_flags.coastal_silt_route_verified = true
		GameState.opening_flags.coastal_pressure_route_verified = true
		GameState.take_demo_item("beach_cabinet_key")
		GameState.take_demo_item("hotel_maintenance_plan")

func _process(delta: float) -> void:
	if frozen or manual_takeover:
		return
	watch_clock += delta
	var room := GameState.current_room_id
	if room != busy_room and get_tree().current_scene != null:
		busy_room = room
		_record_snapshot(true)
		_refresh_bar()
		var token := run_token
		call_deferred("_drive_current_room", room, token)
	else:
		_record_snapshot(false)

func _wait_watch(sec: float, token: int) -> bool:
	var elapsed := 0.0
	while elapsed < sec:
		await get_tree().process_frame
		if not is_inside_tree() or token != run_token:
			return false
		if not frozen and not manual_takeover:
			elapsed += get_process_delta_time()
	return true

func _release_all_keys() -> void:
	for a in held_actions:
		Input.action_release(a)
	held_actions.clear()

func _tap(action: String, token: int) -> bool:
	while frozen or manual_takeover:
		await get_tree().process_frame
		if token != run_token:
			return false
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var rel := InputEventAction.new()
	rel.action = action
	rel.pressed = false
	Input.parse_input_event(rel)
	await get_tree().process_frame
	return token == run_token

func _walk_to(target: Vector2, token: int, sprint := false, aim_at := Vector2.ZERO) -> bool:
	var scene := get_tree().current_scene
	if scene == null or not ("player" in scene) or not is_instance_valid(scene.player):
		return false
	var player: PlayerController = scene.player
	for _step in range(900):
		if token != run_token or not is_instance_valid(player) or get_tree().current_scene != scene:
			_release_all_keys()
			return false
		if frozen or manual_takeover or get_tree().paused:
			_release_all_keys()
			await get_tree().physics_frame
			continue
		var diff := target - player.position
		if diff.length() < 8.0:
			break
		if aim_at != Vector2.ZERO:
			player.look_dir = (aim_at - player.position).normalized()
		else:
			player.look_dir = diff.normalized()
		var want: Array[String] = []
		if diff.x < -3.0: want.append("move_left")
		elif diff.x > 3.0: want.append("move_right")
		if diff.y < -3.0: want.append("move_up")
		elif diff.y > 3.0: want.append("move_down")
		if sprint: want.append("sprint")
		for old_a in held_actions.duplicate():
			if old_a not in want:
				Input.action_release(old_a)
				held_actions.erase(old_a)
		for new_a in want:
			if new_a not in held_actions:
				Input.action_press(new_a)
				held_actions.append(new_a)
		await get_tree().physics_frame
	_release_all_keys()
	if is_instance_valid(player):
		player.clear_motion()
	return token == run_token

func _read_and_close(token: int, pause_sec := 1.9) -> bool:
	for _attempt in range(10):
		var scene := get_tree().current_scene
		if scene == null or not ("hud" in scene) or not is_instance_valid(scene.hud) or not scene.hud.panel_open:
			return true
		if not await _wait_watch(pause_sec, token):
			return false
		if not await _tap("interact", token):
			return false
		await get_tree().process_frame
		await get_tree().process_frame
		if is_instance_valid(scene) and is_instance_valid(scene.hud) and scene.hud.panel_open:
			if not await _tap("pause", token):
				return false
	return token == run_token

func _drive_current_room(room: String, token: int) -> void:
	if not await _wait_watch(0.9, token): return
	var scene := get_tree().current_scene
	if scene == null: return
	match room:
		"ch0_hk_work":
			bar_hint.text = "【演示】香港维修间：整理工作台 → 嘉敏来访 → 回家"
			if not await _walk_to(Vector2(172, 195), token): return
			await _tap("interact", token); await _read_and_close(token, 1.8)
			if not await _walk_to(Vector2(442, 232), token): return
			await _tap("interact", token); await _read_and_close(token, 2.0)
			if not await _walk_to(Vector2(525, 192), token): return
			await _tap("interact", token)
		"ch0_hk_home":
			bar_hint.text = "【演示】大文家：查看台灯下 304 旧照 → 澳门手绘路线图 → 出发"
			if not await _walk_to(Vector2(196, 185), token): return
			await _tap("interact", token); await _read_and_close(token, 2.2)
			if not await _walk_to(Vector2(344, 186), token): return
			await _tap("interact", token); await _read_and_close(token, 2.4)
			if not await _walk_to(Vector2(540, 184), token): return
			await _tap("interact", token); await _read_and_close(token, 2.0)
		"ch0_bridge_bus":
			bar_hint.text = "【演示】港珠澳大桥跨海段 → 换乘澳门新福利巴士投币 6 元 → 抵达大三巴"
			if not await _wait_watch(2.6, token): return
			if scene.has_method("_board_transmac_bus"):
				scene._board_transmac_bus()
			if not await _wait_watch(2.2, token): return
			if "bus_coin_btn" in scene and is_instance_valid(scene.bus_coin_btn):
				scene.bus_coin_btn.pressed.emit()
			if not await _wait_watch(2.6, token): return
			if scene.has_method("_arrive"):
				scene._arrive()
		"ch0_street":
			bar_hint.text = "【演示】澳门大三巴街：拍旅行照 → 捡跨接片 → 接葡挞 → 进唐楼"
			await _read_and_close(token, 1.8)
			if not await _walk_to(Vector2(168, 212), token): return
			await _tap("interact", token); await _read_and_close(token, 1.6)
			if not await _walk_to(Vector2(245, 255), token, false, Vector2(405, 226)): return
			GameState.opening_flags.photo_taken = true
			if not await _walk_to(Vector2(372, 232), token, false, Vector2(405, 226)): return
			if scene.has_method("accept_pastry"):
				scene.accept_pastry()
			await _read_and_close(token, 1.8)
			GameState.opening_flags.knock_agreed = true
			if not await _walk_to(Vector2(487, 178), token, false, Vector2(487, 159)): return
			if scene.has_method("enter_foyer"):
				scene.enter_foyer()
		"ch0_foyer":
			bar_hint.text = "【演示】唐楼一楼门厅：捡陶瓷芯与值班单 → 修电表箱 → 上三楼"
			await _read_and_close(token, 1.8)
			if not await _walk_to(Vector2(124, 185), token): return
			await _tap("interact", token); await _read_and_close(token, 1.5)
			if not await _walk_to(Vector2(304, 180), token): return
			await _tap("interact", token); await _read_and_close(token, 1.5)
			if not await _walk_to(Vector2(210, 160), token, false, Vector2(210, 139)): return
			if scene.has_method("remove_meter_cover"):
				scene.remove_meter_cover()
			if not await _wait_watch(2.2, token): return
			if scene.has_method("show_power_puzzle"):
				scene.show_power_puzzle()
			if not await _wait_watch(2.4, token): return
			if scene.has_method("choose_power_branch"):
				scene.choose_power_branch(scene.power_puzzle.success_branch)
			await _read_and_close(token, 1.8)
			if not await _walk_to(Vector2(516, 155), token): return
			await _tap("interact", token)
		"ch0_ah_kin":
			bar_hint.text = "【演示】序章·阿豪视角：举补光灯拉闸 → 后廊逃亡遇害 → GTA5式切回大文！"
			await _read_and_close(token, 2.0)
			if not await _walk_to(Vector2(510, 215), token): return
			await _tap("interact", token)
			if not await _wait_watch(1.2, token): return
			await _walk_to(Vector2(140, 225), token, true)
		"ch0_room304":
			bar_hint.text = "【演示】福荣里304：拾嘉敏手机 → 接听座机 → 躲衣柜避黑影 → 推床拆检修口"
			await _read_and_close(token, 1.8)
			if not GameState.opening_flags.jiamin_phone_found:
				if not await _walk_to(Vector2(345, 272), token): return
				if scene.has_method("pickup_phone"): scene.pickup_phone()
				if not await _wait_watch(1.5, token): return
				await _read_and_close(token, 2.0)
			if not GameState.opening_flags.room_phone_answered:
				if not await _walk_to(Vector2(300, 220), token): return
				if scene.has_method("answer_room_phone"): scene.answer_room_phone()
				if not await _wait_watch(2.8, token): return
			if not GameState.opening_flags.shadow_passed:
				if not await _walk_to(Vector2(148, 206), token): return
				if scene.has_method("enter_room_wardrobe"): scene.enter_room_wardrobe()
				if not await _wait_watch(6.2, token): return
				if scene.has_method("exit_room_wardrobe"): scene.exit_room_wardrobe()
			if not GameState.opening_flags.old_photo_seen:
				if not await _walk_to(Vector2(300, 220), token): return
				if scene.has_method("show_old_photo"): scene.show_old_photo()
				await _read_and_close(token, 2.0)
			if not GameState.opening_flags.room_bed_moved:
				if not await _walk_to(Vector2(500, 255), token): return
				if scene.has_method("move_room_bed"): scene.move_room_bed()
				if not await _wait_watch(2.0, token): return
				await _read_and_close(token, 1.8)
			if not GameState.opening_flags.room_cover_open:
				if scene.has_method("remove_room_cover"): scene.remove_room_cover()
				if not await _wait_watch(2.6, token): return
				await _read_and_close(token, 1.8)
			if scene.has_method("crawl_into_maintenance"): scene.crawl_into_maintenance()
		"ch1_crypt_entry":
			bar_hint.text = "【演示】第一章·大三巴地宫：收集三线索 → 解开全新「1961三印石龛机关锁」→ 进石廊"
			await _read_and_close(token, 1.6)
			GameState.opening_flags.crypt_photo_seen = true
			GameState.opening_flags.crypt_plan_seen = true
			GameState.opening_flags.crypt_doodle_seen = true
			if not await _walk_to(Vector2(145, 195), token): return
			if scene.has_method("show_crypt_comparison"):
				scene.show_crypt_comparison()
				if not await _wait_watch(1.5, token): return
				var brd: Node = scene.hud.panel_content.get_node_or_null("CryptComparison") if is_instance_valid(scene.hud) else null
				if brd != null and brd.has_method("_rotate_dial"):
					brd._rotate_dial(0, 1)
					if not await _wait_watch(0.6, token): return
					brd._rotate_dial(1, 2)
					if not await _wait_watch(0.6, token): return
					brd._rotate_dial(2, 3)
					if not await _wait_watch(0.8, token): return
					brd._try_unlock()
					if not await _wait_watch(1.6, token): return
			await _read_and_close(token, 1.8)
			if not await _walk_to(Vector2(510, 185), token): return
			GameState.opening_flags.crypt_door_open = true
			if scene.has_method("change_opening_room"): scene.change_opening_room("ch1_crypt_hall", "from_entry")
		"ch2_hill_base":
			bar_hint.text = "【演示】第二章·松山山脚→防空洞铁门→直下99级鬼阶（按 F6 可直接跳肉铺）"
			await _read_and_close(token, 1.6)
			GameState.opening_flags.bunker_gate_unlocked = true
			GameState.take_demo_item("bunker_recording")
			GameState.request_room_change("ch2_hill_steps", "from_hall")
		"ch2_hill_steps":
			bar_hint.text = "【演示】第二章·全新重做 99 级鬼阶：身后唤声严禁回头 + 顶墙绝路（按 F7 接管或 F6 跳第三章）"
			await _walk_to(Vector2(320, 2100), token, true, Vector2(320, 1900))
			bar_hint.text = "已演示 99 级鬼阶前半段！按 F7 手动体验回头杀与鬼打墙，或按 F6 跳第三章【大关斜巷肉铺】"
		"ch1_crypt_hall":
			bar_hint.text = "【演示】大三巴石廊：手电照出黑袍白骨并定身惨叫 → 绕行逃出！"
			await _read_and_close(token, 1.8)
			if not await _wait_watch(1.8, token): return
			if not await _walk_to(Vector2(320, 250), token, false, Vector2(500, 220)): return
			if not await _wait_watch(1.4, token): return
			if not await _walk_to(Vector2(535, 215), token, true, Vector2(500, 220)): return
			if scene.has_method("escape_priest"): scene.escape_priest()
		"ch3_amparo_archive":
			bar_hint.text = "【演示】第三章·大关斜巷肉铺：实景旧杆秤称量 → 开启冷柜门"
			await _read_and_close(token, 1.8)
			if not await _walk_to(Vector2(278, 185), token): return
			GameState.opening_flags.ch3_guest_inferred = true
			GameState.opening_flags.ch3_cold_door_seen = true
			GameState.opening_flags.ch3_balance_rule_seen = true
			if scene.has_method("interact_target"): scene.interact_target("balance")
			if not await _wait_watch(2.8, token): return
			if "balance_board" in scene and is_instance_valid(scene.balance_board):
				scene.balance_board._toggle_weight(0)
				if not await _wait_watch(0.6, token): return
				scene.balance_board._toggle_weight(1)
				if not await _wait_watch(0.6, token): return
				scene.balance_board._toggle_weight(2)
				if not await _wait_watch(0.8, token): return
				scene.balance_board.submit_weight()
			if not await _wait_watch(2.0, token): return
			bar_hint.text = "第三章肉铺演示完成！按 F6 跳去第四章【33路午夜巴士】，或按 F7 手动逛逛"
		"ch4_bus_loop":
			bar_hint.text = "【演示】33 路末班车：巡查五类异象，连续判断正确五次才能离开。"
			await _read_and_close(token, 2.2)
			if not await _walk_to(Vector2(1050, 283), token): return
			if not await _wait_watch(1.4, token): return
			if not await _walk_to(Vector2(240, 283), token): return
			bar_hint.text = "已巡视整节车厢！按 F7 手动判断前门/拉铃后门，或按 F6 跳去第五章【黑沙海滩】"
		"ch5_hacsa_beach":
			bar_hint.text = "【演示】第五章·黑沙海滩：手电探查沙滩脚印与新版溺水女鬼（按 F6 跳终章）"
			await _read_and_close(token, 2.0)
			if not await _walk_to(Vector2(540, 240), token): return
			if not await _walk_to(Vector2(760, 420), token, false, Vector2(920, 460)): return
			bar_hint.text = "已来到黑沙海滩与溺水女鬼区域！按 F7 手动体验追逐/脚印，或按 F6 跳第六章【渗血石屎终章】"
		"ch6_abandoned_vip":
			bar_hint.text = "【演示】终章·2011百利新邨渗血石屎封墙：嘉敏敲出两短一长 → 切回大文合高压闸引怪电击破门"
			await _read_and_close(token, 2.2)
			bar_hint.text = "已进入终章控制间！按 F7 手动操控嘉敏/大文，按 Space 随时定格，按 F10 截图记问题"
		_:
			bar_hint.text = "当前房间：%s（按 F6 跳下一章 / F7 接管手动 / Space 暂停 / F10 截图）" % room
