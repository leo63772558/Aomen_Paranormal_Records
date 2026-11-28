extends Node
class_name GhostTaunt

signal taunt_shown

# Spawns eerie floating trembling crimson taunt whispers above chasing ghosts
# and dark-shadow materialization bursts when ghosts emerge in flickering darkness.

var lines: PackedStringArray = PackedStringArray(["别回头……", "留下来……陪我……", "你听见了吗……"])
var interval := 4.5
var timer := 1.4

static func attach(host: Node2D, custom_lines: PackedStringArray, period := 4.5) -> GhostTaunt:
	var t := GhostTaunt.new()
	t.name = "GhostTaunt"
	t.lines = custom_lines
	t.interval = maxf(3.6, period)
	t.timer = randf_range(1.1, 2.2)
	host.add_child(t)
	return t

static func materialize_from_shadow(world: Node2D, at: Vector2) -> void:
	if world == null or GameState.reduced_flash:
		return
	AudioManager.play_world_effect("scare_bulb_pop")
	var burst := CPUParticles2D.new()
	burst.position = at + Vector2(0, -32)
	burst.amount = 22
	burst.lifetime = 0.65
	burst.one_shot = true
	burst.explosiveness = 0.85
	burst.spread = 180.0
	burst.initial_velocity_min = 18.0
	burst.initial_velocity_max = 62.0
	burst.scale_amount_min = 2.4
	burst.scale_amount_max = 5.5
	burst.color = Color(0.05, 0.04, 0.06, 0.82)
	burst.z_index = int(at.y) + 4
	world.add_child(burst)
	burst.emitting = true
	world.get_tree().create_timer(0.85, false).timeout.connect(func():
		if is_instance_valid(burst):
			burst.queue_free()
	)

func _physics_process(delta: float) -> void:
	var host := get_parent() as Node2D
	if not is_instance_valid(host) or host.get_parent() == null or not host.is_visible_in_tree():
		return
	if "active" in host and not host.active:
		return
	if "flash_receiver" in host and is_instance_valid(host.flash_receiver) and host.flash_receiver.is_stunned():
		return
	timer -= delta
	if timer <= 0.0:
		timer = interval + randf_range(-0.4, 0.9)
		_emit_taunt(host)

func _emit_taunt(host: Node2D) -> void:
	if lines.is_empty():
		return
	var text := lines[randi() % lines.size()]
	var world := host.get_parent()
	var holder := Node2D.new()
	holder.position = host.global_position + Vector2(randf_range(-18, 18), -88)
	holder.rotation = randf_range(-0.07, 0.07)
	holder.z_index = 95
	var font := UiFont.song()
	# Layered ghostly smeared blood-ink echo behind the primary whisper
	var echo := Label.new()
	echo.add_theme_font_override("font", font)
	echo.add_theme_font_size_override("font_size", 14)
	echo.add_theme_color_override("font_color", Color(0.42, 0.03, 0.04, 0.56))
	echo.text = text
	echo.position = Vector2(-78, 2)
	echo.size = Vector2(160, 24)
	echo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	echo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(echo)
	# Crisp dark-crimson calligraphic horror text with deep obsidian outline
	var lbl := Label.new()
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color("b82422"))
	lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.005, 0.008, 0.95))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.text = text
	lbl.position = Vector2(-80, 0)
	lbl.size = Vector2(160, 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(lbl)
	world.add_child(holder)
	taunt_shown.emit()
	AudioManager.play_world_effect("ghost_taunt_whisper")
	var base_x := holder.position.x
	var tw := holder.create_tween()
	tw.tween_property(holder, "position:y", holder.position.y - 26.0, 1.85).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(holder, "modulate:a", 0.0, 1.45).set_delay(0.45)
	if not GameState.reduced_flash:
		var shiver := holder.create_tween()
		shiver.tween_property(holder, "position:x", base_x + 2.2, 0.08)
		shiver.tween_property(holder, "position:x", base_x - 2.4, 0.09)
		shiver.tween_property(holder, "position:x", base_x + 1.6, 0.10)
		shiver.tween_property(holder, "position:x", base_x - 1.4, 0.11)
		shiver.tween_property(holder, "position:x", base_x, 0.12)
	tw.tween_callback(holder.queue_free)
