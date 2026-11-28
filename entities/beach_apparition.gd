extends CharacterBody2D

signal caught
var beach: Node2D
var player: PlayerController
var mesh: Polygon2D
var blend_mesh: Polygon2D
var rest: PackedVector2Array
var tex_size := Vector2(1024, 1024)
var current_cell := Vector2i(-1, -1)
var blend_cell := Vector2i(-1, -1)
var smooth_facing_x := 1.0
var clock := 0.0
var active := true
var warned := false
var mist_timer := 0.0
var chasing_music_on := false
var flank_bias := 1.0
var flash_receiver: PhoneFlashReceiver


func _start_butcher_chase_music() -> void:
	for m in AudioManager.get_method_list():
		if String(m.name) == "start_chase_music":
			var args: Array = m.args
			if args.size() >= 1:
				AudioManager.call("start_chase_music", "butcher")
			else:
				AudioManager.start_chase_music()
			return
	AudioManager.start_chase_music()


func _stop_butcher_chase_music() -> void:
	if chasing_music_on:
		chasing_music_on = false
		AudioManager.stop_chase_music()


func _exit_tree() -> void:
	_stop_butcher_chase_music()


func _ready() -> void:
	flash_receiver = PhoneFlashReceiver.new()
	flash_receiver.sense_offset = Vector2(0, -68)
	add_child(flash_receiver)
	collision_layer = 4
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 12
	collision.shape = shape
	add_child(collision)
	mesh = _mesh(Vector2i(0, 0), 84.0, 96.0)
	tex_size = mesh.texture.get_size()
	rest = mesh.polygon.duplicate()
	add_child(mesh)
	blend_mesh = _mesh(Vector2i(1, 0), 84.0, 96.0)
	blend_mesh.modulate.a = 0.0
	add_child(blend_mesh)
	_set_pose_cell(Vector2i(0, 0))
	_set_blend_cell(Vector2i(1, 0))
	GhostTaunt.attach(self, PackedStringArray([
		"小子，怎么又是你？！撞破老子抛尸，今天非把你灭口不可！",
		"大关斜巷让你跑了，黑沙海滩看你往哪逃！",
		"那个女仔躲不远的……等老子切完这批再收拾你们！",
		"别躲在车灯底下！滚出来！"
	]), 4.4)


static func _mesh(cell: Vector2i, width := 84.0, height := 96.0) -> Polygon2D:
	var polygon := Polygon2D.new()
	var tex: Texture2D = preload("res://assets/characters/butcher_ghost_v6.png")
	polygon.texture = tex
	var cell_sz := tex.get_size() * 0.5
	var region := Rect2(Vector2(cell.x, cell.y) * cell_sz, cell_sz)
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var triangles: Array = []
	for row in range(17):
		for column in range(13):
			var ratio := Vector2(column / 12.0, row / 16.0)
			vertices.append(Vector2((ratio.x - 0.5) * width, (ratio.y - 1.0) * height))
			uv.append(region.position + region.size * ratio)
	for row in range(16):
		for column in range(12):
			var i := row * 13 + column
			triangles.append(PackedInt32Array([i, i + 1, i + 14]))
			triangles.append(PackedInt32Array([i, i + 14, i + 13]))
	polygon.polygon = vertices
	polygon.uv = uv
	polygon.polygons = triangles
	return polygon


func _set_pose_cell(cell: Vector2i) -> void:
	if cell == current_cell or not is_instance_valid(mesh):
		return
	current_cell = cell
	var cell_sz := tex_size * 0.5
	var pad := Vector2(4.0, 4.0)
	var region := Rect2(Vector2(cell.x, cell.y) * cell_sz + pad, cell_sz - pad * 2.0)
	var uv := PackedVector2Array()
	for row in range(17):
		for column in range(13):
			var ratio := Vector2(column / 12.0, row / 16.0)
			uv.append(region.position + region.size * ratio)
	mesh.uv = uv


func _set_blend_cell(cell: Vector2i) -> void:
	if cell == blend_cell or not is_instance_valid(blend_mesh):
		return
	blend_cell = cell
	var cell_sz := tex_size * 0.5
	var pad := Vector2(4.0, 4.0)
	var region := Rect2(Vector2(cell.x, cell.y) * cell_sz + pad, cell_sz - pad * 2.0)
	var uv := PackedVector2Array()
	for row in range(17):
		for column in range(13):
			var ratio := Vector2(column / 12.0, row / 16.0)
			uv.append(region.position + region.size * ratio)
	blend_mesh.uv = uv


func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(player):
		velocity = Vector2.ZERO
		_stop_butcher_chase_music()
		return
	if flash_receiver.is_stunned():
		velocity = Vector2.ZERO
		return
	clock += delta
	var focus := flash_receiver.focus_after_flash(player)
	var delta_to := focus - global_position
	var dist := delta_to.length()
	var lit: bool = beach.in_headlight(position)
	var player_in_beam: bool = beach.in_headlight(player.position)
	var approach: bool = player.position.y > 246.0 and dist < 440.0 and not lit and not player_in_beam
	var chase_speed := 112.0 if dist < 210.0 else 96.0
	if approach:
		velocity = delta_to.normalized() * chase_speed if dist > 0.5 else Vector2.ZERO
	elif lit:
		var away := -delta_to.normalized() if dist > 1.0 else Vector2.DOWN
		if position.x > 1060.0:
			flank_bias = -1.0
		elif position.x < 220.0:
			flank_bias = 1.0
		elif absf(player.position.x - position.x) > 48.0:
			flank_bias = -1.0 if player.position.x < position.x else 1.0
		var perp := Vector2(-away.y, away.x)
		if perp.x * flank_bias < 0.0:
			perp = -perp
		velocity = perp * 98.0 + away * 35.0
	else:
		velocity = Vector2.ZERO
	if player.position.y <= 246.0 or position.y < 258.0:
		velocity.y = maxf(velocity.y, 24.0)
	if approach and dist < 290.0:
		if not chasing_music_on:
			chasing_music_on = true
			_start_butcher_chase_music()
	elif player.position.y <= 246.0 or player_in_beam:
		_stop_butcher_chase_music()
	move_and_slide()
	position = Vector2(clampf(position.x, 70, 1190), clampf(position.y, 258, 676))
	z_index = int(position.y)

	# butcher_ghost_v6.png faces LEFT naturally in all 4 cells -> flip horizontally (-1) when moving right!
	var target_fx := smooth_facing_x
	var blend_alpha := 0.0
	if approach and dist < 116.0:
		_set_pose_cell(Vector2i(1, 1))
		_set_blend_cell(Vector2i(0, 1))
		blend_alpha = 0.25 + 0.20 * sin(clock * 11.0)
		if absf(velocity.x) > 5.0:
			target_fx = -1.0 if velocity.x > 0.0 else 1.0
	elif velocity.length() > 10.0:
		_set_pose_cell(Vector2i(0, 0))
		_set_blend_cell(Vector2i(1, 0))
		blend_alpha = 0.5 + 0.5 * sin(clock * 10.5)
		if absf(velocity.x) > 5.0:
			target_fx = -1.0 if velocity.x > 0.0 else 1.0
	else:
		_set_pose_cell(Vector2i(0, 0))
		_set_blend_cell(Vector2i(0, 1))
		blend_alpha = 0.14 + 0.14 * sin(clock * 3.0)
		target_fx = 1.0 if player.position.x < position.x else -1.0
	smooth_facing_x = lerpf(smooth_facing_x, target_fx, 1.0 - exp(-15.0 * delta))
	if absf(smooth_facing_x) < 0.15:
		smooth_facing_x = 0.15 * signf(target_fx)

	var bob_y := sin(clock * 10.5) * (2.4 if velocity.length() > 10.0 else 0.7)
	var lean_rot := clampf(velocity.x * 0.0008 + sin(clock * 5.2) * 0.032, -0.14, 0.14)
	mesh.scale = Vector2(smooth_facing_x, 1.0 + sin(clock * 10.5) * 0.03)
	mesh.rotation = lerpf(mesh.rotation, lean_rot, 1.0 - exp(-14.0 * delta))
	mesh.position.y = bob_y
	var posed := rest.duplicate()
	var moving_amp := 1.0 if (approach or lit or velocity.length() > 10.0) else 0.32
	for i in range(posed.size()):
		var point := posed[i]
		var leg := clampf((point.y + 48.0) / 48.0, 0, 1)
		var side := -1.0 if point.x < 0 else 1.0
		point.x += sin(clock * 10.5 + side * PI * 0.5) * leg * (3.2 * moving_amp)
		point.y += sin(clock * 5.2 + point.x * 0.06) * (1.0 - leg) * 1.2
		posed[i] = point
	mesh.polygon = posed
	if is_instance_valid(blend_mesh):
		blend_mesh.polygon = posed
		blend_mesh.scale = mesh.scale
		blend_mesh.rotation = mesh.rotation
		blend_mesh.position = mesh.position
		blend_mesh.modulate = Color(mesh.modulate.r, mesh.modulate.g, mesh.modulate.b, mesh.modulate.a * blend_alpha)
	if not GameState.reduced_flash:
		if lit:
			mesh.modulate = Color(1.0, 0.90, 0.84, 0.60 + 0.15 * sin(clock * 28.0))
			mesh.position.x = sin(clock * 40.0) * 2.4
		elif approach:
			mesh.modulate = Color(1.0, 0.92, 0.90, 0.96)
			mesh.position.x = 0.0
			mist_timer -= delta
			if mist_timer <= 0.0:
				mist_timer = 0.24
				_spawn_blood_mud_trail()
		else:
			mesh.modulate = Color(0.92, 0.88, 0.86, 0.94)
			mesh.position.x = 0.0
	if approach and dist < 220.0 and not warned:
		warned = true
		if is_instance_valid(beach) and "hud" in beach and is_instance_valid(beach.hud):
			beach.hud.notify("「小子，怎么又是你？！撞破老子抛尸，我要把你灭口！」拎刀屠夫扑了过来——躲入远光灯或按 [R] 强闪！")
	if flash_receiver.may_catch(player) and approach and global_position.distance_to(player.global_position) < 30:
		active = false
		velocity = Vector2.ZERO
		_stop_butcher_chase_music()
		caught.emit()


func _spawn_blood_mud_trail() -> void:
	if get_parent() == null:
		return
	var puddle := Polygon2D.new()
	puddle.polygon = PackedVector2Array([Vector2(-8, 0), Vector2(-3, -3.5), Vector2(7, -2), Vector2(9, 2.5), Vector2(-2, 4.5)])
	puddle.color = Color(0.28, 0.04, 0.04, 0.54)
	puddle.global_position = global_position + Vector2(randf_range(-5.0, 5.0), 2.0)
	puddle.z_index = 2
	get_parent().add_child(puddle)
	var tw := puddle.create_tween()
	tw.tween_property(puddle, "scale", Vector2(1.4, 1.2), 0.7)
	tw.parallel().tween_property(puddle, "modulate:a", 0.0, 0.95)
	tw.tween_callback(puddle.queue_free)
