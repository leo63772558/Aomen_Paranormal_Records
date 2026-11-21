extends Node
class_name PhoneFlashReceiver

signal stunned
signal recovered

var sense_offset := Vector2(0, -45)
var stun_remaining := 0.0
var search_remaining := 0.0
var search_position := Vector2.ZERO
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
	var center := body.global_position + sense_offset
	if not in_beam(origin, look_dir, center, GameState.RULES.phone_flash_range, GameState.RULES.phone_flash_angle):
		return
	var ray := PhysicsRayQueryParameters2D.create(origin, center, 1)
	if not body.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		return
	# Floor-level colliders represent the footprint of tall walls in this 2D view.
	# Also check the actor-to-actor line so elevated art cannot flash through them.
	var player: PlayerController
	for candidate in get_tree().get_nodes_in_group("phone_flash_actor"):
		if candidate.controls_enabled and candidate.appearance not in ["jiamin", "ah_hao"]:
			player = candidate
			break
	if is_instance_valid(player):
		ray = PhysicsRayQueryParameters2D.create(player.global_position, body.global_position, 1)
		if not body.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			return
		search_position = player.global_position
	else:
		search_position = body.global_position
	stun_remaining = GameState.RULES.phone_flash_stun
	search_remaining = GameState.RULES.enemy_search_time
	body.velocity = Vector2.ZERO
	stunned.emit()

func _physics_process(delta: float) -> void:
	if stun_remaining > 0.0:
		stun_remaining = maxf(0.0, stun_remaining - delta)
		if stun_remaining == 0.0:
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
