extends CanvasLayer
class_name ChapterLandmarkTransition

## Reusable Macau landmark inter-chapter transition card with azulejo street plaque
## styling, dark night curtain, and non-flashing room handoff.

signal completed

var _curtain: ColorRect
var _card: PanelContainer
var _badge_lbl: Label
var _title_lbl: Label
var _sub_lbl: Label
var _hint_lbl: Label
var _tween: Tween
var _waiting_input := false
var _closing := false
var _fast_mode := false


static func play(
	host: Node,
	chapter_badge: String,
	route_title: String,
	subtitle: String,
	second_beat: String = "",
	sfx_id: String = "entrance_door",
	image_path: String = ""
) -> ChapterLandmarkTransition:
	var fx := preload("res://core/components/chapter_landmark_transition.gd").new()
	fx.layer = 20
	fx.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(fx)
	fx._start(chapter_badge, route_title, subtitle, second_beat, sfx_id, image_path)
	return fx


func _start(
	chapter_badge: String,
	route_title: String,
	subtitle: String,
	second_beat: String,
	sfx_id: String,
	image_path: String
) -> void:
	var font := UiFont.title()
	_fast_mode = GameState.profile == "test" or DisplayServer.get_name() == "headless"

	_curtain = ColorRect.new()
	_curtain.name = "LandmarkCurtain"
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_curtain.color = Color(0.025, 0.035, 0.032, 0.0)
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_curtain)

	# Subtle vintage brass outer frame inside 640x360
	var frame := PanelContainer.new()
	frame.name = "BrassBorderFrame"
	frame.position = Vector2(18, 16)
	frame.size = Vector2(604, 328)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.modulate.a = 0.0
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	frame_style.border_color = Color(0.68, 0.59, 0.41, 0.48)
	frame_style.set_border_width_all(1)
	frame.add_theme_stylebox_override("panel", frame_style)
	add_child(frame)

	var has_img := not image_path.is_empty() and ResourceLoader.exists(image_path)
	_card = PanelContainer.new()
	_card.name = "LandmarkCard"
	_card.position = Vector2(44, 42) if has_img else Vector2(62, 76)
	_card.size = Vector2(552, 276) if has_img else Vector2(516, 208)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.modulate.a = 0.0
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.042, 0.065, 0.056, 0.94)
	card_style.border_color = Color(0.76, 0.66, 0.46, 0.78)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(3)
	card_style.content_margin_left = 20
	card_style.content_margin_right = 20
	card_style.content_margin_top = 14
	card_style.content_margin_bottom = 12
	_card.add_theme_stylebox_override("panel", card_style)
	add_child(_card)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(vbox)

	# Macau blue-and-white azulejo street plaque accent badge
	var badge_center := CenterContainer.new()
	badge_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(badge_center)

	var badge_box := PanelContainer.new()
	badge_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var azulejo := StyleBoxFlat.new()
	azulejo.bg_color = Color(0.95, 0.96, 0.98, 0.98)
	azulejo.border_color = Color(0.10, 0.25, 0.54, 0.96)
	azulejo.set_border_width_all(2)
	azulejo.set_corner_radius_all(2)
	azulejo.content_margin_left = 14
	azulejo.content_margin_right = 14
	azulejo.content_margin_top = 3
	azulejo.content_margin_bottom = 3
	badge_box.add_theme_stylebox_override("panel", azulejo)
	badge_center.add_child(badge_box)

	_badge_lbl = Label.new()
	_badge_lbl.text = chapter_badge
	_badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_lbl.add_theme_font_override("font", font)
	_badge_lbl.add_theme_font_size_override("font_size", 12)
	_badge_lbl.add_theme_color_override("font_color", Color("14346e"))
	_badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_box.add_child(_badge_lbl)

	if has_img:
		var img_center := CenterContainer.new()
		img_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(img_center)
		var img_frame := PanelContainer.new()
		img_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var img_skin := StyleBoxFlat.new()
		img_skin.bg_color = Color(0.02, 0.03, 0.025, 1.0)
		img_skin.border_color = Color("bfa56d", 0.85)
		img_skin.set_border_width_all(1)
		img_frame.add_theme_stylebox_override("panel", img_skin)
		img_center.add_child(img_frame)
		var pic := TextureRect.new()
		pic.name = "LandmarkArt"
		pic.texture = load(image_path)
		pic.custom_minimum_size = Vector2(216, 108)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img_frame.add_child(pic)

	_title_lbl = Label.new()
	_title_lbl.text = route_title
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_lbl.add_theme_font_override("font", font)
	_title_lbl.add_theme_font_size_override("font_size", 16)
	_title_lbl.add_theme_color_override("font_color", Color("ecd9a8"))
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_title_lbl)

	var rule_wrap := CenterContainer.new()
	rule_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(rule_wrap)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(220, 1)
	rule.color = Color(0.76, 0.67, 0.48, 0.52)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule_wrap.add_child(rule)

	var combined_sub := subtitle
	if not second_beat.is_empty():
		combined_sub += "\n" + second_beat
	_sub_lbl = Label.new()
	_sub_lbl.text = combined_sub
	_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_lbl.custom_minimum_size = Vector2(490, 38)
	_sub_lbl.add_theme_font_override("font", font)
	_sub_lbl.add_theme_font_size_override("font_size", 12)
	_sub_lbl.add_theme_color_override("font_color", Color("cad8c8"))
	_sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_sub_lbl)

	_hint_lbl = Label.new()
	_hint_lbl.name = "ContinueHint"
	_hint_lbl.text = "按 [ E ] / 空格 / 左键点击 继续"
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_lbl.add_theme_font_override("font", font)
	_hint_lbl.add_theme_font_size_override("font_size", 11)
	_hint_lbl.add_theme_color_override("font_color", Color("ebd18c"))
	_hint_lbl.modulate.a = 0.0
	_hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_hint_lbl)

	if not sfx_id.is_empty():
		AudioManager.play_world_effect(sfx_id)

	_tween = create_tween()
	if _fast_mode:
		_tween.tween_property(_curtain, "color:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
		_tween.parallel().tween_property(frame, "modulate:a", 1.0, 0.18)
		_tween.parallel().tween_property(_card, "modulate:a", 1.0, 0.18)
		_tween.tween_interval(0.24)
		_tween.tween_callback(func(): completed.emit())
	else:
		_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tween.tween_property(_curtain, "color:a", 1.0, 0.42).set_trans(Tween.TRANS_SINE)
		_tween.parallel().tween_property(frame, "modulate:a", 1.0, 0.42).set_trans(Tween.TRANS_SINE)
		_tween.parallel().tween_property(_card, "modulate:a", 1.0, 0.42).set_trans(Tween.TRANS_SINE)
		_tween.tween_property(_hint_lbl, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE)
		_tween.tween_callback(func(): _waiting_input = true)


func _process(_delta: float) -> void:
	if _waiting_input and not _closing and is_instance_valid(_hint_lbl):
		_hint_lbl.modulate.a = 0.62 + 0.38 * (0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.0055))


func _input(event: InputEvent) -> void:
	if not _waiting_input or _closing or _fast_mode:
		return
	var accept := false
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		accept = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			accept = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept = true
	if accept:
		get_viewport().set_input_as_handled()
		_finish_transition()


func _finish_transition() -> void:
	if _closing:
		return
	_closing = true
	_waiting_input = false
	AudioManager.play_dialogue_advance()
	completed.emit()


func dismiss() -> void:
	_waiting_input = false
	_closing = true
	if is_instance_valid(_tween) and _tween.is_running():
		_tween.kill()
	queue_free()
