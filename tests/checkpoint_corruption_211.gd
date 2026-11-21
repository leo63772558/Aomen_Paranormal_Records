extends Node

var failures := 0

func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		failures += 1

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var scope := GameState.opening_scope()
	var base := GameState.get_profile_path()
	var valid := OpeningCheckpoint.load_state(base, scope)
	check(GameState.profile == "test" and valid.ok and valid.data.flags.ending_truth, "load isolated truth ending fixture")
	if not valid.ok or not valid.data.flags.ending_truth:
		get_tree().quit(1)
		return
	var original: Dictionary = valid.data
	for broken_value in [null, 42, [], {}]:
		var damaged := original.duplicate(true)
		damaged.room_id = broken_value
		check(OpeningCheckpoint.decode(JSON.stringify(damaged), scope).is_empty(), "reject invalid room type " + str(typeof(broken_value)))
	for broken_value in [null, 42, [], "invalid"]:
		var damaged := original.duplicate(true)
		damaged.items = broken_value
		check(OpeningCheckpoint.decode(JSON.stringify(damaged), scope).is_empty(), "reject invalid items type " + str(typeof(broken_value)))
	var missing_items := original.duplicate(true)
	missing_items.erase("items")
	check(OpeningCheckpoint.decode(JSON.stringify(missing_items), scope).is_empty(), "reject missing truth-ending items")
	check(not OpeningCheckpoint.decode(JSON.stringify(original), scope).is_empty(), "valid truth ending still decodes")
	var backup := FileAccess.open(base.path_join("opening_checkpoint.bak.json"), FileAccess.WRITE)
	backup.store_string(JSON.stringify(original))
	backup.close()
	var broken_text := JSON.stringify(missing_items)
	var main := FileAccess.open(base.path_join("opening_checkpoint.json"), FileAccess.WRITE)
	main.store_string(broken_text)
	main.close()
	var fallback := OpeningCheckpoint.load_state(base, scope)
	check(fallback.ok and fallback.from_backup and fallback.data.flags.ending_truth, "corrupted truth ending falls back to the valid backup")
	check(FileAccess.get_file_as_string(base.path_join("opening_checkpoint.json")) == broken_text, "fallback preserves the damaged primary for recovery")
	print("CHECKPOINT CORRUPTION failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
