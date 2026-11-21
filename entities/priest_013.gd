extends CharacterBody2D

signal caught
signal freeze_changed(frozen: bool)
var target: PlayerController
var active := true
var frozen := false
var lit_time := 0.0
var speed := 112.0
var step_elapsed := 0.0
var flash_receiver: PhoneFlashReceiver
var bone_shader_mat: ShaderMaterial
var ghost_trail: Sprite2D

func _ready() -> void:
	flash_receiver = PhoneFlashReceiver.new()
	add_child(flash_receiver)
	collision_layer = 4
	collision_mask = 1
	var shape := CircleShape2D.new()
	shape.radius = 8
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

	ghost_trail = Sprite2D.new()
	ghost_trail.name = "GhostAfterimage"
	ghost_trail.position = Vector2(-6, -48)
	ghost_trail.scale = Vector2.ONE * 0.58
	ghost_trail.modulate = Color(0.55, 0.12, 0.12, 0.25)
	add_child(ghost_trail)

	var figure := AnimatedSprite2D.new()
	figure.name = "Figure"
	var frames := SpriteFrames.new()
	var sheet: Texture2D = load("res://assets/characters/priest_walk_013.png")
	for row in range(8):
		frames.add_animation(str(row))
		frames.set_animation_speed(str(row), 6.0)
		for col in range(4):
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(150 + col * 230, int(row * 1339.0 / 8.0), 160, 167)
			frames.add_frame(str(row), frame)
	figure.sprite_frames = frames
	figure.animation = "4"
	figure.frame = 0
	figure.position = Vector2(0, -48)
	figure.scale = Vector2.ONE * 0.58
	# "大三巴黑袍老伯变白骨" — pixel-art X-ray bone-white calcified shader when flashlight hits him!
	var bone_shader := Shader.new()
	bone_shader.code = """shader_type canvas_item;
uniform float reveal : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	// Preserve tattered dark robe folds while calcifying highlights/face/hands into eerie pale bone
	float bone_mask = smoothstep(0.11, 0.44, lum);
	vec3 dark_cloth = vec3(0.08, 0.10, 0.10) + tex.rgb * 0.28;
	vec3 pale_bone = vec3(0.92, 0.89, 0.78);
	vec3 calcified = mix(dark_cloth, pale_bone, bone_mask);
	// Subtle X-ray ribcage/spine glint in the mid-torso under strong flashlight
	vec3 final_rgb = mix(tex.rgb, calcified, reveal);
	COLOR = vec4(final_rgb, tex.a * mix(1.0, 0.94, reveal));
}"""
	bone_shader_mat = ShaderMaterial.new()
	bone_shader_mat.shader = bone_shader
	bone_shader_mat.set_shader_parameter("reveal", 0.0)
	figure.material = bone_shader_mat
	add_child(figure)

	var sound := AudioStreamPlayer.new()
	sound.name = "Steps"
	sound.bus = "SFX"
	sound.volume_db = -8
	sound.stream = load("res://assets/audio/recorded/shadow_step.ogg")
	add_child(sound)

func illuminated() -> bool:
	if not is_instance_valid(target) or not target.flashlight_on or target.hidden_in_wardrobe or not target.lamp.enabled:
		return false
	var torso := global_position + Vector2(0, -45)
	var beam := torso - target.get_flashlight_origin()
	if beam.length() > GameState.RULES.flashlight_range or beam.length() < 0.1:
		return false
	if target.look_dir.dot(beam.normalized()) < cos(deg_to_rad(GameState.RULES.flashlight_angle * 0.5)):
		return false
	var ray := PhysicsRayQueryParameters2D.create(target.global_position, global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(target):
		velocity = Vector2.ZERO
		$Figure.pause()
		return
	if flash_receiver.is_stunned():
		velocity = Vector2.ZERO
		$Figure.pause()
		if bone_shader_mat != null:
			bone_shader_mat.set_shader_parameter("reveal", 1.0)
		return
	var lit := illuminated()
	lit_time = lit_time + delta if lit else 0.0
	var next_frozen := lit
	if next_frozen != frozen:
		frozen = next_frozen
		freeze_changed.emit(frozen)
	if bone_shader_mat != null:
		bone_shader_mat.set_shader_parameter("reveal", 0.92 if frozen else 0.0)
	if frozen:
		velocity = Vector2.ZERO
		$Figure.pause()
		if not GameState.reduced_flash:
			$Figure.position = Vector2(randf_range(-1.2, 1.2), -48 + randf_range(-0.6, 0.6))
		else:
			$Figure.position = Vector2(0, -48)
		ghost_trail.visible = false
		return
	$Figure.modulate = Color.WHITE
	var focus := flash_receiver.focus_after_flash(target)
	var direction := global_position.direction_to(focus) if global_position.distance_to(focus) > 3.0 else Vector2.ZERO
	velocity = direction * speed
	move_and_slide()
	var facing := posmod(roundi(direction.angle() / (PI / 4.0)), 8)
	$Figure.play(str(facing))
	if not GameState.reduced_flash:
		$Figure.position = Vector2(randf_range(-1.1, 1.1), -48)
		ghost_trail.texture = $Figure.sprite_frames.get_frame_texture($Figure.animation, $Figure.frame)
		ghost_trail.position = -direction * 9.0 + Vector2(0, -48)
		ghost_trail.visible = true
	else:
		$Figure.position = Vector2(0, -48)
		ghost_trail.visible = false
	z_index = int(position.y)
	step_elapsed += delta
	if step_elapsed >= 0.7:
		step_elapsed = 0
		if DisplayServer.get_name() != "headless" and "Dummy" not in OS.get_cmdline_args():
			$Steps.play()
	if flash_receiver.may_catch(target) and global_position.distance_to(target.global_position) < 23:
		active = false
		velocity = Vector2.ZERO
		$Figure.pause()
		caught.emit()
