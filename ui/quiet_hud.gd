extends CanvasLayer

signal close_requested
signal pause_requested
signal phone_requested
signal mode_requested(mode: int)

var root: Control
var objective: Label
var prompt: Label
var state_text: Label
var toast: Label
var toast_time: float = 0.0
var modal: PanelContainer
var panel_content: Control
var panel_open: bool = false
var title_mark: TextureRect
var resources: Control
var panel_body: RichTextLabel
var page_hint: Label
var pages: Array[String] = []
var page_index: int = 0
var choice_count: int = 0
var choice_buttons: Array[Button] = []
var phone_keytip: Label
var phone_keytip_enabled := false
var resources_visible_preference := true
var defense_notice: Label
var defense_notice_time := 0.0
var default_phone_actor: PlayerController
var default_phone_widget: Control
var archive_page := ""
var journal_note := ""
var journal_note_provider := Callable()
var journal_page_factory := Callable()
var recent_noise := PackedStringArray()
var live_noise_enabled := false
var live_noise_notice: Label
var live_noise_time := 0.0
const OFFER_HINT_AFTER := 60.0
var hint_actor: PlayerController
var hint_steps := PackedStringArray()
var hint_progress := 0
var hint_idle := 0.0
var hint_index := 0
var hint_duration := 0.0
var investigation_hint: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["SimSun", "Noto Serif CJK SC"])
	theme.default_font = font
	theme.default_font_size = 14
	root.theme = theme
	add_child(root)
	var horror_fx := preload("res://core/components/horror_director.gd").new()
	horror_fx.name = "HorrorDirector"
	horror_fx.hud_ref = self
	root.add_child(horror_fx)
	resources = preload("res://ui/status_readout.gd").new()
	resources.position = Vector2(65, 25)
	resources.visible = resources_visible_preference
	root.add_child(resources)
	title_mark = TextureRect.new()
	title_mark.texture = preload("res://assets/ui/title_mark.png")
	title_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_mark.position = Vector2(470, 2)
	title_mark.size = Vector2(112, 38)
	title_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_mark)
	objective = label("", Vector2(65, 333), Vector2(510, 20), 12, Color("a9af9f"))
	state_text = label("", Vector2(65, 313), Vector2(510, 20), 12, Color("b6b69f"))
	prompt = label("", Vector2(170, 289), Vector2(300, 22), 13, Color("e3e0bd"))
	toast = label("", Vector2(65, 313), Vector2(510, 20), 12, Color("c2b58f"))
	phone_keytip = label("[ Q / Tab ] 嘉敏的手机", Vector2(226, 11), Vector2(210, 18), 11, Color("e6d093"))
	phone_keytip.hide()
	defense_notice = label("", Vector2(65, 46), Vector2(550, 19), 12, Color("e2d49d"))
	defense_notice.hide()
	EventBus.phone_defense_feedback.connect(show_resource_feedback)
	EventBus.flashlight_feedback.connect(show_resource_feedback)
	live_noise_notice = label("", Vector2(65, 88), Vector2(320, 20), 12, Color("e0d6b8"))
	live_noise_notice.hide()
	EventBus.noise_emitted.connect(_record_nearby_noise)
	investigation_hint = label("", Vector2(65, 112), Vector2(510, 34), 13, Color("ead8a1"))
	investigation_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	investigation_hint.add_theme_color_override("font_shadow_color", Color("101914"))
	investigation_hint.add_theme_constant_override("shadow_offset_y", 1)
	investigation_hint.hide()
	modal = PanelContainer.new()
	modal.position = Vector2(5, 5)
	modal.size = Vector2(630, 176)
	modal.visible = false
	var style := StyleBoxTexture.new()
	style.texture = preload("res://assets/ui/dialogue_window.png")
	style.texture_margin_left = 6
	style.texture_margin_right = 6
	style.texture_margin_top = 6
	style.texture_margin_bottom = 6
	modal.add_theme_stylebox_override("panel", style)
	root.add_child(modal)
	panel_content = Control.new()
	panel_content.custom_minimum_size = Vector2(618, 164)
	modal.add_child(panel_content)

func label(text: String, at: Vector2, dimensions: Vector2, size_value: int = 14, color: Color = Color("e0e4d4"), parent: Control = null) -> Label:
	var node := Label.new()
	node.text = text
	node.position = at
	node.size = dimensions
	node.add_theme_font_size_override("font_size", size_value)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_shadow_color", Color("06120e"))
	node.add_theme_constant_override("shadow_offset_x", 1)
	node.add_theme_constant_override("shadow_offset_y", 1)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else root).add_child(node)
	return node

func make_button(text: String, at: Vector2, dimensions: Vector2, parent: Control) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color("e2e4d1"))
	button.add_theme_color_override("font_hover_color", Color("eee097"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.16, 0.13, 0.45)
	style.border_color = Color(0.35, 0.46, 0.38, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 8
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("244d3c")
	hover.border_color = Color("d8c78a")
	hover.content_margin_left = 14
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	parent.add_child(button)
	return button

static var _jiamin_portrait_cached: Texture2D = null
static var _ahhao_portrait_cached: Texture2D = null

func show_resources(enabled: bool) -> void:
	resources_visible_preference = enabled
	if is_instance_valid(resources):
		resources.visible = enabled and not panel_open

static func _get_default_npc_portrait(speaker_name: String) -> Texture2D:
	if speaker_name == "黄嘉敏":
		if _jiamin_portrait_cached == null and ResourceLoader.exists("res://assets/characters/jiamin_006.png"):
			var atlas := AtlasTexture.new()
			atlas.atlas = load("res://assets/characters/jiamin_006.png")
			atlas.region = Rect2(274, 13, 247, 309)
			_jiamin_portrait_cached = atlas
		return _jiamin_portrait_cached
	if speaker_name in ["阿豪", "黄梓豪", "黃梓豪"]:
		if _ahhao_portrait_cached == null:
			_ahhao_portrait_cached = preload("res://assets/ui/ahhao_portrait_252.png")
		return _ahhao_portrait_cached
	return null

func open_panel(title: String, body: String, choices: Array = [], photo: bool = false, speaker: String = "陈大文", portrait: Texture2D = null, photo_texture: Texture2D = null) -> void:
	for child in panel_content.get_children():
		panel_content.remove_child(child)
		child.queue_free()
	panel_open = true
	modal.show()
	modal.modulate.a = 0.72
	var modal_fade := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	modal_fade.tween_property(modal, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE)
	title_mark.hide()
	resources.hide()
	prompt.hide()
	phone_keytip.hide()
	choice_count = choices.size()
	choice_buttons.clear()
	var content_height: float = 164 if choice_count == 0 else 158 + choice_count * 36 + 22
	modal.size = Vector2(630, content_height + 12)
	panel_content.custom_minimum_size = Vector2(618, content_height)
	
	var is_protagonist := (speaker in ["大文", "陈大文", "黄嘉敏"] or speaker.is_empty())
	var effective_portrait: Texture2D = portrait
	if effective_portrait == null:
		effective_portrait = _get_default_npc_portrait(speaker)
	
	if is_protagonist:
		label(speaker if not speaker.is_empty() else "陈大文", Vector2(110, 11), Vector2(120, 23), 16, Color("e1d684"), panel_content)
		label(title, Vector2(235, 14), Vector2(350, 20), 12, Color("acbfa9"), panel_content)
	else:
		label(speaker, Vector2(24, 11), Vector2(140, 23), 16, Color("e1d684"), panel_content)
		label(title, Vector2(170, 14), Vector2(330, 20), 12, Color("acbfa9"), panel_content)
	
	if photo and photo_texture == null:
		make_archive_photo()
	else:
		var image := TextureRect.new()
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var chosen_tex: Texture2D = photo_texture if photo_texture != null else (effective_portrait if effective_portrait != null else (preload("res://assets/ui/dawen_portrait_004.png") if is_protagonist else null))
		image.texture = chosen_tex
		if chosen_tex != null:
			var target_pos := Vector2(12, 40) if is_protagonist else Vector2(518, 40)
			image.position = target_pos + Vector2(0, 6)
			image.size = Vector2(90, 62) if photo_texture != null else Vector2(86, 108)
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel_content.add_child(image)
			var p_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			p_tween.tween_property(image, "position", target_pos, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			image.free()
	
	var header_rule := ColorRect.new()
	header_rule.position = Vector2(110 if is_protagonist else 24, 34)
	header_rule.size = Vector2(495 if is_protagonist else 484, 1)
	header_rule.color = Color(0.55, 0.62, 0.52, 0.35)
	header_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_content.add_child(header_rule)

	panel_body = RichTextLabel.new()
	if is_protagonist:
		panel_body.position = Vector2(110, 40)
		panel_body.size = Vector2(495, 94)
	else:
		panel_body.position = Vector2(24, 40)
		panel_body.size = Vector2(484, 94)
	panel_body.fit_content = false
	panel_body.bbcode_enabled = false
	panel_body.scroll_active = false
	var body_font_size := 16 if GameState.large_dialogue_text else 14
	panel_body.add_theme_font_size_override("normal_font_size", body_font_size)
	panel_body.add_theme_color_override("default_color", Color("edf0e0"))
	panel_body.add_theme_constant_override("line_separation", 3)
	panel_content.add_child(panel_body)
	pages.clear()
	var current: String = ""
	var line: String = ""
	var line_count: int = 1
	var font := root.get_theme_default_font()
	var max_width: float = 484 if is_protagonist else 476
	for character in body:
		var line_break: bool = character == "\n" or font.get_string_size(line + character, HORIZONTAL_ALIGNMENT_LEFT, -1, body_font_size).x > max_width
		if line_break:
			if line_count >= 4:
				pages.append(current.strip_edges())
				current = ""
				line_count = 1
				line = ""
				if character == "\n":
					continue
			else:
				line_count += 1
				line = ""
		current += character
		if character != "\n":
			line += character
	if not current.is_empty():
		pages.append(current)
	if pages.is_empty():
		pages.append("")
	page_index = 0
	panel_body.text = pages[0]
	panel_body.visible_ratio = 0.0
	var reveal := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	reveal.tween_property(panel_body, "visible_ratio", 1.0, 0.14)
	var choice_y: float = 142
	var choice_x: float = 110 if is_protagonist else 24
	var choice_w: float = 380 if is_protagonist else 470
	for choice in choices:
		var button := make_button(choice["text"], Vector2(choice_x, choice_y), Vector2(choice_w, 32), panel_content)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(AudioManager.play_dialogue_advance)
		button.pressed.connect(choice["callback"])
		choice_buttons.append(button)
		choice_y += 36
	page_hint = label("", Vector2(469, content_height - 18), Vector2(140, 16), 10, Color("a6baa7"), panel_content)
	update_page_hint()

func update_page_hint() -> void:
	for button in choice_buttons:
		button.visible = page_index >= pages.size() - 1
	page_hint.text = "E 下一页  ▼" if page_index < pages.size()-1 else ("Esc 返回" if choice_count > 0 else "E 返回  ▼")

func make_archive_photo() -> void:
	# Compose an in-game archival view from the same room/furniture artwork.
	# The bed stands at its former position; no obsolete prototype art is shown.
	var clip := Control.new()
	clip.position = Vector2(12, 40)
	clip.size = Vector2(90, 72)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_content.add_child(clip)
	var stage := Node2D.new()
	stage.scale = Vector2(0.45, 0.45)
	clip.add_child(stage)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){vec4 c=texture(TEXTURE,UV);float g=dot(c.rgb,vec3(0.299,0.587,0.114));COLOR=vec4(g*vec3(1.08,0.99,0.79),c.a);}"
	var material := ShaderMaterial.new()
	material.shader = shader
	stage.material = material
	var background := Sprite2D.new()
	background.texture = preload("res://assets/tilesets/tanglau_room_003.png")
	background.centered = false
	background.scale = Vector2(640, 360) / background.texture.get_size()
	background.position = Vector2(-368, -64)
	background.use_parent_material = true
	stage.add_child(background)
	var patch := Sprite2D.new()
	var patch_texture := AtlasTexture.new()
	patch_texture.atlas = background.texture
	var factor: Vector2 = background.texture.get_size() / Vector2(640, 360)
	patch_texture.region = Rect2(Vector2(480, 184) * factor, Vector2(80, 32) * factor)
	patch.texture = patch_texture
	patch.centered = false
	patch.scale = Vector2(80, 32) / patch_texture.region.size
	patch.position = Vector2(22, 120)
	patch.use_parent_material = true
	stage.add_child(patch)
	var bed := Sprite2D.new()
	var bed_texture := AtlasTexture.new()
	bed_texture.atlas = preload("res://assets/props/furniture_atlas_003_source.png")
	bed_texture.region = Rect2(641, 25, 259, 467)
	bed.texture = bed_texture
	bed.centered = false
	bed.scale = Vector2(66, 90) / bed_texture.region.size
	bed.position = Vector2(37, 0)
	bed.use_parent_material = true
	stage.add_child(bed)

func advance() -> void:
	if is_instance_valid(panel_body) and panel_body.visible_ratio < 0.99:
		panel_body.visible_ratio = 1.0
	if page_index < pages.size()-1:
		AudioManager.play_dialogue_advance()
		page_index += 1
		panel_body.text = pages[page_index]
		panel_body.visible_ratio = 0.0
		var reveal := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		reveal.tween_property(panel_body, "visible_ratio", 1.0, 0.14)
		update_page_hint()
	elif choice_count == 0:
		AudioManager.play_dialogue_advance()
		close_requested.emit()

func open_widget(widget: Control, dimensions := Vector2(618, 330)) -> void:
	open_panel("", "")
	archive_page = ""
	for child in panel_content.get_children():
		panel_content.remove_child(child)
		child.queue_free()
	choice_count = 1
	panel_content.custom_minimum_size = dimensions
	modal.size = dimensions + Vector2(12, 12)
	widget.size = dimensions
	panel_content.add_child(widget)

func set_phone_keytip(enabled: bool) -> void:
	phone_keytip_enabled = enabled
	phone_keytip.visible = enabled and not panel_open

func close_panel() -> void:
	panel_open = false
	archive_page = ""
	modal.hide()
	title_mark.show()
	resources.visible = resources_visible_preference
	prompt.show()
	phone_keytip.visible = phone_keytip_enabled

func notify(text: String) -> void:
	toast.text = text
	toast_time = 4.0

func show_resource_feedback(message: String) -> void:
	defense_notice.text = message
	defense_notice_time = 4.0

func set_investigation_hints(actor: PlayerController, steps: PackedStringArray, progress := 0) -> void:
	if hint_actor == actor and hint_steps == steps and hint_progress == progress:
		return
	hint_actor = actor
	hint_steps = steps
	hint_progress = progress
	hint_idle = 0.0
	hint_index = 0
	hint_duration = 0.0

func _hint_available() -> bool:
	return not panel_open and not get_tree().paused and not hint_steps.is_empty() and is_instance_valid(hint_actor) and hint_actor.controls_enabled and not hint_actor.hidden_in_wardrobe

func _update_investigation_hint(delta: float) -> void:
	investigation_hint.hide()
	if not _hint_available():
		return
	hint_duration = maxf(0.0, hint_duration - delta)
	if hint_duration > 0.0:
		investigation_hint.show()
	else:
		hint_idle += delta
		if hint_index == 0 and hint_idle >= OFFER_HINT_AFTER:
			investigation_hint.text = "[ H ] 查看调查提示"
			investigation_hint.show()

func _active_phone_actor(allow_locked := false) -> PlayerController:
	if GameState.current_role != "dawen" or not GameState.opening_flags.jiamin_phone_found or not GameState.has_demo_item("jiamin_phone"):
		return null
	var scene_root := get_parent()
	for candidate in get_tree().get_nodes_in_group("phone_flash_actor"):
		if candidate is PlayerController and scene_root.is_ancestor_of(candidate) and candidate.appearance not in ["jiamin", "ah_hao"]:
			if allow_locked or (candidate.controls_enabled and not candidate.hidden_in_wardrobe):
				return candidate
	return null

func _open_default_phone(actor: PlayerController, page: String) -> void:
	default_phone_actor = actor
	actor.controls_enabled = false
	actor.clear_motion()
	open_archive_page(page)
	get_tree().paused = true

func open_archive_page(page: String) -> void:
	var next: Control
	match page:
		"phone":
			next = make_phone()
		"map":
			next = preload("res://ui/demo_travel_map.gd").new()
			next.current_objective = objective.text
		"journal":
			if journal_page_factory.is_valid():
				next = journal_page_factory.call()
			else:
				next = preload("res://ui/demo_bag.gd").new()
				next.journal_mode = true
				next.journal_note = journal_note_provider.call() if journal_note_provider.is_valid() else journal_note
		"inventory":
			next = preload("res://ui/demo_bag.gd").new()
	if is_instance_valid(default_phone_actor):
		default_phone_widget = next
	open_widget(next)
	archive_page = page

func _close_default_phone() -> void:
	if is_instance_valid(default_phone_widget):
		default_phone_widget.queue_free()
	default_phone_widget = null
	archive_page = ""
	close_panel()
	get_tree().paused = false
	if is_instance_valid(default_phone_actor):
		default_phone_actor.controls_enabled = true
		default_phone_actor.clear_motion()
	default_phone_actor = null

func make_phone() -> Control:
	var phone = preload("res://ui/demo_phone.gd").new()
	phone.map_requested.connect(open_archive_page.bind("map"))
	phone.journal_requested.connect(open_archive_page.bind("journal"))
	phone.bag_requested.connect(open_archive_page.bind("inventory"))
	phone.recent_noise = recent_noise.duplicate()
	phone.live_noise_enabled = live_noise_enabled
	phone.live_noise_toggled.connect(_set_live_noise_enabled)
	return phone

func _set_live_noise_enabled(enabled: bool) -> void:
	live_noise_enabled = enabled
	if not enabled:
		live_noise_time = 0.0
		live_noise_notice.hide()

func _record_nearby_noise(origin: Vector2, radius: float, source_id: String) -> void:
	if get_tree().paused or radius <= 0.0 or GameState.current_role != "dawen":
		return
	var actor := _active_phone_actor(true)
	if not is_instance_valid(actor):
		return
	var distance := actor.global_position.distance_to(origin)
	if distance >= minf(radius, 160.0):
		return
	var level := clampi(ceili((radius - distance) / 28.0), 1, 5)
	var source: String = {"footstep":"脚步", "shaft_bucket_084":"水桶响动"}.get(source_id, "附近响动")
	var reading := "%s　%d / 5" % [source, level]
	recent_noise.insert(0, reading)
	if recent_noise.size() > 4:
		recent_noise.resize(4)
	if live_noise_enabled:
		live_noise_notice.text = "声强　" + reading
		live_noise_time = 2.0

func _process(delta: float) -> void:
	_update_investigation_hint(delta)
	if GameState.transition_save_failed and not panel_open and not get_tree().paused:
		GameState.transition_save_failed = false
		show_resource_feedback("进度保存失败，仍可继续。请检查存储空间和文件夹权限后重试。")
	if not get_tree().paused and not panel_open:
		defense_notice_time = maxf(0.0, defense_notice_time - delta)
	if not get_tree().paused:
		live_noise_time = maxf(0.0, live_noise_time - delta)
	defense_notice.visible = defense_notice_time > 0.0 and not panel_open
	live_noise_notice.visible = live_noise_time > 0.0 and not panel_open and GameState.current_role == "dawen"
	if toast_time > 0:
		toast_time -= delta
	toast.visible = toast_time > 0 and not panel_open and (not state_text.visible or state_text.text.is_empty())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("investigation_hint") and _hint_available():
		investigation_hint.text = hint_steps[hint_index] + ("　[ H ] 下一条" if hint_index < hint_steps.size() - 1 else "")
		hint_index = mini(hint_index + 1, hint_steps.size() - 1)
		hint_duration = 8.0
		get_viewport().set_input_as_handled()
		return
	var requested_page := ""
	for page in ["phone", "map", "journal", "inventory"]:
		if event.is_action_pressed(page):
			requested_page = page
			break
	if panel_open and (event.is_action_pressed("pause") or not requested_page.is_empty()):
		for child in panel_content.get_children():
			if child.has_method("close_subview") and child.close_subview():
				get_viewport().set_input_as_handled()
				return
	if panel_open and not archive_page.is_empty() and (event.is_action_pressed("pause") or not requested_page.is_empty()):
		get_viewport().set_input_as_handled()
		if requested_page.is_empty() or requested_page == "phone" or requested_page == archive_page:
			if is_instance_valid(default_phone_widget):
				_close_default_phone()
			else:
				close_requested.emit()
		else:
			open_archive_page(requested_page)
		return
	if not panel_open and not requested_page.is_empty():
		var actor := _active_phone_actor()
		if is_instance_valid(actor):
			get_viewport().set_input_as_handled()
			if requested_page == "phone" and not phone_requested.get_connections().is_empty():
				phone_requested.emit()
			else:
				_open_default_phone(actor, requested_page)
			return
		if is_instance_valid(_active_phone_actor(true)):
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if panel_open:
			close_requested.emit()
		else:
			pause_requested.emit()
	elif panel_open and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		advance()
	elif panel_open and event.is_action_pressed("phone") and phone_keytip_enabled:
		get_viewport().set_input_as_handled()
		phone_requested.emit()
	elif panel_open and (event.is_action_pressed("phone") or event.is_action_pressed("journal") or event.is_action_pressed("map") or event.is_action_pressed("inventory")):
		get_viewport().set_input_as_handled()
		close_requested.emit()
	elif panel_open:
		get_viewport().set_input_as_handled()
