extends Control

signal solved
signal close_requested
signal effect_requested(effect_id: String)

const PARTS := preload("res://assets/props/ch3_balance_parts_030.png")
const WEIGHTS := [
	{"name":"饥", "value":1, "region":Rect2(723, 893, 180, 247), "size":Vector2(31, 39)},
	{"name":"寒", "value":3, "region":Rect2(730, 670, 165, 230), "size":Vector2(31, 39)},
	{"name":"贪", "value":4, "region":Rect2(900, 900, 278, 293), "size":Vector2(34, 36)},
	{"name":"嗔", "value":6, "region":Rect2(972, 632, 113, 256), "size":Vector2(25, 42)}
]

var placed: Array[bool] = [false, false, false, false]
var cards: Array[Button] = []
var card_labels: Array[Label] = []
var pan_items: Array[Sprite2D] = []
const BEAM_HALF_SPAN := 124.0
var scale_center := Vector2(309, 88)
var beam_pivot: Node2D
var left_pan: Node2D
var right_pan: Node2D
var status_label: Label
var solved_once := false
var motion: Tween
var focus_suspended := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(618, 330)
	_build_board()

func _atlas(rect: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = PARTS
	texture.region = rect
	texture.filter_clip = true
	return texture

func _build_board() -> void:
	var wash := ColorRect.new()
	wash.position = Vector2.ZERO
	wash.size = size
	wash.color = Color(0.035, 0.075, 0.059, 0.94)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)
	var edge := Panel.new()
	edge.position = Vector2(5, 5)
	edge.size = Vector2(608, 320)
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(0.025, 0.052, 0.042, 0.96)
	skin.border_color = Color("806e4e")
	skin.set_border_width_all(1)
	edge.add_theme_stylebox_override("panel", skin)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(edge)
	var title := _label("旧杆秤 · 肉铺资料柜", Vector2(18, 9), Vector2(430, 23), 16, Color("e2d4a6"))
	title.z_index = 10
	var instructions := _label("左盘放 3 枚，共 8 两，且要有「饥」「寒」。点击砝码放入或取下。", Vector2(18, 34), Vector2(541, 18), 12, Color("d6dac8"))
	instructions.z_index = 10
	var rule := ColorRect.new()
	rule.position = Vector2(18, 56)
	rule.size = Vector2(582, 1)
	rule.color = Color("76694d")
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)
	_build_scale_art()
	_label("左盘", Vector2(125, 66), Vector2(72, 16), 12, Color("e0d5b9"))
	_label("右盘 · 固定 8 两", Vector2(448, 66), Vector2(150, 16), 12, Color("e0d5b9"))
	status_label = _label("左盘 0 / 3 枚 · 0 / 8 两", Vector2(18, 214), Vector2(355, 19), 12, Color("d5c7a5"))
	var weigh_button := _button("确认称量", Vector2(375, 210), Vector2(99, 25))
	weigh_button.pressed.connect(submit_weight)
	var clear_button := _button("清空", Vector2(480, 210), Vector2(57, 25))
	clear_button.pressed.connect(clear_weights)
	var back_button := _button("返回", Vector2(539, 8), Vector2(62, 24))
	back_button.pressed.connect(func(): close_requested.emit())
	_build_weight_cards()
	_update_pan_weights()
	_update_card_states()

func _build_scale_art() -> void:
	var art := Node2D.new()
	art.position = Vector2.ZERO
	art.z_index = 1
	add_child(art)
	var base := Sprite2D.new()
	base.texture = _atlas(Rect2(137, 23, 363, 578))
	base.position = Vector2(309, 120)
	base.scale = Vector2.ONE * 0.19
	base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.add_child(base)
	beam_pivot = Node2D.new()
	beam_pivot.position = scale_center
	art.add_child(beam_pivot)
	var beam := Sprite2D.new()
	beam.texture = _atlas(Rect2(630, 244, 603, 120))
	beam.position = Vector2(-7, 4)
	beam.scale = Vector2.ONE * 0.46
	beam.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	beam_pivot.add_child(beam)
	left_pan = Node2D.new()
	right_pan = Node2D.new()
	art.add_child(left_pan)
	art.add_child(right_pan)
	for pan in [left_pan, right_pan]:
		var bowl := Sprite2D.new()
		bowl.texture = _atlas(Rect2(120, 600, 410, 624))
		bowl.centered = false
		bowl.position = Vector2(-30, -2)
		bowl.scale = Vector2(60, 82) / bowl.texture.get_size()
		bowl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pan.add_child(bowl)
	var reference_weight := Sprite2D.new()
	reference_weight.texture = _atlas(WEIGHTS[2].region)
	reference_weight.position.y = 61
	reference_weight.scale = Vector2(28, 29) / reference_weight.texture.get_size()
	right_pan.add_child(reference_weight)
	beam_pivot.rotation = 0.18

func _build_weight_cards() -> void:
	for i in range(WEIGHTS.size()):
		var x := 17.0 + i * 147.0
		var card := Button.new()
		card.position = Vector2(x, 239)
		card.size = Vector2(140, 74)
		card.focus_mode = Control.FOCUS_NONE
		card.text = ""
		card.pressed.connect(_toggle_weight.bind(i))
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color("18231d")
		normal.border_color = Color("665d46")
		normal.set_border_width_all(1)
		normal.content_margin_left = 3
		normal.content_margin_right = 3
		card.add_theme_stylebox_override("normal", normal)
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color("263d31")
		hover.border_color = Color("c2a66f")
		card.add_theme_stylebox_override("hover", hover)
		card.add_theme_stylebox_override("pressed", hover)
		add_child(card)
		var image := TextureRect.new()
		image.position = Vector2(8, 5)
		image.size = Vector2(43, 61)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture = _atlas(WEIGHTS[i].region)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(image)
		var label := Label.new()
		label.position = Vector2(53, 20)
		label.size = Vector2(80, 34)
		label.text = "%s\n%d 两" % [WEIGHTS[i].name, WEIGHTS[i].value]
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color("e3ddc8"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(label)
		cards.append(card)
		card_labels.append(label)

func _toggle_weight(index: int) -> void:
	if solved_once or index < 0 or index >= placed.size():
		return
	placed[index] = not placed[index]
	_update_card_states()
	_update_pan_weights()
	_animate_balance(_current_total())
	status_label.text = "左盘 %d / 3 枚 · %d / 8 两" % [_current_count(), _current_total()]
	effect_requested.emit("balance_weight")

func clear_weights() -> void:
	if solved_once:
		return
	for i in range(placed.size()):
		placed[i] = false
	_update_card_states()
	_update_pan_weights()
	_animate_balance(0)
	effect_requested.emit("balance_weight")
	status_label.text = "左盘 0 / 3 枚 · 0 / 8 两"

func _current_total() -> int:
	var total := 0
	for i in range(placed.size()):
		if placed[i]:
			total += int(WEIGHTS[i].value)
	return total

func _current_count() -> int:
	var count := 0
	for selected in placed:
		if selected:
			count += 1
	return count

func _update_card_states() -> void:
	for i in range(cards.size()):
		cards[i].modulate = Color("9ba18f") if placed[i] else Color.WHITE
		card_labels[i].text = "%s\n%d 两%s" % [WEIGHTS[i].name, WEIGHTS[i].value, " · 已放" if placed[i] else ""]

func _update_pan_weights() -> void:
	for item in pan_items:
		if is_instance_valid(item):
			item.queue_free()
	pan_items.clear()
	var indices: Array[int] = []
	for i in range(placed.size()):
		if placed[i]:
			indices.append(i)
	for slot in range(indices.size()):
		var index := indices[slot]
		var item := Sprite2D.new()
		item.texture = _atlas(WEIGHTS[index].region)
		item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var dimensions: Vector2 = WEIGHTS[index].size * 0.78
		item.scale = Vector2(dimensions.x / item.texture.get_size().x, dimensions.y / item.texture.get_size().y)
		var land_pos := Vector2((slot - (indices.size() - 1) * 0.5) * 15.0, 73.0 - dimensions.y * 0.5)
		item.position = land_pos + Vector2(0, -14.0)
		item.z_index = 4
		left_pan.add_child(item)
		var drop := item.create_tween()
		drop.tween_property(item, "position", land_pos, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		pan_items.append(item)

func _animate_balance(total: int) -> void:
	if not is_instance_valid(beam_pivot):
		return
	if is_instance_valid(motion):
		motion.kill()
	var target := clampf(float(8 - total) * 0.025, -0.28, 0.24)
	motion = create_tween()
	motion.set_trans(Tween.TRANS_BACK)
	motion.set_ease(Tween.EASE_OUT)
	motion.tween_property(beam_pivot, "rotation", target * 1.12, 0.16)
	motion.tween_property(beam_pivot, "rotation", target * 0.84, 0.12)
	motion.tween_property(beam_pivot, "rotation", target, 0.18)

func submit_weight() -> void:
	if solved_once:
		return
	var count := _current_count()
	var total := _current_total()
	if count != 3:
		if total < 8:
			status_label.text = "秤盘偏轻，枚数也不合（%d/3）。" % count
		else:
			status_label.text = "枚数不合：左盘应是三枚，现在是 %d 枚。" % count
		_animate_balance(total)
		_shake_feedback()
		effect_requested.emit("balance_weight")
		return
	if total < 8:
		status_label.text = "偏轻。秤梁停在了左高右低的位置。"
		_animate_balance(total)
		_shake_feedback()
		effect_requested.emit("balance_weight")
		return
	if total > 8:
		status_label.text = "偏重。左盘比半斤基准多了 %d 两。" % (total - 8)
		_animate_balance(total)
		_shake_feedback()
		effect_requested.emit("balance_weight")
		return
	if not (placed[0] and placed[1] and placed[2] and not placed[3]):
		status_label.text = "秤梁仍在细颤。再核对账边的三枚条件。"
		_animate_balance(total)
		_shake_feedback()
		effect_requested.emit("balance_weight")
		return
	solved_once = true
	status_label.text = "重量合适，等秤杆回正。"
	_animate_balance(8)
	effect_requested.emit("balance_settle")
	motion.tween_callback(func(): status_label.text = "两盘相平。柜内锁舌退开了。")
	motion.tween_interval(0.16)
	await motion.finished
	if not is_inside_tree():
		return
	solved.emit()

func _shake_feedback() -> void:
	if GameState.reduced_flash or not is_instance_valid(status_label):
		return
	var base_x := 18.0
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(status_label, "position:x", base_x + 4.0, 0.04)
	tw.tween_property(status_label, "position:x", base_x - 4.0, 0.04)
	tw.tween_property(status_label, "position:x", base_x + 2.0, 0.04)
	tw.tween_property(status_label, "position:x", base_x, 0.04)

func set_focus_suspended(suspended: bool) -> void:
	if focus_suspended == suspended:
		return
	focus_suspended = suspended
	process_mode = Node.PROCESS_MODE_DISABLED if suspended else Node.PROCESS_MODE_ALWAYS
	if is_instance_valid(motion):
		if suspended:
			motion.pause()
		else:
			motion.play()

func _process(_delta: float) -> void:
	if not is_instance_valid(beam_pivot):
		return
	var angle := beam_pivot.rotation
	left_pan.position = scale_center + Vector2(-BEAM_HALF_SPAN, 4).rotated(angle)
	right_pan.position = scale_center + Vector2(BEAM_HALF_SPAN, 4).rotated(angle)

func _label(value: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.size = dimensions
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color("030a07"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 8
	add_child(label)
	return label

func _button(text_value: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.position = at
	button.size = dimensions
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color("e6ddc5"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("17251e")
	normal.border_color = Color("857453")
	normal.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("314b39")
	hover.border_color = Color("d0b273")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	add_child(button)
	return button
