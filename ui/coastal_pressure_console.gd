extends Control

const IDS := ["inlet", "bypass", "bleed"]
const WHEEL_CENTERS := [Vector2(108, 150), Vector2(318, 112), Vector2(318, 224)]
const NEEDLE_ANGLES := [1.04, 0.44, -0.40, -1.04]
const MACHINERY := preload("res://assets/tilesets/coastal_pressure_gallery_060.png")
const FEED := [Vector2(38, 150), Vector2(203, 150)]
const BYPASS := [Vector2(203, 150), Vector2(203, 112), Vector2(393, 112)]
const DRAIN := [Vector2(203, 150), Vector2(203, 224), Vector2(462, 224)]

var gallery: Node2D
var wheels: Array[Node2D] = []
var captions: Array[Button] = []
var wheel_labels: Array[Label] = []
var gauge_angle := 1.04
var message: Label
var gauge_value: Label
var stage := 0
var turn_progress := 0.0
var turning := -1
var resisted := false
var flow_clock := 0.0
var drain_runoff := 0.0
var flow_redraw := Callable()
var dragging_wheel := -1
var drag_start_pos := Vector2.ZERO
var drag_preview_angle := 0.0
var steam_puffs: Array[Dictionary] = []


func setup(scene: Node2D) -> Control:
	gallery = scene
	return self


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_label("调压台", Vector2(24, 12), 22)
	_label("压力归零，检修柜才会解锁。", Vector2(125, 18), 14)
	_label("来水", Vector2(29, 104), 13)
	_label("分流", Vector2(367, 76), 13)
	_label("侧沟", Vector2(497, 259), 13)

	var wheel_regions := [
		Rect2(346, 298, 113, 113),
		Rect2(1220, 263, 116, 116),
		Rect2(1302, 171, 35, 42)
	]
	for index in range(3):
		var center: Vector2 = WHEEL_CENTERS[index]
		var region: Rect2 = wheel_regions[index]
		var button := Button.new()
		button.position = center - Vector2(38, 37)
		button.size = Vector2(76, 74)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var rim := StyleBoxFlat.new()
		rim.bg_color = Color(0.80, 0.68, 0.48, 0.11)
		rim.border_color = Color("b09a69")
		rim.set_border_width_all(1)
		rim.set_corner_radius_all(12)
		button.add_theme_stylebox_override("hover", rim)
		button.add_theme_stylebox_override("focus", rim)
		button.pressed.connect(_turn.bind(index))
		button.gui_input.connect(_on_wheel_gui_input.bind(index))
		add_child(button)
		captions.append(button)

		var wheel: Node2D
		if index < 2:
			var sp := _art(region, center, Vector2.ONE * 68.0)
			sp.material = _round_crop(region, false)
			wheel = sp
		else:
			wheel = _make_hd_bleed_valve(center)
		wheels.append(wheel)

		var nameplate := _label("", center + Vector2(-56, 36 if index == 0 else -65), 14)
		if index == 2:
			nameplate.position.y = center.y + 30
		nameplate.size.x = 112
		nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wheel_labels.append(nameplate)

	var dial_region := Rect2(1277, 88, 76, 77)
	var dial := _art(dial_region, Vector2(518, 119), Vector2(105, 105))
	dial.material = _round_crop(dial_region)
	# Draw animated details and crisp stone drainage channel on their own canvas.
	var details := Control.new()
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.draw.connect(_draw_details.bind(details))
	add_child(details)
	gauge_value = _label("", Vector2(451, 175), 15)
	gauge_value.size.x = 133
	gauge_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	message = _label("按住或点击手轮调压；看水流与表针变化。", Vector2(24, 285), 14)
	_label("Esc 返回", Vector2(514, 301), 13)
	_refresh()
	flow_redraw = details.queue_redraw
	pivot_offset = Vector2(300, 160)
	scale = Vector2(0.97, 0.97)
	var pop := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	pop.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE)


func _label(value: String, at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _make_hd_bleed_valve(center: Vector2) -> Node2D:
	var node := Node2D.new()
	node.position = center
	var body := Polygon2D.new()
	var ring_pts := PackedVector2Array()
	for i in range(24):
		var a := TAU * i / 24.0
		ring_pts.append(Vector2(cos(a), sin(a)) * 24.0)
	body.polygon = ring_pts
	body.color = Color("463829")
	node.add_child(body)
	var inner := Polygon2D.new()
	var in_pts := PackedVector2Array()
	for i in range(24):
		var a := TAU * i / 24.0
		in_pts.append(Vector2(cos(a), sin(a)) * 17.0)
	inner.polygon = in_pts
	inner.color = Color("231c15")
	node.add_child(inner)
	for angle in [0.0, PI / 3.0, 2.0 * PI / 3.0]:
		var spoke := Line2D.new()
		spoke.points = PackedVector2Array([Vector2.from_angle(angle) * -21.0, Vector2.from_angle(angle) * 21.0])
		spoke.width = 4.2
		spoke.default_color = Color("b59663")
		spoke.antialiased = true
		node.add_child(spoke)
	var rim := Line2D.new()
	var rim_pts := PackedVector2Array(ring_pts)
	rim_pts.append(ring_pts[0])
	rim.points = rim_pts
	rim.width = 4.5
	rim.default_color = Color("c8a974")
	rim.antialiased = true
	node.add_child(rim)
	var bar := Polygon2D.new()
	bar.polygon = PackedVector2Array([Vector2(-26, -5), Vector2(26, -5), Vector2(26, 5), Vector2(-26, 5)])
	bar.color = Color("dfc189")
	node.add_child(bar)
	var cap := Polygon2D.new()
	var cap_pts := PackedVector2Array()
	for i in range(12):
		var a := TAU * i / 12.0
		cap_pts.append(Vector2(cos(a), sin(a)) * 6.5)
	cap.polygon = cap_pts
	cap.color = Color("7b5e3b")
	node.add_child(cap)
	add_child(node)
	return node


func _on_wheel_gui_input(event: InputEvent, index: int) -> void:
	if captions[index].disabled or gallery.scene_action_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging_wheel = index
			drag_start_pos = event.position
			drag_preview_angle = 0.0
		elif dragging_wheel == index:
			var finished_drag := absf(drag_preview_angle) > 0.25
			dragging_wheel = -1
			drag_preview_angle = 0.0
			if finished_drag:
				captions[index].accept_event()
				_turn(index)
	elif event is InputEventMouseMotion and dragging_wheel == index:
		var delta_vec: Vector2 = event.position - drag_start_pos
		drag_preview_angle = clampf((delta_vec.x - delta_vec.y) * 0.025, 0.0, PI * 0.48)
		wheels[index].rotation = drag_preview_angle


func _art(region: Rect2, center: Vector2, dimensions: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	var crop := AtlasTexture.new()
	crop.atlas = MACHINERY
	crop.region = region
	crop.filter_clip = true
	sprite.texture = crop
	sprite.position = center
	sprite.scale = dimensions / region.size
	add_child(sprite)
	return sprite


func _round_crop(region: Rect2, oval := false) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec4 part;
uniform vec2 radius = vec2(0.49);
void fragment() {
	vec2 offset = ((UV - part.xy) / part.zw - 0.5) / radius;
	COLOR.a *= 1.0 - smoothstep(0.93, 1.0, length(offset));
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var size := MACHINERY.get_size()
	material.set_shader_parameter("part", Vector4(region.position.x / size.x, region.position.y / size.y, region.size.x / size.x, region.size.y / size.y))
	if oval:
		material.set_shader_parameter("radius", Vector2(0.39, 0.49))
	return material


func _refresh() -> void:
	stage = gallery.pressure_stage()
	gauge_angle = NEEDLE_ANGLES[stage]
	var names := ["进水轮", "旁通轮", "泄压阀"]
	var poses := ["关闭来水", "接通分流", "打开泄压"]
	for index in range(3):
		var done := index < stage
		wheel_labels[index].text = names[index] + (" ✓" if done else "")
		captions[index].tooltip_text = poses[index]
		captions[index].disabled = done
		wheels[index].rotation = PI / 2.0 if done else 0.0
	gauge_value.text = ["高压", "余压", "低压", "零压 · 柜锁已开"][stage]


func _turn(index: int) -> void:
	if not gallery.scene_action_active:
		await gallery._operate_valve(IDS[index])


func begin_turn(id: String, valid: bool) -> void:
	turning = IDS.find(id)
	turn_progress = 0.0
	resisted = not valid
	if turning >= 0 and not GameState.reduced_flash:
		var origin: Vector2 = WHEEL_CENTERS[turning]
		for _i in range(7):
			var a := randf_range(-PI * 0.9, -PI * 0.1)
			var spd := randf_range(24.0, 62.0)
			steam_puffs.append({
				"pos": origin + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0)),
				"vel": Vector2.from_angle(a) * spd,
				"radius": randf_range(4.0, 9.0),
				"life": randf_range(0.32, 0.58),
				"max_life": 0.58,
				"color": Color("e09c7c") if resisted else Color("c7ded8")
			})


func animate_turn(progress: float) -> void:
	turn_progress = progress
	if resisted:
		var kick := sin(progress * PI)
		wheels[turning].rotation = 0.37 * kick
		gauge_angle = NEEDLE_ANGLES[stage] + 0.17 * kick
	else:
		wheels[turning].rotation = PI / 2.0 * progress
		gauge_angle = lerpf(NEEDLE_ANGLES[stage], NEEDLE_ANGLES[stage + 1], progress)


func finish_turn(line: String) -> void:
	if turning == 2 and not resisted:
		drain_runoff = 1.4
	turning = -1
	_refresh()
	message.text = line


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	flow_clock += delta
	drain_runoff = maxf(0.0, drain_runoff - delta)
	if not steam_puffs.is_empty():
		var next_puffs: Array[Dictionary] = []
		for p in steam_puffs:
			p["life"] = float(p["life"]) - delta
			if float(p["life"]) > 0.0:
				p["pos"] = Vector2(p["pos"]) + Vector2(p["vel"]) * delta
				p["radius"] = float(p["radius"]) + delta * 14.0
				next_puffs.append(p)
		steam_puffs = next_puffs
	if flow_redraw.is_valid():
		flow_redraw.call()


func _draw() -> void:
	for route in [FEED, BYPASS, DRAIN]:
		draw_polyline(PackedVector2Array(route), Color("121716"), 14, true)
		draw_polyline(PackedVector2Array(route), Color("70604b"), 11, true)
		draw_polyline(PackedVector2Array(route), Color("28332c"), 7, true)
	draw_circle(Vector2(203, 150), 7.0, Color("85715a"), true, -1.0, true)
	draw_circle(Vector2(393, 112), 6.0, Color("887458"), true, -1.0, true)
	# Crisp high-res stone drainage trough with iron grate bars (replaces blurry crop).
	var trough := Rect2(448, 208, 144, 46)
	draw_rect(trough, Color("1a211e"), true)
	draw_rect(Rect2(452, 213, 136, 36), Color("26322d"), true)
	for gx in range(462, 584, 14):
		draw_line(Vector2(gx, 211), Vector2(gx - 4, 251), Color("4e564e"), 2.2, true)
	draw_rect(trough, Color("78684b"), false, 2.2)


func _draw_details(canvas: Control) -> void:
	if stage == 0:
		_draw_flow(canvas, FEED, false, Color("c9b288"))
	if stage == 2 or (turning == 1 and not resisted):
		_draw_flow(canvas, BYPASS, false, Color("acc0a8"))
	if turning == 2 and not resisted or drain_runoff > 0.0:
		_draw_flow(canvas, DRAIN, false, Color("b3c9bb"))
		_draw_flow(canvas, [Vector2(467, 224), Vector2(582, 242)], false, Color("acc1b1"))
	elif turning >= 1 and resisted:
		var rejected_route: Array = BYPASS if turning == 1 else DRAIN
		_draw_flow(canvas, rejected_route, true, Color("d99774"))

	var pivot := Vector2(518, 119)
	canvas.draw_circle(pivot, 40, Color("352f25"), true, -1.0, true)
	for index in range(11):
		var angle := lerpf(-1.08, 1.08, index / 10.0)
		var outward := Vector2.UP.rotated(angle)
		var tint := Color("d5ae80") if index < 8 else Color("bd7d62")
		canvas.draw_line(pivot + outward * 29.0, pivot + outward * 35.0, tint, 1.7, true)
	var tremble := sin(flow_clock * 27.0) * (0.025 * float(3 - stage)) if (stage < 3 and turning < 0 and not GameState.reduced_flash) else 0.0
	canvas.draw_line(pivot, pivot + Vector2.UP.rotated(gauge_angle + tremble) * 30.0, Color("f3dfab"), 2.5, true)
	canvas.draw_circle(pivot, 4.0, Color("e7cf99"), true, -1.0, true)
	for p in steam_puffs:
		var c := Color(p["color"])
		c.a = clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0) * 0.42
		canvas.draw_circle(Vector2(p["pos"]), float(p["radius"]), c)


func _draw_flow(canvas: Control, route: Array, reverse: bool, tint: Color) -> void:
	var distance := 0.0
	for i in range(1, route.size()):
		var start: Vector2 = route[i - 1]
		var finish: Vector2 = route[i]
		var length := start.distance_to(finish)
		var shift := flow_clock * (-70.0 if reverse else 70.0) - distance
		for index in range(ceili(length / 21.0)):
			var along := fposmod(shift, 21.0) + index * 21.0
			if along < length - 4.0:
				var origin := start.lerp(finish, along / length)
				var direction := start.direction_to(finish) * (-1.0 if reverse else 1.0)
				var tip := origin + direction * 4.0
				canvas.draw_line(origin - direction.orthogonal() * 2.0, tip, tint, 1.3, true)
				canvas.draw_line(origin + direction.orthogonal() * 2.0, tip, tint, 1.3, true)
		distance += length
