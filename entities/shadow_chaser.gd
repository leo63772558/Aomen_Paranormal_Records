extends CharacterBody2D

signal caught
var target: CharacterBody2D
var active := true
var speed := 66.0
var attack_animation_range := 0.0
var step_elapsed := 0.0
var flash_receiver: PhoneFlashReceiver
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
	ghost_trail.name = "ShadowAfterimage"
	ghost_trail.position = Vector2(0, -50)
	ghost_trail.modulate = Color(0.68, 0.12, 0.14, 0.24)
	add_child(ghost_trail)

	var figure := AnimatedSprite2D.new()
	figure.name = "Figure"
	var frames := SpriteFrames.new()
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 5.2)
	var sheet: Texture2D = load("res://assets/characters/wardrobe_stalker_v5.png")
	var cw := sheet.get_width() * 0.5
	var ch := sheet.get_height() * 0.5
	for row in range(2):
		for col in range(2):
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(col * cw, row * ch, cw, ch)
			frame.filter_clip = true
			frames.add_frame("walk", frame)
	figure.sprite_frames = frames
	figure.position = Vector2(0, -50)
	var spr_scale := Vector2.ONE * (102.0 / ch)
	figure.scale = spr_scale
	ghost_trail.scale = spr_scale
	add_child(figure)
	figure.play("walk")
	var sound := AudioStreamPlayer.new()
	sound.name = "Steps"
	sound.bus = "SFX"
	sound.volume_db = -8
	sound.stream = load("res://assets/audio/recorded/shadow_step.ogg")
	add_child(sound)
	# Default shadow stalker stays eerily SILENT; specific speaking bosses (Butcher/Concrete Wraith) attach their own GhostTaunt!

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(target):
		velocity = Vector2.ZERO
		$Figure.pause()
		return
	if flash_receiver.is_stunned():
		velocity = Vector2.ZERO
		$Figure.pause()
		return
	var focus := flash_receiver.focus_after_flash(target)
	var direction := global_position.direction_to(focus) if global_position.distance_to(focus) > 3.0 else Vector2.ZERO
	var animation := "attack" if attack_animation_range > 0.0 and global_position.distance_to(target.global_position) < attack_animation_range else "walk"
	$Figure.play(animation)
	velocity = direction * speed
	move_and_slide()
	$Figure.flip_h = direction.x > 0
	if not GameState.reduced_flash:
		$Figure.position = Vector2(randf_range(-1.4, 1.4), -47 + randf_range(-0.9, 0.9))
		ghost_trail.texture = $Figure.sprite_frames.get_frame_texture(animation, $Figure.frame)
		ghost_trail.flip_h = $Figure.flip_h
		ghost_trail.position = -direction * 8.0 + Vector2(0, -47)
		ghost_trail.visible = true
	else:
		$Figure.position = Vector2(0, -47)
		ghost_trail.visible = false
	z_index = int(position.y)
	step_elapsed += delta
	if step_elapsed >= 0.62:
		step_elapsed = 0
		if DisplayServer.get_name() != "headless" and "Dummy" not in OS.get_cmdline_args():
			$Steps.play()
	if flash_receiver.may_catch(target) and global_position.distance_to(target.global_position) < 18:
		active = false
		velocity = Vector2.ZERO
		$Figure.pause()
		caught.emit()
