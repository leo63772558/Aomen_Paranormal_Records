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
var blend_pose: Sprite2D
var base_pose_scale := 1.0
var frames: Array[AtlasTexture] = []
var use_quad_front_cycle := false
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
	collision_mask = 33
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
	base_pose_scale = height / float(ROW_HEIGHT[role_id])
	pose.scale = Vector2.ONE * base_pose_scale
	pose.position = Vector2(0, -height * 0.5 + 1.0)
	add_child(pose)
	blend_pose = Sprite2D.new()
	blend_pose.texture = frames[1]
	blend_pose.scale = pose.scale
	blend_pose.position = pose.position
	blend_pose.modulate.a = 0.0
	add_child(blend_pose)
	z_index = int(position.y)
	if role_id == 0:
		GhostTaunt.attach(self, PackedStringArray(["那三个人死了……", "终于来了……你终于来了……", "门锁上了，你出不去了……", "你完蛋了……"]), 2.8)

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
	if flash_receiver.may_catch(target) and global_position.distance_to(target.global_position) <= (22.0 if role_id == 2 else 24.0):
		active = false
		velocity = Vector2.ZERO
		caught.emit(role_id)

func _pose_for(direction: Vector2, distance: float, delta: float) -> void:
	if distance < 0.04:
		return
	gait += delta * (7.2 if role_id == 2 else 5.2 + role_id * 0.6)
	look = look.lerp(direction, 1.0 - exp(-16.0 * delta)).normalized()
	var cycle := 0.5 + 0.5 * sin(gait * TAU)
	if use_quad_front_cycle and frames.size() >= 4:
		var phase_f := fmod(gait * 2.0, 4.0)
		var f0 := int(floor(phase_f)) % 4
		var f1 := (f0 + 1) % 4
		pose.texture = frames[f0]
		blend_pose.texture = frames[f1]
		pose.flip_h = false
		blend_pose.flip_h = false
		blend_pose.modulate.a = clampf(phase_f - floor(phase_f), 0.0, 1.0)
	elif absf(look.x) > absf(look.y) * 0.92:
		pose.texture = frames[2]
		blend_pose.texture = frames[0]
		pose.flip_h = look.x < 0
		blend_pose.flip_h = pose.flip_h
		blend_pose.modulate.a = cycle * 0.38
	elif look.y < -0.35:
		pose.texture = frames[3]
		blend_pose.texture = frames[2]
		pose.flip_h = look.x < 0
		blend_pose.flip_h = pose.flip_h
		blend_pose.modulate.a = cycle * 0.34
	else:
		pose.texture = frames[0]
		blend_pose.texture = frames[1]
		pose.flip_h = look.x < -0.25
		blend_pose.flip_h = pose.flip_h
		blend_pose.modulate.a = cycle
	var bob_y := -float(ROLE_HEIGHT[role_id]) * 0.5 + 1.0 + sin(gait * TAU) * 2.1
	var squash := 1.0 + sin(gait * TAU * 2.0) * 0.036
	var stretch := 1.0 - sin(gait * TAU * 2.0) * 0.024
	var target_rot := clampf(look.x * 0.08 + sin(gait * TAU) * 0.042, -0.14, 0.14)
	pose.rotation = lerpf(pose.rotation, target_rot, 1.0 - exp(-16.0 * delta))
	pose.scale = Vector2(base_pose_scale * stretch, base_pose_scale * squash)
	pose.position.y = bob_y
	var near_dist := global_position.distance_to(target.global_position) if is_instance_valid(target) else 999.0
	if not GameState.reduced_flash and near_dist < 130.0:
		pose.position.x = sin(gait * 14.0 + role_id) * (1.5 if role_id == 2 else 1.0)
		pose.modulate = Color(1.0, 0.82, 0.80, 1.0)
	else:
		pose.position.x = 0.0
		pose.modulate = Color.WHITE
	if is_instance_valid(blend_pose):
		blend_pose.position = pose.position
		blend_pose.rotation = pose.rotation
		blend_pose.scale = pose.scale
	z_index = int(position.y)
	afterimage_timer -= delta
	if afterimage_timer <= 0.0 and not GameState.reduced_flash:
		afterimage_timer = 0.11 + role_id * 0.02
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
