extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame

func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1

func run() -> void:
	check(GameState.profile == "test", "isolated transition failure profile")
	GameState.reset_opening()
	GameState.opening_resume_checked = true
	GameState.current_room_id = "ch5_coastal_works"
	GameState.current_chapter_id = "ch5_hacsa_beach"
	GameState.pending_entry_id = "from_beach"
	GameState.opening_flags.beach_circuit_matched = true
	GameState.opening_flags.coastal_intro_seen = true
	GameState.opening_flags.coastal_route_verified = true
	var scene = preload("res://levels/ch5_hacsa_beach/coastal_works.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await frames(6)
	if scene.hud.panel_open:
		scene._close_panel()
	var safe_start: Vector2 = scene.player.position
	scene._descend_shaft("missing_room")
	await frames(50)
	check(GameState.current_room_id == "ch5_coastal_works" and not scene.transition_active, "failed destination keeps room and clears transition lock")
	check(scene.hud.panel_open and get_tree().paused and not scene.player.controls_enabled, "failed destination displays retry explanation")
	check(scene.find_children("ShaftTransitionFade", "CanvasLayer", true, false).is_empty(), "failed destination removes transition overlay")
	check(scene.player.position == safe_start, "failed descent restores the safe starting position")
	scene._close_panel()
	check(not get_tree().paused and scene.player.controls_enabled, "closing failure explanation restores control")
	scene._descend_shaft()
	await frames(50)
	check(GameState.current_room_id == "ch5_coastal_landing", "retry enters the registered destination")
	var landing = get_tree().current_scene
	if landing.hud.panel_open:
		landing._close_panel()
	for flag in landing.FLAGS.values():
		GameState.opening_flags[flag] = true
	GameState.opening_flags.coastal_crawlway_seen = true
	var landing_start: Vector2 = landing.player.position
	landing._enter_crawlway("missing_room")
	await frames(60)
	check(GameState.current_room_id == "ch5_coastal_landing" and not landing.transition_active, "failed crawlway remains in the landing")
	check(landing.player.position == landing_start and not landing.player.crouching, "failed crawlway restores safe position and standing pose")
	check(landing.hud.panel_open and get_tree().paused, "failed crawlway explains how to retry")
	landing._close_panel()
	landing._enter_crawlway()
	await frames(60)
	check(GameState.current_room_id == "ch5_coastal_chamber", "crawlway retry enters its registered destination")
	get_tree().paused = false
	print("COASTAL RETRY checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
