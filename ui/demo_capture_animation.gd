extends Control
class_name DemoCaptureAnimation

signal finished

const IMPACT_TIME := 0.57
const DURATION := 1.12
const GRID := Vector2i(24, 20)
const REFERENCE_SIZE := Vector2(640, 360)
const PRIEST_PATH := "res://assets/characters/priest_white_eyes_v6.png"
const FAMILY_PATH := "res://assets/characters/bunker_family_lunge_026.png"
const RANGER_PATH := "res://assets/characters/wardrobe_lunge_v9.png"
const BUTCHER_PATH := "res://assets/characters/butcher_lunge_v6.png"
const BOSS_PATH := "res://assets/characters/ch6_boss_lunge_v9.png"
const BEACH_PATH := "res://assets/characters/beach_lunge_v10_anim.png"
const STAIR_WRAITH_PATH := "res://assets/characters/stair_wraith_lunge_v6.png"

# Every jumpscare uses its own dedicated 2x2 4-frame full-body-to-close-up lunging animation sheet!
const PRIEST_ANIM_ART: Texture2D = preload("res://assets/characters/priest_lunge_v11_anim.png")
const FAMILY_ANIM_ART: Texture2D = preload("res://assets/characters/bunker_family_lunge_v10_anim.png")
const RANGER_ANIM_ART: Texture2D = preload("res://assets/characters/wardrobe_lunge_v10_anim.png")
const BUTCHER_ANIM_ART: Texture2D = preload("res://assets/characters/butcher_lunge_v10_anim.png")
const BOSS_ANIM_ART: Texture2D = preload("res://assets/characters/boss_lunge_v11_anim.png")
const BEACH_ANIM_ART: Texture2D = preload(BEACH_PATH)
const STAIR_WRAITH_ART: Texture2D = preload(STAIR_WRAITH_PATH)

const HORROR_SHADER_CODE := """
shader_type canvas_item;
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float distortion = 0.0;
uniform float chroma = 0.0;
uniform float blood_vignette = 0.0;
uniform float time_sec = 0.0;
varying vec4 v_color;

void vertex() {
	v_color = COLOR;
}

vec2 map_cell(vec2 u) {
	vec2 cu = clamp(u, vec2(0.0), vec2(1.0));
	return uv_rect.xy + cu * uv_rect.zw;
}

void fragment() {
	vec2 uv = clamp(UV, vec2(0.0), vec2(1.0));
	if (distortion > 0.001) {
		vec2 centered = uv - vec2(0.5);
		float r2 = dot(centered, centered);
		uv += centered * r2 * distortion * 0.16;
		uv.x += sin(uv.y * 30.0 + time_sec * 54.0) * 0.0038 * distortion;
	}
	vec2 base_uv = map_cell(uv);
	vec4 col = texture(TEXTURE, base_uv);
	if (chroma > 0.001) {
		vec2 off = vec2(0.0042 * chroma, 0.0014 * chroma);
		float r = texture(TEXTURE, map_cell(uv + off)).r;
		float b = texture(TEXTURE, map_cell(uv - off)).b;
		col.r = mix(col.r, r, 0.60);
		col.b = mix(col.b, b, 0.50);
	}
	if (blood_vignette > 0.001) {
		float dist = length((UV - vec2(0.5)) * vec2(1.08, 1.24));
		float vig = smoothstep(0.46, 0.98, dist) * blood_vignette;
		col.rgb = mix(col.rgb, vec3(0.32, 0.02, 0.02), vig * 0.68);
	}
	COLOR = col * v_color;
}
"""

var appearance := PRIEST_PATH
var mesh: Polygon2D
var ghost_mesh: Polygon2D
var tear_overlay: Control
var blackout: ColorRect
var mesh_mat: ShaderMaterial
var is_grid_sheet := true
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
		PRIEST_PATH, "res://assets/characters/priest_lunge_026.png", "res://assets/characters/priest_lunge_v11_anim.png":
			return PRIEST_ANIM_ART
		FAMILY_PATH, "res://assets/characters/bunker_family_lunge_v10_anim.png":
			return FAMILY_ANIM_ART
		RANGER_PATH, "res://assets/characters/wardrobe_stalker_v5.png", "res://assets/characters/shadow_walk_011.png", "res://assets/characters/wardrobe_lunge_v10_anim.png":
			return RANGER_ANIM_ART
		BUTCHER_PATH, "res://assets/characters/butcher_lunge_v10_anim.png":
			return BUTCHER_ANIM_ART
		BOSS_PATH, "res://assets/characters/boss_lunge_v11_anim.png":
			return BOSS_ANIM_ART
		BEACH_PATH:
			return BEACH_ANIM_ART
		STAIR_WRAITH_PATH:
			return STAIR_WRAITH_ART
		_:
			return null


static func _is_animated_sheet(art_path: String) -> bool:
	return art_path != STAIR_WRAITH_PATH


static func _scare_sound_id(art_path: String) -> String:
	match art_path:
		PRIEST_PATH, "res://assets/characters/priest_lunge_026.png", "res://assets/characters/priest_lunge_v11_anim.png":
			return "jumpscare_priest"
		FAMILY_PATH, "res://assets/characters/bunker_family_lunge_v10_anim.png":
			return "jumpscare_family"
		RANGER_PATH, "res://assets/characters/wardrobe_stalker_v5.png", "res://assets/characters/shadow_walk_011.png", "res://assets/characters/wardrobe_lunge_v10_anim.png", STAIR_WRAITH_PATH:
			return "jumpscare_wraith"
		BUTCHER_PATH, "res://assets/characters/butcher_lunge_v10_anim.png":
			return "jumpscare_butcher"
		BOSS_PATH, "res://assets/characters/boss_lunge_v11_anim.png":
			return "boss_roar_impact"
		BEACH_PATH:
			return "jumpscare_drowned"
		_:
			return "jumpscare_shriek"


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	is_grid_sheet = _is_animated_sheet(appearance)
	var backdrop := _screen_rect(Color.BLACK)
	backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	_build_mesh()
	tear_overlay = Control.new()
	tear_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	tear_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	tear_overlay.draw.connect(_draw_tear_overlay)
	add_child(tear_overlay)
	blackout = _screen_rect(Color(0.0, 0.0, 0.0, 0.0))
	apply_pose(0.0)
	AudioManager.stop_chase_music()
	AudioManager.play_world_effect("capture_rush")
	AudioManager.play_world_effect(_scare_sound_id(appearance))


func _screen_rect(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(rect)
	rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	return rect


func _build_mesh() -> void:
	var sh := Shader.new()
	sh.code = HORROR_SHADER_CODE
	mesh_mat = ShaderMaterial.new()
	mesh_mat.shader = sh
	mesh_mat.set_shader_parameter("uv_rect", Vector4(0.006, 0.006, 0.488, 0.488) if is_grid_sheet else Vector4(0.0, 0.0, 1.0, 1.0))

	# Spectral motion-blur afterimage mesh trailing behind the lunging apparition
	ghost_mesh = Polygon2D.new()
	ghost_mesh.name = "SpectralAfterimage"
	ghost_mesh.texture = _preloaded_atlas(appearance)
	ghost_mesh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ghost_mesh.material = mesh_mat
	add_child(ghost_mesh)

	mesh = Polygon2D.new()
	mesh.name = "DeformingFigure"
	mesh.texture = _preloaded_atlas(appearance)
	mesh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mesh.material = mesh_mat
	add_child(mesh)

	var tex_sz := mesh.texture.get_size()
	var source := Rect2(Vector2.ZERO, tex_sz)
	var face := Vector2(0.50, 0.47)
	var hand := Vector2(0.50, 0.80)
	var art_size := Vector2(640.0, 360.0)
	head_pivot = (Vector2(face.x, face.y + 0.16) - face) * art_size
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var faces: Array[PackedInt32Array] = []
	var stride := GRID.x + 1
	for y in range(GRID.y + 1):
		for x in range(GRID.x + 1):
			var uv := Vector2(float(x) / GRID.x, float(y) / GRID.y)
			rest_pose.append((uv - face) * art_size)
			uvs.append(source.position + uv * source.size)
			head_weights.append(_influence(uv, face, Vector2(0.36, 0.42)))
			arm_weights.append(maxf(_influence(uv, Vector2(0.20, 0.72), Vector2(0.28, 0.34)), _influence(uv, Vector2(0.80, 0.72), Vector2(0.28, 0.34))))
			jaw_weights.append(_influence(uv, face + Vector2(0.0, 0.18), Vector2(0.20, 0.18)))
			var edge := minf(minf(uv.x, 1.0 - uv.x), minf(uv.y, 1.0 - uv.y))
			colors.append(Color(1, 1, 1, smoothstep(0.0, 0.04, edge)))
			if x < GRID.x and y < GRID.y:
				var at := y * stride + x
				faces.append(PackedInt32Array([at, at + 1, at + stride + 1]))
				faces.append(PackedInt32Array([at, at + stride + 1, at + stride]))
	mesh.polygon = rest_pose
	mesh.polygons = faces
	mesh.uv = uvs
	mesh.vertex_colors = colors
	ghost_mesh.polygon = rest_pose
	ghost_mesh.polygons = faces
	ghost_mesh.uv = uvs
	ghost_mesh.vertex_colors = colors


func _influence(uv: Vector2, center: Vector2, radius: Vector2) -> float:
	return 1.0 - smoothstep(0.0, 1.0, ((uv - center) / radius).length())


func apply_pose(time: float) -> void:
	var lift := smoothstep(0.04, 0.28, time)
	var charge := smoothstep(0.26, IMPACT_TIME, time)
	var follow_through := smoothstep(IMPACT_TIME, 0.82, time)
	var eased_charge := pow(charge, 1.50)
	var tilt := lerpf(-0.08, 0.04, lift) - charge * 0.09 + follow_through * 0.05
	var jaw_tremor := sin(time * 34.0) * 3.2 * charge
	var posed := rest_pose.duplicate()
	for i in range(posed.size()):
		var point := rest_pose[i]
		var lifted_head := head_pivot + (point - head_pivot).rotated(tilt) + Vector2(-1.5, (1.0 - lift) * 10.0 - charge * 11.0)
		point = point.lerp(lifted_head, head_weights[i] * 0.34)
		# Mouth/jaw wrenches wide open and vibrates during the shriek!
		point.y += (5.0 * lift + 21.0 * charge + jaw_tremor - 4.0 * follow_through) * jaw_weights[i] * 0.72
		# Ghost's own shoulders, arms, and hands surge outward and upward toward the player!
		var side_dir := 1.0 if point.x >= 0.0 else -1.0
		point.x += side_dir * (8.0 * lift + 22.0 * charge) * arm_weights[i] * 0.55
		point.y -= (4.0 * lift + 14.0 * charge) * arm_weights[i] * 0.55
		posed[i] = point
	mesh.polygon = posed
	if is_instance_valid(ghost_mesh):
		ghost_mesh.polygon = posed

	var viewport_scale := size / REFERENCE_SIZE
	if viewport_scale.x <= 0.01 or viewport_scale.y <= 0.01:
		viewport_scale = Vector2.ONE
	var base_zoom := 0.96
	var zoom := base_zoom + lift * 0.08 + eased_charge * 0.24 + follow_through * 0.08
	var hit_age := maxf(0.0, time - IMPACT_TIME)
	var recoil := smoothstep(IMPACT_TIME, IMPACT_TIME + 0.035, time) * exp(-hit_age * 8.0)
	var reduced := GameState.reduced_flash
	var violent_shake := Vector2.ZERO if reduced else Vector2(sin(time * 112.0) * 15.0 + cos(time * 68.0) * 6.0, cos(time * 94.0) * 11.0) * (charge * 0.78 + recoil * 1.55)
	mesh.scale = viewport_scale * zoom
	mesh.position = (Vector2(320.0, 178.0) + Vector2(-2.0 * charge, -3.0 * lift - 4.0 * charge) + violent_shake) * viewport_scale
	mesh.rotation = -0.016 * lift + 0.032 * charge - 0.014 * follow_through + (0.0 if reduced else sin(time * 78.0) * 0.044 * (charge + recoil * 0.85))
	var light := 0.94 + 0.14 * lift + 0.12 * charge + (0.0 if reduced else recoil * 0.20)
	mesh.modulate = Color(light, light * (0.97 - recoil * 0.08), light * (0.94 - recoil * 0.12))

	if is_instance_valid(ghost_mesh):
		ghost_mesh.visible = not reduced
		ghost_mesh.scale = mesh.scale * (1.0 + 0.06 * charge + 0.08 * recoil)
		ghost_mesh.position = mesh.position + Vector2(sin(time * 84.0) * 14.0, -cos(time * 72.0) * 9.0) * (charge + recoil) * viewport_scale
		ghost_mesh.rotation = mesh.rotation * 1.25
		ghost_mesh.modulate = Color(1.15, 0.45, 0.42, (0.28 * charge + 0.35 * recoil) if not reduced else 0.0)

	if is_instance_valid(mesh_mat):
		if is_grid_sheet:
			var f_idx := 0
			if time >= IMPACT_TIME - 0.02:
				f_idx = 3
			elif time >= 0.38:
				f_idx = 2
			elif time >= 0.18:
				f_idx = 1
			var col := float(f_idx % 2) * 0.5
			var row := float(f_idx / 2) * 0.5
			mesh_mat.set_shader_parameter("uv_rect", Vector4(col + 0.006, row + 0.006, 0.488, 0.488))
		else:
			mesh_mat.set_shader_parameter("uv_rect", Vector4(0.0, 0.0, 1.0, 1.0))
		mesh_mat.set_shader_parameter("time_sec", time)
		mesh_mat.set_shader_parameter("distortion", 0.0 if reduced else (0.14 * charge + 0.48 * recoil))
		mesh_mat.set_shader_parameter("chroma", 0.0 if reduced else (0.24 * charge + 0.62 * recoil))
		mesh_mat.set_shader_parameter("blood_vignette", 0.0 if reduced else clampf(0.24 * charge + 0.78 * recoil, 0.0, 1.0))

	if is_instance_valid(tear_overlay):
		tear_overlay.queue_redraw()
	var fade := smoothstep(0.76, 0.95, time)
	var tint := 0.0 if reduced else recoil * 0.22 * (1.0 - fade)
	blackout.color = Color(0.45 * tint, 0.0, 0.0, maxf(tint, fade))


func _draw_tear_overlay() -> void:
	if GameState.reduced_flash or elapsed > 0.90:
		return
	var intensity := smoothstep(0.20, IMPACT_TIME, elapsed)
	if intensity <= 0.02:
		return
	for idx in range(5):
		var y := fmod(elapsed * 540.0 + idx * 74.0, size.y)
		var h := 1.0 + float(idx % 2) * 1.4
		tear_overlay.draw_rect(Rect2(0, y, size.x, h), Color(0.88, 0.10, 0.08, 0.08 * intensity))


func _process(delta: float) -> void:
	elapsed += delta
	if not hit_sent and elapsed >= IMPACT_TIME:
		hit_sent = true
		AudioManager.play_world_effect("capture_hit")
	apply_pose(elapsed)
	if elapsed >= DURATION:
		set_process(false)
		finished.emit()
