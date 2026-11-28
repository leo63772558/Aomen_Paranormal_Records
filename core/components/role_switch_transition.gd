extends CanvasLayer

# Restrained, atmospheric dark-film role transition (NO green tactical HUD / sci-fi grid).
# Smooth fade & subtle camera ease with a comfortable 1.15s hold so players clearly read the switch.
signal completed

var active: bool = false
var backdrop: ColorRect
var plate_panel: PanelContainer
var role_label: Label
var sub_label: Label
var rule_line: ColorRect

var _accent: Color = Color("e4d6b4")
var _target_cam: Camera2D = null
var _orig_zoom: Vector2 = Vector2.ONE

static func play(host: Node, role_title: String, location_subtitle: String, accent := Color("e4d6b4")) -> Node:
	if DisplayServer.get_name() == "headless":
		return null
	var fx: CanvasLayer = preload("res://core/components/role_switch_transition.gd").new()
	fx.layer = 92
	fx.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(fx)
	fx.start_sequence(role_title, location_subtitle, accent)
	return fx

func start_sequence(role_title: String, location_subtitle: String, accent: Color) -> void:
	active = true
	_accent = accent

	var font := UiFont.title()

	backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.03, 0.03, 0.035, 0.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	# Clean, understated dark-charcoal cinematic title card (no green tint, no sci-fi HUD)
	plate_panel = PanelContainer.new()
	plate_panel.position = Vector2(150, 134)
	plate_panel.size = Vector2(340, 88)
	plate_panel.pivot_offset = Vector2(170, 44)
	plate_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate_panel.modulate.a = 0.0
	var plate_style := StyleBoxFlat.new()
	plate_style.bg_color = Color(0.055, 0.055, 0.06, 0.90)
	plate_style.border_color = Color(0.72, 0.67, 0.58, 0.55)
	plate_style.set_border_width_all(0)
	plate_style.border_width_top = 1
	plate_style.border_width_bottom = 1
	plate_style.content_margin_left = 20
	plate_style.content_margin_right = 20
	plate_style.content_margin_top = 12
	plate_style.content_margin_bottom = 12
	plate_panel.add_theme_stylebox_override("panel", plate_style)
	add_child(plate_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 7)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate_panel.add_child(vbox)

	role_label = Label.new()
	role_label.text = role_title
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.add_theme_font_override("font", font)
	role_label.add_theme_font_size_override("font_size", 20)
	role_label.add_theme_color_override("font_color", Color("ece5d4"))
	role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(role_label)

	var rule_wrap := CenterContainer.new()
	rule_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(rule_wrap)

	rule_line = ColorRect.new()
	rule_line.custom_minimum_size = Vector2(180, 1)
	rule_line.color = Color(0.76, 0.71, 0.62, 0.52)
	rule_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule_wrap.add_child(rule_line)

	sub_label = Label.new()
	sub_label.text = location_subtitle
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_override("font", font)
	sub_label.add_theme_font_size_override("font_size", 12)
	sub_label.add_theme_color_override("font_color", Color("b8b5ab"))
	sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sub_label)

	var vp: Viewport = get_viewport()
	_target_cam = vp.get_camera_2d() if vp != null else null
	_orig_zoom = _target_cam.zoom if is_instance_valid(_target_cam) else Vector2.ONE
	var reduced: bool = GameState.reduced_flash

	var tw: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	var fade_in_dur := 0.52
	var hold_dur := 2.10
	var fade_out_dur := 0.65

	# Smooth fade in + gentle subtle zoom pull
	tw.tween_property(backdrop, "color:a", 0.76, fade_in_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(plate_panel, "modulate:a", 1.0, fade_in_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_target_cam) and not reduced:
		tw.parallel().tween_method(_set_cam_zoom, _orig_zoom, _orig_zoom * 0.91, fade_in_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Comfortable readable hold — long enough for player to absorb the perspective shift!
	tw.tween_interval(hold_dur)

	# Smooth fade out back into the active character
	tw.tween_property(plate_panel, "modulate:a", 0.0, fade_out_dur * 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(backdrop, "color:a", 0.0, fade_out_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if is_instance_valid(_target_cam) and not reduced:
		tw.parallel().tween_method(_set_cam_zoom, _orig_zoom * 0.91, _orig_zoom, fade_out_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tw.tween_callback(func():
		if is_instance_valid(_target_cam):
			_target_cam.zoom = _orig_zoom
		active = false
		completed.emit()
		queue_free()
	)

func _set_cam_zoom(value: Vector2) -> void:
	if is_instance_valid(_target_cam):
		_target_cam.zoom = value

func _exit_tree() -> void:
	if active and is_instance_valid(_target_cam):
		_target_cam.zoom = _orig_zoom
	active = false
