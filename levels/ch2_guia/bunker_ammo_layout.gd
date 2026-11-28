extends Node2D

const MAP_SIZE := Vector2(780, 528)
const EXIT := Vector2(390, 489)
const ENTRY := Vector2(390, 461)
const RECORDING := Vector2(692, 178)
const HALL_LIMITS := Rect2(64, 168, 512, 142)
const HALL_BLOCKS := [
	Rect2(64, 168, 153, 43), Rect2(116, 246, 148, 54),
	Rect2(350, 246, 150, 54), Rect2(272, 220, 13, 16), Rect2(285, 232, 18, 12)
]
const INNER_ROOM := Rect2(52, 112, 676, 388)
const PIT_W := 90.0
const PIT_H := 25.0
const PIT_ROWS := [282, 369, 458, 543, 632]
const PIT_COLS := [193, 460, 726, 991, 1258]
const GATE_TEX := preload("res://assets/props/bunker_iron_gate_v11.png")
var art: Texture2D
var floor_art: Texture2D
var exit_gate_sprite: Sprite2D
var exit_gate_body: StaticBody2D
var exit_gate_shadow: LightOccluder2D
var exit_gate_badge: PanelContainer
var exit_gate_badge_label: Label
var exit_gate_locked := false
var exit_gate_remain := 0.0
var gate_shake := 0.0
var gate_open_anim := 1.0
var gate_sparks: Array[Dictionary] = []

func set_exit_locked(locked: bool, remain_sec := 0.0) -> void:
	var changed := (exit_gate_locked != locked)
	exit_gate_locked = locked
	exit_gate_remain = remain_sec
	if changed and is_instance_valid(exit_gate_body):
		exit_gate_body.collision_layer = 1 if locked else 0
		exit_gate_shadow.visible = locked
	if changed and not locked:
		gate_shake = 0.25
		_spawn_gate_sparks(10, Color("e6cb7a"))
	queue_redraw()

func shake_exit_gate() -> void:
	gate_shake = 0.34
	_spawn_gate_sparks(8, Color("d85644"))
	queue_redraw()

func _spawn_gate_sparks(count: int, col: Color) -> void:
	if GameState.reduced_flash:
		return
	for _i in range(count):
		var a := randf_range(-PI, 0.0)
		var spd := randf_range(28.0, 96.0)
		gate_sparks.append({
			"pos": EXIT + Vector2(randf_range(-18.0, 18.0), 6.0),
			"vel": Vector2.from_angle(a) * spd,
			"life": randf_range(0.18, 0.38),
			"max_life": 0.38,
			"col": col
		})

func _process(delta: float) -> void:
	var dirty := false
	var target_open := 0.0 if exit_gate_locked else 1.0
	if absf(gate_open_anim - target_open) > 0.01:
		gate_open_anim = move_toward(gate_open_anim, target_open, delta * 3.8)
		dirty = true
	if gate_shake > 0.0:
		gate_shake = maxf(0.0, gate_shake - delta)
		dirty = true
	if not gate_sparks.is_empty():
		var nxt: Array[Dictionary] = []
		for s in gate_sparks:
			s["life"] = float(s["life"]) - delta
			if float(s["life"]) > 0.0:
				s["pos"] = Vector2(s["pos"]) + Vector2(s["vel"]) * delta
				s["vel"] = Vector2(s["vel"]) + Vector2(0, 180.0) * delta
				nxt.append(s)
		gate_sparks = nxt
		dirty = true
	if dirty or exit_gate_locked:
		queue_redraw()

static func pit_rect(row: int, column: int) -> Rect2:
	return Rect2(94 + 120 * column, 134 + 65 * row, PIT_W, PIT_H)

static func pit_colliders() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for row in range(5):
		for column in range(5):
			result.append(pit_rect(row, column).grow(-2.0))
	return result

func _ready() -> void:
	art = load("res://assets/tilesets/bunker_ammo_pits_2d_022.png")
	floor_art = load("res://assets/tilesets/ammo_floor_026.png")
	LevelGeometry.wall(self, Rect2(32, 0, 716, 112))
	LevelGeometry.wall(self, Rect2(32, 112, 20, 416))
	LevelGeometry.wall(self, Rect2(728, 112, 20, 416))
	LevelGeometry.wall(self, Rect2(52, 500, 302, 28))
	LevelGeometry.wall(self, Rect2(426, 500, 302, 28))
	LevelGeometry.wall(self, Rect2(354, 516, 72, 12))
	exit_gate_body = LevelGeometry.wall(self, Rect2(354, 492, 72, 9))
	exit_gate_body.name = "LockedIronGateFootprint"
	exit_gate_body.collision_layer = 0
	exit_gate_shadow = get_child(get_child_count() - 1) as LightOccluder2D
	exit_gate_shadow.hide()
	exit_gate_sprite = Sprite2D.new()
	exit_gate_sprite.name = "BunkerIronExitGate"
	exit_gate_sprite.texture = GATE_TEX
	exit_gate_sprite.position = Vector2(390, 496)
	exit_gate_sprite.scale = Vector2(146.0 / float(GATE_TEX.get_width()), 62.0 / float(GATE_TEX.get_height()))
	exit_gate_sprite.z_index = 515
	exit_gate_sprite.visible = false
	add_child(exit_gate_sprite)
	exit_gate_badge = PanelContainer.new()
	exit_gate_badge.position = Vector2(334, 444)
	exit_gate_badge.size = Vector2(112, 20)
	exit_gate_badge.z_index = 520
	exit_gate_badge.visible = false
	var bskin := StyleBoxFlat.new()
	bskin.bg_color = Color(0.05, 0.025, 0.025, 0.92)
	bskin.border_color = Color("b84438")
	bskin.set_border_width_all(1)
	exit_gate_badge.add_theme_stylebox_override("panel", bskin)
	exit_gate_badge_label = Label.new()
	exit_gate_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exit_gate_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	exit_gate_badge_label.add_theme_font_size_override("font_size", 11)
	exit_gate_badge_label.add_theme_color_override("font_color", Color("f6c8b0"))
	exit_gate_badge.add_child(exit_gate_badge_label)
	add_child(exit_gate_badge)
	for pit in pit_colliders():
		var body := StaticBody2D.new()
		# Use layer 6 (bit 32) for recessed floor pits so players & enemies cannot walk into them,
		# while light beams & [R] phone strong flash pass cleanly across open floor air!
		body.collision_layer = 32
		body.collision_mask = 6
		var size_shape := RectangleShape2D.new()
		size_shape.size = pit.size
		var collision := CollisionShape2D.new()
		collision.shape = size_shape
		collision.position = pit.get_center()
		body.add_child(collision)
		add_child(body)

func _draw() -> void:
	if art == null:
		return
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color("070a09"))
	draw_texture_rect(floor_art, Rect2(32, 0, 716, MAP_SIZE.y), false)
	for row in range(5):
		for column in range(5):
			draw_texture_rect_region(art, pit_rect(row, column), Rect2(PIT_COLS[column], PIT_ROWS[row], 242, 73))
	# Realistic painted corroded-iron barred bunker gate spanning the ENTIRE south doorway (320..460)
	var sx := sin(gate_shake * 92.0) * 4.2 if (gate_shake > 0.0 and not GameState.reduced_flash) else 0.0
	var gate_slide := gate_open_anim * 126.0
	if is_instance_valid(exit_gate_sprite):
		exit_gate_sprite.visible = (gate_open_anim < 0.98)
		exit_gate_sprite.position = Vector2(390.0 + sx - gate_slide, 496.0)
	if is_instance_valid(exit_gate_badge):
		var show_badge := (gate_open_anim < 0.96 and exit_gate_locked and exit_gate_remain > 0.0)
		exit_gate_badge.visible = show_badge
		if show_badge and is_instance_valid(exit_gate_badge_label):
			exit_gate_badge_label.text = "重铁栅反锁 %ds" % ceili(exit_gate_remain)
	for s in gate_sparks:
		var sa := clampf(float(s["life"]) / float(s["max_life"]), 0.0, 1.0)
		var c: Color = s["col"]
		c.a = sa
		draw_circle(Vector2(s["pos"]), 2.0 * sa + 0.6, c)

static func navigation(limits: Rect2, solid_rects: Array) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i(limits.position / 10.0), Vector2i(limits.size / 10.0) + Vector2i.ONE)
	grid.cell_size = Vector2(10, 10)
	grid.offset = Vector2(5, 5)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in range(grid.region.position.y, grid.region.end.y):
		for x in range(grid.region.position.x, grid.region.end.x):
			var cell := Vector2i(x, y)
			var world := grid.get_point_position(cell)
			var blocked := not limits.grow(-10).has_point(world)
			if not blocked:
				for rect: Rect2 in solid_rects:
					if rect.grow(9.0).has_point(world):
						blocked = true
						break
			grid.set_point_solid(cell, blocked)
	return grid
