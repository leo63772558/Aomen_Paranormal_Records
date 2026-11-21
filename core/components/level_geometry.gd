extends RefCounted
class_name LevelGeometry

static func wall(parent: Node2D, rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = rect.get_center()
	body.add_child(collision)
	parent.add_child(body)
	var shadow := LightOccluder2D.new()
	var polygon := OccluderPolygon2D.new()
	polygon.polygon = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	shadow.occluder = polygon
	parent.add_child(shadow)
	return body

static func polygon_wall(parent: Node2D, footprint: PackedVector2Array, casts_shadow := true) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	var collision := CollisionPolygon2D.new()
	collision.polygon = footprint
	body.add_child(collision)
	parent.add_child(body)
	if casts_shadow:
		var shadow := LightOccluder2D.new()
		var outline := OccluderPolygon2D.new()
		outline.polygon = footprint
		shadow.occluder = outline
		parent.add_child(shadow)
	return body

static func room_bounds(parent: Node2D, top: float, opening := Vector2.ZERO) -> void:
	if opening == Vector2.ZERO:
		wall(parent, Rect2(48, 40, 544, top - 40))
	else:
		wall(parent, Rect2(48, 40, opening.x - 48, top - 40))
		wall(parent, Rect2(opening.y, 40, 592 - opening.y, top - 40))
		wall(parent, Rect2(opening.x, 40, opening.y - opening.x, top - 64))
	wall(parent, Rect2(48, top, 16, 320-top))
	wall(parent, Rect2(576, top, 16, 320-top))
	wall(parent, Rect2(48, 310, 544, 16))
