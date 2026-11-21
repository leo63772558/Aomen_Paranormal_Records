extends Node

var scene
var checks := 0
var failed := false

func _enter_tree() -> void:
	if DisplayServer.get_name() != "headless":
		get_window().set_flag(Window.FLAG_NO_FOCUS, true)
		get_window().position = Vector2i(-32000, -32000)

func _ready() -> void:
	get_tree().create_timer(45, true).timeout.connect(func(): get_tree().quit(2))
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	failed = failed or not value
	print(("PASS " if value else "FAIL ") + label)

func frames(n := 4) -> void:
	for _i in range(n): await get_tree().process_frame

func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames()
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png("res://docs/build_reports/" + label + ".png") == OK, label)

func mouse(board: Control, at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	board._gui_input(event)

func drag_to(board: Control, at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	board._gui_input(event)

func run() -> void:
	check(GameState.profile == "test", "isolated_profile")
	GameState.reset_opening()
	GameState.opening_resume_checked = true
	GameState.current_room_id = "ch5_hacsa_beach"
	GameState.current_chapter_id = "ch5_hacsa_beach"
	GameState.opening_flags.jiamin_phone_found = true
	GameState.opening_items["jiamin_phone"] = 1
	scene = load("res://levels/ch5_hacsa_beach/beach_scene.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await frames(10)
	check(scene.hud.panel_open and is_instance_valid(scene.tide) and is_instance_valid(scene.ghost), "tide_and_ghost_in_real_scene")
	scene._close_panel()
	scene.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var focus_tide: float = scene.tide.clock
	var focus_ghost: Vector2 = scene.ghost.position
	await frames(20)
	check(get_tree().paused and scene.hud.panel_open and scene.tide.clock == focus_tide and scene.ghost.position == focus_ghost, "focus_loss_pauses_tide_and_ghost")
	scene._close_panel()
	check(not get_tree().paused and scene.player.controls_enabled, "focus_resume_restores_beach_control")
	scene.interact_target("trace_a")
	check(GameState.opening_flags.beach_sole_seen and GameState.has_demo_item("shoe_repair_photo"), "field comparison registers the displayed reference before opening the journal")
	scene._close_panel()
	var phone_event := InputEventAction.new()
	phone_event.action = "phone"
	phone_event.pressed = true
	Input.parse_input_event(phone_event)
	await frames(2)
	var before_phone_tide: float = scene.tide.clock
	var before_phone_ghost: Vector2 = scene.ghost.position
	await frames(20)
	check(scene.hud.panel_open and scene.hud.default_phone_widget != null and scene.tide.clock == before_phone_tide and scene.ghost.position == before_phone_ghost, "phone_pauses_tide_and_ghost")
	phone_event = InputEventAction.new()
	phone_event.action = "phone"
	phone_event.pressed = true
	Input.parse_input_event(phone_event)
	await frames()
	check(not scene.hud.panel_open and not get_tree().paused and scene.player.controls_enabled, "phone_returns_to_beach_without_world_action")
	var map_event := InputEventAction.new()
	map_event.action = "map"
	map_event.pressed = true
	var journal_event := InputEventAction.new()
	journal_event.action = "journal"
	journal_event.pressed = true
	var bag_event := InputEventAction.new()
	bag_event.action = "inventory"
	bag_event.pressed = true
	# Every shortcut uses the shared handset pages and the live room objective.
	Input.parse_input_event(map_event)
	await frames()
	check(scene.hud.archive_page == "map" and scene.hud.default_phone_widget.current_objective == scene.hud.objective.text and get_tree().paused, "M opens the handset map with the current objective")
	Input.parse_input_event(journal_event)
	await frames()
	check(scene.hud.archive_page == "journal" and scene.hud.default_phone_widget.get_script() == preload("res://ui/beach_footprints.gd") and GameState.has_demo_item("shoe_repair_photo"), "J switches to the current chapter's footprint journal and reads the offline shoe photo")
	Input.parse_input_event(bag_event)
	await frames()
	check(scene.hud.archive_page == "inventory" and not scene.hud.default_phone_widget.journal_mode and get_tree().paused, "B switches to the bag without resuming the tide")
	Input.parse_input_event(bag_event.duplicate())
	await frames()
	check(not get_tree().paused and scene.player.controls_enabled, "pressing B again restores the world")
	scene.player.controls_enabled = false
	phone_event = InputEventAction.new()
	phone_event.action = "phone"
	phone_event.pressed = true
	Input.parse_input_event(phone_event)
	Input.parse_input_event(map_event.duplicate())
	Input.parse_input_event(journal_event.duplicate())
	Input.parse_input_event(bag_event.duplicate())
	await frames()
	check(not scene.hud.panel_open and not get_tree().paused, "phone_cannot_interrupt_a_locked_world_action")
	scene.player.controls_enabled = true
	await shot("beach_overview_049")
	var tide_clock: float = scene.tide.clock
	scene._pause_menu()
	await frames(30)
	check(scene.tide.clock == tide_clock, "modal_freezes_tide")
	scene._close_panel()
	scene._open_service("key_box")
	await frames()
	var board: Control = scene.widget
	await shot("beach_keybox_closed_049")
	mouse(board, Vector2(300, 160), true)
	drag_to(board, Vector2(300, 137))
	board.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not board.grabbed and board.openness == 0.0 and board.lift == 0.0, "focus loss cancels an unfinished box drag")
	drag_to(board, Vector2(440, 137))
	check(not GameState.opening_flags.beach_key_box_open, "mouse motion after focus loss cannot finish an abandoned drag")
	mouse(board, Vector2(300, 160), true)
	drag_to(board, Vector2(440, 160))
	mouse(board, Vector2(440, 160), false)
	await get_tree().create_timer(0.3, true).timeout
	check(not GameState.opening_flags.beach_key_box_open and board.openness < 0.01, "side_pull_without_lift_springs_back")
	mouse(board, Vector2(300, 160), true)
	drag_to(board, Vector2(320, 137))
	mouse(board, Vector2(320, 137), false)
	mouse(board, Vector2(300, 160), true)
	drag_to(board, Vector2(440, 160))
	check(not GameState.opening_flags.beach_key_box_open, "regrabbing a returning lid still requires lifting its catch")
	mouse(board, Vector2(440, 160), false)
	mouse(board, Vector2(300, 160), true)
	drag_to(board, Vector2(300, 137))
	drag_to(board, Vector2(440, 137))
	check(GameState.opening_flags.beach_key_box_open, "lift_then_pull_opens_real_lid")
	await shot("beach_keybox_open_049")
	mouse(board, Vector2(255, 171), true)
	mouse(board, Vector2(255, 171), false)
	check(GameState.has_demo_item("beach_cabinet_key") and not board.key_sprite.visible, "click_actual_key_collects_it_once")
	scene._close_panel()
	scene._open_service("car")
	await frames()
	board = scene.widget
	var original_knob: float = board.pointer.rotation
	mouse(board, Vector2(223, 166), true)
	drag_to(board, Vector2(323, 108))
	board.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not board.grabbed and is_equal_approx(board.pointer.rotation, original_knob) and not GameState.opening_flags.beach_headlights_on, "focus loss restores the uncommitted light setting")
	mouse(board, Vector2(323, 108), false)
	check(not GameState.opening_flags.beach_headlights_on, "late mouse release cannot commit the interrupted light setting")
	mouse(board, Vector2(223, 166), true)
	drag_to(board, Vector2(323, 108))
	mouse(board, Vector2(323, 108), false)
	await get_tree().create_timer(0.8, true).timeout
	check(GameState.opening_flags.beach_headlights_on and scene.car_lights[0].energy > 0.57, "knob_turns_actual_high_beams_on")
	check(scene.in_headlight(Vector2(800, 430)) and not scene.in_headlight(Vector2(180, 480)), "light_boundary_matches_angle_and_distance")
	mouse(board, Vector2(223, 166), true)
	drag_to(board, Vector2(123, 108))
	mouse(board, Vector2(123, 108), false)
	mouse(board, Vector2(223, 166), true)
	drag_to(board, Vector2(323, 108))
	await frames(15)
	mouse(board, Vector2(323, 108), false)
	await get_tree().create_timer(0.8, true).timeout
	check(GameState.opening_flags.beach_headlights_on, "a previous knob settling animation cannot overwrite a new drag")
	await shot("beach_light_switch_049")
	scene._close_panel()
	scene._inspect_cabinet()
	await get_tree().create_timer(0.8, true).timeout
	await frames()
	check(GameState.opening_flags.beach_cabinet_open and scene.cabinet_plan.visible and not scene.hud.panel_open, "opening the cabinet reveals the folded plan in the room")
	scene._inspect_cabinet()
	await frames()
	check(GameState.has_demo_item("hotel_maintenance_plan") and not scene.cabinet_plan.visible, "taking the plan removes the paper from the cabinet and opens it")
	board = scene.widget
	await shot("coastal_plan_049")
	mouse(board, board.ROUTE[0], true)
	drag_to(board, board.ROUTE[1])
	board.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not board.grabbed and board.trace_progress == 0 and board.trace.points.is_empty(), "focus loss clears an unfinished map trace")
	mouse(board, board.ROUTE[0], true)
	for point in board.ROUTE.slice(1): drag_to(board, point)
	mouse(board, board.ROUTE[-1], false)
	check(GameState.opening_flags.beach_circuit_matched, "plan_tracing_follows_painted_corridor")
	scene._close_panel()
	check(scene.shaft_mark.visible and scene.service_action_active and not scene.player.controls_enabled, "returning from the traced plan shows the matching shaft mark")
	await shot("beach_shaft_mark_repair")
	await get_tree().create_timer(1.2, true).timeout
	check(not scene.service_action_active and scene.player.controls_enabled, "entrance preview restores the original camera and control")
	scene._open_footprints()
	await frames()
	board = scene.widget
	board.matching = "A"
	board.earlier = "A"
	board.submit()
	check(not GameState.opening_flags.beach_footprints_solved, "unknown_world_evidence_cannot_be_skipped")
	scene._close_panel()
	for id in ["trace_a", "wrack", "trace_b"]:
		scene.interact_target(id)
		await frames()
		scene._close_panel()
	scene._open_footprints()
	await frames()
	board = scene.widget
	board.detail_buttons[2].pressed.emit()
	await get_tree().create_timer(0.23, true).timeout
	check(board.zoom > 2.7 and board.source_image.position.y < -125 and board.field_image.position.y < -125, "heel comparison magnifies the same region of both photographs")
	check(board.detail_buttons[0].get_rect().end.y < board.choice_buttons[0].position.y, "magnifying controls stay above both answer rows")
	await shot("beach_heel_repair")
	board.detail_buttons[0].pressed.emit()
	await get_tree().create_timer(0.23, true).timeout
	board.matching = "B"
	board.earlier = "B"
	board.submit()
	check(not GameState.opening_flags.beach_footprints_solved, "fresh_different_shoe_is_not_jiamin")
	board.matching = "A"
	board.earlier = "A"
	board.submit()
	check(GameState.opening_flags.beach_footprints_solved, "identity_and_overlap_time_both_required")
	await shot("beach_footprint_evidence_049")
	scene._close_panel()
	scene.player.position = Vector2(760, 400)
	await frames(12)
	await shot("beach_headlight_boundary_049")
	scene._ghost_caught()
	await get_tree().create_timer(0.6, true).timeout
	var lunge = scene.find_children("*", "CanvasLayer", false, false).back().get_child(0)
	check(lunge.blackout.size.is_equal_approx(lunge.get_viewport_rect().size), "capture_blackout_covers_viewport")
	await shot("beach_ghost_reach_049")
	await get_tree().create_timer(0.36, true).timeout
	check(lunge.blackout.modulate.a >= 0.99, "capture_reaches_full_black_before_recovery")
	await get_tree().create_timer(0.44, true).timeout
	check(scene.hud.panel_open and scene.player.position.y < 240, "animated_attack_returns_to_safe_ground_with_evidence")
	scene._close_panel()
	scene.queue_free()
	await frames(8)
	OS.delay_msec(100)
	await frames(3)
	print("BEACH V5 %d checks failed=%s" % [checks, failed])
	get_tree().quit(1 if failed else 0)
