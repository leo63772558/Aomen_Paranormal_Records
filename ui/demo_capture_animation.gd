extends Control
class_name DemoCaptureAnimation

signal finished

const IMPACT_TIME := 0.57
const DURATION := 1.06
const GRID := Vector2i(24, 20)
const REFERENCE_SIZE := Vector2(640, 360)
const PRIEST_PATH := "res://assets/characters/priest_lunge_026.png"
const FAMILY_PATH := "res://assets/characters/bunker_family_lunge_026.png"
const RANGER_PATH := "res://assets/characters/shadow_walk_011.png"
const PRIEST_ART: Texture2D = preload(PRIEST_PATH)
const FAMILY_ART: Texture2D = preload(FAMILY_PATH)
const RANGER_ART: Texture2D = preload(RANGER_PATH)

var appearance := PRIEST_PATH
var mesh: Polygon2D
var ghost_mesh: Polygon2D
var tear_overlay: Control
var blackout: ColorRect
var rest_pose := PackedVector2Array()
var head_weights := PackedFloat32Array()
var arm_weights := PackedFloat32Array()
var jaw_weights := PackedFloat32Array()
var head_pivot := Vector2.ZERO
var elapsed := 0.0
var hit_sent := false


static func play_on(parent: Node, art_path: String) -> void:
	if _preloaded_atlas(art_path) == null:
		push_error("Unknown capture art: " + art_path)
		return
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(layer)
	var animation := DemoCaptureAnimation.new()
	animation.appearance = art_path
	layer.add_child(animation)
	await animation.finished
	layer.queue_free()

static func _preloaded_atlas(art_path: String) -> Texture2D:
	match art_path:
		PRIEST_PATH:
			return PRIEST_ART
		FAMILY_PATH:
			return FAMILY_ART
		RANGER_PATH:
			return RANGER_ART
		_:
			return null


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var backdrop := _screen_rect(Color.BLACK)
	backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	_build_mesh()
	ghost_mesh = mesh.duplicate() as Polygon2D
	ghost_mesh.name = "ChromaticGhostFigure"
	ghost_mesh.modulate = Color(0.95, 0.18, 0.16, 0.0)
	add_child(ghost_mesh)
	tear_overlay = Control.new()
	tear_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	tear_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	tear_overlay.draw.connect(_draw_tear_overlay)
	add_child(tear_overlay)
	blackout = _screen_rect(Color(0.0, 0.0, 0.0, 0.0))
	apply_pose(0.0)
	AudioManager.stop_chase_music()
	AudioManager.play_world_effect("capture_rush")
	AudioManager.play_world_effect("jumpscare_shriek")


func _screen_rect(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(rect)
	rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	return rect


func _build_mesh() -> void:
	mesh = Polygon2D.new()
	mesh.name = "DeformingFigure"
	mesh.texture = _preloaded_atlas(appearance)
	mesh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(mesh)
	# One fixed illustration contains the robe, arm and face. Skin the entire
	# silhouette on one lattice so movements remain attached at the seams.
	var cell := mesh.texture.get_size() / Vector2(3, 2)
	var source := Rect2(Vector2(2.0 * cell.x + 2.0, 2.0), cell - Vector2(4.0, 4.0))
	var face := Vector2(0.65, 0.37) if appearance == PRIEST_PATH else Vector2(0.61, 0.38)
	var hand := Vector2(0.34, 0.79) if appearance == PRIEST_PATH else Vector2(0.31, 0.83)
	if appearance == RANGER_PATH:
		source = Rect2(2.0, 2.0, 358.0, 504.0)
		face = Vector2(0.48, 0.19)
		hand = Vector2(0.67, 0.78)
	var art_size := Vector2(620.0, 620.0 * source.size.y / source.size.x)
	head_pivot = (Vector2(face.x, face.y + 0.18) - face) * art_size
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var faces: Array[PackedInt32Array] = []
	var stride := GRID.x + 1
	for y in range(GRID.y + 1):
		for x in range(GRID.x + 1):
			var uv := Vector2(float(x) / GRID.x, float(y) / GRID.y)
			rest_pose.append((uv - face) * art_size)
			uvs.append(source.position + uv * source.size)
			head_weights.append(_influence(uv, face, Vector2(0.32, 0.40)))
			arm_weights.append(_influence(uv, hand, Vector2(0.34, 0.34)))
			jaw_weights.append(_influence(uv, face + Vector2(-0.015, 0.16), Vector2(0.14, 0.13)))
			var edge := minf(minf(uv.x, 1.0 - uv.x), minf(uv.y, 1.0 - uv.y))
			colors.append(Color(1, 1, 1, smoothstep(0.0, 0.09, edge)))
			if x < GRID.x and y < GRID.y:
				var at := y * stride + x
				faces.append(PackedInt32Array([at, at + 1, at + stride + 1]))
				faces.append(PackedInt32Array([at, at + stride + 1, at + stride]))
	mesh.polygon = rest_pose
	mesh.polygons = faces
	mesh.uv = uvs
	mesh.vertex_colors = colors


func _influence(uv: Vector2, center: Vector2, radius: Vector2) -> float:
	return 1.0 - smoothstep(0.0, 1.0, ((uv - center) / radius).length())


func apply_pose(time: float) -> void:
	var lift := smoothstep(0.04, 0.29, time)
	var charge := smoothstep(0.28, IMPACT_TIME, time)
	var follow_through := smoothstep(IMPACT_TIME, 0.77, time)
	var eased_charge := pow(charge, 1.65)
	var reach := smoothstep(0.21, 0.55, time)
	var tilt := lerpf(-0.17, 0.08, lift) - charge * 0.17 + follow_through * 0.09
	var posed := rest_pose.duplicate()
	for i in range(posed.size()):
		var point := rest_pose[i]
		var lifted_head := head_pivot + (point - head_pivot).rotated(tilt) + Vector2(-3.0, (1.0 - lift) * 25.0 - charge * 19.0)
		point = point.lerp(lifted_head, head_weights[i])
		point += Vector2(42.0 * reach - 21.0, 28.0 - 66.0 * reach) * arm_weights[i]
		point.y += (4.0 * lift + 14.0 * charge - 5.0 * follow_through) * jaw_weights[i]
		posed[i] = point
	mesh.polygon = posed

	var viewport_scale := size / REFERENCE_SIZE
	var zoom := 0.60 + lift * 0.11 + eased_charge * 0.93 + follow_through * 0.24
	var hit_age := maxf(0.0, time - IMPACT_TIME)
	var recoil := smoothstep(IMPACT_TIME, IMPACT_TIME + 0.035, time) * exp(-hit_age * 12.0)
	var reduced := GameState.reduced_flash
	mesh.scale = viewport_scale * zoom
	mesh.position = (Vector2(319.0, 163.0) + Vector2(-18.0 * charge, -26.0 * lift - 13.0 * charge)
		+ Vector2(sin(hit_age * 35.0) * 8.0, -11.0) * recoil * (0.18 if reduced else 1.0)) * viewport_scale
	mesh.rotation = -0.028 * lift + 0.047 * charge - 0.023 * follow_through
	var light := 0.47 + 0.41 * lift + 0.10 * charge
	mesh.modulate = Color(light, light * 0.97, light * 0.93)
	if is_instance_valid(ghost_mesh):
		ghost_mesh.polygon = posed
		ghost_mesh.scale = mesh.scale * (1.035 + 0.02 * sin(time * 42.0))
		ghost_mesh.position = mesh.position + Vector2(sin(time * 55.0) * 14.0, cos(time * 47.0) * 6.0) * viewport_scale
		ghost_mesh.rotation = mesh.rotation + sin(time * 38.0) * 0.035
		ghost_mesh.modulate = Color(0.92, 0.16, 0.14, 0.0 if reduced else (0.36 * charge * (1.0 - smoothstep(0.70, 0.90, time))))
	if is_instance_valid(tear_overlay):
		tear_overlay.queue_redraw()
	var fade := smoothstep(0.70, 0.90, time)
	var tint := 0.0 if reduced else recoil * 0.12 * (1.0 - fade)
	blackout.color = Color(0.35 * tint, 0.0, 0.0, maxf(tint, fade))


func _draw_tear_overlay() -> void:
	if GameState.reduced_flash or elapsed > 0.85:
		return
	var intensity := smoothstep(0.22, IMPACT_TIME, elapsed)
	if intensity <= 0.02:
		return
	for idx in range(5):
		var y := fmod(elapsed * 410.0 + idx * 73.0, size.y)
		var h := 2.0 + float(idx % 3) * 1.5
		tear_overlay.draw_rect(Rect2(0, y, size.x, h), Color(0.82, 0.12, 0.10, 0.14 * intensity))


func _process(delta: float) -> void:
	elapsed += delta
	if not hit_sent and elapsed >= IMPACT_TIME:
		hit_sent = true
		AudioManager.play_world_effect("capture_hit")
	apply_pose(elapsed)
	if elapsed >= DURATION:
		set_process(false)
		finished.emit()
