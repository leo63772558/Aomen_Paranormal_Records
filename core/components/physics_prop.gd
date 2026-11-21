extends Node2D
class_name PhysicsProp

var kind := "tin_can"
var vel := Vector2.ZERO
var spin_vel := 0.0
var bounds := Rect2(40, 140, 560, 160)
var kick_cooldown := 0.0
var target_player: Node2D

static func spawn(parent: Node2D, prop_kind: String, at: Vector2, room_bounds: Rect2, player_ref: Node2D = null) -> Node2D:
	var p := new()
	p.kind = prop_kind
	p.position = at
	p.bounds = room_bounds
	p.target_player = player_ref
	p.z_index = int(at.y)
	parent.add_child(p)
	return p

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	rotation = randf_range(-0.6, 0.6)

func _physics_process(delta: float) -> void:
	kick_cooldown = maxf(0.0, kick_cooldown - delta)
	if not is_instance_valid(target_player):
		target_player = get_parent().get("player") as Node2D
	if is_instance_valid(target_player) and kick_cooldown <= 0.0:
		var d := position.distance_to(target_player.position)
		if d < 16.0:
			var push_dir := (position - target_player.position).normalized()
			if push_dir.length_squared() < 0.01:
				push_dir = Vector2.RIGHT.rotated(randf() * TAU)
			vel = push_dir * randf_range(110.0, 165.0)
			spin_vel = randf_range(-14.0, 14.0)
			kick_cooldown = 0.35
			var sfx := "tool_clink" if kind in ["tin_can", "glass_bottle"] else "balance_weight"
			AudioManager.play_at(get_parent(), sfx, position, -9.0)
			EventBus.noise_emitted.emit(global_position, 42.0, "physics_prop")

	if vel.length_squared() > 0.5:
		var next_pos := position + vel * delta
		if next_pos.x < bounds.position.x or next_pos.x > bounds.end.x:
			vel.x = -vel.x * 0.55
			next_pos.x = clampf(next_pos.x, bounds.position.x, bounds.end.x)
		if next_pos.y < bounds.position.y or next_pos.y > bounds.end.y:
			vel.y = -vel.y * 0.55
			next_pos.y = clampf(next_pos.y, bounds.position.y, bounds.end.y)
		position = next_pos
		rotation += spin_vel * delta
		vel = vel.move_toward(Vector2.ZERO, 260.0 * delta)
		spin_vel = move_toward(spin_vel, 0.0, 22.0 * delta)
		z_index = int(position.y)
		queue_redraw()

func _draw() -> void:
	match kind:
		"tin_can":
			draw_rect(Rect2(-5, -3, 10, 6), Color("8f3d35"))
			draw_rect(Rect2(-3, -3, 6, 6), Color("c9c2b2"))
			draw_rect(Rect2(-5, -3, 10, 6), Color("29231e"), false, 1.0)
		"glass_bottle":
			draw_rect(Rect2(-6, -3, 8, 6), Color(0.22, 0.42, 0.30, 0.85))
			draw_rect(Rect2(2, -1.5, 4, 3), Color(0.28, 0.50, 0.36, 0.85))
		"casino_chip":
			draw_circle(Vector2.ZERO, 5.0, Color("9e2a25"))
			draw_arc(Vector2.ZERO, 5.0, 0, TAU, 12, Color("e6d49c"), 1.3)
			draw_circle(Vector2.ZERO, 2.2, Color("d9c382"))
		_:
			draw_circle(Vector2.ZERO, 4.0, Color("8a8270"))
