extends CharacterBody2D

signal caught
signal charge_warned
signal fell

enum State { IDLE, PATROL, INVESTIGATE, CHASE, STUNNED, SEARCH, RETURN }
const NAV := preload("res://levels/ch2_guia/bunker_ammo_layout.gd")
const WALK := preload("res://assets/characters/shadow_walk_011.png")
var target: PlayerController
var active := false
var state := State.IDLE
var grid: AStarGrid2D
var pit := Rect2()
var flash_receiver: PhoneFlashReceiver
var figure: AnimatedSprite2D
var patrol_points := PackedVector2Array([Vector2(174, 226), Vector2(244, 226)])
var patrol_index := 0
var destination := Vector2.ZERO
var last_seen := Vector2.ZERO
var route := PackedVector2Array()
var repath := 0.0
var state_time := 0.0
var charge_stage := ""
var charge_origin := Vector2.ZERO
var sound_position := Vector2.ZERO
var charge_dir := Vector2.ZERO
var charge_remaining := 0.0
var fall_progress := 0.0
var fallen := false
var foot_distance := 0.0
var afterimage_timer := 0.0
var dust_timer := 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var hull := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8
	hull.shape = circle
	add_child(hull)
	figure = AnimatedSprite2D.new()
	figure.name = "Figure"
	var frames := SpriteFrames.new()
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 8.0)
	for index in range(6):
		var frame := AtlasTexture.new()
		frame.atlas = WALK
		frame.region = Rect2(index * 362, 0, 362, 724)
		frames.add_frame("walk", frame)
	figure.sprite_frames = frames
	figure.position = Vector2(0, -42)
	figure.scale = Vector2.ONE * (84.0 / 724.0)
	add_child(figure)
	flash_receiver = PhoneFlashReceiver.new()
	flash_receiver.sense_offset = Vector2(0, -48)
	add_child(flash_receiver)
	flash_receiver.stunned.connect(_stunned)
	flash_receiver.recovered.connect(_recovered)
	EventBus.noise_emitted.connect(_hear_noise)
	last_seen = position

func activate() -> void:
	if fallen:
		return
	active = true
	_set_state(State.PATROL)

func _set_state(next: State) -> void:
	state = next
	state_time = 0.0
	repath = 0.0
	route.clear()
	velocity = Vector2.ZERO

func _stunned() -> void:
	# A cancelled charge is discarded, including its old target and direction.
	charge_stage = ""
	charge_remaining = 0.0
	charge_dir = Vector2.ZERO
	sound_position = Vector2.ZERO
	_set_state(State.STUNNED)
	figure.pause()
	figure.rotation = 0.0
	figure.modulate = Color("c6d5d6")

func _recovered() -> void:
	if not active or fallen:
		return
	figure.modulate = Color.WHITE
	last_seen = flash_receiver.search_position
	_set_state(State.SEARCH)

func _hear_noise(origin: Vector2, radius: float, source_id: String) -> void:
	if not active or fallen or get_tree().paused or flash_receiver.is_stunned() or not charge_stage.is_empty():
		return
	if origin.distance_to(global_position) > radius:
		return
	if source_id == "shaft_bucket_084":
		begin_lure(origin, Vector2(pit.position.x - 34, origin.y))
	elif state != State.CHASE:
		last_seen = origin
		destination = origin
		_set_state(State.INVESTIGATE)

func begin_lure(origin: Vector2, approach: Vector2) -> bool:
	if not active or fallen or flash_receiver.is_stunned() or not charge_stage.is_empty():
		return false
	sound_position = origin
	charge_origin = approach
	charge_stage = "approach"
	_set_state(State.CHASE)
	return true

func _physics_process(delta: float) -> void:
	if fallen:
		fall_progress = minf(1.0, fall_progress + delta / 0.78)
		figure.position.y = -42 + fall_progress * 46
		figure.scale = Vector2.ONE * (84.0 / 724.0) * (1.0 - fall_progress * 0.85)
		figure.rotation = fall_progress * 1.15
		figure.modulate.a = 1.0 - fall_progress
		return
	if not active or not is_instance_valid(target):
		velocity = Vector2.ZERO
		figure.pause()
		return
	if flash_receiver.is_stunned():
		velocity = Vector2.ZERO
		return
	state_time += delta
	if not charge_stage.is_empty():
		_charge(delta)
		return
	var sees_target := _sees_target()
	if sees_target and state != State.INVESTIGATE:
		last_seen = target.global_position
		if state != State.CHASE:
			_set_state(State.CHASE)
	if state == State.PATROL or state == State.RETURN:
		destination = patrol_points[patrol_index]
		if global_position.distance_to(destination) < 9:
			patrol_index = (patrol_index + 1) % patrol_points.size()
	elif state == State.CHASE:
		if not sees_target:
			_set_state(State.SEARCH)
		destination = last_seen
	elif state == State.INVESTIGATE:
		destination = last_seen
		if global_position.distance_to(destination) < 12 or state_time > 3.5:
			_set_state(State.SEARCH)
	elif state == State.SEARCH:
		destination = last_seen
		if state_time > GameState.RULES.enemy_search_time:
			_set_state(State.RETURN)
	var speed := 104.0 if state == State.CHASE else 64.0
	_walk_to(destination, speed, delta)
	if state == State.CHASE and flash_receiver.may_catch(target) and sees_target and global_position.distance_to(target.global_position) < 17:
		active = false
		velocity = Vector2.ZERO
		caught.emit()

func _sees_target() -> bool:
	if target.hidden_in_wardrobe or global_position.distance_to(target.global_position) > 230:
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _charge(delta: float) -> void:
	if charge_stage == "approach":
		_walk_to(charge_origin, 112.0, delta)
		# Navigation finishes at a cell centre; allow its half-diagonal plus
		# the waypoint tolerance, otherwise an off-grid start can stall forever.
		if global_position.distance_to(charge_origin) < 15:
			charge_stage = "windup"
			charge_remaining = 1.25
			charge_dir = global_position.direction_to(sound_position)
			velocity = Vector2.ZERO
			figure.pause()
			AudioManager.play_at(get_parent(), "hall_wail", position, -14.0)
			charge_warned.emit()
	elif charge_stage == "windup":
		velocity = Vector2.ZERO
		charge_remaining -= delta
		var tension := 1.0 - maxf(0.0, charge_remaining) / 1.25
		figure.rotation = -0.14 * tension
		figure.position.y = -42 - 5.0 * tension
		if not GameState.reduced_flash:
			figure.position.x = sin(state_time * 52.0) * 2.2 * tension
			figure.modulate = Color(1.0, 1.0 - tension * 0.42, 1.0 - tension * 0.46, 1.0)
			dust_timer -= delta
			if dust_timer <= 0.0:
				dust_timer = 0.14
				_spawn_charge_dust()
		if charge_remaining <= 0:
			figure.position.x = 0.0
			charge_stage = "run"
			charge_remaining = 1.8
	elif charge_stage == "run":
		figure.rotation = 0.15
		figure.play("walk")
		if not GameState.reduced_flash:
			figure.modulate = Color(1.0, 0.72, 0.70, 1.0)
			afterimage_timer -= delta
			if afterimage_timer <= 0.0:
				afterimage_timer = 0.055
				_spawn_charge_afterimage()
		velocity = charge_dir * 250.0
		move_and_slide()
		z_index = int(position.y)
		charge_remaining -= delta
		if pit.has_point(global_position):
			fall()
		elif flash_receiver.may_catch(target) and _sees_target() and global_position.distance_to(target.global_position) < 17:
			active = false
			charge_stage = ""
			figure.modulate = Color.WHITE
			velocity = Vector2.ZERO
			caught.emit()
		elif charge_remaining <= 0 or velocity.length_squared() < 1:
			charge_stage = ""
			figure.modulate = Color.WHITE
			last_seen = sound_position
			_set_state(State.SEARCH)

func fall() -> void:
	if fallen or charge_stage != "run":
		return
	fallen = true
	active = false
	charge_stage = ""
	velocity = Vector2.ZERO
	collision_layer = 0
	figure.pause()
	fell.emit()

func retire() -> void:
	active = false
	charge_stage = ""
	velocity = Vector2.ZERO
	figure.pause()
	_set_state(State.IDLE)

func _walk_to(point: Vector2, speed: float, delta: float) -> void:
	if grid == null:
		velocity = Vector2.ZERO
		return
	repath -= delta
	if repath <= 0:
		repath = 0.18
		var from := _nearest_walkable(global_position)
		var to := _nearest_walkable(point)
		route = grid.get_point_path(from, to) if from != Vector2i(-1,-1) and to != Vector2i(-1,-1) else PackedVector2Array()
	while not route.is_empty() and global_position.distance_to(route[0]) < 8.0:
		route.remove_at(0)
	if route.is_empty() or global_position.distance_to(point) < 8:
		velocity = Vector2.ZERO
		figure.pause()
		return
	var before := global_position
	velocity = global_position.direction_to(route[0]) * speed
	move_and_slide()
	var travelled := before.distance_to(global_position)
	if travelled > 0.05:
		figure.play("walk")
		figure.flip_h = velocity.x > 0
		figure.position.y = -42
		figure.rotation = 0
		foot_distance += travelled
		if foot_distance > 38:
			foot_distance = 0
			AudioManager.play_at(get_parent(), "red_footsteps", global_position, -15)
	else:
		figure.pause()
	z_index = int(position.y)

func _spawn_charge_afterimage() -> void:
	if get_parent() == null or figure == null or figure.sprite_frames == null:
		return
	var tex := figure.sprite_frames.get_frame_texture(figure.animation, figure.frame)
	if tex == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = tex
	ghost.flip_h = figure.flip_h
	ghost.scale = figure.scale
	ghost.rotation = figure.rotation
	ghost.global_position = figure.global_position
	ghost.modulate = Color(0.82, 0.14, 0.12, 0.42)
	ghost.z_index = z_index - 1
	get_parent().add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tw.tween_callback(ghost.queue_free)

func _spawn_charge_dust() -> void:
	if get_parent() == null:
		return
	var puff := Polygon2D.new()
	puff.polygon = PackedVector2Array([Vector2(-5, 0), Vector2(0, -3), Vector2(5, 0), Vector2(0, 3)])
	puff.color = Color(0.62, 0.54, 0.48, 0.45)
	puff.global_position = global_position + Vector2(randf_range(-6.0, 6.0), 2.0)
	puff.z_index = z_index - 1
	get_parent().add_child(puff)
	var tw := puff.create_tween()
	tw.tween_property(puff, "position", puff.position + Vector2(-charge_dir.x * 12.0, -5.0), 0.28)
	tw.parallel().tween_property(puff, "scale", Vector2.ONE * 1.9, 0.28)
	tw.parallel().tween_property(puff, "modulate:a", 0.0, 0.28)
	tw.tween_callback(puff.queue_free)

func _nearest_walkable(point: Vector2) -> Vector2i:
	var origin := Vector2i(floori(point.x / 10), floori(point.y / 10))
	var best := Vector2i(-1,-1)
	var distance := INF
	for y in range(-4,5):
		for x in range(-4,5):
			var cell := origin + Vector2i(x,y)
			if not grid.region.has_point(cell) or grid.is_point_solid(cell):
				continue
			var candidate := grid.get_point_position(cell).distance_squared_to(point)
			if candidate < distance:
				distance = candidate
				best = cell
	return best
