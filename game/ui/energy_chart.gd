extends Control

const FlightUI := preload("res://ui/skin.gd")
var samples := PackedVector3Array()

func _ready() -> void:
	custom_minimum_size.y = 108
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var rect := Rect2(Vector2(46, 9), Vector2(maxf(size.x - 63, 1), maxf(size.y - 32, 1)))
	draw_style_box(FlightUI.box(Color("#17343e"), Color.TRANSPARENT, 6), Rect2(Vector2.ZERO, size))
	if samples.size() < 2:
		return
	var ymax := 20.0
	for p in samples:
		ymax = maxf(ymax, maxf(p.y, p.z * p.z / 19.62))
	ymax = ceilf(ymax / 10.0) * 10.0
	var font := get_theme_default_font()
	for i in 3:
		var y := rect.end.y - rect.size.y * i * 0.5
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color("#3d555e"))
		draw_string(font, Vector2(2, y + 5), "%d" % roundi(ymax * i * 0.5), HORIZONTAL_ALIGNMENT_RIGHT, 35, 13, FlightUI.SOFT)
	var end_time := maxf(samples[-1].x, 0.01)
	var potential := PackedVector2Array()
	var kinetic := PackedVector2Array()
	for p in samples:
		var x := rect.position.x + rect.size.x * p.x / end_time
		potential.append(Vector2(x, rect.end.y - rect.size.y * p.y / ymax))
		kinetic.append(Vector2(x, rect.end.y - rect.size.y * (p.z * p.z / 19.62) / ymax))
	draw_polyline(potential, FlightUI.MINT, 2, true)
	draw_polyline(kinetic, FlightUI.AMBER, 2, true)
	draw_string(font, Vector2(rect.position.x, size.y - 3), "0 s", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, FlightUI.SOFT)
	draw_string(font, Vector2(rect.end.x - 75, size.y - 3), "%.1f s" % end_time, HORIZONTAL_ALIGNMENT_RIGHT, 75, 13, FlightUI.SOFT)
