extends Node2D

const STAIRS := preload("res://levels/ch2_guia/bunker_stair_art.gd")
const FAMILY := preload("res://entities/bunker_family.gd")
const CAPTURE := preload("res://ui/demo_capture_animation.gd")
const START_Y := STAIRS.START_Y
const STEP_DISTANCE := STAIRS.TREAD
enum Phase { DOWN, LOOP, RETURN, LOST, LEFT }
var player: PlayerController
var hud
var stair_art: Node2D
var family: Array[CharacterBody2D] = []
var phase := Phase.DOWN
var steps_reached := 0
var reverse_time := 0.0
var eighty_nine_shown := false
var loop_ready := false
var steps_from_pursuit := false
var landing_light: PointLight2D

func _ready() -> void:
	AudioManager.set_bunker_ambience(true)
	steps_from_pursuit = GameState.demo_pursuit == "steps"
	stair_art = STAIRS.new()
	add_child(stair_art)
	LevelGeometry.wall(self, Rect2(165, 0, 16, START_Y + 45))
	LevelGeometry.wall(self, Rect2(459, 0, 16, START_Y + 45))
	LevelGeometry.wall(self, Rect2(165, START_Y + 43, 310, 16))
	LevelGeometry.wall(self, Rect2(165, STAIRS.y_at(100) - 18, 310, 11))
	player = preload("res://entities/player/player.tscn").instantiate()
	player.appearance = "flashlight"
	player.visual_size_multiplier = 1.65
	player.position = Vector2(320, START_Y)
	add_child(player)
	player.look_dir = Vector2.UP
	var camera := player.get_node("Camera2D") as Camera2D
	camera.enabled = true
	camera.position_smoothing_enabled = false
	player.reset_physics_interpolation()
	var ambient := CanvasModulate.new()
	ambient.color = Color("8c988c")
	add_child(ambient)
	landing_light = PointLight2D.new()
	landing_light.texture = preload("res://assets/lighting/soft_light.png")
	landing_light.texture_scale = 0.28
	landing_light.color = Color("cfb27c")
	landing_light.position = Vector2(396, STAIRS.y_at(99) + 8)
	landing_light.energy = 0.0
	add_child(landing_light)
	hud = preload("res://ui/quiet_hud.gd").new()
	add_child(hud)
	hud.close_requested.connect(close_panel)
	hud.pause_requested.connect(pause_menu)
	hud.objective.text = "往下走 · 找墙上的白记"
	hud.notify("W 沿楼梯往深处。听见身后脚步就按住 Shift + W。")

func _physics_process(delta: float) -> void:
	if phase == Phase.LOST or phase == Phase.LEFT:
		return
	steps_reached = clampi(floori((START_Y - player.position.y) / STEP_DISTANCE + 0.06), 0, 100)
	if phase == Phase.DOWN and steps_from_pursuit and family.is_empty() and not eighty_nine_shown and steps_reached >= 7:
		_start_stair_pursuit()
	if phase == Phase.DOWN and steps_reached >= 89 and not eighty_nine_shown:
		eighty_nine_shown = true
		_clear_family()
		AudioManager.set_bunker_ambience(false)
		AudioManager.play_at(self, "photo_knock", player.position + Vector2(85, -24))
		hud.notify("墙上写着 89。白线到头了，前面却还有台阶。")
	if phase == Phase.DOWN and steps_reached >= 99:
		_enter_loop()
	if phase == Phase.LOOP:
		_update_loop(delta)
	if phase == Phase.RETURN:
		hud.objective.text = "循脚印回机房 · 余下 %d 级" % steps_reached
		if player.position.y >= START_Y - 14:
			hud.prompt.text = "[ E ] 穿过机房门"
	elif phase == Phase.DOWN:
		hud.objective.text = "第 %d 级 · Shift + W 继续跑" % steps_reached if not family.is_empty() else "第 %d 级 · W 向深处走，找白记" % steps_reached
	elif phase == Phase.LOOP:
		hud.objective.text = "同一处白记 · 按住 S 后退，鼠标与手电保持朝前"
	hud.state_text.text = "后退 %d / 10 级" % clampi(99 - steps_reached, 0, 10) if phase == Phase.LOOP else ""
	if phase == Phase.DOWN and absi(steps_reached - 89) <= 1 and not stair_art.marked:
		hud.prompt.text = "[ E ] 在墙边留下记号"
	elif phase != Phase.RETURN:
		hud.prompt.text = ""

func _start_stair_pursuit() -> void:
	for role in range(3):
		var figure = FAMILY.new()
		figure.role_id = role
		figure.target = player
		figure.position = Vector2(280 + role * 42, minf(player.position.y + 184 + role * 18, START_Y + 24))
		figure.speed_scale = 0.79
		figure.active = true
		figure.caught.connect(func(_role: int): fail_route("身后的脚步追上了你。"))
		add_child(figure)
		family.append(figure)
	hud.notify("追上来了！按住 Shift + W 沿楼梯跑。")

func _clear_family() -> void:
	for figure in family:
		if is_instance_valid(figure):
			figure.queue_free()
	family.clear()

func _enter_loop() -> void:
	phase = Phase.LOOP
	loop_ready = true
	AudioManager.play_at(self, "hall_wail", player.position + Vector2(8, 90))
	AudioManager.play_at(self, "door_approach", player.position + Vector2(5, -100))
	var light := create_tween()
	light.tween_property(landing_light, "energy", 0.45 if GameState.reduced_flash else 0.85, 0.55)
	light.tween_property(landing_light, "energy", 0.13, 0.9)
	hud.notify("第 99 级是同一处白记。照住前方，按住 S 倒退十级。")
	if steps_from_pursuit:
		for role in range(3):
			var figure = FAMILY.new()
			figure.role_id = role
			figure.position = Vector2(234 + role * 73, STAIRS.y_at(100) - 9)
			add_child(figure)
			family.append(figure)

func _update_loop(delta: float) -> void:
	if player.look_dir.dot(Vector2.UP) < -0.5:
		if reverse_time == 0.0:
			hud.notify("别回头！立刻把鼠标移到人物上方。")
		reverse_time += delta
		if reverse_time > 0.95:
			fail_route("回头时，墙边的人影已经贴到了脸前。")
			return
	else:
		reverse_time = 0.0
	if steps_reached >= 100:
		player.position.y = STAIRS.y_at(99) - 2
		player.reset_physics_interpolation()
		hud.notify("又走到了同一块缺角。前面的路在打圈。")
	elif steps_reached <= 89 and player.look_dir.dot(Vector2.UP) > 0.45:
		phase = Phase.RETURN
		_clear_family()
		AudioManager.set_bunker_ambience(true)
		AudioManager.play_at(self, "gate_iron", Vector2(323, START_Y), -12.0)
		hud.notify("已退够十级。继续按 S 回机房门，到门边按 E。")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or hud.panel_open:
		return
	if event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		player.controls_enabled = false
		player.clear_motion()
		hud.open_widget(preload("res://ui/demo_bag.gd").new())
		get_tree().paused = true
		return
	if not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if phase == Phase.DOWN and absi(steps_reached - 89) <= 1:
		stair_art.marked = true
		stair_art.queue_redraw()
		AudioManager.play_effect("scrape")
		hud.notify("你在三道旧白线旁留了一个交叉记号。")
	elif phase == Phase.RETURN and player.position.y >= START_Y - 14:
		finish_route()
	elif phase == Phase.LOOP:
		hud.notify("机房拓记：脚印往回，脸朝深处。按住 S 后退，鼠标保持朝前。")

func show_panel(title: String, body: String, choices: Array = []) -> void:
	player.controls_enabled = false
	player.clear_motion()
	hud.open_panel(title, body, choices)
	get_tree().paused = true

func close_panel() -> void:
	if phase == Phase.LOST:
		return
	hud.close_panel()
	get_tree().paused = false
	player.controls_enabled = true
	player.clear_motion()

func pause_menu() -> void:
	show_panel("暂停", "洞内阶梯 · 松山", [{"text":"继续", "callback":close_panel}, {"text":"退出游戏", "callback":func(): get_tree().quit()}])

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud) and is_instance_valid(player) and not hud.panel_open and not get_tree().paused and phase not in [Phase.LOST, Phase.LEFT]:
		pause_menu()

func fail_route(reason: String) -> void:
	if phase == Phase.LOST or phase == Phase.LEFT:
		return
	phase = Phase.LOST
	_clear_family()
	player.controls_enabled = false
	player.clear_motion()
	get_tree().paused = true
	await CAPTURE.play_on(self, "res://assets/characters/bunker_family_lunge_026.png")
	if not is_inside_tree():
		return
	show_panel("没有走出阶梯", reason + "\n\n可回子弹房前的安全落脚处重新尝试。", [{"text":"重新尝试", "callback":retry}])

func retry(destination_override := "") -> void:
	get_tree().paused = false
	var destination := "ch2_bunker_ammo" if steps_from_pursuit else "ch2_bunker_hall"
	if not destination_override.is_empty():
		destination = destination_override
	var entry := "from_hall" if steps_from_pursuit else "from_steps"
	if GameState.request_room_change(destination, entry):
		GameState.demo_pursuit = ""
		GameState.save_transition_checkpoint()
	else:
		show_panel("暂时无法重试", "安全起点暂时无法载入，当前进度仍保留。请稍后再试。", [{"text":"重新尝试", "callback":retry}])

func finish_route() -> void:
	if phase != Phase.RETURN:
		return
	AudioManager.stop_chase_music()
	if not GameState.request_room_change("ch2_bunker_hall", "from_steps"):
		hud.notify("机房门暂未打开。再试一次。")
		return
	phase = Phase.LEFT
	GameState.opening_flags.hill_steps_completed = true
	GameState.opening_flags.ammo_chase_cleared = steps_from_pursuit or GameState.opening_flags.ammo_chase_cleared
	GameState.demo_pursuit = ""
	GameState.save_transition_checkpoint()
