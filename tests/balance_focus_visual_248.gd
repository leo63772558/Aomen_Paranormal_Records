extends Node

var failures := 0
var completed := false

func _enter_tree() -> void:
	get_window().set_flag(Window.FLAG_NO_FOCUS, true)
	get_window().position = Vector2i(-32000, -32000)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures += 1

func run() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(2)
		return
	var layer := CanvasLayer.new()
	add_child(layer)
	var board = preload("res://levels/ch3_amparo_alley/balance_board.gd").new()
	board.position = Vector2(11, 15)
	layer.add_child(board)
	board.solved.connect(func(): completed = true)
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	for i in [0, 1, 2]: board._toggle_weight(i)
	board.submit_weight()
	board.set_focus_suspended(true)
	var angle: float = board.beam_pivot.rotation
	await get_tree().create_timer(0.8, true).timeout
	check(not completed and is_equal_approx(board.beam_pivot.rotation, angle), "focus loss freezes scale and result")
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png("res://docs/build_reports/balance_focus_248.png") == OK, "suspended scale renders")
	board.set_focus_suspended(false)
	await get_tree().create_timer(0.8, true).timeout
	check(completed, "focus return completes the scale")
	get_tree().paused = false
	print("BALANCE FOCUS VISUAL failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
