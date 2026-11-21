extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS " + label)
	else:
		failures += 1
		push_error("FAIL " + label)

func run() -> void:
	GameState.prepare_opening_resume()
	check(GameState.profile == "test", "restart uses isolated test profile")
	check(GameState.current_room_id == "ch5_hacsa_beach" and GameState.current_chapter_id == "ch5_hacsa_beach", "saved return room and chapter reload")
	check(GameState.opening_flags.coastal_route_verified and GameState.opening_flags.coastal_landing_seen, "upper route and landing flags reload")
	check(GameState.opening_flags.coastal_lower_drain_seen and GameState.opening_flags.coastal_shutter_seen and GameState.opening_flags.coastal_crawlway_seen, "all lower evidence flags reload")
	var rooms: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://core/data/rooms_db.json"))
	var scene_path: String = rooms[GameState.current_room_id].scene
	var scene: Node = load(scene_path).instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	for _i in range(12):
		await get_tree().process_frame
	check(is_instance_valid(scene.player) and not scene.hud.panel_open, "normal saved room opens without replaying introduction")
	print("COASTAL RESTART 057 checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
