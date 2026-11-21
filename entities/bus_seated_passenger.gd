extends Node2D

var mesh: Polygon2D
var face_blend: ShaderMaterial
var rest: PackedVector2Array
var turn_amount := 0.0
var clock := 0.0
var motion: Tween

func _ready() -> void:
	mesh = _make_mesh(Rect2(145, 0, 360, 627))
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform float turn = 0.0; uniform vec2 alternate_offset; void fragment(){ vec4 original=texture(TEXTURE,UV); vec4 turned=texture(TEXTURE,UV+alternate_offset); COLOR=mix(original,turned,turn); }"
	face_blend = ShaderMaterial.new()
	face_blend.shader = shader
	face_blend.set_shader_parameter("alternate_offset", Vector2(609.0 / 1246.0, 632.0 / 1263.0))
	mesh.material = face_blend
	rest = mesh.polygon.duplicate()

func _make_mesh(region: Rect2) -> Polygon2D:
	var result := Polygon2D.new()
	result.texture = preload("res://assets/characters/bus_passenger_034.png")
	result.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	var triangles: Array = []
	for row in range(13):
		for column in range(9):
			var ratio := Vector2(column / 8.0, row / 12.0)
			points.append(Vector2((ratio.x - 0.5) * 94.0, (ratio.y - 1.0) * 162.0))
			uv.append(region.position + ratio * region.size)
	for row in range(12):
		for column in range(8):
			var index := row * 9 + column
			triangles.append(PackedInt32Array([index, index + 1, index + 10]))
			triangles.append(PackedInt32Array([index, index + 10, index + 9]))
	result.polygon = points
	result.uv = uv
	result.polygons = triangles
	add_child(result)
	return result

func turn() -> void:
	if is_instance_valid(motion): motion.kill()
	motion = create_tween()
	motion.tween_property(self, "turn_amount", 0.12, 0.24).set_trans(Tween.TRANS_SINE)
	motion.tween_property(self, "turn_amount", 1.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

func reset_pose() -> void:
	if is_instance_valid(motion): motion.kill()
	turn_amount = 0.0

func _process(delta: float) -> void:
	clock += delta
	var posed := rest.duplicate()
	for index in range(posed.size()):
		var point := posed[index]
		var head_weight := smoothstep(0.65, 0.93, -point.y / 162.0)
		point.x += head_weight * sin(turn_amount * 1.4) * 8.0
		point.y += head_weight * turn_amount * 3.0 + sin(clock * 1.6) * 0.35
		posed[index] = point
	mesh.polygon = posed
	# Blend samples in one draw, so overlapping opaque cloth never becomes
	# translucent halfway through the turn as two half-alpha sprites would.
	face_blend.set_shader_parameter("turn", smoothstep(0.10, 0.85, turn_amount))
