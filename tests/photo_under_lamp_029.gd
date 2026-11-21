extends Node

var checks := 0
var failed := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	print(("PASS " if condition else "FAIL ") + label)
	failed = failed or not condition

func _run() -> void:
	var packed := load("res://levels/ch0_tanglau/hk_home_026.tscn") as PackedScene
	_check(packed != null, "Hong Kong home scene loads")
	if packed == null:
		get_tree().quit(1)
		return
	var home := packed.instantiate()
	get_tree().root.add_child(home)
	for _i in range(24):
		await get_tree().process_frame

	var background := home.get_node_or_null("Background") as Sprite2D
	_check(background != null and background.texture != null and background.texture.resource_path.ends_with("hk_home_029.png"), "Desk background uses the cleaned art")
	var photo := home.get_node_or_null("OldPhotoUnderLamp") as Sprite2D
	_check(photo != null and photo.texture != null, "Interactive old photo is present")
	var frame := home.get_node_or_null("OldPhotoFrame") as Polygon2D
	_check(frame != null and frame.polygon.size() == 4, "Photo frame has four physical edges")
	var photo_area := home.get_node_or_null("OldPhotoInteractionArea") as Area2D
	_check(photo_area != null, "Photo has a matching non-blocking interaction area")
	if photo_area != null:
		_check(photo_area.collision_layer == 8 and photo_area.collision_mask == 2, "Photo interaction area uses Interactable and Player layers")
		_check(photo_area.position == Vector2(196.0, 136.0), "Photo interaction area follows the desk photo")
		var area_shape := photo_area.get_node_or_null("PhotoBounds") as CollisionPolygon2D
		_check(area_shape != null and area_shape.polygon.size() == 4, "Photo interaction bounds match its rectangular frame")
		if area_shape != null and area_shape.polygon.size() == 4:
			var area_bounds := Rect2(area_shape.polygon[0], Vector2.ZERO)
			for point in area_shape.polygon:
				area_bounds = area_bounds.expand(point)
			_check(area_bounds.size == Vector2(36.0, 24.0), "Photo interaction bounds cover the complete frame")
	if photo != null and photo.texture != null:
		var source_ratio := float(photo.texture.get_width()) / float(photo.texture.get_height())
		var display_ratio := (photo.texture.get_width() * photo.scale.x) / (photo.texture.get_height() * photo.scale.y)
		_check(is_equal_approx(source_ratio, 1.5), "Source photograph is 3:2")
		_check(absf(display_ratio - source_ratio) < 0.001, "Displayed photograph preserves the source ratio")
	if frame != null and frame.polygon.size() == 4 and photo != null:
		var bounds := Rect2(frame.polygon[0], Vector2.ZERO)
		for point in frame.polygon:
			bounds = bounds.expand(point)
		var framed_ratio := bounds.size.x / bounds.size.y
		_check(absf(framed_ratio - 1.5) < 0.001, "Outer frame matches the 3:2 photograph")
		_check(frame.position.distance_to(photo.position) < 0.01, "Photograph and frame share the same placement")
		_check(photo.position.distance_to(Vector2(196.0, 136.0)) < 0.01, "Photograph sits on the desk surface")
		var scene_targets: Dictionary = home.get("targets")
		var photo_target: Array = scene_targets.get("photo", [])
		_check(photo_target.size() >= 1, "Photo has an interaction hotspot")
		if photo_target.size() >= 1:
			var hotspot_local: Vector2 = photo_target[0] - photo.position
			var photo_bounds := Rect2(Vector2(-18.0, -12.0), Vector2(36.0, 24.0))
			_check(photo_bounds.has_point(hotspot_local), "Interaction hotspot overlaps the visible photograph")
			_check(absf(hotspot_local.x) < 0.01 and absf(hotspot_local.y - 11.0) < 0.01, "Photo hotspot sits just inside the player-facing frame edge")
	_check("左侧台灯" in home.hud.objective.text, "The objective locates the old photograph before the player searches")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var shot := get_tree().root.get_texture().get_image()
		_check(shot != null and not shot.is_empty(), "Hidden render produced a screenshot")
		if shot != null and not shot.is_empty():
			_check(shot.save_png("res://docs/build_reports/home_photo_030.png") == OK, "Rendered desk photograph saved")
	print("PHOTO_030_RESULT checks=%d failed=%s" % [checks, str(failed)])
	get_tree().quit(1 if failed else 0)
