extends Node

var failures := 0

func _ready() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1

func run() -> void:
	check(GameState.profile == "test", "isolated movement profile")
	var player = preload("res://entities/player/player.tscn").instantiate()
	add_child(player)
	await get_tree().process_frame
	player.aim_override = true
	var distances: Array[float] = []
	for actions in [["move_right"], ["move_right", "move_down"], ["move_down"], ["move_down", "move_left"], ["move_left"], ["move_left", "move_up"], ["move_up"], ["move_up", "move_right"]]:
		for action in ["move_up", "move_down", "move_left", "move_right", "sprint"]:
			Input.action_release(action)
		player.clear_motion()
		player.position = Vector2.ZERO
		player.reset_physics_interpolation()
		for action in actions:
			Input.action_press(action)
		for _i in range(60):
			player._physics_process(1.0 / 60.0)
		distances.append(player.position.length())
		check(player.position.length() > 1.0, "movement works for " + str(actions))
	for action in ["move_up", "move_down", "move_left", "move_right", "sprint"]:
		Input.action_release(action)
	var minimum: float = distances.min()
	var maximum: float = distances.max()
	check(maximum - minimum < 0.1, "all eight directions travel equal distance")

	player.clear_motion()
	player.position = Vector2(320, 180)
	player.aim_override = false
	var cursor := InputEventMouseMotion.new()
	cursor.position = Vector2(320, 44)
	get_viewport().push_input(cursor, true)
	Input.action_press("move_down")
	for _i in range(90):
		player._physics_process(1.0 / 60.0)
	Input.action_release("move_down")
	check(player.position.y > 220.0 and player.look_dir.dot(Vector2.UP) > 0.99, "retreating for 1.5 seconds keeps the body aimed at the stationary mouse")
	check(absf(angle_difference(player.look_dir.angle(), player.pivot.rotation)) < 0.06, "the beam follows the same facing during a retreat")
	player.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	player.look_dir = Vector2.RIGHT
	player._physics_process(1.0 / 60.0)
	check(player.look_dir == Vector2.RIGHT, "focus loss clears the previous cursor aim")
	player.queue_free()
	print("EIGHT DIRECTIONS failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
