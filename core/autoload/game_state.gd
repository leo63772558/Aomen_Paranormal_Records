extends Node

const RULES = preload("res://core/data/game_rules.tres")
const LEGACY_PLAYER_PROFILE_PATH := "user://playtest_runs/sample_room"
var current_chapter_id: String = "ch0_tanglau"
var clues: Array[String] = []
var flags: Dictionary = {"bed_moved": false, "cover_open": false}
var stamina: float = 100.0
var flashlight_battery: float = 100.0
var phone_battery: float = 100.0
var phone_flash_charges: int = 0
var phone_flash_cooldown: float = 0.0
var phone_supplied_chapters: Dictionary = {}
var reduced_flash := false
var large_dialogue_text := false
var touch_mode_active: bool = false
var touch_controls_preference: String = "auto"
var touch_auto_sprint: bool = true
var touch_scale: float = 1.0
var touch_move_vector: Vector2 = Vector2.ZERO
var touch_sprint_held: bool = false
var touch_aim_vector: Vector2 = Vector2.ZERO
var touch_aim_active: bool = false
var active_hud: CanvasLayer = null
var active_player: Node = null
var _web_state_push_timer: float = 0.0
var _last_web_state_json: String = ""
# These are protected arrival/preparation rooms, not the chase rooms themselves.
const PHONE_PREPARATIONS := {
	"ch0_tanglau":"ch0_room304", "ch1_stpaul_crypt":"ch1_crypt_entry",
	"ch2_guia_tunnel":"ch2_hill_base", "ch3_amparo_alley":"ch3_amparo_archive",
	"ch4_bus33_loop":"ch4_bus_loop", "ch5_hacsa_beach":"ch5_hacsa_beach",
	"ch6_abandoned_vip":"ch6_abandoned_vip"
}
const PHONE_PREPARATION_POINTS := {
	"ch0_room304":Vector2(180, 182), "ch1_crypt_entry":Vector2(180, 152),
	"ch2_hill_base":Vector2(180, 212), "ch3_amparo_archive":Vector2(22, 232),
	"ch4_bus_loop":Vector2(206, 248), "ch5_hacsa_beach":Vector2(148, 224),
	"ch6_abandoned_vip":Vector2(768, 635)
}
var profile: String = "player"
var run_id: String = "player"
var launch_valid: bool = true
var opening_flags: Dictionary = OpeningCheckpoint.default_flags()
var opening_switches: Dictionary = OpeningCheckpoint.SWITCHES.duplicate(true)
var opening_items: Dictionary = {"multitool_pliers": 1}
var equipped_item_id: String = ""
var demo_pursuit: String = ""
var opening_photo: Texture2D
var opening_photo_file: String=""
var opening_resume_checked: bool=false
var opening_load_notice: String=""
var transition_save_failed := false
var macau_guide_unlocked: Array[String] = []
var current_room_id: String = "ch0_hk_work"
var pending_entry_id: String = "arrival"
var current_role := "dawen"
var preview_state: Dictionary = {}
var bus_loop_state := {"successes":0, "anomaly":"", "cycle":0, "bell_pulled":false, "initialized":false}
var legacy_coastal_qa := false
const PREVIEW_FIELDS := ["current_chapter_id", "current_room_id", "pending_entry_id", "current_role", "role_resources", "stamina", "flashlight_battery", "phone_battery", "phone_flash_charges", "phone_flash_cooldown", "phone_supplied_chapters", "opening_flags", "opening_switches", "opening_items", "macau_guide_unlocked", "demo_pursuit", "opening_photo", "opening_photo_file", "opening_resume_checked", "opening_load_notice", "transition_save_failed"]

func save_transition_checkpoint() -> void:
	if not save_opening_checkpoint():
		transition_save_failed = true

func begin_preview() -> void:
	if not preview_state.is_empty(): return
	for field in PREVIEW_FIELDS:
		var value = get(field)
		preview_state[field] = value.duplicate(true) if value is Dictionary or value is Array else value
	preview_state["bus_loop_state"] = bus_loop_state.duplicate(true)
	reset_opening()
	opening_resume_checked = true

func end_preview() -> void:
	if preview_state.is_empty(): return
	for field in PREVIEW_FIELDS: set(field, preview_state[field])
	bus_loop_state = preview_state.bus_loop_state.duplicate(true)
	preview_state.clear()
var role_resources := {"dawen":{"stamina":100.0,"flashlight_battery":100.0}, "ah_hao":{"stamina":100.0,"flashlight_battery":100.0}, "jiamin":{"stamina":25.0,"flashlight_battery":0.0}}

func enter_role(role: String) -> bool:
	if not role_resources.has(role): return false
	role_resources[current_role] = {"stamina":stamina, "flashlight_battery":flashlight_battery}
	current_role = role
	stamina = float(role_resources[role].stamina)
	flashlight_battery = float(role_resources[role].flashlight_battery)
	return true

func _room_scene_has_valid_controller(packed: PackedScene) -> bool:
	if packed == null or not packed.can_instantiate():
		return false
	var state := packed.get_state()
	if state == null or state.get_node_count() == 0:
		return false
	for index in range(state.get_node_property_count(0)):
		if state.get_node_property_name(0, index) == "script":
			var controller = state.get_node_property_value(0, index)
			return controller is Script and controller.can_instantiate()
	return false

func request_room_change(room_id: String, entry_id: String) -> bool:
	var rooms: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://core/data/rooms_db.json"))
	if not rooms.has(room_id) or entry_id not in rooms[room_id]["entries"]:
		return false
	var path: String = rooms[room_id]["scene"]
	if not ResourceLoader.exists(path):
		return false
	var packed = load(path)
	if not packed is PackedScene or not _room_scene_has_valid_controller(packed):
		return false
	var result: int = get_tree().change_scene_to_packed(packed)
	if result != OK:
		return false
	current_room_id = room_id
	pending_entry_id = entry_id
	current_chapter_id = OpeningCheckpoint.chapter_for_room(room_id)
	return true

func reset_opening() -> bool:
	bus_loop_state = {"successes":0, "anomaly":"", "cycle":0, "bell_pulled":false, "initialized":false}
	transition_save_failed = false
	current_role = "dawen"
	stamina = 100.0
	flashlight_battery = 100.0
	phone_battery = 100.0
	phone_flash_charges = 0
	phone_flash_cooldown = 0.0
	phone_supplied_chapters = {}
	role_resources = {"dawen":{"stamina":100.0,"flashlight_battery":100.0}, "ah_hao":{"stamina":100.0,"flashlight_battery":100.0}, "jiamin":{"stamina":25.0,"flashlight_battery":0.0}}
	opening_flags = OpeningCheckpoint.default_flags()
	opening_items = {"multitool_pliers": 1}
	macau_guide_unlocked.clear()
	equipped_item_id = ""
	demo_pursuit = ""
	opening_photo = null
	opening_photo_file=""
	current_room_id="ch0_hk_work"
	current_chapter_id="ch0_tanglau"
	pending_entry_id="arrival"
	for key in opening_switches:
		opening_switches[key] = false
	return save_opening_checkpoint()

func _archive_current_profile() -> bool:
	if not opening_checkpoint_enabled():
		return false
	var base := get_profile_path()
	var directory := DirAccess.open(base)
	if directory == null:
		return not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(base))
	var files: Array[String] = []
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if not directory.current_is_dir() and (name.begins_with("opening_checkpoint") or name.begins_with("pre_ending_checkpoint") or name.begins_with("invalid_checkpoint_") or (name.begins_with("photo_") and name.ends_with(".png"))):
			files.append(name)
		name = directory.get_next()
	directory.list_dir_end()
	if files.is_empty():
		return true
	var archive := base.path_join("history").path_join("before_new_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()])
	var archive_absolute := ProjectSettings.globalize_path(archive)
	if DirAccess.dir_exists_absolute(archive_absolute) or DirAccess.make_dir_recursive_absolute(archive_absolute) != OK:
		return false
	for filename in files:
		var original := base.path_join(filename)
		var copy := archive.path_join(filename)
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(original), ProjectSettings.globalize_path(copy)) != OK:
			return false
		var source_file := FileAccess.open(original, FileAccess.READ)
		var copy_file := FileAccess.open(copy, FileAccess.READ)
		if source_file == null or copy_file == null or source_file.get_length() != copy_file.get_length():
			return false
	return true

func start_new_opening() -> bool:
	# Archive first so the explicit in-game choice never silently destroys progress.
	if not _archive_current_profile():
		return false
	# A previous playthrough's decision point must never be used as this one's
	# fallback. Move it aside before creating the new opening, preserving it on
	# disk and restoring it if any part of the restart fails.
	var base := get_profile_path()
	var retired := base.path_join("history").path_join("retired_decision_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()])
	var moved: Array[String] = []
	for filename in ["pre_ending_checkpoint.json", "pre_ending_checkpoint.bak.json", "pre_ending_checkpoint.tmp.json"]:
		var source := base.path_join(filename)
		if not FileAccess.file_exists(source):
			continue
		if moved.is_empty() and DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(retired)) != OK:
			return false
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(retired.path_join(filename))) != OK:
			_restore_retired_decision(base, retired, moved)
			return false
		moved.append(filename)
	var old_state := {}
	for field in PREVIEW_FIELDS:
		var value = get(field)
		old_state[field] = value.duplicate(true) if value is Dictionary or value is Array else value
	old_state["bus_loop_state"] = bus_loop_state.duplicate(true)
	if not reset_opening():
		for field in PREVIEW_FIELDS:
			set(field, old_state[field])
		bus_loop_state = old_state.bus_loop_state.duplicate(true)
		_restore_retired_decision(base, retired, moved)
		return false
	opening_resume_checked = true
	opening_load_notice = ""
	return true

func _restore_retired_decision(base: String, retired: String, filenames: Array[String]) -> void:
	for filename in filenames:
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(retired.path_join(filename)), ProjectSettings.globalize_path(base.path_join(filename))) != OK:
			push_warning("Could not restore the previous decision checkpoint; its archived copy remains in history.")

func has_demo_item(item_id: String) -> bool:
	return opening_items.has(item_id)

func take_demo_item(item_id: String) -> bool:
	if not DemoItems.ENTRIES.has(item_id) or has_demo_item(item_id):
		return false
	opening_items[item_id] = 1
	EventBus.item_acquired.emit(item_id, 1)
	return true

func assemble_service_handle() -> bool:
	if not (has_demo_item("service_grip") and has_demo_item("service_spindle")):
		return false
	if not take_demo_item("service_handle"):
		return false
	opening_items.erase("service_grip")
	opening_items.erase("service_spindle")
	save_transition_checkpoint()
	return true

func opening_scope() -> Dictionary:
	return {"profile":profile,"run_id":run_id}

func opening_checkpoint_enabled() -> bool:
	if not preview_state.is_empty(): return false
	if profile == "test":
		return "--checkpoint-qa" in OS.get_cmdline_user_args()
	return profile in ["player", "playtest"] and "--script" not in OS.get_cmdline_args()

func prepare_opening_resume() -> void:
	if opening_resume_checked:
		return
	opening_resume_checked=true
	if not opening_checkpoint_enabled():
		return
	var result := OpeningCheckpoint.load_state(get_profile_path(), opening_scope())
	var migrated_legacy := false
	var source_profile_path := get_profile_path()
	if profile == "player" and not result.ok and not result.existing:
		var legacy_scope: Dictionary = {"profile": "playtest", "run_id": "sample_room"}
		result = OpeningCheckpoint.load_state(LEGACY_PLAYER_PROFILE_PATH, legacy_scope)
		migrated_legacy = result.ok
		if migrated_legacy:
			source_profile_path = LEGACY_PLAYER_PROFILE_PATH
	if not result.ok:
		if result.existing:
			opening_load_notice="开场存档未能读取，原文件已保留。本次从香港前序开始。"
		return
	_apply_opening_checkpoint(result.data, source_profile_path)
	if result.from_backup:
		opening_load_notice="主存档未能读取，已恢复上一份有效开场进度。"

	if migrated_legacy:
		opening_photo_file = ""
		if not save_opening_checkpoint():
			push_warning("Legacy player checkpoint loaded but could not be migrated; legacy data remains untouched.")

func uses_legacy_coastal_rooms() -> bool:
	return profile == "test" and legacy_coastal_qa

func mark_coastal_landing_passed() -> void:
	opening_flags.coastal_landing_seen = true
	opening_flags.coastal_crawlway_seen = true

func mark_coastal_silt_passed() -> void:
	opening_flags.coastal_silt_intro_seen = true
	opening_flags.coastal_silt_arch_seen = true
	opening_flags.coastal_silt_route_verified = true

func _apply_opening_checkpoint(data: Dictionary, source_profile_path: String) -> void:
	opening_flags=data.flags.duplicate(true)
	opening_switches=data.switches.duplicate(true)
	opening_items=data.items.duplicate()
	stamina=float(data.resources.stamina)
	flashlight_battery=float(data.resources.flashlight_battery)
	phone_battery = float(data.phone_defense.battery)
	phone_flash_charges = int(data.phone_defense.charges)
	phone_flash_cooldown = float(data.phone_defense.cooldown)
	phone_supplied_chapters = data.phone_defense.supplied_chapters.duplicate()
	current_role = data.active_role
	role_resources = data.role_resources.duplicate(true)
	bus_loop_state = data.bus_loop_state.duplicate(true)
	macau_guide_unlocked.clear()
	for card_id in data.get("macau_guide", []):
		if card_id is String and card_id not in macau_guide_unlocked:
			macau_guide_unlocked.append(card_id)
	current_room_id=data.room_id
	current_chapter_id=data.current_chapter_id
	pending_entry_id=data.entry_id
	# A staircase or retired guard shelter is never a place to resume mid-pursuit.
	if current_room_id == "ch2_hill_steps" or current_room_id == "ch2_bunker_shaft":
		current_room_id = "ch2_bunker_hall"
		pending_entry_id = "from_steps"
	elif not uses_legacy_coastal_rooms() and current_room_id == "ch5_coastal_landing":
		current_room_id = "ch5_coastal_chamber"
		pending_entry_id = "from_landing"
		mark_coastal_landing_passed()
	elif not uses_legacy_coastal_rooms() and current_room_id == "ch5_coastal_silt_tunnel":
		current_room_id = "ch5_coastal_pressure_gallery"
		pending_entry_id = "from_silt_tunnel"
		mark_coastal_silt_passed()
	opening_photo_file=data.photo_file
	opening_photo = null
	if opening_flags.photo_taken:
		opening_photo = ImageTexture.create_from_image(Image.load_from_file(source_profile_path.path_join(opening_photo_file)))

func _opening_checkpoint_data() -> Dictionary:
	if opening_flags.photo_taken and opening_photo_file.is_empty():
		if opening_photo==null:
			return {}
		opening_photo_file=OpeningCheckpoint.save_photo(get_profile_path(),opening_photo.get_image())
		if opening_photo_file.is_empty():
			return {}
	role_resources[current_role] = {"stamina":stamina, "flashlight_battery":flashlight_battery}
	return {"schema_version":OpeningCheckpoint.SCHEMA_VERSION,"build_id":"story_v5_087","rules_version":1,"profile":profile,"run_id":run_id,
		"checkpoint_id":"opening_stage","current_chapter_id":current_chapter_id,"room_id":current_room_id,"entry_id":pending_entry_id,
		"flags":opening_flags.duplicate(true),"switches":opening_switches.duplicate(true),"items":opening_items.duplicate(),
		"resources":{"stamina":stamina,"flashlight_battery":flashlight_battery},"photo_file":opening_photo_file,
		"phone_defense":{"battery":phone_battery,"charges":phone_flash_charges,"cooldown":phone_flash_cooldown,"supplied_chapters":phone_supplied_chapters.duplicate()},
		"active_role":current_role,"role_resources":role_resources.duplicate(true), "bus_loop_state":bus_loop_state.duplicate(true),
		"macau_guide":macau_guide_unlocked.duplicate()}

func unlock_macau_guide(card_id: String, show_toast := true) -> bool:
	if not MacauGuide.CARDS.has(card_id) or card_id in macau_guide_unlocked:
		return false
	macau_guide_unlocked.append(card_id)
	if show_toast and is_instance_valid(EventBus):
		var c: Dictionary = MacauGuide.get_card(card_id)
		EventBus.phone_defense_feedback.emit("【澳门见闻图鉴】已收录：%s（打开手机或背包可随时翻阅）" % str(c.get("title", card_id)))
	save_opening_checkpoint()
	return true

func save_opening_checkpoint() -> bool:
	if not opening_checkpoint_enabled() or not demo_pursuit.is_empty():
		return true
	var data := _opening_checkpoint_data()
	if data.is_empty():
		return false
	return OpeningCheckpoint.save_state(get_profile_path(),data,opening_scope())

func save_pre_ending_checkpoint() -> bool:
	if not opening_checkpoint_enabled() or not demo_pursuit.is_empty():
		return false
	var data := _opening_checkpoint_data()
	if data.is_empty() or data.flags.ending_missing or data.flags.ending_escape or data.flags.ending_truth:
		return false
	return OpeningCheckpoint.save_state(get_profile_path(), data, opening_scope(), "pre_ending_checkpoint")

func has_pre_ending_checkpoint() -> bool:
	if not opening_checkpoint_enabled():
		return false
	var result := OpeningCheckpoint.load_state(get_profile_path(), opening_scope(), "pre_ending_checkpoint")
	return result.ok and not result.data.flags.ending_missing and not result.data.flags.ending_escape and not result.data.flags.ending_truth

func recover_old_ending_checkpoint() -> bool:
	# Recover the last decision point from old builds without changing the main save.
	if has_pre_ending_checkpoint():
		return true
	if not opening_checkpoint_enabled():
		return false
	var result := OpeningCheckpoint.load_state(get_profile_path(), opening_scope())
	if not result.ok or not (result.data.flags.ending_missing or result.data.flags.ending_escape or result.data.flags.ending_truth):
		return false
	var data: Dictionary = result.data.duplicate(true)
	data.flags.ending_missing = false
	data.flags.ending_escape = false
	data.flags.ending_truth = false
	return OpeningCheckpoint.save_state(get_profile_path(), data, opening_scope(), "pre_ending_checkpoint")

func restore_pre_ending_checkpoint() -> bool:
	if not opening_checkpoint_enabled():
		return false
	var result := OpeningCheckpoint.load_state(get_profile_path(), opening_scope(), "pre_ending_checkpoint")
	if not result.ok or result.data.flags.ending_missing or result.data.flags.ending_escape or result.data.flags.ending_truth:
		return false
	# A failed write leaves the displayed ending and current in-memory state intact.
	if not OpeningCheckpoint.save_state(get_profile_path(), result.data, opening_scope()):
		return false
	_apply_opening_checkpoint(result.data, get_profile_path())
	opening_resume_checked = true
	return true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Enable smooth fractional window scaling on real displays so maximized windows fill the screen without giant integer black bars,
	# while keeping headless 100x100 dummy windows at exact 1:1 coordinate parity for automated QA.
	if DisplayServer.get_name() != "headless":
		var win := get_window()
		if win != null:
			win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
			win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var bindings := {
		"move_left": [KEY_A], "move_right": [KEY_D], "move_up": [KEY_W], "move_down": [KEY_S],
		"sprint": [KEY_SHIFT], "crouch": [KEY_CTRL], "interact": [KEY_E], "flashlight": [KEY_F],
		"phone": [KEY_Q, KEY_TAB], "camera_flash": [KEY_R], "hold_breath": [KEY_SPACE],
		"map": [KEY_M], "journal": [KEY_J], "inventory": [KEY_B], "investigation_hint": [KEY_H], "pause": [KEY_ESCAPE], "debug_autobot": [KEY_F9],
		"light_day": [KEY_F1], "light_out": [KEY_F2], "light_danger": [KEY_F3]
	}
	for action in bindings:
		InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	InputMap.add_action("photo_capture")
	InputMap.add_action("camera_mode")
	var camera_key := InputEventKey.new()
	camera_key.physical_keycode = KEY_C
	InputMap.action_add_event("camera_mode", camera_key)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("photo_capture", mouse)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--profile="):
			profile = argument.trim_prefix("--profile=")
		if argument.begins_with("--run-id="):
			run_id = argument.trim_prefix("--run-id=")
	if profile == "player":
		run_id = "player"
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9_-]{1,64}$")
	launch_valid = profile in ["player", "playtest", "test"] and regex.search(run_id) != null
	if "--autobot" in OS.get_cmdline_user_args() and profile != "test":
		launch_valid = false
	if not launch_valid:
		push_error("样板仅接受隔离的 playtest/test 配置和安全 run-id。")
		get_tree().quit(2)
	else:
		var preferences := ConfigFile.new()
		if preferences.load(get_profile_path().path_join("visual_preferences.cfg")) == OK:
			reduced_flash = preferences.get_value("visual", "reduced_flash", false) == true
			var saved_mode := str(preferences.get_value("touch", "mode", "auto"))
			if saved_mode in ["auto", "on", "off"]:
				touch_controls_preference = saved_mode
			touch_auto_sprint = preferences.get_value("touch", "auto_sprint", true) == true
			touch_scale = clampf(float(preferences.get_value("touch", "scale", 1.0)), 0.85, 1.15)
		var text_preferences := ConfigFile.new()
		if text_preferences.load(get_profile_path().path_join("text_preferences.cfg")) == OK:
			large_dialogue_text = text_preferences.get_value("text", "large_dialogue", false) == true

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	for actor in get_tree().get_nodes_in_group("phone_flash_actor"):
		if actor.controls_enabled and current_role == "dawen":
			phone_flash_cooldown = maxf(0.0, phone_flash_cooldown - delta)
			return

func _process(delta: float) -> void:
	if not OS.has_feature("web"):
		return
	var raw = JavaScriptBridge.eval("window.__AOMEN_BRIDGE__ && window.__AOMEN_BRIDGE__.poll ? window.__AOMEN_BRIDGE__.poll() : ''", false)
	if raw is String and not raw.is_empty():
		var parsed = JSON.parse_string(raw)
		if parsed is Dictionary:
			touch_mode_active = bool(parsed.get("ta", false))
			touch_move_vector = Vector2(float(parsed.get("mx", 0.0)), float(parsed.get("my", 0.0)))
			touch_sprint_held = bool(parsed.get("sp", false))
			touch_aim_vector = Vector2(float(parsed.get("ax", 0.0)), float(parsed.get("ay", 0.0)))
			touch_aim_active = bool(parsed.get("aa", false))
			var events = parsed.get("ev", [])
			if events is Array:
				for item in events:
					if item is Dictionary and item.has("a"):
						var ev := InputEventAction.new()
						ev.action = str(item.get("a", ""))
						ev.pressed = bool(item.get("p", false))
						ev.strength = 1.0 if ev.pressed else 0.0
						Input.parse_input_event(ev)
			var pref = parsed.get("pref", null)
			if pref is Dictionary:
				var pm := str(pref.get("mode", touch_controls_preference))
				if pm in ["auto", "on", "off"] and pm != touch_controls_preference:
					set_touch_controls_preference(pm)
				if pref.has("autoSprint") and bool(pref["autoSprint"]) != touch_auto_sprint:
					set_touch_auto_sprint(bool(pref["autoSprint"]))
				if pref.has("scale"):
					var ps := clampf(float(pref["scale"]), 0.85, 1.15)
					if not is_equal_approx(ps, touch_scale):
						set_touch_scale(ps)
	_web_state_push_timer += delta
	if _web_state_push_timer >= 0.08:
		_web_state_push_timer = 0.0
		var state_json := JSON.stringify(_collect_touch_ui_state())
		if state_json != _last_web_state_json:
			_last_web_state_json = state_json
			JavaScriptBridge.eval("window.__AOMEN_BRIDGE__ && window.__AOMEN_BRIDGE__.setState(" + state_json + ")", false)

func _is_camera_view_visible() -> bool:
	if not is_instance_valid(active_hud) or not is_instance_valid(active_hud.get("root")):
		return false
	for child in active_hud.root.get_children():
		if child is Control and child.visible and child.has_method("frame_rect"):
			return true
	return false

func _clean_prompt_verb(raw_prompt: String) -> String:
	var text := raw_prompt.strip_edges()
	for prefix in ["[ E ] ", "[E] ", "按 E ", "按E "]:
		if text.begins_with(prefix):
			text = text.substr(prefix.length()).strip_edges()
	if text.is_empty():
		return ""
	return text

func _collect_touch_ui_state() -> Dictionary:
	var hud_valid := is_instance_valid(active_hud) and active_hud.is_inside_tree()
	var player_valid := is_instance_valid(active_player) and active_player.is_inside_tree()
	var mode := "explore"
	if not hud_valid and not player_valid:
		mode = "menu"
	elif hud_valid and active_hud.panel_open and (bool(active_hud.get("is_widget_modal")) or not str(active_hud.get("archive_page")).is_empty()):
		mode = "modal"
	elif hud_valid and active_hud.panel_open:
		mode = "dialogue"
	elif _is_camera_view_visible():
		mode = "camera"
	elif not get_tree().get_nodes_in_group("pipe_knock_panel").is_empty():
		mode = "pipe_knock"
	elif not player_valid or not active_player.controls_enabled or get_tree().paused:
		mode = "cutscene"
	elif active_player.hidden_in_wardrobe:
		mode = "hidden"

	var raw_prompt := ""
	if hud_valid and is_instance_valid(active_hud.prompt) and active_hud.prompt.visible:
		raw_prompt = active_hud.prompt.text
	var cleaned_prompt := _clean_prompt_verb(raw_prompt)
	var has_phone := current_role == "dawen" and bool(opening_flags.get("jiamin_phone_found", false)) and has_demo_item("jiamin_phone")
	var can_hint: bool = hud_valid and active_hud.has_method("_hint_available") and bool(active_hud._hint_available())
	return {
		"mode": mode,
		"prompt": cleaned_prompt,
		"hasTarget": not cleaned_prompt.is_empty(),
		"crouching": bool(active_player.crouching) if player_valid else false,
		"flashlightOn": bool(active_player.flashlight_on) if player_valid else false,
		"allowFlashlight": bool(active_player.allow_flashlight) if player_valid else false,
		"hasPhone": has_phone,
		"flashCharges": phone_flash_charges,
		"flashCooldown": snappedf(phone_flash_cooldown, 0.1),
		"canCombineBag": has_demo_item("service_grip") and has_demo_item("service_spindle"),
		"bagCount": opening_items.size(),
		"canMap": has_demo_item("trip_map") or bool(opening_flags.get("jiamin_phone_found", false)),
		"canCamera": current_room_id == "ch0_street" and not bool(opening_flags.get("photo_taken", false)),
		"canHint": can_hint,
		"dialogueChoices": int(active_hud.choice_count) if (hud_valid and mode == "dialogue") else 0,
		"prefMode": touch_controls_preference,
		"prefAutoSprint": touch_auto_sprint,
		"prefScale": touch_scale,
	}

func try_use_phone_flash(actor: PlayerController) -> Dictionary:
	if not is_instance_valid(actor) or not actor.is_inside_tree() or get_tree().paused or not actor.controls_enabled or actor.hidden_in_wardrobe or not actor.allow_phone_defense:
		return {"ok":false,"reason":"先返回现场，离开藏身处后再举机。"}
	var dawen_own_phone: bool = current_room_id == "ch0_ah_kin" and opening_flags.ah_hao_dead
	if current_role != "dawen" or (not dawen_own_phone and (not opening_flags.jiamin_phone_found or not has_demo_item("jiamin_phone"))):
		return {"ok":false,"reason":"还没有可以使用强闪的手机。"}
	if phone_flash_cooldown > 0.0:
		return {"ok":false,"reason":"闪光还在回充，稍等一下。"}
	if phone_flash_charges <= 0:
		return {"ok":false,"reason":"本章的两次强闪已经用完，寻找原有的避险路线。"}
	if phone_battery < RULES.phone_flash_cost:
		return {"ok":false,"reason":"强闪需要 25% 手机电量；离线资料仍可阅读。"}
	phone_battery -= RULES.phone_flash_cost
	phone_flash_charges -= 1
	phone_flash_cooldown = RULES.phone_flash_cooldown
	return {"ok":true,"reason":"强闪后还剩 %d 次 · 手机电量 %d%%" % [phone_flash_charges, roundi(phone_battery)]}

func at_phone_preparation() -> bool:
	if current_role != "dawen" or not opening_flags.jiamin_phone_found or not demo_pursuit.is_empty():
		return false
	if PHONE_PREPARATIONS.get(current_chapter_id, "") != current_room_id:
		return false
	var near_socket := false
	for actor in get_tree().get_nodes_in_group("phone_flash_actor"):
		if actor.appearance not in ["jiamin", "ah_hao"] and not actor.hidden_in_wardrobe and actor.global_position.distance_to(PHONE_PREPARATION_POINTS[current_room_id]) <= 78.0:
			near_socket = true
	if not near_socket:
		return false
	if current_room_id == "ch6_abandoned_vip" and opening_flags.ch6_entity_lured and not opening_flags.ch6_entity_bound:
		return false
	return true

func grant_chapter_supply(chapter_id: String, supply_event_id: String) -> bool:
	if chapter_id != current_chapter_id or PHONE_PREPARATIONS.get(chapter_id, "") != current_room_id or supply_event_id != current_room_id or phone_supplied_chapters.has(chapter_id):
		return false
	if current_role != "dawen" or not opening_flags.jiamin_phone_found or not demo_pursuit.is_empty():
		return false
	phone_supplied_chapters[chapter_id] = true
	phone_flash_charges = RULES.phone_flash_charges
	phone_battery = maxf(phone_battery, RULES.phone_flash_cost * RULES.phone_flash_charges)
	flashlight_battery = 100.0
	phone_flash_cooldown = 0.0
	save_transition_checkpoint()
	return true

func recharge_preparation() -> bool:
	if not at_phone_preparation():
		return false
	phone_battery = 100.0
	flashlight_battery = 100.0
	# An outlet never restores the chapter's spent flash opportunities.
	save_transition_checkpoint()
	return true

func _save_visual_preference(section: String, key: String, value) -> void:
	if not launch_valid:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(get_profile_path()))
	var preferences := ConfigFile.new()
	preferences.load(get_profile_path().path_join("visual_preferences.cfg"))
	preferences.set_value(section, key, value)
	if preferences.save(get_profile_path().path_join("visual_preferences.cfg")) != OK:
		push_warning("Could not save preference %s/%s." % [section, key])

func set_reduced_flash(enabled: bool) -> void:
	reduced_flash = enabled
	_save_visual_preference("visual", "reduced_flash", enabled)

func set_touch_controls_preference(mode: String) -> void:
	if mode not in ["auto", "on", "off"]:
		return
	touch_controls_preference = mode
	_save_visual_preference("touch", "mode", mode)

func set_touch_auto_sprint(enabled: bool) -> void:
	touch_auto_sprint = enabled
	_save_visual_preference("touch", "auto_sprint", enabled)

func set_touch_scale(scale_val: float) -> void:
	touch_scale = clampf(scale_val, 0.85, 1.15)
	_save_visual_preference("touch", "scale", touch_scale)

func set_large_dialogue_text(enabled: bool) -> bool:
	large_dialogue_text = enabled
	if not launch_valid:
		return false
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(get_profile_path())) != OK:
		return false
	var preferences := ConfigFile.new()
	preferences.set_value("text", "large_dialogue", enabled)
	return preferences.save(get_profile_path().path_join("text_preferences.cfg")) == OK

func get_profile_path() -> String:
	if profile == "player":
		return "user://profiles/player/"
	if profile == "test":
		return "user://test_runs/%s/" % run_id
	return "user://playtest_runs/%s/" % run_id

func has_clue(clue_id: String) -> bool:
	return clue_id in clues

func try_add_clue(clue_id: String) -> bool:
	if clue_id not in ["old_photo", "floor_marks"] or has_clue(clue_id):
		return false
	clues.append(clue_id)
	EventBus.clue_collected.emit(clue_id)
	return true

func set_flag(flag_id: String, value: bool) -> bool:
	if not flags.has(flag_id):
		return false
	flags[flag_id] = value
	return true
