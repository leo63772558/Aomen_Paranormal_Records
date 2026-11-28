extends Node2D
## Silky-smooth assisted-support cutscene walk along a gentle Bezier curve to the open exit arch.

const CAMERA_SHEET := preload("res://assets/characters/rescue_camera_handoff_108.png")
const SUPPORT_SHEET := preload("res://assets/characters/rescue_support_095.png")
const CELL := Vector2(512, 512)
const SCALE := 0.198
const CAMERA_JIAMIN_FOOT := Vector2(190, 490)
const SUPPORT_DAWEN_FOOT := Vector2(132, 490)
const GAIT_CYCLE := [3, 4, 5, 4]
const BEZIER_MID := Vector2(870, 560)

var figure: Sprite2D
var shadow: Polygon2D
var arch_dawn_glow: PointLight2D
var displayed_frame := 0
var use_camera_sheet := true


func _ready() -> void:
	shadow = Polygon2D.new()
	shadow.name = "PairContactShadow"
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a) * 21.0, sin(a) * 6.5))
	shadow.polygon = pts
	shadow.position = Vector2(14, 1)
	shadow.color = Color(0.02, 0.025, 0.02, 0.38)
	shadow.z_index = -1
	add_child(shadow)

	figure = Sprite2D.new()
	figure.centered = false
	figure.light_mask = 2
	figure.scale = Vector2.ONE * SCALE
	add_child(figure)


func set_frame(index: int) -> void:
	displayed_frame = index
	var atlas := AtlasTexture.new()
	atlas.atlas = CAMERA_SHEET if use_camera_sheet else SUPPORT_SHEET
	atlas.region = Rect2(Vector2(index % 3, floori(index / 3.0)) * CELL, CELL)
	figure.texture = atlas


func perform(dawen: PlayerController, jiamin: PlayerController, carry_camera: bool) -> void:
	use_camera_sheet = carry_camera
	var start := jiamin.position
	position = start
	figure.position = -CAMERA_JIAMIN_FOOT * SCALE if carry_camera else -SUPPORT_DAWEN_FOOT * SCALE
	figure.flip_h = not carry_camera
	shadow.position = Vector2(16, 1) if carry_camera else Vector2(-12, 1)
	z_index = int(start.y)
	dawen.sprite.visible = false
	jiamin.sprite.visible = false
	var lamp_was_on := dawen.lamp.enabled
	var near_light: PointLight2D = dawen.get_node("NearLight")
	var near_was_on := near_light.enabled
	dawen.lamp.enabled = false
	near_light.enabled = false

	# Warm exit-arch dawn glow brightening as the pair walks out
	var host := get_parent()
	if is_instance_valid(host):
		arch_dawn_glow = PointLight2D.new()
		arch_dawn_glow.name = "ExitArchDawnGlow"
		arch_dawn_glow.position = Vector2(640, 690)
		arch_dawn_glow.texture = preload("res://assets/lighting/soft_light.png")
		arch_dawn_glow.texture_scale = 0.85
		arch_dawn_glow.color = Color("ffdca2")
		arch_dawn_glow.energy = 0.18
		host.add_child(arch_dawn_glow)

	var destination := Vector2(640, 664)
	var walking := create_tween()
	walking.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	walking.tween_method(_walk_step.bind(dawen, jiamin, start, destination), 0.0, 1.0, 3.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var animation := create_tween()
	animation.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	for _cycle in range(6):
		for idx in range(GAIT_CYCLE.size()):
			var frame: int = GAIT_CYCLE[idx]
			animation.tween_callback(set_frame.bind(frame))
			if idx == 0:
				animation.tween_callback(func(): AudioManager.play_footstep(false, false))
			elif idx == 2:
				animation.tween_callback(func(): AudioManager.play_footstep(true, false))
			animation.tween_interval(0.14)
	await walking.finished
	if is_instance_valid(animation) and animation.is_running():
		animation.kill()
	if is_instance_valid(arch_dawn_glow):
		arch_dawn_glow.queue_free()
	if not is_inside_tree() or not is_instance_valid(dawen) or not is_instance_valid(jiamin):
		return
	if is_instance_valid(dawen.sprite):
		dawen.sprite.visible = true
	if is_instance_valid(jiamin.sprite):
		jiamin.sprite.visible = true
	dawen.lamp.enabled = lamp_was_on
	near_light.enabled = near_was_on
	queue_free()


func _walk_step(progress: float, dawen: PlayerController, jiamin: PlayerController, start: Vector2, destination: Vector2) -> void:
	var one_minus := 1.0 - progress
	var next_position := one_minus * one_minus * start + 2.0 * one_minus * progress * BEZIER_MID + progress * progress * destination
	var delta := next_position - jiamin.position
	jiamin.position = next_position
	dawen.position += delta
	position = jiamin.position
	z_index = int(position.y)
	jiamin.look_dir = delta.normalized() if delta.length_squared() > 0.001 else Vector2.LEFT
	jiamin.facing = posmod(roundi(jiamin.look_dir.angle() / (PI / 4.0)), 8)
	dawen.look_dir = jiamin.look_dir
	dawen.facing = jiamin.facing
	dawen._sync_pose_landmarks()
	jiamin._sync_pose_landmarks()

	var stride_phase := progress * TAU * 4.5
	var vertical_bob := -absf(sin(stride_phase)) * 2.8
	var sway := sin(stride_phase) * 0.018
	var weight_scale := 1.0 + sin(stride_phase * 2.0) * 0.012
	var base_foot := -CAMERA_JIAMIN_FOOT * SCALE if use_camera_sheet else -SUPPORT_DAWEN_FOOT * SCALE
	if is_instance_valid(figure):
		figure.position = base_foot + Vector2(0.0, vertical_bob)
		figure.rotation = sway
		figure.scale = Vector2(SCALE * weight_scale, SCALE * (2.0 - weight_scale))
	if is_instance_valid(shadow):
		var shadow_pulse := 1.0 - absf(sin(stride_phase)) * 0.08
		shadow.scale = Vector2(shadow_pulse, shadow_pulse)
	if is_instance_valid(arch_dawn_glow):
		arch_dawn_glow.energy = lerpf(0.18, 1.15, progress)
