extends Node2D

var mesh: Polygon2D
var rest_vertices: PackedVector2Array
var walk_phase := 0.0
var walking := false
var foot_clock := 0.0

func _ready() -> void:
	mesh = Polygon2D.new()
	mesh.texture = preload("res://assets/characters/bus_passenger_034.png")
	mesh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var atlas_region := Rect2(820, 0, 242, 627)
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var cells: Array = []
	# A textured mesh, not a sliding unanimated standing sprite. Separate columns
	# let the trouser legs and sleeves move with opposite phases.
	for row in range(9):
		for column in range(5):
			var u := float(column) / 4.0
			var v := float(row) / 8.0
			vertices.append(Vector2((u - 0.5) * 66.0, (v - 1.0) * 170.0))
			uv.append(atlas_region.position + atlas_region.size * Vector2(u, v))
	for row in range(8):
		for column in range(4):
			var top := row * 5 + column
			cells.append(PackedInt32Array([top, top + 1, top + 6]))
			cells.append(PackedInt32Array([top, top + 6, top + 5]))
	mesh.polygon = vertices
	mesh.uv = uv
	mesh.polygons = cells
	rest_vertices = vertices
	add_child(mesh)

func _process(delta: float) -> void:
	if not walking:
		return
	var old_phase := walk_phase
	walk_phase += delta * 9.0
	foot_clock += delta
	if int(old_phase / PI) != int(walk_phase / PI):
		AudioManager.play_footstep(false, false)
	var posed := rest_vertices.duplicate()
	for index in range(posed.size()):
		var point := posed[index]
		var from_feet := -point.y / 170.0
		var side := -1.0 if point.x < 0 else 1.0
		var leg := clampf((0.52 - from_feet) / 0.52, 0, 1)
		point.x += sin(walk_phase + side * PI * 0.5) * leg * 5.5
		point.y -= maxf(0, sin(walk_phase + side * PI * 0.5)) * leg * 2.2
		point.y += sin(walk_phase * 2.0) * 0.7 * (1.0 - leg)
		var sleeve := clampf((absf(point.x) - 15.0) / 18.0, 0, 1) * clampf(1.0 - absf(from_feet - 0.58) * 4.0, 0, 1)
		point.x += sin(walk_phase - side * PI * 0.5) * sleeve * 2.0
		posed[index] = point
	mesh.polygon = posed
