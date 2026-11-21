extends Node

var failures := 0
var checks := 0

func _enter_tree() -> void:
	if DisplayServer.get_name() != "headless":
		get_window().set_flag(Window.FLAG_NO_FOCUS, true)
		get_window().position = Vector2i(-32000, -32000)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png("res://docs/build_reports/player_feedback_251_" + name + ".png") == OK, name + " rendered")

func click(board: Control, point: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		board._gui_input(event)

func run() -> void:
	if GameState.profile != "test":
		get_tree().quit(1)
		return
	GameState.reset_opening()
	GameState.opening_resume_checked = true
	var menu = preload("res://ui/main_menu.tscn").instantiate()
	add_child(menu)
	var captions: Array[String] = []
	for child in menu.menu.get_children():
		captions.append(child.text)
	check(captions == ["新游戏", "继续游戏", "设置", "退出"], "title only presents the four main actions")
	await shot("title")
	menu.queue_free()
	await get_tree().process_frame

	for id in DemoItems.ENTRIES:
		check(DemoItems.texture(id) != null, "inventory artwork: " + id)
	GameState.current_room_id = "ch0_hk_home"
	GameState.pending_entry_id = "from_work"
	var home = preload("res://levels/ch0_tanglau/hk_home_026.tscn").instantiate()
	add_child(home)
	await get_tree().process_frame
	home._photo(DemoItems.texture("old_304_photo"))
	var display: TextureRect
	for candidate in home.hud.panel_content.find_children("*", "TextureRect", true, false):
		if candidate.texture == DemoItems.texture("old_304_photo"):
			display = candidate
			break
	check(is_instance_valid(display) and display.size == Vector2(276, 184), "opening photo is reduced and keeps a 3:2 frame")
	await shot("photo")
	home._close()
	home.queue_free()
	await get_tree().process_frame

	var hud = preload("res://ui/quiet_hud.gd").new()
	add_child(hud)
	hud.open_panel("阿豪", "姐夫，我去后廊找总闸。", [], false, "黄梓豪")
	var actor_portrait := false
	for child in hud.panel_content.get_children():
		if child is TextureRect and child.texture != null:
			actor_portrait = child.texture.resource_path.ends_with("ahhao_portrait_252.png")
	check(actor_portrait, "Ah Hao dialogue uses his own portrait")
	await shot("ahhao")
	hud.close_panel()

	var lock = preload("res://ui/bunker_lock_puzzle.gd").new()
	var opened := [false]
	lock.unlocked.connect(func(): opened[0] = true)
	GameState.opening_flags.bunker_oil_found = true
	GameState.take_demo_item("oil")
	for id in ["gate_key_1", "gate_key_2", "gate_key_3"]:
		GameState.take_demo_item(id)
	hud.open_widget(lock)
	get_tree().paused = true
	await shot("lock")
	click(lock, lock.HOOK)
	await get_tree().create_timer(0.41).timeout
	check(GameState.opening_flags.bunker_chain_relieved, "clicking the chain or hook lifts the chain")
	click(lock, lock.OIL_TRAY)
	await get_tree().create_timer(0.80).timeout
	check(GameState.opening_flags.bunker_lock_oiled, "clicking oil runs the pouring action")
	click(lock, lock.KEY_TRAYS[0])
	check(not GameState.opening_flags.bunker_lock_open, "wrong key remains a recoverable attempt")
	click(lock, lock.KEY_TRAYS[1])
	await get_tree().create_timer(0.53).timeout
	check(GameState.opening_flags.bunker_lock_open, "matching key turns from a click")
	click(lock, lock.HOOK)
	await get_tree().create_timer(0.54).timeout
	check(opened[0], "clicking the released chain removes it")
	hud.close_panel()
	var tape = preload("res://ui/bunker_tape_board.gd").new()
	hud.open_widget(tape)
	check(tape.classify.disabled, "tape waits for both clips")
	tape.play_buttons[0].pressed.emit()
	tape.play_buttons[1].pressed.emit()
	check(not tape.classify.disabled and "竖井" in tape.transcripts[1].text, "playing both clips reveals the route in text")
	await shot("tape")
	get_tree().paused = false
	hud.queue_free()
	await get_tree().process_frame
	print("PLAYER FEEDBACK checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
