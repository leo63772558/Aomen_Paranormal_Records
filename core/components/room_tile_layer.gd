extends TileMapLayer

@export var background_texture: Texture2D = preload("res://assets/tilesets/tanglau_room_003.png")

func _ready() -> void:
	# The generated albedo is partitioned into actual 32px cells. Furniture and
	# collision/occluder geometry stay separate from the map artwork.
	var source_texture = background_texture
	var image: Image = source_texture.get_image()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var padded := Image.create(640, 384, false, Image.FORMAT_RGBA8)
	padded.fill(Color.BLACK)
	padded.blit_rect(image, Rect2i(0, 0, 640, 360), Vector2i.ZERO)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(padded)
	atlas.texture_region_size = Vector2i(32, 32)
	tile_set = TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	var source_id: int = tile_set.add_source(atlas)
	for y in range(12):
		for x in range(20):
			var cell := Vector2i(x, y)
			atlas.create_tile(cell)
			set_cell(cell, source_id, cell)
