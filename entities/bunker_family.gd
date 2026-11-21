extends CharacterBody2D

signal caught(role_id: int)

const ROLE_HEIGHT := [71.0, 62.0, 43.0]
const ROW_TOP := [8, 387, 770]
const ROW_HEIGHT := [372, 365, 305]
const FRAME_X := [204, 545, 884, 1256]
const SPEED := [104.0, 94.0, 85.0]
var role_id := 0
var target: PlayerController
var grid: AStarGrid2D
var active := false
var speed_scale := 1.0
var look := Vector2.DOWN
var pose: Sprite2D
var frames: Array[AtlasTexture] = []
var route := PackedVector2Array()
var repath := 0.0
var gait := 0.0
var hearing := 0.0
var afterimage_timer := 0.0
var flash_receiver: PhoneFlashReceiver

func _ready() -> void:
	flash_receiver = PhoneFlashReceiver.new()
	flash_receiver.sense_offset = Vector2(0, -ROLE_HEIGHT[role_id] * 0.6)
	add_child(flash_receiver)
	flash_receiver.stunned.connect(func(): route.clear(); repath = 0.0)
	collision_layer = 4
	collision_mask = 1
	var hull := CircleShape2D.new()
	hull.radius = 6 if role_id == 2 else 8
	var collision := CollisionShape2D.new()
	collision.shape = hull
	add_child(collision)
	var art: Texture2D = load("res://assets/characters/bunker_family_026.png")
	for i in range(4):
		var crop := AtlasTexture.new()
		crop.atlas = art
		var x: int = FRAME_X[i] - 145
		crop.region = Rect2(x, ROW_TOP[role_id], 290, ROW_HEIGHT[role_id])
		crop.filter_clip = true
		frames.append(crop)
	pose = Sprite2D.new()
	pose.texture = frames[0]
	var height: float = ROLE_HEIGHT[role_id]
	pose.scale = Vector2.ONE * height / float(ROW_HEIGHT[role_id])
	pose.position = Vector2(0, -height * 0.5 + 1.0)
	add_child(pose)
	z_index = int(position.y)

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(target):
		velocity = Vector2.ZERO
		return
	if flash_receiver.is_stunned():
		velocity = Vector2.ZERO
		return
	var focus := flash_receiver.focus_after_flash(target)
	if grid != null:
		repath -= delta
		if repath <= 0:
			repath = 0.16 + 0.03 * role_id
			var projected := focus
			if role_id == 1 and flash_receiver.search_remaining <= 0.0 and global_position.distance_to(focus) > 58:
				projected += target.velocity.limit_length(85) * 0.32 + Vector2(27, 0)
			route = _path_to(projected)
			if route.size() < 2:
				route = _path_to(focus)
		while route.size() > 1 and global_position.distance_to(route[0]) <= 9.0:
			route.remove_at(0)
		if not route.is_empty() and global_position.distance_to(focus) > 23.0:
			focus = route[0]
	var direction := global_position.direction_to(focus)
	velocity = direction * float(SPEED[role_id]) * speed_scale
	var before := global_position
	move_and_slide()
	var distance := global_position.distance_to(before)
	_pose_for(direction, distance, delta)
	if flash_receiver.may_catch(target) and global_position.distance_to(target.global_position) <= (13.0 if role_id == 2 else 16.0):
		active = false
		velocity = Vector2.ZERO
		caught.emit(role_id)

func _pose_for(direction: Vector2, distance: float, delta: float) -> void:
	if distance < 0.1:
		return
	gait += delta * (6.4 if role_id == 2 else 4.1 + role_id)
	look = direction
	if absf(look.x) > absf(look.y) * 0.85:
		pose.texture = frames[2]
		pose.flip_h = look.x < 0
	elif look.y < 0:
		pose.texture = frames[3]
		pose.flip_h = false
	else:
		pose.texture = frames[int(gait * 2.0) % 2]
		pose.flip_h = false
	pose.position.y = -float(ROLE_HEIGHT[role_id]) * 0.5 + 1.0 + sin(gait * TAU) * 1.6
	var near_dist := global_position.distance_to(target.global_position) if is_instance_valid(target) else 999.0
	if not GameState.reduced_flash and near_dist < 130.0:
		pose.position.x = sin(gait * 19.0 + role_id) * (1.8 if role_id == 2 else 1.2)
		pose.modulate = Color(1.0, 0.82, 0.80, 1.0)
	else:
		pose.position.x = 0.0
		pose.modulate = Color.WHITE
	z_index = int(position.y)
	afterimage_timer -= delta
	if afterimage_timer <= 0.0 and not GameState.reduced_flash:
		afterimage_timer = 0.16 + role_id * 0.03
		_spawn_afterimage()
	hearing -= delta
	if hearing <= 0:
		hearing = 0.56 + role_id * 0.13
		AudioManager.play_at(get_parent(), "red_footsteps", position, -8.0 - role_id * 3)

func _spawn_afterimage() -> void:
	if get_parent() == null or pose == null or pose.texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = pose.texture
	ghost.flip_h = pose.flip_h
	ghost.scale = pose.scale
	ghost.global_position = pose.global_position
	ghost.modulate = Color(0.75, 0.18, 0.16, 0.34)
	ghost.z_index = z_index - 1
	get_parent().add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.24)
	tw.tween_callback(ghost.queue_free)

func _path_to(point: Vector2) -> PackedVector2Array:
	var from := _nearest_walkable(global_position)
	var to := _nearest_walkable(point)
	if from == Vector2i(-1, -1) or to == Vector2i(-1, -1):
		return PackedVector2Array()
	return grid.get_point_path(from, to)

func _nearest_walkable(point: Vector2) -> Vector2i:
	var origin := Vector2i(floori(point.x / 10.0), floori(point.y / 10.0))
	var best := Vector2i(-1, -1)
	var distance := INF
	for y in range(-3, 4):
		for x in range(-3, 4):
			var cell := origin + Vector2i(x, y)
			if not grid.region.has_point(cell) or grid.is_point_solid(cell):
				continue
			var candidate := point.distance_squared_to(grid.get_point_position(cell))
			if candidate < distance:
				distance = candidate
				best = cell
	return best
