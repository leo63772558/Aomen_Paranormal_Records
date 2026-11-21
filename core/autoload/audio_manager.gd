extends Node

var effects: AudioStreamPlayer
var footsteps: AudioStreamPlayer
var step_index: int = 0
var silent_run: bool = false
var world_effects: AudioStreamPlayer
var ambience: AudioStreamPlayer
var last_world_effect: String = ""
signal world_effect_requested(effect_id: String)
signal dialogue_advanced
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
	"recording_fragment":"res://assets/audio/demo/recording_fragment_026.wav",
	"power_failure":"res://assets/audio/demo/power_failure_026.wav",
	"door_approach":"res://assets/audio/demo/door_approach_026.wav",
	"hall_wail":"res://assets/audio/demo/hall_wail_026.wav",
	"pit_drop":"res://assets/audio/demo/pit_drop_026.wav",
	"oil_drops":"res://assets/audio/demo/oil_drops_026.wav",
	"capture_hit":"res://assets/audio/demo/capture_hit_026.wav",
	"capture_rush":"res://assets/audio/demo/capture_rush_026.wav",
	"jumpscare_shriek":"res://assets/audio/demo/jumpscare_shriek_122.wav",
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
	"boss_roar_impact":"res://assets/audio/demo/boss_roar_impact.wav"
}
var chase_music: AudioStreamPlayer
var heartbeat_player: AudioStreamPlayer
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
	world_effects = AudioStreamPlayer.new()
	world_effects.bus = "SFX"
	world_effects.volume_db = 0.0
	world_effects.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world_effects)
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
	heartbeat_player = AudioStreamPlayer.new()
	heartbeat_player.bus = "SFX"
	heartbeat_player.volume_db = -4.0
	heartbeat_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(heartbeat_player)

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

func start_chase_music() -> void:
	if not is_instance_valid(chase_music):
		return
	if chase_music.playing:
		return
	var stream: AudioStreamWAV = load("res://assets/audio/demo/chase_urgent_122.wav")
	if stream != null:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		chase_music.stream = stream
		if not silent_run:
			chase_music.play()
	if is_instance_valid(heartbeat_player) and not heartbeat_player.playing:
		var hb: AudioStreamWAV = load("res://assets/audio/demo/heartbeat_tension.wav")
		if hb != null:
			hb.loop_mode = AudioStreamWAV.LOOP_FORWARD
			heartbeat_player.stream = hb
			if not silent_run:
				heartbeat_player.play()

func stop_chase_music() -> void:
	if is_instance_valid(chase_music) and chase_music.playing:
		chase_music.stop()
	if is_instance_valid(heartbeat_player) and heartbeat_player.playing:
		heartbeat_player.stop()

func set_bunker_ambience(enabled: bool) -> void:
	set_scene_ambience("bunker" if enabled else "")

func set_scene_ambience(kind: String) -> void:
	if not is_instance_valid(ambience):
		return
	var path: String = {
		"bunker":"res://assets/audio/recorded/bunker_ambience.ogg",
		"crypt":"res://assets/audio/recorded/crypt_ambience.ogg",
		"beach":"res://assets/audio/demo/beach_waves_ambience.wav",
		"street":"res://assets/audio/demo/street_macau_ambience.wav",
		"bus":"res://assets/audio/demo/bridge_bus_ambience.wav"
	}.get(kind, "")
	if path.is_empty():
		ambience.stop()
		return
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
		raw_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		ambience.stream = raw_stream
		ambience.play()

func play_world_effect(effect_id: String, pause_with_world := false) -> void:
	var path: String = WORLD_SOUNDS.get(effect_id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("Missing registered world sound: " + effect_id)
		return
	last_world_effect = effect_id
	# These completed interaction cues finish under the reading panel they open;
	# wardrobe/world movement sounds retain ordinary world-pause behaviour.
	var continues_under_panel := effect_id in ["camera_shutter", "metal_cover", "entrance_door", "power_switch", "lock_mechanism", "photo_knock", "gate_chain", "gate_iron", "recording_fragment", "capture_hit", "capture_rush", "jumpscare_shriek", "oil_drops", "balance_weight", "balance_settle", "archive_key_pickup", "archive_ticket_pickup", "valve_turn_heavy", "valve_resist_clank", "wood_creak", "wood_door_open", "wood_door_close", "metal_latch", "metal_spring", "key_jingle", "iron_slam", "tool_clink", "scare_bulb_pop", "scare_door_bang", "scare_extra_step", "scare_whisper_ear", "scare_pipe_scrape", "scare_radio_static", "electric_arc_blast", "boss_roar_impact"]
	world_effects.process_mode = Node.PROCESS_MODE_ALWAYS if continues_under_panel and not pause_with_world else Node.PROCESS_MODE_PAUSABLE
	world_effect_requested.emit(effect_id)
	world_effects.stream = load(path)
	if silent_run:
		return
	world_effects.volume_db = -12.0 if effect_id == "camera_shutter" else -5.0
	world_effects.play()

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
	elif room.begins_with("ch5_coastal") or room in ["ch2_bunker_descent", "ch2_bunker_hall", "ch2_bunker_ammo", "ch2_bunker_shaft"]:
		step_path = "res://assets/audio/demo/step_water_%d.wav" % (step_index % 2)
	elif room in ["ch4_bus_loop", "ch6_abandoned_vip", "ch0_maintenance"]:
		step_path = "res://assets/audio/demo/step_metal_%d.wav" % (step_index % 2)
	elif room in ["ch0_hk_work", "ch0_hk_home", "ch0_foyer", "ch0_corridor", "ch0_room304", "ch0_ah_kin", "ch3_amparo_archive"]:
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

func stop_all() -> void:
	if is_instance_valid(effects):
		effects.stop()
		effects.stream = null
	if is_instance_valid(footsteps):
		footsteps.stop()
		footsteps.stream = null
	if is_instance_valid(world_effects):
		world_effects.stop()
		world_effects.stream = null
	if is_instance_valid(ambience):
		ambience.stop()
		ambience.stream = null
	if is_instance_valid(chase_music):
		chase_music.stop()
		chase_music.stream = null
	if is_instance_valid(heartbeat_player):
		heartbeat_player.stop()
		heartbeat_player.stream = null

func _exit_tree() -> void:
	stop_all()
