extends Node2D

const PROP_SCRIPT = preload("res://core/components/interactable_area.gd")
const HUD_SCRIPT = preload("res://ui/quiet_hud.gd")
var player: PlayerController
var hud
var ambience: CanvasModulate
var ceiling: PointLight2D
var shrine_light: PointLight2D
var mode: int = 0
var props: Dictionary = {}
var selected: SampleInteractable
var hidden_exit := Vector2.ZERO
var elapsed: float = 0.0
var modal_kind: String = ""
var window_reflection: Sprite2D
var photo_disturbance_pending: bool = false
var tool_pose: Sprite2D
var tool_pose_data: Dictionary
var work_in_progress: bool = false

func _ready() -> void:
	var floor_layer = preload("res://core/components/room_tile_layer.gd").new()
	add_child(floor_layer)
	ambience = CanvasModulate.new()
	add_child(ambience)
	add_wall(Rect2(48, 48, 544, 47))
	add_wall(Rect2(48, 64, 16, 260))
	add_wall(Rect2(576, 64, 16, 260))
	add_wall(Rect2(48, 310, 544, 16))
	add_prop("wardrobe", "衣柜 · 躲藏", "wardrobe", Vector2(145, 156), Vector2(58, 35))
	add_prop("bed", "铁架床", "iron_bed", Vector2(438, 183), Vector2(62, 69))
	add_prop("desk", "旧照片与电话", "photo_desk", Vector2(264, 266), Vector2(80, 34))
	add_prop("gate", "趟栊门 · 接电", "gate", Vector2(75, 287), Vector2(18, 70))
	add_prop("marks", "花砖上的拖痕", "vent", Vector2(405, 218), Vector2(10, 10), false)
	props["marks"].sprite.visible = false
	add_prop("vent", "床后的检修盖", "vent_006", Vector2(438, 116), Vector2(38, 18), true)
	props["vent"].visible = false
	props["vent"].active = false
	props["vent"].set_solid_enabled(false)
	add_prop("shrine", "门边神龛", "shrine", Vector2(92, 111), Vector2(34, 16))
	add_prop("mailbox", "门旁的旧信箱", "mailbox_004", Vector2(84, 205), Vector2(18, 30), true, Vector2(-12, 0))
	props["mailbox"].sprite.position.x -= 12.0
	add_prop("partition", "", "partition", Vector2(356, 178), Vector2(16, 113))
	props["partition"].active = false
	window_reflection = Sprite2D.new()
	window_reflection.texture = preload("res://assets/props/window_reflection.png")
	window_reflection.position = Vector2(268, 66)
	window_reflection.visible = false
	add_child(window_reflection)
	ceiling = add_light(Vector2(268, 135), Color("ffe0a0"), 0.65, 1.65)
	shrine_light = add_light(Vector2(92, 84), Color("ffc076"), 0.8, 0.58)
	player = preload("res://entities/player/player.tscn").instantiate()
	player.position = Vector2(207, 228)
	add_child(player)
	player.lamp.shadow_enabled = true
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://core/data/opening_art.json"))
	tool_pose_data = art["pliers"]
	tool_pose = PoseArt.sprite(load("res://assets/characters/dawen_pliers_006.png"), tool_pose_data)
	tool_pose.z_index = 1
	player.add_child(tool_pose)
	tool_pose.hide()
	hud = HUD_SCRIPT.new()
	add_child(hud)
	hud.close_requested.connect(close_modal)
	hud.pause_requested.connect(show_pause)
	hud.mode_requested.connect(set_light_mode)
	set_light_mode(1)
	update_objective()
	hud.notify("先靠近桌子，朝向旧照片，按 E 查看")

func add_prop(id: String, title: String, texture: String, at: Vector2, body_size: Vector2, solid: bool = true, body_offset: Vector2 = Vector2.ZERO) -> void:
	var prop = PROP_SCRIPT.new()
	add_child(prop)
	prop.setup(id, title, texture, at, body_size, solid, body_offset)
	props[id] = prop

func add_wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = rect.get_center()
	body.add_child(collision)
	add_child(body)
	var shadow := LightOccluder2D.new()
	var polygon := OccluderPolygon2D.new()
	polygon.polygon = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	shadow.occluder = polygon
	add_child(shadow)

func add_light(at: Vector2, color: Color, energy: float, scale_value: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.position = at
	light.texture = preload("res://assets/lighting/soft_light.png")
	light.texture_scale = scale_value
	light.color = color
	light.energy = energy
	light.range_item_cull_mask = 3
	light.shadow_enabled = true
	light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	add_child(light)
	return light

func _process(delta: float) -> void:
	elapsed += delta
	if mode == 2:
		shrine_light.energy = 0.85 + sin(elapsed * 1.7) * 0.08
	if work_in_progress:
		hud.prompt.text = ""
		return
	select_interactable()
	hud.state_text.text = ("衣柜内 · 按住 Space 屏息 / E 安全离开" if player.hidden_in_wardrobe else ["楼内灯火尚亮。窗外有很远的车声。", "走廊断了电。神龛的灯还亮着。", "电话没有响，听筒里却传来一下敲击。"] [mode])
	hud.state_text.visible = player.hidden_in_wardrobe or player.crouching
	if player.crouching and not player.hidden_in_wardrobe:
		hud.state_text.text += " 〔蹲行〕"
	if player.hidden_in_wardrobe and Input.is_action_pressed("hold_breath"):
		hud.state_text.text = "屏息中 · 这里只演示躲藏操作，尚无追逐"

func select_interactable() -> void:
	if selected != null:
		selected.set_highlight(false)
	selected = null
	if player.hidden_in_wardrobe:
		hud.prompt.text = "[ E ] 离开衣柜"
		return
	var nearest: float = GameState.RULES.interaction_range
	for prop in props.values():
		if not prop.active:
			continue
		var target: Vector2 = prop.global_position + Vector2(0, 6)
		var offset: Vector2 = target - player.global_position
		var distance: float = offset.length()
		if distance > nearest or (distance > 10 and player.look_dir.dot(offset.normalized()) < -0.05):
			continue
		if not interaction_visible(target):
			continue
		nearest = distance
		selected = prop
	if selected:
		selected.set_highlight(true)
		hud.prompt.text = "[ E ] " + selected.prompt
		hud.prompt.position = Vector2(clampf(selected.position.x - 44, 65, 410), clampf(selected.position.y + 13, 100, 286))
	else:
		hud.prompt.text = ""

func interaction_visible(target: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(player.global_position, target, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if work_in_progress:
		return
	if event.is_action_pressed("interact"):
		if player.hidden_in_wardrobe:
			exit_wardrobe()
		elif selected:
			interact(selected.interactable_id)
		else:
			hud.notify("靠近物件，并把观察方向朝向它")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("phone") or event.is_action_pressed("journal") or event.is_action_pressed("map"):
		open_journal()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera_flash"):
		hud.notify("样板暂未进入取得嘉敏手机的剧情，防身强闪尚未开放")
	elif event.is_action_pressed("light_day"):
		set_light_mode(0)
	elif event.is_action_pressed("light_out"):
		set_light_mode(1)
	elif event.is_action_pressed("light_danger"):
		set_light_mode(2)

func interact(id: String) -> void:
	if id not in ["wardrobe", "vent"]:
		AudioManager.play_effect("click")
	match id:
		"desk":
			photo_disturbance_pending = not GameState.has_clue("old_photo")
			GameState.try_add_clue("old_photo")
			show_modal("旧照片 · 床的位置", "照片里的铁床更靠近墙，床脚与地砖接缝对齐。\n\n现在的床离墙更远，墙脚那道通风缝也被遮住了。\n\n大文：『张床好似郁过。』\n（这张床好像被挪过。）", [], true)
		"marks":
			GameState.try_add_clue("floor_marks")
			show_modal("花砖上的拖痕", "两道新拖痕从墙边延伸到床脚。\n\n灰尘被划开，床原本应更靠近墙。旧照片能帮你确认遮住的是什么。")
		"bed":
			if GameState.flags["bed_moved"]:
				show_modal("铁床已移开", "床后的通风缝露了出来。靠近检修盖，用随身工具钳拆下它。")
			else:
				# Examining the bed includes its visible feet and drag marks. Players
				# need not discover a second small hotspot for the same observation.
				GameState.try_add_clue("floor_marks")
				if not GameState.has_clue("old_photo"):
					show_modal("床脚有新拖痕", "拖痕从墙边延伸到床脚，这张床被拖动过。\n\n先看看桌上的旧照片，对照它以前的位置，再回来移床。")
				else:
					show_modal("对照现场 · 为什么移床？", "你查看床脚，发现拖痕从墙边延伸到现在的位置。\n\n旧照片里床更靠墙。哪一种解释符合现场？", [
					{"text": "床被挪过", "callback": try_move_bed},
					{"text": "照片拍歪了", "callback": wrong_deduction},
					{"text": "再看看", "callback": close_modal, "width": 100}])
		"vent":
			if not GameState.flags["cover_open"]:
				remove_cover()
			else:
				show_vent_contents()
		"wardrobe":
			hidden_exit = player.position
			player.hidden_in_wardrobe = true
			player.clear_motion()
			player.lamp.enabled = false
			player.sprite.visible = false
			EventBus.player_hidden.emit(true)
			AudioManager.play_world_effect("wardrobe_close")
			hud.notify("已藏进衣柜 · E 离开，Space 演示屏息")
		"gate":
			GameState.flashlight_battery = 100.0
			hud.notify("门边插座已为手电充满电；样板暂不开放楼外区域")
		"shrine":
			show_modal("门边神龛", "小灯把门槛照得很清楚，香炉里已经没有余火。\n\n断电后，这盏灯仍可帮你找到返回门边的路。")
		"mailbox":
			show_modal("红信箱", "褪色的信箱上贴着『福荣里 304』。\n\n信箱、趟栊门与花砖是这间唐楼的美术样板；地点与房间布局为游戏虚构。")
	update_objective()

func try_move_bed() -> void:
	if not GameState.has_clue("old_photo"):
		show_modal("先对照旧照片", "你已经看到了床脚拖痕。\n\n桌上的旧照片能确认这张床以前的位置，看完后再回来移床。")
		return
	if not GameState.has_clue("floor_marks"):
		show_modal("查看床脚", "靠近铁床按 E 调查，看看床脚和地面的拖痕，再与照片对照。")
		return
	var destination := Vector2(514, 183)
	var occupied: Rect2 = props["bed"].footprint.grow(9)
	if occupied.has_point(player.position - destination):
		show_modal("让出床边的位置", "右侧是移床的空位。先站到床前的花砖上，再操作铁床。")
		return
	props["bed"].position = destination
	GameState.set_flag("bed_moved", true)
	props["vent"].visible = true
	props["vent"].active = true
	props["vent"].set_solid_enabled(true)
	props["marks"].active = false
	AudioManager.play_effect("scrape")
	close_modal()
	hud.notify("铁床移开了 · 墙脚露出检修盖")
	update_objective()

func wrong_deduction() -> void:
	show_modal("这个解释对不上", "花砖的方向没有变化，地面却多出了拖痕。\n\n照片拍歪解释不了床被拖动的痕迹，可以重新对照。")

func exit_wardrobe() -> void:
	var shape := CircleShape2D.new()
	shape.radius = 7.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, hidden_exit)
	query.collision_mask = 5
	if not get_world_2d().direct_space_state.intersect_shape(query).is_empty():
		hud.notify("衣柜出口被挡住了，暂时无法离开")
		return
	player.position = hidden_exit
	player.hidden_in_wardrobe = false
	player.sprite.visible = true
	player.lamp.enabled = player.flashlight_on
	EventBus.player_hidden.emit(false)
	AudioManager.play_world_effect("wardrobe_open")

func show_modal(title: String, body: String, choices: Array = [], photo: bool = false) -> void:
	modal_kind = "reading"
	player.clear_motion()
	player.controls_enabled = false
	hud.open_panel(title, body, choices, photo)
	get_tree().paused = true

func close_modal() -> void:
	if is_instance_valid(tool_pose) and tool_pose.visible and not work_in_progress:
		tool_pose.hide()
		player.sprite.visible = not player.hidden_in_wardrobe
	hud.close_panel()
	modal_kind = ""
	player.clear_motion()
	player.controls_enabled = not work_in_progress
	get_tree().paused = false
	if photo_disturbance_pending:
		photo_disturbance_pending = false
		set_light_mode(2)
		hud.notify("窗上多了一个倒影，房间里却没有别人。")

func open_journal() -> void:
	var content := "已经发现的线索：\n"
	content += "旧照片：已查看，床的位置与现场不同。\n" if GameState.has_clue("old_photo") else "旧照片：尚未查看。\n"
	content += "地面拖痕：已确认，铁床被挪动过。" if GameState.has_clue("floor_marks") else "地面拖痕：尚未调查。"
	content += "\n\n接下来：" + current_objective()
	show_modal("线索记录", content)

func current_objective() -> String:
	if GameState.flags["cover_open"]:
		return "样板完成 · 可继续观察灯光与衣柜"
	if GameState.flags["bed_moved"]:
		return "靠近床后的检修盖，用工具钳拆盖"
	if not GameState.has_clue("old_photo"):
		return "查看桌上的旧照片"
	if not GameState.has_clue("floor_marks"):
		return "检查床脚前方的拖痕"
	return "对照证据，调查铁床并移开它"

func update_objective() -> void:
	hud.objective.text = current_objective()

func set_light_mode(value: int) -> void:
	mode = clampi(value, 0, 2)
	ambience.color = [Color("c3c8b1"), Color("73868d"), Color("68747b")][mode]
	ceiling.enabled = mode == 0
	window_reflection.visible = mode == 2
	shrine_light.color = Color("ffb86b") if mode < 2 else Color("d96d45")
	shrine_light.energy = 0.8
	if hud != null:
		hud.notify(["明灯 · 观察家具与花砖", "停电 · 手电可随鼠标转动，F 开关", "异响 · 仅预览危险氛围，尚无怪物追逐"][mode])

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud) and not hud.panel_open:
		show_pause()

func show_pause() -> void:
	show_modal("暂停", "WASD 移动（可斜走）　鼠标观察\nE 调查／翻页　F 手电　Q 线索记录\nShift 跑　Ctrl 蹲\n\n当前是试玩样板，退出后从头开始。", [
		{"text": "继续观察", "callback": close_modal},
		{"text": "重新开始", "callback": restart_sample},
		{"text": "退出", "callback": func(): get_tree().quit(), "width": 100}])

func restart_sample() -> void:
	close_modal()
	GameState.clues.clear()
	GameState.flags = {"bed_moved": false, "cover_open": false}
	GameState.stamina = 100.0
	GameState.flashlight_battery = 100.0
	get_tree().reload_current_scene()

func remove_cover() -> void:
	if work_in_progress:
		return
	work_in_progress=true
	player.clear_motion()
	player.controls_enabled=false
	player.sprite.hide()
	tool_pose.show()
	var lens=tool_pose_data["torch_lens"]
	var anchor=tool_pose_data["anchor"]
	player.pivot.position=(Vector2(lens[0],lens[1])-Vector2(anchor[0],anchor[1]))*float(tool_pose_data.scale)
	AudioManager.play_world_effect("metal_cover")
	hud.notify("用工具钳拆下检修盖……")
	var timer:=Timer.new()
	timer.wait_time=.7
	timer.one_shot=true
	add_child(timer)
	timer.start()
	await timer.timeout
	timer.queue_free()
	GameState.set_flag("cover_open",true)
	EventBus.puzzle_solved.emit("p_ch0_photo_door")
	props["vent"].reveal_opening()
	work_in_progress=false
	tool_pose.hide()
	player.sprite.show()
	player.controls_enabled=true
	show_vent_contents()
	update_objective()

func show_vent_contents() -> void:
	show_modal("检修入口", "工具钳拧下了盖板。门边留着新刮痕，里面是一段向下的窄梯。\n\n大文：『嘉敏，你系咪入咗去？』\n（嘉敏，你是不是进去了？）\n\n样板体验到这里结束，后续通道尚未制作。")
