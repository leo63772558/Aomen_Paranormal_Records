extends Control

signal close_requested
signal decision_requested(action: String)

var bus: Node2D
var evidence_id := ""
var preview_actor: Sprite2D
var preview_glass: Sprite2D
var timer := 0.0
var tape_comparison: Control
var comparison_status: Label

func configure(owner_bus: Node2D, id: String) -> void:
	bus = owner_bus
	evidence_id = id

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	var title := Label.new()
	title.text = {"seat":"后排座位", "glass":"侧窗 · 对照实景", "mirror":"驾驶座后视镜", "display":"报站与手机旧附件", "sign":"窗外站牌", "door":"前门与站台", "notebook":"嘉敏笔记 · 失踪前的记录"}.get(evidence_id, "现场调查")
	title.position = Vector2(20, 12)
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)
	var viewport := Control.new()
	viewport.position = Vector2(18, 48)
	viewport.size = Vector2(290, 195)
	viewport.clip_contents = true
	viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(viewport)
	_build_preview(viewport)
	var body := RichTextLabel.new()
	body.position = Vector2(329, 50)
	body.size = Vector2(270, 197)
	body.text = bus.evidence_text(evidence_id)
	body.add_theme_font_size_override("normal_font_size", 15)
	body.add_theme_constant_override("line_separation", 5)
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(body)
	var caption := Label.new()
	caption.text = "实景与记录对照；观察不会推进车外危险。"
	caption.position = Vector2(20, 250)
	caption.size = Vector2(290, 30)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 11)
	add_child(caption)
	if evidence_id == "display" and bus.stage == 2:
		caption.text = "拖动滑轨，把两段断音移到同一位置。"
		var confirm := Button.new()
		confirm.text = "确认：声音来自旧片段"
		confirm.position = Vector2(329, 250)
		confirm.size = Vector2(270, 27)
		confirm.add_theme_font_size_override("font_size", 12)
		_style_button(confirm, true)
		confirm.pressed.connect(tape_comparison.confirm_match)
		add_child(confirm)
		comparison_status = caption
	var exit := Button.new()
	exit.text = "收起观察   [ Esc ]"
	exit.position = Vector2(20, 285)
	exit.size = Vector2(200, 30)
	_style_button(exit, false)
	exit.pressed.connect(func(): close_requested.emit())
	add_child(exit)
	if bus.stage in [0, 2]:
		var proceed := Button.new()
		proceed.text = "继续观察车程"
		proceed.position = Vector2(330, 285)
		proceed.size = Vector2(265, 30)
		_style_button(proceed, true)
		proceed.pressed.connect(func(): decision_requested.emit("continue"))
		add_child(proceed)

func _style_button(btn: Button, accent := false) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_color_override("font_color", Color("f2e4b6") if accent else Color("e0e5d4"))
	btn.add_theme_color_override("font_hover_color", Color("fff4cf"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.24, 0.19, 0.90) if accent else Color(0.08, 0.15, 0.12, 0.88)
	normal.border_color = Color("bfa872") if accent else Color("6f7a64")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("244c3c")
	hover.border_color = Color("e8d391")
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)

func _build_preview(viewport: Control) -> void:
	var photo := TextureRect.new()
	photo.size = viewport.size
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crop := AtlasTexture.new()
	crop.atlas = bus.bus_base.texture
	# All scene crops come from the active bus. The window, seat and door are
	# the same objects the player approached, rather than disconnected clue art.
	var regions := {"seat":Rect2(770, 275, 420, 430), "glass":Rect2(770, 112, 420, 440), "sign":Rect2(1160, 115, 410, 350), "door":Rect2(1690, 75, 420, 620)}
	crop.region = regions.get(evidence_id, Rect2(770, 112, 420, 440))
	crop.filter_clip = true
	photo.texture = crop
	viewport.add_child(photo)
	if evidence_id in ["seat", "glass", "mirror"]:
		if bus.stage == 0:
			preview_actor = _actor(bus._cell(0), Vector2(100, 110), 155)
			viewport.add_child(preview_actor)
		if evidence_id in ["glass", "mirror"] and (bus.stage == 0 or (bus.stage == 1 and evidence_id == "glass")):
			preview_glass = _actor(bus._cell(2 if bus.stage == 0 else 3), Vector2(219, 90), 147)
			preview_glass.modulate = Color(0.51, 0.69, 0.68, 0.67)
			viewport.add_child(preview_glass)
	elif evidence_id == "display":
		if bus.stage == 2:
			photo.hide()
			var comparison := preload("res://ui/tape_comparison_view.gd").new()
			tape_comparison = comparison
			comparison.size = viewport.size
			comparison.matched.connect(func():
				bus.observed["recording_matched"] = true
				bus._update_hud_status()
			)
			viewport.add_child(comparison)
		else:
			_add_caption(viewport, "[33]  黑沙海滩", Vector2(18, 20), 18)
	elif evidence_id == "sign":
		_add_caption(viewport, "黑沙海滩" if bus.stage == 3 else "旧站  W-17", Vector2(48, 66), 28)
	elif evidence_id == "notebook":
		photo.texture = DemoItems.prop_cell(8)
		_add_caption(viewport, "倒影独坐\n离开末排\n\n声音须核对当下", Vector2(30, 40), 22)

func _actor(texture: Texture2D, at: Vector2, height: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = at
	sprite.scale = Vector2.ONE * (height / texture.get_height())
	return sprite

func _add_caption(parent: Control, value: String, at: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e2d8b8"))
	label.add_theme_color_override("font_outline_color", Color("0e1a17"))
	label.add_theme_constant_override("outline_size", 3)
	parent.add_child(label)

func _process(delta: float) -> void:
	timer += delta
	if is_instance_valid(comparison_status) and is_instance_valid(tape_comparison):
		comparison_status.text = tape_comparison.status
		comparison_status.add_theme_font_size_override("font_size", 10)
	if is_instance_valid(preview_glass) and bus.stage == 1:
		# Continuous small head/shoulder movement in the reflection view. This is
		# presentation only: evidence states and world timers remain frozen.
		preview_glass.rotation = sin(timer * 0.7) * 0.035
		preview_glass.position.y = 90.0 + sin(timer * 0.9) * 1.4
