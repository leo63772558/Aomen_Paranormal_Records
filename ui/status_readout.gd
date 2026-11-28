extends Control
var show_flashlight: bool = true
var _pulse_time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()

func _draw() -> void:
	var font := get_theme_default_font()
	var stamina_pct := clampf(GameState.stamina / 100.0, 0.0, 1.0)
	var bat_pct := clampf(GameState.flashlight_battery / 100.0, 0.0, 1.0)
	var plate_w := 234.0 if show_flashlight else 120.0
	var plate_h := 24.0

	# Minimalist HK-horror smoked obsidian-emerald glass strip with micro rivets & crisp hairline brass trim
	var plate := Rect2(-8.0, -15.0, plate_w, plate_h)
	draw_rect(Rect2(plate.position + Vector2(1.0, 1.5), plate.size), Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(plate, Color(0.022, 0.042, 0.036, 0.84))
	draw_rect(plate, Color(0.62, 0.54, 0.36, 0.54), false, 1.0)
	draw_line(plate.position + Vector2(2, 1), Vector2(plate.end.x - 2, plate.position.y + 1), Color(1.0, 0.94, 0.76, 0.14), 1.0)

	# --- Left Gauge: Stamina (subtle pulse/foot-sprint vector glyph + recessed micro-segmented bar + numeric %) ---
	var sx := -1.0
	var sy := -3.0
	# Tiny stylized sprint bolt / lung-pulse icon
	draw_colored_polygon(PackedVector2Array([
		Vector2(sx + 4.5, sy - 6.5), Vector2(sx + 1.0, sy - 1.5), Vector2(sx + 4.0, sy - 1.5),
		Vector2(sx + 2.5, sy + 3.5), Vector2(sx + 7.2, sy - 2.5), Vector2(sx + 4.4, sy - 2.5)
	]), Color("c4d8a8") if stamina_pct >= 0.25 else Color("ea7b68"))

	var st_rect := Rect2(10.0, -6.5, 70.0, 5.5)
	draw_rect(st_rect, Color(0.015, 0.025, 0.02, 0.95))
	draw_rect(st_rect, Color("3c4e43", 0.9), false, 0.8)
	var st_fill_w := st_rect.size.x * stamina_pct
	if st_fill_w > 0.6:
		var low_st := stamina_pct < 0.25
		var pulse := 0.72 + 0.28 * sin(_pulse_time * 9.0) if low_st else 1.0
		var st_col := Color(0.86, 0.30, 0.24, pulse) if low_st else Color("7fb888").lerp(Color("ebd68a"), stamina_pct)
		draw_rect(Rect2(st_rect.position + Vector2(0.8, 0.8), Vector2(maxf(0.0, st_fill_w - 1.6), st_rect.size.y - 1.6)), st_col)
		draw_line(st_rect.position + Vector2(1.0, 1.3), st_rect.position + Vector2(maxf(1.0, st_fill_w - 1.0), 1.3), Color(1.0, 0.97, 0.88, 0.50), 1.0)
	draw_string(font, Vector2(84.0, -0.5), "%d" % int(round(GameState.stamina)), HORIZONTAL_ALIGNMENT_RIGHT, 22, 8, Color("c8d8c2") if stamina_pct >= 0.25 else Color("ee8876"))

	if not show_flashlight:
		return

	# Clean brass hairline divider
	draw_line(Vector2(111.0, -11.5), Vector2(111.0, 4.5), Color("67725e", 0.55), 1.0)

	# --- Right Gauge: Vintage brass flashlight glyph + glowing amber battery meter + percentage ---
	var gx := 118.0
	draw_rect(Rect2(gx, -5.8, 6.5, 4.0), Color("7a6d4e"))
	draw_rect(Rect2(gx + 6.5, -6.8, 2.8, 6.0), Color("d5bc7a"))
	if bat_pct > 0.01:
		draw_colored_polygon(PackedVector2Array([
			Vector2(gx + 9.3, -5.2), Vector2(gx + 14.5, -7.2), Vector2(gx + 14.5, -0.4), Vector2(gx + 9.3, -2.4)
		]), Color(0.98, 0.86, 0.52, 0.28 + 0.42 * bat_pct))

	var fl_rect := Rect2(137.0, -6.5, 62.0, 5.5)
	draw_rect(fl_rect, Color(0.015, 0.025, 0.02, 0.95))
	draw_rect(fl_rect, Color("3c4e43", 0.9), false, 0.8)
	var fl_fill_w := fl_rect.size.x * bat_pct
	if fl_fill_w > 0.6:
		var fl_flicker := (0.64 + 0.36 * sin(_pulse_time * 16.0)) if bat_pct < 0.20 else 1.0
		var fl_col := Color(0.90, 0.40, 0.24, fl_flicker) if bat_pct < 0.20 else Color("c9ad68").lerp(Color("fae4a4"), bat_pct)
		draw_rect(Rect2(fl_rect.position + Vector2(0.8, 0.8), Vector2(maxf(0.0, fl_fill_w - 1.6), fl_rect.size.y - 1.6)), fl_col)
		draw_line(fl_rect.position + Vector2(1.0, 1.3), fl_rect.position + Vector2(maxf(1.0, fl_fill_w - 1.0), 1.3), Color(1.0, 0.98, 0.88, 0.54), 1.0)
	draw_string(font, Vector2(202.0, -0.5), "%d%%" % int(round(GameState.flashlight_battery)), HORIZONTAL_ALIGNMENT_LEFT, 26, 8, Color("e5d69c") if bat_pct >= 0.20 else Color("f08a6d"))
