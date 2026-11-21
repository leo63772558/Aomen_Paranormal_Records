extends Node2D
class_name SampleInteractable

var interactable_id: String
var prompt: String
var active: bool = true
var sprite: Sprite2D
var footprint: Rect2
var solid_body: StaticBody2D
var light_blocker: LightOccluder2D

func setup(id: String, title: String, texture_name: String, anchor: Vector2, body_size: Vector2, solid: bool = true, body_offset: Vector2 = Vector2.ZERO) -> void:
	interactable_id = id
	prompt = title
	position = anchor
	z_index = int(anchor.y)
	add_to_group("interactables")
	sprite = Sprite2D.new()
	var generated := {
		"wardrobe": [Rect2(137, 26, 273, 464), Vector2(64, 98)],
		"iron_bed": [Rect2(641, 25, 259, 467), Vector2(66, 90)],
		"photo_desk": [Rect2(1062, 93, 403, 366), Vector2(86, 68)],
		"gate": [Rect2(186, 545, 180, 452), Vector2(20, 78)],
		"shrine": [Rect2(613, 576, 312, 405), Vector2(40, 52)],
		"partition": [Rect2(1222, 534, 90, 469), Vector2(16, 114)]
	}
	var dimensions: Vector2
	if texture_name == "vent_006":
		sprite.texture = DemoItems.prop_cell(10)
		dimensions = Vector2(52, 32)
		sprite.scale = dimensions / sprite.texture.get_size()
	elif texture_name == "mailbox_004":
		var texture := AtlasTexture.new()
		texture.atlas = preload("res://assets/props/mailbox_004_source.png")
		texture.region = Rect2(132, 123, 760, 1288)
		sprite.texture = texture
		dimensions = Vector2(18, 30)
		sprite.scale = dimensions / texture.region.size
	elif generated.has(texture_name):
		var texture := AtlasTexture.new()
		texture.atlas = preload("res://assets/props/furniture_atlas_003_source.png")
		texture.region = generated[texture_name][0]
		sprite.texture = texture
		dimensions = generated[texture_name][1]
		sprite.scale = dimensions / texture.region.size
	else:
		sprite.texture = load("res://assets/props/%s.png" % texture_name)
		dimensions = sprite.texture.get_size()
	sprite.centered = false
	sprite.position = Vector2(-dimensions.x / 2.0, -dimensions.y)
	add_child(sprite)
	footprint = Rect2(Vector2(-body_size.x / 2.0, -body_size.y) + body_offset, body_size)
	var area := Area2D.new()
	area.collision_layer = 8
	area.collision_mask = 2
	var shape := RectangleShape2D.new()
	shape.size = Vector2(maxf(body_size.x, 20), maxf(body_size.y, 16))
	var detector := CollisionShape2D.new()
	detector.shape = shape
	detector.position = footprint.get_center()
	area.add_child(detector)
	add_child(area)
	if solid:
		var body := StaticBody2D.new()
		solid_body = body
		body.collision_layer = 1
		body.collision_mask = 2
		var collision := CollisionShape2D.new()
		var body_shape := RectangleShape2D.new()
		body_shape.size = Vector2(maxf(body_size.x, 1), maxf(body_size.y, 1))
		collision.shape = body_shape
		collision.position = footprint.get_center()
		body.add_child(collision)
		add_child(body)
		var occluder := LightOccluder2D.new()
		light_blocker = occluder
		var polygon := OccluderPolygon2D.new()
		polygon.polygon = PackedVector2Array([footprint.position, Vector2(footprint.end.x, footprint.position.y), footprint.end, Vector2(footprint.position.x, footprint.end.y)])
		occluder.occluder = polygon
		add_child(occluder)

func set_solid_enabled(enabled: bool) -> void:
	if is_instance_valid(solid_body):
		for child in solid_body.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", not enabled)
	if is_instance_valid(light_blocker):
		light_blocker.visible = enabled

func reveal_opening() -> void:
	set_solid_enabled(false)
	var opening := AtlasTexture.new()
	opening.atlas = preload("res://assets/tilesets/maintenance_012.png")
	opening.region = Rect2(221, 340, 130, 156)
	sprite.texture = opening
	sprite.position = Vector2(-19, -26)
	sprite.scale = Vector2(38, 26) / opening.get_size()

func set_highlight(value: bool) -> void:
	sprite.modulate = Color(1.25, 1.18, 0.93) if value else Color.WHITE
