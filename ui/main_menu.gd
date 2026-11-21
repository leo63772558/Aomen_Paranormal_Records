extends Control

var notice_panel: Control
var menu: VBoxContainer
var start_button: Button
var new_button: Button
var load_error: Label
var new_game_error: Label
var title_font: SystemFont

func _ready() -> void:
	GameState.end_preview()
	GameState.prepare_opening_resume()
	AudioManager.set_scene_ambience("")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_font = SystemFont.new()
	title_font.font_names = PackedStringArray(["STZhongsong", "SimSun", "Noto Serif CJK SC"])
	var typography := Theme.new()
	typography.default_font = title_font
	theme = typography
	var background := TextureRect.new()
	background.texture = load("res://assets/ui/menu_macau_026.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var atmosphere := MenuAtmosphere.new()
	atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(atmosphere)
	_add_masthead()
	menu = VBoxContainer.new()
	menu.position = Vector2(70, 184)
	menu.custom_minimum_size.x = 175
	menu.add_theme_constant_override("separation", 8)
	add_child(menu)
	new_button = _button("新游戏")
	new_button.pressed.connect(_confirm_new_game)
	menu.add_child(new_button)
	start_button = _button("继续游戏")
	start_button.pressed.connect(_proceed)
	start_button.disabled = not _has_opening_progress()
	menu.add_child(start_button)
	var audio_btn := _button("设置")
	audio_btn.pressed.connect(_open_audio_settings)
	menu.add_child(audio_btn)
	var quit_button := _button("退出")
	quit_button.pressed.connect(func(): get_tree().quit())
	menu.add_child(quit_button)
	load_error = _caption(self, "", Vector2(73, 342), 11, Color("edb1a0"))
	if "--autobot" not in OS.get_cmdline_user_args():
		_focus_entry()

func _has_opening_progress() -> bool:
	var path := GameState.get_profile_path()
	return GameState.current_room_id != "ch0_hk_work" or FileAccess.file_exists(path.path_join("opening_checkpoint.json")) or FileAccess.file_exists(path.path_join("opening_checkpoint.bak.json"))

func _focus_entry() -> void:
	var primary := new_button if start_button.disabled else start_button
	primary.grab_focus.call_deferred()

func _open_audio_settings() -> void:
	if is_instance_valid(notice_panel):
		return
	menu.hide()
	notice_panel = PanelContainer.new()
	notice_panel.position = Vector2(89, 24)
	notice_panel.size = Vector2(462, 312)
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("101a16")
	skin.border_color = Color("847657")
	skin.set_border_width_all(1)
	notice_panel.add_theme_stylebox_override("panel", skin)
	add_child(notice_panel)
	var body := Control.new()
	body.custom_minimum_size = Vector2(462, 312)
	notice_panel.add_child(body)
	_caption(body, "声音与文字设置", Vector2(30, 14), 20, Color("ead7a5"))
	var warning := _caption(body, "", Vector2(30, 260), 12, Color("edb1a0"))
	var labels := {"Master":"总音量", "Music":"音乐", "Ambience":"环境", "SFX":"音效", "Voice":"对白"}
	var row := 0
	for bus_name in AudioManager.VOLUME_BUSES:
		var y := 52.0 + row * 34.0
		_caption(body, labels[bus_name], Vector2(30, y), 15, Color("e0ddc8"))
		var slider := HSlider.new()
		slider.name = "Volume_" + bus_name
		slider.position = Vector2(135, y + 1)
		slider.size = Vector2(225, 24)
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.value = roundi(AudioManager.get_bus_volume(bus_name) * 100)
		var number := _caption(body, "%d%%" % int(slider.value), Vector2(375, y), 14, Color("e0ddc8"))
		slider.value_changed.connect(func(value: float):
			number.text = "%d%%" % int(value)
			warning.text = "" if AudioManager.set_bus_volume(bus_name, value / 100.0) else "无法保存设置，请检查存储空间和权限。"
		)
		body.add_child(slider)
		row += 1
	var larger := CheckButton.new()
	larger.name = "LargeDialogueText"
	larger.text = "放大对白文字"
	larger.position = Vector2(30, 226)
	larger.size = Vector2(220, 28)
	larger.button_pressed = GameState.large_dialogue_text
	larger.toggled.connect(func(enabled: bool):
		warning.text = "" if GameState.set_large_dialogue_text(enabled) else "无法保存设置，请检查存储空间和权限。"
	)
	body.add_child(larger)
	var reduce := CheckButton.new()
	reduce.name = "ReducedFlash"
	reduce.text = "减弱闪光"
	reduce.position = Vector2(250, 226)
	reduce.size = Vector2(190, 28)
	reduce.button_pressed = GameState.reduced_flash
	reduce.toggled.connect(GameState.set_reduced_flash)
	body.add_child(reduce)
	var close := _button("返回")
	close.position = Vector2(255, 274)
	close.pressed.connect(_cancel_notice)
	body.add_child(close)
	close.call_deferred("grab_focus")

func _add_masthead() -> void:
	_caption(self, "取材自澳门都市传说", Vector2(73, 51), 12, Color("c9aa72"))
	var line := ColorRect.new()
	line.position = Vector2(73, 76)
	line.size = Vector2(177, 1)
	line.color = Color("9c7f50")
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	var glyphs := ["澳", "诡", "实", "录"]
	var offsets := [Vector2(62, 82), Vector2(114, 90), Vector2(161, 86), Vector2(208, 91)]
	var sizes := [58, 51, 50, 50]
	for i in range(glyphs.size()):
		var glyph := _caption(self, glyphs[i], offsets[i], sizes[i], Color("e3d8bd"))
		glyph.add_theme_color_override("font_outline_color", Color("231c18"))
		glyph.add_theme_constant_override("outline_size", 2)
		glyph.add_theme_color_override("font_shadow_color", Color("8e4e3d"))
		glyph.add_theme_constant_override("shadow_offset_x", 2)
		glyph.add_theme_constant_override("shadow_offset_y", 3)
	_caption(self, "A O M E N    P A R A N O R M A L    R E C O R D S", Vector2(72, 161), 8, Color("d4c1a1"))
	_caption(self, "大三巴  ·  澳门半岛", Vector2(479, 330), 12, Color("e5d9ba"))

func _caption(parent: Control, value: String, at: Vector2, size_px: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)
	return label

func _button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(175, 31)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("ded4bd"))
	button.add_theme_color_override("font_hover_color", Color("ffe5ab"))
	button.add_theme_color_override("font_focus_color", Color("ffe5ab"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.03, 0.045, 0.039, 0.78)
	normal.border_color = Color("695d47")
	normal.border_width_bottom = 1
	normal.border_width_left = 2
	normal.content_margin_left = 14
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.19, 0.14, 0.97)
	hover.border_color = Color("be9d63")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	var focus := hover.duplicate() as StyleBoxFlat
	focus.draw_center = false
	focus.border_width_right = 1
	focus.border_width_top = 1
	button.add_theme_stylebox_override("focus", focus)
	return button

func _proceed() -> void:
	AudioManager.play_dialogue_advance()
	if GameState.request_room_change(GameState.current_room_id, GameState.pending_entry_id):
		GameState.save_transition_checkpoint()
	elif is_instance_valid(notice_panel):
		var body := notice_panel.get_child(0) as Control
		var error := body.get_node_or_null("RoomLoadError") as Label
		if error == null:
			error = _caption(body, "", Vector2(32, 150), 12, Color("edb1a0"))
			error.name = "RoomLoadError"
		error.text = "场景暂时无法载入，进度已保留，请稍后重试。"
	else:
		load_error.text = "场景暂时无法载入，请稍后重试。"

func _confirm_new_game() -> void:
	if is_instance_valid(notice_panel):
		return
	if not _has_opening_progress():
		_start_new_game()
		return
	AudioManager.play_dialogue_advance()
	menu.hide()
	notice_panel = PanelContainer.new()
	notice_panel.position = Vector2(89, 57)
	notice_panel.size = Vector2(462, 246)
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("101a16")
	skin.border_color = Color("847657")
	skin.set_border_width_all(1)
	notice_panel.add_theme_stylebox_override("panel", skin)
	add_child(notice_panel)
	var body := Control.new()
	body.custom_minimum_size = Vector2(462, 246)
	notice_panel.add_child(body)
	_caption(body, "从头开始", Vector2(32, 26), 21, Color("ead7a5"))
	_caption(body, "将先备份当前进度与照片，再从香港序章开始。\n确认后，主菜单的继续游戏会读取新进度。", Vector2(32, 72), 14, Color("e0ddc8"))
	new_game_error = _caption(body, "", Vector2(32, 139), 12, Color("edb1a0"))
	var proceed := _button("备份并开始")
	proceed.position = Vector2(32, 182)
	proceed.pressed.connect(_start_new_game)
	body.add_child(proceed)
	var cancel := _button("返回")
	cancel.position = Vector2(237, 182)
	cancel.pressed.connect(_cancel_notice)
	body.add_child(cancel)
	proceed.call_deferred("grab_focus")

func _start_new_game() -> void:
	if not GameState.start_new_opening():
		if is_instance_valid(new_game_error):
			new_game_error.text = "无法备份或保存，请检查存储空间与权限。"
		else:
			load_error.text = "无法保存，请检查存储空间和权限。"
		return
	_proceed()

func _cancel_notice() -> void:
	if is_instance_valid(notice_panel):
		notice_panel.queue_free()
		notice_panel = null
	new_game_error = null
	menu.show()
	_focus_entry()

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(notice_panel) and event.is_action_pressed("pause") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_cancel_notice()

class MenuAtmosphere extends Control:
	var clock := 0.0
	var drops: Array[Dictionary] = []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 20261121
		for _i in range(44):
			drops.append({
				"x": rng.randf_range(0.0, 640.0),
				"y": rng.randf_range(0.0, 360.0),
				"speed": rng.randf_range(175.0, 290.0),
				"len": rng.randf_range(9.0, 18.0),
				"alpha": rng.randf_range(0.09, 0.22),
			})

	func _process(delta: float) -> void:
		clock += delta
		for d in drops:
			d["y"] = float(d["y"]) + float(d["speed"]) * delta
			d["x"] = float(d["x"]) - float(d["speed"]) * 0.14 * delta
			if float(d["y"]) > 372.0:
				d["y"] = -14.0
				d["x"] = fposmod(float(d["x"]) + 690.0, 680.0)
		queue_redraw()

	func _draw() -> void:
		# Subtle drifting Macau night fog along the St. Paul's stone steps
		for i in range(4):
			var drift := fposmod(clock * (8.0 + i * 3.5) + i * 165.0, 820.0) - 90.0
			var y := 272.0 + i * 21.0 + sin(clock * 0.6 + i) * 4.0
			draw_circle(Vector2(drift, y), 78.0 + i * 14.0, Color(0.76, 0.84, 0.80, 0.032))
		# Subtle flickering warm heritage streetlamp halo on the right
		var lamp_pulse := 1.0
		if not GameState.reduced_flash:
			lamp_pulse = 0.84 + 0.16 * sin(clock * 3.7) * sin(clock * 11.3)
		var lamp_pos := Vector2(516.0, 126.0)
		draw_circle(lamp_pos, 58.0, Color(0.95, 0.72, 0.36, 0.055 * lamp_pulse))
		draw_circle(lamp_pos, 26.0, Color(1.0, 0.84, 0.52, 0.085 * lamp_pulse))
		# Diagonal night drizzle streaks
		for d in drops:
			var p := Vector2(float(d["x"]), float(d["y"]))
			var l := float(d["len"])
			draw_line(p, p + Vector2(-l * 0.14, l), Color(0.74, 0.84, 0.88, float(d["alpha"])), 1.0)
