extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		push_error("FAIL " + label)

func frames(n: int) -> void:
	for i in range(n): await get_tree().physics_frame

func escape() -> void:
	var event := InputEventAction.new()
	event.action = "pause"
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(2)
	event = InputEventAction.new()
	event.action = "pause"
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(2)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var reading := "--read-cover" in args
	var action_phase := "--action-phase" in args
	check(GameState.profile == "test" and GameState.opening_checkpoint_enabled(),"uses isolated disk checkpoints")
	if reading:
		GameState.prepare_opening_resume()
	else:
		GameState.reset_opening()
		GameState.opening_resume_checked = true
		GameState.current_chapter_id = "ch0_tanglau"
		GameState.current_room_id = "ch0_room304"
		GameState.pending_entry_id = "from_corridor"
		for flag in ["photo_taken","pastry_shared","knock_agreed","entered_foyer","meter_cover_open","floor3_power","jiamin_phone_found","old_photo_seen","room_bed_moved","room_phone_answered"]:
			GameState.opening_flags[flag] = true
		GameState.opening_switches.B = true
		GameState.opening_photo = ImageTexture.create_from_image(Image.create(2,2,false,Image.FORMAT_RGBA8))
		GameState.take_demo_item("jiamin_phone")
		check(GameState.save_opening_checkpoint(),"closed-cover baseline writes")
	var scene := preload("res://levels/ch0_tanglau/room304.tscn").instantiate()
	scene.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(scene)
	await frames(5)
	if reading:
		check(not GameState.opening_flags.room_cover_open and scene.room_vent.visible,"interrupted action resumes closed cover")
		check(is_instance_valid(scene.room_aperture) and is_instance_valid(scene.room_aperture_shadow),"interrupted action resumes collision and shadow")
	else:
		scene.player.position = Vector2(520,211)
		scene.player.reset_physics_interpolation()
		scene.remove_room_cover()
		if action_phase: await frames(30)
		else: await frames(2)
		check(scene.work_in_progress and not GameState.opening_flags.room_cover_open,"action remains uncommitted")
		check(is_instance_valid(scene.vent_work_pose) == action_phase,"test reached intended action phase")
		await escape()
		check(get_tree().paused and scene.work_in_progress,"actual Esc opens pause during work")
		var before: Vector2 = scene.player.position
		var texture: Texture2D = scene.vent_work_pose.texture if action_phase else null
		await frames(50)
		check(get_tree().paused and scene.player.position == before,"actual Esc pauses player during work")
		check(not action_phase or (is_instance_valid(scene.vent_work_pose) and scene.vent_work_pose.texture == texture),"actual Esc freezes the work pose")
		check(not GameState.opening_flags.room_cover_open and is_instance_valid(scene.room_aperture) and is_instance_valid(scene.room_aperture_shadow),"pause does not commit opening")
		var saved := OpeningCheckpoint.load_state(GameState.get_profile_path(),GameState.opening_scope())
		check(saved.ok and not saved.data.flags.room_cover_open,"disk checkpoint stays closed during interrupted work")
		# Process exits while paused, simulating interruption before completion.
	print("COVER 101 checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
