extends Control

signal verified

var heard := [false, false]
const TITLES := ["洞口现场", "嘉敏的录音"]
const TRANSCRIPTS := ["正门从外面锁住，里面的人打不开。", "「阿豪……楼梯口有人。我试试排风竖井。」"]
var status := "依次点两段录音，看看她当时往哪走。"
var info: Label
var classify: Button
var dismiss: Button
var transcripts: Array[Label] = []
var play_buttons: Array[Button] = []

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	var header := _label("复听录音", Vector2(19, 8), 19, Color("ecd6a3"))
	header.size.x = 420
	_label("Esc 返回", Vector2(535, 10), 12, Color("d1ceb8"))
	var recorder := TextureRect.new()
	recorder.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	recorder.texture = DemoItems.texture("bunker_recording")
	recorder.position = Vector2(14, 54)
	recorder.size = Vector2(135, 190)
	recorder.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	recorder.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(recorder)
	for i in range(2):
		var row_y := 62 + i * 83
		_label(TITLES[i], Vector2(165, row_y), 15, Color("e5dfc5"))
		transcripts.append(_label("播放后显示文字", Vector2(165, row_y + 34), 13, Color("ddd4b3")))
		var play := Button.new()
		play.text = "播放"
		play.position = Vector2(493, row_y - 4)
		play.size = Vector2(102, 30)
		play.pressed.connect(_play.bind(i))
		add_child(play)
		play_buttons.append(play)
	info = _label(status, Vector2(19, 228), 13, Color("e1dcbd"))
	classify = Button.new()
	classify.text = "她当时改走竖井"
	classify.position = Vector2(20, 271)
	classify.size = Vector2(235, 33)
	classify.disabled = true
	classify.pressed.connect(func(): verified.emit())
	add_child(classify)
	dismiss = Button.new()
	dismiss.text = "她现在一定还在洞里"
	dismiss.position = Vector2(271, 271)
	dismiss.size = Vector2(239, 33)
	dismiss.disabled = true
	dismiss.pressed.connect(func(): info.text = "这是她当时留下的录音。再看看她提到哪条退路。")
	add_child(dismiss)

func _label(value: String, at: Vector2, points: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _play(index: int) -> void:
	AudioManager.play_world_effect("gate_chain" if index == 0 else "recording_fragment")
	heard[index] = true
	transcripts[index].text = TRANSCRIPTS[index]
	play_buttons[index].text = "重播"
	info.text = "两段都听过了。选出录音能确认的一件事。" if heard[0] and heard[1] else "再听另一段。"
	classify.disabled = not (heard[0] and heard[1])
	dismiss.disabled = classify.disabled
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("13201b"))
	for index in range(2):
		var card := Rect2(154, 49 + index * 83, 447, 74)
		draw_rect(card, Color("1d2c23"))
		draw_rect(card, Color("8f8056") if heard[index] else Color("526458"), false, 1.0)
