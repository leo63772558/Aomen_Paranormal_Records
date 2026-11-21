extends Node2D
## Dedicated six-pose, held-pipe action. The contact cue follows the painted strike.

signal contact

const SHEET := preload("res://assets/characters/jiamin_pipe_strike_086.png")
const CELL := Vector2(512, 512)
const ANCHOR := Vector2(251, 503)

var figure: Sprite2D
var sequence: Tween
var displayed_frame := 0
var striking := false


func _ready() -> void:
	figure = Sprite2D.new()
	figure.name = "PaintedHeldPipePose"
	figure.light_mask = 2
	figure.offset = CELL * 0.5 - ANCHOR
	add_child(figure)
	set_frame(0)


func set_frame(index: int) -> void:
	displayed_frame = clampi(index, 0, 5)
	var atlas := AtlasTexture.new()
	atlas.atlas = SHEET
	atlas.region = Rect2(Vector2(displayed_frame % 3, floori(displayed_frame / 3.0)) * CELL, CELL)
	figure.texture = atlas


func hold(actor: PlayerController) -> void:
	position = actor.position
	z_index = int(position.y)
	# The existing walk frame has a 166px visible body at its metadata scale.
	# New poses have a 493px visible body, so feet and adult stature remain fixed.
	figure.scale = Vector2.ONE * actor.sprite_scale * 166.0 / 493.0
	actor.sprite.visible = false


func strike() -> void:
	if striking:
		return
	striking = true
	sequence = create_tween()
	sequence.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	sequence.tween_callback(set_frame.bind(1))
	sequence.tween_interval(0.045)
	sequence.tween_callback(set_frame.bind(2))
	sequence.tween_interval(0.035)
	sequence.tween_callback(set_frame.bind(3))
	sequence.tween_callback(func(): contact.emit())
	sequence.tween_interval(0.035)
	sequence.tween_callback(set_frame.bind(4))
	sequence.tween_interval(0.04)
	sequence.tween_callback(set_frame.bind(5))
	sequence.tween_interval(0.04)
	sequence.tween_callback(set_frame.bind(0))
	await sequence.finished
	striking = false


func release(actor: PlayerController) -> void:
	actor.sprite.visible = true
	queue_free()
