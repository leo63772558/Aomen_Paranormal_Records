extends Control

signal removed
const SCREWS := [Vector2(179, 162), Vector2(409, 162)]
const HEADS := [Rect2(415, 391, 136, 136), Rect2(1034, 391, 136, 136)]
const BRACKET_RECT := Rect2(138, 126, 306, 74)
const SCREW_HEAD_TEX := preload("res://assets/props/crypt_screw_head_v10.png")

var background: Texture2D
var pliers_tex: Texture2D
var turns := [0.0, 0.0]
var loose := [false, false]
var ratchet_clicks := [0, 0]
var bracket_dropping := false
var bracket_drop := 0.0
var hover_screw := -1
var pulse_clock := 0.0
var feedback := "用随身工具钳逐一咬紧并旋出铁扣上的两枚锈蚀一字螺钉。"
var focus_suspended := false
var focus_previous_mode := Node.PROCESS_MODE_INHERIT

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not focus_suspended:
		focus_previous_mode = process_mode
		focus_suspended = true
		process_mode = Node.PROCESS_MODE_DISABLED
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and focus_suspended:
		process_mode = focus_previous_mode
		focus_suspended = false

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	background = load("res://assets/props/crypt_door_clip_026.png")
	pliers_tex = DemoItems.texture("multitool_pliers")

func _process(delta: float) -> void:
	pulse_clock += delta
	if not (loose[0] and loose[1]):
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover_screw = -1
		for i in range(SCREWS.size()):
			if not loose[i] and event.position.distance_to(SCREWS[i]) < 41.0:
				hover_screw = i
				break
		return
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	for i in range(SCREWS.size()):
		if event.position.distance_to(SCREWS[i]) < 41.0 and not loose[i]:
			loose[i] = true
			ratchet_clicks[i] = 1
			AudioManager.play_world_effect("tool_clink")
			var fast_test := (GameState.profile == "test" or DisplayServer.get_name() == "headless")
			var turn_duration := 0.34 if fast_test else 0.88
			var turn := create_tween()
			turn.tween_method(_set_turn.bind(i), 0.0, 1.0, turn_duration).set_trans(Tween.TRANS_LINEAR)
			turn.tween_callback(_on_screw_finished.bind(i))
			feedback = "工具钳咬紧锈钉边缘，正逆时针发力旋出第一枚螺钉……" if not (loose[0] and loose[1]) else "工具钳夹紧最后一枚锈钉，锈渣簌簌掉落……"
			accept_event()
			return

func _set_turn(value: float, screw: int) -> void:
	turns[screw] = value
	var step_count: int = ratchet_clicks[screw]
	if value >= 0.25 and step_count < 2:
		ratchet_clicks[screw] = 2
		AudioManager.play_world_effect("lock_mechanism")
	elif value >= 0.50 and step_count < 3:
		ratchet_clicks[screw] = 3
		AudioManager.play_world_effect("tool_clink")
	elif value >= 0.72 and step_count < 4:
		ratchet_clicks[screw] = 4
		AudioManager.play_world_effect("metal_spring")
	queue_redraw()

func _on_screw_finished(screw: int) -> void:
	turns[screw] = 1.0
	if loose[0] and loose[1] and float(turns[0]) >= 0.999 and float(turns[1]) >= 0.999 and not bracket_dropping:
		bracket_dropping = true
		feedback = "两枚锈钉全部旋落！生锈铁扣失去固定，沉重坠下……"
		AudioManager.play_world_effect("iron_slam")
		var fast_test := (GameState.profile == "test" or DisplayServer.get_name() == "headless")
		var drop_duration := 0.16 if fast_test else 0.42
		var drop_tw := create_tween()
		drop_tw.tween_method(_set_bracket_drop, 0.0, 1.0, drop_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		drop_tw.tween_callback(func(): removed.emit())
	elif not (loose[0] and loose[1]):
		feedback = "第一枚锈钉已旋出落地。继续拧下另一端锈钉。"
	queue_redraw()

func _set_bracket_drop(value: float) -> void:
	bracket_drop = value
	queue_redraw()

func _ratchet_state(t: float) -> Dictionary:
	var clamped_t := clampf(t, 0.0, 0.72)
	var phase_len := 0.24
	var step_idx := mini(2, int(floor(clamped_t / phase_len)))
	var local := clampf((clamped_t - float(step_idx) * phase_len) / phase_len, 0.0, 1.0)
	var stroke_ratio := 0.68
	var stroke_progress := 0.0
	var jaw_open := 0.0
	var pliers_reposition := 0.0
	if local <= stroke_ratio:
		var s := local / stroke_ratio
		stroke_progress = 1.0 - pow(1.0 - s, 2.2)
		jaw_open = 0.0
		pliers_reposition = stroke_progress
	else:
		var r := (local - stroke_ratio) / (1.0 - stroke_ratio)
		stroke_progress = 1.0
		jaw_open = sin(r * PI)
		pliers_reposition = 1.0 - (0.5 - 0.5 * cos(r * PI))
	var turn_arc := -1.42
	var screw_angle := (float(step_idx) + stroke_progress) * turn_arc
	var pliers_angle := 0.30 + pliers_reposition * (turn_arc * 0.58)
	return {
		"screw_angle": screw_angle,
		"pliers_angle": pliers_angle,
		"jaw_open": jaw_open,
		"extract": clampf(clamped_t / 0.72, 0.0, 1.0)
	}

func _draw_threaded_hole(p: Vector2, reveal: float) -> void:
	var a := clampf(reveal, 0.0, 1.0)
	draw_circle(p, 23.0, Color(0.10, 0.068, 0.044, 0.96 * a))
	draw_arc(p, 22.0, 0.0, TAU, 24, Color(0.26, 0.16, 0.09, 0.80 * a), 1.8, true)
	draw_circle(p, 15.0, Color(0.025, 0.02, 0.015, 0.98 * a))
	for ring_r in [12.5, 9.5, 6.5]:
		draw_arc(p, ring_r, 0.15, PI * 1.15, 16, Color(0.24, 0.20, 0.16, 0.48 * a), 1.0, true)

func _draw_real_rusted_screw(head_pos: Vector2, hole_pos: Vector2, angle: float, extract: float, r_scale: float, alpha: float, detached: bool) -> void:
	# Realistic emerging threaded dark iron shank behind the REAL painted screw head texture!
	if not detached:
		var shadow_pos := hole_pos + Vector2(4.0, 6.0) * extract + Vector2(2.0, 2.5)
		draw_circle(shadow_pos, 22.0 * r_scale, Color(0.02, 0.015, 0.01, 0.45 * alpha))
		var shaft_vec := head_pos - hole_pos
		var shaft_len := shaft_vec.length()
		if shaft_len > 1.2:
			var dir := shaft_vec / shaft_len
			var side := Vector2(-dir.y, dir.x)
			var half_w := 6.6
			draw_colored_polygon(PackedVector2Array([
				hole_pos - side * half_w, hole_pos + side * half_w,
				head_pos + side * half_w, head_pos - side * half_w
			]), Color(0.16, 0.13, 0.10, alpha))
			var thread_count := maxi(2, int(shaft_len / 2.6))
			for k in range(thread_count):
				var frac := (float(k) + 0.4) / float(thread_count)
				var mid := hole_pos.lerp(head_pos, frac)
				draw_line(mid - side * (half_w + 0.7), mid + side * (half_w + 0.7), Color(0.05, 0.04, 0.03, 0.90 * alpha), 1.5, true)
				draw_line(mid - side * (half_w * 0.7) + dir * 1.1, mid + side * (half_w * 0.7) + dir * 1.1, Color(0.46, 0.36, 0.25, 0.72 * alpha), 0.9, true)
	else:
		var shank_dir := Vector2(cos(angle + 1.1), sin(angle + 1.1))
		var shank_end := head_pos + shank_dir * 16.0 * r_scale
		draw_line(head_pos, shank_end, Color(0.18, 0.15, 0.12, alpha), 8.5 * r_scale, true)
	# Draw the REAL painted rusted straight-slotted screw head from crypt_door_clip_026.png (ZERO cartoon vector screw!)
	var d_sz := 49.0 * r_scale
	draw_set_transform(head_pos, angle, Vector2.ONE)
	draw_circle(Vector2(2.0, 2.5), d_sz * 0.46, Color(0, 0, 0, 0.42 * alpha))
	draw_texture_rect(SCREW_HEAD_TEX, Rect2(-d_sz * 0.5, -d_sz * 0.5, d_sz, d_sz), false, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_real_pliers(grip_pos: Vector2, pliers_angle: float, jaw_open: float, retract: float) -> void:
	if pliers_tex == null:
		return
	var alpha := clampf(1.0 - retract * 1.25, 0.0, 1.0)
	if alpha <= 0.02:
		return
	var pull_offset := Vector2(cos(pliers_angle + 0.55), sin(pliers_angle + 0.55)) * (retract * 48.0 + jaw_open * 7.0)
	# Use the REAL painted multitool pliers asset gripping the screw head — ZERO cartoon vector lines!
	var pl_size := Vector2(138.0, 108.0)
	# Main weathered steel pliers sprite clamped directly over the screw head
	draw_set_transform(grip_pos + pull_offset + Vector2(6.0, 9.0), pliers_angle - 0.18, Vector2.ONE)
	draw_texture_rect(pliers_tex, Rect2(-20.0, -26.0, pl_size.x, pl_size.y), false, Color(0.0, 0.0, 0.0, 0.44 * alpha))
	draw_set_transform(grip_pos + pull_offset, pliers_angle - 0.18, Vector2.ONE)
	draw_texture_rect(pliers_tex, Rect2(-20.0, -26.0, pl_size.x, pl_size.y), false, Color(0.95, 0.92, 0.86, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_rust_dust(p: Vector2, screw_idx: int, t: float) -> void:
	for k in range(10):
		var trigger_t := float(k % 3) * 0.24 + 0.04
		if t < trigger_t:
			continue
		var age := t - trigger_t
		if age > 0.42:
			continue
		var seed_ang := float(screw_idx * 17 + k * 41) * 0.73
		var vx := cos(seed_ang) * (18.0 + float(k % 4) * 9.0)
		var vy := sin(seed_ang) * 14.0 - 8.0
		var pos := p + Vector2(vx * age, vy * age + 130.0 * age * age)
		var a := clampf(1.0 - age / 0.42, 0.0, 1.0)
		var col := Color(0.42, 0.22, 0.11, 0.85 * a) if k % 2 == 0 else Color(0.24, 0.18, 0.14, 0.80 * a)
		draw_circle(pos, 1.3 + float(k % 3) * 0.6, col)

func _draw() -> void:
	draw_texture_rect(background, Rect2(Vector2.ZERO, size), false)

	if bracket_drop > 0.001 and background != null:
		draw_rect(BRACKET_RECT, Color(0.045, 0.04, 0.032, 0.88))
		draw_rect(BRACKET_RECT, Color(0.18, 0.14, 0.10, 0.55), false, 1.5)
		for p_hole in SCREWS:
			_draw_threaded_hole(p_hole, 1.0)
		var tex_sz := background.get_size()
		var sx := tex_sz.x / maxf(1.0, size.x)
		var sy := tex_sz.y / maxf(1.0, size.y)
		var src_region := Rect2(
			BRACKET_RECT.position.x * sx,
			BRACKET_RECT.position.y * sy,
			BRACKET_RECT.size.x * sx,
			BRACKET_RECT.size.y * sy
		)
		var drop_offset := Vector2(12.0 * bracket_drop, 196.0 * bracket_drop)
		var pivot := BRACKET_RECT.get_center() + drop_offset
		draw_set_transform(pivot, 0.22 * bracket_drop, Vector2.ONE)
		var local_rect := Rect2(-BRACKET_RECT.size * 0.5, BRACKET_RECT.size)
		draw_rect(local_rect.grow(2.0), Color(0.0, 0.0, 0.0, 0.42))
		draw_texture_rect_region(background, local_rect, src_region)
		for p_hole in SCREWS:
			var local_hole: Vector2 = (p_hole as Vector2) - BRACKET_RECT.get_center()
			draw_circle(local_hole, 18.5, Color(0.04, 0.03, 0.025, 0.96))
			draw_arc(local_hole, 18.5, 0.0, TAU, 20, Color(0.28, 0.17, 0.09, 0.80), 1.5, true)
		draw_set_transform(Vector2.ZERO)
	else:
		for i in range(SCREWS.size()):
			var p: Vector2 = SCREWS[i]
			if not loose[i]:
				var pulse := 0.5 + 0.5 * sin(pulse_clock * 4.2 + float(i) * 1.4)
				var is_h := (hover_screw == i)
				var ring_col := Color(0.92, 0.78, 0.44, 0.72 if is_h else (0.22 + 0.20 * pulse))
				draw_arc(p, 25.0 if not is_h else 27.0, 0.0, TAU, 28, ring_col, 1.8 if is_h else 1.2, true)
				continue
			var t: float = float(turns[i])
			_draw_threaded_hole(p, minf(1.0, t * 4.5 + 0.35))
			_draw_rust_dust(p, i, t)
			if t <= 0.72:
				var rs := _ratchet_state(t)
				var extract: float = float(rs.extract)
				var head_pos := p + Vector2(-2.5, -14.5) * extract
				var r_scale := 1.0 + 0.12 * extract
				_draw_real_rusted_screw(head_pos, p, float(rs.screw_angle), extract, r_scale, 1.0, false)
				var retract := clampf((t - 0.66) / 0.08, 0.0, 1.0)
				_draw_real_pliers(head_pos, float(rs.pliers_angle), float(rs.jaw_open), retract)
			else:
				var u := clampf((t - 0.72) / 0.28, 0.0, 1.0)
				var side_vx := -24.0 if i == 0 else 28.0
				var base_pos := p + Vector2(-2.5, -14.5)
				var pop_pos := base_pos + Vector2(side_vx * u, -16.0 * u + 215.0 * u * u)
				var final_angle := -4.14 - u * 5.2
				var alpha := clampf(1.0 - maxf(0.0, u - 0.78) * 4.5, 0.0, 1.0)
				_draw_real_rusted_screw(pop_pos, p, final_angle, 1.0, 1.12 - 0.10 * u, alpha, true)

	var font := get_theme_default_font()
	draw_rect(Rect2(0, 304, 618, 34), Color(0.015, 0.027, 0.023, 0.94))
	draw_string(font, Vector2(15, 325), feedback, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("eee0bc"))
	draw_string(font, Vector2(535, 325), "Esc 返回", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("cfc3a6"))
