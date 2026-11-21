extends Node

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--checkpoint-write" in args:
		var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		image.fill(Color("714f38"))
		GameState.opening_photo = ImageTexture.create_from_image(image)
		for key in GameState.opening_flags:
			GameState.opening_flags[key] = true
		GameState.opening_switches.B = true
		GameState.current_room_id = "ch0_exit_lane" if "--checkpoint-lane" in args else "ch0_foyer"
		GameState.pending_entry_id = "from_yard" if "--checkpoint-lane" in args else "from_street"
		if "--checkpoint-bunker" in args:
			GameState.current_chapter_id = "ch2_guia_tunnel"
			GameState.current_room_id = "ch2_bunker_hall"
			GameState.pending_entry_id = "from_steps"
		GameState.stamina = 72.0
		var ok := GameState.save_opening_checkpoint()
		print("WRITE ", ok)
		get_tree().quit(0 if ok else 1)
	else:
		GameState.prepare_opening_resume()
		if "--checkpoint-final" in args:
			var photo_ok: bool = true
			if GameState.opening_flags.get("photo_taken", false):
				photo_ok = GameState.opening_photo != null and FileAccess.file_exists(GameState.get_profile_path().path_join(GameState.opening_photo_file))
			var final_ok: bool = GameState.profile == "player" and GameState.run_id == "player" and GameState.get_profile_path() == "user://profiles/player/" and GameState.current_room_id == "ch6_abandoned_vip" and GameState.opening_flags.get("ch6_jiamin_rescued", false) and GameState.opening_flags.get("ending_truth", false) and photo_ok
			print("PLAYER PROFILE RESUME ", final_ok, " photo=", photo_ok, " path=", GameState.get_profile_path(), " room=", GameState.current_room_id)
			get_tree().quit(0 if final_ok else 1)
			return
		var expected_room := "ch0_exit_lane" if "--checkpoint-lane" in args else "ch0_foyer"
		var entry := "from_yard" if "--checkpoint-lane" in args else "from_street"
		if "--checkpoint-bunker" in args:
			expected_room = "ch2_bunker_hall"
			entry = "from_steps"
		var ok: bool = GameState.current_room_id == expected_room and GameState.opening_flags.floor3_power and GameState.opening_switches.B and GameState.opening_photo != null and GameState.stamina == 72.0
		if "--checkpoint-lane" in args:
			ok = ok and GameState.opening_flags.help_attempted and GameState.opening_flags.yard_escaped and GameState.opening_flags.room_cover_open
		if ok:
			reparent(GameState)
			ok = GameState.request_room_change(expected_room, entry)
			await get_tree().process_frame
			await get_tree().process_frame
			var scene = get_tree().current_scene
			var expected_stage := "bunker_hall" if "--checkpoint-bunker" in args else ("exit_lane" if "--checkpoint-lane" in args else "foyer")
			ok = ok and scene != null and scene.stage_kind == expected_stage
			if "--checkpoint-lane" not in args and "--checkpoint-bunker" not in args:
				ok = ok and scene.stair_light.enabled
		print("RESTART AND SCENE STATE ", ok)
		get_tree().quit(0 if ok else 1)
