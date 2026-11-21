extends Node2D

var actor: PlayerController
var pose: Sprite2D
var flash_light: PointLight2D
var pose_time := 0.0
var pulse_time := 0.0
var last_origin := Vector2.ZERO
var last_direction := Vector2.RIGHT
var last_result := {"ok":false,"reason":""}
var preparation_socket: Node2D
var socket_hint: Label

func _ready() -> void:
	actor = get_parent() as PlayerController
	actor.add_to_group("phone_flash_actor")
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://core/data/opening_art.json"))
	pose = PoseArt.sprite(preload("res://assets/characters/dawen_camera_006.png"), layout.camera)
	pose.name = "RaisedPhonePose"
	pose.scale *= actor.visual_size_multiplier
	pose.hide()
	add_child(pose)
	flash_light = PointLight2D.new()
	flash_light.name = "PhonePulse"
	flash_light.texture = preload("res://assets/lighting/flashlight_cone.png")
	flash_light.texture_scale = GameState.RULES.phone_flash_range / GameState.RULES.flashlight_range
	flash_light.range_item_cull_mask = 3
	flash_light.shadow_enabled = true
	flash_light.color = Color("e4efff")
	flash_light.enabled = false
	add_child(flash_light)
	call_deferred("prepare_chapter")

func prepare_chapter() -> void:
	if actor.appearance in ["jiamin", "ah_hao"] or not actor.allow_phone_defense:
		return
	_build_preparation_socket()
	if GameState.grant_chapter_supply(GameState.current_chapter_id, GameState.current_room_id):
		EventBus.phone_defense_feedback.emit("手电已满 · 强闪 ×2 [R]")

func _unhandled_input(event: InputEvent) -> void:
	if not actor.controls_enabled or not actor.allow_phone_defense:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("camera_flash"):
		get_viewport().set_input_as_handled()
		fire()
	elif event.is_action_pressed("interact") and _socket_selected():
		get_viewport().set_input_as_handled()
		if GameState.recharge_preparation():
			AudioManager.play_world_effect("power_switch")
			EventBus.phone_defense_feedback.emit("接电完成 · 手电与手机充满；本章剩余强闪 %d 次。" % GameState.phone_flash_charges)

func _build_preparation_socket() -> void:
	if not GameState.PHONE_PREPARATION_POINTS.has(GameState.current_room_id):
		return
	var room := actor.get_parent()
	if room.get_node_or_null("ChapterPreparationSocket") != null:
		return
	preparation_socket = Node2D.new()
	preparation_socket.name = "ChapterPreparationSocket"
	preparation_socket.position = GameState.PHONE_PREPARATION_POINTS[GameState.current_room_id]
	preparation_socket.z_index = int(preparation_socket.position.y)
	room.add_child(preparation_socket)
	var body := LevelGeometry.wall(preparation_socket, Rect2(-10, -5, 20, 8))
	body.name = "PowerSocketBody"
	var art := Sprite2D.new()
	art.texture = preload("res://assets/props/meter_connector_008.png")
	art.position = Vector2(0, -11)
	art.scale = Vector2(30, 25) / art.texture.get_size()
	preparation_socket.add_child(art)
	socket_hint = Label.new()
	socket_hint.text = "[ E ] 接电"
	socket_hint.position = Vector2(-28, -43)
	socket_hint.add_theme_font_size_override("font_size", 11)
	socket_hint.add_theme_color_override("font_color", Color("e4d3a7"))
	socket_hint.light_mask = 2
	socket_hint.hide()
	preparation_socket.add_child(socket_hint)

func _socket_selected() -> bool:
	if not is_instance_valid(preparation_socket) or not GameState.at_phone_preparation():
		return false
	var offset := preparation_socket.global_position - actor.global_position
	# A nearby door must not lose its E event to a socket at the edge of the
	# normal investigation range. The small wall socket requires a close,
	# deliberate facing, and displays its own hint only under those conditions.
	return offset.length() <= 28.0 and (offset.length() <= 10.0 or actor.look_dir.dot(offset.normalized()) > 0.78)

func phone_origin() -> Vector2:
	var sideways := -1.0 if actor.look_dir.x < -0.1 else 1.0
	# Lens landmark in the existing full-character phone-holding artwork.
	return actor.global_position + Vector2(195.0 * sideways, -1082.0) * absf(pose.scale.x)

func fire() -> Dictionary:
	last_result = GameState.try_use_phone_flash(actor)
	EventBus.phone_defense_feedback.emit(last_result.reason)
	if not last_result.ok:
		return last_result
	last_origin = phone_origin()
	last_direction = actor.look_dir.normalized()
	pose_time = 0.42
	pulse_time = 0.16
	pose.flip_h = actor.look_dir.x < -0.1
	pose.show()
	actor.sprite.hide()
	flash_light.global_position = last_origin
	flash_light.rotation = last_direction.angle()
	flash_light.enabled = true
	flash_light.energy = 0.45 if GameState.reduced_flash else 2.4
	AudioManager.play_world_effect("camera_shutter")
	EventBus.camera_flash_fired.emit(last_origin, last_direction)
	return last_result

func _process(delta: float) -> void:
	if is_instance_valid(socket_hint):
		socket_hint.visible = actor.controls_enabled and _socket_selected()
	if pose_time > 0.0:
		pose_time = maxf(0.0, pose_time - delta)
		pose.position.y = -sin((0.42 - pose_time) / 0.42 * PI) * 1.5
		actor.sprite.visible = false
		actor.lamp.enabled = false
		if pose_time == 0.0:
			pose.hide()
			actor.sprite.visible = not actor.hidden_in_wardrobe
			actor.lamp.enabled = actor.flashlight_on and actor.allow_flashlight and not actor.hidden_in_wardrobe
	if pulse_time > 0.0:
		pulse_time = maxf(0.0, pulse_time - delta)
		flash_light.energy = (0.45 if GameState.reduced_flash else 2.4) * pulse_time / 0.16
		flash_light.enabled = pulse_time > 0.0
