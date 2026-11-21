extends Node

func _ready() -> void:
	if "--write-gate" in OS.get_cmdline_user_args():
		for key in GameState.opening_flags:
			GameState.opening_flags[key] = false
		for key in [
			"photo_taken", "pastry_shared", "knock_agreed", "entered_foyer",
			"meter_cover_open", "floor3_power", "jiamin_phone_found", "old_photo_seen",
			"room_bed_moved", "room_cover_open", "maintenance_unlocked", "yard_escaped",
			"crypt_photo_seen", "crypt_plan_seen", "crypt_doodle_seen", "crypt_aligned",
			"crypt_clip_removed", "crypt_door_open", "priest_escaped", "interview_index_copied",
			"bunker_oil_found", "bunker_lock_oiled", "bunker_lock_open", "bunker_key_2"
		]:
			GameState.opening_flags[key] = true
		GameState.opening_flags.bunker_gate_unlocked = false
		GameState.opening_flags.bunker_key_1 = false
		GameState.opening_flags.bunker_key_3 = false
		GameState.opening_switches.B = true
		GameState.opening_items = {
			"multitool_pliers": 1, "jiamin_phone": 1, "crypt_old_photo": 1,
			"crypt_survey": 1, "crypt_doodle": 1, "interview_index": 1,
			"oil": 1, "gate_key_2": 1
		}
		GameState.current_chapter_id = "ch2_guia_tunnel"
		GameState.current_room_id = "ch2_shelter"
		GameState.pending_entry_id = "from_base"
		var photo := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		photo.fill(Color("333333"))
		GameState.opening_photo = ImageTexture.create_from_image(photo)
		var ok := GameState.save_opening_checkpoint()
		print("GATE WRITE ", ok)
		get_tree().quit(0 if ok else 1)
	else:
		GameState.prepare_opening_resume()
		var flags: Dictionary = GameState.opening_flags
		var ok: bool = GameState.current_room_id == "ch2_shelter" and flags.bunker_key_2 and not flags.bunker_key_1 and not flags.bunker_key_3 and flags.bunker_oil_found and flags.bunker_lock_oiled and flags.bunker_lock_open and not flags.bunker_gate_unlocked
		print("GATE RESTART ", ok)
		get_tree().quit(0 if ok else 1)
