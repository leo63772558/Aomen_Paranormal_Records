extends Control

signal finished

var animation_player: AnimationPlayer
var rig: Skeleton2D
var head: Bone2D
var left_arm: Bone2D
var right_arm: Bone2D
var normal_face: Sprite2D
var screaming_face: Sprite2D
var blackout: ColorRect
var sound: AudioStreamPlayer
var hit_sent := false
var elapsed := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.005, 0.012, 0.009, 0.82)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	rig = Skeleton2D.new()
	rig.name = "PassengerRig"
	rig.position = Vector2(320, 165)
	add_child(rig)
	head = _bone("Head", Vector2.ZERO)
	left_arm = _bone("LeftArm", Vector2(-200, 160))
	right_arm = _bone("RightArm", Vector2(200, 160))
	normal_face = _sprite(0)
	head.add_child(normal_face)
	screaming_face = _sprite(1)
	screaming_face.modulate.a = 0.0
	head.add_child(screaming_face)
	# Enable painted grabbing hands plunging in from both sides as the passenger's jaw snaps open!
	left_arm.visible = true
	right_arm.visible = true
	left_arm.add_child(_sprite(2))
	right_arm.add_child(_sprite(3))
	var tear_layer := Control.new()
	tear_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	tear_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tear_layer.draw.connect(func():
		if GameState.reduced_flash or elapsed > 1.05:
			return
		var k := clampf((elapsed - 0.25) / 0.55, 0.0, 1.0)
		for i in range(6):
			var y := fmod(elapsed * 460.0 + i * 61.0, 360.0)
			tear_layer.draw_rect(Rect2(0, y, 640, 2.5), Color(0.88, 0.12, 0.10, 0.16 * k))
	)
	add_child(tear_layer)
	blackout = ColorRect.new()
	blackout.name = "Blackout"
	blackout.color = Color.BLACK
	blackout.modulate.a = 0.0
	blackout.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(blackout)
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)
	var animation := Animation.new()
	animation.length = 1.35
	animation.step = 1.0 / 60.0
	# Keep the collar and sleeve ends below the lower edge throughout the shot.
	# The hands can approach independently while their arms continue off camera.
	_track(animation, "PassengerRig:scale", [[0.0, Vector2.ONE * 1.05], [0.24, Vector2.ONE * 1.06], [0.45, Vector2.ONE * 1.13], [0.73, Vector2.ONE * 1.48], [1.05, Vector2.ONE * 1.57]])
	_track(animation, "PassengerRig:position", [[0.0, Vector2(320, 249)], [0.24, Vector2(320, 246)], [0.45, Vector2(317, 233)], [0.73, Vector2(322, 210)], [1.05, Vector2(320, 208)]])
	_track(animation, "PassengerRig/Head:rotation", [[0.0, -0.12], [0.24, -0.10], [0.46, 0.13], [0.69, -0.06], [0.93, 0.015]])
	_track(animation, "PassengerRig/Head:scale", [[0.0, Vector2.ONE], [0.46, Vector2(1.0, 1.01)], [0.70, Vector2(1.03, 1.09)], [0.94, Vector2.ONE]])
	_track(animation, "PassengerRig/Head/Part0:modulate:a", [[0.0, 1.0], [0.41, 1.0], [0.59, 0.0]])
	_track(animation, "PassengerRig/Head/Part1:modulate:a", [[0.0, 0.0], [0.41, 0.0], [0.59, 1.0]])
	_track(animation, "PassengerRig/LeftArm:position", [[0.0, Vector2(-225, 185)], [0.27, Vector2(-215, 178)], [0.55, Vector2(-185, 119)], [0.78, Vector2(-164, 98)], [1.05, Vector2(-155, 100)]])
	_track(animation, "PassengerRig/RightArm:position", [[0.0, Vector2(230, 190)], [0.33, Vector2(213, 180)], [0.58, Vector2(188, 115)], [0.83, Vector2(162, 99)], [1.05, Vector2(157, 104)]])
	_track(animation, "PassengerRig/LeftArm:rotation", [[0.0, -0.65], [0.34, -0.57], [0.69, -0.16], [1.04, 0.08]])
	_track(animation, "PassengerRig/RightArm:rotation", [[0.0, 0.64], [0.39, 0.50], [0.74, 0.12], [1.04, -0.07]])
	_track(animation, "Blackout:modulate:a", [[0.0, 0.0], [0.96, 0.0], [1.16, 1.0], [1.35, 1.0]])
	var library := AnimationLibrary.new()
	library.add_animation("lunge", animation)
	animation_player.add_animation_library("", library)
	animation_player.animation_finished.connect(func(_name): finished.emit())
	animation_player.play("lunge")
	sound = AudioStreamPlayer.new()
	sound.bus = "SFX"
	sound.volume_db = -6
	sound.stream = preload("res://assets/audio/demo/capture_rush_026.wav")
	add_child(sound)
	if not AudioManager.silent_run:
		sound.play()

func _bone(bone_name: String, at: Vector2) -> Bone2D:
	var bone := Bone2D.new()
	bone.name = bone_name
	bone.position = at
	bone.set_autocalculate_length_and_angle(false)
	bone.length = 30.0
	bone.rest = bone.transform
	rig.add_child(bone)
	return bone

func _sprite(index: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "Part%d" % index
	var atlas := preload("res://assets/characters/bus_lunge_parts_035.png")
	# The generated parts have generous but unequal margins. Explicit regions
	# exclude the head's shoulder pixels from the two arm sprites.
	var regions := [Rect2(0, 0, 623, 710), Rect2(623, 0, 623, 710), Rect2(0, 727, 623, 536), Rect2(623, 727, 623, 536)]
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = regions[index]
	texture.filter_clip = true
	sprite.texture = texture
	sprite.scale = Vector2.ONE * ((360.0 if index < 2 else 280.0) / texture.region.size.y)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return sprite

func _track(animation: Animation, path: String, keys: Array) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(path))
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	for key in keys:
		animation.track_insert_key(track, key[0], key[1])

func _process(delta: float) -> void:
	elapsed += delta
	if not GameState.reduced_flash and elapsed > 0.38 and elapsed < 1.02:
		var shake := (elapsed - 0.38) * 18.0
		rig.position += Vector2(sin(elapsed * 68.0) * shake, cos(elapsed * 54.0) * shake * 0.6) * delta * 18.0
	if not hit_sent and elapsed >= 0.63:
		hit_sent = true
		sound.stream = preload("res://assets/audio/demo/capture_hit_026.wav")
		sound.play()
		AudioManager.play_world_effect("jumpscare_shriek")

func _exit_tree() -> void:
	if is_instance_valid(sound):
		sound.stop()
		sound.stream = null
