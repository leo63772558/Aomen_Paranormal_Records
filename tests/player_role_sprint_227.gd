extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1

func run() -> void:
	check(GameState.profile == "test", "isolated movement profile")
	var player = preload("res://entities/player/player.tscn").instantiate()
	add_child(player)
	await get_tree().process_frame
	player.aim_override = true
	Input.action_press("move_right")
	Input.action_press("sprint")
	GameState.stamina = 50.0
	player._physics_process(1.0 / 60.0)
	check(player.was_sprinting, "Daven can start sprinting")
	player.set_appearance("jiamin")
	GameState.stamina = 25.0
	player._physics_process(1.0 / 60.0)
	check(not player.was_sprinting and is_equal_approx(GameState.stamina, 25.0), "switching to Jiamin cancels inherited sprint and stamina drain")
	for _i in range(60):
		player._physics_process(1.0 / 60.0)
	check(player.velocity.length() <= GameState.RULES.crouch_speed + 0.01, "Jiamin remains within her movement speed while sprint is held")
	Input.action_release("move_right")
	Input.action_release("sprint")
	player.queue_free()
	print("ROLE MOVEMENT checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
