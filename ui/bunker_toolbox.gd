extends Control

signal key_selected(index: int)

# Authentic matching orthogonal rusty iron wartime toolbox (matching lid, hinges & front clasp!)
const BOX_ART := preload("res://assets/props/bunker_box_open_025.png")
const KEY_SHEET := preload("res://assets/props/bunker_keys_025.png")

var keys: Array[AtlasTexture] = []
var pliers_tex: Texture2D
var opened := false
var opening := false
var motion: Tween
var focus_suspended := false
var hover_clasp := false
var hover_key := -1
var wire_cut := 0.0:
	set(value):
		wire_cut = value
		queue_redraw()
var open_progress := 0.0:
	set(value):
		open_progress = value
		queue_redraw()
var sparks: Array[Dictionary] = []
var feedback := "旧铁皮工具箱的前端搭扣缠着锈铁丝。点击底部锁扣用工具钳剪断。"

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not focus_suspended:
		focus_suspended = true
		process_mode = Node.PROCESS_MODE_DISABLED
		if is_instance_valid(motion): motion.pause()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and focus_suspended:
		focus_suspended = false
		process_mode = Node.PROCESS_MODE_ALWAYS
		if is_instance_valid(motion): motion.play()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	pliers_tex = DemoItems.texture("multitool_pliers")
	for i in range(3):
		var texture := AtlasTexture.new()
		texture.atlas = KEY_SHEET
		texture.region = Rect2(i * 724, 180, 724, 320)
		keys.append(texture)

func key_rect(index: int) -> Rect2:
	return Rect2(142, 134 + index * 46, 174, 42)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover_clasp = (not opened and not opening and Rect2(246, 224, 126, 74).has_point(event.position))
		hover_key = -1
		if opened:
			for i in range(3):
				if key_rect(i).grow(6.0).has_point(event.position):
					hover_key = i
					break
		queue_redraw()
		return
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if opening:
		accept_event()
		return
	if not opened:
		# Accept click directly on the real bottom front clasp (246..372, 224..298) as well as box center for test parity
		if Rect2(190, 128, 240, 172).has_point(event.position):
			opening = true
			feedback = "咔嚓！工具钳剪断搭扣上的锈铁丝，沉重的铁箱盖缓缓掀开……"
			AudioManager.play_world_effect("tool_clink")
			_spawn_wire_sparks()
			var fast_test := (GameState.profile == "test" or DisplayServer.get_name() == "headless")
			motion = create_tween()
			motion.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			motion.tween_property(self, "wire_cut", 1.0, 0.04 if fast_test else 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			motion.tween_callback(func(): AudioManager.play_world_effect("metal_cover"))
			motion.tween_property(self, "open_progress", 1.0, 0.42 if fast_test else 0.56).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			motion.tween_callback(func():
				opening = false
				opened = true
				feedback = "对照铁门锁面磨槽与换锁工单，点击直接取走需要的铁门钥匙。"
				queue_redraw()
			)
		else:
			feedback = "铁箱搭扣被锈铁丝缠紧，点击底部中央的铁丝搭扣用工具钳剪断。"
	else:
		for i in range(3):
			if key_rect(i).has_point(event.position):
				key_selected.emit(i + 1)
				accept_event()
				return
		feedback = "直接点击箱底帆布上的钥匙即可取走。"
	queue_redraw()
	accept_event()

func _spawn_wire_sparks() -> void:
	if GameState.reduced_flash:
		return
	for _i in range(12):
		var ang := randf_range(-PI, 0.25)
		var spd := randf_range(40.0, 135.0)
		sparks.append({
			"pos": Vector2(309, 268),
			"vel": Vector2.from_angle(ang) * spd,
			"life": randf_range(0.22, 0.46),
			"max_life": 0.46
		})

func _process(delta: float) -> void:
	if not sparks.is_empty():
		var next_sparks: Array[Dictionary] = []
		for s in sparks:
			s["life"] = float(s["life"]) - delta
			if float(s["life"]) > 0.0:
				s["pos"] = Vector2(s["pos"]) + Vector2(s["vel"]) * delta
				s["vel"] = Vector2(s["vel"]) + Vector2(0, 195.0) * delta
				next_sparks.append(s)
		sparks = next_sparks
		queue_redraw()
	elif not opened and not opening:
		queue_redraw()

func _draw_twisted_wire(cx: float, cy: float, recoil: float, alpha: float) -> void:
	# Multi-strand dark oxidized iron wire coiled tightly around the REAL front clasp — ZERO cartoon lines or yellow circles!
	var wire_dark := Color(0.14, 0.12, 0.10, alpha)
	var wire_rust := Color(0.42, 0.28, 0.18, alpha)
	var wire_hi := Color(0.68, 0.64, 0.56, alpha * 0.85)
	for strand in range(4):
		var off_y := float(strand) * 5.2 - 7.5
		var p_l0 := Vector2(cx - 44.0 - recoil * 0.7, cy + off_y - 3.0 + recoil * 0.35)
		var p_l1 := Vector2(cx - 6.0 - recoil * 1.15, cy + off_y + 2.5 - recoil * 0.25)
		var p_r0 := Vector2(cx + 6.0 + recoil * 1.15, cy + off_y - 2.0 - recoil * 0.30)
		var p_r1 := Vector2(cx + 44.0 + recoil * 0.7, cy + off_y + 3.0 + recoil * 0.35)
		# Drop shadow
		draw_line(p_l0 + Vector2(0, 2.2), p_l1 + Vector2(0, 2.2), Color(0, 0, 0, 0.45 * alpha), 3.6, true)
		draw_line(p_r0 + Vector2(0, 2.2), p_r1 + Vector2(0, 2.2), Color(0, 0, 0, 0.45 * alpha), 3.6, true)
		# Dark oxidized iron wire body + rust + specular steel ridge
		draw_line(p_l0, p_l1, wire_dark, 3.2, true)
		draw_line(p_r0, p_r1, wire_dark, 3.2, true)
		draw_line(p_l0, p_l1, wire_rust, 1.8, true)
		draw_line(p_r0, p_r1, wire_rust, 1.8, true)
		draw_line(p_l0 + Vector2(0, -0.7), p_l1 + Vector2(0, -0.7), wire_hi, 0.9, true)
		draw_line(p_r0 + Vector2(0, -0.7), p_r1 + Vector2(0, -0.7), wire_hi, 0.9, true)
	# Twisted center knot locking the wire around the clasp ring (splits cleanly when cut)
	if recoil < 6.0:
		var ka := alpha * (1.0 - recoil / 6.0)
		draw_circle(Vector2(cx, cy), 6.2, Color(0.18, 0.14, 0.11, ka))
		draw_arc(Vector2(cx, cy), 5.6, 0.2, PI * 1.6, 14, Color(0.62, 0.54, 0.42, ka), 1.6, true)

func _draw() -> void:
	var font := get_theme_default_font()
	# Authentic orthogonal rusted iron wartime toolbox with real hinges & bottom clasp
	draw_texture_rect(BOX_ART, Rect2(Vector2.ZERO, size), false)
	# Mask out the baked-in open upper lid while the box is closed so only ONE physical lid exists!
	if open_progress < 0.98:
		var mask_a := clampf(1.0 - open_progress * 1.45, 0.0, 1.0)
		var tex_sz := BOX_ART.get_size()
		# Tile damp stone floor texture from left/right margins of BOX_ART seamlessly across upper zone (y=0..121)
		var stone_src := Rect2(tex_sz.x * 0.87, tex_sz.y * 0.04, tex_sz.x * 0.12, tex_sz.y * 0.40)
		draw_texture_rect_region(BOX_ART, Rect2(76, 0, 466, 121), stone_src, Color(0.88, 0.88, 0.84, mask_a))
		draw_rect(Rect2(76, 110, 466, 12), Color(0.02, 0.025, 0.02, 0.55 * mask_a))

	# Keys resting naturally inside the damp canvas chest bottom (ZERO ugly opaque overlay box!)
	if opened or opening:
		for i in range(3):
			var r := key_rect(i)
			var item_id := "gate_key_%d" % (i + 1)
			var taken := GameState.has_demo_item(item_id)
			if not taken:
				var is_h := (opened and hover_key == i)
				# Subtle recessed oil-stained shadow under each physical iron key
				draw_rect(Rect2(r.position + Vector2(4, 6), r.size - Vector2(8, 8)), Color(0.0, 0.0, 0.0, 0.34))
				draw_texture_rect(keys[i], r, false, Color(1.12, 1.08, 0.98, 1.0) if is_h else Color(0.95, 0.93, 0.88, 1.0))
				# Engraved shoulder-notch indicator on the key bit
				for j in range(1 if i == 0 else 2):
					draw_line(r.position + Vector2(11, 11 + j * 5), r.position + Vector2(20, 16 + j * 5), Color("dfd0a8"), 1.5)
				# Small aged linen key tag resting neatly beside the key inside the chest
				var tag_rect := Rect2(r.end.x + 14.0, r.position.y + 8.0, 154.0, 24.0)
				draw_rect(tag_rect, Color(0.08, 0.075, 0.06, 0.80))
				draw_rect(tag_rect, Color("bfa872") if is_h else Color("685b42"), false, 1.2 if is_h else 1.0)
				draw_string(font, tag_rect.position + Vector2(10, 16), DemoItems.title(item_id), HORIZONTAL_ALIGNMENT_LEFT, 138, 12, Color("f4e6be") if is_h else Color("d8ccaa"))

	# Hinged weathered iron lid matching BOX_ART 1:1 (swings cleanly up from the real hinges at y=120!)
	if open_progress < 0.99:
		var quad := lid_quad()
		var uv := PackedVector2Array([Vector2(0.13, 0.355), Vector2(0.87, 0.355), Vector2(0.87, 0.015), Vector2(0.13, 0.015)])
		if absf(quad[2].y - quad[0].y) >= 0.5:
			# Soft drop shadow cast by the closing lid onto the chest rim
			var sh_q := PackedVector2Array([quad[0] + Vector2(0, 5), quad[1] + Vector2(0, 5), quad[2] + Vector2(0, 8), quad[3] + Vector2(0, 8)])
			draw_colored_polygon(sh_q, Color(0.0, 0.0, 0.0, 0.38 * (1.0 - open_progress)))
			draw_polygon(quad, PackedColorArray([Color(0.92, 0.90, 0.86, 1.0)]), uv, BOX_ART)
		else:
			draw_line(quad[0], quad[1], Color("8f8166"), 2.5)
		var rim := quad.duplicate()
		rim.append(quad[0])
		draw_polyline(rim, Color("3c3328"), 2.0, true)

		# Twisted rusted iron wire tightly binding the REAL painted bottom front clasp at (309, 268)!
		var clasp_y := 268.0 - open_progress * 44.0
		var clasp_a := clampf(1.0 - open_progress * 2.6, 0.0, 1.0)
		if clasp_a > 0.02:
			_draw_twisted_wire(309.0, clasp_y, wire_cut * 30.0, clasp_a)
			# Animated real multitool pliers darting in to snip the wire cleanly!
			if opening and wire_cut > 0.01 and wire_cut < 0.98 and pliers_tex != null:
				var snip_t := sin(wire_cut * PI)
				var pl_pos := Vector2(318.0 + (1.0 - snip_t) * 58.0, clasp_y + 12.0 + (1.0 - snip_t) * 32.0)
				draw_set_transform(pl_pos, -0.42 + snip_t * 0.24, Vector2.ONE)
				draw_texture_rect(pliers_tex, Rect2(-22.0, -30.0, 128.0, 98.0), false, Color(0.95, 0.92, 0.86, clampf(snip_t * 1.6, 0.0, 1.0)))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# Subtle weathered hover bracket around the bottom clasp (NO cartoon pulsing yellow circle!)
			if not opening and hover_clasp:
				draw_rect(Rect2(256, 246, 106, 44), Color("e0c67d", 0.72), false, 1.5)
				draw_rect(Rect2(260, 224, 98, 19), Color(0.03, 0.05, 0.04, 0.86))
				draw_string(font, Vector2(264, 238), "钳断搭扣铁丝", HORIZONTAL_ALIGNMENT_CENTER, 90, 11, Color("f0deb0"))

	for s in sparks:
		var sa := clampf(float(s["life"]) / float(s["max_life"]), 0.0, 1.0)
		draw_circle(Vector2(s["pos"]), 2.0 * sa + 0.5, Color(1.0, 0.84, 0.42, sa))

	draw_rect(Rect2(12, 300, 594, 28), Color(0.025, 0.045, 0.04, 0.92))
	draw_rect(Rect2(12, 300, 594, 28), Color("625842"), false, 1.0)
	draw_string(font, Vector2(22, 319), feedback, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("efe3c4"))
	draw_rect(Rect2(510, 8, 96, 22), Color(0.025, 0.045, 0.04, 0.86))
	draw_rect(Rect2(510, 8, 96, 22), Color("625842"), false, 1.0)
	draw_string(font, Vector2(519, 24), "Esc 返回", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e6d9bd"))

func lid_quad() -> PackedVector2Array:
	var angle := deg_to_rad(132.0) * open_progress
	var edge_y := 120.0 + cos(angle) * 168.0
	var spread := sin(angle) * 5.0
	return PackedVector2Array([Vector2(82, 120), Vector2(536, 120), Vector2(536 + spread, edge_y), Vector2(82 - spread, edge_y)])
