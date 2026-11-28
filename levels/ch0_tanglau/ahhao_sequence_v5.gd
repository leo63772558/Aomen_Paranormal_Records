extends Node2D

const BREAKER := Vector2(550, 235)
const AH_EXIT := Vector2(94, 238)
const DAWEN_EXIT := Vector2(478, 235)
var player: PlayerController
var hud
var monster: CharacterBody2D
var phase := "explore"
var after_panel := Callable()
var ambience: CanvasModulate
var ceiling_light: PointLight2D
var switch_arm: Sprite2D
var grille: Sprite2D
var exit_sign: PointLight2D
var exit_beacon: PointLight2D
var dawen_npc: PlayerController
var corpse: Sprite2D
var caught_layer: CanvasLayer
var preview := false
var transition_busy := false
var animation_clock := 0.0
var snapshots: Dictionary = {}

func _ready() -> void:
	GameState.prepare_opening_resume()
	AudioManager.set_scene_ambience("crypt")
	preview = GameState.pending_entry_id == "arrival"
	GameState.enter_role("dawen" if GameState.opening_flags.ah_hao_dead else "ah_hao")
	_build_room()
	player = preload("res://entities/player/player.tscn").instantiate()
	player.appearance = "flashlight" if GameState.current_role == "dawen" else "ah_hao"
	player.visual_size_multiplier = 1.65
	player.position = Vector2(130, 260)
	add_child(player)
	hud = preload("res://ui/quiet_hud.gd").new()
	add_child(hud)
	hud.close_requested.connect(_close_panel)
	hud.pause_requested.connect(_pause)
	if GameState.opening_flags.ah_hao_dead:
		_say("304 门外", "通风口还在刮响……阿豪倒在血泊里，快冲进右边 304 锁门！", _start_dawen_flee)
	elif GameState.opening_flags.ah_hao_escaped:
		_quiet_reunion()
	elif GameState.opening_flags.ah_hao_breaker_done:
		player.position = Vector2(532, 260)
		_say("闸箱旁", "补光灯还亮着，退路在左边楼梯口！绕开鞋架冲过去！", _start_ah_chase)
	else:
		await _show_role_card("黄梓豪（阿豪）", "福荣里唐楼 · 二楼半", Color("9be0b4"))
		if not is_inside_tree(): return
		_say("二楼半 · 阿豪", "我姐先上 304 了。这走廊阴冷得吓人……快去右边合上备用闸刀，回楼梯口找姐夫。")

func _show_role_card(role: String, location: String, accent := Color("e4d6b4")) -> void:
	transition_busy = true
	player.controls_enabled = false
	player.clear_motion()
	var card := preload("res://core/components/role_switch_transition.gd").play(self, "视角切换 · " + role, location, accent)
	if card != null:
		await card.completed
	transition_busy = false

func _build_room() -> void:
	var background := Sprite2D.new()
	background.texture = preload("res://assets/tilesets/corridor_010.png")
	background.centered = false
	background.scale = Vector2(640, 360) / background.texture.get_size()
	add_child(background)
	ambience = CanvasModulate.new()
	ambience.color = Color("89968b")
	add_child(ambience)
	LevelGeometry.wall(self, Rect2(0, 0, 640, 207))
	LevelGeometry.wall(self, Rect2(0, 310, 640, 50))
	LevelGeometry.wall(self, Rect2(0, 207, 48, 103))
	LevelGeometry.wall(self, Rect2(592, 207, 48, 103))
	LevelGeometry.wall(self, Rect2(154, 198, 66, 23))
	LevelGeometry.wall(self, Rect2(222, 199, 23, 24))
	LevelGeometry.wall(self, Rect2(558, 201, 39, 27))
	ceiling_light = PointLight2D.new()
	ceiling_light.position = Vector2(374, 48)
	ceiling_light.texture = preload("res://assets/lighting/soft_light.png")
	ceiling_light.texture_scale = 1.1
	ceiling_light.energy = 0.50
	ceiling_light.color = Color("d9c89a")
	add_child(ceiling_light)
	var box := Sprite2D.new()
	box.texture = _hardware(0)
	box.position = Vector2(548, 175)
	box.scale = Vector2.ONE * (66.0 / box.texture.get_height())
	box.z_index = 210
	add_child(box)
	switch_arm = Sprite2D.new()
	switch_arm.texture = _hardware(1)
	switch_arm.position = Vector2(548, 197)
	switch_arm.scale = Vector2.ONE * (44.0 / switch_arm.texture.get_height())
	switch_arm.offset.y = -switch_arm.texture.get_height() * 0.40
	switch_arm.rotation = -1.1 if not GameState.opening_flags.ah_hao_breaker_done else 0.0
	switch_arm.z_index = 211
	add_child(switch_arm)
	grille = Sprite2D.new()
	grille.texture = _hardware(2)
	grille.position = Vector2(182, 80)
	grille.scale = Vector2.ONE * (57.0 / grille.texture.get_width())
	grille.z_index = 20
	add_child(grille)
	# Soft emerald safety-exit glow at the left stairwell (no intrusive floating Chinese labels on doors)
	exit_sign = PointLight2D.new()
	exit_sign.position = Vector2(86, 178)
	exit_sign.texture = preload("res://assets/lighting/soft_light.png")
	exit_sign.texture_scale = 0.72
	exit_sign.color = Color("5fe08c")
	exit_sign.energy = 0.28
	add_child(exit_sign)
	exit_beacon = PointLight2D.new()
	exit_beacon.position = Vector2(548, 175)
	exit_beacon.texture = preload("res://assets/lighting/soft_light.png")
	exit_beacon.texture_scale = 0.32
	exit_beacon.color = Color("f2cf84")
	exit_beacon.energy = 0.38 if not GameState.opening_flags.ah_hao_breaker_done else 0.0
	add_child(exit_beacon)
	for at in [BREAKER, AH_EXIT, DAWEN_EXIT]:
		var area := Area2D.new()
		area.position = at
		area.collision_layer = 8
		area.collision_mask = 2
		var shape := CircleShape2D.new()
		shape.radius = 35
		var collision := CollisionShape2D.new()
		collision.shape = shape
		area.add_child(collision)
		add_child(area)

func _hardware(index: int) -> AtlasTexture:
	var sheet := preload("res://assets/props/annex_hardware_046.png")
	var cell := sheet.get_size() / Vector2(2, 2)
	var crop := AtlasTexture.new()
	crop.atlas = sheet
	crop.region = Rect2(Vector2(index % 2, index / 2) * cell, cell)
	crop.filter_clip = true
	return crop

func _part(region: Rect2) -> AtlasTexture:
	var crop := AtlasTexture.new()
	crop.atlas = preload("res://assets/characters/ahhao_ambush_parts_045.png")
	crop.region = region
	crop.filter_clip = true
	return crop

func _process(delta: float) -> void:
	animation_clock += delta
	if not is_instance_valid(hud) or hud.panel_open or transition_busy: return
	var to_exit := AH_EXIT - player.position
	var sees_exit := player.flashlight_on and to_exit.length() < 256.0 and player.look_dir.dot(to_exit.normalized()) > 0.86
	var exit_pulse := 0.95 + 0.35 * sin(animation_clock * 7.5) if phase == "ah_chase" else (0.72 if sees_exit else 0.24)
	exit_sign.energy = move_toward(exit_sign.energy, exit_pulse, delta * 3.5)
	if is_instance_valid(exit_beacon):
		exit_beacon.energy = (0.34 + 0.22 * sin(animation_clock * 3.6)) if phase == "explore" else 0.0
	var target := BREAKER if phase == "explore" else (AH_EXIT if phase == "ah_chase" else DAWEN_EXIT)
	hud.prompt.text = ""
	if phase in ["explore", "ah_chase", "dawen_flee"] and player.position.distance_to(target) < 43:
		hud.prompt.text = "[ E ] " + ("合上备用闸刀" if phase == "explore" else ("冲出后廊" if phase == "ah_chase" else "冲入 304，锁上门栓"))
	hud.objective.text = {"explore":"阿豪 · 用补光灯看清左侧楼梯口，再去右边合闸。", "ah_chase":"沿来路跑回左侧楼梯口。", "dawen_flee":"大文 · 沿过道冲进右侧 304。"}.get(phase, "")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or hud.panel_open or transition_busy: return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if phase == "explore" and player.position.distance_to(BREAKER) < 43: _throw_breaker()
		elif phase == "ah_chase" and player.position.distance_to(AH_EXIT) < 43: _escape_ah()
		elif phase == "dawen_flee" and player.position.distance_to(DAWEN_EXIT) < 43: _finish()

func _throw_breaker() -> void:
	transition_busy = true
	player.controls_enabled = false
	player.clear_motion()
	var tween := create_tween()
	tween.tween_property(switch_arm, "rotation", 0.0, 0.48).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	if not is_inside_tree(): return
	AudioManager.play_world_effect("power_switch")
	GameState.opening_flags.ah_hao_breaker_done = true
	checkpoint()
	for energy in [0.82, 0.22, 0.60, 0.30]:
		if not is_inside_tree() or not is_instance_valid(ceiling_light): return
		ceiling_light.energy = energy
		await get_tree().create_timer(0.13, false).timeout
	if not is_inside_tree(): return
	transition_busy = false
	_start_ah_chase()

func _spawn_monster(at: Vector2, speed: float) -> void:
	if is_instance_valid(monster): monster.queue_free()
	monster = preload("res://entities/shadow_chaser.gd").new()
	monster.position = at
	monster.speed = speed
	monster.target = player
	monster.caught.connect(_caught)
	add_child(monster)
	monster.active = true
	AudioManager.start_chase_music()

func _start_ah_chase() -> void:
	phase = "ah_chase"
	player.controls_enabled = true
	player.clear_motion()
	AudioManager.play_voice("ahhao_chase_panic", -1.5)
	_spawn_monster(Vector2(582, 260), 125.0)
	monster.active = false
	hud.notify("闸箱后传来沉重拖拽声！左侧安全灯亮了——快向左冲出楼梯口！")
	# Sequential right-to-left flashing guide lamps leading the player unambiguously left!
	if not GameState.reduced_flash:
		for idx in range(4):
			var lx := 470.0 - idx * 115.0
			var guide := PointLight2D.new()
			guide.position = Vector2(lx, 188)
			guide.texture = preload("res://assets/lighting/soft_light.png")
			guide.texture_scale = 0.65
			guide.color = Color("6be696")
			guide.energy = 0.0
			add_child(guide)
			var gtw := guide.create_tween()
			gtw.tween_interval(idx * 0.14)
			gtw.tween_property(guide, "energy", 0.95, 0.12)
			gtw.tween_property(guide, "energy", 0.0, 0.45)
			gtw.tween_callback(guide.queue_free)
	await get_tree().create_timer(0.75, false).timeout
	if phase == "ah_chase" and is_instance_valid(monster): monster.active = true

func _escape_ah() -> void:
	transition_busy = true
	monster.active = false
	monster.queue_free()
	AudioManager.stop_chase_music()
	GameState.opening_flags.ah_hao_escaped = true
	checkpoint()
	player.controls_enabled = false
	player.clear_motion()
	AudioManager.play_world_effect("entrance_door")
	var tween := create_tween()
	tween.tween_property(ambience, "color", Color("26312b"), 0.25)
	await tween.finished
	if not is_instance_valid(player): return
	player.position = Vector2(190, 260)
	player.look_dir = Vector2.LEFT
	player.set_appearance("ah_hao")
	player.reset_physics_interpolation()
	tween = create_tween()
	tween.tween_property(ambience, "color", Color("89968b"), 0.35)
	await tween.finished
	if not is_instance_valid(player): return
	transition_busy = false
	_quiet_reunion()

func _quiet_reunion() -> void:
	phase = "reunion"
	hud.objective.text = ""
	player.position = Vector2(190, 260)
	player.controls_enabled = false
	if not is_instance_valid(dawen_npc):
		dawen_npc = preload("res://entities/player/player.tscn").instantiate()
		dawen_npc.appearance = "flashlight"
		dawen_npc.visual_size_multiplier = 1.65
		dawen_npc.position = Vector2(138, 260)
		dawen_npc.controls_enabled = false
		dawen_npc.collision_layer = 1
		dawen_npc.z_index = 260
		add_child(dawen_npc)
	_say("楼梯口", "姐夫！走廊里有东西追我——快上去找我姐，这栋楼不对劲！", _ambush)

func _ambush() -> void:
	phase = "ambush"
	transition_busy = true
	player.controls_enabled = false
	player.clear_motion()
	# Omen: ceiling light sputters out, dust falls, vent violently snaps, emergency crimson strobe!
	for i in range(8):
		var dust := ColorRect.new()
		dust.size = Vector2(2, 2)
		dust.color = Color(0.72, 0.68, 0.58, 0.80)
		dust.position = Vector2(166 + i * 5, 86)
		dust.z_index = 490
		add_child(dust)
		var dtw := create_tween()
		dtw.tween_property(dust, "position:y", 242.0, 0.24 + i * 0.02)
		dtw.parallel().tween_property(dust, "modulate:a", 0.0, 0.26)
		dtw.tween_callback(dust.queue_free)
	if is_instance_valid(ceiling_light):
		ceiling_light.energy = 0.06
	AudioManager.play_world_effect("scare_bulb_pop")
	var dur_scale := 2.35
	var shake := create_tween()
	shake.tween_property(grille, "rotation", 0.08, 0.09 * dur_scale)
	shake.tween_property(grille, "rotation", -0.07, 0.09 * dur_scale)
	shake.tween_property(grille, "rotation", 0.05, 0.08 * dur_scale)
	shake.tween_property(grille, "rotation", 0.0, 0.10 * dur_scale)
	await shake.finished
	if not is_inside_tree(): return
	AudioManager.play_world_effect("iron_slam")
	grille.texture = _hardware(3)
	# Realistic tragic horror ambush: bulbs burst, dark corridor entity materializes from the extinguished shadow
	# as Ah Hao shoves his camera & fill light toward Dawen to hold the gate!
	GhostTaunt.materialize_from_shadow(self, Vector2(215, 232))
	var pounce := Sprite2D.new()
	var stalk_tex := preload("res://assets/characters/wardrobe_stalker_v5.png")
	var at := AtlasTexture.new()
	at.atlas = stalk_tex
	at.region = Rect2(stalk_tex.get_width() * 0.5, stalk_tex.get_height() * 0.5, stalk_tex.get_width() * 0.5, stalk_tex.get_height() * 0.5)
	pounce.texture = at
	pounce.scale = Vector2(0.14, 0.14)
	pounce.position = Vector2(258, 220)
	pounce.modulate = Color(0.75, 0.72, 0.76, 0.0)
	pounce.z_index = 500
	add_child(pounce)
	hud.notify("阿豪：“哥！顶灯全炸了——快拿好相机冲进 304！我顶住铁门！”")
	var thrust := create_tween()
	thrust.tween_property(pounce, "modulate:a", 0.96, 0.22 * dur_scale)
	thrust.tween_property(pounce, "position", Vector2(226, 223), 0.28 * dur_scale).set_trans(Tween.TRANS_SINE)
	thrust.tween_property(pounce, "position", Vector2(198, 226), 0.26 * dur_scale).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	thrust.parallel().tween_property(pounce, "scale", pounce.scale * 1.38, 0.26 * dur_scale)
	await thrust.finished
	if not is_instance_valid(player): return
	AudioManager.play_world_effect("capture_hit")
	AudioManager.play_world_effect("jumpscare_wraith")
	_spawn_ambush_blood_splatter(Vector2(198, 224))
	if not GameState.reduced_flash and is_instance_valid(ambience):
		ambience.color = Color("b52622")
		var flash_tw := create_tween()
		flash_tw.tween_property(ambience, "color", Color("1f2622"), 0.24 * dur_scale)
		flash_tw.tween_property(ambience, "color", Color("89968b"), 0.34 * dur_scale)
	player.sprite.hide()
	player.lamp.enabled = false
	var stagger := Sprite2D.new()
	stagger.texture = _part(Rect2(45, 15, 455, 640))
	stagger.position = Vector2(190, 215)
	stagger.scale = Vector2.ONE * (89.0 / 640.0)
	stagger.z_index = 261
	add_child(stagger)
	var fall := create_tween()
	fall.tween_property(stagger, "rotation", -0.08, 0.16 * dur_scale).set_trans(Tween.TRANS_SINE)
	fall.tween_property(stagger, "rotation", 0.22, 0.28 * dur_scale).set_trans(Tween.TRANS_CUBIC)
	fall.parallel().tween_property(stagger, "position", Vector2(201, 234), 0.34 * dur_scale)
	fall.parallel().tween_property(pounce, "modulate:a", 0.0, 0.42 * dur_scale)
	fall.parallel().tween_property(pounce, "position:y", 112.0, 0.42 * dur_scale)
	fall.tween_interval(0.18 * dur_scale)
	fall.tween_property(stagger, "modulate:a", 0.0, 0.24 * dur_scale)
	corpse = Sprite2D.new()
	corpse.texture = _part(Rect2(515, 382, 739, 281))
	corpse.position = Vector2(203, 258)
	corpse.scale = Vector2.ONE * (107.0 / 739.0)
	corpse.modulate.a = 0.0
	corpse.z_index = 220
	add_child(corpse)
	fall.parallel().tween_property(corpse, "modulate:a", 1.0, 0.28 * dur_scale)
	await fall.finished
	if not is_inside_tree(): return
	if is_instance_valid(stagger): stagger.queue_free()
	if is_instance_valid(pounce): pounce.queue_free()
	if is_instance_valid(dawen_npc):
		dawen_npc.hide()
		dawen_npc.collision_layer = 0
		dawen_npc.collision_mask = 0
	var help := Sprite2D.new()
	help.texture = _part(Rect2(645, 678, 609, 560))
	help.scale = Vector2.ONE * (64.0 / 560.0)
	help.position = Vector2(153, 228)
	help.z_index = 262
	add_child(help)
	var camera_prop := Sprite2D.new()
	camera_prop.texture = preload("res://assets/props/ahhao_camera_051.png")
	camera_prop.position = Vector2(210, 250)
	camera_prop.scale = Vector2.ONE * (16.0 / camera_prop.texture.get_width())
	camera_prop.rotation = 0.15
	camera_prop.z_index = 263
	add_child(camera_prop)
	var retrieval := create_tween()
	retrieval.tween_interval(0.20 * dur_scale)
	retrieval.tween_property(camera_prop, "position", Vector2(170, 235), 0.32 * dur_scale).set_trans(Tween.TRANS_SINE)
	retrieval.tween_property(camera_prop, "position", Vector2(149, 233), 0.24 * dur_scale)
	retrieval.parallel().tween_property(camera_prop, "modulate:a", 0.0, 0.24 * dur_scale)
	await retrieval.finished
	if not is_inside_tree(): return
	GameState.take_demo_item("ahhao_camera")
	GameState.opening_flags.ah_hao_dead = true
	GameState.enter_role("dawen")
	if is_instance_valid(camera_prop): camera_prop.queue_free()
	checkpoint()
	transition_busy = false
	AudioManager.play_voice("ahhao_dying", -1.0)
	_say("阿豪", "「姐……姐夫……别管我……快去救我姐……」\n他死死攥着大文袖口的手滑落下去。大文颤抖着抓起他掉在地上的相机。", func():
		help.queue_free()
		await _show_role_card("陈大文", "福荣里唐楼 · 304 门外")
		if is_inside_tree(): _start_dawen_flee()
	)

func _start_dawen_flee() -> void:
	phase = "dawen_flee"
	transition_busy = false
	if is_instance_valid(dawen_npc): dawen_npc.queue_free()
	GameState.enter_role("dawen")
	player.look_dir = Vector2.RIGHT
	player.has_mouse_aim = false
	player.set_appearance("flashlight")
	player.sprite.show()
	player.position = Vector2(133, 293)
	player.reset_physics_interpolation()
	player.controls_enabled = true
	player.clear_motion()
	if not is_instance_valid(corpse):
		corpse = Sprite2D.new()
		corpse.texture = _part(Rect2(515, 382, 739, 281))
		corpse.position = Vector2(203, 258)
		corpse.scale = Vector2.ONE * (107.0 / 739.0)
		corpse.z_index = 220
		add_child(corpse)
	if get_node_or_null("AhHaoFallenBodyCollision") == null:
		var body := LevelGeometry.wall(self, Rect2(160, 251, 91, 14))
		body.name = "AhHaoFallenBodyCollision"
	_spawn_monster(Vector2(103, 238), 132.0)
	monster.active = false
	GameState.phone_battery = maxf(GameState.phone_battery, GameState.RULES.phone_flash_cost * GameState.RULES.phone_flash_charges)
	GameState.phone_flash_charges = GameState.RULES.phone_flash_charges
	GameState.phone_flash_cooldown = 0.0
	hud.notify("按住 Shift 冲向右侧 304。恶灵逼近时可以按 R 强闪。")
	await get_tree().create_timer(0.65, false).timeout
	if not is_inside_tree(): return
	if phase == "dawen_flee" and is_instance_valid(monster): monster.active = true

func _caught() -> void:
	if transition_busy or phase == "caught": return
	var retry_phase := phase
	phase = "caught"
	transition_busy = true
	player.controls_enabled = false
	player.clear_motion()
	AudioManager.stop_chase_music()
	# Full painted-pixel HK horror face lunge (ZERO reaching claw hand!)
	await DemoCaptureAnimation.play_on(self, DemoCaptureAnimation.RANGER_PATH)
	if not is_inside_tree() or not is_instance_valid(player): return
	transition_busy = false
	_say("还没到门口", "身后追得很近。沿过道先绕开实体障碍，冲刺时不要停在柜脚前。\n\n这次从追逐前的安全位置重试。", _retry.bind(retry_phase))

func _retry(retry_phase: String) -> void:
	phase = retry_phase
	if retry_phase == "ah_chase":
		GameState.enter_role("ah_hao")
		GameState.stamina = 100.0
		player.position = Vector2(525, 263)
		_start_ah_chase()
	else:
		GameState.stamina = 100.0
		_start_dawen_flee()

func _finish() -> void:
	transition_busy = true
	monster.active = false
	monster.queue_free()
	AudioManager.stop_chase_music()
	player.controls_enabled = false
	player.clear_motion()
	AudioManager.play_world_effect("entrance_door")
	GameState.opening_flags.dawen_304_escape_done = true
	checkpoint()
	transition_busy = false
	_say("304 门边", "大文反手扣死门栓，门外利爪刮得木框剧烈发颤。\n「嘉敏不在屋里……门边地上的手机是她掉的！」", _continue_main)

func _continue_main(room_id := "ch0_room304", entry_id := "from_ah_escape") -> void:
	if preview:
		get_tree().change_scene_to_file("res://ui/main_menu.tscn")
		return
	# The next scene owns the visible phone pickup; do not silently grant it here.
	if GameState.request_room_change(room_id, entry_id):
		GameState.save_transition_checkpoint()
	else:
		_say("暂时无法进入 304", "房间暂时没有载入成功。大文仍在门边，稍后可继续重试。", _continue_main)

func _spawn_ambush_blood_splatter(origin: Vector2) -> void:
	# Arterial directional blood spray + persistent spreading crimson pool around Ah Hao's ambush site
	var spray := CPUParticles2D.new()
	spray.position = origin + Vector2(0, -14)
	spray.z_index = 265
	spray.one_shot = true
	spray.explosiveness = 0.94
	spray.amount = 34
	spray.lifetime = 0.68
	spray.direction = Vector2(-0.55, -0.35)
	spray.spread = 115.0
	spray.gravity = Vector2(0, 260.0)
	spray.initial_velocity_min = 65.0
	spray.initial_velocity_max = 185.0
	spray.scale_amount_min = 2.0
	spray.scale_amount_max = 4.6
	spray.color = Color("b61515")
	spray.emitting = true
	add_child(spray)
	var mist := CPUParticles2D.new()
	mist.position = origin + Vector2(4, -8)
	mist.z_index = 264
	mist.one_shot = true
	mist.explosiveness = 0.9
	mist.amount = 24
	mist.lifetime = 0.52
	mist.direction = Vector2(0.45, -0.45)
	mist.spread = 140.0
	mist.gravity = Vector2(0, 140.0)
	mist.initial_velocity_min = 38.0
	mist.initial_velocity_max = 115.0
	mist.scale_amount_min = 2.5
	mist.scale_amount_max = 5.5
	mist.color = Color(0.45, 0.03, 0.04, 0.85)
	mist.emitting = true
	add_child(mist)
	# Persistent dark-crimson spreading floor pool & wall splashes visible during Dawen's escape
	if get_node_or_null("AmbushBloodPool") == null:
		var pool := Polygon2D.new()
		pool.name = "AmbushBloodPool"
		pool.position = Vector2(201, 263)
		pool.z_index = 216
		pool.polygon = PackedVector2Array([
			Vector2(-28, 2), Vector2(-18, -7), Vector2(4, -9), Vector2(28, -5),
			Vector2(36, 3), Vector2(22, 10), Vector2(-6, 11), Vector2(-24, 7)
		])
		pool.color = Color(0.38, 0.025, 0.025, 0.88)
		pool.scale = Vector2(0.18, 0.18)
		add_child(pool)
		var sheen := Polygon2D.new()
		sheen.polygon = PackedVector2Array([Vector2(-12, -2), Vector2(10, -4), Vector2(16, 1), Vector2(-4, 4)])
		sheen.color = Color(0.68, 0.08, 0.07, 0.45)
		pool.add_child(sheen)
		var ptw := create_tween()
		ptw.tween_property(pool, "scale", Vector2(1.15, 1.05), 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for sp_pos in [Vector2(174, 240), Vector2(228, 246), Vector2(186, 256)]:
		var splash := Polygon2D.new()
		splash.position = sp_pos
		splash.z_index = 217
		splash.polygon = PackedVector2Array([Vector2(-7, -2), Vector2(2, -5), Vector2(9, 0), Vector2(4, 5), Vector2(-5, 3)])
		splash.color = Color(0.48, 0.03, 0.03, 0.78)
		add_child(splash)

func _say(title: String, body: String, after := Callable()) -> void:
	after_panel = after
	player.controls_enabled = false
	player.clear_motion()
	hud.open_panel(title, body, [], false, "黄梓豪" if GameState.current_role == "ah_hao" or title == "阿豪" else "陈大文")
	get_tree().paused = true

func _close_panel() -> void:
	AudioManager.stop_voice()
	hud.close_panel()
	get_tree().paused = false
	player.controls_enabled = not transition_busy and phase in ["explore", "ah_chase", "dawen_flee"]
	player.clear_motion()
	var callback := after_panel
	after_panel = Callable()
	if callback.is_valid(): callback.call()

func _pause() -> void:
	player.controls_enabled = false
	player.clear_motion()
	hud.open_panel("暂停", "走廊、追逐、动画与补光灯计时已经暂停。", [
		{"text":"继续", "callback":_close_panel},
		{"text":"保存并回到标题", "callback":_title}
	])
	get_tree().paused = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud) and is_instance_valid(player) and not hud.panel_open and not get_tree().paused:
		_pause()

func _title() -> void:
	_close_panel()
	if not GameState.save_opening_checkpoint():
		_say("保存失败", "当前进度未能保存，仍留在现场。请检查存储空间和文件夹权限后重试。")
		return
	AudioManager.stop_chase_music()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")

func checkpoint() -> void:
	if not GameState.save_opening_checkpoint() and is_instance_valid(hud):
		hud.show_resource_feedback("进度保存失败，仍可继续。请检查存储空间和文件夹权限后重试。")

func _exit_tree() -> void:
	AudioManager.stop_chase_music()
