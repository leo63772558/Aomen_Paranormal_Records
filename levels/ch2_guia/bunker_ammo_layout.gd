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
var art: Texture2D
var floor_art: Texture2D

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
	for pit in pit_colliders():
		var body := StaticBody2D.new()
		body.collision_layer = 1
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
