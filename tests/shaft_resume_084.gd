extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(value: bool, text: String) -> void:
	checks += 1
	if value: print("PASS " + text)
	else:
		failures += 1
		push_error("FAIL " + text)

func frames(count: int) -> void:
	for _i in range(count): await get_tree().physics_frame

func run() -> void:
	var writing := "--write-shaft" in OS.get_cmdline_user_args()
	var fallen := "--fallen" in OS.get_cmdline_user_args()
	check(GameState.profile == "test" and GameState.opening_checkpoint_enabled(),"resume check uses isolated on-disk checkpoints")
	if writing:
		GameState.reset_opening()
		GameState.current_room_id = "ch2_bunker_shaft"
		GameState.current_chapter_id = "ch2_guia_tunnel"
		GameState.pending_entry_id = "from_hall"
		GameState.take_demo_item("bunker_recording")
		for flag in ["jiamin_phone_found","old_photo_seen","room_bed_moved","room_cover_open","maintenance_unlocked","yard_escaped","crypt_photo_seen","crypt_plan_seen","crypt_doodle_seen","crypt_aligned","crypt_clip_removed","crypt_door_open","priest_escaped","interview_index_copied","ch2_shaft_demo_seen"]:
			GameState.opening_flags[flag] = true
		GameState.phone_battery = 0
		GameState.phone_flash_charges = 0
	else:
		GameState.prepare_opening_resume()
		check(GameState.current_room_id == "ch2_bunker_shaft" and GameState.pending_entry_id == "from_hall","fresh process returns to registered shaft entry")
	var scene := preload("res://levels/ch2_guia/bunker_shaft_084.tscn").instantiate()
	add_child(scene)
	await frames(6)
	if writing:
		if fallen:
			scene.player.position = Vector2(545,296)
			scene.ranger.position = Vector2(294,269)
			scene.pull_rope()
			await frames(240)
			check(GameState.opening_flags.ch2_ranger_fallen,"actual rope action persists completed monster fall")
		else:
			scene.player.position = Vector2(650,435)
			scene.close_bypass()
			await frames(50)
			check(GameState.opening_flags.ch2_shaft_bypass_closed,"actual bypass action persists closed escape door")
		check(GameState.save_opening_checkpoint(),"resolved shaft snapshot writes successfully")
	else:
		check(scene.phase == scene.Phase.CLEARED and not scene.ranger.active and not scene.ranger.visible,"freshly loaded outcome has no resurrected enemy")
		check(GameState.phone_flash_charges == 0 and GameState.phone_battery == 0,"reload does not refill exhausted defense")
		if fallen:
			check(GameState.opening_flags.ch2_ranger_fallen and GameState.opening_flags.ch2_shaft_rope_used,"fresh process restores rope and monster outcome")
			check(scene.door_body.collision_layer == 0,"lure outcome leaves side door open")
		else:
			check(GameState.opening_flags.ch2_shaft_bypass_closed and not GameState.opening_flags.ch2_ranger_fallen,"fresh process distinguishes bypass from fall")
			check(scene.door_body.collision_layer == 1 and scene.door_shadow.visible,"fresh process restores closed door and shadow")
			check(scene.ALCOVE.has_point(scene.player.position),"closed-door snapshot spawns on the safe inside of the door")
	print("SHAFT RESUME writing=%s fallen=%s checks=%d failures=%d" % [writing,fallen,checks,failures])
	get_tree().quit(0 if failures == 0 else 1)
