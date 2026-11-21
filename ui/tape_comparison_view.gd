extends Control

signal matched

var samples: PackedFloat32Array
var sound: AudioStreamPlayer
var active_track := -1
var playhead := 0.0
var elapsed := 0.0
var track_buttons: Array[Button] = []
var current_samples: PackedFloat32Array
var trim_slider: HSlider
var played_tracks: Dictionary = {}
var confirmed := false
var status := "先分别重放，再拖动下方滑轨对齐断音。"
var streams: Array[AudioStreamWAV] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	sound = AudioStreamPlayer.new()
	sound.bus = "Voice"
	sound.volume_db = -8.0
	streams = [preload("res://assets/audio/demo/recording_fragment_026.wav"), preload("res://assets/audio/recorded/bus_replayed_fragment_037.wav")]
	sound.stream = streams[0]
	add_child(sound)
	sound.finished.connect(func(): active_track = -1)
	# This is a real envelope from the shared recording, not a decorative trace.
	samples = _envelope(streams[0])
	current_samples = _envelope(streams[1])
	for index in range(2):
		var button := Button.new()
		button.text = "▶ 旧附件 · 失踪前" if index == 0 else "▶ 车载片段 · 刚刚"
		button.position = Vector2(6, 4 + index * 83)
		button.size = Vector2(274, 26)
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(play_track.bind(index))
		add_child(button)
		track_buttons.append(button)
	trim_slider = HSlider.new()
	trim_slider.position = Vector2(8, 173)
	trim_slider.size = Vector2(270, 18)
	trim_slider.min_value = 0.0
	trim_slider.max_value = 0.44
	trim_slider.step = 0.005
	trim_slider.value_changed.connect(func(_value): status = "对齐两条记录中的断音，再确认是不是旧片段。")
	add_child(trim_slider)

func _envelope(wav: AudioStreamWAV) -> PackedFloat32Array:
	var envelope := PackedFloat32Array()
	var bytes := wav.data
	var stride := 2 * (2 if wav.stereo else 1)
	for bin_index in range(128):
		var peak := 0.0
		var begin := int(float(bin_index) / 128.0 * 2.0 * wav.mix_rate)
		var end := mini(int(float(bin_index + 1) / 128.0 * 2.0 * wav.mix_rate), bytes.size() / stride)
		for sample_index in range(begin, end, 16):
			var offset := sample_index * stride
			if offset + 1 < bytes.size():
				peak = maxf(peak, absf(float(bytes.decode_s16(offset))) / 32768.0)
		envelope.append(peak)
	return envelope

func play_track(index: int) -> void:
	active_track = index
	played_tracks[index] = true
	playhead = 0.0
	sound.stop()
	sound.stream = streams[index]
	sound.play()

func confirm_match() -> void:
	if confirmed:
		return
	if played_tracks.size() < 2:
		status = "还没有重放两段记录。先听完同一处敲击。"
		return
	if absf(trim_slider.value - 0.22) > 0.025:
		status = "电流断口还没有对齐；拖动滑轨重新对照。"
		return
	confirmed = true
	status = "断音与敲击同步重合：这是旧片段的再次播放。"
	matched.emit()

func _process(delta: float) -> void:
	elapsed += delta
	if active_track >= 0:
		playhead = sound.get_playback_position() / maxf(sound.stream.get_length(), 0.01)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("10211e"))
	for track in range(2):
		var center := 57.0 + track * 83.0
		draw_line(Vector2(8, center), Vector2(281, center), Color("344d43"), 1.0)
		var trace := samples if track == 0 else current_samples
		for index in range(trace.size()):
			var x := 9.0 + float(index) * 2.1 - (trim_slider.value * 134.4 if track == 1 and is_instance_valid(trim_slider) else 0.0)
			if x < 8 or x > 281: continue
			var height := trace[index] * 22.0
			draw_line(Vector2(x, center - height), Vector2(x, center + height), Color("a1a989"), 1.2)
		if active_track == track:
			var scan_x := 9.0 + playhead * 267.0
			draw_line(Vector2(scan_x, center - 27), Vector2(scan_x, center + 27), Color("dac38e"), 1.5)

func _exit_tree() -> void:
	if is_instance_valid(sound):
		sound.stop()
		sound.stream = null
