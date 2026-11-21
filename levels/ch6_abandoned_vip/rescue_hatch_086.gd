extends Node2D
## A hinged textured leaf, sampled from the room's own art, over a dark passage.
## This avoids showing the painted closed door after its collision is removed.

const BACKGROUND := preload("res://assets/tilesets/abandoned_vip_rescue_061.png")
const SOURCE_RECT := Rect2(1483, 326, 151, 349)
const SOURCE_TO_WORLD := Vector2(1280.0 / 1672.0, 720.0 / 941.0)
const LEAF_RECT := Rect2(SOURCE_RECT.position * SOURCE_TO_WORLD, SOURCE_RECT.size * SOURCE_TO_WORLD)
const BLOCKING_RECT := LEAF_RECT
const LEAF_CONTOUR := [
	Vector2(8, 33), Vector2(18, 14), Vector2(40, 4), Vector2(116, 4),
	Vector2(139, 20), Vector2(150, 43), Vector2(150, 325),
	Vector2(128, 347), Vector2(47, 342), Vector2(22, 325), Vector2(8, 301)
]

var leaf: Polygon2D
var cavity: Polygon2D
var progress := 0.0


func _ready() -> void:
	name = "AnimatedMaintenanceHatch086"
	z_index = 5
	cavity = Polygon2D.new()
	cavity.name = "DarkMaintenancePassage"
	cavity.texture = BACKGROUND
	cavity.position = LEAF_RECT.position
	cavity.modulate = Color(0.28, 0.31, 0.29, 1.0)
	add_child(cavity)
	leaf = Polygon2D.new()
	leaf.name = "HingedRustSteelLeaf"
	leaf.texture = BACKGROUND
	leaf.position = LEAF_RECT.position
	var contour := PackedVector2Array()
	var leaf_uv := PackedVector2Array()
	var interior_uv := PackedVector2Array()
	for point in LEAF_CONTOUR:
		contour.append(point * SOURCE_TO_WORLD)
		leaf_uv.append(SOURCE_RECT.position + point)
		# Continue the existing lower maintenance arch inside the opened frame.
		interior_uv.append(Vector2(765, 840) + point / SOURCE_RECT.size * Vector2(100, 65))
	leaf.polygon = contour
	leaf.uv = leaf_uv
	cavity.polygon = contour
	cavity.uv = interior_uv
	add_child(leaf)
	set_open_progress(progress)


func set_open_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	if not is_instance_valid(leaf):
		return
	var projected_width := maxf(0.025, cos(progress * PI * 0.5))
	leaf.scale.x = projected_width
	leaf.skew = -0.075 * sin(progress * PI)
	leaf.modulate = Color(1.0 - 0.3 * progress, 1.0 - 0.3 * progress, 1.0 - 0.3 * progress, 1.0)
	leaf.visible = progress < 0.995


func sync_blocking(body: StaticBody2D, occluder: LightOccluder2D) -> void:
	# The physical leaf narrows with the same hinge projection as its texture.
	var width := maxf(2.0, BLOCKING_RECT.size.x * cos(progress * PI * 0.5))
	var bounds := Rect2(BLOCKING_RECT.position, Vector2(width, BLOCKING_RECT.size.y))
	if is_instance_valid(body):
		var collision := body.get_child(0) as CollisionShape2D
		(collision.shape as RectangleShape2D).size = bounds.size
		collision.position = bounds.get_center()
	if is_instance_valid(occluder):
		occluder.occluder.polygon = PackedVector2Array([
			bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end,
			Vector2(bounds.position.x, bounds.end.y)
		])
