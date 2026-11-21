extends SceneTree

var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state = root.get_node("GameState")
	state.opening_resume_checked = true
	var menu = load("res://ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	var buttons = menu.find_children("*", "Button", true, false)
	check(buttons.size() == 2, "主菜单只有开始与退出")
	menu._start_game()
	var proceed: Button
	for button in menu.find_children("*", "Button", true, false):
		if button.text == "进入游戏":
			proceed = button
	check(proceed != null and menu.notice_panel != null, "开始后出现传闻声明")
	if proceed:
		proceed.pressed.emit()
		await process_frame
		await process_frame
		check(current_scene != null and current_scene.stage_kind == "street", "声明后进入街口")
		check(current_scene.hud.panel_open, "新游戏显示两位主角背景")
		current_scene.close_dialog()
	var player = current_scene.player
	check(not player.lamp.shadow_enabled, "手电光不被错误碰撞阴影遮住")
	check(player.animation_layout.size() > 0, "持手电角色帧加载")
	check(load("res://assets/audio/recorded/bunker_ambience.ogg") is AudioStreamOggVorbis, "洞内氛围音可加载")
	check(load("res://assets/audio/recorded/crypt_ambience.ogg") is AudioStreamOggVorbis, "地宫氛围音可加载")
	player.set_appearance("flashlight")
	player.position = Vector2(200, 200)
	player.look_dir = Vector2.RIGHT
	player.aim_override = true
	player.lamp.enabled = true
	var priest = load("res://entities/priest_013.gd").new()
	priest.position = Vector2(320, 200)
	priest.target = player
	priest.speed = 0.0
	current_scene.add_child(priest)
	await physics_frame
	for i in range(5):
		priest._physics_process(0.1)
	check(priest.frozen, "持续照射能暂时阻止黑衣人")
	for i in range(20):
		priest._physics_process(0.1)
	check(priest.frozen, "持续照射期间黑衣人保持静止")
	var wall = LevelGeometry.wall(current_scene, Rect2(250, 175, 8, 60))
	var wall_shadow = current_scene.get_child(current_scene.get_child_count() - 1)
	await physics_frame
	priest._physics_process(0.1)
	check(not priest.frozen, "墙壁挡住光线时不能照停黑衣人")
	wall.queue_free()
	wall_shadow.queue_free()
	await physics_frame
	priest._physics_process(0.1)
	check(priest.frozen, "移除遮挡后照射立即生效")
	player.look_dir = Vector2.LEFT
	priest._physics_process(0.9)
	check(not priest.frozen, "移开光线后黑衣人恢复行动")
	var circuit = load("res://ui/floor_power_diagram.gd").new()
	circuit.size = Vector2(618, 338)
	current_scene.add_child(circuit)
	var completed := [false]
	circuit.completed.connect(func(): completed[0] = true)
	for i in range(3):
		connect_circuit(circuit, i, i)
	await process_frame
	check(not completed[0] and circuit.connected.size() == 3, "错误接线不通电")
	for i in range(3):
		var unplug := InputEventMouseButton.new()
		unplug.button_index = MOUSE_BUTTON_RIGHT
		unplug.pressed = true
		unplug.position = circuit.port(true, i)
		circuit._gui_input(unplug)
	check(circuit.connected.is_empty(), "错误线路可以拔下重接")
	for pair in [[0, 1], [1, 2], [2, 0]]:
		connect_circuit(circuit, pair[0], pair[1])
	await process_frame
	check(completed[0], "按维修记录推断接线后通电")
	var old_scene = current_scene
	root.remove_child(old_scene)
	old_scene.queue_free()
	var room = load("res://levels/ch0_tanglau/room304.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	await process_frame
	var audio = root.get_node("AudioManager")
	audio.last_world_effect = ""
	room.show_old_photo()
	await create_timer(1.2, true).timeout
	check(audio.last_world_effect == "photo_knock", "首次看旧照触发敲门声")
	room.close_dialog()
	quit(1 if failures else 0)

func connect_circuit(circuit: Control, from_index: int, to_index: int) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = circuit.port(true, from_index)
	circuit._gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = circuit.port(false, to_index)
	circuit._gui_input(release)
