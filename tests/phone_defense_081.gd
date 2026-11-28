extends Node
# State/geometry fixtures; this is not a claim of natural exploration.
var checks := 0
var failures := 0
var world: Node2D
var player: PlayerController
var hud
var enemies: Array[CharacterBody2D] = []
var fired := 0

class BeachStub extends Node2D:
	var hud: Node2D
	func _init() -> void: hud = self
	func in_headlight(_point: Vector2) -> bool: return false
	func notify(_message: String) -> void: pass

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1
	print(("PASS " if value else "FAIL ") + message)

func frames(count: int) -> void:
	for _i in range(count): await get_tree().process_frame

func physics(count: int) -> void:
	for _i in range(count): await get_tree().physics_frame

func reset_flash(battery := 100.0, charges := 2) -> void:
	GameState.phone_battery = battery
	GameState.phone_flash_charges = charges
	GameState.phone_flash_cooldown = 0.0

func tap(action_name: String) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventAction.new()
	event.action = action_name
	Input.parse_input_event(event)
	await frames(2)

func run() -> void:
	check(GameState.profile == "test", "test profile is isolated")
	GameState.reset_opening()
	GameState.opening_resume_checked = true
	GameState.current_room_id = "ch1_crypt_entry"
	GameState.current_chapter_id = "ch1_stpaul_crypt"
	world = Node2D.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	player = preload("res://entities/player/player.tscn").instantiate()
	player.position = Vector2(300, 240)
	player.visual_size_multiplier = 1.65
	player.aim_override = true
	world.add_child(player)
	EventBus.camera_flash_fired.connect(func(_origin: Vector2, _direction: Vector2): fired += 1)
	await frames(4)
	if "--save-failure" in OS.get_cmdline_user_args():
		check(GameState.opening_checkpoint_enabled(), "persistent isolated checkpoint enabled")
		hud = preload("res://ui/quiet_hud.gd").new()
		world.add_child(hud)
		hud.show_resource_feedback("保存失败测试")
		hud.panel_open = true
		hud._process(5.0)
		check(hud.defense_notice_time > 0.0 and not hud.defense_notice.visible, "feedback waits while an unpaused panel covers it")
		hud.panel_open = false
		hud._process(0.01)
		check(hud.defense_notice.visible, "covered feedback appears after panel closes")
		GameState.opening_flags.jiamin_phone_found = true
		GameState.take_demo_item("jiamin_phone")
		GameState.opening_flags.photo_taken = true
		GameState.opening_photo = null
		GameState.opening_photo_file = ""
		player.phone_defense.prepare_chapter()
		await frames(3)
		check(GameState.phone_flash_charges == 2 and "保存失败" in hud.defense_notice.text, "chapter supply succeeds and save failure is reported after success feedback")
		player.position = Vector2(180, 174)
		GameState.phone_battery = 10.0
		check(GameState.recharge_preparation(), "socket still recharges after save failure")
		await frames(3)
		check(GameState.phone_battery == 100.0 and "保存失败" in hud.defense_notice.text, "recharge reports save failure")
		GameState.take_demo_item("service_grip")
		GameState.take_demo_item("service_spindle")
		check(GameState.assemble_service_handle(), "assembly remains available after save failure")
		await frames(3)
		check(GameState.has_demo_item("service_handle") and "保存失败" in hud.defense_notice.text, "assembly reports save failure")
		GameState.transition_save_failed = true
		GameState.reset_opening()
		check(not GameState.transition_save_failed, "new opening clears a stale pending save warning")
		get_tree().quit(1 if failures else 0)
		return
	check(not player.phone_defense.fire().ok and fired == 0, "R before finding the phone does not fire or consume")
	GameState.opening_flags.jiamin_phone_found = true
	GameState.take_demo_item("jiamin_phone")
	player.phone_defense.prepare_chapter()
	check(GameState.phone_flash_charges == 2 and GameState.phone_supplied_chapters.has("ch1_stpaul_crypt"), "protected arrival grants two chapter opportunities exactly once")
	player.position = Vector2(318.38, 279.25)
	player.look_dir = player.position.direction_to(Vector2(320, 300))
	check(not player.phone_defense._socket_selected(), "nearby preparation socket cannot steal an E aimed at the room exit")
	player.position = Vector2(180, 174)
	player.look_dir = Vector2.UP
	check(player.phone_defense._socket_selected(), "standing directly in front of the visible socket selects recharging")
	player.position = Vector2(300, 240)
	player.look_dir = Vector2.RIGHT
	for offset in [Vector2(85,-25), Vector2(94,-20), Vector2(100,-30)]:
		var enemy := preload("res://entities/shadow_chaser.gd").new()
		enemy.position = player.position + offset
		enemy.target = player
		enemy.speed = 0.0
		world.add_child(enemy)
		enemies.append(enemy)
	await physics(3)
	var result: Dictionary = player.phone_defense.fire()
	check(result.ok and GameState.phone_battery == 75 and GameState.phone_flash_charges == 1 and fired == 1, "one real trigger atomically spends 25 and one opportunity")
	check(enemies.all(func(enemy): return enemy.flash_receiver.is_stunned() and enemy.velocity == Vector2.ZERO), "one pulse stuns all three visible in-range targets immediately")
	check(player.phone_defense.pose.visible and not player.sprite.visible, "trigger uses the authored full-character phone pose")
	check(player.phone_defense.last_origin.distance_to(player.phone_defense.phone_origin()) < 0.01, "pulse originates at the held phone lens")
	check(not player.phone_defense.fire().ok and GameState.phone_battery == 75 and fired == 1, "cooldown rejection does not spend again or duplicate the event")
	await physics(27)
	var remaining: float = enemies[0].flash_receiver.stun_remaining
	var position_before := enemies[0].position
	var cooldown_before: float = GameState.phone_flash_cooldown
	get_tree().paused = true
	await frames(50)
	check(is_equal_approx(enemies[0].flash_receiver.stun_remaining, remaining) and enemies[0].position == position_before, "pause freezes stun and enemy movement")
	check(is_equal_approx(GameState.phone_flash_cooldown, cooldown_before), "pause freezes flash cooldown")
	check(not player.phone_defense.fire().ok and GameState.phone_battery == 75, "paused world cannot flash")
	get_tree().paused = false
	await physics(132)
	check(not enemies[0].flash_receiver.is_stunned(), "stun expires after 2.5 active-world seconds")
	for enemy in enemies: enemy.active = false
	reset_flash(24.99)
	check(not player.phone_defense.fire().ok and GameState.phone_flash_charges == 2, "less than 25 battery rejects without spending a charge")
	reset_flash(25.0)
	check(player.phone_defense.fire().ok and GameState.phone_battery == 0 and GameState.phone_flash_charges == 1, "exactly 25 battery permits a valid empty shot and reaches zero")
	reset_flash(100, 0)
	check(not player.phone_defense.fire().ok and GameState.phone_battery == 100, "zero opportunities rejects despite full battery")
	reset_flash()
	player.hidden_in_wardrobe = true
	check(not player.phone_defense.fire().ok and GameState.phone_flash_charges == 2, "hidden actor cannot flash")
	player.hidden_in_wardrobe = false
	player.controls_enabled = false
	check(not player.phone_defense.fire().ok, "cutscene and disabled world input cannot flash")
	GameState.phone_flash_cooldown = 0.75
	await physics(10)
	check(is_equal_approx(GameState.phone_flash_cooldown, 0.75), "disabled or dead actor freezes the world flash cooldown")
	player.controls_enabled = true
	await physics(6)
	check(GameState.phone_flash_cooldown < 0.75, "resuming active world input resumes flash cooldown")
	GameState.current_role = "ah_hao"
	check(not player.phone_defense.fire().ok, "A-Hao cannot use Jiamin's later recovered phone")
	GameState.current_role = "dawen"
	check(PhoneFlashReceiver.in_beam(Vector2.ZERO, Vector2.RIGHT, Vector2.from_angle(deg_to_rad(30)) * 120, 120, 60), "exact range 120 and half angle 30 degrees are included")
	check(not PhoneFlashReceiver.in_beam(Vector2.ZERO, Vector2.RIGHT, Vector2.from_angle(deg_to_rad(30.01)) * 100, 120, 60), "outside the 60 degree cone misses")
	check(not PhoneFlashReceiver.in_beam(Vector2.ZERO, Vector2.RIGHT, Vector2(120.01,0), 120, 60), "outside 120 pixels misses")
	check(PhoneFlashReceiver.in_beam(Vector2.ZERO, Vector2.RIGHT, Vector2.ZERO, 120, 60), "coincident center is a valid near-contact hit")
	check(not PhoneFlashReceiver.in_beam(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 120, 60), "zero look vector is rejected")
	# Test both the visible-ray and floor-collision obstruction on the actual world.
	var target = enemies[0]
	target.active = true
	target.flash_receiver.stun_remaining = 0.0
	var wall := LevelGeometry.wall(world, Rect2(344, 100, 9, 170))
	var occluder := world.get_child(world.get_child_count()-1)
	await physics(3)
	reset_flash()
	check(player.phone_defense.fire().ok and not target.flash_receiver.is_stunned(), "wall blocks stun while an empty flash still spends resources")
	wall.queue_free()
	occluder.queue_free()
	await physics(3)
	reset_flash()
	GameState.reduced_flash = true
	check(player.phone_defense.fire().ok and target.flash_receiver.is_stunned() and player.phone_defense.flash_light.energy < 1.0, "reduced visuals preserve the same hit and stun geometry")
	GameState.reduced_flash = false
	target.active = false
	target.flash_receiver.stun_remaining = 0.0
	reset_flash()
	player.phone_defense.fire()
	check(not target.flash_receiver.is_stunned(), "inactive or finished entities do not revive from a flash")
	reset_flash(0, 0)
	hud = preload("res://ui/quiet_hud.gd").new()
	add_child(hud)
	var phone := preload("res://ui/demo_phone.gd").new()
	hud.open_widget(phone)
	get_tree().paused = true
	var event_count := fired
	await tap("camera_flash")
	check(GameState.phone_battery == 0 and fired == event_count and phone.is_visible_in_tree(), "phone remains readable at zero battery and R in the modal cannot fire")
	hud.close_requested.connect(func():
		hud.close_panel()
		get_tree().paused = false
	)
	await tap("pause")
	check(not get_tree().paused and not hud.panel_open and fired == event_count, "closing the modal consumes its input without a world flash")
	player.position = Vector2(180, 174)
	GameState.phone_flash_charges = 0
	check(GameState.recharge_preparation() and GameState.phone_battery == 100 and GameState.phone_flash_charges == 0, "safe recharging restores battery but never used opportunities")
	player.phone_defense.prepare_chapter()
	check(GameState.phone_flash_charges == 0, "re-entering an already supplied chapter cannot farm charges")
	GameState.demo_pursuit = "hall"
	check(not GameState.recharge_preparation(), "pursuit cannot use a preparation recharge")
	GameState.demo_pursuit = ""
	GameState.current_chapter_id = "ch2_guia_tunnel"
	GameState.current_room_id = "ch2_hill_base"
	GameState.phone_battery = 10
	player.phone_defense.prepare_chapter()
	check(GameState.phone_battery == 50 and GameState.phone_flash_charges == 2, "next chapter supplies minimum 50 battery and two opportunities once")
	var flash_count := fired
	AudioManager.play_world_effect("camera_shutter")
	check(fired == flash_count and GameState.phone_flash_charges == 2, "normal shutter/audio is separate from the defense signal")
	await _verify_enemy_types()
	await _verify_codec()
	print("PHONE_DEFENSE_081 checks=%d failures=%d" % [checks, failures])
	get_tree().paused = false
	get_tree().quit(1 if failures > 0 else 0)

func _verify_enemy_types() -> void:
	player.position = Vector2(300, 400)
	player.look_dir = Vector2.RIGHT
	player.flashlight_on = false
	var priest := preload("res://entities/priest_013.gd").new()
	priest.position = Vector2(385, 375)
	priest.target = player
	priest.active = false
	priest.speed = 0.0
	world.add_child(priest)
	var red := preload("res://entities/bunker_family.gd").new()
	red.position = Vector2(390, 375)
	red.target = player
	red.speed_scale = 0.0
	world.add_child(red)
	var beach := BeachStub.new()
	world.add_child(beach)
	var ghost := preload("res://entities/beach_apparition.gd").new()
	ghost.position = Vector2(395, 400)
	ghost.beach = beach
	ghost.player = player
	ghost.active = false
	beach.add_child(ghost)
	await physics(3)
	priest.active = true
	red.active = true
	ghost.active = true
	reset_flash()
	player.phone_defense.fire()
	for enemy in [priest, red, ghost]:
		check(enemy.flash_receiver.is_stunned() and enemy.velocity == Vector2.ZERO, "actual enemy receives flash without capture: " + enemy.get_script().resource_path.get_file())
	var positions := [priest.position, red.position, ghost.position]
	await physics(30)
	check(priest.position.x > positions[0].x and red.position.x > positions[1].x and ghost.position.x > positions[2].x, "all actual enemy types recoil away from the flash")
	positions = [priest.position, red.position, ghost.position]
	await physics(30)
	check(priest.position == positions[0] and red.position == positions[1] and ghost.position == positions[2], "all actual enemy types stop after the initial recoil and stay stunned")
	for enemy in [priest, red, ghost]: enemy.active = false

func _verify_codec() -> void:
	GameState.current_chapter_id = "ch0_tanglau"
	GameState.current_room_id = "ch0_hk_work"
	GameState.pending_entry_id = "arrival"
	GameState.phone_battery = 31.0
	GameState.phone_flash_charges = 1
	GameState.phone_flash_cooldown = 0.7
	var data: Dictionary = GameState._opening_checkpoint_data()
	var scope: Dictionary = GameState.opening_scope()
	var encoded := JSON.stringify(data)
	var decoded := OpeningCheckpoint.decode(encoded, scope)
	check(not decoded.is_empty() and decoded.phone_defense.battery == 31 and decoded.phone_defense.charges == 1 and decoded.phone_defense.cooldown == 0.7, "codec retains battery, spent charges and cooldown together")
	for bad_field in ["battery", "charges", "cooldown", "supplied_chapters"]:
		var invalid := data.duplicate(true)
		invalid.phone_defense.erase(bad_field)
		check(OpeningCheckpoint.decode(JSON.stringify(invalid), scope).is_empty(), "partial defense record rejected: " + bad_field)
	for invalid_value in [true, -1, 2.5, 3]:
		var invalid := data.duplicate(true)
		invalid.phone_defense.charges = invalid_value
		check(OpeningCheckpoint.decode(JSON.stringify(invalid), scope).is_empty(), "invalid opportunity count rejected: " + str(invalid_value))
	var old := data.duplicate(true)
	old.erase("phone_defense")
	decoded = OpeningCheckpoint.decode(JSON.stringify(old), scope)
	check(not decoded.is_empty() and decoded.phone_defense.charges == 2 and decoded.phone_defense.supplied_chapters.has("ch0_tanglau"), "pre-081 checkpoint migrates current chapter once without losing flags/items")
	var base := GameState.get_profile_path().path_join("codec_fixture")
	check(OpeningCheckpoint.save_state(base, data, scope), "defense state writes to the isolated fixture directory")
	var loaded := OpeningCheckpoint.load_state(base, scope)
	check(loaded.ok and loaded.data.phone_defense.charges == 1 and loaded.data.phone_defense.supplied_chapters == data.phone_defense.supplied_chapters, "disk read preserves spent charges and chapter supply ledger")
