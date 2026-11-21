extends Node2D

signal motion_finished(open: bool)

var openness := 0.0
var moving := false
var left_hinge: Node2D
var right_hinge: Node2D
var collision: CollisionShape2D
var occluder: LightOccluder2D
var motion: Tween
var audio: AudioStreamPlayer

func _ready() -> void:
	var frame := Sprite2D.new()
	frame.texture = part(Rect2(200, 10, 225, 609))
	frame.position = Vector2(0, -100)
	frame.scale = Vector2(0.33, 0.33)
	add_child(frame)
	left_hinge = Node2D.new()
	left_hinge.position = Vector2(-27, -191)
	add_child(left_hinge)
	right_hinge = Node2D.new()
	right_hinge.position = Vector2(27, -191)
	add_child(right_hinge)
	for index in range(2):
		var leaf := Sprite2D.new()
		leaf.texture = part(Rect2(850 + index * 94, 42, 94, 560))
		leaf.centered = false
		leaf.scale = Vector2(0.287, 0.33)
		if index == 1: leaf.position.x = -27
		(left_hinge if index == 0 else right_hinge).add_child(leaf)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	add_child(body)
	collision = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(54, 16)
	collision.shape = shape
	collision.position = Vector2(0, -7)
	body.add_child(collision)
	occluder = LightOccluder2D.new()
	var polygon := OccluderPolygon2D.new()
	polygon.polygon = PackedVector2Array([Vector2(-27, -191), Vector2(27, -191), Vector2(27, 0), Vector2(-27, 0)])
	occluder.occluder = polygon
	add_child(occluder)
	LevelGeometry.wall(self, Rect2(-33, -23, 6, 26))
	LevelGeometry.wall(self, Rect2(27, -23, 6, 26))
	audio = AudioStreamPlayer.new()
	audio.bus = "SFX"
	audio.volume_db = -8
	add_child(audio)
	_apply_pose(0.0)

static func part(region: Rect2) -> AtlasTexture:
	var crop := AtlasTexture.new()
	crop.atlas = preload("res://assets/props/bus_door_parts_036.png")
	crop.region = region
	crop.filter_clip = true
	return crop

func set_open(open: bool, animate := true) -> void:
	if is_instance_valid(motion): motion.kill()
	moving = true
	if not open:
		collision.set_deferred("disabled", false)
		occluder.visible = true
	if not animate:
		_apply_pose(1.0 if open else 0.0)
		moving = false
		motion_finished.emit(open)
		return
	audio.stream = load("res://assets/audio/recorded/bus_door_open_036.wav" if open else "res://assets/audio/recorded/bus_door_close_036.wav")
	audio.play()
	motion = create_tween()
	motion.tween_method(_apply_pose, openness, 1.0 if open else 0.0, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await motion.finished
	if not is_inside_tree(): return
	moving = false
	motion_finished.emit(open)

func _apply_pose(value: float) -> void:
	openness = clampf(value, 0.0, 1.0)
	var fold := lerpf(1.0, 0.08, openness)
	left_hinge.scale.x = fold
	right_hinge.scale.x = fold
	left_hinge.rotation = openness * 0.05
	right_hinge.rotation = openness * -0.05
	left_hinge.modulate = Color.WHITE.darkened(openness * 0.22)
	right_hinge.modulate = left_hinge.modulate
	collision.set_deferred("disabled", openness > 0.88)
	occluder.visible = openness <= 0.88

func _exit_tree() -> void:
	if is_instance_valid(motion): motion.kill()
	if is_instance_valid(audio):
		audio.stop()
		audio.stream = null
