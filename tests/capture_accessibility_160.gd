extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS " if value else "FAIL ") + description)

func run() -> void:
	check(GameState.profile == "test", "isolated capture test profile")
	var cues: Array[String] = []
	AudioManager.world_effect_requested.connect(func(id: String): cues.append(id))
	var layer := CanvasLayer.new()
	add_child(layer)
	for appearance in [DemoCaptureAnimation.PRIEST_PATH, DemoCaptureAnimation.FAMILY_PATH, DemoCaptureAnimation.RANGER_PATH]:
		var animation := DemoCaptureAnimation.new()
		animation.appearance = appearance
		layer.add_child(animation)
		animation.set_process(false)
		animation.apply_pose(0.24)
		var pose := animation.mesh.polygon.duplicate()
		var art := animation.mesh.texture
		var uvs := animation.mesh.uv.duplicate()
		animation.apply_pose(0.25)
		check(animation.mesh.texture == art and animation.mesh.uv == uvs and animation.mesh.polygon != pose, "changes deform the same art and UV mesh")
		var step := 0.0
		var last_pose := animation.mesh.polygon.duplicate()
		for frame in range(16, 34):
			animation.apply_pose(float(frame) / 60.0)
			var current := animation.mesh.polygon
			for index in range(current.size()):
				step = maxf(step, current[index].distance_to(last_pose[index]))
			last_pose = current.duplicate()
		check(step > 0.0 and step < 14.0, "local movement remains continuous frame to frame during the reach")
		animation.apply_pose(0.67)
		check(animation.mesh.scale.x > 1.0 and animation.blackout.color.a < 0.5, "the advancing figure remains visible before blackout")
		GameState.reduced_flash = true
		animation.apply_pose(0.61)
		check(animation.blackout.color == Color(0, 0, 0, 0), "reduced mode suppresses impact tint")
		animation.apply_pose(0.97)
		check(animation.blackout.color.a == 1.0 and animation.blackout.size.is_equal_approx(animation.size), "the sequence ends in full-screen blackout")
		var before := cues.count("capture_hit")
		animation.elapsed = DemoCaptureAnimation.IMPACT_TIME - 0.01
		animation._process(0.03)
		animation._process(0.02)
		check(cues.count("capture_hit") == before + 1, "one impact cue is sent at the strike")
		animation.free()
	print("CAPTURE MOTION checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
