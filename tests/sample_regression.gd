extends Node

# Known-route regression: movement/actions use input events. Aim is an explicit
# fixture because the headless display has no real system cursor.
var checks: int = 0
var failures: int = 0
var room
var player: PlayerController

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame

func action(name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	Input.parse_input_event(event)

func tap(name: String) -> void:
	action(name, true)
	await frames(2)
	action(name, false)
	await frames(2)

func walk_to(target: Vector2) -> void:
	var count: int = 0
	while player.position.distance_to(target) > 2.0 and count < 420:
		var difference: Vector2 = target - player.position
		var name: String
		if absf(difference.x) > 2:
			name = "move_right" if difference.x > 0 else "move_left"
		else:
			name = "move_down" if difference.y > 0 else "move_up"
		action(name, true)
		await frames(1)
		action(name, false)
		count += 1
	await frames(2)
	check(player.position.distance_to(target) < 4.0, "input route reaches " + str(target))

func use_target(id: String) -> void:
	var offset: Vector2 = room.props[id].position + Vector2(0, 6) - player.position
	player.look_dir = offset.normalized()
	await frames(2)
	check(room.selected != null and room.selected.interactable_id == id, "selection and line of sight: " + id)
	await tap("interact")

func run() -> void:
	await frames(5)
	room = get_tree().current_scene
	player = room.player
	player.aim_override = true
	check(GameState.profile == "test" and GameState.get_profile_path().begins_with("user://test_runs/"), "test profile is isolated")
	await walk_to(Vector2(210, 200))
	player.clear_motion()
	var start := player.position
	action("move_right", true)
	action("move_down", true)
	await frames(6)
	check(player.position.x > start.x and player.position.y > start.y and absf(player.position.x - start.x - (player.position.y - start.y)) < 0.2, "combined perpendicular keys move diagonally")
	check(absf(player.resolve_movement().length() - 1.0) < 0.001, "diagonal direction is normalized; speed does not gain sqrt(2)")
	action("move_down", false)
	start = player.position
	await frames(18)
	check(player.position.x > start.x and absf(player.velocity.y) < 0.1, "release settles smoothly to remaining axis (velocity %s)" % player.velocity)
	action("move_right", false)
	await frames(6)
	action("move_up", true)
	action("move_down", true)
	check(player.resolve_movement() == Vector2.ZERO, "opposing W/S keys cancel")
	action("move_up", false)
	action("move_down", false)
	for index in range(8):
		player.look_dir = Vector2.from_angle(index * PI / 4.0)
		await frames(2)
		check(player.sprite.animation == str(index) and player.sprite.sprite_frames.get_frame_count(str(index)) == 6, "distinct six-frame facing " + str(index))
		check(player.get_flashlight_origin().y < player.global_position.y - 23.0, "held-torch beam originates at chest height, facing " + str(index))
	# The partition must block both the player and physical interaction rays.
	check(not room.interaction_visible(Vector2(400, 120)), "partition blocks interaction line of sight")
	await walk_to(Vector2(207, 286))
	await walk_to(Vector2(264, 286))
	await use_target("desk")
	check(GameState.has_clue("old_photo") and room.hud.panel_open, "photo acquired by normal interaction")
	var battery := GameState.flashlight_battery
	var stamina := GameState.stamina
	start = player.position
	action("move_right", true)
	await tap("camera_flash")
	await frames(30)
	check(player.position == start and GameState.flashlight_battery == battery and GameState.stamina == stamina, "reading freezes movement and resources; flash action is blocked")
	action("move_right", false)
	var first_page: int = room.hud.page_index
	await tap("interact")
	check(get_tree().paused and room.hud.page_index > first_page, "E advances classic dialogue page while the world remains paused")
	while room.hud.page_index < room.hud.pages.size()-1:
		await tap("interact")
	await tap("interact")
	check(not get_tree().paused and not room.hud.panel_open, "closing E is consumed and does not reopen the photo behind the panel")
	await tap("journal")
	check(room.hud.panel_open and room.hud.pages[0].contains("已经发现的线索"), "Q/J records explain the discovered evidence")
	await tap("pause")
	check(not get_tree().paused, "Escape closes clue records and restores world")
	# Clear the desk's solid foot area before crossing the room.
	await walk_to(Vector2(264, 296))
	await walk_to(Vector2(405, 296))
	check(not GameState.has_clue("floor_marks"), "photo-only route has not inspected floor marks yet")
	await walk_to(Vector2(438, 208))
	await use_target("bed")
	check(GameState.has_clue("floor_marks"), "examining bed naturally observes its feet and drag marks; no hidden hotspot is required")
	var previous_choice: Button = null
	var choice_total := 0
	for child in room.hud.panel_content.get_children():
		if child is Button:
			check(not child.get_global_rect().intersects(room.hud.page_hint.get_global_rect()), "choice and Esc footer do not overlap: " + child.text)
			if previous_choice != null:
				check(is_equal_approx(child.position.x, previous_choice.position.x) and child.position.y >= previous_choice.position.y + previous_choice.size.y, "choices are vertically arranged without overlap")
			previous_choice = child
			choice_total += 1
	check(choice_total == 3, "all three deduction choices are available")
	room.wrong_deduction()
	check(not GameState.flags["bed_moved"], "wrong deduction does not complete puzzle")
	await tap("pause")
	await use_target("bed")
	# Click the same puzzle UI action rather than writing completion flags.
	for child in room.hud.panel_content.get_children():
		if child is Button and child.text == "床被挪过":
			child.pressed.emit()
	await frames(3)
	check(GameState.flags["bed_moved"] and room.props["vent"].active, "successful deduction moves solid bed and reveals cover")
	await walk_to(Vector2(438, 142))
	action("move_up",true)
	await frames(20)
	action("move_up",false)
	await frames(6)
	check(player.position.y>=122.5 and player.position.y<130, "closed metal cover blocks the player at its visible surface")
	await use_target("vent")
	check(room.work_in_progress and room.tool_pose.visible and not player.controls_enabled, "cover removal visibly uses the pliers action pose")
	await frames(50)
	check(GameState.flags["cover_open"], "cover opened through input route")
	await tap("pause")
	action("move_up",true)
	await frames(15)
	action("move_up",false)
	await frames(6)
	check(player.position.y<118 and player.position.y>=101.5, "opened cover releases its collision while the wall still blocks")
	await use_target("vent")
	check(GameState.clues.size() == 2, "repeated examination does not duplicate evidence")
	await tap("pause")
	await walk_to(Vector2(438, 208))
	await walk_to(Vector2(184, 208))
	await walk_to(Vector2(145, 178))
	await use_target("wardrobe")
	check(player.hidden_in_wardrobe and not player.lamp.enabled, "wardrobe hides body and flashlight")
	check(AudioManager.last_world_effect == "wardrobe_close", "entering wardrobe requests the recorded closing sound")
	await tap("interact")
	check(not player.hidden_in_wardrobe, "wardrobe exits at collision-free entry point")
	check(AudioManager.last_world_effect == "wardrobe_open", "successful wardrobe exit requests the recorded opening sound")
	for sound in ["wardrobe_open", "wardrobe_close"]:
		var stream = load("res://assets/audio/qubodup/%s.ogg" % sound)
		check(stream is AudioStream and stream.get_length() > 0.05, "recorded sound decodes with nonzero duration: " + sound)
	await walk_to(Vector2(110, 178))
	await walk_to(Vector2(110, 190))
	action("move_left", true)
	await frames(35)
	action("move_left", false)
	await frames(6)
	check(player.position.x >= 87.5 and player.position.x < 96.0, "walking into wall mailbox is stopped at its real protruding surface")
	await use_target("mailbox")
	check(room.hud.panel_open, "solid mailbox remains examinable from outside its collision")
	await tap("pause")
	await walk_to(Vector2(110, 190))
	# Wall fixture: walk into the partition and ensure collision stops movement.
	await walk_to(Vector2(320, 200))
	await walk_to(Vector2(320, 130))
	action("move_right", true)
	await frames(65)
	action("move_right", false)
	check(player.position.x < 342, "solid partition stops movement")
	player.look_dir = Vector2.LEFT
	await frames(2)
	check(player.look_dir == Vector2.LEFT, "observation remains independent from movement")
	room.set_light_mode(1)
	check(not room.ceiling.enabled and player.lamp.shadow_enabled, "outage disables ceiling; flashlight shadow rendering configured")
	var previous := player.flashlight_on
	await tap("flashlight")
	check(player.flashlight_on != previous, "F toggles actual flashlight")
	GameState.stamina = 0.0
	player.sprint_locked = true
	await tap("crouch")
	await frames(110)
	check(GameState.stamina > 20.0 and not player.sprint_locked, "crouching recovers stamina and releases exhaustion lock")
	var report := {"build": "tanglau_sample_005", "type": "known_route_scripted_regression", "checks": checks, "failures": failures, "profile_path": GameState.get_profile_path(), "limitations": "Aim fixture; no save implementation; no human or visual/audio acceptance."}
	var output := FileAccess.open("res://docs/build_reports/sample_regression.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	AudioManager.stop_all()
	get_tree().quit(0 if failures == 0 else 1)
