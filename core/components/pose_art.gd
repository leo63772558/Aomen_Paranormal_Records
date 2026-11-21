extends RefCounted
class_name PoseArt

static func sprite(texture: Texture2D, frame: Dictionary) -> Sprite2D:
	var result := Sprite2D.new()
	var atlas := AtlasTexture.new()
	var region = frame["region"]
	var anchor = frame["anchor"]
	atlas.atlas = texture
	atlas.region = Rect2(region[0], region[1], region[2], region[3])
	result.texture = atlas
	result.scale = Vector2.ONE * float(frame["scale"])
	result.offset = Vector2(float(region[2])/2.0-float(anchor[0]), float(region[3])/2.0-float(anchor[1]))
	result.light_mask = 2
	return result
