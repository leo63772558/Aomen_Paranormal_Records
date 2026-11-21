extends Node

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	if GameState.profile != "test":
		push_error("audio settings test requires an isolated profile")
		get_tree().quit(1)
		return
	if "--verify-reload" in OS.get_cmdline_user_args():
		if not GameState.large_dialogue_text or not GameState.reduced_flash:
			push_error("text or reduced-flash preference was not restored")
			get_tree().quit(1)
			return
		for index in range(AudioManager.VOLUME_BUSES.size()):
			var expected := (30.0 + index * 10.0) / 100.0
			if absf(AudioManager.get_bus_volume(AudioManager.VOLUME_BUSES[index]) - expected) > 0.001:
				push_error("saved audio setting was not restored")
				get_tree().quit(1)
				return
		print("PASS five audio bus settings restored in an independent process")
		get_tree().quit()
		return
	var menu = load("res://ui/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().process_frame
	menu._open_audio_settings()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var capture := get_viewport().get_texture().get_image()
		if capture.save_png("res://docs/build_reports/audio_settings_152.png") != OK:
			push_error("audio settings capture failed")
			get_tree().quit(1)
			return
	for index in range(AudioManager.VOLUME_BUSES.size()):
		var bus_name: String = AudioManager.VOLUME_BUSES[index]
		var slider := menu.notice_panel.find_child("Volume_" + bus_name, true, false) as HSlider
		if slider == null:
			push_error("missing volume slider " + bus_name)
			get_tree().quit(1)
			return
		slider.value = 30 + index * 10
		if absf(AudioManager.get_bus_volume(bus_name) - slider.value / 100.0) > 0.001:
			push_error("slider changed the wrong bus: " + bus_name)
			get_tree().quit(1)
			return
	var larger := menu.notice_panel.find_child("LargeDialogueText", true, false) as CheckButton
	if larger == null:
		push_error("large dialogue setting is missing")
		get_tree().quit(1)
		return
	larger.button_pressed = true
	var reduce := menu.notice_panel.find_child("ReducedFlash", true, false) as CheckButton
	if reduce == null:
		push_error("reduced flash setting is missing")
		get_tree().quit(1)
		return
	reduce.button_pressed = true
	if not GameState.large_dialogue_text:
		push_error("large dialogue setting was not applied")
		get_tree().quit(1)
		return
	var path: String = GameState.get_profile_path().path_join("audio_preferences.cfg")
	var settings := ConfigFile.new()
	if settings.load(path) != OK or absf(float(settings.get_value("volume", "Voice", -1.0)) - 0.7) > 0.001:
		push_error("audio preferences did not persist")
		get_tree().quit(1)
		return
	if AudioManager.set_bus_volume("SFX", -1.0) or AudioManager.set_bus_volume("invalid", 0.5):
		push_error("invalid audio volume accepted")
		get_tree().quit(1)
		return
	AudioManager.set_bus_volume("Master", 0.0)
	if not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")):
		push_error("zero volume must mute")
		get_tree().quit(1)
		return
	AudioManager.set_bus_volume("Master", 0.3)
	menu._cancel_notice()
	await get_tree().process_frame
	if not menu.menu.visible:
		push_error("return did not restore the menu")
		get_tree().quit(1)
		return
	var hud = preload("res://ui/quiet_hud.gd").new()
	add_child(hud)
	await get_tree().process_frame
	hud.open_panel("测试", "这是一段用来确认较大文字分页和选项分区的对白。".repeat(12), [{"text":"继续", "callback":func(): pass}])
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var dialogue_capture := get_viewport().get_texture().get_image()
		if dialogue_capture.save_png("res://docs/build_reports/large_dialogue_156.png") != OK:
			push_error("large dialogue capture failed")
			get_tree().quit(1)
			return
	if hud.panel_body.get_theme_font_size("normal_font_size") != 16 or hud.pages.size() < 2 or hud.choice_buttons[0].visible:
		push_error("large dialogue must paginate before showing choices")
		get_tree().quit(1)
		return
	while hud.page_index < hud.pages.size() - 1:
		hud.advance()
	if not hud.choice_buttons[0].visible:
		push_error("choices must appear on the last page")
		get_tree().quit(1)
		return
	print("PASS five volume sliders, isolation, validation, mute, persistence and return")
	get_tree().quit()
