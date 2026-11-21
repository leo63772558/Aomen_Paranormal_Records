extends Node
# Walkability audit: flood-fills every registered room from its spawn using the
# player's real collision body (test_move), then writes a JSON report that
# tools/walk_overlay.py composites over the room art for visual review.

const STEP := 8.0
var report := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func run() -> void:
	if GameState.profile != "test":
		push_error("isolated test profile required")
		get_tree().quit(1)
		return
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://core/data/rooms_db.json"))
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--room="):
			only = arg.substr(7)
	for room_id in registry:
		if not only.is_empty() and room_id != only:
			continue
		var entries: Array = registry[room_id].entries
		for entry in entries:
			await audit_room(room_id, String(entry), registry[room_id].scene)
			break
	var file := FileAccess.open("res://docs/build_reports/walk_audit/walk_audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()
	print("WALK AUDIT rooms=%d" % report.size())
	get_tree().paused = false
	get_tree().quit()

func seed_flags() -> void:
	GameState.reset_opening()
	GameState.opening_resume_checked = true
	for key in GameState.opening_flags.keys():
		if typeof(GameState.opening_flags[key]) == TYPE_BOOL and not key.begins_with("ending_"):
			GameState.opening_flags[key] = true
	GameState.opening_items = {"multitool_pliers": 1}

func find_player(node: Node) -> PlayerController:
	if node is PlayerController:
		return node
	for child in node.get_children():
		var found := find_player(child)
		if found:
			return found
	return null

func find_background(node: Node, best: Array) -> void:
	if node is Sprite2D and node.texture and node.texture.resource_path != "":
		var area: float = node.texture.get_size().x * node.texture.get_size().y * node.scale.x * node.scale.y
		if area > best[1]:
			best[0] = node
			best[1] = area
	elif node is TileMapLayer and "background_texture" in node and node.background_texture and node.background_texture.resource_path != "":
		var area2 := 640.0 * 360.0
		if area2 > best[1]:
			best[0] = node
			best[1] = area2
	for child in node.get_children():
		find_background(child, best)

func audit_room(room_id: String, entry: String, path: String) -> void:
	seed_flags()
	GameState.current_room_id = room_id
	GameState.current_chapter_id = OpeningCheckpoint.chapter_for_room(room_id)
	GameState.pending_entry_id = entry
	var packed := load(path) as PackedScene
	var scene := packed.instantiate()
	get_tree().root.add_child(scene)
	for _i in range(6):
		await get_tree().physics_frame
	get_tree().paused = false
	var player := find_player(scene)
	var result := {"scene": path, "entry": entry}
	if player == null:
		result.error = "no player"
		report[room_id] = result
		scene.queue_free()
		await get_tree().process_frame
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	var bounds := Rect2(0, 0, 640, 360)
	if "WORLD_SIZE" in scene:
		bounds = Rect2(Vector2.ZERO, scene.WORLD_SIZE)
	elif camera and camera.limit_right < 100000:
		bounds = Rect2(camera.limit_left, camera.limit_top, camera.limit_right - camera.limit_left, camera.limit_bottom - camera.limit_top)
	var best := [null, 0.0]
	find_background(scene, best)
	if best[0] is Sprite2D:
		var bg: Sprite2D = best[0]
		result.background = bg.texture.resource_path
		result.bg_origin = [bg.global_position.x, bg.global_position.y]
		result.bg_scale = [bg.global_scale.x, bg.global_scale.y]
		result.bg_centered = bg.centered
		if bg.texture is AtlasTexture:
			result.bg_region = [bg.texture.region.position.x, bg.texture.region.position.y, bg.texture.region.size.x, bg.texture.region.size.y]
	elif best[0] is TileMapLayer:
		var tbg: TileMapLayer = best[0]
		result.background = tbg.background_texture.resource_path
		result.bg_origin = [0.0, 0.0]
		var tex_sz: Vector2 = tbg.background_texture.get_size()
		result.bg_scale = [640.0 / tex_sz.x, 360.0 / tex_sz.y]
		result.bg_centered = false
	var start: Vector2 = player.global_position
	var cols := int(bounds.size.x / STEP)
	var rows := int(bounds.size.y / STEP)
	var origin := bounds.position
	var seen := {}
	var queue: Array[Vector2i] = []
	var start_cell := Vector2i(int((start.x - origin.x) / STEP), int((start.y - origin.y) / STEP))
	var base := player.global_transform
	# Snap the start so test_move begins from a real, non-penetrating position.
	seen[start_cell] = true
	queue.append(start_cell)
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var guard := 0
	while not queue.is_empty() and guard < 60000:
		guard += 1
		var cell: Vector2i = queue.pop_front()
		var from := origin + (Vector2(cell) + Vector2(0.5, 0.5)) * STEP
		if cell == start_cell:
			from = start
		for d in dirs:
			var next: Vector2i = cell + d
			if next.x < 0 or next.y < 0 or next.x >= cols or next.y >= rows or seen.has(next):
				continue
			var to := origin + (Vector2(next) + Vector2(0.5, 0.5)) * STEP
			var xf := Transform2D(base.get_rotation(), from)
			if not player.test_move(xf, to - from):
				seen[next] = true
				queue.append(next)
	var cells: Array = []
	for c in seen:
		cells.append([c.x, c.y])
	result.bounds = [origin.x, origin.y, bounds.size.x, bounds.size.y]
	result.step = STEP
	result.start = [start.x, start.y]
	result.cells = cells
	report[room_id] = result
	print("ROOM %s reachable=%d" % [room_id, cells.size()])
	scene.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
	await get_tree().process_frame
