extends CharacterBody2D
class_name PlayerController

const DIRECTIONS := {"move_left": Vector2.LEFT, "move_right": Vector2.RIGHT, "move_up": Vector2.UP, "move_down": Vector2.DOWN}
const SHEET = preload("res://assets/characters/dawen_flashlight_025.png")
# Active stride frames only (skip column 0 rigid feet-together idle pose during walking!)
const STRIDE_SEQUENCE := [1, 2, 3, 4, 5, 4, 3, 2]
static var _wet_ripple_shader: Shader = null

@export var appearance: String = "flashlight"
@export var visual_size_multiplier: float = 1.0
var allow_flashlight: bool = true
var allow_phone_defense := true
var phone_defense: Node2D
var held: Array[String] = []
var look_dir := Vector2.RIGHT
var body_angle: float = 0.0
var movement_dir := Vector2.ZERO
var crouching: bool = false
var crouch_blend: float = 0.0
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
var move_blend: float = 0.0
var step_impact: float = 0.0
var turn_rate_smooth: float = 0.0
var animation_layout: Dictionary
var sprite_scale: float
var dust_motes: CPUParticles2D
var contact_shadow: Polygon2D
var lean_angle: float = 0.0
var idle_clock: float = 0.0
var smooth_offset := Vector2.ZERO
var offset_initialized: bool = false
var mouse_aim_position := Vector2.ZERO
var has_mouse_aim := false
var touch_aim_hold_time: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var pivot: Node2D = $FlashlightPivot
@onready var lamp: PointLight2D = $FlashlightPivot/PointLight2D

func _ready() -> void:
	GameState.active_player = self
	if visual_size_multiplier != 1.0:
		$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
		$CollisionShape2D.shape.radius *= 1.2
	_build_contact_shadow()
	_build_tyndall_flashlight()
	body_angle = look_dir.angle()
	set_appearance(appearance)
	phone_defense = preload("res://core/components/phone_defense.gd").new()
	phone_defense.name = "PhoneDefense"
	add_child(phone_defense)

func _build_contact_shadow() -> void:
	# Subtle grounded contact ellipse directly under boots so stride weight & elevation read naturally
	contact_shadow = Polygon2D.new()
	contact_shadow.name = "GroundedContactShadow"
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a) * 10.5, sin(a) * 4.2))
	contact_shadow.polygon = pts
	contact_shadow.position = Vector2(0, 1.5)
	contact_shadow.color = Color(0.02, 0.025, 0.02, 0.30)
	contact_shadow.z_index = -1
	add_child(contact_shadow)
	move_child(contact_shadow, 0)

func _build_tyndall_flashlight() -> void:
	dust_motes = CPUParticles2D.new()
	dust_motes.name = "FlashlightDustMotes"
	dust_motes.position = Vector2(76, 0)
	dust_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust_motes.emission_rect_extents = Vector2(54, 18)
	dust_motes.amount = 14
	dust_motes.lifetime = 2.4
	dust_motes.preprocess = 1.0
	dust_motes.direction = Vector2(0.2, -1.0)
	dust_motes.spread = 110.0
	dust_motes.gravity = Vector2(0, -3.5)
	dust_motes.initial_velocity_min = 3.0
	dust_motes.initial_velocity_max = 9.0
	dust_motes.scale_amount_min = 0.9
	dust_motes.scale_amount_max = 1.6
	dust_motes.color = Color(0.96, 0.93, 0.80, 0.28)
	dust_motes.z_index = 3
	pivot.add_child(dust_motes)

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
	offset_initialized = false
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row in range(8):
		var animation := str(row)
		frames.add_animation(animation)
		frames.set_animation_speed(animation, 10.0)
		for column in range(6):
			var texture := AtlasTexture.new()
			texture.atlas = active_sheet
			var region = animation_layout["frames"][row][column]["region"]
			texture.region = Rect2(region[0], region[1], region[2], region[3])
			frames.add_frame(animation, texture)
	sprite.sprite_frames = frames
	body_angle = look_dir.angle()
	facing = posmod(roundi(body_angle / (PI / 4.0)), 8)
	sprite.animation = str(facing)
	_sync_pose_landmarks(1.0)
	lamp.enabled = flashlight_on and allow_flashlight and not hidden_in_wardrobe
	if is_instance_valid(phone_defense):
		phone_defense.prepare_chapter()

func _exit_tree() -> void:
	if GameState.active_player == self:
		GameState.active_player = null

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or (event is InputEventKey and event.echo):
		return
	if event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		mouse_aim_position = event.position
		has_mouse_aim = true
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
	var direction := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if direction.length_squared() <= 0.001 and GameState.touch_move_vector.length_squared() > 0.001:
		direction = GameState.touch_move_vector
	return direction.normalized() if direction.length_squared() > 1.0 else direction

func _physics_process(delta: float) -> void:
	if not controls_enabled:
		velocity = Vector2.ZERO
		return
	movement_dir = resolve_movement() if not hidden_in_wardrobe else Vector2.ZERO
	var rules = GameState.RULES
	if sprint_locked and GameState.stamina >= 20.0:
		sprint_locked = false
	var sprint_input: bool = Input.is_action_pressed("sprint") or GameState.touch_sprint_held
	var sprinting: bool = movement_dir != Vector2.ZERO and not crouching and not hidden_in_wardrobe and appearance != "jiamin" and sprint_input and not sprint_locked and GameState.stamina >= 5.0
	if was_sprinting and movement_dir != Vector2.ZERO and sprint_input and not crouching and not hidden_in_wardrobe and appearance != "jiamin" and not sprint_locked:
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

	# Silky 360° continuous velocity steering (smooth angular turn arc + smooth acceleration/deceleration)
	var target_vel := movement_dir * speed
	if movement_dir != Vector2.ZERO:
		if velocity.length_squared() > 25.0:
			var cur_ang := velocity.angle()
			var tgt_ang := movement_dir.angle()
			var smooth_ang := lerp_angle(cur_ang, tgt_ang, 1.0 - exp(-16.0 * delta))
			var target_spd := lerpf(velocity.length(), speed, 1.0 - exp(-14.0 * delta))
			velocity = Vector2.from_angle(smooth_ang) * target_spd
		else:
			velocity = velocity.lerp(target_vel, 1.0 - exp(-14.0 * delta))
		if velocity.distance_to(target_vel) < 1.5:
			velocity = target_vel
	else:
		velocity = velocity.move_toward(Vector2.ZERO, rules.deceleration * delta)

	var before := position
	move_and_slide()
	var travelled := position.distance_to(before)
	var actual_speed := travelled / maxf(delta, 0.0001)
	var is_moving := travelled > 0.06 and velocity.length_squared() > 12.0

	# A stationary cursor keeps controlling the actor while walking or retreating.
	if not aim_override and not hidden_in_wardrobe:
		if GameState.touch_aim_active and GameState.touch_aim_vector.length_squared() > 0.04:
			look_dir = Vector2.from_angle(lerp_angle(look_dir.angle(), GameState.touch_aim_vector.angle(), 1.0 - exp(-22.0 * delta)))
			touch_aim_hold_time = 2.4
			has_mouse_aim = false
		elif touch_aim_hold_time > 0.0:
			touch_aim_hold_time = maxf(0.0, touch_aim_hold_time - delta)
		elif GameState.touch_mode_active and movement_dir.length_squared() > 0.04:
			look_dir = Vector2.from_angle(lerp_angle(look_dir.angle(), movement_dir.angle(), 1.0 - exp(-14.0 * delta)))
		elif has_mouse_aim:
			var target := get_canvas_transform().affine_inverse() * mouse_aim_position
			var aim := target - (global_position + Vector2(0, -24 * visual_size_multiplier))
			if aim.length_squared() > 14.0 * 14.0:
				look_dir = Vector2.from_angle(lerp_angle(look_dir.angle(), aim.angle(), 1.0 - exp(-20.0 * delta)))

	var prev_body_angle := body_angle
	body_angle = look_dir.angle()
	pivot.rotation = body_angle
	foot_distance += travelled
	var stride: float = rules.crouch_stride if crouching else (rules.sprint_stride if sprinting else rules.walk_stride)
	step_impact = maxf(0.0, step_impact - delta * 6.5)
	if foot_distance >= stride:
		foot_distance = fmod(foot_distance, stride)
		step_impact = 1.0
		EventBus.noise_emitted.emit(global_position, 16.0 if crouching else (140.0 if sprinting else 48.0), "footstep")
		AudioManager.play_footstep(crouching, sprinting)
		_spawn_step_particle(sprinting)

	if flashlight_on and not hidden_in_wardrobe:
		GameState.flashlight_battery = maxf(0.0, GameState.flashlight_battery - rules.flashlight_cost * delta)
		if GameState.flashlight_battery == 0.0:
			flashlight_on = false
			EventBus.flashlight_feedback.emit("手电电量耗尽。找备用电池，或返回安全区接电。")
	lamp.enabled = flashlight_on and not hidden_in_wardrobe
	if is_instance_valid(dust_motes):
		dust_motes.emitting = lamp.enabled
	if lamp.enabled:
		var breath := sin(float(Time.get_ticks_msec()) * 0.0042) * 0.012
		var stride_sway := sin(walk_phase * PI * 0.5) * (0.024 if sprinting else 0.011) * move_blend
		pivot.rotation = body_angle + breath + stride_sway

	var raw_turn_rate := clampf(angle_difference(prev_body_angle, body_angle) / maxf(delta, 0.001), -8.0, 8.0)
	turn_rate_smooth = lerpf(turn_rate_smooth, raw_turn_rate, 1.0 - exp(-14.0 * delta))

	var desired_sector: int = posmod(roundi(body_angle / (PI / 4.0)), 8)
	var sector_angle: float = facing * PI / 4.0
	var ang_diff := angle_difference(sector_angle, body_angle)
	if aim_override or absf(ang_diff) > PI / 8.0 + 0.015:
		facing = desired_sector
		sector_angle = facing * PI / 4.0
		ang_diff = angle_difference(sector_angle, body_angle)
	sprite.animation = str(facing)

	# Smooth blend between walking kinematics and calm breathing idle
	var target_move_blend := clampf(actual_speed / maxf(rules.crouch_speed, 1.0), 0.0, 1.0) if is_moving else 0.0
	move_blend = lerpf(move_blend, target_move_blend, 1.0 - exp(-16.0 * delta))
	crouch_blend = lerpf(crouch_blend, 1.0 if crouching else 0.0, 1.0 - exp(-14.0 * delta))

	# Crisp upright 2D RPG stride kinematics — ZERO sideways tilting/wobbling!
	var bounce_y := 0.0
	if move_blend > 0.08:
		idle_clock = 0.0
		# Advance cleanly through active stride frames synced to footsteps
		var active_seq := [1, 2, 3, 4, 5] if appearance == "ah_hao" else STRIDE_SEQUENCE
		var step_advance := maxf(travelled / maxf(stride * 0.42, 7.0), delta * (10.5 if sprinting else 8.2) * move_blend)
		walk_phase = fmod(walk_phase + step_advance, float(active_seq.size()))
		sprite.frame = active_seq[int(walk_phase) % active_seq.size()]
		var gait_lift := absf(sin(walk_phase * PI * 0.5))
		var amp := (1.5 if sprinting else (0.7 if crouching else 1.0)) * move_blend
		bounce_y = -gait_lift * amp
		lean_angle = 0.0
		sprite.rotation = 0.0
		sprite.position.y = lerpf(sprite.position.y, bounce_y, 1.0 - exp(-22.0 * delta))
	else:
		idle_clock += delta
		sprite.frame = 0
		var breath_wave := sin(idle_clock * 2.0) * 0.35
		lean_angle = 0.0
		sprite.rotation = 0.0
		sprite.position.y = lerpf(sprite.position.y, -0.25 - breath_wave, 1.0 - exp(-8.0 * delta))

	_sync_pose_landmarks(1.0 - exp(-24.0 * delta), 0.0)
	if is_instance_valid(contact_shadow):
		contact_shadow.visible = not hidden_in_wardrobe
		var lift_factor := clampf(1.0 + bounce_y * 0.04, 0.82, 1.05)
		contact_shadow.scale = Vector2(lift_factor, lift_factor) * (visual_size_multiplier / 1.65)
		contact_shadow.modulate.a = 0.28 * lift_factor
	sprite.visible = not hidden_in_wardrobe
	z_index = int(position.y)

func _is_in_wet_water_zone() -> bool:
	var room := GameState.current_room_id
	if room == "ch5_coastal_landing":
		return position.y >= 240.0
	if room == "ch5_coastal_chamber":
		# Only wet near the lower flooded sluice pool & drainage apron, NOT dry upper paving
		return position.y >= 265.0
	if room == "ch5_coastal_silt_tunnel":
		return true
	if room == "ch5_coastal_pressure_gallery":
		# Wet along lower drainage channels & wet floor near sluice arch
		return position.y >= 340.0 or (not bool(GameState.opening_flags.get("coastal_pressure_bleeder_open", false)) and position.y >= 295.0)
	if room == "ch5_hacsa_beach":
		return position.y >= 540.0
	return false

func _spawn_step_particle(is_sprinting: bool) -> void:
	if not is_inside_tree() or get_parent() == null:
		return
	var room := GameState.current_room_id
	var fx := Node2D.new()
	fx.position = position + Vector2(randf_range(-3.5, 3.5), 2.5)
	fx.z_index = max(0, int(position.y) - 1)
	get_parent().add_child(fx)
	if _is_in_wet_water_zone():
		# Genuine dark-water concentric GLSL meniscus ripple + wet boot-print sheen matching painted sewer tiles
		var ripple_quad := Polygon2D.new()
		var hw := 22.0 if is_sprinting else 17.0
		var hh := 10.5 if is_sprinting else 8.2
		ripple_quad.polygon = PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
		ripple_quad.uv = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		if _wet_ripple_shader == null:
			_wet_ripple_shader = Shader.new()
			_wet_ripple_shader.code = """shader_type canvas_item;
uniform float progress = 0.0;
varying vec2 v_uv;
void vertex() {
	v_uv = UV;
}
void fragment() {
	vec2 p = (v_uv - vec2(0.5)) * 2.0;
	float r = length(p);
	if (r > 1.0) { discard; }
	float p1 = clamp(progress, 0.0, 1.0);
	float p2 = clamp((progress - 0.16) / 0.84, 0.0, 1.0);
	float fade = pow(1.0 - p1, 1.35);
	// Primary outer crest + refractive dark shadow trough right behind it
	float r1 = mix(0.14, 0.94, 1.0 - pow(1.0 - p1, 2.0));
	float crest1 = exp(-pow((r - r1) / 0.068, 2.0));
	float trough1 = exp(-pow((r - (r1 - 0.085)) / 0.075, 2.0));
	// Secondary inner harmonic echo ring
	float r2 = mix(0.08, 0.72, 1.0 - pow(1.0 - p2, 1.8));
	float crest2 = exp(-pow((r - r2) / 0.055, 2.0)) * step(0.16, progress) * 0.72;
	// Subtle directional specular highlight from overhead corridor lamps (brighter on upper-left arc)
	float spec = 0.62 + 0.38 * clamp(dot(normalize(p + vec2(0.0001)), vec2(-0.45, -0.89)), -0.3, 1.0);
	// Dark wet puddle depression at center that settles quickly
	float wet_core = exp(-r * r * 6.5) * (1.0 - p1 * 0.75) * 0.42;
	vec3 water_hi = vec3(0.58, 0.68, 0.66) * spec;
	vec3 water_lo = vec3(0.04, 0.08, 0.08);
	float hi_amt = clamp((crest1 + crest2) * 0.72, 0.0, 0.85);
	float lo_amt = clamp(trough1 * 0.55 + wet_core, 0.0, 0.65);
	vec3 col = mix(water_lo, water_hi, hi_amt / max(hi_amt + lo_amt, 0.001));
	float alpha = clamp((hi_amt * 0.58 + lo_amt * 0.44) * fade * smoothstep(1.0, 0.86, r), 0.0, 0.68);
	COLOR = vec4(col, alpha);
}"""
		var rmat := ShaderMaterial.new()
		rmat.shader = _wet_ripple_shader
		rmat.set_shader_parameter("progress", 0.0)
		ripple_quad.material = rmat
		fx.add_child(ripple_quad)
		var dur := 0.58 if is_sprinting else 0.72
		var rtw := fx.create_tween()
		rtw.tween_property(rmat, "shader_parameter/progress", 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		# Delicate realistic water splash mist arcs when wading/running
		var drop_count := 5 if is_sprinting else 3
		for _d in range(drop_count):
			var drop := Polygon2D.new()
			drop.polygon = PackedVector2Array([Vector2(-0.9, -0.7), Vector2(0.9, -0.5), Vector2(0.7, 0.8), Vector2(-0.8, 0.6)])
			drop.color = Color(0.64, 0.74, 0.73, 0.46)
			drop.position = Vector2(randf_range(-4.5, 4.5), randf_range(-1.5, 1.5))
			fx.add_child(drop)
			var dtw := fx.create_tween()
			var dx := randf_range(-10.5, 10.5) * (1.35 if is_sprinting else 0.82)
			var dy := randf_range(-9.0, -4.5) * (1.3 if is_sprinting else 0.85)
			dtw.tween_property(drop, "position", drop.position + Vector2(dx, dy), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			dtw.tween_property(drop, "position:y", drop.position.y + 2.5, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			dtw.parallel().tween_property(drop, "modulate:a", 0.0, 0.25)
		rtw.tween_callback(fx.queue_free)
	elif is_sprinting or room == "ch5_hacsa_beach":
		for _i in range(3):
			var dot := ColorRect.new()
			dot.size = Vector2(2, 2)
			dot.color = Color(0.24, 0.23, 0.20, 0.48) if room == "ch5_hacsa_beach" else Color(0.68, 0.65, 0.56, 0.36)
			dot.position = Vector2(randf_range(-5, 5), randf_range(-2, 2))
			fx.add_child(dot)
		var tw := fx.create_tween()
		tw.tween_property(fx, "position:y", fx.position.y - 5.5, 0.26)
		tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.26)
		tw.tween_callback(fx.queue_free)
	else:
		fx.queue_free()

func _sync_pose_landmarks(offset_lerp := 1.0, squash := 0.0) -> void:
	var metadata = animation_layout["frames"][facing][sprite.frame]
	var region = metadata["region"]
	var anchor = metadata["anchor"]
	var target_offset := Vector2(float(region[2]) / 2.0 - float(anchor[0]), float(region[3]) / 2.0 - float(anchor[1]))
	if not offset_initialized or offset_lerp >= 0.99:
		smooth_offset = target_offset
		offset_initialized = true
	else:
		# Damp erratic horizontal anchor.x jumps between frames so feet stay smoothly planted
		smooth_offset.x = lerpf(smooth_offset.x, target_offset.x, offset_lerp * 0.55)
		smooth_offset.y = lerpf(smooth_offset.y, target_offset.y, offset_lerp)
	sprite.offset = smooth_offset
	var crouch_y := lerpf(1.0, 0.85, crouch_blend)
	var sx := sprite_scale * (1.0 + squash * 0.65)
	var sy := sprite_scale * crouch_y * (1.0 - squash)
	sprite.scale = Vector2(sx, sy)
	if metadata.has("torch_lens"):
		var lens = metadata["torch_lens"]
		var lens_on_sprite := Vector2(float(lens[0]), float(lens[1])) - Vector2(float(region[2]), float(region[3])) * 0.5
		pivot.position = sprite.position + (lens_on_sprite + sprite.offset) * sprite.scale

func clear_motion() -> void:
	held.clear()
	velocity = Vector2.ZERO
	movement_dir = Vector2.ZERO
	was_sprinting = false
	move_blend = 0.0

func get_flashlight_origin() -> Vector2:
	return lamp.global_position

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		clear_motion()
		has_mouse_aim = false
