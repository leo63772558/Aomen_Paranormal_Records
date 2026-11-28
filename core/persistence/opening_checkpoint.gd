extends RefCounted
class_name OpeningCheckpoint

const SCHEMA_VERSION := 2
const DEMO_FLAGS := {
	"intro_job_done": false, "intro_invited": false, "intro_photo_seen": false,
	"intro_plan_seen": false, "intro_boarded": false, "phone_taught": false,
	"wet_tag_left": false, "pit_stone_thrown": false, "pit_bones_seen": false,
	"bunker_chain_relieved": false, "ammo_chase_cleared": false, "demo_case_closed": false,
	"bunker_recording_verified": false, "tart_granny_met": false, "tea_uncle_met": false,
	"street_ahhao_met": false, "foyer_intro_seen": false
}

const FLAGS := {"photo_taken":false,"pastry_shared":false,"knock_agreed":false,"entered_foyer":false,"meter_cover_open":false,"floor3_power":false,"jiamin_phone_found":false,"old_photo_seen":false,"room_bed_moved":false,"room_cover_open":false,"room_phone_answered":false,"wardrobe_tutorial_done":false,"shadow_passed":false,"maintenance_unlocked":false,"yard_escaped":false,"help_attempted":false}
const SWITCHES := {"A":false,"B":false,"C":false}
const SHAFT_FLAGS := {
	"ch2_shaft_demo_seen":false, "ch2_shaft_rope_used":false,
	"ch2_ranger_fallen":false, "ch2_shaft_bypass_closed":false, "ch2_shaft_note_seen":false
}
const SPARE_BATTERY_FLAGS := {
	"maintenance_spare_battery_taken":false, "crypt_spare_battery_taken":false,
	"bunker_spare_battery_taken":false, "silt_spare_battery_taken":false
}
const CRYPT_FLAGS := {"crypt_photo_seen":false, "crypt_plan_seen":false, "crypt_doodle_seen":false, "crypt_aligned":false, "crypt_clip_removed":false, "crypt_door_open":false, "priest_escaped":false, "interview_index_copied":false, "hill_stele_seen":false, "hill_warning_seen":false, "hill_steps_completed":false, "bunker_gate_unlocked":false, "bunker_red_seen":false, "bunker_gate_examined":false, "bunker_oil_found":false, "bunker_lock_oiled":false, "bunker_lock_open":false, "bunker_key_1":false, "bunker_key_2":false, "bunker_key_3":false}
const CH3_FLAGS := {"ch3_intro_seen":false, "ch3_photo_seen":false, "ch3_register_seen":false, "ch3_delivery_seen":false, "ch3_visitor_log_seen":false, "ch3_guest_inferred":false, "ch3_cold_door_seen":false, "ch3_cold_door_open":false, "ch3_balance_rule_seen":false, "ch3_balance_solved":false, "ch3_key_found":false, "ch3_ticket_found":false}
const BUS_FLAGS := {"bus_taught":false, "bus_reflection_cleared":false, "bus_voice_cleared":false, "bus_arrived":false}
const BEACH_FLAGS := {"beach_intro_seen":false, "beach_sole_seen":false, "beach_trace_a_seen":false, "beach_wrack_seen":false, "beach_trace_b_seen":false, "beach_footprints_solved":false, "beach_key_box_open":false, "beach_cabinet_key_found":false, "beach_headlights_on":false, "beach_parking_lights_on":false, "beach_cabinet_open":false, "beach_plan_found":false, "beach_circuit_matched":false, "coastal_intro_seen":false, "coastal_drain_seen":false, "coastal_arrow_seen":false, "coastal_thread_seen":false, "coastal_ladder_seen":false, "coastal_route_verified":false, "coastal_landing_seen":false, "coastal_lower_drain_seen":false, "coastal_shutter_seen":false, "coastal_crawlway_seen":false, "coastal_chamber_intro_seen":false, "coastal_chamber_tide_seen":false, "coastal_chamber_grate_seen":false, "coastal_chamber_hatch_seen":false, "coastal_chamber_west_seen":false, "coastal_chamber_route_verified":false, "coastal_silt_intro_seen":false, "coastal_silt_map_seen":false, "coastal_silt_sluice_seen":false, "coastal_silt_collapse_seen":false, "coastal_silt_grate_seen":false, "coastal_silt_arch_seen":false, "coastal_silt_route_verified":false, "coastal_pressure_intro_seen":false, "coastal_pressure_diagram_seen":false, "coastal_pressure_gauge_seen":false, "coastal_pressure_drain_seen":false, "coastal_pressure_inlet_closed":false, "coastal_pressure_bypass_open":false, "coastal_pressure_bleeder_open":false, "coastal_works_record_found":false, "coastal_pressure_route_verified":false}
const ROLE_FLAGS := {"ah_hao_breaker_done":false, "ah_hao_escaped":false, "ah_hao_dead":false, "dawen_304_escape_done":false}
const CH6_FLAGS := {
	"ch6_intro_seen":false, "ch6_jiamin_pipe_found":false, "ch6_signal_sent":false,
	"ch6_route_diagram_seen":false, "ch6_failed_echo_seen":false, "ch6_live_signal_received":false,
	"ch6_pipe_route_verified":false, "ch6_bunker_register_found":false, "ch6_venue_stopwork_found":false,
	"ch6_circuit_isolated":false, "ch6_entity_lured":false, "ch6_entity_bound":false,
	"ch6_rescue_door_open":false, "ch6_jiamin_rescued":false, "ch6_reunion_seen":false, "ch6_ahhao_camera_handed":false, "pre_ending_checkpoint":false,
	"ending_missing":false, "ending_escape":false, "ending_truth":false
}
const FINAL_ENTRIES := {"ch6_abandoned_vip":["from_pressure_gallery", "from_pre_ending"]}
const ENTRY_EXTENSIONS := {"ch5_coastal_pressure_gallery":["from_ch6"], "ch2_bunker_hall":["from_shaft"], "ch3_amparo_archive":["from_passage"], "ch3_quiet_passage":["from_archive"]}
const SHAFT_ENTRIES := {"ch2_bunker_shaft":["from_hall"]}
const ENTRIES := {"ch5_hacsa_beach":["from_bus_crash"],"ch5_coastal_works":["from_beach","from_landing"],"ch5_coastal_landing":["from_shaft","from_crawlway"],"ch5_coastal_chamber":["from_landing","from_silt_tunnel"],"ch5_coastal_silt_tunnel":["from_chamber","from_pressure_gallery"],"ch5_coastal_pressure_gallery":["from_silt_tunnel"],"ch0_street":["arrival","from_foyer"],"ch0_foyer":["from_street","from_corridor"],"ch0_corridor":["from_foyer","from_room304"],"ch0_room304":["from_corridor","from_maintenance","from_ah_escape"],"ch0_maintenance":["from_room304","from_yard"],"ch0_yard":["from_maintenance"],"ch0_exit_lane":["from_yard","from_crypt"],"ch1_crypt_entry":["from_lane","from_hall"],"ch1_crypt_hall":["from_entry","from_archive"],"ch1_archive":["from_hall","from_hill"],"ch2_hill_base":["from_archive"],"ch2_hill_steps":["from_hall"],"ch2_shelter":["from_base","from_descent"],"ch2_bunker_descent":["from_gate","from_hall"],"ch2_bunker_hall":["from_steps","from_descent","from_ammo"],"ch2_bunker_ammo":["from_hall"],"ch3_amparo_archive":["from_bunker"],"ch4_bus_loop":["arrival","loop_start","from_w17_ticket"]}
const INTRO_ENTRIES := {"ch0_ah_kin":["arrival","from_foyer"], "ch0_hk_work":["arrival"], "ch0_hk_home":["from_work"], "ch0_bridge_bus":["from_home"]}

static func default_flags() -> Dictionary:
	var result := FLAGS.duplicate()
	result.merge(CRYPT_FLAGS)
	result.merge(DEMO_FLAGS)
	result.merge(CH3_FLAGS)
	result.merge(BUS_FLAGS)
	result.merge(BEACH_FLAGS)
	result.merge(ROLE_FLAGS)
	result.merge(CH6_FLAGS)
	result.merge(SHAFT_FLAGS)
	result.merge(SPARE_BATTERY_FLAGS)
	return result

static func migrate_items(data: Dictionary) -> Dictionary:
	var items := {"multitool_pliers": 1, "trip_map": 1, "old_304_photo": 1}
	var carried := {
		"jiamin_phone_found": "jiamin_phone", "crypt_photo_seen": "crypt_old_photo",
		"crypt_plan_seen": "crypt_survey", "crypt_doodle_seen": "crypt_doodle",
		"interview_index_copied": "interview_index", "bunker_oil_found": "oil"
	}
	for flag in carried:
		if data.flags.get(flag, false):
			items[carried[flag]] = 1
	for key_number in range(1, 4):
		if data.flags.get("bunker_key_%d" % key_number, false):
			items["gate_key_%d" % key_number] = 1
	return items

static func chapter_for_room(room_id: String) -> String:
	if room_id.begins_with("ch6_"):
		return "ch6_abandoned_vip"
	if room_id.begins_with("ch5_"):
		return "ch5_hacsa_beach"
	if room_id.begins_with("ch4_"):
		return "ch4_bus33_loop"
	if room_id.begins_with("ch3_"):
		return "ch3_amparo_alley"
	if room_id.begins_with("ch2_"):
		return "ch2_guia_tunnel"
	return "ch1_stpaul_crypt" if room_id.begins_with("ch1_") else "ch0_tanglau"

static func decode(text: String, scope: Dictionary) -> Dictionary:
	var parser:=JSON.new()
	if parser.parse(text)!=OK or not parser.data is Dictionary:
		return {}
	var data: Dictionary=parser.data
	if not data.has("bus_loop_state"):
		data.bus_loop_state = {"successes":0, "anomaly":"", "cycle":0, "bell_pulled":false, "initialized":false}
	var bus = data.bus_loop_state
	if not bus is Dictionary: return {}
	if not bus.has("next_cycle_pending"): bus.next_cycle_pending = false
	if typeof(bus.next_cycle_pending) != TYPE_BOOL: return {}
	for numeric in ["successes", "cycle"]:
		if typeof(bus.get(numeric)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(bus[numeric])) or bus[numeric] != int(bus[numeric]) or bus[numeric] < 0: return {}
	if bus.successes > 8 or bus.cycle > 100000: return {}
	if bus.get("anomaly") not in GameRules.BUS_ANOMALIES and bus.get("anomaly") not in ["", "aisle_blood_seep", "ceiling_shadow", "empty_seat_shoes", "fog_runner", "hanging_straps", "rear_door_peeker", "window_fog_writing", "driver_neck_twist", "aisle_wet_footprints"]: return {}
	if typeof(bus.get("bell_pulled")) != TYPE_BOOL or typeof(bus.get("initialized")) != TYPE_BOOL: return {}
	if not bus.has("seen_anomalies"):
		bus.seen_anomalies = [bus.anomaly] if bus.anomaly in GameRules.BUS_ANOMALIES else []
	if not bus.seen_anomalies is Array or bus.seen_anomalies.size() > GameRules.BUS_ANOMALIES.size():
		return {}
	var seen := {}
	for anomaly in bus.seen_anomalies:
		if anomaly not in GameRules.BUS_ANOMALIES or seen.has(anomaly):
			return {}
		seen[anomaly] = true
	if typeof(data.get("schema_version")) not in [TYPE_INT, TYPE_FLOAT]:
		return {}
	if data.schema_version != 1 and data.schema_version != SCHEMA_VERSION:
		return {}
	if typeof(data.get("rules_version")) not in [TYPE_INT, TYPE_FLOAT] or data.rules_version != 1:
		return {}
	if typeof(data.get("profile")) != TYPE_STRING or typeof(data.get("run_id")) != TYPE_STRING:
		return {}
	if data.profile != scope.profile or data.run_id != scope.run_id:
		return {}
	if typeof(data.get("room_id")) != TYPE_STRING:
		return {}
	var room_id: String = data.room_id
	var room_entries: Array = SHAFT_ENTRIES.get(room_id, FINAL_ENTRIES.get(room_id, ENTRIES.get(room_id, INTRO_ENTRIES.get(room_id, [])))).duplicate()
	room_entries.append_array(ENTRY_EXTENSIONS.get(room_id, []))
	if room_entries.is_empty():
		return {}
	var expected_chapter := chapter_for_room(data.get("room_id", ""))
	if typeof(data.get("current_chapter_id")) != TYPE_STRING or data.current_chapter_id != expected_chapter:
		return {}
	if typeof(data.get("entry_id")) != TYPE_STRING or data.entry_id not in room_entries:
		return {}
	for name in ["flags","switches","resources"]:
		if not data.get(name) is Dictionary:
			return {}
	# Old opening checkpoints predate the phone; retain all existing progress.
	for added_flag in ["jiamin_phone_found", "old_photo_seen", "room_bed_moved", "room_cover_open", "room_phone_answered", "wardrobe_tutorial_done", "shadow_passed", "maintenance_unlocked", "yard_escaped", "help_attempted"]:
		if not data.flags.has(added_flag):
			data.flags[added_flag] = false
	if not data.flags.has("bunker_gate_unlocked"):
		data.flags.bunker_gate_unlocked = data.room_id in ["ch2_hill_steps", "ch2_bunker_hall"] or data.flags.get("hill_steps_completed", false)
	for added_flag in CRYPT_FLAGS:
		if not data.flags.has(added_flag):
			data.flags[added_flag] = false
		if typeof(data.flags[added_flag]) != TYPE_BOOL:
			return {}
	for added_flag in CH3_FLAGS:
		if not data.flags.has(added_flag):
			# Older builds marked the opened contents as collected when the scale solved.
			var previously_opened := bool(data.flags.get("ch3_balance_solved", false))
			data.flags[added_flag] = added_flag in ["ch3_balance_rule_seen", "ch3_key_found", "ch3_ticket_found"] and previously_opened
		if typeof(data.flags[added_flag]) != TYPE_BOOL:
			return {}
	for flag in DEMO_FLAGS:
		if not data.flags.has(flag):
			data.flags[flag] = data.schema_version == 1 and flag.begins_with("intro_")
		if typeof(data.flags[flag]) != TYPE_BOOL:
			return {}
	for flag in BUS_FLAGS:
		if not data.flags.has(flag):
			data.flags[flag] = false
		if typeof(data.flags[flag]) != TYPE_BOOL:
			return {}
	if data.flags.bus_reflection_cleared and not data.flags.bus_taught:
		return {}
	if data.flags.bus_voice_cleared and not data.flags.bus_reflection_cleared:
		return {}
	if data.flags.bus_arrived and not data.flags.bus_voice_cleared and bus.successes != 8 and bus.successes != 5:
		return {}
	for flag in BEACH_FLAGS:
		if not data.flags.has(flag): data.flags[flag] = false
		if typeof(data.flags[flag]) != TYPE_BOOL: return {}
	for flag in CH6_FLAGS:
		if not data.flags.has(flag): data.flags[flag] = false
		if typeof(data.flags[flag]) != TYPE_BOOL: return {}
	for flag in ROLE_FLAGS:
		if not data.flags.has(flag): data.flags[flag] = false
		if typeof(data.flags[flag]) != TYPE_BOOL: return {}
	for flag in SHAFT_FLAGS:
		if not data.flags.has(flag): data.flags[flag] = false
		if typeof(data.flags[flag]) != TYPE_BOOL: return {}
	for flag in SPARE_BATTERY_FLAGS:
		if not data.flags.has(flag): data.flags[flag] = false
		if typeof(data.flags[flag]) != TYPE_BOOL: return {}
	if data.flags.ch2_shaft_rope_used and not data.flags.ch2_shaft_demo_seen: return {}
	if data.flags.ch2_ranger_fallen and not data.flags.ch2_shaft_rope_used: return {}
	if data.flags.ch2_shaft_bypass_closed and not data.flags.ch2_shaft_demo_seen: return {}
	if data.flags.ah_hao_escaped and not data.flags.ah_hao_breaker_done: return {}
	if data.flags.ah_hao_dead and not data.flags.ah_hao_escaped: return {}
	if data.flags.dawen_304_escape_done and not data.flags.ah_hao_dead: return {}
	if data.room_id.begins_with("ch5_") and not (data.flags.bus_arrived and (bus.successes == 8 or bus.successes == 5)): return {}
	if data.flags.beach_footprints_solved and not (data.flags.beach_sole_seen and data.flags.beach_trace_a_seen and data.flags.beach_wrack_seen and data.flags.beach_trace_b_seen): return {}
	if data.flags.beach_cabinet_key_found and not data.flags.beach_key_box_open: return {}
	if data.flags.beach_cabinet_open and not data.flags.beach_cabinet_key_found: return {}
	if data.flags.beach_plan_found and not data.flags.beach_cabinet_open: return {}
	if data.flags.beach_circuit_matched and not data.flags.beach_plan_found: return {}
	if data.room_id == "ch5_coastal_works" and not data.flags.beach_circuit_matched: return {}
	if data.room_id == "ch5_coastal_landing" and not data.flags.coastal_route_verified: return {}
	if data.room_id == "ch5_coastal_chamber" and not (data.flags.coastal_route_verified and data.flags.coastal_landing_seen and data.flags.coastal_crawlway_seen): return {}
	if data.room_id == "ch5_coastal_silt_tunnel" and not (data.flags.coastal_chamber_route_verified and data.flags.coastal_silt_intro_seen): return {}
	if data.room_id == "ch5_coastal_pressure_gallery" and not (data.flags.coastal_silt_route_verified and data.flags.coastal_pressure_intro_seen): return {}
	if data.flags.coastal_route_verified and not (data.flags.beach_circuit_matched and data.flags.coastal_intro_seen and data.flags.coastal_ladder_seen): return {}
	if data.flags.coastal_landing_seen and not data.flags.coastal_route_verified: return {}
	if data.flags.coastal_lower_drain_seen and not data.flags.coastal_landing_seen: return {}
	if data.flags.coastal_shutter_seen and not data.flags.coastal_landing_seen: return {}
	if data.flags.coastal_crawlway_seen and not data.flags.coastal_landing_seen: return {}
	if data.flags.coastal_chamber_intro_seen and not data.flags.coastal_crawlway_seen: return {}
	if data.flags.coastal_chamber_route_verified and not data.flags.coastal_chamber_west_seen: return {}
	if data.flags.coastal_silt_intro_seen and not data.flags.coastal_chamber_route_verified: return {}
	if data.flags.coastal_silt_arch_seen and not data.flags.coastal_silt_intro_seen: return {}
	if data.flags.coastal_silt_route_verified and not data.flags.coastal_silt_arch_seen: return {}
	if data.flags.coastal_pressure_inlet_closed and not data.flags.coastal_pressure_intro_seen: return {}
	if data.flags.coastal_pressure_bypass_open and not data.flags.coastal_pressure_inlet_closed: return {}
	if data.flags.coastal_pressure_bleeder_open and not data.flags.coastal_pressure_bypass_open: return {}
	if data.flags.coastal_works_record_found and not data.flags.coastal_pressure_bleeder_open: return {}
	if data.flags.coastal_pressure_route_verified and not data.flags.coastal_works_record_found: return {}
	if data.room_id == "ch6_abandoned_vip" and not data.flags.coastal_pressure_route_verified: return {}
	if data.flags.ch6_jiamin_pipe_found and not data.flags.ch6_intro_seen: return {}
	if data.flags.ch6_signal_sent and not data.flags.ch6_jiamin_pipe_found: return {}
	if data.flags.ch6_live_signal_received and not (data.flags.ch6_signal_sent and data.flags.ch6_route_diagram_seen): return {}
	if data.flags.ch6_pipe_route_verified and not data.flags.ch6_live_signal_received: return {}
	if data.flags.ch6_failed_echo_seen and not data.flags.ch6_signal_sent: return {}
	if (data.flags.ch6_bunker_register_found or data.flags.ch6_venue_stopwork_found) and not data.flags.ch6_intro_seen: return {}
	if data.flags.ch6_circuit_isolated and not data.flags.ch6_pipe_route_verified: return {}
	if data.flags.ch6_entity_lured and not data.flags.ch6_circuit_isolated: return {}
	if data.flags.ch6_entity_bound and not data.flags.ch6_entity_lured: return {}
	if data.flags.ch6_rescue_door_open and not data.flags.ch6_entity_bound: return {}
	if data.flags.ch6_jiamin_rescued and not data.flags.ch6_rescue_door_open: return {}
	if data.flags.ch6_reunion_seen and not data.flags.ch6_jiamin_rescued: return {}
	if data.flags.pre_ending_checkpoint and not data.flags.ch6_jiamin_rescued: return {}
	if data.flags.ending_missing and not data.flags.ch6_failed_echo_seen: return {}
	if (int(data.flags.ending_missing) + int(data.flags.ending_escape) + int(data.flags.ending_truth)) > 1: return {}
	if (data.flags.ending_escape or data.flags.ending_truth) and not data.flags.pre_ending_checkpoint: return {}
	if (data.flags.ending_escape or data.flags.ending_truth) and not data.flags.ch6_jiamin_rescued: return {}
	if data.flags.beach_headlights_on and data.flags.beach_parking_lights_on: return {}
	if data.schema_version == 1:
		data.items = migrate_items(data)
	if not data.get("items") is Dictionary or data.items.get("multitool_pliers") != 1:
		return {}
	# Preserve progress from builds that recorded the key and ticket as auto-collected.
	if data.flags.ch3_key_found:
		data.items["archive_spare_key"] = 1
	if data.flags.ch3_ticket_found:
		data.items["w17_bus_ticket"] = 1
		# The note is folded with the ticket, including in pre-note checkpoints.
		data.items["laochen_handoff_note"] = 1
	if data.flags.beach_cabinet_key_found: data.items["beach_cabinet_key"] = 1
	if data.flags.beach_plan_found: data.items["hotel_maintenance_plan"] = 1
	for item_id in data.items:
		var count: Variant = data.items[item_id]
		if not DemoItems.ENTRIES.has(item_id) or typeof(count) not in [TYPE_INT, TYPE_FLOAT] or count != 1:
			return {}
	if data.flags.ending_truth and not (data.items.has("ahhao_camera") and data.flags.ch6_bunker_register_found and data.flags.ch3_register_seen and data.flags.ch3_balance_solved and data.flags.coastal_works_record_found and data.flags.ch6_venue_stopwork_found): return {}
	if data.flags.demo_case_closed and not (data.flags.ammo_chase_cleared and data.items.has("bunker_recording")):
		return {}
	if data.flags.crypt_aligned and not (data.flags.crypt_photo_seen and data.flags.crypt_plan_seen and data.flags.crypt_doodle_seen):
		return {}
	if data.flags.crypt_clip_removed and not data.flags.crypt_aligned:
		return {}
	if data.get("room_id", "").begins_with("ch3_") and not data.flags.demo_case_closed:
		return {}
	if data.flags.ch3_guest_inferred and not (data.flags.ch3_photo_seen and data.flags.ch3_register_seen and data.flags.ch3_delivery_seen and data.flags.ch3_visitor_log_seen):
		return {}
	if data.flags.ch3_balance_solved and not data.flags.ch3_balance_rule_seen:
		return {}
	if data.flags.ch3_balance_solved and not data.flags.ch3_cold_door_seen:
		return {}
	if data.flags.ch3_key_found and not data.flags.ch3_balance_solved:
		return {}
	if data.flags.ch3_ticket_found and not data.flags.ch3_balance_solved:
		return {}
	if data.flags.ch3_cold_door_open and not data.flags.ch3_key_found:
		return {}
	if data.get("room_id") == "ch3_quiet_passage" and not (data.flags.ch3_cold_door_open and data.flags.ch3_key_found and data.flags.ch3_ticket_found):
		return {}
	if data.get("room_id") == "ch4_bus_loop" and data.get("entry_id") == "from_w17_ticket" and not (data.flags.ch3_cold_door_open and data.flags.ch3_key_found and data.flags.ch3_ticket_found):
		return {}
	if data.flags.ch3_key_found != data.items.has("archive_spare_key"):
		return {}
	if data.flags.ch3_ticket_found != data.items.has("w17_bus_ticket"):
		return {}
	if data.flags.ch3_ticket_found != data.items.has("laochen_handoff_note"):
		return {}
	if data.flags.crypt_door_open and not data.flags.crypt_clip_removed:
		return {}
	if (data.get("room_id") == "ch1_crypt_hall" or data.flags.priest_escaped) and not data.flags.crypt_door_open:
		return {}
	if (data.get("room_id") == "ch1_archive" or data.flags.interview_index_copied) and not data.flags.priest_escaped:
		return {}
	if (data.get("room_id", "").begins_with("ch2_") or data.flags.hill_stele_seen or data.flags.hill_warning_seen or data.flags.hill_steps_completed) and not data.flags.interview_index_copied:
		return {}
	for key in FLAGS:
		if typeof(data.flags.get(key))!=TYPE_BOOL:
			return {}
	for key in SWITCHES:
		if typeof(data.switches.get(key))!=TYPE_BOOL:
			return {}
	for key in ["stamina","flashlight_battery"]:
		var value=data.resources.get(key)
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)<0 or float(value)>100:
			return {}
	# Optional in pre-081 saves. Migrate once, then preserve spent opportunities.
	if not data.has("phone_defense"):
		var supplied := {}
		if data.flags.jiamin_phone_found:
			supplied[data.current_chapter_id] = true
		data.phone_defense = {"battery":100.0, "charges":2 if data.flags.jiamin_phone_found else 0, "cooldown":0.0, "supplied_chapters":supplied}
	var defense = data.phone_defense
	if not defense is Dictionary or not defense.get("supplied_chapters") is Dictionary:
		return {}
	for key in ["battery", "charges", "cooldown"]:
		var number = defense.get(key)
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(number)) or number < 0:
			return {}
	if defense.battery > 100 or defense.charges != int(defense.charges) or defense.charges > 2 or defense.cooldown > 1.0:
		return {}
	for chapter in defense.supplied_chapters:
		if chapter not in ["ch0_tanglau", "ch1_stpaul_crypt", "ch2_guia_tunnel", "ch3_amparo_alley", "ch4_bus33_loop", "ch5_hacsa_beach", "ch6_abandoned_vip"] or defense.supplied_chapters[chapter] != true or typeof(defense.supplied_chapters[chapter]) != TYPE_BOOL:
			return {}
	if not data.has("active_role"): data.active_role = "dawen"
	if data.active_role not in ["dawen", "ah_hao", "jiamin"]: return {}
	if not data.has("role_resources"):
		data.role_resources = {"dawen":data.resources.duplicate(), "ah_hao":{"stamina":100.0,"flashlight_battery":100.0}, "jiamin":{"stamina":25.0,"flashlight_battery":0.0}}
	if not data.role_resources is Dictionary: return {}
	for role in ["dawen", "ah_hao", "jiamin"]:
		if not data.role_resources.get(role) is Dictionary: return {}
		for key in ["stamina", "flashlight_battery"]:
			var role_value = data.role_resources[role].get(key)
			if typeof(role_value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(role_value)) or float(role_value) < 0 or float(role_value) > 100: return {}
	for key in ["stamina", "flashlight_battery"]:
		if data.role_resources[data.active_role][key] != data.resources[key]: return {}
	if data.flags.pastry_shared and not data.flags.photo_taken:
		return {}
	if data.flags.knock_agreed and not data.flags.pastry_shared:
		return {}
	if data.flags.entered_foyer and not data.flags.knock_agreed:
		return {}
	if data.flags.floor3_power!=data.switches.B or (data.flags.floor3_power and not data.flags.meter_cover_open):
		return {}
	if data.room_id in ["ch0_foyer", "ch0_corridor", "ch0_room304", "ch0_maintenance", "ch0_yard", "ch0_exit_lane"] and not data.flags.entered_foyer:
		return {}
	if data.room_id in ["ch0_corridor", "ch0_room304", "ch0_maintenance", "ch0_yard", "ch0_exit_lane"] and not data.flags.floor3_power:
		return {}
	if data.room_id in ["ch0_room304", "ch0_maintenance", "ch0_yard", "ch0_exit_lane"] and not data.flags.jiamin_phone_found and not (data.room_id == "ch0_room304" and data.entry_id == "from_ah_escape" and data.flags.dawen_304_escape_done):
		return {}
	if data.flags.room_bed_moved and (not data.flags.old_photo_seen or not data.flags.jiamin_phone_found):
		return {}
	if data.flags.room_cover_open and not data.flags.room_bed_moved:
		return {}
	if data.room_id in ["ch0_maintenance", "ch0_yard", "ch0_exit_lane"] and not data.flags.room_cover_open:
		return {}
	if data.flags.maintenance_unlocked and not data.flags.room_cover_open:
		return {}
	if (data.room_id=="ch0_yard" or data.flags.yard_escaped) and not data.flags.maintenance_unlocked:
		return {}
	if (data.room_id in ["ch0_exit_lane", "ch1_crypt_entry", "ch1_crypt_hall", "ch1_archive"] or data.room_id.begins_with("ch2_")) and not data.flags.yard_escaped:
		return {}
	if data.flags.help_attempted and not data.flags.yard_escaped:
		return {}
	if data.flags.wardrobe_tutorial_done and not data.flags.room_phone_answered:
		return {}
	if data.flags.shadow_passed and not data.flags.wardrobe_tutorial_done:
		return {}
	if not data.get("photo_file","") is String:
		return {}
	if data.has("macau_guide"):
		if not data.macau_guide is Array:
			return {}
		for cid in data.macau_guide:
			if not cid is String or not MacauGuide.CARDS.has(cid):
				return {}
	else:
		data.macau_guide = []
	if data.flags.photo_taken:
		var regex:=RegEx.new()
		regex.compile("^photo_[0-9_]+[.]png$")
		if regex.search(data.photo_file)==null:
			return {}
	return data

static func read_valid(path: String, scope: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data:=decode(FileAccess.get_file_as_string(path),scope)
	if data.is_empty():
		return {}
	if data.flags.photo_taken:
		var photo_path:=path.get_base_dir().path_join(data.photo_file)
		if not FileAccess.file_exists(photo_path):
			return {}
		var image:=Image.load_from_file(photo_path)
		if image==null or image.is_empty():
			return {}
	return data

static func load_state(base: String, scope: Dictionary, checkpoint_name := "opening_checkpoint") -> Dictionary:
	if checkpoint_name not in ["opening_checkpoint", "pre_ending_checkpoint"]:
		return {"ok":false,"existing":false}
	for name in [checkpoint_name + ".json", checkpoint_name + ".bak.json"]:
		var data:=read_valid(base.path_join(name),scope)
		if not data.is_empty():
			return {"ok":true,"data":data,"from_backup":name.contains(".bak.")}
	return {"ok":false,"existing":FileAccess.file_exists(base.path_join(checkpoint_name + ".json")) or FileAccess.file_exists(base.path_join(checkpoint_name + ".bak.json"))}

static func save_state(base: String, data: Dictionary, scope: Dictionary, checkpoint_name := "opening_checkpoint") -> bool:
	if checkpoint_name not in ["opening_checkpoint", "pre_ending_checkpoint"]:
		return false
	var text:=JSON.stringify(data,"\t")
	if decode(text,scope).is_empty():
		return false
	var absolute_base := ProjectSettings.globalize_path(base)
	if DirAccess.make_dir_recursive_absolute(absolute_base)!=OK:
		return false
	var main:=base.path_join(checkpoint_name + ".json")
	var temp:=base.path_join(checkpoint_name + ".tmp.json")
	var backup:=base.path_join(checkpoint_name + ".bak.json")
	var had_valid_main := false
	if FileAccess.file_exists(main):
		had_valid_main = not read_valid(main,scope).is_empty()
		if had_valid_main:
			if not _copy_file(main,backup) or read_valid(backup,scope).is_empty():
				return false
		else:
			var quarantine:=base.path_join("invalid_checkpoint_%d.json" % Time.get_ticks_usec())
			if not _copy_file(main,quarantine):
				return false
	if not _write_text(temp,text) or read_valid(temp,scope).is_empty():
		return false
	if not _write_text(main,text):
		if had_valid_main:
			_copy_file(backup,main)
		return false
	if read_valid(main,scope).is_empty():
		if had_valid_main:
			_copy_file(backup,main)
		return false
	return true

static func _write_text(path: String, text: String) -> bool:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		return false
	file.store_string(text)
	file.flush()
	file.close()
	return true

static func _copy_file(source: String, destination: String) -> bool:
	var source_file:=FileAccess.open(source,FileAccess.READ)
	if source_file==null:
		return false
	var bytes:=source_file.get_buffer(source_file.get_length())
	source_file.close()
	var destination_file:=FileAccess.open(destination,FileAccess.WRITE)
	if destination_file==null:
		return false
	destination_file.store_buffer(bytes)
	destination_file.flush()
	destination_file.close()
	return true

static func save_photo(base: String, image: Image) -> String:
	var absolute_base := ProjectSettings.globalize_path(base)
	if image==null or image.is_empty() or DirAccess.make_dir_recursive_absolute(absolute_base)!=OK:
		return ""
	var name:="photo_%d_%d.png" % [int(Time.get_unix_time_from_system()),Time.get_ticks_usec()]
	var destination:=base.path_join(name)
	if image.save_png(destination)!=OK:
		return ""
	var verify:=Image.load_from_file(destination)
	if verify==null or verify.is_empty():
		return ""
	return name
