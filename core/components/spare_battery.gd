extends StaticBody2D

const BATTERY_SHEET := preload("res://assets/props/flashlight_spare_battery_196.png")
const RECOVERY := 50.0

var taken_flag := ""

func _ready() -> void:
	name = "FlashlightSpareBattery"
	collision_layer = 1
	collision_mask = 2
	z_index = int(position.y)
	var footprint := RectangleShape2D.new()
	footprint.size = Vector2(10, 4)
	var shape := CollisionShape2D.new()
	shape.shape = footprint
	add_child(shape)
	var region := AtlasTexture.new()
	region.atlas = BATTERY_SHEET
	region.region = Rect2(289, 225, 936, 567)
	region.filter_clip = true
	var art := Sprite2D.new()
	art.texture = region
	art.scale = Vector2.ONE * 16.0 / region.region.size.x
	art.position.y = -2.0
	add_child(art)

func collect(actor: PlayerController) -> String:
	if GameState.opening_flags.get(taken_flag, true):
		return ""
	if not actor.allow_flashlight:
		return "手电还没有拿在手上。"
	var previous := GameState.flashlight_battery
	if previous >= 100.0:
		return "手电电量充足，备用电池留在原处。"
	var restored := minf(100.0, previous + RECOVERY)
	GameState.flashlight_battery = restored
	GameState.opening_flags[taken_flag] = true
	if not GameState.save_opening_checkpoint():
		GameState.flashlight_battery = previous
		GameState.opening_flags[taken_flag] = false
		return "电池更换未能保存，备用电池仍在原处。"
	queue_free()
	AudioManager.play_world_effect("lock_mechanism")
	return "已更换备用电池 · 手电 %d%%" % ceili(restored)
