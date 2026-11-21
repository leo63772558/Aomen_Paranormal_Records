extends SceneTree

var checks:int=0
var failures:int=0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks+=1
	if value:
		print("PASS: "+label)
	else:
		failures+=1
		push_error("FAIL: "+label)

func write(path: String, text: String) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(text)
	file.close()

func run() -> void:
	var base:="user://test_runs/checkpoint_006_%d" % Time.get_ticks_usec()
	var scope:={"profile":"test","run_id":"checkpoint_006"}
	var image:=Image.create(16,16,false,Image.FORMAT_RGBA8)
	image.fill(Color("714f38"))
	var photo:=OpeningCheckpoint.save_photo(base,image)
	check(not photo.is_empty(),"image writes, decodes and commits in isolated test root")
	var data:={"schema_version":1,"build_id":"test","rules_version":1,"profile":"test","run_id":"checkpoint_006","checkpoint_id":"opening_stage",
		"current_chapter_id":"ch0_tanglau","room_id":"ch0_street","entry_id":"arrival",
		"flags":OpeningCheckpoint.FLAGS.duplicate(true),"switches":OpeningCheckpoint.SWITCHES.duplicate(true),
		"resources":{"stamina":72.0,"flashlight_battery":100.0},"photo_file":photo}
	data.flags.photo_taken=true
	check(OpeningCheckpoint.save_state(base,data,scope),"first checkpoint commits")
	var first:=OpeningCheckpoint.load_state(base,scope)
	check(first.ok and first.data.flags.photo_taken and first.data.resources.stamina==72,"fresh read verifies flags and resources")
	data.flags.pastry_shared=true
	check(OpeningCheckpoint.save_state(base,data,scope),"second save keeps a validated backup before replacing primary")
	data.flags.knock_agreed=true
	check(OpeningCheckpoint.save_state(base,data,scope),"later save refreshes the backup with the latest valid primary")
	var main:=base.path_join("opening_checkpoint.json")
	write(main,"{truncated")
	var fallback:=OpeningCheckpoint.load_state(base,scope)
	check(fallback.ok and fallback.from_backup and fallback.data.flags.pastry_shared and not fallback.data.flags.knock_agreed,"truncated primary restores exactly the prior valid backup")
	check(FileAccess.get_file_as_string(main)=="{truncated","reading a damaged file does not overwrite it")
	check(OpeningCheckpoint.save_state(base,data,scope),"subsequent good save preserves invalid source and commits new primary")
	var dir:=DirAccess.open(base)
	var quarantines:int=0
	for name in dir.get_files():
		if name.begins_with("invalid_checkpoint_"):
			quarantines+=1
	check(quarantines==1,"invalid primary retained in one quarantine file")
	var original:=FileAccess.get_file_as_string(main)
	var invalid:=data.duplicate(true)
	invalid.flags.erase("jiamin_phone_found")
	var migrated:=OpeningCheckpoint.decode(JSON.stringify(invalid),scope)
	check(not migrated.is_empty() and not migrated.flags.jiamin_phone_found, "old checkpoints gain the new phone flag without losing progress")
	invalid=data.duplicate(true)
	invalid.room_id="ch0_room304"
	invalid.entry_id="from_corridor"
	check(OpeningCheckpoint.decode(JSON.stringify(invalid),scope).is_empty(), "room 304 requires power and phone")
	invalid=data.duplicate(true)
	invalid.schema_version=true
	check(not OpeningCheckpoint.save_state(base,invalid,scope),"boolean schema version rejected")
	invalid=data.duplicate(true)
	invalid.rules_version=2
	check(not OpeningCheckpoint.save_state(base,invalid,scope),"unknown rules version rejected")
	invalid=data.duplicate(true)
	invalid.resources.stamina=-1
	check(not OpeningCheckpoint.save_state(base,invalid,scope),"negative resource rejected before changing primary")
	invalid=data.duplicate(true)
	invalid.flags.erase("photo_taken")
	check(not OpeningCheckpoint.save_state(base,invalid,scope),"missing mandatory flag rejected")
	invalid=data.duplicate(true)
	invalid.room_id="res://arbitrary_scene.tscn"
	check(not OpeningCheckpoint.save_state(base,invalid,scope),"unregistered room paths rejected")
	invalid=data.duplicate(true)
	invalid.photo_file="../../outside.png"
	check(not OpeningCheckpoint.save_state(base,invalid,scope),"photo path traversal rejected")
	invalid=data.duplicate(true)
	invalid.flags.floor3_power=true
	check(not OpeningCheckpoint.save_state(base,invalid,scope),"inconsistent power and switch state rejected")
	invalid=data.duplicate(true)
	invalid.photo_file="photo_0_0.png"
	check(not OpeningCheckpoint.save_state(base,invalid,scope),"missing photo prevents commit of otherwise valid JSON")
	check(FileAccess.get_file_as_string(main)==original,"failed saves preserve prior primary bytes")
	check(not OpeningCheckpoint.load_state(base,{"profile":"player","run_id":"checkpoint_006"}).ok,"test checkpoint cannot be loaded as player profile")
	write(base.path_join("opening_checkpoint.tmp.json"),"{interrupted")
	check(OpeningCheckpoint.load_state(base,scope).ok,"interrupted temporary write cannot replace valid main")
	write(main,"{broken")
	write(base.path_join("opening_checkpoint.bak.json"),"{broken backup")
	var failed:=OpeningCheckpoint.load_state(base,scope)
	check(not failed.ok and failed.existing,"two invalid saves are reported, not treated as empty new progress")
	check(FileAccess.get_file_as_string(main)=="{broken","double failure keeps the damaged original")
	print("RESULT: %d checks, %d failures" % [checks,failures])
	call_deferred("quit",0 if failures==0 else 1)
