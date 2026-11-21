extends Node2D

signal phase_changed(phase: int)

enum Phase { LOW, WARNING, RISING, HIGH, EBB }
const DURATIONS := [24.0, 8.0, 12.0, 10.0, 12.0]
var phase := Phase.LOW
var phase_clock := 0.0
var clock := 0.0
var level := 0.0
var water: Polygon2D
var foam: Line2D
var hazard: Area2D
var hazard_polygon: CollisionPolygon2D

func _ready() -> void:
	water = Polygon2D.new()
	water.texture = preload("res://assets/tilesets/hacsa_beach_038.png")
	water.color = Color(0.65, 0.77, 0.75, 0.97)
	water.z_index = 1
	add_child(water)
	foam = Line2D.new()
	foam.width = 3.3
	foam.default_color = Color(0.70, 0.77, 0.73, 0.54)
	foam.z_index = 2
	add_child(foam)
	hazard = Area2D.new()
	hazard.collision_layer = 16
	hazard.collision_mask = 2
	hazard.name = "TidalWaterHazard"
	hazard_polygon = CollisionPolygon2D.new()
	hazard.add_child(hazard_polygon)
	add_child(hazard)
	_update_shape()

func waterline_at(x: float) -> float:
	return 687.0 - x * 0.125 - level

func is_wet(at: Vector2) -> bool:
	return at.y > waterline_at(at.x) - 5.0

func _process(delta: float) -> void:
	clock += delta
	phase_clock += delta
	if phase_clock >= DURATIONS[phase]:
		phase_clock -= DURATIONS[phase]
		phase = (phase + 1) % DURATIONS.size()
		phase_changed.emit(phase)
	match phase:
		Phase.LOW, Phase.WARNING: level = 0.0
		Phase.RISING: level = phase_clock / DURATIONS[phase] * 190.0
		Phase.HIGH: level = 190.0
		Phase.EBB: level = (1.0 - phase_clock / DURATIONS[phase]) * 190.0
	_update_shape()

func _update_shape() -> void:
	var surface := PackedVector2Array()
	var uvs := PackedVector2Array()
	var texture_size := water.texture.get_size()
	for index in range(17):
		var x := float(index) * 80.0
		var ripple := sin(clock * 1.2 + index * 0.7) * 3.0 + sin(clock * 2.1 + index * 1.7) * 1.5
		surface.append(Vector2(x, waterline_at(x) + ripple))
		uvs.append(Vector2(x / 1280.0 * texture_size.x, texture_size.y * 0.88))
	foam.points = surface
	surface.append(Vector2(1280, 760))
	surface.append(Vector2(0, 760))
	uvs.append(texture_size)
	uvs.append(Vector2(0, texture_size.y))
	water.polygon = surface
	water.uv = uvs
	hazard_polygon.set_deferred("polygon", surface)
