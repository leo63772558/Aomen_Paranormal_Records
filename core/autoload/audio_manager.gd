extends Node

var effects: AudioStreamPlayer
var footsteps: AudioStreamPlayer
var step_index: int = 0
var silent_run: bool = false
var world_effects: AudioStreamPlayer
var world_effects_pool: Array[AudioStreamPlayer] = []
var world_effects_cursor: int = 0
var ambience: AudioStreamPlayer
var voice_player: AudioStreamPlayer
var bus_pa_player: AudioStreamPlayer
var last_world_effect: String = ""
var last_voice_id: String = ""
signal world_effect_requested(effect_id: String)
signal voice_requested(voice_id: String)
signal dialogue_advanced
const VOICE_LINES := {
	"ahhao_street_01": "res://assets/audio/v6/voice/ahhao_street_01_v6.wav",
	"ahhao_enter": "res://assets/audio/v6/voice/ahhao_enter_v6.wav",
	"ahhao_chase_panic": "res://assets/audio/v6/voice/ahhao_chase_panic_v6.wav",
	"ahhao_dying": "res://assets/audio/v6/voice/ahhao_dying_v6.wav",
	"ahhao_ghost_99": "res://assets/audio/v6/voice/ahhao_ghost_99_v6.wav",
	"dawen_pastry_reply": "res://assets/audio/v6/voice/dawen_pastry_reply_v6.wav",
	"dawen_knock_reply": "res://assets/audio/v6/voice/dawen_knock_reply_v6.wav",
	"dawen_foyer": "res://assets/audio/v6/voice/dawen_foyer_v6.wav",
	"dawen_meter": "res://assets/audio/v6/voice/dawen_meter_v6.wav",
	"dawen_stairs": "res://assets/audio/v6/voice/dawen_stairs_v6.wav",
	"dawen_ch6_answer_ahhao": "res://assets/audio/v6/voice/dawen_ch6_answer_ahhao_v6.wav",
	"jiamin_photo_invite": "res://assets/audio/v6/voice/jiamin_photo_invite_v6.wav",
	"jiamin_photo_done": "res://assets/audio/v6/voice/jiamin_photo_done_v6.wav",
	"jiamin_pastry_offer": "res://assets/audio/v6/voice/jiamin_pastry_offer_v6.wav",
	"jiamin_pastry_plan": "res://assets/audio/v6/voice/jiamin_pastry_plan_v6.wav",
	"jiamin_knock": "res://assets/audio/v6/voice/jiamin_knock_v6.wav",
	"jiamin_enter": "res://assets/audio/v6/voice/jiamin_enter_v6.wav",
	"jiamin_304_scared": "res://assets/audio/v6/voice/jiamin_304_scared_v6.wav",
	"jiamin_bunker_tape": "res://assets/audio/v6/voice/jiamin_bunker_tape_v6.wav",
	"jiamin_ch6_wall": "res://assets/audio/v6/voice/jiamin_ch6_wall_v6.wav",
	"jiamin_ch6_where_ahhao": "res://assets/audio/v6/voice/jiamin_ch6_where_ahhao_v6.wav",
	"granny_chen_01": "res://assets/audio/v6/voice/granny_chen_01_v6.wav",
	"granny_chen_02": "res://assets/audio/v6/voice/granny_chen_02_v6.wav",
	"uncle_liang_01": "res://assets/audio/v6/voice/uncle_liang_01_v6.wav",
	"uncle_liang_02": "res://assets/audio/v6/voice/uncle_liang_02_v6.wav",
	"bus_driver_pa": "res://assets/audio/v6/voice/bus_driver_pa_v6.wav",
	"bus_handrail_4lang": "res://assets/audio/v6/voice/bus_handrail_4lang_v6.wav",
	"bus_normal_pa": "res://assets/audio/v6/voice/bus_normal_pa_v6.wav",
	"bus_anomaly_pa": "res://assets/audio/v6/voice/bus_anomaly_pa_v6.wav"
}
const WORLD_SOUNDS := {
	"wardrobe_open":"res://assets/audio/qubodup/wardrobe_open.ogg",
	"wardrobe_close":"res://assets/audio/qubodup/wardrobe_close.ogg",
	"camera_shutter":"res://assets/audio/recorded/camera_shutter.wav",
	"metal_cover":"res://assets/audio/recorded/metal_cover.ogg",
	"entrance_door":"res://assets/audio/recorded/entrance_door.ogg",
	"power_switch":"res://assets/audio/recorded/power_switch.wav",
	"bed_scrape":"res://assets/audio/recorded/bed_scrape.ogg",
	"rotary_ring":"res://assets/audio/recorded/rotary_ring.ogg",
	"lock_mechanism":"res://assets/audio/recorded/lock_mechanism.wav",
	"phone_busy":"res://assets/audio/recorded/phone_busy.ogg",
	"red_footsteps":"res://assets/audio/recorded/shadow_step.ogg",
	"photo_knock":"res://assets/audio/recorded/door_knocks_025.ogg",
	"gate_chain":"res://assets/audio/recorded/gate_chain_025.wav",
	"gate_iron":"res://assets/audio/recorded/gate_iron_025.ogg",
	"recording_fragment":"res://assets/audio/v6/recording_fragment_v6.wav",
	"jiamin_phone_scream":"res://assets/audio/v6/jiamin_scream_phone_v6.wav",
	"menu_footsteps":"res://assets/audio/v6/menu_footsteps_v6.wav",
	"menu_door_knock":"res://assets/audio/v6/menu_door_knock_v6.wav",
	"power_failure":"res://assets/audio/demo/power_failure_026.wav",
	"door_approach":"res://assets/audio/demo/door_approach_026.wav",
	"hall_wail":"res://assets/audio/v6/jumpscare_family_v6.wav",
	"pit_drop":"res://assets/audio/demo/pit_drop_026.wav",
	"oil_drops":"res://assets/audio/demo/oil_drops_026.wav",
	"capture_hit":"res://assets/audio/demo/capture_hit_026.wav",
	"capture_rush":"res://assets/audio/demo/capture_rush_026.wav",
	"jumpscare_shriek":"res://assets/audio/v6/jumpscare_wraith_v6.wav",
	"jumpscare_wraith":"res://assets/audio/v6/jumpscare_wraith_v6.wav",
	"jumpscare_priest":"res://assets/audio/v6/jumpscare_family_v6.wav",
	"jumpscare_family":"res://assets/audio/v6/jumpscare_family_v6.wav",
	"jumpscare_butcher":"res://assets/audio/v6/jumpscare_butcher_v6.wav",
	"jumpscare_drowned":"res://assets/audio/demo/jumpscare_drowned_v10.wav",
	"chase_urgent":"res://assets/audio/demo/chase_urgent_122.wav",
	"balance_weight":"res://assets/audio/recorded/ch3_balance_weight.wav",
	"balance_settle":"res://assets/audio/recorded/ch3_balance_settle.wav",
	"archive_key_pickup":"res://assets/audio/recorded/archive_key_pickup.wav",
	"archive_ticket_pickup":"res://assets/audio/recorded/archive_ticket_pickup.wav",
	"valve_turn_heavy":"res://assets/audio/demo/valve_turn_heavy.wav",
	"valve_resist_clank":"res://assets/audio/demo/valve_resist_clank.wav",
	"heartbeat_tension":"res://assets/audio/demo/heartbeat_tension.wav",
	"wood_creak":"res://assets/audio/foley/wood_squeak_01.ogg",
	"wood_door_open":"res://assets/audio/foley/door_open_01.ogg",
	"wood_door_close":"res://assets/audio/foley/wood_close_01.ogg",
	"metal_latch":"res://assets/audio/foley/lock_open_01.ogg",
	"metal_spring":"res://assets/audio/foley/metal_spring_01.ogg",
	"key_jingle":"res://assets/audio/foley/keys_01.ogg",
	"iron_slam":"res://assets/audio/foley/metal_slam_01.ogg",
	"tool_clink":"res://assets/audio/foley/tools_01.ogg",
	"scare_bulb_pop":"res://assets/audio/demo/scare_bulb_pop.wav",
	"scare_door_bang":"res://assets/audio/demo/scare_door_bang.wav",
	"scare_extra_step":"res://assets/audio/demo/scare_extra_step.wav",
	"scare_whisper_ear":"res://assets/audio/demo/scare_whisper_ear.wav",
	"scare_pipe_scrape":"res://assets/audio/demo/scare_pipe_scrape.wav",
	"scare_radio_static":"res://assets/audio/demo/scare_radio_static.wav",
	"electric_arc_blast":"res://assets/audio/demo/electric_arc_blast.wav",
	"boss_roar_impact":"res://assets/audio/v6/jumpscare_butcher_v6.wav",
	"pickup_coin":"res://assets/audio/demo/pickup_coin.wav",
	"pickup_ceramic":"res://assets/audio/demo/pickup_ceramic.wav",
	"pickup_stone":"res://assets/audio/demo/pickup_stone.wav",
	"pickup_camera":"res://assets/audio/demo/pickup_camera.wav",
	"pickup_oil_can":"res://assets/audio/demo/pickup_oil_can.wav",
	"use_install_snap":"res://assets/audio/demo/use_install_snap.wav",
	"use_keypad_dead":"res://assets/audio/demo/use_keypad_dead.wav",
	"ghost_taunt_whisper":"res://assets/audio/v6/peephole_grudge_croak_v6.wav",
	"peephole_grudge_croak":"res://assets/audio/v6/peephole_grudge_croak_v6.wav",
	"cantonese_opera_radio":"res://assets/audio/v6/cantonese_opera_butterfly_v6.wav"
}
const CHASE_TRACKS := {
	"default": "res://assets/audio/demo/chase_urgent_122.wav",
	"stalker": "res://assets/audio/v6/chase_stalker_v6.wav",
	"priest": "res://assets/audio/demo/chase_priest_v9.wav",
	"family": "res://assets/audio/v6/chase_family_v6.wav",
	"butcher": "res://assets/audio/v6/chase_butcher_v6.wav",
	"boss": "res://assets/audio/demo/chase_boss_v9.wav"
}
var current_chase_profile: String = ""
var chase_music: AudioStreamPlayer
var exploration_bgm: AudioStreamPlayer
var heartbeat_player: AudioStreamPlayer
var item_pickup_player: AudioStreamPlayer
const ITEM_PICKUP_SOUNDS := {
	"multitool_pliers": "tool_clink",
	"ceramic_fuse": "pickup_ceramic",
	"insulated_bridge": "tool_clink",
	"service_grip": "tool_clink",
	"service_spindle": "tool_clink",
	"service_handle": "metal_latch",
	"gate_key_1": "key_jingle",
	"gate_key_2": "key_jingle",
	"gate_key_3": "key_jingle",
	"archive_spare_key": "archive_key_pickup",
	"beach_cabinet_key": "archive_key_pickup",
	"oil": "pickup_oil_can",
	"loose_stone": "pickup_stone",
	"jiamin_phone": "pickup_camera",
	"ahhao_camera": "pickup_camera",
	"jiamin_lens_cap": "pickup_camera",
	"bunker_recording": "pickup_camera",
	"macau_coin": "pickup_coin"
}
const VOLUME_BUSES := ["Master", "Music", "Ambience", "SFX", "Voice"]

func _ready() -> void:
	silent_run = AudioServer.get_driver_name() == "Dummy"
	for bus_name in ["Music", "Ambience", "SFX", "Voice"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_load_volume_preferences()
	effects = AudioStreamPlayer.new()
	effects.bus = "SFX"
	effects.volume_db = -1.0
	add_child(effects)
	footsteps = AudioStreamPlayer.new()
	footsteps.bus = "SFX"
	footsteps.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(footsteps)
	# 8-channel polyphonic world SFX pool so simultaneous horror layers (rush + scream + impact) NEVER cut each other off!
	for _i in range(8):
		var channel := AudioStreamPlayer.new()
		channel.bus = "SFX"
		channel.volume_db = 0.0
		channel.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(channel)
		world_effects_pool.append(channel)
	world_effects = world_effects_pool[0]
	ambience = AudioStreamPlayer.new()
	ambience.bus = "Ambience"
	ambience.volume_db = -6.0
	ambience.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(ambience)
	chase_music = AudioStreamPlayer.new()
	chase_music.bus = "Music"
	chase_music.volume_db = 1.0
	chase_music.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(chase_music)
	exploration_bgm = AudioStreamPlayer.new()
	exploration_bgm.bus = "Music"
	exploration_bgm.volume_db = -11.0
	exploration_bgm.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(exploration_bgm)
	heartbeat_player = AudioStreamPlayer.new()
	heartbeat_player.bus = "SFX"
	heartbeat_player.volume_db = -4.0
	heartbeat_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(heartbeat_player)
	item_pickup_player = AudioStreamPlayer.new()
	item_pickup_player.bus = "SFX"
	item_pickup_player.volume_db = -4.0
	item_pickup_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(item_pickup_player)
	voice_player = AudioStreamPlayer.new()
	voice_player.bus = "Voice"
	voice_player.volume_db = -1.5
	voice_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(voice_player)
	bus_pa_player = AudioStreamPlayer.new()
	bus_pa_player.bus = "Voice"
	bus_pa_player.volume_db = -6.0
	bus_pa_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(bus_pa_player)
	EventBus.item_acquired.connect(_on_item_acquired_sfx)

func _on_item_acquired_sfx(item_id: String, _count: int) -> void:
	if silent_run or not is_instance_valid(item_pickup_player):
		return
	var cue: String = ITEM_PICKUP_SOUNDS.get(item_id, "archive_ticket_pickup")
	var path: String = WORLD_SOUNDS.get(cue, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	item_pickup_player.stream = load(path)
	item_pickup_player.pitch_scale = randf_range(0.95, 1.05)
	item_pickup_player.play()

func get_bus_volume(bus_name: String) -> float:
	if bus_name not in VOLUME_BUSES:
		return 1.0
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return 1.0
	return 0.0 if AudioServer.is_bus_mute(index) else db_to_linear(AudioServer.get_bus_volume_db(index))

func set_bus_volume(bus_name: String, volume: float, persist := true) -> bool:
	if bus_name not in VOLUME_BUSES or not is_finite(volume) or volume < 0.0 or volume > 1.0:
		return false
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return false
	AudioServer.set_bus_mute(index, volume <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
	if not persist:
		return true
	var path: String = GameState.get_profile_path()
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path)) != OK:
		return false
	var preferences := ConfigFile.new()
	for name in VOLUME_BUSES:
		preferences.set_value("volume", name, get_bus_volume(name))
	return preferences.save(path.path_join("audio_preferences.cfg")) == OK

func _load_volume_preferences() -> void:
	var preferences := ConfigFile.new()
	if preferences.load(GameState.get_profile_path().path_join("audio_preferences.cfg")) != OK:
		return
	for name in VOLUME_BUSES:
		var value = preferences.get_value("volume", name, 1.0)
		if (value is float or value is int) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= 1.0:
			set_bus_volume(name, float(value), false)

func _enable_wav_loop(st: AudioStreamWAV) -> void:
	if st == null:
		return
	st.loop_begin = 0
	var bytes_per_sample := 2 if st.format == AudioStreamWAV.FORMAT_16_BITS else 1
	var channels := 2 if st.stereo else 1
	var frames := st.data.size() / maxi(1, bytes_per_sample * channels)
	if frames <= 0:
		frames = int(round(st.get_length() * float(st.mix_rate)))
	st.loop_end = maxi(1, frames)
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD

func _resolve_chase_profile(profile: String) -> String:
	if profile != "default":
		return profile if CHASE_TRACKS.has(profile) else "default"
	var room: String = GameState.current_room_id
	if room.begins_with("ch0_"):
		return "stalker"
	if room.begins_with("ch1_"):
		return "priest"
	if room.begins_with("ch2_"):
		return "family"
	if room.begins_with("ch3_"):
		return "butcher"
	if room.begins_with("ch5_") or room.begins_with("ch6_"):
		return "boss"
	return "default"

func start_chase_music(profile: String = "default") -> void:
	if not is_instance_valid(chase_music):
		return
	if is_instance_valid(exploration_bgm) and exploration_bgm.playing:
		exploration_bgm.stop()
	var resolved_profile: String = _resolve_chase_profile(profile)
	var track_path: String = CHASE_TRACKS.get(resolved_profile, CHASE_TRACKS["default"])
	if not ResourceLoader.exists(track_path):
		track_path = CHASE_TRACKS["default"]
	var needs_switch: bool = (current_chase_profile != resolved_profile) or chase_music.stream == null
	if needs_switch:
		var stream: AudioStreamWAV = load(track_path) as AudioStreamWAV
		if stream == null and track_path != CHASE_TRACKS["default"]:
			stream = load(CHASE_TRACKS["default"]) as AudioStreamWAV
		if stream != null:
			_enable_wav_loop(stream)
			if chase_music.playing:
				chase_music.stop()
			chase_music.stream = stream
			current_chase_profile = resolved_profile
	if chase_music.stream != null and not silent_run and not chase_music.playing:
		chase_music.play()
	if is_instance_valid(heartbeat_player) and not heartbeat_player.playing:
		var hb: AudioStreamWAV = load("res://assets/audio/demo/heartbeat_tension.wav") as AudioStreamWAV
		if hb != null:
			_enable_wav_loop(hb)
			heartbeat_player.stream = hb
			if not silent_run:
				heartbeat_player.play()

func stop_chase_music() -> void:
	current_chase_profile = ""
	if is_instance_valid(chase_music) and chase_music.playing:
		chase_music.stop()
	if is_instance_valid(heartbeat_player) and heartbeat_player.playing:
		heartbeat_player.stop()
	if is_instance_valid(exploration_bgm) and exploration_bgm.stream != null and not silent_run and not exploration_bgm.playing:
		exploration_bgm.play()

func set_bunker_ambience(enabled: bool) -> void:
	set_scene_ambience("bunker" if enabled else "")

func stop_bgm(_fade := 0.0) -> void:
	if is_instance_valid(exploration_bgm):
		exploration_bgm.stop()
		exploration_bgm.stream = null

func _set_exploration_bgm(kind: String) -> void:
	if not is_instance_valid(exploration_bgm):
		return
	var bgm_path: String = {
		"main_menu": "res://assets/audio/v6/bgm_main_menu_v6.wav",
		"home": "res://assets/audio/demo/bgm_hong_kong_evening.wav",
		"transit": "res://assets/audio/demo/bgm_crossing.wav",
		"night_bus": "res://assets/audio/demo/bgm_bunker_dread.wav",
		"crypt": "res://assets/audio/demo/bgm_crypt_drone.wav",
		"bunker": "res://assets/audio/demo/bgm_bunker_dread.wav",
		"street": "res://assets/audio/demo/bgm_hong_kong_evening.wav",
		"tenement": "res://assets/audio/demo/bgm_tenement_horror.wav",
		"butcher_opera": "res://assets/audio/demo/bgm_tenement_horror.wav",
		"beach": "res://assets/audio/demo/bgm_after_the_tide.wav",
		"coastal": "res://assets/audio/demo/bgm_after_the_tide.wav",
		"finale": "res://assets/audio/demo/bgm_under_the_concrete.wav"
	}.get(kind, "")
	exploration_bgm.volume_db = -24.0 if kind == "butcher_opera" else (-16.0 if kind == "night_bus" else -11.0)
	if bgm_path.is_empty():
		exploration_bgm.stop()
		exploration_bgm.stream = null
		return
	if exploration_bgm.stream != null and exploration_bgm.stream.resource_path == bgm_path:
		if not silent_run and not exploration_bgm.playing and not (is_instance_valid(chase_music) and chase_music.playing):
			exploration_bgm.play()
		return
	exploration_bgm.stop()
	exploration_bgm.stream = null
	var st := load(bgm_path)
	if st is AudioStreamWAV:
		_enable_wav_loop(st)
		exploration_bgm.stream = st
		if not silent_run and not (is_instance_valid(chase_music) and chase_music.playing):
			exploration_bgm.play()

func set_scene_ambience(kind: String) -> void:
	_set_exploration_bgm(kind)
	if not is_instance_valid(ambience):
		return
	var path: String = {
		"bunker":"res://assets/audio/recorded/bunker_ambience.ogg",
		"crypt":"res://assets/audio/recorded/crypt_ambience.ogg",
		"beach":"res://assets/audio/demo/beach_waves_ambience.wav",
		"coastal":"res://assets/audio/recorded/crypt_ambience.ogg",
		"finale":"res://assets/audio/recorded/crypt_ambience.ogg",
		"bus":"res://assets/audio/demo/bridge_bus_ambience.wav",
		"butcher_opera":"res://assets/audio/v6/cantonese_opera_butterfly_v6.wav"
	}.get(kind, "")
	if path.is_empty():
		ambience.stop()
		return
	# Keep Cantonese opera radio playing continuously even during reading/puzzle modals (never power-cut!)
	ambience.process_mode = Node.PROCESS_MODE_ALWAYS if kind == "butcher_opera" else Node.PROCESS_MODE_PAUSABLE
	ambience.volume_db = -4.0 if kind == "butcher_opera" else (-7.5 if kind == "bus" else -10.0)
	if ambience.playing and ambience.stream != null and ambience.stream.resource_path == path:
		return
	if silent_run:
		return
	ambience.stop()
	var raw_stream := load(path)
	if raw_stream is AudioStreamOggVorbis:
		raw_stream.loop = true
		ambience.stream = raw_stream
		ambience.play()
	elif raw_stream is AudioStreamWAV:
		_enable_wav_loop(raw_stream)
		ambience.stream = raw_stream
		ambience.play()

func _pick_world_channel() -> AudioStreamPlayer:
	if world_effects_pool.is_empty():
		return world_effects
	for _i in range(world_effects_pool.size()):
		var idx := (world_effects_cursor + _i) % world_effects_pool.size()
		var ch := world_effects_pool[idx]
		if is_instance_valid(ch) and not ch.playing:
			world_effects_cursor = (idx + 1) % world_effects_pool.size()
			return ch
	var fallback := world_effects_pool[world_effects_cursor % world_effects_pool.size()]
	world_effects_cursor = (world_effects_cursor + 1) % world_effects_pool.size()
	return fallback

func play_world_effect(effect_id: String, pause_with_world := false) -> void:
	var path: String = WORLD_SOUNDS.get(effect_id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("Missing registered world sound: " + effect_id)
		return
	last_world_effect = effect_id
	# These completed interaction cues finish under the reading panel they open;
	# wardrobe/world movement sounds retain ordinary world-pause behaviour.
	var continues_under_panel := effect_id in ["camera_shutter", "metal_cover", "entrance_door", "power_switch", "lock_mechanism", "photo_knock", "gate_chain", "gate_iron", "recording_fragment", "jiamin_phone_scream", "peephole_grudge_croak", "capture_hit", "capture_rush", "jumpscare_shriek", "jumpscare_wraith", "jumpscare_priest", "jumpscare_family", "jumpscare_butcher", "jumpscare_drowned", "oil_drops", "balance_weight", "balance_settle", "archive_key_pickup", "archive_ticket_pickup", "valve_turn_heavy", "valve_resist_clank", "wood_creak", "wood_door_open", "wood_door_close", "metal_latch", "metal_spring", "key_jingle", "iron_slam", "tool_clink", "scare_bulb_pop", "scare_door_bang", "scare_extra_step", "scare_whisper_ear", "scare_pipe_scrape", "scare_radio_static", "electric_arc_blast", "boss_roar_impact", "phone_busy", "use_keypad_dead"]
	if effect_id == "phone_busy":
		stop_world_effect("phone_busy")
	var channel := _pick_world_channel()
	world_effects = channel
	channel.set_meta("effect_id", effect_id)
	channel.process_mode = Node.PROCESS_MODE_ALWAYS if continues_under_panel and not pause_with_world else Node.PROCESS_MODE_PAUSABLE
	world_effect_requested.emit(effect_id)
	channel.stream = load(path)
	if silent_run:
		return
	var is_scare := effect_id.begins_with("jumpscare_") or effect_id == "boss_roar_impact"
	channel.volume_db = -12.0 if effect_id == "camera_shutter" else (-1.5 if is_scare else -5.0)
	channel.play()

func stop_world_effect(effect_id: String) -> void:
	for ch in world_effects_pool:
		if is_instance_valid(ch) and String(ch.get_meta("effect_id", "")) == effect_id:
			ch.stop()
			ch.set_meta("effect_id", "")

func play_at(parent: Node2D, effect_id: String, at: Vector2, volume := -5.0) -> void:
	var path: String = WORLD_SOUNDS.get(effect_id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("Missing registered positional sound: " + effect_id)
		return
	last_world_effect = effect_id
	world_effect_requested.emit(effect_id)
	if silent_run:
		return
	var sound := AudioStreamPlayer2D.new()
	sound.position = at
	sound.bus = "SFX"
	sound.max_distance = 390
	sound.volume_db = volume
	sound.stream = load(path)
	parent.add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()

func play_footstep(crouching: bool, sprinting: bool) -> void:
	if silent_run:
		return
	var room := GameState.current_room_id
	var step_path := "res://assets/audio/recorded/shadow_step.ogg"
	if room == "ch5_hacsa_beach":
		step_path = "res://assets/audio/demo/step_sand_%d.wav" % (step_index % 2)
	elif room.begins_with("ch5_coastal"):
		step_path = "res://assets/audio/demo/step_water_%d.wav" % (step_index % 2)
	elif room in ["ch4_bus_loop", "ch6_abandoned_vip", "ch0_maintenance"]:
		step_path = "res://assets/audio/demo/step_metal_%d.wav" % (step_index % 2)
	elif room in ["ch0_hk_home", "ch0_corridor", "ch0_room304", "ch0_ah_kin", "ch3_amparo_archive"]:
		step_path = "res://assets/audio/demo/step_wood_%d.wav" % (step_index % 2)
	else:
		step_path = "res://assets/audio/step_stone_%d.wav" % (step_index % 4)
	footsteps.stream = load(step_path)
	step_index = (step_index + 1) % 4
	footsteps.volume_db = -14.0 if crouching else (-2.0 if sprinting else -5.0)
	footsteps.pitch_scale = randf_range(0.88, 0.98)
	footsteps.play()

func play_effect(effect: String) -> void:
	if silent_run:
		return
	var path := "res://assets/audio/%s.wav" % effect
	if ResourceLoader.exists(path):
		effects.process_mode = Node.PROCESS_MODE_PAUSABLE if effect in ["step", "scrape"] else Node.PROCESS_MODE_ALWAYS
		effects.stream = load(path)
		effects.play()

func play_dialogue_advance() -> void:
	dialogue_advanced.emit()
	play_effect("click")

func play_voice(voice_id: String, volume_db: float = -1.5) -> void:
	var path: String = VOICE_LINES.get(voice_id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	last_voice_id = voice_id
	voice_requested.emit(voice_id)
	if not is_instance_valid(voice_player):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	voice_player.stop()
	voice_player.pitch_scale = 1.0
	voice_player.volume_db = volume_db
	voice_player.stream = stream
	if not silent_run:
		voice_player.play()

func stop_voice() -> void:
	if is_instance_valid(voice_player):
		voice_player.stop()

func play_bus_pa(voice_id: String, volume_db: float = -6.0) -> void:
	var path: String = VOICE_LINES.get(voice_id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	last_voice_id = voice_id
	voice_requested.emit(voice_id)
	if not is_instance_valid(bus_pa_player):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	bus_pa_player.stop()
	bus_pa_player.volume_db = volume_db
	bus_pa_player.stream = stream
	if not silent_run:
		bus_pa_player.play()

func stop_bus_pa() -> void:
	if is_instance_valid(bus_pa_player):
		bus_pa_player.stop()

func stop_all() -> void:
	if is_instance_valid(effects):
		effects.stop()
		effects.stream = null
	if is_instance_valid(footsteps):
		footsteps.stop()
		footsteps.stream = null
	for ch in world_effects_pool:
		if is_instance_valid(ch):
			ch.stop()
			ch.stream = null
	if is_instance_valid(world_effects):
		world_effects.stop()
		world_effects.stream = null
	if is_instance_valid(ambience):
		ambience.stop()
		ambience.stream = null
	if is_instance_valid(chase_music):
		chase_music.stop()
		chase_music.stream = null
	current_chase_profile = ""
	if is_instance_valid(exploration_bgm):
		exploration_bgm.stop()
		exploration_bgm.stream = null
	if is_instance_valid(heartbeat_player):
		heartbeat_player.stop()
		heartbeat_player.stream = null
	if is_instance_valid(item_pickup_player):
		item_pickup_player.stop()
		item_pickup_player.stream = null
	if is_instance_valid(voice_player):
		voice_player.stop()
		voice_player.stream = null
	if is_instance_valid(bus_pa_player):
		bus_pa_player.stop()
		bus_pa_player.stream = null

func _exit_tree() -> void:
	stop_all()
