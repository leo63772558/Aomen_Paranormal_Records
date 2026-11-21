extends Control

var layout_id := "silt"

const PLATE_SIZE := Vector2(570, 199)

static func pipe_symbol(index: int, tint: Color, thickness: float) -> Node2D:
	var symbol := Node2D.new()
	var strokes: Array = [
		[Vector2(-8, 0), Vector2(-5, -7), Vector2(4, -7), Vector2(8, 0), Vector2(4, 7), Vector2(-5, 7), Vector2(-8, 0)]
	] if index == 0 else []
	if index == 1:
		strokes = [[Vector2(-6, -6), Vector2(6, 6)], [Vector2(-6, 6), Vector2(6, -6)]]
	elif index == 2:
		for x in [-8.0, 0.0, 8.0]:
			strokes.append([Vector2(x - 3, 7), Vector2(x + 3, -7)])
	for points in strokes:
		var stroke := Line2D.new()
		stroke.points = PackedVector2Array(points)
		stroke.default_color = tint
		stroke.width = thickness
		stroke.antialiased = true
		symbol.add_child(stroke)
	return symbol

static func rescue_plate() -> Node2D:
	var plate := Node2D.new()
	var metal := Sprite2D.new()
	var crop := AtlasTexture.new()
	crop.atlas = preload("res://assets/tilesets/coastal_pressure_gallery_060.png")
	crop.region = Rect2(375, 73, 266, 154)
	crop.filter_clip = true
	metal.texture = crop
	metal.centered = false
	metal.scale = PLATE_SIZE / crop.region.size
	plate.add_child(metal)
	for row in range(3):
		var y := 33.0 + row * 61.0
		var route := Line2D.new()
		route.points = PackedVector2Array([
			Vector2(122, y + 10), Vector2(174, y + 10),
			Vector2(187, y), Vector2(359, y)
		])
		route.default_color = Color("433d2e")
		route.width = 3.0
		route.antialiased = true
		plate.add_child(route)
		var mark := pipe_symbol(row, Color("eee1b8") if row == 2 else Color("453527"), 2.4)
		mark.position = Vector2(261, y)
		plate.add_child(mark)
	return plate

func setup(id: String) -> Control:
	layout_id = id
	return self

static func marker(world: Node2D, caption: String, at: Vector2) -> Label:
	var label := Label.new()
	label.text = caption + " ◆"
	label.position = at - Vector2(42, 0)
	label.size.x = 84
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("efd399"))
	label.add_theme_color_override("font_outline_color", Color("16120f"))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate = Color.WHITE
	label.z_index = 35
	world.add_child(label)
	return label

func _ready() -> void:
	var rescue := layout_id == "rescue"
	_label("三路管线图" if rescue else "淤泥岔口 · 工事图", Vector2(24, 14), 23)
	if rescue:
		var plate := rescue_plate()
		plate.position = Vector2(24, 57)
		add_child(plate)
	var ends := ["旧回声箱", "封死的泵槽", "维护舱"] if rescue else ["坍塌", "干燥拱道", "积水闸门"]
	var starts := ["上管", "中管", "下管"] if rescue else ["左支路", "检修干路", "低处支路"]
	for row in range(3):
		var y := 77.0 + row * 61.0
		var tint := Color("251b13") if rescue else Color("eff0df")
		_label(starts[row], Vector2(63 if rescue else 48, y), 16, tint)
		_label(ends[row], Vector2(414, y), 16, tint)
	_label("找到同样的记号。换个节奏敲，数它回了几下。" if rescue else "沿粉笔箭头穿过小拱门。", Vector2(24, 278), 15)
	_label("Esc 返回", Vector2(518, 278), 14)

func _label(value: String, at: Vector2, font_size: int, tint := Color("eff0df")) -> void:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	if tint == Color("251b13"):
		label.add_theme_color_override("font_outline_color", Color("d9bd8f", 0.58))
		label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func _draw() -> void:
	if layout_id == "rescue":
		return
	draw_rect(Rect2(24, 57, 570, 199), Color("242b26"))
	draw_rect(Rect2(24, 57, 570, 199), Color("80735b"), false, 1.5)
	for row in range(3):
		var y := 89.0 + row * 61.0
		var marked := row == 1
		var ink := Color("d7bb7e") if marked else Color("74756a")
		draw_line(Vector2(147, y), Vector2(387, y), ink, 4.0, true)
		draw_circle(Vector2(147, y), 6.0, ink)
		draw_circle(Vector2(387, y), 6.0, ink)
		if marked:
			for dash in range(3):
				var x := 253.0 + dash * 12.0
				draw_line(Vector2(x, y + 10), Vector2(x + 6, y - 11), Color("eee2c6"), 2.0, true)
