extends Node

var checks := 0
var failures := 0
var cues: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")


func check(value: bool, label: String) -> void:
	checks += 1
	if value:
		print("PASS " + label)
	else:
		failures += 1
		push_error("FAIL " + label)


func run() -> void:
	check(GameState.profile == "test", "audio checks use an isolated test profile")
	check(AudioServer.get_driver_name() == "Dummy", "background checks use the dummy audio driver")
	AudioManager.world_effect_requested.connect(func(id: String): cues.append(id))
	for id in AudioManager.WORLD_SOUNDS:
		var path: String = AudioManager.WORLD_SOUNDS[id]
		var stream := load(path) as AudioStream if ResourceLoader.exists(path) else null
		check(stream != null and stream.get_length() > 0.0, "registered sound exists and decodes: " + id)
		var previous := cues.size()
		AudioManager.play_world_effect(id)
		check(cues.size() == previous + 1 and cues.back() == id and AudioManager.last_world_effect == id, "registered sound request reaches audio manager: " + id)
	for path in ["res://assets/audio/recorded/bunker_ambience.ogg", "res://assets/audio/recorded/crypt_ambience.ogg", "res://assets/audio/demo/chase_urgent_122.wav"]:
		var stream := load(path) as AudioStream if ResourceLoader.exists(path) else null
		check(stream != null and stream.get_length() > 0.0, "ambience or chase track decodes: " + path)
	for kind in ["home", "transit", "street", "tenement", "crypt", "bunker", "night_bus", "butcher_opera", "beach", "coastal", "finale"]:
		AudioManager.set_scene_ambience(kind)
		var stream := AudioManager.exploration_bgm.stream as AudioStreamWAV
		check(stream != null and stream.get_length() > 0.0 and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_end > 0, "scene has a decoded looping score: " + kind)
		check(not AudioManager.exploration_bgm.playing, "scene score stays silent on Dummy audio: " + kind)
	AudioManager.set_scene_ambience("")
	check(AudioManager.exploration_bgm.stream == null, "silence clears the previous room's score")
	AudioManager.play_world_effect("wardrobe_open")
	check(AudioManager.world_effects.process_mode == Node.PROCESS_MODE_PAUSABLE, "movement sound uses the world pause policy")
	AudioManager.play_world_effect("metal_cover")
	check(AudioManager.world_effects.process_mode == Node.PROCESS_MODE_ALWAYS, "short interaction cue may finish under its dialogue")
	AudioManager.start_chase_music()
	var chase_stream := AudioManager.chase_music.stream as AudioStreamWAV
	check(chase_stream != null and chase_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "chase trigger decodes and configures the replacement loop")
	check(AudioManager.chase_music.process_mode == Node.PROCESS_MODE_PAUSABLE and not AudioManager.chase_music.playing, "chase loop uses the world pause policy and remains silent on dummy audio")
	get_tree().paused = true
	await get_tree().process_frame
	check(not AudioManager.chase_music.can_process(), "chase loop is paused with the world")
	check(not AudioManager.exploration_bgm.can_process(), "exploration music follows world pause")
	get_tree().paused = false
	AudioManager.stop_chase_music()
	AudioManager.play_world_effect("jumpscare_shriek")
	check(AudioManager.world_effects.stream != null and AudioManager.world_effects.process_mode == Node.PROCESS_MODE_ALWAYS, "jumpscare request decodes its stinger and selects the overlay pause policy")
	get_tree().paused = true
	await get_tree().process_frame
	check(AudioManager.world_effects.process_mode == Node.PROCESS_MODE_ALWAYS and not AudioManager.world_effects.playing, "jumpscare stinger remains silent under the dummy driver")
	get_tree().paused = false
	AudioManager.stop_all()
	check(AudioManager.chase_music.stream == null and AudioManager.world_effects.stream == null, "triggered cue streams are released on cleanup")
	for vid in AudioManager.VOICE_LINES:
		var vpath: String = AudioManager.VOICE_LINES[vid]
		var vstream := load(vpath) as AudioStream if ResourceLoader.exists(vpath) else null
		check(vstream != null and vstream.get_length() > 0.0, "voice line exists and decodes: " + vid)
	AudioManager.play_voice("jiamin_knock")
	check(AudioManager.last_voice_id == "jiamin_knock" and AudioManager.voice_player.stream != null and not AudioManager.voice_player.playing, "voice player decodes and honors dummy driver")
	AudioManager.play_bus_pa("bus_handrail_4lang")
	check(AudioManager.bus_pa_player.stream != null and AudioManager.bus_pa_player.process_mode == Node.PROCESS_MODE_PAUSABLE, "bus PA uses world pausable policy")
	AudioManager.stop_all()
	check(AudioManager.voice_player.stream == null and AudioManager.bus_pa_player.stream == null, "voice and bus PA streams are released on stop_all")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.35, true).timeout
	print("AUDIO REGISTRY checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
