extends Control
class_name HorrorDirector

var hud_ref
var scare_player: AudioStreamPlayer
var elapsed_in_room := 0.0
var last_room_id := ""
var pulse_clock := 0.0
var flash_alpha := 0.0
var triggered_rooms := {}

const ROOM_SCARES := {
	"ch0_corridor": ["scare_bulb_pop", "走廊顶灯啪地炸出一串电火花……"],
	"ch0_maintenance": ["scare_pipe_scrape", "头顶锈管深处传来一记刺耳的金属刮擦声……"],
	"ch1_crypt_entry": ["scare_extra_step", "停步瞬间，石龛背后多响了一声沉重的脚步……"],
	"ch2_bunker_descent": ["scare_whisper_ear", "黑暗深坑边掠过一声极近的冷叹……"],
	"ch2_bunker_hall": ["scare_door_bang", "防空洞铁门背后猛然传出一声闷响！"],
	"ch3_amparo_archive": ["scare_door_bang", "冷库铁钩无风自晃，门后似有人指甲刮过铁板……"],
	"ch3_quiet_passage": ["scare_radio_static", "巷尾旧收音机突然窜出一阵沙哑粤剧杂音，又瞬间断电……"],
	"ch5_coastal_works": ["scare_pipe_scrape", "潮水涌动的暗渠下方传来铁链拖拽的回响……"],
	"ch5_coastal_pressure_gallery": ["scare_bulb_pop", "调压廊壁灯猛地闪灭了一瞬……"]
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	scare_player = AudioStreamPlayer.new()
	scare_player.bus = "SFX"
	scare_player.volume_db = -5.5
	add_child(scare_player)

func _process(delta: float) -> void:
	pulse_clock += delta
	flash_alpha = move_toward(flash_alpha, 0.0, delta * 1.8)
	var room := GameState.current_room_id
	if room != last_room_id:
		last_room_id = room
		elapsed_in_room = 0.0

	var in_chase := (is_instance_valid(AudioManager.chase_music) and AudioManager.chase_music.playing) or not GameState.demo_pursuit.is_empty()
	if in_chase or flash_alpha > 0.005:
		queue_redraw()

	if get_tree().paused or (is_instance_valid(hud_ref) and hud_ref.panel_open) or in_chase:
		return

	elapsed_in_room += delta
	if elapsed_in_room >= 5.2 and ROOM_SCARES.has(room) and not triggered_rooms.has(room):
		triggered_rooms[room] = true
		_trigger_micro_scare(ROOM_SCARES[room][0], ROOM_SCARES[room][1])

func _trigger_micro_scare(sfx_key: String, msg: String) -> void:
	if not AudioManager.silent_run and AudioManager.WORLD_SOUNDS.has(sfx_key):
		var path: String = AudioManager.WORLD_SOUNDS[sfx_key]
		if ResourceLoader.exists(path):
			scare_player.stream = load(path)
			scare_player.play()
	if not GameState.reduced_flash:
		flash_alpha = 0.22
	if is_instance_valid(hud_ref) and is_instance_valid(hud_ref.toast) and hud_ref.toast_time <= 0.0:
		hud_ref.notify(msg)
	queue_redraw()

func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size if size.x > 10 else Vector2(640, 360))
	var in_chase := (is_instance_valid(AudioManager.chase_music) and AudioManager.chase_music.playing) or not GameState.demo_pursuit.is_empty()
	var max_alpha := 0.10 if GameState.reduced_flash else 0.28
	if in_chase:
		var pulse := (0.55 + 0.45 * sin(pulse_clock * 16.5)) * max_alpha
		# Crimson horror border vignette during active chases
		draw_rect(Rect2(0, 0, area.size.x, 18), Color(0.52, 0.04, 0.05, pulse))
		draw_rect(Rect2(0, area.size.y - 18, area.size.x, 18), Color(0.52, 0.04, 0.05, pulse))
		draw_rect(Rect2(0, 0, 22, area.size.y), Color(0.52, 0.04, 0.05, pulse))
		draw_rect(Rect2(area.size.x - 22, 0, 22, area.size.y), Color(0.52, 0.04, 0.05, pulse))
	if flash_alpha > 0.005 and not GameState.reduced_flash:
		draw_rect(area, Color(0.05, 0.08, 0.07, flash_alpha))
