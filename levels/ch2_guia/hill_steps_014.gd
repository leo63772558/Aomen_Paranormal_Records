extends Node2D

const STAIRS := preload("res://levels/ch2_guia/bunker_stair_art.gd")
const FAMILY := preload("res://entities/bunker_family.gd")
const CAPTURE := preload("res://ui/demo_capture_animation.gd")
const START_Y := STAIRS.START_Y
const STEP_DISTANCE := STAIRS.TREAD
const STAIR_AMBIENT := Color("8c988c")
const TAUNT_AMBIENT := Color("95615b")
const TAUNT_PULSE_PERIOD := 1.4
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
var haunt_stage := 0
var whisper_timer := 0.0
var ambient_node: CanvasModulate
var phantom_sprite: AnimatedSprite2D
var phantom_blend: Sprite2D
var phantom_light: PointLight2D
var phantom_anim_clock := 0.0
var camera_node: Camera2D
var taunt_pulse_left := 0.0

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
	camera_node = player.get_node("Camera2D") as Camera2D
	camera_node.enabled = true
	camera_node.position_smoothing_enabled = false
	player.reset_physics_interpolation()
	ambient_node = CanvasModulate.new()
	ambient_node.color = STAIR_AMBIENT
	add_child(ambient_node)
	landing_light = PointLight2D.new()
	landing_light.texture = preload("res://assets/lighting/soft_light.png")
	landing_light.texture_scale = 0.34
	landing_light.color = Color("e07b5c")
	landing_light.position = Vector2(320, STAIRS.y_at(99) - 24)
	landing_light.energy = 0.0
	add_child(landing_light)
	phantom_sprite = AnimatedSprite2D.new()
	phantom_sprite.visible = false
	phantom_sprite.z_index = 260
	_setup_fullbody_phantom_frames()
	add_child(phantom_sprite)
	phantom_blend = Sprite2D.new()
	phantom_blend.visible = false
	phantom_blend.z_index = 261
	add_child(phantom_blend)
	phantom_light = PointLight2D.new()
	phantom_light.texture = preload("res://assets/lighting/soft_light.png")
	phantom_light.texture_scale = 0.24
	phantom_light.color = Color("7bc7cf")
	phantom_light.energy = 0.0
	add_child(phantom_light)
	hud = preload("res://ui/quiet_hud.gd").new()
	add_child(hud)
	hud.close_requested.connect(close_panel)
	hud.pause_requested.connect(pause_menu)
	hud.objective.text = "按 W 下探 · 鼠标朝向石阶深处"
	hud.notify("无论身后谁叫你，都别回头。")

func _setup_fullbody_phantom_frames() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	# Stage 1: Wounded/mangled Ah Hao matching ceiling ambush injuries (2x2 = 4 smooth front limping frames)
	frames.add_animation("ahhao_full")
	frames.set_animation_speed("ahhao_full", 5.5)
	var ah_sheet: Texture2D = preload("res://assets/characters/ahhao_wounded_99_v6_sheet.png")
	var ah_w := ah_sheet.get_width() * 0.5
	var ah_h := ah_sheet.get_height() * 0.5
	for idx in range(4):
		var at := AtlasTexture.new()
		at.atlas = ah_sheet
		at.region = Rect2(float(idx % 2) * ah_w, float(idx / 2) * ah_h, ah_w, ah_h)
		at.filter_clip = true
		frames.add_frame("ahhao_full", at)
	# Stage 2 & 3: Front-facing 2x2 Stair Wraith (4 continuous advancing poses)
	var sw_sheet: Texture2D = preload("res://assets/characters/stair_wraith_v6_sheet.png")
	var sw_w := sw_sheet.get_width() * 0.5
	var sw_h := sw_sheet.get_height() * 0.5
	for anim_name in ["wraith_full", "red_full"]:
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, 6.0)
		for idx in range(4):
			var at := AtlasTexture.new()
			at.atlas = sw_sheet
			at.region = Rect2(float(idx % 2) * sw_w, float(idx / 2) * sw_h, sw_w, sw_h)
			at.filter_clip = true
			frames.add_frame(anim_name, at)
	phantom_sprite.sprite_frames = frames

func _spawn_stair_phantom(stage: int) -> void:
	if not is_instance_valid(phantom_sprite):
		return
	phantom_anim_clock = 0.0
	if stage == 1:
		phantom_sprite.animation = "ahhao_full"
		phantom_sprite.scale = Vector2.ONE * 0.305
		phantom_sprite.modulate = Color(0.84, 0.90, 0.92, 0.90)
		phantom_sprite.position = Vector2(clampf(player.position.x - 18.0, 220.0, 420.0), player.position.y + 82.0)
		phantom_light.color = Color("7ec8d6")
		phantom_light.energy = 0.55 if not GameState.reduced_flash else 0.28
	elif stage == 2:
		phantom_sprite.animation = "wraith_full"
		phantom_sprite.scale = Vector2.ONE * 0.315
		phantom_sprite.modulate = Color(0.88, 0.94, 0.90, 0.92)
		phantom_sprite.position = Vector2(clampf(player.position.x + 24.0, 220.0, 420.0), player.position.y + 74.0)
		phantom_light.color = Color("7ca89b")
		phantom_light.energy = 0.62 if not GameState.reduced_flash else 0.30
	else:
		phantom_sprite.animation = "red_full"
		phantom_sprite.scale = Vector2.ONE * 0.322
		phantom_sprite.modulate = Color(0.92, 0.90, 0.88, 0.94)
		phantom_sprite.position = Vector2(clampf(player.position.x, 225.0, 415.0), player.position.y + 68.0)
		phantom_light.color = Color("89ada0")
		phantom_light.energy = 0.56 if not GameState.reduced_flash else 0.24
	phantom_sprite.visible = true
	if is_instance_valid(phantom_blend):
		phantom_blend.visible = true
		phantom_blend.position = phantom_sprite.position
		phantom_blend.scale = phantom_sprite.scale
	phantom_light.position = phantom_sprite.position

func _clear_phantom() -> void:
	if is_instance_valid(phantom_sprite):
		phantom_sprite.visible = false
	if is_instance_valid(phantom_blend):
		phantom_blend.visible = false
	if is_instance_valid(phantom_light):
		phantom_light.energy = 0.0
	if is_instance_valid(camera_node):
		camera_node.offset = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if phase == Phase.LOST or phase == Phase.LEFT:
		return
	steps_reached = clampi(floori((START_Y - player.position.y) / STEP_DISTANCE + 0.06), 0, 100)
	if phase == Phase.DOWN and steps_from_pursuit and family.is_empty() and not eighty_nine_shown and steps_reached >= 7:
		_start_stair_pursuit()
	if phase == Phase.DOWN:
		if haunt_stage == 0 and steps_reached >= 24:
			haunt_stage = 1
			whisper_timer = 3.2
			_spawn_stair_phantom(1)
			AudioManager.play_voice("ahhao_ghost_99", -2.0)
			AudioManager.play_world_effect("ghost_taunt_whisper")
			AudioManager.play_at(self, "scare_extra_step", player.position + Vector2(0, 72))
			hud.notify("黄梓豪：“姐夫……我好冷……慢点走，等等我好不好……”")
			_pulse_taunt_light()
		elif haunt_stage == 1 and steps_reached >= 34:
			haunt_stage = 2
			whisper_timer = 3.2
			if is_instance_valid(phantom_sprite):
				phantom_sprite.visible = true
			AudioManager.play_world_effect("ghost_taunt_whisper")
			hud.notify("黄梓豪：“天花板扑下来那一下好痛……我的左臂动不了了，血一直在流……”")
		elif haunt_stage == 2 and steps_reached >= 45:
			haunt_stage = 3
			whisper_timer = 3.0
			if is_instance_valid(phantom_sprite):
				phantom_sprite.visible = true
			AudioManager.play_at(self, "scare_extra_step", player.position + Vector2(-8, 60))
			hud.notify("黄梓豪：“别丢下我一个人……你不是答应过我姐要照顾我吗？回头拉我一把……”")
		elif haunt_stage == 3 and steps_reached >= 56:
			haunt_stage = 4
			whisper_timer = 3.0
			_spawn_stair_phantom(2)
			AudioManager.play_world_effect("scare_bulb_pop")
			AudioManager.play_world_effect("hall_wail")
			AudioManager.play_at(self, "scare_extra_step", player.position + Vector2(20, 62))
			hud.notify("身后湿冷的脚步紧贴着你的脚后跟跟了上来……")
		elif haunt_stage == 4 and steps_reached >= 74:
			haunt_stage = 5
			whisper_timer = 2.6
			_spawn_stair_phantom(3)
			AudioManager.play_world_effect("scare_pipe_scrape")
			AudioManager.play_world_effect("ghost_taunt_whisper")
			hud.notify("手电光束发抖，石阶数字乱跳……明明只有八十多级，黑暗深处却多出了十级鬼阶！")
		if whisper_timer > 0.0:
			whisper_timer = maxf(0.0, whisper_timer - delta)
			phantom_anim_clock += delta * 4.8
			var t_pulse := float(Time.get_ticks_msec()) * 0.012
			if is_instance_valid(phantom_sprite) and phantom_sprite.visible:
				var pf := fmod(phantom_anim_clock, 4.0)
				var f0 := int(floor(pf)) % 4
				var f1 := (f0 + 1) % 4
				var blend_t := clampf(pf - floor(pf), 0.0, 1.0)
				phantom_sprite.frame = f0
				phantom_sprite.position.y = lerpf(phantom_sprite.position.y, player.position.y + 62.0, delta * 2.2) + sin(t_pulse * 0.6) * 1.4
				phantom_sprite.position.x += sin(t_pulse * 1.1) * 0.25
				var base_a := clampf(whisper_timer * 0.42, 0.0, 0.86)
				phantom_sprite.modulate.a = base_a * (1.0 - blend_t * 0.45)
				if is_instance_valid(phantom_blend) and phantom_sprite.sprite_frames != null:
					phantom_blend.visible = true
					phantom_blend.texture = phantom_sprite.sprite_frames.get_frame_texture(phantom_sprite.animation, f1)
					phantom_blend.position = phantom_sprite.position
					phantom_blend.scale = phantom_sprite.scale
					phantom_blend.modulate = Color(phantom_sprite.modulate.r, phantom_sprite.modulate.g, phantom_sprite.modulate.b, base_a * blend_t)
				phantom_light.position = phantom_sprite.position
				phantom_light.energy = clampf(whisper_timer * 0.26, 0.0, 0.62)
			if not _check_facing(delta, "身后传来唤声。看向石阶深处。", "身后的声音忽然贴在耳边。一只冰冷的手扣住了你的后颈。"):
				return
		else:
			reverse_time = 0.0
			if is_instance_valid(phantom_sprite) and phantom_sprite.visible:
				_clear_phantom()
	_update_taunt_light(delta)
	if phase == Phase.DOWN and steps_reached >= 89 and not eighty_nine_shown:
		eighty_nine_shown = true
		_clear_family()
		_clear_phantom()
		AudioManager.set_bunker_ambience(false)
		AudioManager.play_at(self, "photo_knock", player.position + Vector2(85, -24))
		hud.notify("石阶缺了一角。墙上有三道白线，旁边刻着 89。")
	if phase == Phase.DOWN and steps_reached >= 99:
		_enter_loop()
	if phase == Phase.LOOP:
		_update_loop(delta)
	if phase == Phase.RETURN:
		if not _check_facing(delta, "别回头。鼠标留在人物上方。", "你转过头时，那道鬼影已经扑到了脸前。"):
			return
		# Keep the single pursuer menacingly close on the return walk without blocking natural catch-up.
		for figure in family:
			var trailing_y := player.position.y - 148.0
			if is_instance_valid(figure) and figure.position.y < trailing_y:
				figure.position.y = lerpf(figure.position.y, trailing_y, delta * 3.0)
		hud.objective.text = "按住 S 退回机房 · 鼠标留在人物上方"
	elif phase == Phase.DOWN:
		var shown_step := steps_reached
		if steps_reached in [74, 75, 76, 86, 87, 88] and not GameState.reduced_flash:
			var tick := (Time.get_ticks_msec() / 190) % 4
			if tick == 0:
				shown_step = 99 if steps_reached < 80 else 89
		hud.objective.text = "第 %d 级 · Shift + W 甩开红影" % shown_step if not family.is_empty() else "第 %d 级 · W 下探" % shown_step
	elif phase == Phase.LOOP:
		hud.objective.text = "第 99 级 · 按住 S 倒退，鼠标留在人物上方"
	hud.state_text.text = "已退 %d / 10 级" % clampi(99 - steps_reached, 0, 10) if phase == Phase.LOOP else ("离机房还有 %d 级" % steps_reached if phase == Phase.RETURN else "")
	if phase == Phase.DOWN and absi(steps_reached - 89) <= 1 and not stair_art.marked:
		hud.prompt.text = "[ E ] 在墙边留下记号"
	elif _at_machine_room():
		hud.prompt.text = "[ E ] 穿过机房门"
	else:
		hud.prompt.text = ""

func _at_machine_room() -> bool:
	return phase == Phase.RETURN and player.position.y >= START_Y - 14

func _pulse_taunt_light(force := false) -> void:
	if not GameState.reduced_flash and (force or taunt_pulse_left <= 0.0):
		taunt_pulse_left = TAUNT_PULSE_PERIOD * 2.0

func _update_taunt_light(delta: float) -> void:
	if GameState.reduced_flash:
		taunt_pulse_left = 0.0
	taunt_pulse_left = maxf(taunt_pulse_left - delta, 0.0)
	var strength := 0.5 - 0.5 * cos(TAU * taunt_pulse_left / TAUNT_PULSE_PERIOD)
	ambient_node.color = STAIR_AMBIENT.lerp(TAUNT_AMBIENT, strength)

func _connect_stair_taunt(figure: Node) -> void:
	var taunt := figure.get_node_or_null("GhostTaunt") as GhostTaunt
	if taunt != null:
		taunt.taunt_shown.connect(_pulse_taunt_light)

func _check_facing(delta: float, warning: String, failure: String) -> bool:
	if player.look_dir.dot(Vector2.UP) >= -0.5:
		reverse_time = 0.0
		return true
	if reverse_time == 0.0:
		hud.notify(warning)
	reverse_time += delta
	if reverse_time <= 0.85:
		return true
	fail_route(failure)
	return false

func _apply_stair_wraith_skin(figure: CharacterBody2D) -> void:
	var sheet: Texture2D = preload("res://assets/characters/stair_wraith_v6_sheet.png")
	if sheet == null:
		return
	var cw := sheet.get_width() * 0.5
	var ch := sheet.get_height() * 0.5
	var wraith_frames: Array[AtlasTexture] = []
	for idx in range(4):
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(float(idx % 2) * cw, float(idx / 2) * ch, cw, ch)
		at.filter_clip = true
		wraith_frames.append(at)
	figure.frames = wraith_frames
	figure.use_quad_front_cycle = true
	figure.base_pose_scale = 82.0 / ch
	if is_instance_valid(figure.pose):
		figure.pose.texture = wraith_frames[0]
		figure.pose.scale = Vector2.ONE * figure.base_pose_scale
		figure.pose.position = Vector2(0.0, -40.0)
	if is_instance_valid(figure.blend_pose):
		figure.blend_pose.texture = wraith_frames[1]
		figure.blend_pose.scale = Vector2.ONE * figure.base_pose_scale
		figure.blend_pose.position = Vector2(0.0, -40.0)

func _start_stair_pursuit() -> void:
	var figure = FAMILY.new()
	figure.role_id = 0
	figure.target = player
	figure.position = Vector2(320.0, minf(player.position.y + 168.0, START_Y + 24))
	figure.speed_scale = 1.04
	figure.active = true
	figure.caught.connect(func(_role: int): fail_route("身后的怨灵追上了你。"))
	add_child(figure)
	_apply_stair_wraith_skin(figure)
	_connect_stair_taunt(figure)
	family.append(figure)
	hud.notify("追上来了！按住 Shift + W 沿楼梯快跑！")

func _clear_family() -> void:
	for figure in family:
		if is_instance_valid(figure):
			figure.queue_free()
	family.clear()

func _enter_loop() -> void:
	phase = Phase.LOOP
	loop_ready = true
	reverse_time = 0.0
	_clear_phantom()
	_clear_family()
	AudioManager.play_at(self, "hall_wail", player.position + Vector2(8, 90))
	AudioManager.play_at(self, "door_approach", player.position + Vector2(5, -100))
	AudioManager.start_chase_music()
	var light := create_tween()
	light.tween_property(landing_light, "energy", 0.45 if GameState.reduced_flash else 0.85, 0.55)
	light.tween_callback(_wake_landing_family)
	light.tween_property(landing_light, "energy", 0.13, 0.9)
	hud.notify("缺角和白线一模一样。怨灵从这一头逼近了！")
	_pulse_taunt_light(true)
	var figure = FAMILY.new()
	figure.role_id = 0
	figure.target = player
	figure.position = Vector2(320.0, STAIRS.y_at(99) - 52.0)
	figure.speed_scale = 0.84
	figure.caught.connect(func(_role: int): fail_route("怨灵沿 99 级鬼阶高速追了下来，冰冷的手攥住了你的肩！"))
	add_child(figure)
	_apply_stair_wraith_skin(figure)
	_connect_stair_taunt(figure)
	# The actor sets its usual world mask in _ready(). This entity emerges from the sealed wall.
	figure.collision_layer = 0
	figure.collision_mask = 0
	family.append(figure)

func _wake_landing_family() -> void:
	for figure in family:
		figure.active = true

func _update_loop(delta: float) -> void:
	if not _check_facing(delta, "别回头。鼠标留在人物上方。", "回头时，墙边的怨灵已经贴到了脸前。"):
		return
	if steps_reached >= 100:
		player.position.y = STAIRS.y_at(99) - 2
		player.reset_physics_interpolation()
		hud.notify("又走到了同一块缺角。前面的路在打圈，快按 S 倒退！")
	elif steps_reached <= 89 and player.look_dir.dot(Vector2.UP) > 0.45:
		phase = Phase.RETURN
		for figure in family:
			figure.speed_scale = 0.80
		AudioManager.set_bunker_ambience(true)
		AudioManager.play_at(self, "gate_iron", Vector2(323, START_Y), -12.0)
		hud.notify("循环断了。怨灵还在逼近——按住 S 加速倒退，听到机房风声就快到门口了！")

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
	elif _at_machine_room():
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
	taunt_pulse_left = 0.0
	ambient_node.color = STAIR_AMBIENT
	AudioManager.stop_voice()
	AudioManager.stop_chase_music()
	_clear_family()
	_clear_phantom()
	player.controls_enabled = false
	player.clear_motion()
	get_tree().paused = true
	await CAPTURE.play_on(self, "res://assets/characters/stair_wraith_lunge_v6.png")
	if not is_inside_tree():
		return
	show_panel("没有走出阶梯", reason + "\n\n已保留录音机进度，可直接回到阶梯入口前的机房重新尝试（无需重跑子弹房）。", [{"text":"重新尝试", "callback":retry}])

func retry(destination_override := "") -> void:
	get_tree().paused = false
	var destination := "ch2_bunker_hall"
	if not destination_override.is_empty():
		destination = destination_override
	if GameState.request_room_change(destination, "from_steps"):
		GameState.demo_pursuit = "steps" if GameState.has_demo_item("bunker_recording") else ""
		GameState.save_transition_checkpoint()
	else:
		show_panel("暂时无法重试", "安全起点暂时无法载入，当前进度仍保留。请稍后再试。", [{"text":"重新尝试", "callback":retry}])

func finish_route() -> void:
	if phase != Phase.RETURN:
		return
	AudioManager.stop_voice()
	AudioManager.stop_chase_music()
	if not GameState.request_room_change("ch2_bunker_hall", "from_steps"):
		hud.notify("机房门暂未打开。再试一次。")
		return
	phase = Phase.LEFT
	GameState.opening_flags.hill_steps_completed = true
	GameState.opening_flags.ammo_chase_cleared = steps_from_pursuit or GameState.has_demo_item("bunker_recording") or GameState.opening_flags.ammo_chase_cleared
	GameState.demo_pursuit = ""
	GameState.save_transition_checkpoint()
