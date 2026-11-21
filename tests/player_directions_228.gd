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
	player.queue_free()
	print("EIGHT DIRECTIONS failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
