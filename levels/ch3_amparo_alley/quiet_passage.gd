extends Node2D

const ROOM_ID := "ch3_quiet_passage"
const TARGETS := {"archive": Vector2(96, 160), "herbal_pot": Vector2(315, 162), "street": Vector2(565, 160)}
var player: PlayerController
var hud
var selected_id := ""
var widget: Control
var leaving := false

func _ready() -> void:
	GameState.prepare_opening_resume()
	if GameState.current_room_id != ROOM_ID or not (GameState.opening_flags.ch3_cold_door_open and GameState.opening_flags.ch3_key_found and GameState.opening_flags.ch3_ticket_found):
		push_error("Quiet passage requires the opened archive exit and its two items.")
		return
	AudioManager.set_scene_ambience("")
	var background = preload("res://core/components/room_tile_layer.gd").new()
	background.background_texture = load("res://assets/tilesets/ch3_quiet_passage_open_167.png")
	add_child(background)
	var ambient := CanvasModulate.new()
	ambient.color = Color("b8b4a1")
	add_child(ambient)
	_build_geometry()
	preload("res://core/components/physics_prop.gd").spawn(self, "tin_can", Vector2(265, 224), Rect2(60, 165, 520, 165))
	preload("res://core/components/physics_prop.gd").spawn(self, "glass_bottle", Vector2(420, 236), Rect2(60, 165, 520, 165))
	player = preload("res://entities/player/player.tscn").instantiate()
	player.visual_size_multiplier = 1.65
	player.appearance = "flashlight"
	player.position = Vector2(105, 220)
	add_child(player)
	player.reset_physics_interpolation()
	hud = preload("res://ui/quiet_hud.gd").new()
	add_child(hud)
	hud.close_requested.connect(_close_panel)
	hud.pause_requested.connect(_pause_menu)
	hud.objective.text = "穿过后巷走向街面；可返回肉铺复查旧资料"
	if not GameState.save_opening_checkpoint():
		hud.show_resource_feedback("进度保存失败，仍可继续。请检查存储空间和文件夹权限后重试。")

func _build_geometry() -> void:
	LevelGeometry.wall(self, Rect2(0, 0, 640, 140))
	LevelGeometry.wall(self, Rect2(0, 140, 14, 220))
	LevelGeometry.wall(self, Rect2(626, 140, 14, 220))
	LevelGeometry.wall(self, Rect2(14, 345, 612, 15))
	# The already-open steel leaf occupies the left edge of the doorway.
	LevelGeometry.wall(self, Rect2(45, 140, 40, 24))
	# Bin, baskets, ceramic jars, crate and potted tree stand against the wall.
	LevelGeometry.wall(self, Rect2(120, 115, 75, 45))
	LevelGeometry.wall(self, Rect2(382, 117, 113, 43))

func _process(_delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(hud) or hud.panel_open or leaving:
		return
	selected_id = ""
	var best := INF
	for id in TARGETS:
		var toward: Vector2 = TARGETS[id] - player.position
		var distance := toward.length()
		var alignment := player.look_dir.dot(toward.normalized()) if distance > 0.1 else 1.0
		var score := distance + (1.0 - alignment) * 35.0
		if distance < 58.0 and alignment > -0.1 and score < best:
			selected_id = id
			best = score
	var prompt_names := {"archive": "返回肉铺后间", "herbal_pot": "查看旧凉茶铺铜壶与街牌", "street": "走向街面"}
	hud.prompt.text = "[ E ] " + String(prompt_names.get(selected_id, "")) if not selected_id.is_empty() else ""

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or hud.panel_open or leaving:
		return
	if event.is_action_pressed("interact") and not selected_id.is_empty():
		get_viewport().set_input_as_handled()
		interact_target(selected_id)
	elif event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		widget = preload("res://ui/demo_bag.gd").new()
		hud.open_widget(widget)
		player.controls_enabled = false
		player.clear_motion()
		get_tree().paused = true

func interact_target(id: String) -> void:
	if id == "archive":
		if GameState.request_room_change("ch3_amparo_archive", "from_passage"):
			GameState.save_transition_checkpoint()
		else:
			_say("暂时无法返回", "肉铺后间暂时无法载入。大文仍留在后巷，请稍后重试。")
	elif id == "herbal_pot":
		_say("旧凉茶铺铜壶与街牌", "墙角摆着凹陷的廿四味大铜壶，手写木牌留着「大关斜巷 Calçada do Amparo」。墙上旧剪报写着2004年深夜新福利 33 路末班车曾出现无声的校服女生，到站回头空无一人。")
	elif id == "street":
		_say("走向街面", "按嘉敏在时刻表背面的留言，去亚马喇前地找唯一还亮着灯的 33 路末班车。", [{"text":"前往亚马喇前地", "callback":_enter_bus}, {"text":"再留一会", "callback":_close_panel}])

func _enter_bus() -> void:
	if leaving:
		return
	leaving = true
	_close_panel()
	player.controls_enabled = false
	hud.prompt.text = ""
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var curtain := ColorRect.new()
	curtain.color = Color.BLACK
	curtain.modulate.a = 0.0
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(curtain)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var location: Label = hud.label("深夜 · 亚马喇前地", Vector2(120, 162), Vector2(400, 35), 19, Color("e1d7c2"), curtain)
	location.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	location.add_theme_font_override("font", hud.root.get_theme_default_font())
	var travel := create_tween()
	travel.tween_property(curtain, "modulate:a", 1.0, 0.38).set_trans(Tween.TRANS_SINE)
	travel.tween_interval(0.43)
	await travel.finished
	if not is_inside_tree():
		return
	if GameState.request_room_change("ch4_bus_loop", "from_w17_ticket"):
		GameState.save_transition_checkpoint()
	else:
		layer.queue_free()
		leaving = false
		_say("暂时无法前往", "街面的路线暂时无法载入。大文仍留在后巷，请稍后重试。")

func _say(title: String, body: String, choices: Array = []) -> void:
	player.controls_enabled = false
	player.clear_motion()
	hud.open_panel(title, body, choices)
	get_tree().paused = true

func _close_panel() -> void:
	if is_instance_valid(widget):
		widget.queue_free()
		widget = null
	hud.close_panel()
	get_tree().paused = false
	player.controls_enabled = not leaving
	player.clear_motion()

func _pause_menu() -> void:
	_say("暂停", "后巷已经暂停。", [{"text":"继续", "callback":_close_panel}, {"text":"保存并回到标题", "callback":_return_to_title}])

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud) and is_instance_valid(player) and not hud.panel_open and not get_tree().paused:
		_pause_menu()

func _return_to_title() -> void:
	_close_panel()
	if not GameState.save_opening_checkpoint():
		_say("保存失败", "当前进度未能保存，仍留在后巷。请检查存储空间和文件夹权限后重试。")
		return
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
