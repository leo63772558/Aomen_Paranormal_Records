extends CharacterBody2D

signal caught
var beach: Node2D
var player: PlayerController
var mesh: Polygon2D
var rest: PackedVector2Array
var clock := 0.0
var active := true
var warned := false
var attack_amount := 0.0
var mist_timer := 0.0
var flash_receiver: PhoneFlashReceiver

func _ready() -> void:
	flash_receiver = PhoneFlashReceiver.new()
	flash_receiver.sense_offset = Vector2(0, -67)
	add_child(flash_receiver)
	collision_layer = 4
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 12
	collision.shape = shape
	add_child(collision)
	mesh = _mesh(Rect2(12, 0, 600, 645))
	rest = mesh.polygon.duplicate()
	add_child(mesh)

static func _mesh(region: Rect2, width := 74.0, height := 112.0) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.texture = preload("res://assets/characters/beach_apparition_041.png")
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var triangles: Array = []
	for row in range(17):
		for column in range(13):
			var ratio := Vector2(column / 12.0, row / 16.0)
			vertices.append(Vector2((ratio.x - 0.5) * width, (ratio.y - 1.0) * height))
			uv.append(region.position + region.size * ratio)
	for row in range(16):
		for column in range(12):
			var i := row * 13 + column
			triangles.append(PackedInt32Array([i, i + 1, i + 14]))
			triangles.append(PackedInt32Array([i, i + 14, i + 13]))
	polygon.polygon = vertices
	polygon.uv = uv
	polygon.polygons = triangles
	return polygon

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(player):
		velocity = Vector2.ZERO
		return
	if flash_receiver.is_stunned():
		velocity = Vector2.ZERO
		return
	clock += delta
	var focus := flash_receiver.focus_after_flash(player)
	var delta_to := focus - global_position
	var lit: bool = beach.in_headlight(position)
	var approach := player.position.y > 345 and delta_to.length() < 370 and not lit
	velocity = delta_to.normalized() * 51.0 if approach else Vector2.ZERO
	if lit: velocity = -delta_to.normalized() * 72.0
	if player.position.y < 345 or position.y < 350: velocity.y = maxf(velocity.y, 26.0)
	move_and_slide()
	position = Vector2(clampf(position.x, 70, 1190), clampf(position.y, 354, 676))
	z_index = int(position.y)
	var posed := rest.duplicate()
	for i in range(posed.size()):
		var point := posed[i]
		var leg := clampf((point.y + 57.0) / 57.0, 0, 1)
		var side := -1.0 if point.x < 0 else 1.0
		point.x += sin(clock * 5.5 + side * PI * 0.5) * leg * (2.5 if approach else 0.4)
		point.y += sin(clock * 2.6) * (1.0 - leg) * 1.0
		point.x += sin(clock * 1.2) * smoothstep(0.55, 1.0, -point.y / 112.0) * 1.7
		posed[i] = point
	mesh.polygon = posed
	if not GameState.reduced_flash:
		if lit:
			mesh.modulate = Color(1.0, 0.92, 0.85, 0.55 + 0.15 * sin(clock * 28.0))
			mesh.position.x = sin(clock * 42.0) * 2.4
		elif approach:
			mesh.modulate = Color(0.86, 0.96, 1.0, 0.82 + 0.14 * sin(clock * 8.0))
			mesh.position.x = 0.0
			mist_timer -= delta
			if mist_timer <= 0.0:
				mist_timer = 0.22
				_spawn_wet_trail()
		else:
			mesh.modulate = Color(0.88, 0.94, 0.98, 0.88)
			mesh.position.x = 0.0
	if approach and delta_to.length() < 170 and not warned:
		warned = true
		beach.hud.notify("沙地上多了一串湿脚步。白影避开了车头的远光。")
	if flash_receiver.may_catch(player) and approach and global_position.distance_to(player.global_position) < 30:
		active = false
		velocity = Vector2.ZERO
		caught.emit()

func _spawn_wet_trail() -> void:
	if get_parent() == null:
		return
	var puddle := Polygon2D.new()
	puddle.polygon = PackedVector2Array([Vector2(-9, 0), Vector2(-3, -4), Vector2(8, -2), Vector2(10, 3), Vector2(-2, 5)])
	puddle.color = Color(0.06, 0.12, 0.16, 0.42)
	puddle.global_position = global_position + Vector2(randf_range(-5.0, 5.0), 2.0)
	puddle.z_index = 2
	get_parent().add_child(puddle)
	var tw := puddle.create_tween()
	tw.tween_property(puddle, "scale", Vector2(1.45, 1.25), 0.7)
	tw.parallel().tween_property(puddle, "modulate:a", 0.0, 0.95)
	tw.tween_callback(puddle.queue_free)
