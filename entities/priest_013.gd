extends CharacterBody2D

signal caught
signal freeze_changed(frozen: bool)
var target: PlayerController
var active := true
var frozen := false
var lit_time := 0.0
var speed := 112.0
var step_elapsed := 0.0
var walk_clock := 0.0
var afterimage_timer := 0.0
var freeze_screech_cooldown := 0.0
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
		frames.set_animation_speed(str(row), 10.5)
		for col in [0, 1, 2, 3, 2, 1]:
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(150 + col * 230, int(row * 1339.0 / 8.0), 160, 167)
			frames.add_frame(str(row), frame)
	figure.sprite_frames = frames
	figure.animation = "4"
	figure.frame = 0
	figure.position = Vector2(0, -48)
	figure.scale = Vector2.ONE * 0.58
	# "大三巴黑袍老伯变白骨" — gruesome blood-seeping flesh-stripping bone transformation shader under flashlight!
	var bone_shader := Shader.new()
	bone_shader.code = """shader_type canvas_item;
uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float bone_mask = smoothstep(0.14, 0.48, lum);
	float flesh_crack = smoothstep(0.06, 0.16, lum) * (1.0 - smoothstep(0.24, 0.38, lum));
	// Ribcage/skull horizontal striated horror pattern across upper body when revealed
	float rib_wave = sin(UV.y * 160.0) * 0.5 + 0.5;
	vec3 rotting_robe = vec3(0.06, 0.03, 0.04) + tex.rgb * 0.18;
	vec3 bloody_sinew = vec3(0.46, 0.04, 0.05) * (0.8 + 0.4 * pulse);
	vec3 yellowed_bone = vec3(0.95, 0.90, 0.74) * (0.86 + 0.18 * rib_wave);
	vec3 transformed = mix(rotting_robe, bloody_sinew, flesh_crack * 0.92);
	transformed = mix(transformed, yellowed_bone, bone_mask);
	vec3 final_rgb = mix(tex.rgb, transformed, reveal);
	COLOR = vec4(final_rgb, tex.a * mix(1.0, 0.96, reveal));
}"""
	bone_shader_mat = ShaderMaterial.new()
	bone_shader_mat.shader = bone_shader
	bone_shader_mat.set_shader_parameter("reveal", 0.0)
	bone_shader_mat.set_shader_parameter("pulse", 0.0)
	figure.material = bone_shader_mat
	add_child(figure)
	GhostTaunt.attach(self, PackedStringArray(["别照我……", "你完蛋了……", "来看我的骨头……", "留在地宫里吧……"]), 3.3)

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
	freeze_screech_cooldown = maxf(0.0, freeze_screech_cooldown - delta)
	var next_frozen := lit
	if next_frozen != frozen:
		frozen = next_frozen
		freeze_changed.emit(frozen)
		if frozen and freeze_screech_cooldown <= 0.0:
			freeze_screech_cooldown = 2.0
			AudioManager.play_world_effect("scare_pipe_scrape")
	if bone_shader_mat != null:
		bone_shader_mat.set_shader_parameter("reveal", 0.98 if frozen else 0.0)
		bone_shader_mat.set_shader_parameter("pulse", absf(sin(lit_time * 16.0)) if frozen else 0.0)
	if frozen:
		velocity = Vector2.ZERO
		$Figure.pause()
		if not GameState.reduced_flash:
			$Figure.position = Vector2(randf_range(-2.8, 2.8), -48 + randf_range(-1.6, 1.6))
			$Figure.rotation = randf_range(-0.07, 0.07)
		else:
			$Figure.position = Vector2(0, -48)
			$Figure.rotation = 0.0
		ghost_trail.visible = false
		return
	$Figure.modulate = Color.WHITE
	var focus := flash_receiver.focus_after_flash(target)
	var direction := global_position.direction_to(focus) if global_position.distance_to(focus) > 3.0 else Vector2.ZERO
	velocity = velocity.lerp(direction * speed, 1.0 - exp(-15.0 * delta))
	move_and_slide()
	walk_clock += delta * 6.5
	var facing := posmod(roundi(direction.angle() / (PI / 4.0)), 8)
	$Figure.play(str(facing))
	var bob_y := -48.0 + sin(walk_clock * TAU) * 1.9
	var squash := 0.58 * (1.0 + sin(walk_clock * TAU * 2.0) * 0.032)
	var stretch := 0.58 * (1.0 - sin(walk_clock * TAU * 2.0) * 0.022)
	var sway_rot := clampf(direction.x * 0.065 + sin(walk_clock * TAU) * 0.038, -0.12, 0.12)
	$Figure.rotation = lerpf($Figure.rotation, sway_rot, 1.0 - exp(-16.0 * delta))
	$Figure.scale = Vector2(stretch, squash)
	if not GameState.reduced_flash:
		$Figure.position = Vector2(sin(walk_clock * TAU) * 0.9, bob_y)
		ghost_trail.texture = $Figure.sprite_frames.get_frame_texture($Figure.animation, $Figure.frame)
		ghost_trail.position = -direction * 10.0 + Vector2(0, bob_y)
		ghost_trail.rotation = $Figure.rotation
		ghost_trail.scale = $Figure.scale
		ghost_trail.visible = true
		afterimage_timer -= delta
		if afterimage_timer <= 0.0 and get_parent() != null:
			afterimage_timer = 0.13
			var sp := Sprite2D.new()
			sp.texture = ghost_trail.texture
			sp.scale = $Figure.scale
			sp.rotation = $Figure.rotation
			sp.global_position = $Figure.global_position
			sp.modulate = Color(0.52, 0.16, 0.16, 0.30)
			sp.z_index = z_index - 1
			get_parent().add_child(sp)
			var tw := sp.create_tween()
			tw.tween_property(sp, "modulate:a", 0.0, 0.24)
			tw.tween_callback(sp.queue_free)
	else:
		$Figure.position = Vector2(0, bob_y)
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
