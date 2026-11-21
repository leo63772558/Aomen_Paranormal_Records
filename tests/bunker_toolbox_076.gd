extends Node

var checks := 0
var failures := 0
var picked: Array[int] = []
var cue_count := 0

func _enter_tree() -> void:
	if DisplayServer.get_name() != "headless":
		get_window().set_flag(Window.FLAG_NO_FOCUS, true)
		get_window().position = Vector2i(-32000, -32000)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")


func check(value: bool, label: String) -> void:
	checks += 1
	if value:
		print("PASS " + label)
	else:
		failures += 1
		push_error("FAIL " + label)


func frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame


func click(control: Control, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = true
	control._gui_input(event)


func run() -> void:
	check(GameState.profile == "test", "toolbox check uses isolated test profile")
	var toolbox := preload("res://ui/bunker_toolbox.gd").new()
	toolbox.size = Vector2(618, 330)
	add_child(toolbox)
	toolbox.key_selected.connect(func(index: int): picked.append(index))
	AudioManager.world_effect_requested.connect(func(id: String):
		if id == "metal_cover": cue_count += 1
	)
	get_tree().paused = true
	click(toolbox, Vector2(305, 180))
	await frames(10)
	check(toolbox.opening and not toolbox.opened and toolbox.open_progress > 0.0 and toolbox.open_progress < 1.0, "toolbox animates while the world is paused")
	toolbox.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var stopped_progress: float = toolbox.open_progress
	await frames(50)
	check(toolbox.opening and not toolbox.opened and is_equal_approx(toolbox.open_progress, stopped_progress), "focus loss freezes the unfinished toolbox animation")
	toolbox.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	if "--capture-toolbox" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var mid_frame := get_viewport().get_texture().get_image()
		check(mid_frame != null and not mid_frame.is_empty() and mid_frame.save_png("res://docs/build_reports/bunker_toolbox_opening_076.png") == OK, "hidden renderer captures the moving toolbox")
	click(toolbox, toolbox.key_rect(0).get_center())
	check(picked.is_empty(), "keys cannot be selected through the moving lid")
	await frames(50)
	check(toolbox.opened and not toolbox.opening and is_equal_approx(toolbox.open_progress, 1.0), "opening finishes and reveals the keys")
	check(cue_count == 1, "metal opening cue is requested exactly once")
	click(toolbox, toolbox.key_rect(1).get_center())
	check(picked == [2], "visible key accepts the corresponding click")
	if "--capture-toolbox" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		check(image != null and not image.is_empty() and image.save_png("res://docs/build_reports/bunker_toolbox_open_076.png") == OK, "hidden renderer captures the opened toolbox")
	print("BUNKER TOOLBOX checks=%d failures=%d" % [checks, failures])
	get_tree().paused = false
	get_tree().quit(0 if failures == 0 else 1)
