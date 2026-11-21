extends Node

var failures := 0
var checks := 0

func _enter_tree() -> void:
	if DisplayServer.get_name() != "headless":
		get_window().set_flag(Window.FLAG_NO_FOCUS, true)
		get_window().position = Vector2i(-32000, -32000)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures += 1

func mouse(board: Control, position: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = down
	board._gui_input(event)

func move(board: Control, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	board._gui_input(event)

func capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png("res://docs/build_reports/drag_focus_%s_250.png" % name) == OK, name + " interrupted state renders")

func run() -> void:
	if GameState.profile != "test":
		push_error("test profile required")
		get_tree().quit(1)
		return
	GameState.reset_opening()
	GameState.opening_flags.bunker_oil_found = true
	GameState.take_demo_item("ceramic_fuse")
	var lock = preload("res://ui/bunker_lock_puzzle.gd").new()
	lock.size = Vector2(618, 330)
	add_child(lock)
	mouse(lock, lock.OIL_TRAY, true)
	move(lock, lock.KEYHOLE)
	lock.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(lock.dragging.is_empty(), "lost focus immediately ends oil drag")
	await capture("lock")
	mouse(lock, lock.KEYHOLE, false)
	check(lock.dragging.is_empty() and not GameState.opening_flags.bunker_lock_oiled, "lost focus cancels oil drag without applying it")
	lock.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	mouse(lock, lock.OIL_TRAY, true)
	move(lock, lock.KEYHOLE)
	mouse(lock, lock.KEYHOLE, false)
	await get_tree().create_timer(0.1, true).timeout
	lock.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var oil_before: float = lock.oil_progress
	await get_tree().create_timer(0.85, true).timeout
	check(lock.busy and not GameState.opening_flags.bunker_lock_oiled and is_equal_approx(lock.oil_progress, oil_before), "focus loss freezes oiling before commit")
	lock.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await get_tree().create_timer(0.85, true).timeout
	check(GameState.opening_flags.bunker_lock_oiled, "oil drag can be retried after focus returns")
	lock.queue_free()
	await get_tree().process_frame
	var panel = preload("res://ui/power_service_panel.gd").new()
	panel.size = Vector2(618, 330)
	add_child(panel)
	mouse(panel, panel.TRAY_POS.ceramic_fuse, true)
	move(panel, panel.SLOT_POS[1])
	panel.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not panel.dragging and panel.selected.is_empty(), "lost focus immediately ends fuse drag")
	await capture("power")
	mouse(panel, panel.SLOT_POS[1], false)
	check(not panel.dragging and panel.parts.ceramic_fuse == -1, "lost focus cancels fuse drag without installing it")
	panel.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	mouse(panel, panel.TRAY_POS.ceramic_fuse, true)
	move(panel, panel.SLOT_POS[1])
	mouse(panel, panel.SLOT_POS[1], false)
	check(panel.parts.ceramic_fuse == 1, "fuse can be installed after focus returns")
	panel._test()
	await get_tree().create_timer(0.05, true).timeout
	panel.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var needle_before: Vector3 = panel.needle_levels
	await get_tree().create_timer(0.5, true).timeout
	check(panel.in_test and panel.needle_levels.is_equal_approx(needle_before), "focus loss freezes the uncompleted circuit test")
	panel.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await get_tree().create_timer(0.4, true).timeout
	check(not panel.in_test, "circuit test continues when focus returns")
	panel.queue_free()
	await get_tree().process_frame
	var crypt = preload("res://ui/crypt_survey_board.gd").new()
	crypt.size = Vector2(618, 330)
	add_child(crypt)
	crypt._turn_to(crypt.sheet_angle + PI / 4.0)
	await get_tree().create_timer(0.04, true).timeout
	crypt.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var angle_before: float = crypt.drawn_angle
	await get_tree().create_timer(0.25, true).timeout
	check(is_equal_approx(crypt.drawn_angle, angle_before), "focus loss freezes tracing rotation")
	crypt.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await get_tree().create_timer(0.25, true).timeout
	check(is_equal_approx(crypt.drawn_angle, crypt.sheet_angle), "tracing rotation resumes on focus return")
	mouse(crypt, crypt.PLAN_TRAY.get_center(), true)
	move(crypt, crypt.GUIDE_ORIGIN)
	crypt.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not crypt.dragging, "lost focus immediately ends tracing drag")
	await capture("crypt")
	mouse(crypt, crypt.GUIDE_ORIGIN, false)
	check(not crypt.dragging and not crypt.fitted, "lost focus cancels a tracing drag")
	crypt.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	crypt.sheet_angle = 0.0
	mouse(crypt, crypt.PLAN_TRAY.get_center(), true)
	move(crypt, crypt.GUIDE_ORIGIN)
	mouse(crypt, crypt.GUIDE_ORIGIN, false)
	check(crypt.fitted, "tracing can be aligned after focus returns")
	crypt.queue_free()
	await get_tree().process_frame
	var wiring = preload("res://ui/floor_power_diagram.gd").new()
	wiring.size = Vector2(618, 330)
	add_child(wiring)
	mouse(wiring, wiring.port(true, 0), true)
	move(wiring, wiring.port(false, 0))
	wiring.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(wiring.dragging.is_empty(), "lost focus immediately ends wire drag")
	await capture("wiring")
	mouse(wiring, wiring.port(false, 0), false)
	check(wiring.dragging.is_empty() and wiring.connected.is_empty(), "lost focus cancels an unfinished wire")
	wiring.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	mouse(wiring, wiring.port(true, 0), true)
	move(wiring, wiring.port(false, 0))
	mouse(wiring, wiring.port(false, 0), false)
	check(wiring.connected.get("A") == "1", "wire can be connected after focus returns")
	wiring.queue_free()
	await get_tree().process_frame
	await check_service_latch()
	await check_crypt_clip()
	print("DRAG FOCUS checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func check_service_latch() -> void:
	GameState.take_demo_item("service_handle")
	var latch = preload("res://ui/service_latch.gd").new()
	latch.size = Vector2(618, 330)
	add_child(latch)
	mouse(latch, latch.TRAY.get_center(), true)
	mouse(latch, latch.CENTER, false)
	mouse(latch, latch.PLATE.get_center(), true)
	mouse(latch, latch.PLATE.get_center(), false)
	mouse(latch, latch.CENTER, true)
	move(latch, latch.CENTER + Vector2(48, 0))
	latch.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(latch.held.is_empty() and is_equal_approx(latch.angle, -1.1) and not latch.rotated, "interrupted latch rotation returns to its closed position")
	await capture("service_latch")
	latch.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	mouse(latch, latch.CENTER, true)
	mouse(latch, latch.CENTER + Vector2(56, 0), false)
	mouse(latch, latch.CENTER, true)
	mouse(latch, latch.CENTER, false)
	check(latch.rotated and is_equal_approx(latch.angle, 0.55), "clicking a turned handle preserves its committed pose")
	check("锁舌" in latch.status, "operating the finished handle points to the remaining bolt action")
	var bolt: Vector2 = latch.SLIDE.get_center()
	mouse(latch, bolt, true)
	move(latch, bolt - Vector2(50, 0))
	latch.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(latch.held.is_empty() and latch.rotated and is_zero_approx(latch.slide), "interrupted bolt drag resets while preserving turned handle")
	latch.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	var result := [0]
	latch.unlocked.connect(func(): result[0] += 1)
	mouse(latch, bolt, true)
	mouse(latch, bolt - Vector2(52, 0), false)
	await get_tree().create_timer(0.4, true).timeout
	check(result[0] == 1, "bolt can be unlocked using the actual release position")
	latch.queue_free()
	await get_tree().process_frame

func check_crypt_clip() -> void:
	var clip = preload("res://ui/crypt_clip.gd").new()
	clip.size = Vector2(618, 338)
	add_child(clip)
	var result := [0]
	clip.removed.connect(func(): result[0] += 1)
	get_tree().paused = true
	mouse(clip, clip.SCREWS[0], true)
	mouse(clip, clip.SCREWS[1], true)
	await get_tree().create_timer(0.08, true).timeout
	clip.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var turns_before: Array = clip.turns.duplicate()
	await get_tree().create_timer(0.65, true).timeout
	check(clip.turns == turns_before and result[0] == 0, "crypt clip freezes both screws and defers completion while unfocused")
	await capture("crypt_clip")
	clip.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await get_tree().create_timer(0.65, true).timeout
	check(is_equal_approx(clip.turns[0], 1.0) and is_equal_approx(clip.turns[1], 1.0) and result[0] == 1, "both clip screws finish once after focus returns")
	get_tree().paused = false
	clip.queue_free()
	await get_tree().process_frame
