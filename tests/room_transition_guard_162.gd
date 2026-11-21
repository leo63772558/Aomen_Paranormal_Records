extends Node

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	if GameState.profile != "test":
		push_error("isolated test profile required")
		get_tree().quit(1)
		return
	var root := Node2D.new()
	var empty := PackedScene.new()
	if empty.pack(root) != OK:
		push_error("could not build invalid scene fixture")
		get_tree().quit(1)
		return
	root.free()
	if GameState._room_scene_has_valid_controller(empty):
		push_error("scriptless room was incorrectly accepted")
		get_tree().quit(1)
		return
	for path in ["res://levels/ch0_tanglau/opening_street.tscn", "res://levels/ch2_guia/bunker_shaft_084.tscn", "res://levels/ch6_abandoned_vip/abandoned_vip_rescue_061.tscn"]:
		var scene := load(path) as PackedScene
		if not GameState._room_scene_has_valid_controller(scene):
			push_error("valid room controller rejected: " + path)
			get_tree().quit(1)
			return
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://core/data/rooms_db.json"))
	for id in registry:
		var registered := load(registry[id].scene) as PackedScene
		if not GameState._room_scene_has_valid_controller(registered):
			push_error("registered room controller rejected: " + str(id))
			get_tree().quit(1)
			return
	var old_room: String = GameState.current_room_id
	var old_entry: String = GameState.pending_entry_id
	if GameState.request_room_change("not_registered", "invalid") or GameState.current_room_id != old_room or GameState.pending_entry_id != old_entry:
		push_error("invalid room transition changed current progress")
		get_tree().quit(1)
		return
	var menu = load("res://ui/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().process_frame
	GameState.current_room_id = "not_registered"
	menu._proceed()
	var error_label: Label = menu.load_error
	if error_label == null or error_label.text.is_empty() or get_tree().current_scene != menu:
		push_error("main menu did not report the failed transition")
		get_tree().quit(1)
		return
	GameState.current_room_id = old_room
	GameState.pending_entry_id = old_entry
	print("PASS %d registered room controllers, rejected scriptless fixture and unchanged room on failure" % registry.size())
	get_tree().quit()
