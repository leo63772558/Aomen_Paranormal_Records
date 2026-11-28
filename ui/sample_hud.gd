extends CanvasLayer

signal close_requested
signal pause_requested
signal mode_requested(mode: int)
signal restart_requested

var root: Control
var objective: Label
var prompt: Label
var stamina: ProgressBar
var battery: Label
var state_text: Label
var modal: PanelContainer
var panel_content: Control
var panel_open: bool = false
var toast: Label
var toast_time: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	var font := UiFont.song()
	theme.default_font = font
	theme.default_font_size = 12
	root.theme = theme
	add_child(root)
	var strip := ColorRect.new()
	strip.color = Color("10151c")
	strip.position = Vector2.ZERO
	strip.size = Vector2(640, 39)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(strip)
	label("体力", Vector2(12, 5), Vector2(30, 16), 10)
	stamina = ProgressBar.new()
	stamina.position = Vector2(43, 10)
	stamina.size = Vector2(74, 5)
	stamina.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color("354947")
	stamina.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("b5b989")
	stamina.add_theme_stylebox_override("fill", fill)
	root.add_child(stamina)
	stamina.size = Vector2(74, 5)
	battery = label("", Vector2(129, 5), Vector2(106, 17), 10)
	label("澳 诡 实 录", Vector2(269, 2), Vector2(140, 23), 17, Color("c7cdc1"))
	label("福荣旧影 · 唐楼 304", Vector2(270, 24), Vector2(150, 14), 9, Color("8aaba3"))
	objective = label("", Vector2(12, 23), Vector2(253, 15), 10, Color("d5d5b1"))
	for i in range(3):
		var names := ["明灯", "停电", "异响"]
		var button := make_button(names[i], Vector2(451+i*59, 8), Vector2(53, 23), root)
		button.pressed.connect(func(): mode_requested.emit(i))
	state_text = label("", Vector2(69, 312), Vector2(500, 16), 10, Color("a5b3a1"))
	var footer := ColorRect.new()
	footer.color = Color("10151c")
	footer.position = Vector2(0, 330)
	footer.size = Vector2(640, 30)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(footer)
	label("WASD 移动  ·  鼠标观察  ·  E 调查  ·  F 手电", Vector2(12, 338), Vector2(325, 16), 10, Color("9aafa5"))
	label("Shift 跑  Ctrl 蹲  B 背包  Esc 暂停", Vector2(408, 338), Vector2(230, 16), 10, Color("9aafa5"))
	prompt = label("", Vector2(170, 289), Vector2(340, 22), 12, Color("f3dfaa"))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast = label("", Vector2(105, 45), Vector2(430, 25), 12, Color("f0d2a0"))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal = PanelContainer.new()
	modal.position = Vector2(108, 62)
	modal.size = Vector2(424, 246)
	modal.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color("151e29")
	style.border_color = Color("919d9c")
	style.set_border_width_all(1)
	style.shadow_color = Color(0, 0, 0, 0.65)
	style.shadow_size = 12
	modal.add_theme_stylebox_override("panel", style)
	root.add_child(modal)
	panel_content = Control.new()
	panel_content.custom_minimum_size = Vector2(422, 244)
	modal.add_child(panel_content)

func label(text: String, at: Vector2, dimensions: Vector2, font_size: int = 12, color: Color = Color("dedcc2"), parent: Control = null) -> Label:
	var node := Label.new()
	node.text = text
	node.position = at
	node.size = dimensions
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else root).add_child(node)
	return node

func make_button(text: String, at: Vector2, dimensions: Vector2, parent: Control) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 11)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("26313b")
	style.border_color = Color("5a6c72")
	style.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("495b62")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	parent.add_child(button)
	return button

func open_panel(title: String, body: String, choices: Array = [], photo: bool = false) -> void:
	for child in panel_content.get_children():
		panel_content.remove_child(child)
		child.queue_free()
	panel_open = true
	modal.show()
	label(title, Vector2(19, 12), Vector2(360, 26), 17, Color("e7d3a5"), panel_content)
	label("福荣里 / 304", Vector2(20, 40), Vector2(350, 14), 9, Color("7c9f96"), panel_content)
	if photo:
		var image := TextureRect.new()
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.texture = preload("res://assets/props/old_photo.png")
		image.position = Vector2(20, 68)
		image.size = Vector2(180, 144)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		panel_content.add_child(image)
	var body_label := RichTextLabel.new()
	body_label.fit_content = false
	body_label.bbcode_enabled = false
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.position = Vector2(215 if photo else 20, 66)
	body_label.size = Vector2(188 if photo else 384, 145)
	body_label.add_theme_font_size_override("normal_font_size", 12)
	body_label.add_theme_color_override("default_color", Color("d7d9be"))
	body_label.text = body
	panel_content.add_child(body_label)
	var x: float = 20
	for choice in choices:
		var button := make_button(choice["text"], Vector2(x, 207), Vector2(choice.get("width", 122), 26), panel_content)
		button.pressed.connect(choice["callback"])
		x += choice.get("width", 122) + 8
	var close := make_button("×", Vector2(386, 10), Vector2(24, 25), panel_content)
	close.pressed.connect(func(): close_requested.emit())

func close_panel() -> void:
	panel_open = false
	modal.hide()

func notify(text: String) -> void:
	toast.text = text
	toast_time = 3.5

func _process(delta: float) -> void:
	stamina.value = GameState.stamina
	battery.text = "手电  %s  %d%%" % ["▰" if GameState.flashlight_battery > 0 else "▱", ceili(GameState.flashlight_battery)]
	if toast_time > 0:
		toast_time -= delta
		toast.visible = true
	else:
		toast.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("pause"):
		if panel_open:
			close_requested.emit()
		else:
			pause_requested.emit()
		get_viewport().set_input_as_handled()
	elif panel_open and (event.is_action_pressed("phone") or event.is_action_pressed("journal") or event.is_action_pressed("map")):
		close_requested.emit()
		get_viewport().set_input_as_handled()
	elif panel_open:
		# Modal input never reaches world interactions, including R and E.
		get_viewport().set_input_as_handled()
