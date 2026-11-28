extends Control

signal finished

var anim: DemoCaptureAnimation
var blackout: ColorRect

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	anim = DemoCaptureAnimation.new()
	anim.appearance = DemoCaptureAnimation.BUTCHER_PATH
	add_child(anim)
	blackout = anim.blackout
	anim.finished.connect(func(): finished.emit())
