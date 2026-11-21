extends CharacterBody2D
class_name PlayerController

const DIRECTIONS := {"move_left": Vector2.LEFT, "move_right": Vector2.RIGHT, "move_up": Vector2.UP, "move_down": Vector2.DOWN}
const SHEET = preload("res://assets/characters/dawen_flashlight_025.png")
@export var appearance: String = "flashlight"
@export var visual_size_multiplier: float = 1.0
var allow_flashlight: bool = true
var allow_phone_defense := true
var phone_defense: Node2D
var held: Array[String] = []
var look_dir := Vector2.RIGHT
var movement_dir := Vector2.ZERO
var crouching: bool = false
var hidden_in_wardrobe: bool = false
var flashlight_on: bool = true
var sprint_locked: bool = false
var recovery_delay: float = 0.0
var was_sprinting: bool = false
var foot_distance: float = 0.0
var controls_enabled: bool = true
var aim_override: bool = false
var facing: int = 2
var walk_phase: float = 0.0
var animation_layout: Dictionary
var sprite_scale: float
var ground_shadow: Polygon2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var pivot: Node2D = $FlashlightPivot
@onready var lamp: PointLight2D = $FlashlightPivot/PointLight2D

func _ready() -> void:
	if visual_size_multiplier != 1.0:
		$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
		$CollisionShape2D.shape.radius *= 1.2
	_build_ground_shadow()
	set_appearance(appearance)
	phone_defense = preload("res://core/components/phone_defense.gd").new()
	phone_defense.name = "PhoneDefense"
	add_child(phone_defense)

func _build_ground_shadow() -> void:
	ground_shadow = Polygon2D.new()
	ground_shadow.name = "GroundFootShadow"
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a) * 11.0, sin(a) * 4.5))
	ground_shadow.polygon = pts
	ground_shadow.color = Color(0.0, 0.0, 0.0, 0.34)
	ground_shadow.position = Vector2(0, 2)
	ground_shadow.z_index = -1
	add_child(ground_shadow)
	move_child(ground_shadow, 0)

func set_appearance(next_appearance: String) -> void:
	appearance = next_appearance
	var active_sheet: Texture2D = SHEET
	if appearance == "unarmed":
		active_sheet = preload("res://assets/characters/dawen_walk_004_source.png")
		animation_layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/dawen_walk_004_layout.json"))
		allow_flashlight = false
		flashlight_on = false
		$NearLight.enabled = false
	elif appearance == "jiamin":
		active_sheet = preload("res://assets/characters/jiamin_walk_061.png")
		animation_layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/jiamin_walk_061_layout.json"))
		allow_flashlight = false
		flashlight_on = false
		$NearLight.enabled = false
	elif appearance == "ah_hao":
		active_sheet = preload("res://assets/characters/ahhao_walk_043.png")
		animation_layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/ahhao_walk_043_layout.json"))
		allow_flashlight = true
		flashlight_on = GameState.flashlight_battery > 0.0
		$NearLight.enabled = true
	else:
		animation_layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/dawen_flashlight_005_layout.json"))
		allow_flashlight = true
		flashlight_on = GameState.flashlight_battery > 0.0
		$NearLight.enabled = true
	sprite_scale = float(animation_layout["scale"]) * visual_size_multiplier
	sprite.position = Vector2.ZERO
	sprite.scale = Vector2.ONE * sprite_scale
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row in range(8):
		var animation := str(row)
		frames.add_animation(animation)
		frames.set_animation_speed(animation, 8.0)
		for column in range(6):
			var texture := AtlasTexture.new()
			texture.atlas = active_sheet
			var region = animation_layout["frames"][row][column]["region"]
			texture.region = Rect2(region[0], region[1], region[2], region[3])
			frames.add_frame(animation, texture)
	sprite.sprite_frames = frames
	facing = posmod(roundi(look_dir.angle() / (PI / 4.0)), 8)
	sprite.animation = str(facing)
	_sync_pose_landmarks()
	lamp.enabled = flashlight_on and allow_flashlight and not hidden_in_wardrobe
	if is_instance_valid(phone_defense):
		phone_defense.prepare_chapter()

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or (event is InputEventKey and event.echo):
		return
	for action in DIRECTIONS:
		if event.is_action_pressed(action):
			held.erase(action)
			held.append(action)
		elif event.is_action_released(action):
			held.erase(action)
	if event.is_action_pressed("crouch") and not hidden_in_wardrobe:
		crouching = not crouching
	if event.is_action_pressed("flashlight") and allow_flashlight and not hidden_in_wardrobe:
		if GameState.flashlight_battery > 0.0:
			flashlight_on = not flashlight_on
		else:
			EventBus.flashlight_feedback.emit("手电没电了。找备用电池，或返回安全区接电。")
		AudioManager.play_effect("click")

func resolve_movement() -> Vector2:
	var direction := Vector2(Input.get_action_strength("move_right") - Input.get_action_strength("move_left"), Input.get_action_strength("move_down") - Input.get_action_strength("move_up"))
	return direction.normalized() if direction.length_squared() > 1.0 else direction

func _physics_process(delta: float) -> void:
	if not controls_enabled:
		velocity = Vector2.ZERO
		return
	if not aim_override and not hidden_in_wardrobe:
		var aim := get_global_mouse_position() - (global_position + Vector2(0, -24 * visual_size_multiplier))
		if aim.length() > 30.0:
			look_dir = Vector2.from_angle(lerp_angle(look_dir.angle(), aim.angle(), 1.0 - exp(-GameState.RULES.aim_response * delta)))
	pivot.rotation = look_dir.angle()
	movement_dir = resolve_movement() if not hidden_in_wardrobe else Vector2.ZERO
	var rules = GameState.RULES
	if sprint_locked and GameState.stamina >= 20.0:
		sprint_locked = false
	var sprinting: bool = movement_dir != Vector2.ZERO and not crouching and not hidden_in_wardrobe and appearance != "jiamin" and Input.is_action_pressed("sprint") and not sprint_locked and GameState.stamina >= 5.0
	# Once running, it continues below the starting threshold until exhausted.
	if was_sprinting and movement_dir != Vector2.ZERO and Input.is_action_pressed("sprint") and not crouching and not hidden_in_wardrobe and appearance != "jiamin" and not sprint_locked:
		sprinting = true
	var speed: float = rules.crouch_speed if crouching else rules.walk_speed
	if appearance == "jiamin":
		speed = rules.crouch_speed
	if sprinting:
		GameState.stamina = maxf(0.0, GameState.stamina - rules.sprint_cost * delta)
		recovery_delay = rules.stamina_delay
		speed = rules.sprint_speed
		if GameState.stamina <= 0.0:
			sprint_locked = true
			speed = rules.walk_speed
	else:
		recovery_delay = maxf(0.0, recovery_delay - delta)
		if recovery_delay == 0.0:
			GameState.stamina = minf(100.0, GameState.stamina + rules.stamina_recovery * delta)
	was_sprinting = sprinting and not sprint_locked
	var response: float = rules.acceleration if movement_dir != Vector2.ZERO else rules.deceleration
	velocity = velocity.move_toward(movement_dir * speed, response * delta)
	var before := position
	move_and_slide()
	var travelled := position.distance_to(before)
	foot_distance += travelled
	var stride: float = rules.crouch_stride if crouching else (rules.sprint_stride if sprinting else rules.walk_stride)
	if foot_distance >= stride:
		foot_distance = fmod(foot_distance, stride)
		EventBus.noise_emitted.emit(global_position, 16.0 if crouching else (140.0 if sprinting else 48.0), "footstep")
		AudioManager.play_footstep(crouching, sprinting)
		_spawn_step_particle(sprinting)
	if flashlight_on and not hidden_in_wardrobe:
		GameState.flashlight_battery = maxf(0.0, GameState.flashlight_battery - rules.flashlight_cost * delta)
		if GameState.flashlight_battery == 0.0:
			flashlight_on = false
			EventBus.flashlight_feedback.emit("手电电量耗尽。找备用电池，或返回安全区接电。")
	lamp.enabled = flashlight_on and not hidden_in_wardrobe
	if lamp.enabled:
		var breath := sin(float(Time.get_ticks_msec()) * 0.0045) * 0.018
		pivot.rotation = look_dir.angle() + breath
	# Eight distinct poses with a small angular hysteresis at sector boundaries.
	var desired: int = posmod(roundi(look_dir.angle() / (PI / 4.0)), 8)
	var sector_angle: float = facing * PI / 4.0
	if absf(angle_difference(sector_angle, look_dir.angle())) > PI / 8.0 + 0.14:
		facing = desired
	sprite.animation = str(facing)
	if travelled > 0.05:
		walk_phase = fmod(walk_phase + travelled / (stride * 2.0) * 6.0, 6.0)
		sprite.frame = int(walk_phase)
	else:
		sprite.frame = 0
	_sync_pose_landmarks()
	if is_instance_valid(ground_shadow):
		var pulse := 1.0 - absf(sin(walk_phase * PI / 3.0)) * 0.12 if travelled > 0.05 else 1.0
		ground_shadow.scale = Vector2(pulse, pulse) * (visual_size_multiplier * 0.65)
		ground_shadow.visible = not hidden_in_wardrobe
	sprite.visible = not hidden_in_wardrobe
	z_index = int(position.y)

func _spawn_step_particle(is_sprinting: bool) -> void:
	if not is_inside_tree() or get_parent() == null:
		return
	var room := GameState.current_room_id
	var fx := Node2D.new()
	fx.position = position + Vector2(randf_range(-4, 4), 2)
	fx.z_index = max(0, int(position.y) - 1)
	get_parent().add_child(fx)
	if room.begins_with("ch5_coastal") or room in ["ch2_bunker_descent", "ch2_bunker_hall", "ch2_bunker_ammo", "ch2_bunker_shaft"]:
		var ring := Line2D.new()
		var pts := PackedVector2Array()
		for i in range(17):
			var a := TAU * float(i) / 16.0
			pts.append(Vector2(cos(a) * 5.0, sin(a) * 2.4))
		ring.points = pts
		ring.width = 1.1
		ring.default_color = Color(0.68, 0.82, 0.84, 0.45)
		fx.add_child(ring)
		var tw := fx.create_tween()
		tw.tween_property(ring, "scale", Vector2(2.4, 2.4), 0.34)
		tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.34)
		tw.tween_callback(fx.queue_free)
	elif is_sprinting or room == "ch5_hacsa_beach":
		for i in range(3):
			var dot := ColorRect.new()
			dot.size = Vector2(2, 2)
			dot.color = Color(0.28, 0.26, 0.22, 0.55) if room == "ch5_hacsa_beach" else Color(0.72, 0.68, 0.58, 0.42)
			dot.position = Vector2(randf_range(-5, 5), randf_range(-2, 2))
			fx.add_child(dot)
		var tw := fx.create_tween()
		tw.tween_property(fx, "position:y", fx.position.y - 6.0, 0.26)
		tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.26)
		tw.tween_callback(fx.queue_free)
	else:
		fx.queue_free()

func _sync_pose_landmarks() -> void:
	# Resizing/changing a pose must also update the held torch immediately,
	# including when a dialogue pauses before the first physics frame.
	var metadata = animation_layout["frames"][facing][sprite.frame]
	var region = metadata["region"]
	var anchor = metadata["anchor"]
	sprite.offset = Vector2(float(region[2]) / 2.0 - float(anchor[0]), float(region[3]) / 2.0 - float(anchor[1]))
	sprite.scale = Vector2(sprite_scale, sprite_scale * (0.85 if crouching else 1.0))
	# The torch is painted into the same sprite, not overlaid as a separate prop.
	# Its lens landmark follows the current facing, animation cell and crouch.
	if metadata.has("torch_lens"):
		var lens = metadata["torch_lens"]
		pivot.position = Vector2((float(lens[0])-float(anchor[0]))*sprite_scale,
			(float(lens[1])-float(anchor[1]))*sprite_scale*(0.85 if crouching else 1.0))

func clear_motion() -> void:
	held.clear()
	velocity = Vector2.ZERO
	movement_dir = Vector2.ZERO
	was_sprinting = false

func get_flashlight_origin() -> Vector2:
	return lamp.global_position

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		clear_motion()
