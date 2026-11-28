extends Node
# Read-only gameplay fixture: exercises actual inputs and button signals.
var checks := 0
var failures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print(("PASS " if value else "FAIL ") + label)

func frames(count := 4) -> void:
	for _i in range(count): await get_tree().process_frame

func tap(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventAction.new()
	event.action = action
	Input.parse_input_event(event)
	await frames(2)

func click(button: Button) -> void:
	var at := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	get_viewport().push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_viewport().push_input(event, true)
	await frames(2)
	event = InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	get_viewport().push_input(event, true)
	await frames(2)
func run() -> void:
	check(GameState.profile == "test", "isolated modal audit profile")
	GameState.reset_opening()
	GameState.opening_resume_checked = true
	GameState.current_room_id = "ch5_coastal_pressure_gallery"
	GameState.current_chapter_id = "ch5_hacsa_beach"
	GameState.pending_entry_id = "from_silt_tunnel"
	GameState.opening_flags.coastal_silt_route_verified = true
	var scene := preload("res://levels/ch5_hacsa_beach/coastal_pressure_gallery_060.tscn").instantiate()
	# The harness must keep receiving input while paused; the real level must
	# retain its normal pausable behavior rather than inherit this harness mode.
	scene.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(scene)
	await frames(8)
	for _i in range(3):
		if scene.hud.panel_open: await tap("pause")
	check(not scene.hud.panel_open and not get_tree().paused, "pressure-gallery introduction closes normally")
	scene.hud.hint_idle = scene.hud.OFFER_HINT_AFTER
	await frames(2)
	check(scene.hud.investigation_hint.visible and scene.hud.investigation_hint.text == "[ H ] 查看调查提示", "idle offer reveals only the hint key")
	await tap("investigation_hint")
	check("持续给管线加压" in scene.hud.investigation_hint.text and not get_tree().paused, "first voluntary hint states the investigation goal")
	await tap("investigation_hint")
	check("墙图" in scene.hud.investigation_hint.text and "最后转动" not in scene.hud.investigation_hint.text, "second hint points to evidence without giving the valve order")
	if "--capture-hint" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var screenshot := get_viewport().get_texture().get_image()
		check(screenshot.save_png("res://docs/build_reports/pressure_investigation_hint.png") == OK, "the hint renders over the real pressure gallery")
	await tap("pause")
	var remaining_hint: float = scene.hud.hint_duration
	await tap("investigation_hint")
	check(not scene.hud.investigation_hint.visible and scene.hud.hint_index == 2 and scene.hud.hint_duration == remaining_hint, "pause hides hints and freezes their progression")
	await tap("pause")
	await tap("investigation_hint")
	check("先关闭来水轮" in scene.hud.investigation_hint.text, "third voluntary hint names the next steps")
	GameState.opening_flags.coastal_pressure_diagram_seen = true
	await frames(4)
	check(scene.hud.hint_index == 0 and not scene.hud.investigation_hint.visible, "recording evidence resets the hint sequence")
	GameState.opening_flags.coastal_pressure_diagram_seen = false
	await frames(4)
	var before: Vector2 = scene.player.position
	await tap("inventory")
	check(scene.hud.panel_open and get_tree().paused and is_instance_valid(scene.widget) and scene.widget.is_inside_tree(), "B in pressure gallery opens the actual inventory modal")
	if scene.hud.panel_open:
		var old_widget: Control = scene.widget
		Input.action_press("move_right")
		await frames(8)
		Input.action_release("move_right")
		check(scene.player.position == before, "inventory modal freezes pressure-gallery movement")
		await tap("pause")
		check(not scene.hud.panel_open and not get_tree().paused and scene.player.controls_enabled, "Esc closes inventory and restores world controls")
		check(not is_instance_valid(old_widget) and not is_instance_valid(scene.widget), "closed inventory is freed and its persistent reference cleared")
		await tap("inventory")
		check(scene.hud.panel_open and get_tree().paused and is_instance_valid(scene.widget) and scene.widget.is_inside_tree(), "inventory can be opened again after closing")
		await tap("inventory")
		check(not scene.hud.panel_open and not get_tree().paused and not is_instance_valid(scene.widget), "B closes the active inventory without immediately reopening it")
		# Set an explicit safe observation position, then close ordinary dialogue
		# with E; that same key event must not inspect the nearby world hotspot.
		scene.player.position = Vector2(394, 370)
		scene.player.look_dir = Vector2.UP
		scene.player.aim_override = true
		await frames(4)
		check(scene.selected_id == "schematic", "dialogue-close fixture is in range of a real world hotspot")
		scene._say("回归夹具", "关闭这句话后，不应同时调查墙图。")
		await frames(4)
		check(scene.hud.modal.size.y <= 176.0 and scene.hud.modal.get_global_rect().encloses(scene.hud.panel_body.get_global_rect()), "short dialogue shrinks after closing the full-height inventory")
		await tap("interact")
		check(not scene.hud.panel_open and not GameState.opening_flags.coastal_pressure_diagram_seen, "E closing dialogue does not pass through to the world hotspot")
		await verify_valve_action(scene)
	if is_instance_valid(scene.widget) and not scene.widget.is_inside_tree():
		scene.widget.free()
		scene.widget = null
	get_tree().paused = false
	scene.queue_free()
	await frames(6)
	var hud := preload("res://ui/quiet_hud.gd").new()
	add_child(hud)
	var phone := preload("res://ui/demo_phone.gd").new()
	hud.open_widget(phone)
	get_tree().paused = true
	await frames(4)
	var shoe: Button
	for child in phone.get_children():
		if child is Button and child.text == "原有照片 · 鞋底维修": shoe = child
	check(is_instance_valid(shoe), "phone has an actual shoe-photo button")
	await click(shoe)
	await frames(3)
	var count_before := 0
	for child in phone.get_children():
		if child is PanelContainer: count_before += 1
	check(count_before == 1, "first photo button opens one photo layer")
	await click(shoe)
	await frames(3)
	var count_after := 0
	for child in phone.get_children():
		if child is PanelContainer: count_after += 1
	check(count_after == 1, "repeated photo button does not stack duplicate photo layers")
	for child in phone.get_children():
		if child is PanelContainer:
			var column := child.get_child(0)
			for node in column.get_children():
				if node is Button:
					await click(node)
					break
			break
	await frames(3)
	var remaining := 0
	for child in phone.get_children():
		if child is PanelContainer: remaining += 1
	check(remaining == 0, "one return closes the photo without exposing a duplicate layer")
	check(get_tree().paused and hud.panel_open and not is_instance_valid(phone.photo_cover), "photo return leaves the parent phone modal paused and clears its cover reference")
	await click(shoe)
	check(is_instance_valid(phone.photo_cover) and phone.photo_cover.is_inside_tree(), "photo can be reopened after one return")
	phone._close_shoe_photo()
	phone._close_shoe_photo()
	await frames(3)
	check(not is_instance_valid(phone.photo_cover), "repeated close requests safely release the photo once")
	get_tree().paused = false
	print("MODAL_REGRESSION_088 checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func verify_valve_action(scene: Node) -> void:
	for flag in ["coastal_pressure_diagram_seen", "coastal_pressure_gauge_seen", "coastal_pressure_drain_seen"]:
		GameState.opening_flags[flag] = true
	scene.player.position = Vector2(315, 370)
	scene.player.look_dir = Vector2.UP
	scene.player.clear_motion()
	await frames(4)
	check(scene.selected_id == "inlet", "valve-action fixture selects the actual inlet wheel")
	await tap("interact")
	check(scene.hud.panel_open and get_tree().paused and is_instance_valid(scene.widget), "inlet interaction opens the pressure console")
	var inlet_btn: Button = scene.widget.captions[0]
	inlet_btn.emit_signal("pressed")
	await frames(3)
	check(not scene.player.controls_enabled and scene.scene_action_active, "wheel animation starts with world controls locked")
	for _i in range(3): inlet_btn.emit_signal("pressed")
	await tap("inventory")
	check(not scene.player.controls_enabled and scene.scene_action_active, "B cannot unlock world controls during the wheel animation")
	scene.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var focus_wheel: Node2D = scene.valve_handles["inlet"]
	var focus_rotation: float = focus_wheel.rotation
	await frames(18)
	check(get_tree().paused and scene.hud.panel_open and is_equal_approx(focus_wheel.rotation, focus_rotation), "focus loss freezes an in-progress wheel animation")
	scene._close_panel()
	check(not get_tree().paused and not scene.player.controls_enabled and scene.scene_action_active, "focus resume keeps the wheel action locked")
	await tap("pause")
	check(scene.hud.panel_open and get_tree().paused, "Esc can pause an in-progress wheel animation")
	var wheel: Node2D = scene.valve_handles["inlet"]
	var rotation_before := wheel.rotation
	await frames(18)
	check(is_equal_approx(wheel.rotation, rotation_before), "pause freezes the wheel rotation")
	await tap("pause")
	check(not scene.hud.panel_open and not get_tree().paused and not scene.player.controls_enabled, "resuming a wheel animation keeps world movement locked until it completes")
	await frames(60)
	check(GameState.opening_flags.coastal_pressure_inlet_closed and is_equal_approx(wheel.rotation, PI * 0.5), "repeated input produces only one quarter-turn and one completed valve state")
	check(not scene.scene_action_active and scene.player.controls_enabled, "completed wheel restores world controls cleanly after animation")
