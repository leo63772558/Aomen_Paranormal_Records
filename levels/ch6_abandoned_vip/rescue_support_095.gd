extends Node2D
## The pair is painted together, so their supporting hands never detach.

const SHEET := preload("res://assets/characters/rescue_support_095.png")
const CELL := Vector2(512, 512)
const SCALE := 0.17
# The sheet faces right; flip it for Jiamin emerging from the right-hand hatch.
const DAWEN_FOOT := Vector2(132, 490)

var figure: Sprite2D
var displayed_frame := 0


func _ready() -> void:
	figure = Sprite2D.new()
	figure.centered = false
	figure.flip_h = true
	figure.light_mask = 2
	figure.scale = Vector2.ONE * SCALE
	figure.position = -DAWEN_FOOT * SCALE
	add_child(figure)
	set_frame(0)


func set_frame(index: int) -> void:
	displayed_frame = clampi(index, 0, 5)
	var atlas := AtlasTexture.new()
	atlas.atlas = SHEET
	atlas.region = Rect2(Vector2(displayed_frame % 3, floori(displayed_frame / 3.0)) * CELL, CELL)
	figure.texture = atlas


func perform(dawen: PlayerController, jiamin: PlayerController) -> void:
	position = dawen.position
	z_index = int(position.y)
	dawen.sprite.visible = false
	jiamin.sprite.visible = false
	var lamp_was_on := dawen.lamp.enabled
	var near_light: PointLight2D = dawen.get_node("NearLight")
	var near_was_on := near_light.enabled
	# The painted hands are supporting Jiamin and do not carry the flashlight.
	dawen.lamp.enabled = false
	near_light.enabled = false
	var sequence := create_tween()
	sequence.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	for frame in range(6):
		sequence.tween_callback(set_frame.bind(frame))
		if frame == 1:
			sequence.tween_callback(func(): AudioManager.play_footstep(true, false))
		sequence.tween_interval(0.2)
	await sequence.finished
	if not is_inside_tree() or not is_instance_valid(dawen) or not is_instance_valid(jiamin): return
	if is_instance_valid(dawen.sprite):
		dawen.sprite.visible = true
	if is_instance_valid(jiamin.sprite):
		jiamin.sprite.visible = true
	dawen.lamp.enabled = lamp_was_on
	near_light.enabled = near_was_on
	queue_free()
