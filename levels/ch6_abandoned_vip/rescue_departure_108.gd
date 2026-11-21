extends Node2D
## Short playable-scale cutscene walk to the room's open exit arch.

const CAMERA_SHEET := preload("res://assets/characters/rescue_camera_handoff_108.png")
const SUPPORT_SHEET := preload("res://assets/characters/rescue_support_095.png")
const CELL := Vector2(512, 512)
const SCALE := 0.17
const CAMERA_JIAMIN_FOOT := Vector2(190, 490)
const SUPPORT_DAWEN_FOOT := Vector2(132, 490)
const CAMERA_WALK_FRAMES := [3, 4, 5]
const SUPPORT_WALK_FRAMES := [3, 4, 5]

var figure: Sprite2D
var displayed_frame := 0
var use_camera_sheet := true


func _ready() -> void:
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
	z_index = int(start.y)
	dawen.sprite.visible = false
	jiamin.sprite.visible = false
	var lamp_was_on := dawen.lamp.enabled
	var near_light: PointLight2D = dawen.get_node("NearLight")
	var near_was_on := near_light.enabled
	dawen.lamp.enabled = false
	near_light.enabled = false
	var destination := Vector2(640, 664)
	var walking := create_tween()
	walking.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	walking.tween_method(_walk_step.bind(dawen, jiamin, start, destination), 0.0, 1.0, 3.6).set_trans(Tween.TRANS_LINEAR)
	var animation := create_tween()
	animation.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	for _cycle in range(6):
		for frame in CAMERA_WALK_FRAMES:
			animation.tween_callback(set_frame.bind(frame))
			if frame == CAMERA_WALK_FRAMES[0]:
				animation.tween_callback(func(): AudioManager.play_footstep(false, false))
			elif frame == CAMERA_WALK_FRAMES[1]:
				animation.tween_callback(func(): AudioManager.play_footstep(true, false))
			animation.tween_interval(0.2)
	await walking.finished
	if is_instance_valid(animation) and animation.is_running():
		animation.kill()
	if not is_inside_tree() or not is_instance_valid(dawen) or not is_instance_valid(jiamin): return
	if is_instance_valid(dawen.sprite):
		dawen.sprite.visible = true
	if is_instance_valid(jiamin.sprite):
		jiamin.sprite.visible = true
	dawen.lamp.enabled = lamp_was_on
	near_light.enabled = near_was_on
	queue_free()


func _walk_step(progress: float, dawen: PlayerController, jiamin: PlayerController, start: Vector2, destination: Vector2) -> void:
	var next_position := start.lerp(destination, progress)
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
	if not use_camera_sheet:
		figure.position = -SUPPORT_DAWEN_FOOT * SCALE
