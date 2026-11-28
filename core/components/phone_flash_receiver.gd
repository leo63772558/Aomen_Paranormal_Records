extends Node
class_name PhoneFlashReceiver

signal stunned
signal recovered

var sense_offset := Vector2(0, -45)
var stun_remaining := 0.0
var search_remaining := 0.0
var search_position := Vector2.ZERO
var pushback_velocity := Vector2.ZERO
var pushback_time := 0.0
var body: CharacterBody2D

func _ready() -> void:
	body = get_parent() as CharacterBody2D
	EventBus.camera_flash_fired.connect(_receive_flash)

static func in_beam(origin: Vector2, look_dir: Vector2, center: Vector2, reach: float, angle: float) -> bool:
	if not origin.is_finite() or not look_dir.is_finite() or not center.is_finite() or look_dir.length_squared() < 0.000001:
		return false
	var offset := center - origin
	if offset.length_squared() > reach * reach + 0.0001:
		return false
	return offset.length_squared() < 0.000001 or look_dir.normalized().dot(offset.normalized()) + 0.000001 >= cos(deg_to_rad(angle * 0.5))

func _receive_flash(origin: Vector2, look_dir: Vector2) -> void:
	if get_tree().paused or not is_instance_valid(body) or not body.active:
		return
	var player: PlayerController
	for candidate in get_tree().get_nodes_in_group("phone_flash_actor"):
		if candidate.controls_enabled and candidate.appearance not in ["jiamin", "ah_hao"]:
			player = candidate
			break
	# Align beam geometry on a consistent torso/ground plane so close-range ghosts never pass
	# beneath an elevated phone lens origin (old y-70.4 vs y-45.0 caused 56px blind spot!).
	var reach: float = GameState.RULES.phone_flash_range
	var cone_angle: float = GameState.RULES.phone_flash_angle
	var center := body.global_position + sense_offset
	var hit := in_beam(origin, look_dir, center, reach, cone_angle)
	if not hit and is_instance_valid(player):
		var ground_offset := body.global_position - player.global_position
		var dist := ground_offset.length()
		if dist <= reach:
			# Generous close-range frontal cone when ghost is lunging right on top of player
			var eff_angle := cone_angle + (36.0 if dist <= 56.0 else 10.0)
			hit = in_beam(player.global_position, look_dir, body.global_position, reach, eff_angle)
	if not hit:
		return
	# Use floor-level actor-to-actor raycast on layer 1 (World_Wall) so walls block flash properly
	# while standing near north walls (where elevated origin y-70 sticks into wall footprint) or
	# flashing over floor pits (layer 6) NEVER false-blocks!
	if is_instance_valid(player):
		var ray := PhysicsRayQueryParameters2D.create(player.global_position, body.global_position, 1)
		if not body.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			return
		search_position = player.global_position
	else:
		var ray := PhysicsRayQueryParameters2D.create(origin, center, 1)
		if not body.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			return
		search_position = body.global_position
	stun_remaining = GameState.RULES.phone_flash_stun
	search_remaining = GameState.RULES.enemy_search_time
	body.velocity = Vector2.ZERO
	var away_origin := player.global_position if is_instance_valid(player) else origin
	var away_dir := (body.global_position - away_origin).normalized()
	if away_dir.length_squared() < 0.01:
		away_dir = look_dir.normalized()
	pushback_velocity = away_dir * 225.0
	pushback_time = 0.28
	EventBus.phone_defense_feedback.emit("强闪命中！恶灵被强光逼退并陷入眩晕！")
	stunned.emit()

func _physics_process(delta: float) -> void:
	if pushback_time > 0.0 and is_instance_valid(body):
		pushback_time = maxf(0.0, pushback_time - delta)
		body.move_and_collide(pushback_velocity * delta)
		pushback_velocity = pushback_velocity.lerp(Vector2.ZERO, minf(delta * 9.0, 1.0))
	if stun_remaining > 0.0:
		stun_remaining = maxf(0.0, stun_remaining - delta)
		if is_instance_valid(body) and not GameState.reduced_flash:
			body.modulate = Color(1.0, 0.96, 0.90, 0.55 + 0.25 * absf(sin(stun_remaining * 18.0)))
		if stun_remaining == 0.0:
			if is_instance_valid(body):
				body.modulate = Color.WHITE
			recovered.emit()
	elif search_remaining > 0.0:
		search_remaining = maxf(0.0, search_remaining - delta)

func is_stunned() -> bool:
	return stun_remaining > 0.0

func focus_after_flash(current_target: Node2D) -> Vector2:
	if search_remaining <= 0.0:
		return current_target.global_position
	var ray := PhysicsRayQueryParameters2D.create(body.global_position, current_target.global_position, 1)
	var visible_target := body.global_position.distance_to(current_target.global_position) <= GameState.RULES.flashlight_range
	if current_target is PlayerController and current_target.hidden_in_wardrobe:
		visible_target = false
	if visible_target and body.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		search_remaining = 0.0
		return current_target.global_position
	return search_position

func may_catch(current_target: Node2D = null) -> bool:
	if get_tree().paused or not is_instance_valid(body) or not body.active or is_stunned() or search_remaining > 0.0:
		return false
	if current_target == null:
		return true
	if not is_instance_valid(current_target):
		return false
	if current_target is PlayerController and current_target.hidden_in_wardrobe:
		return false
	var ray := PhysicsRayQueryParameters2D.create(body.global_position, current_target.global_position, 1)
	return body.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
