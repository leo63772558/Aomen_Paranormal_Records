extends Node

var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var scope := GameState.opening_scope()
	var loaded := OpeningCheckpoint.load_state(GameState.get_profile_path(), scope)
	check(GameState.profile == "test" and loaded.ok and loaded.data.flags.ending_truth, "valid isolated ending fixture")
	if not loaded.ok:
		get_tree().quit(1)
		return
	var original: Dictionary = loaded.data
	for key in ["schema_version", "rules_version", "profile", "run_id", "room_id", "entry_id", "current_chapter_id", "flags", "switches", "resources", "items", "photo_file", "phone_defense", "active_role", "role_resources", "bus_loop_state"]:
		for value in [null, [], {}, false]:
			var damaged := original.duplicate(true)
			damaged[key] = value
			check(OpeningCheckpoint.decode(JSON.stringify(damaged), scope).is_empty(), "reject %s type %d" % [key, typeof(value)])
	for group in ["flags", "switches"]:
		for key in original[group]:
			var damaged := original.duplicate(true)
			damaged[group][key] = "invalid"
			check(OpeningCheckpoint.decode(JSON.stringify(damaged), scope).is_empty(), "reject %s.%s type" % [group, key])
	for group in ["resources", "phone_defense"]:
		for key in (["stamina", "flashlight_battery"] if group == "resources" else ["battery", "charges", "cooldown"]):
			var damaged := original.duplicate(true)
			damaged[group][key] = "invalid"
			check(OpeningCheckpoint.decode(JSON.stringify(damaged), scope).is_empty(), "reject %s.%s type" % [group, key])
	check(not OpeningCheckpoint.decode(JSON.stringify(original), scope).is_empty(), "original ending still decodes")
	print("CHECKPOINT TYPES checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
