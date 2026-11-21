extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS " if condition else "FAIL ") + description)

func frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame

func tap(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await frames(3)
	event = InputEventAction.new()
	event.action = action
	Input.parse_input_event(event)
	await frames(3)

func run() -> void:
	check(GameState.profile == "test", "isolated test profile")
	if "--other-opening-batteries" in OS.get_cmdline_user_args():
		await inspect_other_opening_batteries()
		finish()
		return
	var reading := "--read-battery-save" in OS.get_cmdline_user_args()
	if reading:
		GameState.prepare_opening_resume()
	else:
		GameState.reset_opening()
		GameState.opening_resume_checked = true
		GameState.current_room_id = "ch0_maintenance"
		GameState.pending_entry_id = "from_room304"
		for flag in ["photo_taken", "pastry_shared", "knock_agreed", "entered_foyer", "meter_cover_open", "floor3_power", "jiamin_phone_found", "old_photo_seen", "room_bed_moved", "room_cover_open"]:
			GameState.opening_flags[flag] = true
		GameState.opening_switches.B = true
		GameState.take_demo_item("jiamin_phone")
		var photo := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		photo.fill(Color("746554"))
		GameState.opening_photo = ImageTexture.create_from_image(photo)
	var scene := preload("res://levels/ch0_tanglau/maintenance_012.tscn").instantiate()
	scene.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(scene)
	await frames(5)
	if reading:
		check(GameState.current_room_id == "ch0_maintenance", "saved room resumes through the registry")
		check(GameState.opening_flags.maintenance_spare_battery_taken and is_instance_valid(scene.player) and not is_instance_valid(scene.spare_battery), "collected spare does not respawn")
		check(is_equal_approx(GameState.flashlight_battery, 50.0) or absf(GameState.flashlight_battery - 50.0) < 0.1, "charge persists independently of the scene instance")
		finish()
		return
	var actor: PlayerController = scene.player
	actor.aim_override = true
	actor.flashlight_on = false
	for _frame in range(55):
		var distance := 155.0 - actor.position.x
		if distance < 2.0:
			break
		Input.action_press("move_right")
		await get_tree().physics_frame
	Input.action_release("move_right")
	actor.clear_motion()
	actor.look_dir = Vector2.UP
	await frames(4)
	check(scene.selected_id == "spare_battery", "walking from the entry reaches the visible battery and E prompt")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var screenshot := get_viewport().get_texture().get_image()
		check(screenshot.save_png("res://docs/build_reports/maintenance_spare_battery.png") == OK, "maintenance battery rendered in the live scene")
	Input.action_press("move_up")
	await frames(25)
	Input.action_release("move_up")
	actor.clear_motion()
	check(actor.position.y > scene.spare_battery.position.y + 3.0, "the battery footprint blocks crossing the physical object")
	GameState.flashlight_battery = 100.0
	await tap("interact")
	check(is_instance_valid(scene.spare_battery) and GameState.flashlight_battery == 100.0, "a full flashlight leaves the spare unspent")
	GameState.flashlight_battery = 0.0
	await tap("flashlight")
	check(not actor.flashlight_on and actor.get_node("NearLight").enabled and "没电" in scene.hud.defense_notice.text, "empty flashlight reports depletion and retains close-range light")
	await tap("interact")
	check(not is_instance_valid(scene.spare_battery) and GameState.flashlight_battery == 50.0, "actual E input replaces the empty battery once for 50")
	var checkpoint := OpeningCheckpoint.load_state(GameState.get_profile_path(), GameState.opening_scope())
	check(checkpoint.ok and checkpoint.data.flags.maintenance_spare_battery_taken and checkpoint.data.resources.flashlight_battery == 50.0, "the pickup and new charge are written together")
	await tap("flashlight")
	check(actor.lamp.enabled and actor.flashlight_on, "F restores the flashlight beam after changing the battery")
	finish()

func inspect_other_opening_batteries() -> void:
	for evidence in [
		["ch1_crypt_entry", "from_lane", "res://levels/ch1_stpaul/crypt_entry_013.tscn", Vector2(215, 201)],
		["ch2_bunker_hall", "from_descent", "res://levels/ch2_guia/bunker_hall_015.tscn", Vector2(252, 237)]
	]:
		GameState.reset_opening()
		GameState.opening_resume_checked = true
		GameState.current_room_id = evidence[0]
		GameState.current_chapter_id = OpeningCheckpoint.chapter_for_room(evidence[0])
		GameState.pending_entry_id = evidence[1]
		var scene: Node = load(evidence[2]).instantiate()
		scene.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(scene)
		await frames(4)
		var actor: PlayerController = scene.player
		actor.aim_override = true
		actor.position = evidence[3]
		actor.look_dir = actor.position.direction_to(scene.spare_battery.position)
		actor.reset_physics_interpolation()
		await frames(4)
		check(scene.selected_id == "spare_battery", "visible battery is selectable from a clear lane in " + evidence[0])
		check(scene.spare_battery.collision_layer == (actor.collision_mask & 1), "battery footprint belongs to the player world collision layer")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var screenshot := get_viewport().get_texture().get_image()
			check(screenshot.save_png("res://docs/build_reports/" + evidence[0] + "_spare_battery.png") == OK, "the reserve renders in " + evidence[0])
		scene.queue_free()
		await frames(4)

func finish() -> void:
	print("SPARE BATTERY %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
