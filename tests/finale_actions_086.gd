extends Node

var scene: Node
var checks := 0
var failures := 0
var contacts := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")


func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1


func frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame

func tap_pipe() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)


func run() -> void:
	var fixture := preload("res://tests/ch6_rescue_061.gd").new()
	fixture._prepare_state()
	fixture.free()
	AudioManager.world_effect_requested.connect(func(id: String):
		if id == "metal_cover": contacts += 1)
	scene = preload("res://levels/ch6_abandoned_vip/abandoned_vip_rescue_061.tscn").instantiate()
	add_child(scene)
	await frames(3)
	scene._close_panel()
	scene.player.aim_override = true
	scene.player.position = Vector2(250, 248)
	GameState.opening_flags.ch6_jiamin_pipe_found = true
	var original_scale: Vector2 = scene.player.sprite.scale
	scene._send_jiamin_signal()
	await frames(18)
	check(scene.scene_action_active and is_instance_valid(scene.pipe_action), "dedicated held-pipe action is active")
	check(not scene.player.sprite.visible and not scene.player.controls_enabled, "walking sprite and controls are replaced during the held action")
	check(scene.player.sprite.scale.is_equal_approx(original_scale), "dedicated action does not deform Jiamin's normal sprite")
	check(scene.pipe_action.figure.texture is AtlasTexture and scene.pipe_action.figure.texture.atlas.resource_path.ends_with("jiamin_pipe_strike_086.png"), "action uses six new painted poses with the tube integrated in the hands")
	check(scene.player.position.is_equal_approx(Vector2(224, 312)), "Jiamin approaches the visible pipe joint in the clear service lane")
	check(contacts == 0, "holding the pipe does not strike until Space is pressed")
	await tap_pipe()
	var frame_before: int = scene.pipe_action.displayed_frame
	var contacts_before := contacts
	scene._pause_menu()
	await frames(55)
	check(scene.scene_action_active and scene.pipe_action.displayed_frame == frame_before and contacts == contacts_before, "pause freezes action poses and the contact sound cues")
	check(not GameState.opening_flags.ch6_signal_sent, "paused performance does not complete the role handoff")
	scene._close_panel()
	check(not scene.player.controls_enabled, "resuming an unfinished strike keeps world movement locked")
	await frames(18)
	for _strike in range(2):
		await tap_pipe()
		await frames(18)
	check(contacts == 3, "exactly three contact frames request metallic knocks")
	check(GameState.opening_flags.ch6_signal_sent and GameState.current_role == "dawen", "the role handoff waits for all three physical knocks")
	check(not is_instance_valid(scene.pipe_action) and scene.player.sprite.visible and scene.player.appearance == "flashlight", "handoff removes action art and restores Daven's correct sprite")
	check(scene.player.sprite.scale.is_equal_approx(Vector2.ONE * scene.player.sprite_scale), "Daven returns at his own metadata scale after the role swap")
	var previous_contacts := contacts
	scene._send_jiamin_signal()
	await frames(3)
	check(contacts == previous_contacts, "completed Jiamin signal cannot be replayed as Daven")
	scene._close_panel()
	GameState.opening_flags.ch6_route_diagram_seen = true
	GameState.opening_flags.ch6_pipe_route_verified = true
	GameState.opening_flags.ch6_live_signal_received = true
	GameState.opening_flags.ch6_circuit_isolated = true
	GameState.opening_flags.ch6_entity_lured = true
	GameState.opening_flags.ch6_entity_bound = true
	scene.player.position = Vector2(1112, 335)
	scene.player.controls_enabled = true
	Input.action_press("move_right")
	await frames(35)
	Input.action_release("move_right")
	scene.player.clear_motion()
	check(scene.player.position.x < 1141.0, "closed hatch blocks a real movement attempt")
	scene.player.position = Vector2(1112, 490)
	Input.action_press("move_right")
	await frames(35)
	Input.action_release("move_right")
	scene.player.clear_motion()
	check(scene.player.position.x < scene.rescue_hatch.LEAF_RECT.position.x, "the lower visible door leaf also blocks passage instead of leaving a gap below its old collision")
	scene.player.position = Vector2(1112, 335)
	scene._open_rescue_door()
	await frames(20)
	check(scene.scene_action_active and scene.rescue_hatch.progress > 0.0 and scene.rescue_hatch.progress < 1.0, "rusted door leaf swings before rescue begins")
	check(is_instance_valid(scene.locked_door_body) and is_instance_valid(scene.locked_door_occluder), "moving leaf retains physical and light blocking until the opening completes")
	var collision := scene.locked_door_body.get_child(0) as CollisionShape2D
	var width_before: float = collision.shape.size.x
	check(width_before < scene.rescue_hatch.BLOCKING_RECT.size.x and width_before > 2.0, "leaf collision narrows with the hinge projection")
	var polygon_width: float = scene.locked_door_occluder.occluder.polygon[1].x - scene.locked_door_occluder.occluder.polygon[0].x
	check(is_equal_approx(polygon_width, width_before), "moving door light occlusion uses the same projected width")
	var progress_before: float = scene.rescue_hatch.progress
	scene._pause_menu()
	await frames(55)
	check(is_equal_approx(scene.rescue_hatch.progress, progress_before) and is_equal_approx(collision.shape.size.x, width_before), "pause freezes door art, collision and occlusion together")
	scene._close_panel()
	check(not scene.player.controls_enabled, "world controls stay locked while the hatch continues opening")
	await frames(55)
	check(scene.scene_action_active and is_instance_valid(scene.rescued_jiamin) and not is_instance_valid(scene.rescue_support), "both characters approach before the support action")
	check(scene.rescued_jiamin.sprite.animation == "4" and scene.rescued_jiamin.look_dir.x < 0.0, "Jiamin faces her actual leftward path from the hatch")
	check(scene.player.sprite.animation == "2" and scene.player.look_dir.y > 0.0 and scene.player.pivot.rotation > 0.0, "Daven faces his downward approach with the held light aligned")
	var walk_frame: int = scene.player.sprite.frame
	var walk_position: Vector2 = scene.player.position
	await frames(8)
	check(scene.player.position.distance_to(walk_position) > 1.0 and scene.player.sprite.frame != walk_frame, "Daven's approach advances both position and walking frames")
	var paused_approach_position: Vector2 = scene.player.position
	var paused_approach_frame: int = scene.player.sprite.frame
	scene._pause_menu()
	await frames(40)
	check(scene.player.position.is_equal_approx(paused_approach_position) and scene.player.sprite.frame == paused_approach_frame and not GameState.opening_flags.ch6_jiamin_rescued, "pause freezes walking poses without committing rescue")
	scene._close_panel()
	check(not scene.player.controls_enabled, "approach resumes with movement input locked")
	await frames(49)
	check(scene.scene_action_active and is_instance_valid(scene.rescue_support), "the physical support scene starts after the hatch opens")
	check(not scene.player.sprite.visible and not scene.rescued_jiamin.sprite.visible and not scene.player.lamp.enabled, "painted pair replaces both walking sprites and the unheld flashlight")
	check(not GameState.opening_flags.ch6_jiamin_rescued, "an interrupted support scene has not committed rescue early")
	var support_frame: int = scene.rescue_support.displayed_frame
	scene._pause_menu()
	await frames(50)
	check(scene.rescue_support.displayed_frame == support_frame and not GameState.opening_flags.ch6_jiamin_rescued, "pause freezes support and does not commit the rescue")
	scene._close_panel()
	check(not scene.player.controls_enabled, "support keeps movement locked after resuming")
	var handoff_started := false
	for _i in range(240):
		if is_instance_valid(scene.rescue_support) and scene.rescue_support.get_script().resource_path.ends_with("rescue_camera_handoff_108.gd") and scene.rescue_support.displayed_frame >= 1:
			handoff_started = true
			break
		await get_tree().process_frame
	check(handoff_started and not GameState.opening_flags.ch6_ahhao_camera_handed, "camera handoff begins only after the support action")
	var handoff_frame: int = scene.rescue_support.displayed_frame if handoff_started else -1
	if handoff_started:
		scene._pause_menu()
		await frames(50)
		check(scene.rescue_support.displayed_frame == handoff_frame and not GameState.opening_flags.ch6_ahhao_camera_handed, "pause freezes the camera transfer before saving ownership")
		var handoff_checkpoint := OpeningCheckpoint.load_state(GameState.get_profile_path(), GameState.opening_scope())
		check(handoff_checkpoint.ok and handoff_checkpoint.data.flags.ch6_jiamin_rescued and not handoff_checkpoint.data.flags.ch6_ahhao_camera_handed, "interrupted transfer can resume from the rescued-before-handoff checkpoint")
		scene._close_panel()
		check(not scene.player.controls_enabled, "camera handoff resumes with player movement locked")
	for _i in range(260):
		if not scene.scene_action_active and scene.hud.panel_open: break
		await get_tree().process_frame
	check(GameState.opening_flags.ch6_rescue_door_open and GameState.opening_flags.ch6_jiamin_rescued, "completed door animation leads into physical rescue")
	check("嘉敏已获救" in scene.hud.objective.text, "rescue immediately updates the objective instead of asking to open the door again")
	check(is_equal_approx(scene.rescue_hatch.progress, 1.0) and not scene.rescue_hatch.leaf.visible, "the painted closed leaf is absent from the opened passage")
	check(not is_instance_valid(scene.locked_door_body) and not is_instance_valid(scene.locked_door_occluder), "opened hatch removes both old collision and its occluder")
	check(scene.rescued_jiamin.position.is_equal_approx(Vector2(1080, 535)) and scene.player.position.is_equal_approx(Vector2(1115, 535)) and scene.player.sprite.visible and scene.rescued_jiamin.sprite.visible, "both actors return to the composed camera-handoff positions after Jiamin emerges")
	check(GameState.opening_flags.ch6_ahhao_camera_handed and scene.hud.panel_open, "Ah Hao's camera handoff completes and is saved before the reunion dialogue")
	var handed_checkpoint := OpeningCheckpoint.load_state(GameState.get_profile_path(), GameState.opening_scope())
	check(handed_checkpoint.ok and handed_checkpoint.data.flags.ch6_ahhao_camera_handed, "completed handoff ownership survives disk decode")
	check(scene.hud.panel_body.text == "阿豪呢？", "Jiamin asks about Ah Hao after receiving his camera")
	scene._close_panel()
	await frames(52)
	check(scene.hud.panel_open and "楼梯口" in scene.hud.panel_body.text, "Daven responds after a pause")
	scene._close_panel()
	scene.player.position = Vector2(1112, 335)
	scene.player.look_dir = Vector2.RIGHT
	await frames(2)
	check(scene.selected_id == "rescue_door" and "决定如何撤离" in scene.hud.prompt.text, "open rescue door offers the departure action")
	scene.player.position = Vector2(1020, 535)
	scene.player.controls_enabled = true
	Input.action_press("move_right")
	await frames(60)
	Input.action_release("move_right")
	scene.player.clear_motion()
	check(scene.player.position.x > 1030.0 and scene.player.position.x < 1115.0, "rescued Jiamin retains physical foot collision instead of letting the player walk through her")
	scene.player.position = Vector2(1112, 335)
	scene.player.controls_enabled = true
	Input.action_press("move_right")
	await frames(65)
	Input.action_release("move_right")
	scene.player.clear_motion()
	check(scene.player.position.x > 1190.0 and scene.player.position.x < 1262.0, "opened door permits actual passage while the room boundary stays solid")
	scene.rescued_jiamin.position = Vector2(1080, 535)
	scene.player.position = Vector2(1115, 535)
	scene._play_assisted_departure()
	await frames(30)
	var departure_action: Node
	for child in scene.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("rescue_departure_108.gd"):
			departure_action = child
			break
	check(is_instance_valid(departure_action) and scene.scene_action_active and not scene.player.sprite.visible and not scene.rescued_jiamin.sprite.visible, "assisted departure replaces both actors with the coordinated walking poses")
	var departure_position: Vector2 = scene.rescued_jiamin.position
	var departure_frame: int = departure_action.displayed_frame if is_instance_valid(departure_action) else -1
	scene._pause_menu()
	await frames(50)
	check(scene.rescued_jiamin.position.is_equal_approx(departure_position) and (not is_instance_valid(departure_action) or departure_action.displayed_frame == departure_frame), "pause freezes the assisted departure position and animation frame")
	scene._close_panel()
	check(not scene.player.controls_enabled, "resuming departure keeps world movement locked")
	for _i in range(260):
		if not scene.scene_action_active: break
		await get_tree().process_frame
	check(not scene.scene_action_active and scene.rescued_jiamin.position.is_equal_approx(Vector2(640, 664)) and scene.player.position.is_equal_approx(Vector2(675, 664)), "both characters reach the open exit arch together")
	check(scene.player.lamp.enabled, "Daven's flashlight restores after the assisted departure")
	scene.queue_free()
	await frames(3)
	GameState.opening_flags.ch6_reunion_seen = true
	scene = preload("res://levels/ch6_abandoned_vip/abandoned_vip_rescue_061.tscn").instantiate()
	add_child(scene)
	await frames(4)
	check(is_equal_approx(scene.rescue_hatch.progress, 1.0) and not scene.rescue_hatch.leaf.visible, "room re-entry restores the open leaf appearance")
	check(not is_instance_valid(scene.locked_door_body) and not is_instance_valid(scene.locked_door_occluder), "room re-entry keeps the completed doorway passable")
	print("FINALE_ACTIONS_086 checks=%d failures=%d" % [checks, failures])
	get_tree().paused = false
	get_tree().quit(0 if failures == 0 else 1)
