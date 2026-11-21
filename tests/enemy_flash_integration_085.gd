extends Node
# Actual enemy/phone fixtures. Known positions and authored rules are used;
# this is a system regression, not a first-time exploration or art review.
var checks := 0
var failures := 0
var world: Node2D
var player: PlayerController
var enemy: CharacterBody2D
var captures := 0
var flash_events := 0
var beach: BeachStub

class BeachStub extends Node2D:
	var hud: Node2D
	var lit := false
	func _init() -> void: hud = self
	func in_headlight(_point: Vector2) -> bool: return lit
	func notify(_message: String) -> void: pass

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1
	print(("PASS " if value else "FAIL ") + message)

func physics(count: int) -> void:
	for _i in range(count): await get_tree().physics_frame

func frames(count: int) -> void:
	for _i in range(count): await get_tree().process_frame

func reset_flash() -> void:
	GameState.phone_battery = 100.0
	GameState.phone_flash_charges = 2
	GameState.phone_flash_cooldown = 0.0

func run() -> void:
	check(GameState.profile == "test", "isolated enemy fixture profile")
	GameState.reset_opening()
	GameState.opening_resume_checked = true
	GameState.current_room_id = "ch1_crypt_entry"
	GameState.current_chapter_id = "ch1_stpaul_crypt"
	GameState.opening_flags.jiamin_phone_found = true
	GameState.take_demo_item("jiamin_phone")
	world = Node2D.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	player = preload("res://entities/player/player.tscn").instantiate()
	player.visual_size_multiplier = 1.65
	player.aim_override = true
	world.add_child(player)
	player.flashlight_on = false
	beach = BeachStub.new()
	world.add_child(beach)
	EventBus.camera_flash_fired.connect(func(_origin: Vector2, _direction: Vector2): flash_events += 1)
	await physics(4)
	for role in ["shadow", "priest", "father", "mother", "daughter", "beach"]:
		await verify_enemy(role)
	await verify_mother_search_path()
	await verify_no_flash_protection()
	print("ENEMY_FLASH_INTEGRATION_085 checks=%d failures=%d" % [checks, failures])
	get_tree().paused = false
	get_tree().quit(1 if failures > 0 else 0)

func spawn_enemy(role: String) -> void:
	if is_instance_valid(enemy):
		enemy.queue_free()
		await physics(3)
	player.position = Vector2(400, 450)
	player.clear_motion()
	player.look_dir = Vector2.RIGHT
	player.hidden_in_wardrobe = false
	player.flashlight_on = false
	player.lamp.enabled = false
	beach.lit = false
	if role == "shadow": enemy = preload("res://entities/shadow_chaser.gd").new()
	elif role == "priest": enemy = preload("res://entities/priest_013.gd").new()
	elif role == "beach": enemy = preload("res://entities/beach_apparition.gd").new()
	else:
		enemy = preload("res://entities/bunker_family.gd").new()
		enemy.role_id = ["father", "mother", "daughter"].find(role)
	enemy.active = false
	enemy.position = Vector2(490, 430) if role != "beach" else Vector2(490, 450)
	if role == "beach":
		enemy.player = player
		enemy.beach = beach
		beach.add_child(enemy)
	else:
		enemy.target = player
		world.add_child(enemy)
	if role in ["father", "mother", "daughter"]:
		enemy.caught.connect(func(_id: int): captures += 1)
	else: enemy.caught.connect(func(): captures += 1)
	await physics(3)

func verify_enemy(role: String) -> void:
	await spawn_enemy(role)
	var capture_start := captures
	enemy.active = true
	enemy.velocity = Vector2(70, 0)
	reset_flash()
	var fired_start := flash_events
	var result: Dictionary = player.phone_defense.fire()
	check(result.ok and flash_events == fired_start + 1 and GameState.phone_flash_charges == 1, role + " actual held-phone trigger spends one charge")
	check(enemy.flash_receiver.is_stunned() and enemy.velocity == Vector2.ZERO, role + " stun cancels movement immediately")
	var before := enemy.position
	await physics(30)
	check(enemy.position == before and captures == capture_start, role + " cannot move or capture while stunned")
	if role in ["shadow", "priest"]:
		check(not enemy.get_node("Figure").is_playing(), role + " walk animation pauses during stun")
	var remaining: float = enemy.flash_receiver.stun_remaining
	get_tree().paused = true
	await frames(35)
	check(is_equal_approx(enemy.flash_receiver.stun_remaining, remaining) and enemy.position == before, role + " pause preserves the full remaining stun")
	get_tree().paused = false
	# Target has moved beyond an opaque wall. Recovery must use the position seen
	# at the flash, not the hidden player's current position or movement velocity.
	var wall := LevelGeometry.wall(world, Rect2(540, 250, 10, 450))
	var occluder := world.get_child(world.get_child_count() - 1)
	player.position = Vector2(580, 450)
	await physics(130)
	check(not enemy.flash_receiver.is_stunned() and enemy.flash_receiver.search_remaining > 0.0, role + " recovers into search while target is behind a wall")
	check(enemy.position.x < before.x and captures == capture_start, role + " searches the last seen position without teleport or capture")
	wall.queue_free()
	occluder.queue_free()
	await physics(4)
	check(enemy.flash_receiver.search_remaining <= 0.0 and enemy.velocity.x > 0.0, role + " sees the returning target and resumes pursuit")
	enemy.active = false
	enemy.velocity = Vector2(40, 0)
	await physics(3)
	check(enemy.velocity == Vector2.ZERO, role + " finished story state has zero residual velocity")
	if role in ["shadow", "priest"]:
		check(not enemy.get_node("Figure").is_playing(), role + " finished story state stops walking animation")
	player.position = Vector2(400, 450)
	enemy.position = before
	reset_flash()
	player.phone_defense.fire()
	check(not enemy.flash_receiver.is_stunned() and not enemy.active, role + " a new flash cannot revive an inactive entity")
	# Close wall and hiding capture tests use the real enemy tick at zero speed.
	enemy.active = true
	enemy.flash_receiver.search_remaining = 0.0
	enemy.flash_receiver.stun_remaining = 0.0
	if role in ["shadow", "priest"]: enemy.speed = 0.0
	elif role != "beach": enemy.speed_scale = 0.0
	player.position = Vector2(400, 450)
	enemy.position = Vector2(418, 450) if role == "beach" else Vector2(410, 450)
	wall = LevelGeometry.wall(world, Rect2(405 if role == "beach" else 403, 395, 3, 110))
	occluder = world.get_child(world.get_child_count() - 1)
	await physics(4)
	check(not enemy.flash_receiver.may_catch(player), role + " capture eligibility rejects world-wall occlusion")
	check(captures == capture_start and enemy.active, role + " cannot capture through a thin world wall")
	wall.queue_free()
	occluder.queue_free()
	player.hidden_in_wardrobe = true
	await physics(4)
	check(not enemy.flash_receiver.may_catch(player), role + " capture eligibility rejects a hidden target")
	check(captures == capture_start and enemy.active, role + " cannot capture a hidden target")
	player.hidden_in_wardrobe = false
	player.position = Vector2(400, 450)
	enemy.position = Vector2(418, 450) if role == "beach" else Vector2(410, 450)
	await physics(4)
	check(captures == capture_start + 1 and not enemy.active and enemy.velocity == Vector2.ZERO, role + " valid close contact captures once then stops")

func verify_mother_search_path() -> void:
	await spawn_enemy("mother")
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, 100, 80)
	grid.cell_size = Vector2(10, 10)
	grid.offset = Vector2(5, 5)
	grid.update()
	enemy.grid = grid
	enemy.active = true
	enemy.set_physics_process(false)
	player.set_physics_process(false)
	player.position = Vector2(700, 450)
	player.velocity = Vector2(85, 0)
	enemy.flash_receiver.search_position = Vector2(400, 450)
	enemy.flash_receiver.search_remaining = 5.0
	var wall := LevelGeometry.wall(world, Rect2(540, 250, 10, 450))
	var occluder := world.get_child(world.get_child_count() - 1)
	await physics(3)
	enemy._physics_process(0.0)
	check(not enemy.route.is_empty() and enemy.route[-1].distance_to(Vector2(400, 450)) < 9.0, "mother search path uses the last seen place without hidden-player velocity prediction")
	enemy.active = false
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	wall.queue_free()
	occluder.queue_free()
	await physics(3)

func verify_no_flash_protection() -> void:
	await spawn_enemy("priest")
	var before_events := flash_events
	enemy.active = true
	player.flashlight_on = true
	player.lamp.enabled = true
	player.look_dir = (enemy.global_position + Vector2(0, -45) - player.get_flashlight_origin()).normalized()
	var before := enemy.position
	await physics(18)
	check(enemy.illuminated() and enemy.position == before and flash_events == before_events, "ordinary flashlight holds the priest without a defensive flash")
	enemy.active = false
	await spawn_enemy("beach")
	enemy.active = true
	beach.lit = true
	before = enemy.position
	await physics(20)
	check(enemy.position.distance_to(player.position) > before.distance_to(player.position) and flash_events == before_events, "headlight refuge drives the apparition back without a defensive flash")
	enemy.active = false
	beach.lit = false
	player.position = Vector2(400, 310)
	enemy.position = Vector2(430, 360)
	enemy.active = true
	var capture_start := captures
	await physics(10)
	check(captures == capture_start and enemy.position.y >= 354, "beach dry ground remains a non-flash escape boundary")
