extends Node2D

signal phase_changed(phase: int)

enum Phase { LOW, WARNING, RISING, HIGH, EBB }
const DURATIONS := [24.0, 8.0, 12.0, 10.0, 12.0]
var phase := Phase.LOW
var phase_clock := 0.0
var clock := 0.0
var level := 0.0
var water: Polygon2D
var water_mat: ShaderMaterial
var wet_sand: Polygon2D
var foam: Line2D
var foam_inner: Line2D
var hazard: Area2D
var hazard_polygon: CollisionPolygon2D

const WATER_SHADER := """
shader_type canvas_item;
uniform float time_sec = 0.0;
uniform float tide_level = 0.0;
varying vec4 v_color;

void vertex() {
	v_color = COLOR;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	// UV.y goes from ~0.88 at shoreline to 1.00 at deep water bottom
	float shore_t = clamp((UV.y - 0.88) / 0.12, 0.0, 1.0);
	float t = time_sec;
	// Multi-layered rolling night ocean waves flowing toward the black sand
	float swell1 = sin(UV.x * 26.0 - t * 1.55 + shore_t * 11.0);
	float swell2 = cos(UV.x * 42.0 + t * 1.15 - shore_t * 17.0);
	float n = noise2(vec2(UV.x * 18.0 + t * 0.18, shore_t * 10.0 + t * 0.42));
	float n2 = noise2(vec2(UV.x * 36.0 - t * 0.28, shore_t * 18.0 + t * 0.65));
	vec2 distort = vec2(
		(swell1 * 0.0024 + (n - 0.5) * 0.0042),
		(swell2 * 0.0018 + (n2 - 0.5) * 0.0030)
	);
	vec2 sample_uv = clamp(UV + distort, vec2(0.002, 0.86), vec2(0.998, 0.998));
	vec4 base = texture(TEXTURE, sample_uv);
	// Darken deep water, keep cold moonlit translucent emerald-slate tint near shallow wash
	vec3 shallow_col = vec3(0.11, 0.17, 0.18);
	vec3 deep_col = vec3(0.035, 0.068, 0.082);
	vec3 sea = mix(base.rgb * 0.72 + shallow_col * 0.35, base.rgb * 0.52 + deep_col * 0.55, smoothstep(0.05, 0.78, shore_t));
	// Moonlit silver-green wave crest shimmer
	float crest = smoothstep(0.55, 0.95, 0.5 + 0.32 * swell1 + 0.18 * swell2 + 0.35 * (n2 - 0.5));
	sea += vec3(0.24, 0.32, 0.31) * crest * (0.28 + 0.25 * (1.0 - shore_t));
	// Approaching rolling surf foam bands
	float band = sin(shore_t * 22.0 + t * 2.2 + n * 4.5);
	float mid_foam = smoothstep(0.80, 0.98, band) * smoothstep(0.70, 0.08, shore_t) * n2;
	// Lacy breaking whitewash right at shoreline edge
	float edge_foam = smoothstep(0.16, 0.0, shore_t) * (0.55 + 0.45 * n2);
	float foam_amt = clamp(edge_foam * 0.78 + mid_foam * 0.48, 0.0, 0.88);
	vec3 final_rgb = mix(sea, vec3(0.76, 0.82, 0.80), foam_amt);
	// Soft feathered wet alpha at very tip of wash
	float edge_alpha = smoothstep(0.0, 0.045, shore_t) * 0.93 + edge_foam * 0.35;
	COLOR = vec4(final_rgb, clamp(edge_alpha, 0.0, 0.96)) * v_color;
}
"""

func _ready() -> void:
	wet_sand = Polygon2D.new()
	wet_sand.color = Color(0.03, 0.045, 0.052, 0.44)
	wet_sand.z_index = 1
	add_child(wet_sand)
	water = Polygon2D.new()
	water.texture = preload("res://assets/tilesets/hacsa_beach_038.png")
	water.color = Color(0.86, 0.92, 0.90, 0.98)
	water.z_index = 2
	var sh := Shader.new()
	sh.code = WATER_SHADER
	water_mat = ShaderMaterial.new()
	water_mat.shader = sh
	water.material = water_mat
	add_child(water)
	foam = Line2D.new()
	foam.width = 4.2
	foam.default_color = Color(0.78, 0.85, 0.83, 0.62)
	foam.joint_mode = Line2D.LINE_JOINT_ROUND
	foam.z_index = 3
	add_child(foam)
	foam_inner = Line2D.new()
	foam_inner.width = 2.0
	foam_inner.default_color = Color(0.62, 0.74, 0.73, 0.34)
	foam_inner.joint_mode = Line2D.LINE_JOINT_ROUND
	foam_inner.z_index = 3
	add_child(foam_inner)
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
	if is_instance_valid(water_mat):
		water_mat.set_shader_parameter("time_sec", clock)
		water_mat.set_shader_parameter("tide_level", level)
	_update_shape()

func _update_shape() -> void:
	var surface := PackedVector2Array()
	var inner_foam := PackedVector2Array()
	var wet_strip := PackedVector2Array()
	var uvs := PackedVector2Array()
	var texture_size := water.texture.get_size()
	var steps := 32
	for index in range(steps + 1):
		var frac := float(index) / float(steps)
		var x := frac * 1280.0
		var surge := sin(clock * 1.45 + frac * 11.0) * 3.8 + sin(clock * 2.6 - frac * 19.0) * 1.9 + cos(clock * 0.85 + frac * 6.0) * 1.4
		var wy := waterline_at(x) + surge
		surface.append(Vector2(x, wy))
		inner_foam.append(Vector2(x, wy + 13.0 + sin(clock * 2.1 + frac * 15.0) * 2.6))
		wet_strip.append(Vector2(x, wy - 20.0 - absf(sin(clock * 0.7 + frac * 5.0)) * 7.0))
		uvs.append(Vector2(frac * texture_size.x, texture_size.y * 0.88))
	foam.points = surface
	foam_inner.points = inner_foam
	# Dark glossy wet-sand margin slightly ahead of the receding/advancing foam line
	var wet_poly := wet_strip.duplicate()
	for i in range(surface.size() - 1, -1, -1):
		wet_poly.append(surface[i] + Vector2(0, 6.0))
	wet_sand.polygon = wet_poly
	surface.append(Vector2(1280, 760))
	surface.append(Vector2(0, 760))
	uvs.append(texture_size)
	uvs.append(Vector2(0, texture_size.y))
	water.polygon = surface
	water.uv = uvs
	hazard_polygon.set_deferred("polygon", surface)
