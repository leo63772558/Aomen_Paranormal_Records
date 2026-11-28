extends Node

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		failures += 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func frames(count := 4) -> void:
	for _i in range(count):
		await get_tree().process_frame

func run() -> void:
	check(GameState.profile == "test", "isolated focus test")
	var fixture := preload("res://tests/ch6_rescue_061.gd").new()
	fixture._prepare_state()
	fixture.free()
	var scene = preload("res://levels/ch6_abandoned_vip/abandoned_vip_rescue_061.tscn").instantiate()
	add_child(scene)
	await frames()
	scene._close_panel()
	GameState.enter_role("dawen")
	GameState.opening_flags.ch6_signal_sent = true
	GameState.opening_flags.ch6_route_diagram_seen = true
	GameState.opening_flags.ch6_pipe_route_verified = true
	scene._sync_illusion_door_visibility()
	scene.player.controls_enabled = true
	scene.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(get_tree().paused and scene.hud.panel_open, "focus loss pauses Dawen exploration in the finale")
	scene._close_panel()
	check(not get_tree().paused and scene.player.controls_enabled, "resume restores Dawen controls after focus pause")
	scene.scene_action_active = true
	scene.player.controls_enabled = false
	scene.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(get_tree().paused and scene.hud.panel_open, "focus loss pauses an ongoing scene action")
	scene._close_panel()
	check(not get_tree().paused and not scene.player.controls_enabled and scene.scene_action_active, "resume keeps action control lock")
	scene.scene_action_active = false
	get_tree().paused = false
	scene.queue_free()
	await frames()
	print("FINALE FOCUS checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
