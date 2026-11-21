extends Node2D

var player: PlayerController
var hud
var monster: CharacterBody2D
var stalker_active := false
var breaker_done := false
var dawen_npc: Node2D
var blood_decal: Node2D
var phase := "explore" # explore -> chase -> escape -> ambush -> dawen_flee -> done

const HALL_WIDTH := 640.0
const HALL_HEIGHT := 360.0
const BREAKER_POS := Vector2(560, 210)
const DOOR_POS := Vector2(90, 210)

func _ready() -> void:
	AudioManager.stop_chase_music()
	AudioManager.set_scene_ambience("bunker")
	
	# Background visuals
	var back := Sprite2D.new()
	var bg_tex: Texture2D = load("res://assets/tilesets/corridor_010.png")
	if bg_tex != null:
		back.texture = bg_tex
		back.centered = false
		back.scale = Vector2(640, 360) / bg_tex.get_size()
	add_child(back)
	
	# Dim ambient overlay
	var dark_overlay := ColorRect.new()
	dark_overlay.size = Vector2(640, 360)
	dark_overlay.color = Color(0.02, 0.04, 0.03, 0.65)
	dark_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dark_overlay)
	
	# Boundaries & collision
	LevelGeometry.room_bounds(self, 160)
	LevelGeometry.wall(self, Rect2(0, 140, 640, 20))
	LevelGeometry.wall(self, Rect2(0, 260, 640, 20))
	LevelGeometry.wall(self, Rect2(260, 160, 30, 45)) # obstacle 1
	LevelGeometry.wall(self, Rect2(410, 210, 35, 45)) # obstacle 2
	
	# Visual obstacles
	_add_box(Vector2(275, 182), Vector2(30, 45))
	_add_box(Vector2(427, 232), Vector2(35, 45))
	
	# Breaker box visual
	var breaker := ColorRect.new()
	breaker.position = BREAKER_POS - Vector2(10, 20)
	breaker.size = Vector2(20, 30)
	breaker.color = Color("8c7542")
	add_child(breaker)
	
	# Player as Ah Kin
	player = preload("res://entities/player/player.tscn").instantiate()
	player.position = Vector2(140, 210)
	player.visual_size_multiplier = 1.65
	player.appearance = "flashlight"
	player.flashlight_on = true
	add_child(player)
	player.reset_physics_interpolation()
	
	# HUD
	hud = preload("res://ui/quiet_hud.gd").new()
	add_child(hud)
	hud.show_resources(false)
	hud.close_requested.connect(_on_hud_close)
	
	var stamp: Label = hud.label("福荣旧酒店 · 杂物后廊 18:45  [ 黄梓豪（阿豪）视角 ]", Vector2(20, 16), Vector2(420, 26), 14, Color("e5d29d"))
	hud.root.move_child(stamp, 0)
	hud.objective.text = "沿后廊往前，找到总电闸刀合上"
	
	hud.open_panel("前哨视点", "姐夫在楼下检修电表，我姐先上三楼看 304 事故房。\n\n我顺路到二楼半的杂物后廊找备用总闸……这旧酒店阴森森的，得赶紧合上电闸回去和姐夫会合。", [], false, "黄梓豪")

func _add_box(center: Vector2, bsize: Vector2) -> void:
	var box := ColorRect.new()
	box.position = center - bsize * 0.5
	box.size = bsize
	box.color = Color("232c25")
	add_child(box)

func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(hud):
		return
	if hud.panel_open:
		return
	
	if phase == "explore":
		if player.position.distance_to(BREAKER_POS) < 45.0 and not breaker_done:
			hud.prompt.text = "[ E ] 合上备用电闸"
			if Input.is_action_just_pressed("interact"):
				_trigger_breaker()
		else:
			hud.prompt.text = ""
	elif phase == "chase":
		_update_chase(delta)
		if player.position.distance_to(DOOR_POS) < 48.0:
			hud.prompt.text = "[ E ] 冲出逃生铁门！"
			if Input.is_action_just_pressed("interact"):
				_trigger_escape()
		else:
			hud.prompt.text = "按住 Shift 狂奔向左侧逃生门！"
	elif phase == "dawen_flee":
		_update_dawen_chase(delta)
		if player.position.distance_to(DOOR_POS) < 45.0:
			hud.prompt.text = "[ E ] 冲入 304 锁上门！"
			if Input.is_action_just_pressed("interact"):
				_finish_prologue()

func _trigger_breaker() -> void:
	breaker_done = true
	hud.prompt.text = ""
	AudioManager.play_world_effect("power_switch")
	player.controls_enabled = false
	player.clear_motion()
	
	hud.open_panel("备用电闸", "电闸合上了！走廊顶上的日光灯闪了几下……\n\n等等，走廊尽头好像有粗重的拖拽声……？", [], false, "黄梓豪", null, null)

func _on_hud_close() -> void:
	if breaker_done and phase == "explore":
		_start_stalker_chase()

func _start_stalker_chase() -> void:
	phase = "chase"
	player.controls_enabled = true
	hud.objective.text = "恶灵现身！按住 Shift 狂奔冲向左侧逃生铁门！"
	AudioManager.play_world_effect("hall_wail")
	AudioManager.start_chase_music()
	
	# Spawn horrifying fast stalker
	monster = CharacterBody2D.new()
	monster.position = Vector2(610, 210)
	monster.collision_layer = 4
	monster.collision_mask = 1
	var cshape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 12.0
	cshape.shape = circ
	monster.add_child(cshape)
	
	var fig := Sprite2D.new()
	var mtex: Texture2D = load("res://assets/characters/priest_lunge_026.png")
	if mtex != null:
		fig.texture = mtex
		fig.scale = Vector2(0.16, 0.16)
		fig.modulate = Color(0.95, 0.25, 0.25)
	monster.add_child(fig)
	add_child(monster)
	stalker_active = true

func _update_chase(delta: float) -> void:
	if not stalker_active or not is_instance_valid(monster):
		return
	var dir := monster.position.direction_to(player.position)
	var chase_speed: float = 125.0 # Ao Oni fast pursuit!
	monster.velocity = dir * chase_speed
	monster.move_and_slide()
	
	# Caught by monster!
	if monster.position.distance_to(player.position) < 24.0:
		_on_ah_hao_caught()

func _on_ah_hao_caught() -> void:
	stalker_active = false
	AudioManager.stop_chase_music()
	player.controls_enabled = false
	player.clear_motion()
	
	# Jumpscare!
	await DemoCaptureAnimation.play_on(self, "res://assets/characters/priest_lunge_026.png")
	if not is_instance_valid(hud): return
	
	# Retry
	hud.open_panel("被恶灵扑倒", "恶灵速度极快！按住 Shift 奔跑，绕开路上的箱子逃往大门！", [
		{"text": "从电闸前重试", "callback": Callable(self, "_retry_ahhao_catch")}
	], false, "系统")

func _trigger_escape() -> void:
	stalker_active = false
	phase = "escape"
	AudioManager.stop_chase_music()
	player.controls_enabled = false
	player.clear_motion()
	if is_instance_valid(monster):
		monster.queue_free()
	
	# Spawn Da-wen waiting outside door
	dawen_npc = Node2D.new()
	dawen_npc.position = Vector2(65, 210)
	var d_sprite := Sprite2D.new()
	var d_tex: Texture2D = load("res://assets/characters/dawen_flashlight_025.png")
	if d_tex != null:
		d_sprite.texture = d_tex
		d_sprite.scale = Vector2(0.15, 0.15)
	dawen_npc.add_child(d_sprite)
	add_child(dawen_npc)
	
	hud.open_panel("劫后余生", "阿豪：呼……呼……姐夫！！甩掉了……！走廊里真有鬼！一个满身血痕的怪尸刚才一直在追我！快……快去找我姐，我们必须马上离开这鬼地方！", [
		{"text": "大文：阿豪你冷静点……", "callback": _trigger_instant_kill}
	], false, "黄梓豪")

func _trigger_instant_kill() -> void:
	hud.close_panel()
	phase = "ambush"
	
	# Dramatic screen shock & instant brutal kill
	AudioManager.play_world_effect("jumpscare_shriek")
	
	# Blood decals
	blood_decal = Node2D.new()
	blood_decal.position = player.position
	var b_draw := GDScript.new()
	b_draw.source_code = """extends Node2D
func _draw() -> void:
	draw_circle(Vector2.ZERO, 28.0, Color(0.75, 0.05, 0.05, 0.9))
	draw_circle(Vector2(14, 8), 16.0, Color(0.65, 0.02, 0.02, 0.85))
	draw_circle(Vector2(-12, 10), 18.0, Color(0.55, 0.02, 0.02, 0.85))
"""
	b_draw.reload()
	blood_decal.set_script(b_draw)
	add_child(blood_decal)
	
	# Ah Hao is struck down!
	player.sprite.modulate = Color(0.8, 0.1, 0.1)
	player.sprite.rotation = PI * 0.5
	player.position += Vector2(0, 15)
	
	# Spawn killer monster right above Ah Hao
	monster = CharacterBody2D.new()
	monster.position = player.position - Vector2(10, 30)
	var fig := Sprite2D.new()
	var mtex: Texture2D = load("res://assets/characters/priest_lunge_026.png")
	if mtex != null:
		fig.texture = mtex
		fig.scale = Vector2(0.18, 0.18)
		fig.modulate = Color(1.0, 0.1, 0.1)
	monster.add_child(fig)
	add_child(monster)
	
	# Camera shake impact
	var tw := create_tween()
	tw.tween_property(self, "position", Vector2(15, -10), 0.05)
	tw.tween_property(self, "position", Vector2(-12, 8), 0.05)
	tw.tween_property(self, "position", Vector2(8, -5), 0.05)
	tw.tween_property(self, "position", Vector2.ZERO, 0.08)
	
	await get_tree().create_timer(0.4).timeout
	if not is_instance_valid(hud): return
	
	hud.open_panel("目击瞬杀！", "天花板通风管猛然暴裂！一只枯槁血爪瞬间贯穿了阿豪的胸膛！\n\n鲜血溅满了大文的面门。阿豪倒在血泊中，拼尽最后一丝力气抓住大文：\n“姐……姐夫……快去……救我姐……”\n恶灵冰冷扭曲的面孔缓缓转向了大文……！", [
		{"text": "大文：阿豪！！！跑！！！", "callback": _start_dawen_flee}
	], false, "陈大文")

func _start_dawen_flee() -> void:
	hud.close_panel()
	phase = "dawen_flee"
	
	# POV snaps to Da-wen!
	if is_instance_valid(dawen_npc):
		dawen_npc.queue_free()
	
	player.sprite.rotation = 0
	player.sprite.modulate = Color.WHITE
	player.position = Vector2(120, 210)
	player.controls_enabled = true
	
	hud.objective.text = "阿豪牺牲！恶灵扑过来了！快往左侧 304 房门跑！！"
	AudioManager.start_chase_music()
	stalker_active = true

func _update_dawen_chase(_delta: float) -> void:
	if not stalker_active or not is_instance_valid(monster):
		return
	var dir := monster.position.direction_to(player.position)
	monster.velocity = dir * 135.0 # Even faster!
	monster.move_and_slide()
	
	if monster.position.distance_to(player.position) < 22.0:
		# Da-wen caught
		stalker_active = false
		AudioManager.stop_chase_music()
		player.controls_enabled = false
		DemoCaptureAnimation.play_on(self, "res://assets/characters/priest_lunge_026.png")
		hud.open_panel("被怪物扑倒", "大文被恶灵扑倒在血泊中……按住 Shift 全速冲向 304！", [
			{"text": "重新逃生", "callback": Callable(self, "_retry_after_dawen_caught")}
		], false, "陈大文")

func _finish_prologue() -> void:
	stalker_active = false
	AudioManager.stop_chase_music()
	player.controls_enabled = false
	player.clear_motion()
	
	AudioManager.play_world_effect("entrance_door")
	hud.open_panel("逃入 304", "大文撞进 304 室，反手死死锁上门栓！\n\n门外传来刺耳的抓挠声与撞击声……嘉敏不在这里，手机落在门外，阿豪惨死在眼前。\n\n绝望的寻人之路正式开始。", [
		{"text": "进入主线：香港出发前夜", "callback": Callable(self, "_continue_to_opening")}
	], false, "陈大文")
func _retry_ahhao_catch() -> void:
	hud.close_panel()
	player.position = BREAKER_POS - Vector2(40, 0)
	monster.position = Vector2(610, 210)
	stalker_active = true
	player.controls_enabled = true
	AudioManager.start_chase_music()

func _retry_after_dawen_caught() -> void:
	hud.close_panel()
	player.position = Vector2(160, 210)
	monster.position = Vector2(280, 210)
	stalker_active = true
	player.controls_enabled = true
	AudioManager.start_chase_music()

func _continue_to_opening() -> void:
	hud.close_panel()
	GameState.request_room_change("ch0_hk_work", "arrival")
