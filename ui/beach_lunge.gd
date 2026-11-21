extends Control

signal finished
var mesh: Polygon2D
var rest: PackedVector2Array
var clock := 0.0
var head_rotation := 0.0
var reach := 0.0
var blackout: ColorRect
var motion: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.color = Color(0.005, 0.015, 0.012, 0.0)
	add_child(dim)
	var dim_motion := create_tween()
	dim_motion.tween_property(dim, "color:a", 0.78, 0.24)
	mesh = preload("res://entities/beach_apparition.gd")._mesh(Rect2(628, 649, 615, 648), 274, 330)
	mesh.position = Vector2(320, 340)
	mesh.scale = Vector2.ONE * 0.58
	rest = mesh.polygon.duplicate()
	add_child(mesh)
	var ghost := mesh.duplicate() as Polygon2D
	ghost.modulate = Color(0.75, 0.92, 0.88, 0.0 if GameState.reduced_flash else 0.28)
	add_child(ghost)
	blackout = ColorRect.new()
	blackout.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	blackout.color = Color.BLACK
	blackout.modulate.a = 0.0
	add_child(blackout)
	motion = create_tween()
	motion.tween_property(self, "head_rotation", -0.16, 0.25)
	motion.tween_property(self, "reach", 1.0, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	motion.parallel().tween_property(mesh, "scale", Vector2.ONE * 1.8, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	motion.parallel().tween_property(mesh, "position:y", 690.0, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	motion.parallel().tween_property(self, "head_rotation", 0.12, 0.40)
	motion.tween_callback(func(): AudioManager.play_world_effect("capture_hit"))
	motion.tween_property(blackout, "modulate:a", 1.0, 0.22)
	motion.tween_interval(0.18)
	motion.tween_callback(func(): finished.emit())
	AudioManager.play_world_effect("capture_rush")

func _process(delta: float) -> void:
	clock += delta
	var posed := rest.duplicate()
	for i in range(posed.size()):
		var point := posed[i]
		var upper := smoothstep(0.60, 0.92, -point.y / 330.0)
		var arm := smoothstep(0.35, 0.75, absf(point.x) / 137.0) * (1.0 - absf(-point.y / 330.0 - 0.50))
		point = point.lerp((point - Vector2(0, -270)).rotated(head_rotation) + Vector2(0, -270), upper)
		point.x += signf(point.x) * arm * reach * 35.0
		point.y += arm * reach * 26.0 + sin(clock * 9.0) * upper * 0.9
		posed[i] = point
	mesh.polygon = posed
